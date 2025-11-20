# EarnPlay: Cost Optimization & Monetization Plan

**Objective**: Support 1,000+ DAU within Firebase Free Tier limits while maximizing AdMob revenue (60% to app, 40% to users).

**Date**: November 18, 2025  
**Version**: 1.0

---

## 1. CURRENT COST ANALYSIS

### 1.1 Current Firestore Usage (Per 1,000 DAU)

| Operation | Reads/Day | Writes/Day | Workers/Day |
|-----------|-----------|-----------|------------|
| **Home Screen Load** | 2,000 | 0 | 0 |
| **Watch Ads (5 ads/user)** | 1,000 | 5,000 | 2,100 |
| **Spin & Win (3 spins/user)** | 2,000 | 3,000 | 0 |
| **Daily Streak** | 1,000 | 2,000 | 0 |
| **Tic-Tac-Toe (5 games batch)** | 1,000 | 2,000 | 0 |
| **Withdrawal (5% of users)** | 500 | 1,500 | 250 |
| **Referral Claim (10% of users)** | 500 | 1,000 | 100 |
| **Profile Load** | 1,000 | 0 | 0 |
| **TOTAL (Daily)** | **9,000** | **14,500** | **2,450** |

### 1.2 Monthly Cost Projection (1,000 DAU × 30 Days)

| Resource | Monthly Operations | Free Tier Limit | Cost |
|----------|-------------------|-----------------|------|
| **Firestore Reads** | 270,000 | 50,000,000 | $0.00 |
| **Firestore Writes** | 435,000 | 50,000,000 | $0.00 |
| **Firestore Deletes** | 0 | 10,000,000 | $0.00 |
| **Storage** | ~2 GB | 1 GB (exceeds) | $0.18/GB excess = $0.18 |
| **Cloudflare Workers** | 73,500 calls | 100,000/day | $0.00 |
| **AdMob Revenue** | ~$300-500 | - | Baseline |
| **TOTAL COST** | - | - | **$0.18/month** |

✅ **Verdict**: Currently sustainable on Firebase Free Tier, but storage will exceed 1 GB at scale.

---

## 2. COST REDUCTION ROADMAP

### 2.1 Optimization Targets

| Category | Current | Target | Savings |
|----------|---------|--------|---------|
| **Firebase Reads** | 9,000/day | 6,000/day | -33% |
| **Firebase Writes** | 14,500/day | 8,500/day | -41% |
| **Worker Calls** | 2,450/day | 1,200/day | -51% |
| **Storage** | On-demand | 500 MB | -50% |

### 2.2 Key Optimization Strategies

#### **Strategy 1: Client-Side Caching**
- **Action**: Cache user data with 5-minute TTL. Skip re-reads if cache fresh.
- **Impact**: -30% reads on profile loads, home screen re-visits
- **Implementation**: Add `lastFetchedAt` to UserData, skip reads if `now - lastFetchedAt < 5 min`

#### **Strategy 2: Batch Game Sessions to Longer Intervals**
- **Current**: Flush games every 10 games or session end
- **New**: Flush every 50 games OR 6 hours OR session end
- **Impact**: -80% writes for heavy game players (50 games → 1 write instead of 5)
- **Trade-off**: User sees coins update delay up to 6 hours (acceptable for offline-first)

#### **Strategy 3: Move Ad Verification to Scheduled Worker Job**
- **Current**: Worker verifies each ad individually (~2,100 calls/day)
- **New**: Queue ad completions locally (Hive), batch verify at 22:00 IST sync window
- **Impact**: -95% worker calls, reduces to ~50/day
- **Trade-off**: Reward delay up to 24 hours (show "Pending verification" UI state)

#### **Strategy 4: Eliminate Referral Real-Time Query**
- **Current**: Worker queries Firebase for referrer by code (~100 calls/day)
- **New**: Pre-compute referral mappings in cache at app launch (one-time read)
- **Impact**: -50% worker calls for referral feature
- **Trade-off**: Referral codes not searchable in real-time (acceptable)

#### **Strategy 5: Lazy-Load Monthly Stats Only on Demand**
- **Current**: Load monthly stats every game session (~1,000 reads/day)
- **New**: Load only when user opens "Game History" or "Stats" screen
- **Impact**: -80% reads on game sessions
- **Trade-off**: Stats unavailable until user explicitly opens stats screen

#### **Strategy 6: Compress & Archive Old User Data**
- **Current**: All user documents stored indefinitely
- **New**: Archive user data >90 days inactive (compress to JSON, move to Cloud Storage)
- **Impact**: -50% Firestore document storage after 90 days
- **Trade-off**: Requires data recovery workflow for reactivated users

---

## 3. NEW FIREBASE ARCHITECTURE

### 3.1 Optimized Data Model

