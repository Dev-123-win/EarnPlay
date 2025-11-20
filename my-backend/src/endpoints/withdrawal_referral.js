import admin from 'firebase-admin';
import {
  validateRequest,
  handleError,
  successResponse
} from '../utils/validation.js';
import { REWARDS } from '../utils/constants.js';

/**
 * Handle withdrawal request
 * ✅ CRITICAL: Idempotency (24h KV cache) + Rate limiting + Fraud detection
 * 
 * Fraud Scoring:
 * - Account age < 7 days: +20
 * - Device/IP mismatch: +10
 * - Zero activity: +15
 * - Block if score > 50
 * 
 * @param {Request} request - HTTP request
 * @param {Firestore} db - Firestore instance
 * @param {string} userId - User ID from auth
 * @param {ExecutionContext} ctx - Cloudflare worker context
 * @returns {Promise<Response>} HTTP response
 */
export async function handleWithdrawal(request, db, userId, ctx) {
  try {
    // 1. Parse and validate request body
    const { amount, method, paymentId, deviceHash, idempotencyKey } = await validateRequest(request, {
      amount: 'number',
      method: 'string',
      paymentId: 'string',
      deviceHash: 'string',
      idempotencyKey: 'string'
    });

    // 2. Check idempotency cache (prevent duplicate withdrawals)
    const idempotencyCacheKey = `idempotency:request-withdrawal:${userId}:${idempotencyKey}`;
    const cached = await ctx.env.KV_IDEMPOTENCY.get(idempotencyCacheKey);
    
    if (cached) {
      console.log('[Withdrawal] Returning cached response (idempotent)');
      return new Response(cached, { status: 200 });
    }

    // 3. Check rate limits (3 per minute per UID, 10 per minute per IP)
    const ip = request.headers.get('CF-Connecting-IP') || 'unknown';
    const rateLimitResult = await checkRateLimits(userId, ip, ctx.env.KV_RATE_COUNTERS, 'request-withdrawal');
    
    if (rateLimitResult.limited) {
      return handleError(`Rate limit exceeded. Try again in ${rateLimitResult.retryAfter}s`, 429);
    }

    // 4. Validate withdrawal amount
    const minWithdrawal = 500;
    if (amount < minWithdrawal) {
      return handleError(`Minimum withdrawal amount is ${minWithdrawal} coins`, 400);
    }

    // 5. Validate method and payment ID
    if (!['UPI', 'BANK'].includes(method)) {
      return handleError('Invalid payment method. Use UPI or BANK', 400);
    }

    if (method === 'UPI' && !isValidUPI(paymentId)) {
      return handleError('Invalid UPI ID format (use: name@bank)', 400);
    }

    if (method === 'BANK' && !isValidBankAccount(paymentId)) {
      return handleError('Invalid bank account format', 400);
    }

    const userRef = db.collection('users').doc(userId);
    let result;

    // 6. ATOMIC TRANSACTION: Read + Validate + Fraud Check + Write
    await db.runTransaction(async (transaction) => {
      const userSnap = await transaction.get(userRef);

      if (!userSnap.exists) {
        const err = new Error('User not found');
        err.status = 404;
        throw err;
      }

      const userData = userSnap.data();

      // Validate sufficient balance (inside transaction, no race conditions)
      if (userData.coins < amount) {
        const err = new Error(`Insufficient balance. You have ${userData.coins} coins`);
        err.status = 400;
        throw err;
      }

      // ✅ FRAUD DETECTION: Calculate risk score
      let riskScore = 0;
      const createdAt = userData.createdAt?.toDate?.() || new Date(0);
      const accountAgeMs = Date.now() - createdAt.getTime();
      const accountAgeDays = accountAgeMs / (1000 * 60 * 60 * 24);

      if (accountAgeDays < 7) {
        riskScore += 20;  // New account = suspicious
      }

      if (userData.lastRecordedIP && userData.lastRecordedIP !== ip) {
        riskScore += 10;  // IP mismatch
      }

      if ((userData.totalAdsWatched || 0) === 0 && (userData.totalGamesWon || 0) === 0) {
        riskScore += 15;  // Zero activity = suspicious
      }

      // Block if score > 50
      if (riskScore > 50) {
        console.warn(`[Withdrawal Fraud] Blocked user ${userId}: score=${riskScore}`);
        const err = new Error('Withdrawal request blocked due to security checks. Contact support.');
        err.status = 403;
        throw err;
      }

      // Create withdrawal document (atomic)
      const withdrawalRef = db.collection('withdrawals').doc();
      transaction.set(withdrawalRef, {
        userId,
        amount,
        paymentMethod: method,
        paymentDetails: paymentId,
        deviceHash,
        riskScore,
        status: 'PENDING',
        requestedAt: admin.firestore.FieldValue.serverTimestamp(),
        processedAt: null,
        lastStatusUpdate: admin.firestore.FieldValue.serverTimestamp()
      });

      // Deduct coins from user (atomic)
      transaction.update(userRef, {
        coins: admin.firestore.FieldValue.increment(-amount),
        totalWithdrawn: admin.firestore.FieldValue.increment(amount),
        lastWithdrawalDate: admin.firestore.FieldValue.serverTimestamp(),
        lastRecordedIP: ip,
        lastRecordedDeviceHash: deviceHash
      });

      // Log to fraud_logs collection
      transaction.set(userRef.collection('fraud_logs').doc(), {
        type: 'WITHDRAWAL_REQUEST',
        riskScore,
        amount,
        deviceHash,
        ip,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });

      result = {
        success: true,
        withdrawalId: withdrawalRef.id,
        amountDeducted: amount,
        newBalance: userData.coins - amount,
        status: 'PENDING',
        message: 'Withdrawal request submitted. Processing within 24-48 hours.'
      };
    });

    // 7. Cache response for idempotency
    await ctx.env.KV_IDEMPOTENCY.put(
      idempotencyCacheKey,
      JSON.stringify(result),
      { expirationTtl: 86400 }  // 24 hour TTL
    );

    // 8. Async audit log
    ctx.waitUntil(
      userRef.collection('actions').add({
        type: 'WITHDRAWAL_REQUEST',
        amount: -amount,
        method,
        status: 'PENDING',
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      })
    );

    return successResponse(result, 200);
  } catch (error) {
    console.error(`[Withdrawal Error] ${error.message}`, {
      userId,
      status: error.status
    });

    return handleError(error.message, error.status || 500);
  }
}

