import {
  validateRequest,
  validateTimestamp,
  hasDateChanged,
  handleError,
  successResponse
} from '../utils/validation.js';
import {
  incrementCoins,
  serverTimestamp,
  addAuditLog,
  atomicTransaction
} from '../utils/firebase.js';
import { REWARDS, LIMITS, TIMEOUTS, ACTION_TYPES } from '../utils/constants.js';

/**
 * Handle ad reward claim
 * @param {Request} request - HTTP request
 * @param {Firestore} db - Firestore instance
 * @param {string} userId - User ID from auth
 * @param {ExecutionContext} ctx - Cloudflare worker context
 * @returns {Promise<Response>} HTTP response
 */
export async function handleAdReward(request, db, userId, ctx) {
  try {
    // 1. Parse and validate request body
    const { adUnitId, timestamp } = await validateRequest(request, {
      adUnitId: 'string',
      timestamp: 'number'
    });

    // 2. Validate timestamp (anti-replay attack)
    validateTimestamp(timestamp, TIMEOUTS.REQUEST_AGE_MAX);

    // 3. Validate ad unit ID format
    if (!adUnitId || adUnitId.length < 5) {
      return handleError('Invalid ad unit ID format', 400);
    }

    const reward = REWARDS.AD_WATCH;
    const userRef = db.collection('users').doc(userId);
    let result;

    // 4. ATOMIC TRANSACTION: Read + Validate + Write
    await atomicTransaction(db, async (transaction) => {
      // Read user data within transaction (free, no extra read cost)
      const userSnap = await transaction.get(userRef);

      if (!userSnap.exists) {
        const err = new Error('User not found in database');
        err.status = 404;
        throw err;
      }

      const userData = userSnap.data();

      // Validate user has required fields
      if (userData.coins === undefined) {
        const err = new Error('User data corrupted: missing coins field');
        err.status = 500;
        throw err;
      }

      // Check daily ad limit with lazy reset
      const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
      const lastAdResetDate = userData.lastAdResetDate;
      const lastAdResetDateString = lastAdResetDate
        ? new Date(lastAdResetDate.toDate()).toISOString().split('T')[0]
        : null;

      // Determine if new day (lazy reset)
      const isNewDay = hasDateChanged(lastAdResetDate);
      const watchedToday = isNewDay ? 0 : userData.watchedAdsToday || 0;

      // Validate daily limit
      if (watchedToday >= LIMITS.ADS_PER_DAY) {
        const err = new Error(`Daily ad limit reached (${LIMITS.ADS_PER_DAY}/day)`);
        err.status = 429; // Too Many Requests
        throw err;
      }

      // All validations passed, perform atomic update
      transaction.update(userRef, {
        coins: incrementCoins(reward),
        watchedAdsToday: watchedToday + 1,
        lastAdResetDate: serverTimestamp(),
        totalAdsWatched: incrementCoins(1),
        lastUpdated: serverTimestamp()
      });

      result = {
        success: true,
        reward,
        newBalance: userData.coins + reward,
        adsWatchedToday: watchedToday + 1,
        adUnitId
      };
    });

    // 5. Async audit log (fire-and-forget using ctx.waitUntil)
    ctx.waitUntil(
      addAuditLog(db, userId, ACTION_TYPES.AD_WATCHED, {
        reward,
        adUnitId,
        amount: reward
      })
    );

    return successResponse(result, 200);
  } catch (error) {
    console.error(`[Ad Reward Error] ${error.message}`, {
      userId,
      status: error.status
    });

    return handleError(error.message, error.status || 500);
  }
}