#### **Users Collection** (Primary)
```
/users/{uid}
├── uid: string
├── email: string
├── coins: number (incremented via FieldValue.increment only)
├── createdAt: timestamp
├── referralCode: string (8 chars)
├── referredBy: string (set once, never changed)
├── totalGamesWon: number (total ever)
├── totalAdsWatched: number (total ever)
├── totalReferrals: number (total referrals made)
├── totalCoinsEarned: number (lifetime sum for user analytics)
├── totalCoinsWithdrawn: number (total withdrawn)
├── lastSync: timestamp (when data was last synced from server)
├── dailyStreak: {
│   ├── currentStreak: number
│   ├── lastCheckIn: timestamp
│   ├── checkInDates: array (last 10 dates only, not unlimited)
│   └── longestStreak: number (personal best)
├── daily: {
│   ├── watchedAdsToday: number (resets daily)
│   ├── lastAdResetDate: timestamp
│   ├── spinsRemaining: number (resets daily)
│   ├── lastSpinResetDate: timestamp
│   └── gamesPlayedToday: number (optional, for daily stats)
└── metadata: {
    ├── lastActiveAt: timestamp (for archival decisions)
    ├── deviceId: string (optional, for fraud detection)
    └── appVersion: string
```

#### **Monthly Stats** (Aggregated, created on-demand)
```
/users/{uid}/monthly_stats/{YYYY-MM}
├── month: string (YYYY-MM)
├── gamesPlayed: number
├── gameWins: number
├── coinsEarned: number (from games)
├── adsWatched: number
├── spinsUsed: number
├── streakCheckIns: number
├── withdrawalsRequested: number (count)
├── referralsProcessed: number (count)
├── lastUpdated: timestamp
└── totalPlayTime: number (seconds, optional)
```

#### **Action Audit Trail** (Per-user, compressed)
```
/users/{uid}/actions/{YYYY-MM-DD}
├── date: string (YYYY-MM-DD, one document per day)
├── events: array [
│   {
│     "type": "GAME_WON",
│     "coins": 25,
│     "gameName": "tictactoe",
│     "timestamp": 1700000000000 (milliseconds)
│   },
│   {
│     "type": "AD_WATCHED",
│     "coins": 5,
│     "timestamp": 1700000100000
│   }
│ ]
├── totalCoinsEarned: number (sum for the day)
├── totalActions: number (count of events)
└── lastUpdated: timestamp
```

**Rationale**: One action document per day per user instead of per-action. Reduces writes from 10,000+ to ~500/month per user.

#### **Offline Queue** (Client-side only, no Firestore storage)
```
Hive: local_queue
├── userId: {
│   "actions": [
│     {"type": "GAME_WON", "coins": 50, "timestamp": ...},
│     {"type": "AD_WATCHED", "coins": 5, "timestamp": ...}
│   ],
│   "lastSyncedAt": timestamp,
│   "pendingSync": boolean
}
```

**Rationale**: No Firestore writes for queue. All queued locally, batch synced at 22:00 IST.

---

