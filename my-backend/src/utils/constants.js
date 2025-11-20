/**
 * All reward amounts in coins
 */
export const REWARDS = {
  AD_WATCH: 5,
  GAME_WIN: 10,
  GAME_LOSS: 2,
  SPIN_WIN: 25,
  DAILY_STREAK_BONUS: 15,
  REFERRAL_CLAIMED: 50,
  REFERRAL_BONUS: 30
};

/**
 * Daily limits per user
 */
export const LIMITS = {
  ADS_PER_DAY: 10,
  GAMES_PER_HOUR: 20,
  SPINS_PER_DAY: 3,
  WITHDRAWAL_MIN: 500,
  WITHDRAWAL_MAX: 100000
};

/**
 * Request validation timeouts
 */
export const TIMEOUTS = {
  REQUEST_AGE_MAX: 60000, // 1 minute in milliseconds
  AD_CLICK_VALIDITY: 30000 // 30 seconds
};

/**
 * Error messages (user-friendly)
 */
export const ERROR_MESSAGES = {
  STALE_REQUEST: 'Request is too old. Please try again.',
  DAILY_LIMIT_REACHED: 'Daily limit reached. Come back tomorrow!',
  USER_NOT_FOUND: 'User not found in database.',
  INSUFFICIENT_COINS: 'Not enough coins for this action.',
  INVALID_AMOUNT: 'Invalid amount specified.',
  DUPLICATE_REQUEST: 'This request is being processed. Please wait.'
};

/**
 * Firestore collection names
 */
export const COLLECTIONS = {
  USERS: 'users',
  ACTIONS: 'actions',
  WITHDRAWALS: 'withdrawals',
  MONTHLY_STATS: 'monthlyStats',
  LEADERBOARD: 'leaderboard'
};

/**
 * Action types for audit logging
 */
export const ACTION_TYPES = {
  AD_WATCHED: 'AD_WATCHED',
  GAME_PLAYED: 'GAME_PLAYED',
  SPIN_USED: 'SPIN_USED',
  STREAK_CLAIMED: 'STREAK_CLAIMED',
  WITHDRAWAL_REQUESTED: 'WITHDRAWAL_REQUESTED',
  REFERRAL_CLAIMED: 'REFERRAL_CLAIMED'
};
