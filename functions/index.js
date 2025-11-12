const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();

// ============================================================================
// COIN DISTRIBUTION FUNCTIONS
// ============================================================================

/**
 * Safely update user coins with transaction
 * Validates coin amount and prevents negative balances
 */
exports.updateUserCoins = functions.https.onCall(async (data, context) => {
  // Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const { uid, amount, reason } = data;
  const userId = context.auth.uid;

  // Validate ownership
  if (uid !== userId) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Users can only update their own coins'
    );
  }

  // Validate amount
  if (!Number.isInteger(amount) || amount === 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Amount must be a non-zero integer'
    );
  }

  // Validate reason
  const validReasons = [
    'daily_streak',
    'watch_ad',
    'spin_win',
    'game_win',
    'referral',
    'admin_bonus'
  ];
  if (!validReasons.includes(reason)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Invalid reason provided'
    );
  }

  try {
    const result = await db.runTransaction(async (transaction) => {
      const userRef = db.collection('users').doc(uid);
      const userDoc = await transaction.get(userRef);

      if (!userDoc.exists) {
        throw new Error('User document not found');
      }

      const currentCoins = userDoc.data().coins || 0;
      const newCoins = currentCoins + amount;

      if (newCoins < 0) {
        throw new Error('Insufficient coins');
      }

      // Update user coins
      transaction.update(userRef, {
        coins: newCoins,
        lastCoinUpdate: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Log transaction
      transaction.set(db.collection('coinTransactions').doc(), {
        userId,
        amount,
        reason,
        previousBalance: currentCoins,
        newBalance: newCoins,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        status: 'completed',
      });

      return newCoins;
    });

    return { success: true, newBalance: result };
  } catch (error) {
    console.error('Error updating coins:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to update coins: ' + error.message
    );
  }
});

// ============================================================================
// DAILY STREAK FUNCTIONS
// ============================================================================

/**
 * Claim daily streak reward
 * Validates streak progression and prevents duplicate claims
 */
exports.claimDailyStreak = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const userId = context.auth.uid;

  try {
    const result = await db.runTransaction(async (transaction) => {
      const userRef = db.collection('users').doc(userId);
      const userDoc = await transaction.get(userRef);

      if (!userDoc.exists) {
        throw new Error('User document not found');
      }

      const userData = userDoc.data();
      const dailyStreak = userData.dailyStreak || { currentStreak: 0, lastCheckIn: null, checkInDates: [] };
      const today = new Date();
      today.setHours(0, 0, 0, 0);

      // Check if already claimed today
      if (dailyStreak.lastCheckIn) {
        const lastCheckIn = dailyStreak.lastCheckIn.toDate();
        lastCheckIn.setHours(0, 0, 0, 0);
        
        if (lastCheckIn.getTime() === today.getTime()) {
          throw new Error('Already claimed streak today');
        }
      }

      // Calculate new streak
      let newStreak = 1;
      if (dailyStreak.lastCheckIn) {
        const yesterday = new Date(today);
        yesterday.setDate(yesterday.getDate() - 1);
        const lastCheckIn = new Date(dailyStreak.lastCheckIn.toDate());
        lastCheckIn.setHours(0, 0, 0, 0);

        if (lastCheckIn.getTime() === yesterday.getTime()) {
          newStreak = (dailyStreak.currentStreak || 0) + 1;
        }
      }

      // Cap streak at 7
      newStreak = Math.min(newStreak, 7);

      // Calculate reward based on day
      const rewardMap = {
        1: 10, 2: 15, 3: 20, 4: 25, 5: 30, 6: 40, 7: 100
      };
      const reward = rewardMap[newStreak] || 10;

      // Reset if streak > 7
      if (newStreak > 7) {
        newStreak = 1;
      }

      // Update streak and coins
      const newCoins = (userData.coins || 0) + reward;
      transaction.update(userRef, {
        coins: newCoins,
        dailyStreak: {
          currentStreak: newStreak,
          lastCheckIn: admin.firestore.FieldValue.serverTimestamp(),
          checkInDates: admin.firestore.FieldValue.arrayUnion([admin.firestore.FieldValue.serverTimestamp()])
        },
      });

      // Log transaction
      transaction.set(db.collection('coinTransactions').doc(), {
        userId,
        amount: reward,
        reason: 'daily_streak',
        streakDay: newStreak,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        status: 'completed',
      });

      return {
        newStreak,
        reward,
        newBalance: newCoins,
      };
    });

    return { success: true, ...result };
  } catch (error) {
    console.error('Error claiming streak:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to claim streak: ' + error.message
    );
  }
});

// ============================================================================
// REFERRAL FUNCTIONS
// ============================================================================

/**
 * Handle referral signup bonus
 * Awards coins to both referrer and new user
 */