### 3.2 Optimized Firestore Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ============================================
    // CONSTANTS & HELPER FUNCTIONS
    // ============================================
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isUserOwner(userId) {
      return request.auth.uid == userId;
    }
    
    function isNewDay(lastResetTimestamp) {
      // Check if timestamps are on different calendar days (IST)
      let lastResetDay = int(lastResetTimestamp.toMillis() / 86400000);
      let nowDay = int(request.time.toMillis() / 86400000);
      return nowDay > lastResetDay;
    }
    
    function isValidCoinIncrement(oldCoins, newCoins, allowedAmounts) {
      let difference = newCoins - oldCoins;
      return difference == 0 || difference in allowedAmounts;
    }
    
    // ============================================
    // USERS COLLECTION
    // ============================================
    match /users/{userId} {
      // READ: Only owner can read own document
      allow read: if isUserOwner(userId);
      
      // CREATE: Initialize new user document with all required fields
      allow create: if isUserOwner(userId) && 
                       validateNewUserDocument(request.resource.data);
      
      // UPDATE: Strict field-level validation
      allow update: if isUserOwner(userId) && 
                       validateUserUpdate(resource.data, request.resource.data);
      
      // Helper: Validate new user document
      function validateNewUserDocument(data) {
        return data.size() >= 15 &&
               data.keys().hasAll([
                 'uid', 'email', 'displayName', 'coins',
                 'createdAt', 'referralCode', 'referredBy',
                 'totalGamesWon', 'totalAdsWatched', 'totalReferrals',
                 'totalCoinsEarned', 'totalCoinsWithdrawn',
                 'dailyStreak', 'daily', 'metadata'
               ]) &&
               data.uid is string &&
               data.email is string &&
               data.coins == 0 &&
               data.totalGamesWon == 0 &&
               data.totalAdsWatched == 0 &&
               data.totalCoinsEarned == 0 &&
               data.totalCoinsWithdrawn == 0 &&
               data.dailyStreak is map &&
               data.dailyStreak.currentStreak == 0 &&
               data.daily is map &&
               data.daily.watchedAdsToday == 0 &&
               data.daily.spinsRemaining == 3 &&
               data.referralCode is string &&
               data.referralCode.size() == 8 &&
               (data.referredBy == null || data.referredBy is string) &&
               data.createdAt is timestamp;
      }
      
      // Helper: Validate user updates
      function validateUserUpdate(oldData, newData) {
        // RULE 1: Coins - only specific increments allowed
        let allowedCoinIncrements = [5, 10, 15, 20, 25, 30, 50, 70, 100];
        let allowedCoinDecrements = [-100, -500, -1000, -5000]; // For withdrawals
        let coinDiff = newData.coins - oldData.coins;
        let isValidCoin = coinDiff == 0 || 
                          coinDiff in allowedCoinIncrements ||
                          coinDiff in allowedCoinDecrements;
        
        // RULE 2: watchedAdsToday - increment by 1 or reset to 1 on new day
        let isNewAdDay = isNewDay(oldData.daily.lastAdResetDate);
        let isValidAdsWatch = (newData.daily.watchedAdsToday == oldData.daily.watchedAdsToday) ||
                              (newData.daily.watchedAdsToday == oldData.daily.watchedAdsToday + 1 && 
                               newData.daily.watchedAdsToday <= 10) ||
                              (isNewAdDay && newData.daily.watchedAdsToday == 1);
        
        // RULE 3: spinsRemaining - decrement by 1 or reset to 3 on new day
        let isNewSpinDay = isNewDay(oldData.daily.lastSpinResetDate);
        let isValidSpins = (newData.daily.spinsRemaining == oldData.daily.spinsRemaining) ||
                           (newData.daily.spinsRemaining == oldData.daily.spinsRemaining - 1 && 
                            newData.daily.spinsRemaining >= 0) ||
                           (isNewSpinDay && newData.daily.spinsRemaining == 3);
        
        // RULE 4: referredBy - can only be set ONCE, never changed after
        let isValidReferral = (newData.referredBy == oldData.referredBy) ||
                              (oldData.referredBy == null && newData.referredBy is string && 
                               newData.referredBy.size() == 8);
        
        // RULE 5: Cumulative stats - can only increase (never decrease)
        let isValidStats = newData.totalGamesWon >= oldData.totalGamesWon &&
                           newData.totalAdsWatched >= oldData.totalAdsWatched &&
                           newData.totalReferrals >= oldData.totalReferrals &&
                           newData.totalCoinsEarned >= oldData.totalCoinsEarned &&
                           newData.totalCoinsWithdrawn >= oldData.totalCoinsWithdrawn;
        
        // RULE 6: Immutable fields
        let isImmutable = newData.uid == oldData.uid &&
                          newData.email == oldData.email &&
                          newData.referralCode == oldData.referralCode &&
                          newData.createdAt == oldData.createdAt;
        
        return isValidCoin && isValidAdsWatch && isValidSpins && 
               isValidReferral && isValidStats && isImmutable;
      }
      
      // Subcollection: Monthly Stats
      match /monthly_stats/{monthYear} {
        allow read: if isUserOwner(userId);
        allow create, update: if isUserOwner(userId) && 
                               validateMonthlyStats(request.resource.data);
        allow delete: if false; // Immutable
        
        function validateMonthlyStats(data) {
          return data.size() >= 8 &&
                 data.keys().hasAll([
                   'month', 'gamesPlayed', 'gameWins', 'coinsEarned',
                   'adsWatched', 'spinsUsed', 'lastUpdated'
                 ]) &&
                 data.month is string &&
                 data.gamesPlayed is number &&
                 data.gamesPlayed >= 0 &&
                 data.gameWins is number &&
                 data.gameWins >= 0 &&
                 data.gameWins <= data.gamesPlayed &&
                 data.coinsEarned is number &&
                 data.coinsEarned >= 0;
        }
      }
      
      // Subcollection: Daily Action Audit Trail
      match /actions/{date} {
        allow read: if isUserOwner(userId);
        allow create, update: if isUserOwner(userId) && 
                               validateDailyActions(request.resource.data);
        allow delete: if false; // Immutable
        
        function validateDailyActions(data) {
          return data.size() >= 4 &&
                 data.keys().hasAll(['date', 'events', 'totalCoinsEarned', 'lastUpdated']) &&
                 data.date is string &&
                 data.events is list &&
                 data.events.size() <= 1000 &&
                 data.totalCoinsEarned is number &&
                 data.totalCoinsEarned >= 0;
        }
      }
    }
    
    // ============================================
    // WITHDRAWALS COLLECTION
    // ============================================
    match /withdrawals/{withdrawalId} {
      allow read: if request.auth != null && 
                     (isUserOwner(resource.data.userId) || isAdmin());
      
      allow create: if isAuthenticated() && 
                       isUserOwner(request.resource.data.userId) &&
                       validateWithdrawalCreation(request.resource.data);
      
      // Admin-only: Update withdrawal status
      allow update: if isAdmin() && 
                       validateWithdrawalUpdate(resource.data, request.resource.data);
      
      allow delete: if false; // Immutable
      
      function validateWithdrawalCreation(data) {
        return data.size() >= 7 &&
               data.keys().hasAll([
                 'userId', 'amount', 'paymentMethod', 'paymentDetails',
                 'status', 'requestedAt', 'lastActionTimestamp'
               ]) &&
               data.amount is number &&
               data.amount >= 500 &&
               data.amount <= 100000 &&
               (data.paymentMethod == 'UPI' || data.paymentMethod == 'BANK_TRANSFER') &&
               data.paymentDetails is string &&
               data.paymentDetails.size() > 0 &&
               data.status == 'PENDING' &&
               data.requestedAt is timestamp;
      }
      
      function validateWithdrawalUpdate(oldData, newData) {
        return oldData.status == 'PENDING' &&
               (newData.status == 'APPROVED' || newData.status == 'REJECTED') &&
               newData.processedAt is timestamp &&
               (newData.status == 'REJECTED' ? 
                 (newData.rejectionReason is string) : true) &&
               newData.userId == oldData.userId &&
               newData.amount == oldData.amount;
      }
    }
    
    // ============================================
    // DEFAULT DENY
    // ============================================
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## 4. OPTIMIZED COIN REWARDS STRUCTURE

