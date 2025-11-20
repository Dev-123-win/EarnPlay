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
    // Expected body: { adUnitId: string, timestamp: number, challengeId: string }
    const { adUnitId, timestamp, challengeId, idempotencyKey } = await validateRequest(request, {
      adUnitId: 'string',
      timestamp: 'number',
      challengeId: 'string'
    });

    // Anti-replay: timestamp must be recent
    validateTimestamp(timestamp, TIMEOUTS.REQUEST_AGE_MAX);

    // Validate ad unit ID format
    if (!adUnitId || adUnitId.length < 5) {
      return handleError('Invalid ad unit ID format', 400);
    }

    // Validate challenge in KV (single-use, short TTL)
    const challengeKey = `ad-challenge:${userId}:${challengeId}`;
    const raw = await ctx.env.KV_AD_CHALLENGES.get(challengeKey);

    if (!raw) {
      return handleError('Invalid or expired ad challenge', 400);
    }

    let challenge;
    try {
      challenge = JSON.parse(raw);
    } catch (e) {
      // Corrupted challenge
      await ctx.env.KV_AD_CHALLENGES.delete(challengeKey);
      return handleError('Invalid ad challenge data', 400);
    }

    // Ensure challenge matches adUnit and user
    if (challenge.adUnitId !== adUnitId || challenge.userId !== userId) {
      await ctx.env.KV_AD_CHALLENGES.delete(challengeKey);
      return handleError('Ad challenge mismatch', 400);
    }

    // Single-use: delete challenge to prevent replay
    await ctx.env.KV_AD_CHALLENGES.delete(challengeKey);

    const reward = REWARDS.AD_WATCH;
    const userRef = db.collection('users').doc(userId);
    let result;

    // ATOMIC: validate limits and award reward
    await atomicTransaction(db, async (transaction) => {
      const userSnap = await transaction.get(userRef);
      if (!userSnap.exists) {
        const err = new Error('User not found in database');
        err.status = 404;
        throw err;
      }

      const userData = userSnap.data();
      if (userData.coins === undefined) {
        const err = new Error('User data corrupted: missing coins field');
        err.status = 500;
        throw err;
      }

      const isNewDay = hasDateChanged(userData.lastAdResetDate);
      const watchedToday = isNewDay ? 0 : (userData.watchedAdsToday || 0);

      if (watchedToday >= LIMITS.ADS_PER_DAY) {
        const err = new Error(`Daily ad limit reached (${LIMITS.ADS_PER_DAY}/day)`);
        err.status = 429;
        throw err;
      }

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
        newBalance: (userData.coins || 0) + reward,
        adsWatchedToday: watchedToday + 1,
        adUnitId
      };
    });

    // Async audit log
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