exports.processReferralBonus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const { referralCode, newUserId } = data;
  const userId = context.auth.uid;

  if (!referralCode) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Referral code required'
    );
  }

  try {
    // Find user with this referral code
    const referrerQuery = await db
      .collection('users')
      .where('referralCode', '==', referralCode)
      .limit(1)
      .get();

    if (referrerQuery.empty) {
      throw new Error('Invalid referral code');
    }

    const referrerId = referrerQuery.docs[0].id;

    if (referrerId === userId) {
      throw new Error('Cannot refer yourself');
    }

    const REFERRAL_BONUS = 25;

    const result = await db.runTransaction(async (transaction) => {
      const referrerRef = db.collection('users').doc(referrerId);
      const newUserRef = db.collection('users').doc(userId);

      const referrerDoc = await transaction.get(referrerRef);
      const newUserDoc = await transaction.get(newUserRef);

      if (!referrerDoc.exists || !newUserDoc.exists) {
        throw new Error('User not found');
      }

      // Award referrer
      const referrerCoins = (referrerDoc.data().coins || 0) + REFERRAL_BONUS;
      transaction.update(referrerRef, {
        coins: referrerCoins,
        referrals: admin.firestore.FieldValue.arrayUnion([userId]),
      });

      // Award new user
      const newUserCoins = (newUserDoc.data().coins || 0) + REFERRAL_BONUS;
      transaction.update(newUserRef, {
        coins: newUserCoins,
        referredBy: referrerId,
      });

      // Log both transactions
      transaction.set(db.collection('coinTransactions').doc(), {
        userId: referrerId,
        amount: REFERRAL_BONUS,
        reason: 'referral',
        referredUser: userId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        status: 'completed',
      });

      transaction.set(db.collection('coinTransactions').doc(), {
        userId,
        amount: REFERRAL_BONUS,
        reason: 'referral',
        referredBy: referrerId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        status: 'completed',
      });

      return { referrerCoins, newUserCoins };
    });

    return { success: true, ...result };
  } catch (error) {
    console.error('Error processing referral:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to process referral: ' + error.message
    );
  }
});

// ============================================================================
// WITHDRAWAL FUNCTIONS
// ============================================================================

/**
 * Process withdrawal request
 * Validates amount and deducts coins
 */
exports.requestWithdrawal = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const { amount, method, paymentId } = data;
  const userId = context.auth.uid;
  const MIN_WITHDRAWAL = 100;

  // Validate inputs
  if (!Number.isInteger(amount) || amount < MIN_WITHDRAWAL) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `Minimum withdrawal is ${MIN_WITHDRAWAL} coins`
    );
  }

  const validMethods = ['UPI', 'Bank Transfer', 'PayPal'];
  if (!validMethods.includes(method)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Invalid payment method'
    );
  }

  if (!paymentId || paymentId.trim().length === 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Payment ID is required'
    );
  }

  try {
    const result = await db.runTransaction(async (transaction) => {
      const userRef = db.collection('users').doc(userId);
      const userDoc = await transaction.get(userRef);

      if (!userDoc.exists) {
        throw new Error('User not found');
      }

      const userCoins = userDoc.data().coins || 0;

      if (userCoins < amount) {
        throw new Error('Insufficient coins');
      }

      // Create withdrawal record
      const withdrawalId = db.collection('withdrawals').doc().id;
      const newCoins = userCoins - amount;

      transaction.update(userRef, {
        coins: newCoins,
        lastWithdrawal: admin.firestore.FieldValue.serverTimestamp(),
      });

      transaction.set(db.collection('withdrawals').doc(withdrawalId), {
        userId,
        amount,
        method,
        paymentId,
        status: 'pending',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        completedAt: null,
      });

      // Log transaction
      transaction.set(db.collection('coinTransactions').doc(), {
        userId,
        amount: -amount,
        reason: 'withdrawal',
        withdrawalId,
        method,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        status: 'pending',
      });

      return {
        newBalance: newCoins,
        withdrawalId,
      };
    });

    return { success: true, ...result };
  } catch (error) {
    console.error('Error processing withdrawal:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to process withdrawal: ' + error.message
    );
  }
});

/**
 * Admin function to complete withdrawal (after payment processing)
 */
exports.completeWithdrawal = functions.https.onCall(async (data, context) => {
  // Verify admin claim
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  // Check if user has admin claim
  const userDoc = await admin.auth().getUser(context.auth.uid);
  if (!userDoc.customClaims?.admin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can complete withdrawals'
    );
  }

  const { withdrawalId, transactionId } = data;

  try {
    await db.runTransaction(async (transaction) => {
      const withdrawalRef = db.collection('withdrawals').doc(withdrawalId);
      const withdrawalDoc = await transaction.get(withdrawalRef);

      if (!withdrawalDoc.exists) {
        throw new Error('Withdrawal not found');
      }

      transaction.update(withdrawalRef, {
        status: 'completed',
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        transactionId,
      });
    });

    return { success: true };
  } catch (error) {
    console.error('Error completing withdrawal:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to complete withdrawal: ' + error.message
    );
  }
});

// ============================================================================
// GAME REWARD FUNCTIONS
// ============================================================================

/**
 * Reward user for game win
 * Validates game type and awards coins
 */