### 4.1 AdMob Revenue Model

**Assumptions**:
- **India ECPM**: $0.50-1.00 per 1,000 impressions
- **Conservative estimate**: $0.75 ECPM = $0.00075 per ad
- **Revenue split**: 60% app, 40% users
- **User payout**: 40% of $0.00075 = $0.0003 per ad
- **Coin value**: 1 rupee ≈ $0.012 USD
- **Exchange**: 1 coin = 0.003 rupees ≈ $0.000036

**Monthly Revenue (1,000 DAU)**:
- Ad impressions: 1,000 users × 5 ads/day × 30 days = 150,000 impressions
- Total revenue: 150,000 × $0.00075 = $112.50/month
- App revenue (60%): $67.50/month
- User revenue (40%): $45/month to distribute

### 4.2 Optimized Coin Rewards

#### **Watch Ads**
```
Per Ad: 5 coins
Daily Limit: 10 ads/day = 50 coins/day
Monthly Revenue (1k DAU):
  - Impressions: 1k × 10 ads/day × 30 = 300k
  - Revenue: 300k × $0.00075 = $225
  - User payout (40%): $90 = ~30,000 coins total
  - Per user monthly: 30k ÷ 1k = 30 coins from ads
```

**Rationale**: 5 coins/ad = $0.00015 per user. This is 50% of ad revenue, leaving 10% buffer.

#### **Games (Tic-Tac-Toe)**
```
Win: 10 coins
Loss: 0 coins
Streak Bonus (3 consecutive wins): +15 bonus coins (18 total)
Daily Limit: No limit (batched)
Monthly Revenue Impact:
  - Games won per user: ~30-50/month
  - Coins per user: 400-500 coins/month from games
```

**Rationale**: Low barrier to entry. Encourages engagement. Users spend coins on withdrawals, creating monetization loop.

#### **Games (Whack-A-Mole)** ⚠️ **CRITICAL FIX**
```
BEFORE (Broken): Score-based (5-100 coins) - EXPLOITABLE
AFTER (Fixed):
  - Win (score ≥ 50): 20 coins (fixed reward)
  - Participation: 5 coins
  - Monthly limit: 300 coins/user (30 games × 10 coins avg)
```

**Rationale**: Removes exploitability. Fixed rewards reduce user gaming the system.

#### **Daily Streak**
```
Day 1: 10 coins
Day 2: 15 coins
Day 3: 20 coins
Day 4: 25 coins
Day 5: 30 coins
Day 6: 40 coins
Day 7 Bonus: 50 coins (total 190 for week)
Reset: Misses reset streak to 0

Monthly: ~3 weeks × 190 = 570 coins/user
```

**Rationale**: Encourages daily engagement. 7-day cycle = 4 cycles/month = ~2,280 coins total for 1,000 users.

#### **Spin & Win**
```
Rewards Pool: [10, 15, 20, 25, 30, 50 coins]
Average Reward: (10+15+20+25+30+50)/6 = 25 coins
Daily Spins: 3 spins/day = 75 coins/day
Monthly (per user): 75 × 30 = 2,250 coins

With Ad-Double Feature (50% take ad):
  - 1.5 spins/day watched ad = 1.5 × 50 = 75 bonus coins/day
  - Monthly bonus: 2,250 coins
  - Total from spins: 4,500 coins/user/month
```

**Rationale**: Highest coin earner. High ad impression volume (spins × 1.5 ads/user).

#### **Referrals**
```
Referrer Bonus: 100 coins (one-time, when referred user joins)
Referred User Bonus: 50 coins (one-time, on first deposit/game)
Monthly Volume (10% referral rate):
  - 1k users × 10% = 100 successful referrals
  - Costs: 100 × 100 coins (referrer) = 10,000 coins
  - Revenue impact: $0 direct, but drives retention
```

**Rationale**: Acquisition driver. Cost-effective CAC (10,000 coins ÷ 100 referrals = 100 coins/user ≈ $0.003).

### 4.3 Withdrawal Tiers & Monetization

```
Minimum Withdrawal: 500 coins = ₹1.50 (~$0.018)
Exchange Rate: 1 coin = ₹0.003

Tier 1 (500-2,000 coins):
  - ₹1.50 - ₹6
  - Processing time: 2-3 business days
  - Frequency: Every 7 days

Tier 2 (2,001-5,000 coins):
  - ₹6 - ₹15
  - Processing time: 1-2 business days
  - Frequency: Every 3 days

Tier 3 (5,001+ coins):
  - ₹15+
  - Processing time: 24 hours
  - Frequency: Every 24 hours
  - Premium badge in app (engagement booster)

Monthly Withdrawal Volume (1k DAU, 20% withdrawal rate):
  - Withdrawals: 1k × 0.2 = 200 withdrawals/month
  - Average withdrawal: 2,000 coins = ₹6 each
  - Total payout: 200 × ₹6 = ₹1,200 (~$14.50)
  - Processor fee (2.5%): ₹30 (~$0.36)
  - App net: $14.50 - $0.36 = $14.14/month
```

### 4.4 Monthly Coin Distribution (1,000 DAU)