/**
 * Handle referral code claim
 * ✅ CRITICAL: Idempotency (24h KV cache) + Rate limiting + Fraud detection
 * 
 * Fraud Scoring:
 * - Account age < 48 hours: +5
 * - Zero user activity: +10
 * - Same IP as referrer: +10
 * - Block if score > 30
 * 
 * @param {Request} request - HTTP request
 * @param {Firestore} db - Firestore instance
 * @param {string} userId - User ID from auth
 * @param {ExecutionContext} ctx - Cloudflare worker context
 * @returns {Promise<Response>} HTTP response
 */
export async function handleReferral(request, db, userId, ctx) {
  try {
    // 1. Parse and validate request body
    const { referralCode, deviceHash, idempotencyKey } = await validateRequest(request, {
      referralCode: 'string',
      deviceHash: 'string',
      idempotencyKey: 'string'
    });

    // 2. Check idempotency cache (prevent double claiming)
    const idempotencyCacheKey = `idempotency:claim-referral:${userId}:${idempotencyKey}`;
    const cached = await ctx.env.KV_IDEMPOTENCY.get(idempotencyCacheKey);
    
    if (cached) {
      console.log('[Referral] Returning cached response (idempotent)');
      return new Response(cached, { status: 200 });
    }

    // 3. Check rate limits (5 per minute per UID, 20 per minute per IP)
    const ip = request.headers.get('CF-Connecting-IP') || 'unknown';
    const rateLimitResult = await checkRateLimits(userId, ip, ctx.env.KV_RATE_COUNTERS, 'claim-referral');
    
    if (rateLimitResult.limited) {
      return handleError(`Rate limit exceeded. Try again in ${rateLimitResult.retryAfter}s`, 429);
    }

    // 4. Validate referral code format (6 characters)
    if (!referralCode || referralCode.length !== 6) {
      return handleError('Invalid referral code format (must be 6 characters)', 400);
    }

    // 5. Cannot use own code
    const userRef = db.collection('users').doc(userId);
    const userSnap = await userRef.get();

    if (!userSnap.exists) {
      return handleError('User not found', 404);
    }

    const userData = userSnap.data();
    if (userData.referralCode === referralCode) {
      return handleError('Cannot use your own referral code', 400);
    }

    // 6. Check if already claimed
    if (userData.referredBy) {
      return handleError('You have already used a referral code', 400);
    }

    // 7. Find referrer by code (single query outside transaction)
    const referrerSnap = await db
      .collection('users')
      .where('referralCode', '==', referralCode)
      .limit(1)
      .get();

    if (referrerSnap.empty) {
      return handleError('Invalid referral code', 404);
    }

    const referrerId = referrerSnap.docs[0].id;
    const referrerRef = db.collection('users').doc(referrerId);
    const referralBonus = REWARDS.REFERRAL_BONUS || 50;

    let result;

    // 8. MULTI-USER ATOMIC TRANSACTION with FRAUD DETECTION
    await db.runTransaction(async (transaction) => {
      // Read both users within transaction
      const claimedSnap = await transaction.get(userRef);
      const referrerSnap = await transaction.get(referrerRef);

      if (!claimedSnap.exists || !referrerSnap.exists) {
        const err = new Error('User not found');
        err.status = 404;
        throw err;
      }

      const claimedData = claimedSnap.data();
      const referrerData = referrerSnap.data();

      // Double-check referredBy is still null (prevents race condition)
      if (claimedData.referredBy) {
        const err = new Error('You have already used a referral code');
        err.status = 400;
        throw err;
      }

      // ✅ FRAUD DETECTION: Calculate risk score for claimer
      let riskScore = 0;
      const createdAt = claimedData.createdAt?.toDate?.() || new Date(0);
      const accountAgeMs = Date.now() - createdAt.getTime();
      const accountAgeHours = accountAgeMs / (1000 * 60 * 60);

      if (accountAgeHours < 48) {
        riskScore += 5;  // Very new account
      }

      if ((claimedData.totalAdsWatched || 0) === 0 && (claimedData.totalGamesWon || 0) === 0) {
        riskScore += 10;  // No activity
      }

      if (referrerData.lastRecordedIP && referrerData.lastRecordedIP === ip) {
        riskScore += 10;  // Same IP as referrer (suspicious)
      }

      // Block if score > 30
      if (riskScore > 30) {
        console.warn(`[Referral Fraud] Blocked user ${userId}: score=${riskScore}`);
        const err = new Error('Referral claim blocked due to security checks.');
        err.status = 403;
        throw err;
      }

      // ATOMIC: Update both users simultaneously
      // Claimer gets bonus
      transaction.update(userRef, {
        coins: admin.firestore.FieldValue.increment(referralBonus),
        referredBy: referralCode,
        referralClaimedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastRecordedIP: ip,
        lastRecordedDeviceHash: deviceHash
      });

      // Referrer gets bonus for recruiting
      transaction.update(referrerRef, {
        coins: admin.firestore.FieldValue.increment(referralBonus),
        totalReferrals: admin.firestore.FieldValue.increment(1),
        lastReferralAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Log to fraud_logs collection
      transaction.set(userRef.collection('fraud_logs').doc(), {
        type: 'REFERRAL_CLAIMED',
        riskScore,
        referrerId,
        deviceHash,
        ip,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });

      result = {
        success: true,
        claimerBonus: referralBonus,
        referrerBonus: referralBonus,
        referrerId,
        newBalance: claimedData.coins + referralBonus,
        message: `Referral claimed! You earned ${referralBonus} coins`
      };
    });

    // 9. Cache response for idempotency
    await ctx.env.KV_IDEMPOTENCY.put(
      idempotencyCacheKey,
      JSON.stringify(result),
      { expirationTtl: 86400 }  // 24 hour TTL
    );

    // 10. Async audit logs
    ctx.waitUntil(
      Promise.all([
        userRef.collection('actions').add({
          type: 'REFERRAL_CLAIMED',
          amount: referralBonus,
          referrerCode: referralCode,
          timestamp: admin.firestore.FieldValue.serverTimestamp()
        }),
        referrerRef.collection('actions').add({
          type: 'REFERRAL_REWARD',
          amount: referralBonus,
          referredUserId: userId,
          timestamp: admin.firestore.FieldValue.serverTimestamp()
        })
      ])
    );

    return successResponse(result, 200);
  } catch (error) {
    console.error(`[Referral Error] ${error.message}`, {
      userId,
      status: error.status
    });

    return handleError(error.message, error.status || 500);
  }
}

/**
 * Check rate limits for immediate endpoints
 * Per-endpoint limits differ:
 * - request-withdrawal: 3/min per UID, 10/min per IP
 * - claim-referral: 5/min per UID, 20/min per IP
 */
async function checkRateLimits(userId, ip, kvBinding, endpoint) {
  const windowMs = 60;  // 60 seconds
  
  // Per-endpoint limits
  const limits = {
    'request-withdrawal': { uid: 3, ip: 10 },
    'claim-referral': { uid: 5, ip: 20 },
  };
  
  const { uid: uidLimit, ip: ipLimit } = limits[endpoint] || { uid: 5, ip: 20 };

  try {
    // Per-UID check
    const uidKey = `rate:${endpoint}:uid:${userId}`;
    let uidCount = parseInt(await kvBinding.get(uidKey) || '0');
    
    if (uidCount >= uidLimit) {
      return { limited: true, retryAfter: windowMs };
    }
    
    await kvBinding.put(uidKey, (uidCount + 1).toString(), { expirationTtl: windowMs });

    // Per-IP check
    const ipKey = `rate:${endpoint}:ip:${ip}`;
    let ipCount = parseInt(await kvBinding.get(ipKey) || '0');
    
    if (ipCount >= ipLimit) {
      return { limited: true, retryAfter: windowMs };
    }
    
    await kvBinding.put(ipKey, (ipCount + 1).toString(), { expirationTtl: windowMs });

    return { limited: false };
  } catch (error) {
    console.error('[Rate Limit Check] Error:', error);
    // On error, allow the request (don't block on KV failure)
    return { limited: false };
  }
}

/**
 * Validate UPI ID format (name@bank)
 */
function isValidUPI(upi) {
  const regex = /^[a-zA-Z0-9.\-_]{3,}@[a-zA-Z]{3,}$/;
  return regex.test(upi);
}

/**
 * Validate bank account (9-18 digits)
 */
function isValidBankAccount(account) {
  const digits = account.replace(/\D/g, '');
  return digits.length >= 9 && digits.length <= 18;
}