exports.recordGameWin = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const { gameType, score, reward } = data;
  const userId = context.auth.uid;

  const validGames = ['tictactoe', 'whack_mole'];
  if (!validGames.includes(gameType)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Invalid game type'
    );
  }

  if (!Number.isInteger(reward) || reward < 0 || reward > 500) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Reward must be between 0 and 500'
    );
  }

  try {
    const result = await db.runTransaction(async (transaction) => {
      const userRef = db.collection('users').doc(userId);
      const userDoc = await transaction.get(userRef);

      if (!userDoc.exists) {
        throw new Error('User not found');
      }

      const userData = userDoc.data();
      const gameStats = userData.gameStats || {};
      const gameData = gameStats[gameType] || { wins: 0, losses: 0, totalRewards: 0 };

      const newCoins = (userData.coins || 0) + reward;
      gameData.wins = (gameData.wins || 0) + 1;
      gameData.totalRewards = (gameData.totalRewards || 0) + reward;

      gameStats[gameType] = gameData;

      transaction.update(userRef, {
        coins: newCoins,
        gameStats,
      });

      // Log transaction
      transaction.set(db.collection('coinTransactions').doc(), {
        userId,
        amount: reward,
        reason: 'game_win',
        gameType,
        score,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        status: 'completed',
      });

      return newCoins;
    });

    return { success: true, newBalance: result };
  } catch (error) {
    console.error('Error recording game win:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to record game win: ' + error.message
    );
  }
});

// ============================================================================
// SCHEDULED FUNCTIONS
// ============================================================================

/**
 * Reset daily limits at midnight (runs daily at 00:00 UTC)
 */
exports.resetDailyLimits = functions.pubsub
  .schedule('0 0 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('Starting daily reset...');

    try {
      const snapshot = await db.collection('users').get();
      const batch = db.batch();

      snapshot.forEach((doc) => {
        batch.update(doc.ref, {
          watchedAdsToday: 0,
          spinsRemaining: 3,
        });
      });

      await batch.commit();
      console.log('Daily reset completed successfully');
      return null;
    } catch (error) {
      console.error('Error resetting daily limits:', error);
      return null;
    }
  });

/**
 * Reset streaks for inactive users (runs daily at 00:30 UTC)
 */
exports.resetInactiveStreaks = functions.pubsub
  .schedule('30 0 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('Checking for inactive streaks...');

    try {
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 2);
      yesterday.setHours(0, 0, 0, 0);

      const snapshot = await db
        .collection('users')
        .where('dailyStreak.lastCheckIn', '<', admin.firestore.Timestamp.fromDate(yesterday))
        .get();

      const batch = db.batch();

      snapshot.forEach((doc) => {
        batch.update(doc.ref, {
          'dailyStreak.currentStreak': 0,
        });
      });

      await batch.commit();
      console.log(`Reset ${snapshot.size} inactive streaks`);
      return null;
    } catch (error) {
      console.error('Error resetting inactive streaks:', error);
      return null;
    }
  });

// ============================================================================
// USER MANAGEMENT FUNCTIONS
// ============================================================================

/**
 * Create user document on auth signup
 */
exports.createUserDocument = functions.auth
  .user()
  .onCreate(async (user) => {
    try {
      const referralCode = generateReferralCode();

      await db.collection('users').doc(user.uid).set({
        uid: user.uid,
        email: user.email,
        displayName: user.displayName || 'Player',
        coins: 0,
        dailyStreak: {
          currentStreak: 0,
          lastCheckIn: null,
          checkInDates: [],
        },
        watchedAdsToday: 0,
        spinsRemaining: 3,
        referralCode,
        referrals: [],
        referredBy: null,
        gameStats: {
          tictactoe: { wins: 0, losses: 0, totalRewards: 0 },
          whack_mole: { wins: 0, losses: 0, totalRewards: 0 },
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastSync: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`User document created for ${user.uid}`);
    } catch (error) {
      console.error('Error creating user document:', error);
    }
  });

/**
 * Clean up on user deletion
 */
exports.deleteUserData = functions.auth
  .user()
  .onDelete(async (user) => {
    try {
      // Delete user document
      await db.collection('users').doc(user.uid).delete();

      // Delete user's transactions
      const transactionsSnapshot = await db
        .collection('coinTransactions')
        .where('userId', '==', user.uid)
        .get();

      const batch = db.batch();
      transactionsSnapshot.forEach((doc) => {
        batch.delete(doc.ref);
      });

      // Delete withdrawals
      const withdrawalsSnapshot = await db
        .collection('withdrawals')
        .where('userId', '==', user.uid)
        .get();

      withdrawalsSnapshot.forEach((doc) => {
        batch.delete(doc.ref);
      });

      await batch.commit();
      console.log(`User data deleted for ${user.uid}`);
    } catch (error) {
      console.error('Error deleting user data:', error);
    }
  });

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Generate a random 8-character referral code
 */
function generateReferralCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code = '';
  for (let i = 0; i < 8; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

// ============================================================================
// ERROR HANDLING
// ============================================================================

/**
 * Log errors to Firestore for monitoring
 */
async function logError(error, context) {
  try {
    await db.collection('errors').add({
      message: error.message,
      stack: error.stack,
      context,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (e) {
    console.error('Failed to log error:', e);
  }
}