| Source | Coins/User | Total Coins | % of Revenue |
|--------|-----------|------------|-------------|
| **Watch Ads** | 30 | 30,000 | 8% |
| **Games (Tic-Tac-Toe)** | 400 | 400,000 | 12% |
| **Games (Whack-A-Mole)** | 300 | 300,000 | 9% |
| **Daily Streak** | 570 | 570,000 | 17% |
| **Spin & Win** | 2,250 | 2,250,000 | 67% |
| **Referral Bonus** | 10 | 10,000 | 0.3% |
| **TOTAL** | **3,560** | **3,560,000** | **100%** |

**Key Insight**: Spin & Win drives 67% of coins. Highest ad impression rate (spins × 1.5x ads).

---

## 5. BACKEND ARCHITECTURE (Cloudflare Workers)

### 5.1 Optimized Worker Endpoints

#### **Endpoint 1: POST /verify-ad** (BATCHED at 22:00 IST)
```
Current: Real-time verification (2,100 calls/day)
Optimized: Batch verification via offline queue

Request (Client):
{
  "userId": "uid_123",
  "adUnitId": "ca-app-pub-xxx",
  "adEventData": {
    "completionTime": 1700000000000,
    "adNetwork": "admob",
    "rewardAmount": 5
  },
  "idempotencyKey": "uuid_xxxxx"  // Prevents double-claims
}

Backend Logic:
1. Verify idempotencyKey not exists in cache (Redis)
2. Check daily ad limit NOT exceeded (read user doc)
3. Atomic transaction:
   - Update coins FieldValue.increment(5)
   - Increment watchedAdsToday
   - Add to daily action log
   - Store idempotencyKey in cache (24h TTL)
4. Return { success: true, newBalance: 505 }

Cost Optimization:
- Batch 100 ad completions in one worker call
- Call once daily at 22:00 IST instead of per-ad
- Reduces worker calls: 2,100 → 10 per day
- Savings: ~$0.10/month worker costs
```

#### **Endpoint 2: POST /claim-referral** (ON-DEMAND)
```
Current: Query Firestore for referrer by code (~100 calls/day)
Optimized: Pre-cached referral mapping

Request (Client):
{
  "claimerUserId": "uid_123",
  "referralCode": "REF12345"
}

Backend Logic:
1. Look up referralCode in Redis cache (loaded at startup)
2. If NOT in cache:
   a. Query Firestore once: WHERE referralCode == "REF12345"
   b. Update Redis cache
3. Verify referrer exists and hasn't referred claimer before
4. Atomic transaction (multi-user):
   - Update claimer: { referredBy: referrerId, coins += 50 }
   - Update referrer: { totalReferrals += 1, coins += 100 }
   - Add action logs for both users
5. Return { success: true, claimerBonus: 50, referrerBonus: 100 }

Cost Optimization:
- Cache all referral codes in Redis at app startup
- Query Firestore only on first claim (cache miss)
- Subsequent claims use Redis (no Firestore read)
- Reduces Firestore reads: 100 → 5 per day
- Savings: ~$0.02/month
```

#### **Endpoint 3: POST /request-withdrawal** (ON-DEMAND)
```
Current: Direct Firestore write (50 calls/day)
Optimized: Worker-managed transaction + idempotency

Request (Client):
{
  "userId": "uid_123",
  "amount": 1000,
  "method": "UPI",
  "paymentDetails": "supreet@okhdfcbank",
  "idempotencyKey": "uuid_withdrawal_xxxxx"
}

Backend Logic:
1. Check idempotencyKey not exists (prevents duplicate withdrawals)
2. Validate:
   - amount >= 500 && amount <= 100000
   - method in ['UPI', 'BANK_TRANSFER']
   - paymentDetails matches regex
3. Atomic Firestore transaction:
   - Read user: verify coins >= amount
   - Create withdrawal doc: { userId, amount, status: 'PENDING', ... }
   - Update user coins: FieldValue.increment(-amount)
   - Add action log
4. Store idempotencyKey in Redis (7-day TTL)
5. Return { success: true, withdrawalId: 'wd_xxx', newBalance: 500 }

Error Handling:
- Insufficient balance: Return { success: false, code: 'INSUFFICIENT_BALANCE' }
- Invalid amount: Return { success: false, code: 'INVALID_AMOUNT' }
- Cooldown period: Return { success: false, code: 'COOLDOWN', resetAt: timestamp }

Cost Optimization:
- Minimal Firestore reads (one user read)
- Single transaction write
- No external API calls
- Savings: Already optimal
```

#### **Endpoint 4: POST /batch-sync** (SCHEDULED 22:00 IST)
```
Purpose: Batch all offline game actions to Firestore

Request (Client sends via worker):
{
  "userId": "uid_123",
  "actions": [
    { "type": "GAME_WON", "gameName": "tictactoe", "coins": 25, "timestamp": 1700000000 },
    { "type": "GAME_WON", "gameName": "tictactoe", "coins": 25, "timestamp": 1700000100 },
    ...
  ]
}

Backend Logic:
1. Aggregate actions by type
2. Verify total coins <= daily limit (anti-cheat)
3. Atomic Firestore batch:
   - Update user coins FieldValue.increment(totalCoins)
   - Update monthly_stats with aggregated counts
   - Create/update daily action log with all events
4. Return { success: true, actionsProcessed: 50, coinsAwarded: 500 }

Cost Optimization:
- One worker call instead of 50 (per-game calls)
- One Firestore batch (2-3 writes) instead of 50 writes
- Reduces worker: 50 calls → 1 call per user
- Reduces Firestore writes: 50 → 3
- Savings: ~95% on worker, ~94% on writes
```

