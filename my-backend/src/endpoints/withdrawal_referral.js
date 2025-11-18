import admin from 'firebase-admin';
import {
  validateRequest,
  handleError,
  successResponse
} from '../utils/validation.js';
import { REWARDS } from '../utils/constants.js';

/**
 * Handle withdrawal request
 * @param {Request} request - HTTP request
 * @param {Firestore} db - Firestore instance
 * @param {string} userId - User ID from auth
 * @param {ExecutionContext} ctx - Cloudflare worker context
 * @returns {Promise<Response>} HTTP response
 */
export async function handleWithdrawal(request, db, userId, ctx) {
  try {
    // 1. Parse and validate request body
    const { amount, method, paymentId } = await validateRequest(request, {
      amount: 'number',
      method: 'string',
      paymentId: 'string'
    });

    // 2. Validate withdrawal amount
    const minWithdrawal = 500;
    if (amount < minWithdrawal) {
      return handleError(`Minimum withdrawal amount is ${minWithdrawal} coins`, 400);
    }

    // 3. Validate method and payment ID
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

    // 4. ATOMIC TRANSACTION: Read + Validate + Write
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

      // Create withdrawal document (atomic)
      const withdrawalRef = db.collection('withdrawals').doc();
      transaction.set(withdrawalRef, {
        userId,
        amount,
        paymentMethod: method,
        paymentDetails: paymentId,
        status: 'PENDING',
        requestedAt: admin.firestore.FieldValue.serverTimestamp(),
        processedAt: null,
        lastStatusUpdate: admin.firestore.FieldValue.serverTimestamp()
      });

      // Deduct coins from user (atomic)
      transaction.update(userRef, {
        coins: admin.firestore.FieldValue.increment(-amount),
        totalWithdrawn: admin.firestore.FieldValue.increment(amount),
        lastWithdrawalDate: admin.firestore.FieldValue.serverTimestamp()
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

    // 5. Async audit log
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
 * @param {Request} request - HTTP request
 * @param {Firestore} db - Firestore instance
 * @param {string} userId - User ID from auth
 * @param {ExecutionContext} ctx - Cloudflare worker context
 * @returns {Promise<Response>} HTTP response
 */
export async function handleReferral(request, db, userId, ctx) {
  try {
    // 1. Parse and validate request body
    const { referralCode } = await validateRequest(request, {
      referralCode: 'string'
    });

    // 2. Validate referral code format (6 characters)
    if (!referralCode || referralCode.length !== 6) {
      return handleError('Invalid referral code format (must be 6 characters)', 400);
    }

    // 3. Cannot use own code
    const userRef = db.collection('users').doc(userId);
    const userSnap = await userRef.get();

    if (!userSnap.exists) {
      return handleError('User not found', 404);
    }

    const userData = userSnap.data();
    if (userData.referralCode === referralCode) {
      return handleError('Cannot use your own referral code', 400);
    }

    // 4. Check if already claimed
    if (userData.referredBy) {
      return handleError('You have already used a referral code', 400);
    }

    // 5. Find referrer by code (single query outside transaction)
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

    // 6. MULTI-USER ATOMIC TRANSACTION
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

      // Double-check referredBy is still null (prevents race condition)
      if (claimedData.referredBy) {
        const err = new Error('You have already used a referral code');
        err.status = 400;
        throw err;
      }

      // ATOMIC: Update both users simultaneously
      // Claimer gets bonus
      transaction.update(userRef, {
        coins: admin.firestore.FieldValue.increment(referralBonus),
        referredBy: referralCode,
        referralClaimedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Referrer gets bonus for recruiting
      transaction.update(referrerRef, {
        coins: admin.firestore.FieldValue.increment(referralBonus),
        totalReferrals: admin.firestore.FieldValue.increment(1),
        lastReferralAt: admin.firestore.FieldValue.serverTimestamp()
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

    // 7. Async audit logs
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