### 5.2 Worker Cost Breakdown

| Endpoint | Calls/Day | Calls/Month | Worker Cost |
|----------|-----------|-------------|------------|
| /verify-ad (batched) | 10 | 300 | $0.00015 |
| /claim-referral | 5 | 150 | $0.00008 |
| /request-withdrawal | 50 | 1,500 | $0.00075 |
| /batch-sync | 1,000 | 30,000 | $0.015 |
| **TOTAL** | **1,065** | **31,950** | **$0.02** |

**Verdict**: Cloudflare Workers FREE tier: 100,000 requests/day. Usage = 1,065/day = 1% of quota. ✅

---

## 6. RACE CONDITIONS & MITIGATION

### 6.1 Critical Race Conditions

#### **Race Condition 1: Double Coin Claim (Ad Watch)**

**Scenario**:
1. User watches ad, gets reward callback
2. Network is slow, `incrementWatchedAds()` starts executing
3. User impatiently taps "Watch" button again
4. Second `incrementWatchedAds()` call fires simultaneously
5. Both reach Firestore, both succeed → **+10 coins instead of +5**

**Root Cause**: No client-side debounce + no idempotency check

**Mitigation**:
```dart
// In WatchEarnScreen
bool _isProcessingAd = false;

Future<void> _watchAd() async {
  if (_isProcessingAd) return; // Prevent rapid re-taps
  _isProcessingAd = true;
  
  try {
    await userProvider.incrementWatchedAds(
      coinsPerAd,
      idempotencyKey: uuid.v4(), // NEW: Unique key per ad claim
    );
  } finally {
    _isProcessingAd = false;
  }
}
```

**Backend** (Worker: /verify-ad):
```javascript
// Check if this idempotencyKey was already processed
const cached = await REDIS.get(`idempotency:${idempotencyKey}`);
if (cached) {
  return { success: true, newBalance: cached.balance }; // Idempotent response
}

// Process ad
await db.transaction(async (txn) => {
  const user = await txn.get(userId);
  if (user.watchedAdsToday >= 10) throw new Error('Daily limit exceeded');
  
  await txn.update(userId, {
    coins: FieldValue.increment(5),
    watchedAdsToday: FieldValue.increment(1),
  });
});

// Cache result for 24 hours (prevent re-processing)
await REDIS.set(`idempotency:${idempotencyKey}`, {
  balance: updatedBalance,
  timestamp: Date.now(),
}, { EX: 86400 });

return { success: true, newBalance };
```

---

#### **Race Condition 2: Lazy Reset During Simultaneous Requests**

**Scenario**:
1. At 12:00 AM, user tries to watch 2 ads simultaneously
2. Both requests check `isNewDay` → true
3. Both fire lazy reset: `watchedAdsToday = 1`
4. Both succeed in separate transactions → **watchedAdsToday = 1 (correct) but logged twice**
5. User's daily counter looks inconsistent in logs

**Root Cause**: No atomic check-and-reset

**Mitigation**:
```dart
// In UserProvider
Future<void> resetDailyLimitIfNewDay() async {
  final now = DateTime.now();
  final lastReset = userData?.daily.lastAdResetDate ?? now;
  
  // Client-side check
  final isNewDay = now.day != lastReset.day || 
                   now.month != lastReset.month || 
                   now.year != lastReset.year;
  
  if (!isNewDay) return; // No reset needed
  
  // Atomic reset via Firestore transaction
  final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
  
  await FirebaseFirestore.instance.runTransaction((transaction) async {
    final userSnap = await transaction.get(userRef);
    final lastResetDate = userSnap['daily']['lastAdResetDate'].toDate();
    
    // Double-check in transaction (prevent TOCTOU)
    final isTrulyNewDay = now.day != lastResetDate.day ||
                          now.month != lastResetDate.month ||
                          now.year != lastResetDate.year;
    
    if (isTrulyNewDay) {
      transaction.update(userRef, {
        'daily.watchedAdsToday': 1,
        'daily.lastAdResetDate': FieldValue.serverTimestamp(),
      });
    }
  });
}
```

**Firestore Rules** (enforce atomicity):
```javascript
// In validateUserUpdate, use transaction to ensure reset happens only once
function validateAdReset(oldData, newData) {
  let isNewDay = request.time.toMillis() / 86400000 > 
                 oldData.daily.lastAdResetDate.toMillis() / 86400000;
  
  // Only allow reset if truly new day AND not already reset today
  return isNewDay && 
         newData.daily.watchedAdsToday <= 1 &&
         newData.daily.lastAdResetDate.toMillis() >= 
         oldData.daily.lastAdResetDate.toMillis();
}
```

---

#### **Race Condition 3: Withdrawal Duplicate Request**

**Scenario**:
1. User fills withdrawal form: 1000 coins, UPI
2. User taps "Submit" → loading spinner shows
3. Network is flaky, request hangs for 5 seconds
4. User thinks button didn't register, taps again
5. Two withdrawal requests created in Firestore
6. Both deduct 1000 coins → **user balance goes -1000 (or pending withdrawals totaling 2000)**

**Root Cause**: No client-side debounce + no idempotency in backend

**Mitigation**:
```dart
// In WithdrawalScreen
Future<void> _submitWithdrawal() async {
  if (_isProcessing) {
    SnackbarHelper.showWarning(context, 'Request already in progress');
    return;
  }
  
  setState(() => _isProcessing = true);
  
  try {
    final idempotencyKey = Uuid().v4(); // NEW: Unique per request
    
    await userProvider.requestWithdrawal(
      amount: int.parse(_amountController.text),
      method: _selectedMethod,
      paymentDetails: _upiController.text,
      idempotencyKey: idempotencyKey, // Pass to provider
    );
    
    if (mounted) {
      _amountController.clear();
      SnackbarHelper.showSuccess(context, 'Withdrawal request submitted');
    }
  } catch (e) {
    if (mounted) {
      if (e.code == 'ALREADY_PROCESSING') {
        SnackbarHelper.showWarning(context, 'Request already in progress');
      } else {
        SnackbarHelper.showError(context, e.message);
      }
    }
  } finally {
    if (mounted) setState(() => _isProcessing = false);
  }
}
```

**Backend** (Idempotency):
```javascript
// POST /request-withdrawal
const cachedResult = await REDIS.get(`withdrawal:${idempotencyKey}`);
if (cachedResult) {
  // Return cached result (idempotent)
  return { success: true, withdrawalId: cachedResult.id };
}

// Process withdrawal
const withdrawalId = await FirebaseFirestore.instance
  .collection('withdrawals')
  .add({
    userId,
    amount,
    status: 'PENDING',
    requestedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

// Update user coins atomically
await db.collection('users').doc(userId).update({
  coins: admin.firestore.FieldValue.increment(-amount),
});

// Cache result
await REDIS.set(`withdrawal:${idempotencyKey}`, {
  id: withdrawalId,
  amount,
}, { EX: 3600 }); // Cache for 1 hour

return { success: true, withdrawalId };
```

---

#### **Race Condition 4: Referral Code Applied Twice**

**Scenario**:
1. User gets referral code "REF12345" from friend
2. User opens referral screen, enters code, taps "Claim"
3. Request goes to backend, but user also taps Claim again (double-tap)
4. Both requests hit worker simultaneously
5. Both check `referredBy == null` → true
6. Both claim: **User gets +50 coins twice, referrer gets +100 twice (4x total)**

**Root Cause**: Firestore security rule allows `referredBy` to be set multiple times if null, but two concurrent requests both see null

**Mitigation**:

**Firestore Rule** (prevent concurrent sets):
```javascript
// In validateUserUpdate
function validateReferralUpdate(oldData, newData) {
  // STRICT: referredBy can ONLY transition from null → userId ONCE
  // Multiple concurrent updates both see null, but only first should succeed
  
  let referralChanged = newData.referredBy != oldData.referredBy;
  
  if (referralChanged) {
    // Once set, NEVER change
    if (oldData.referredBy != null) return false;
    
    // New referral must be valid format
    if (newData.referredBy !is string || newData.referredBy.size() < 8) return false;
    
    // Timestamp must be recent (prevent replay attacks)
    if (request.time.toMillis() - newData.referralClaimedAt.toMillis() > 5000) return false;
  }
  
  return true;
}
```

**Backend** (Use transaction with write conflict):
```javascript
// POST /claim-referral
const idempotencyKey = request.body.idempotencyKey;
const cached = await REDIS.get(`referral_claim:${idempotencyKey}`);
if (cached) return { success: true, ...cached }; // Idempotent

await db.transaction(async (txn) => {
  const claimer = await txn.get(userRef);
  
  // Verify referredBy is still null (catch race)
  if (claimer.referredBy != null) {
    throw new Error('ALREADY_CLAIMED');
  }
  
  // Atomic set
  txn.update(userRef, {
    referredBy: referrerId,
    coins: FieldValue.increment(50),
    referralClaimedAt: FieldValue.serverTimestamp(),
  });
  
  // Update referrer
  const referrerRef = db.collection('users').doc(referrerId);
  txn.update(referrerRef, {
    totalReferrals: FieldValue.increment(1),
    coins: FieldValue.increment(100),
  });
});

// Cache for 24 hours
await REDIS.set(`referral_claim:${idempotencyKey}`, {
  claimerBonus: 50,
  referrerBonus: 100,
}, { EX: 86400 });

return { success: true, claimerBonus: 50, referrerBonus: 100 };
```

---

#### **Race Condition 5: Spin Claim During Daily Reset**

**Scenario**:
1. User spins at 11:59:59 PM, gets 50 coins
2. Modal appears with "Claim" and "Watch Ad for Double" buttons
3. Clock ticks to 12:00:00 AM
4. Lazy reset fires: `spinsRemaining` = 3
5. User clicks "Claim" while reset is in flight
6. Both transactions execute:
   - Claim: `coins += 50, spinsRemaining -= 1`
   - Reset: `spinsRemaining = 3`
7. **Result**: User gets +50 coins (correct) but spinsRemaining = 3 instead of 2 (should have 2 after claiming one)**

**Root Cause**: Reset and claim transactions not sequenced

**Mitigation**:
```dart
// In SpinWinScreen
Future<void> _claimSpinReward(int amount, bool watchedAd) async {
  try {
    // CRITICAL: Do lazy reset BEFORE claiming to establish consistent state
    await context.read<UserProvider>().resetSpinsIfNewDay();
    
    // Now safe to claim
    await context.read<UserProvider>().claimSpinReward(
      amount,
      watchedAd: watchedAd,
      idempotencyKey: Uuid().v4(),
    );
    
    if (mounted) {
      SnackbarHelper.showSuccess(context, '✨ $amount coins claimed!');
    }
  } catch (e) {
    if (mounted) SnackbarHelper.showError(context, 'Error: $e');
  }
}
```

**Backend** (Force reset before claim):
```javascript
// POST /claim-spin-reward
await db.transaction(async (txn) => {
  const user = await txn.get(userRef);
  
  // Step 1: Check if day changed, reset if needed
  const lastResetDay = Math.floor(user.daily.lastSpinResetDate.toMillis() / 86400000);
  const nowDay = Math.floor(Date.now() / 86400000);
  
  if (nowDay > lastResetDay) {
    // Day changed, reset spins first
    txn.update(userRef, {
      'daily.spinsRemaining': 3,
      'daily.lastSpinResetDate': admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  
  // Step 2: Re-read after reset to get accurate count
  const updatedUser = await txn.get(userRef);
  if (updatedUser.daily.spinsRemaining <= 0) {
    throw new Error('NO_SPINS_REMAINING');
  }
  
  // Step 3: Claim spin
  txn.update(userRef, {
    coins: FieldValue.increment(amount),
    'daily.spinsRemaining': FieldValue.increment(-1),
    lastUpdated: FieldValue.serverTimestamp(),
  });
});

return { success: true, newBalance, spinsRemaining };
```

---

### 6.2 Race Condition Summary Table

| Race Condition | Screens | Severity | Mitigation |
|----------------|---------|----------|-----------|
| **Double Coin Claim** | Watch Ads, Games | HIGH | Client debounce + idempotency key |
| **Lazy Reset Race** | Ads, Spins, Streak | HIGH | Atomic transaction with double-check |
| **Withdrawal Duplicate** | Withdrawal | CRITICAL | Client disable + backend idempotency |
| **Referral Double-Claim** | Referral | HIGH | Firestore rule + backend transaction |
| **Spin Reset During Claim** | Spin & Win | HIGH | Force reset before claim in transaction |
| **Monthly Stats Missing Fields** | Game Sessions | MEDIUM | Validate ALL fields in batch insert |
| **Offline Sync Retry Loss** | All | HIGH | Retry timer, hourly fallback |
| **Ad Reward Callback Before Update** | Watch Ads | MEDIUM | Verify coins post-update before UI |

---

## 7. IMPLEMENTATION ROADMAP

### Phase 1: Foundation (Week 1-2)
- [ ] Update Firestore rules with all validations
- [ ] Implement idempotency keys in all operations
- [ ] Add client-side debounce to all action buttons
- [ ] Deploy optimized Worker endpoints

### Phase 2: Optimization (Week 3-4)
- [ ] Implement client-side caching (5-min TTL)
- [ ] Move ad verification to batch/scheduled sync
- [ ] Migrate game history to lazy-load
- [ ] Archive user data >90 days inactive

### Phase 3: Monitoring (Week 5-6)
- [ ] Add Firestore cost tracking dashboard
- [ ] Monitor Worker invocation costs
- [ ] Track race condition incidents
- [ ] Set up alerts for anomalies

### Phase 4: Scale (Week 7+)
- [ ] Test with 5,000 DAU
- [ ] Optimize based on real usage patterns
- [ ] Plan upgrade to Blaze if needed

---

## 8. SUCCESS METRICS

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| **Firestore Reads/Day** | 6,000 | 9,000 | -33% |
| **Firestore Writes/Day** | 8,500 | 14,500 | -41% |
| **Worker Calls/Day** | 1,200 | 2,450 | -51% |
| **Monthly Cost** | $0.50 | $0.18 | ✅ Free Tier |
| **DAU Supported** | 5,000+ | 1,000 | 5x capacity |
| **User Retention** | 40% | TBD | Baseline |
| **AdMob Revenue** | $500+/month | TBD | Baseline |

---

## 9. APPENDIX: Coin Economics Reference

### Coin Value Mapping
```
1 coin = ₹0.003 = $0.000036 USD

Earning Rates:
- Watch Ad (5 coins): $0.00018 / 3 min video = $0.06/hour
- Game Win (10 coins): $0.00036 / 5 min game = $0.0432/hour
- Daily Streak (10-50 coins): $0.00036-0.0018 / 2 min = $10.80-54/hour (burst)
- Spin & Win (25 coins avg): $0.0009 / 1 min spin = $0.54/hour

Monthly Active User Earnings:
- Low engagement (ads only): 30 coins = $0.0011
- Medium engagement (ads + games): 800 coins = $0.029
- High engagement (all features): 3,560 coins = $0.128
```

### MonthlyRevenue Model (1,000 DAU)

```
Ad Revenue (150k impressions @ $0.75 ECPM):
  Gross: $112.50
  App Share (60%): $67.50
  User Share (40%): $45
  Cost of coins to users: 30,000 coins ≈ $1.08
  Net to app: $66.42

Withdrawal Fees (200 withdrawals @ 2.5%):
  Gross withdrawal volume: ₹1,200 (~$14.50)
  Fee revenue (2.5%): ₹30 (~$0.36)

Total Monthly Revenue:
  AdMob: $67.50
  Withdrawal fees: $0.36
  TOTAL: $67.86
```

---

**Document Version**: 1.0  
**Last Updated**: November 18, 2025  
**Status**: Plan (Not Implemented)
