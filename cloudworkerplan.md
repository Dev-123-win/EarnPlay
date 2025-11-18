# ✅ OPTIMIZED CLOUD WORKER PLAN (Firebase Reads/Writes Optimized)

## 🎯 ARCHITECTURE (The Right Way)

```
┌─────────────────────────────────────────────────────────┐
│  Flutter App                                            │
│  • Firebase Auth SDK (handles login/tokens)            │
│  • Firestore SDK (reads user data directly)            │
│  • UI State Management (Provider)                      │
└────────────────┬────────────────────────────────────────┘
                 │
                 │ HTTP Requests (with Firebase ID Token)
                 ▼
┌─────────────────────────────────────────────────────────┐
│  Cloudflare Worker (Logic Only)                         │
│  • Validates Firebase token                             │
│  • Runs business logic                                  │
│  • **Batch Writes** to Firestore via Admin SDK         │
│  • **Transaction Support** for atomic operations       │
│  • NO storage, NO sessions, NO caching                  │
└────────────────┬────────────────────────────────────────┘
                 │
                 │ Firebase Admin SDK (Optimized)
                 ▼
┌─────────────────────────────────────────────────────────┐
│  Firebase/Firestore                                     │
│  • Authentication (users, tokens)                       │
│  • Database (all app data)                              │
│  • Security Rules (read permissions)                    │
│  • **Single Atomic Transaction** per endpoint           │
└─────────────────────────────────────────────────────────┘
```

**Key Insight**: Workers = Stateless Write Logic. Firestore = Atomic Transactions (not individual writes). Firebase = Stateful Storage.

## 🔥 WHAT WORKERS DO (6 Endpoints Only) - OPTIMIZED FOR FIRESTORE

| Endpoint | Purpose | Reads | Writes | Why Worker? | Optimization |
|----------|---------|-------|--------|-------------|--------------|
| POST /verify-ad | Validate ad watch, add coins | 1 | 1 (batched) | Prevent fraud, rate limiting | Single transaction |
| POST /verify-game | Validate game result, add coins | 1 | 1 (batched) | Prevent score hacking | Atomic update |
| POST /spin-wheel | Server RNG, add coins | 1 | 1 (batched) | Prevent RNG manipulation | Transaction-based |
| POST /claim-streak | Validate daily streak, add coins | 1 | 1 (batched) | Prevent timezone exploits | Atomic increment |
| POST /request-withdrawal | Validate balance, create request | 1 | 2 (atomic) | Deduct coins + record atomically | Transaction (prevent double-spend) |
| POST /claim-referral | Validate code, bonus both users | 2 | 2 (atomic) | Prevent multi-account fraud | Transaction (both users update) |

**Total**: 6 endpoints. Firebase Reads: 9 total | Firebase Writes: 8 total (all batched/transactional)

## 🚫 WHAT WORKERS DON'T DO - FIRESTORE OPTIMIZATION RULES

### ❌ NO Individual Writes (Use Transactions)

```javascript
// ❌ WRONG: Multiple separate writes = multiple costs
await userRef.update({'coins': admin.firestore.FieldValue.increment(10)});
await userRef.update({'watchedAdsToday': admin.firestore.FieldValue.increment(1)});
await userRef.update({'lastAdResetDate': admin.firestore.FieldValue.serverTimestamp()});
// Cost: 3 writes = $0.000018 per user

// ✅ CORRECT: Single atomic transaction = 1 write cost
await firestore.runTransaction(async (transaction) => {
  transaction.update(userRef, {
    'coins': admin.firestore.FieldValue.increment(10),
    'watchedAdsToday': admin.firestore.FieldValue.increment(1),
    'lastAdResetDate': admin.firestore.FieldValue.serverTimestamp()
  });
});
// Cost: 1 write = $0.000006 per user (66% savings!)
```

**Why**: Transactions batch multiple updates into ONE Firestore write. For 1,000 users watching ads daily:
- Individual writes: 1,000 × 3 = 3,000 writes = $0.018
- Transaction: 1,000 × 1 = 1,000 writes = $0.006 (67% cost reduction)

### ❌ NO Separate Reads for Validation (Batch in Transaction)

```javascript
// ❌ WRONG: Read first, then write (2 operations)
const userSnap = await userRef.get(); // Read #1
const userData = userSnap.data();
if (userData.coins < 100) throw new Error('Insufficient coins');

// If validation passed, write
await userRef.update({'coins': admin.firestore.FieldValue.increment(100)}); // Write #1
// Cost: 1 read + 1 write = $0.000012

// ✅ CORRECT: Read + Write in single transaction
await firestore.runTransaction(async (transaction) => {
  const userSnap = await transaction.get(userRef); // Read inside transaction (free)
  const userData = userSnap.data();
  
  if (userData.coins < 100) throw new Error('Insufficient coins');
  
  transaction.update(userRef, {
    'coins': admin.firestore.FieldValue.increment(100) // Write inside transaction
  });
}); // Cost: 1 write = $0.000006 (50% savings!)
```

### ❌ NO KV Storage (Firebase is Your Cache)

```javascript
// ❌ WRONG
const cached = await KV.get(`user:${uid}`);
if (!cached) {
  const fresh = await firestore.collection('users').doc(uid).get();
  await KV.put(`user:${uid}`, JSON.stringify(fresh.data()), {expirationTtl: 3600});
}
// Problem: Firestore updates don't sync to KV. Data becomes stale.

// ✅ CORRECT: Read directly from Firestore (free within limits)
const userData = await firestore.collection('users').doc(uid).get();
// Firestore reads are FREE (50K/day included). No KV needed.
```

**Why**: Firestore includes 50K free reads per day. At 1,000 DAU with 6 reads per user = 6,000 reads. Stays within free tier. No KV sync headaches.

### ❌ NO Audit Logs in Same Request (Fire-and-Forget)

```javascript
// ❌ WRONG: Audit log blocks the response
await userRef.update({'coins': admin.firestore.FieldValue.increment(10)});
await userRef.collection('actions').add({ // Blocks response
  type: 'AD_WATCHED',
  amount: 10,
  timestamp: admin.firestore.FieldValue.serverTimestamp()
});
// User waits for both operations. Slow response.

// ✅ CORRECT: Return immediately, log async
const updatePromise = firestore.runTransaction(async (transaction) => {
  transaction.update(userRef, {
    'coins': admin.firestore.FieldValue.increment(10)
  });
});

// Return response immediately
const response = new Response(JSON.stringify({success: true, reward: 10}));

// Log audit trail in background (fire-and-forget)
ctx.waitUntil(
  updatePromise.then(() => {
    return userRef.collection('actions').add({
      type: 'AD_WATCHED',
      amount: 10,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
  })
);

return response;
```

**Why**: `ctx.waitUntil()` keeps the Worker alive to complete logging without blocking the user's response.


## ✅ WHEN TO USE KV (Very Limited Cases)

### 1. Distributed Locks (Prevent Race Conditions)

```javascript
// Prevent duplicate ad claims if user spams button
const lockKey = `lock:ad:${uid}`;
const locked = await KV.get(lockKey);
if (locked) throw new Error('Request in progress');

await KV.put(lockKey, '1', {expirationTtl: 5}); // 5 sec lock

try {
  // ... process ad reward
} finally {
  await KV.delete(lockKey);
}
```

**Usage**: ~6 operations per worker request (get + put + delete × 2 endpoints)  
**Daily for 1K users**: 6 ops × 30 requests/user/day × 1K users = 180K KV ops  
**Free tier**: 100K reads + 1K writes = BARELY FITS (need paid plan at scale)

### 2. IP-Based Rate Limiting (Anti-Bot Protection)

```javascript
// Prevent bot farms hitting your API
const ip = request.headers.get('CF-Connecting-IP');
const ipKey = `ratelimit:${ip}`;
const requests = (await KV.get(ipKey)) || 0;

if (requests > 100) throw new Error('Rate limit exceeded');

await KV.put(ipKey, requests + 1, {expirationTtl: 60}); // 1-min window
```

**Usage**: ~2 operations per request (get + put)  
**Daily for 10K requests**: 20K KV ops  
**Verdict**: Fits within free tier

### 3. Request Deduplication (Prevent Double Submissions)

```javascript
// Prevent double-processing if user retries request
const requestId = request.headers.get('X-Request-ID');
const dedupeKey = `dedup:${uid}:${requestId}`;
const cached = await KV.get(dedupeKey);

if (cached) return new Response(cached); // Return cached result immediately

const result = await processRequest();

// Cache result for 5 minutes
await KV.put(dedupeKey, JSON.stringify(result), {expirationTtl: 300});

return new Response(JSON.stringify(result));
```

**Usage**: ~2 operations per request (get + put)  
**Verdict**: Optional (Firestore transactions can handle this too)


---

## 🏗️ OPTIMIZED WORKER STRUCTURE

### File Structure
```
my-backend/
├── src/
│   ├── index.js                    # Router (120 lines)
│   ├── auth.js                     # Firebase token verification (60 lines)
│   ├── utils/
│   │   ├── firebase.js             # Admin SDK setup + transaction helpers (80 lines)
│   │   ├── validation.js           # Common validation logic (100 lines)
│   │   └── constants.js            # Rewards, limits, config (40 lines)
│   ├── endpoints/
│   │   ├── ad.js                   # Ad verification (optimized) (100 lines)
│   │   ├── game.js                 # Game validation (optimized) (140 lines)
│   │   ├── spin.js                 # RNG logic (optimized) (80 lines)
│   │   ├── streak.js               # Streak validation (optimized) (90 lines)
│   │   ├── withdrawal.js           # Withdrawal + atomic deduction (110 lines)
│   │   └── referral.js             # Referral + dual-user transaction (120 lines)
│   └── middleware/
│       ├── errorHandler.js         # Centralized error handling (60 lines)
│       └── logger.js               # Request logging (40 lines)
├── wrangler.toml                   # Cloudflare config
├── package.json
└── .env.example
Total Code: ~1,040 lines (more robust than original 730)
```

---

## 📝 OPTIMIZED ENDPOINT: Ad Verification (with Transaction)

### `src/endpoints/ad.js` - Single Transaction Pattern

```javascript
import admin from 'firebase-admin';
import { validateRequest, handleError } from '../utils/validation.js';
import { REWARDS, LIMITS } from '../utils/constants.js';

export async function handleAdReward(request, db, userId, ctx) {
  try {
    // 1. Parse & validate request
    const { adUnitId, timestamp } = await validateRequest(request, {
      adUnitId: 'string',
      timestamp: 'number'
    });

    // 2. Basic fraud detection (timestamp check)
    const now = Date.now();
    if (Math.abs(now - timestamp) > 60000) { // Request older than 1 min
      return handleError('Stale request', 400);
    }

    // 3. SINGLE TRANSACTION: Read validation + Write reward atomically
    const userRef = db.collection('users').doc(userId);
    const reward = REWARDS.AD_WATCH; // 5 coins

    let result;
    await db.runTransaction(async (transaction) => {
      // Read user data within transaction (free, no extra read cost)
      const userSnap = await transaction.get(userRef);
      
      if (!userSnap.exists) {
        throw new Error('User not found', {status: 404});
      }

      const userData = userSnap.data();
      
      // Validate daily ad limit (read inside transaction)
      const today = new Date().toISOString().split('T')[0];
      const lastAdDate = userData.lastAdResetDate?.toDate().toISOString().split('T')[0];
      
      const watchedToday = (today === lastAdDate) ? userData.watchedAdsToday : 0;
      
      if (watchedToday >= LIMITS.ADS_PER_DAY) {
        throw new Error('Daily ad limit reached', {status: 429});
      }

      // Write: Update user document atomically
      transaction.update(userRef, {
        coins: admin.firestore.FieldValue.increment(reward),
        watchedAdsToday: watchedToday + 1,
        lastAdResetDate: admin.firestore.FieldValue.serverTimestamp(),
        totalAdsWatched: admin.firestore.FieldValue.increment(1)
      });

      result = {
        success: true,
        reward,
        newBalance: userData.coins + reward,
        adsWatchedToday: watchedToday + 1
      };
    });

    // 4. Async audit log (fire-and-forget using ctx.waitUntil)
    ctx.waitUntil(
      userRef.collection('actions').add({
        type: 'AD_WATCHED',
        reward,
        adUnitId,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      })
    );

    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    });

  } catch (error) {
    return handleError(error.message, error.status || 500);
  }
}
```

**Firestore Operations**:
- 1 read (inside transaction, free)
- 1 write (atomic update)
- 1 write (async audit, non-blocking)

**Total Cost**: 2 writes = $0.000012  
**Response Time**: ~200-300ms (mostly Firestore latency, user gets instant response)

---

## 📝 OPTIMIZED ENDPOINT: Withdrawal (with Atomic Transaction)

### `src/endpoints/withdrawal.js` - Prevent Double-Spend with Transaction

```javascript
import admin from 'firebase-admin';
import { handleError } from '../utils/validation.js';
import { REWARDS } from '../utils/constants.js';

export async function handleWithdrawal(request, db, userId, ctx) {
  try {
    const { amount } = await request.json();

    if (!amount || amount < 100) {
      return handleError('Minimum withdrawal: 100 coins', 400);
    }

    const userRef = db.collection('users').doc(userId);
    const withdrawalRef = db.collection('withdrawals').doc();
    
    let result;
    
    // ATOMIC TRANSACTION: Prevent double-spend
    await db.runTransaction(async (transaction) => {
      const userSnap = await transaction.get(userRef);
      
      if (!userSnap.exists) {
        throw new Error('User not found');
      }

      const userData = userSnap.data();
      
      // Validate balance (inside transaction, no race conditions)
      if (userData.coins < amount) {
        throw new Error('Insufficient coins', {status: 400});
      }

      // Update 1: Deduct coins from user (ATOMIC)
      transaction.update(userRef, {
        coins: admin.firestore.FieldValue.increment(-amount),
        totalWithdrawn: admin.firestore.FieldValue.increment(amount),
        lastWithdrawalDate: admin.firestore.FieldValue.serverTimestamp()
      });

      // Update 2: Create withdrawal record (ATOMIC)
      transaction.set(withdrawalRef, {
        userId,
        amount,
        status: 'pending',
        requestedAt: admin.firestore.FieldValue.serverTimestamp(),
        processedAt: null
      });

      result = {
        success: true,
        withdrawalId: withdrawalRef.id,
        amountDeducted: amount,
        newBalance: userData.coins - amount,
        status: 'pending'
      };
    });

    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    });

  } catch (error) {
    return handleError(error.message, error.status || 500);
  }
}
```

**Firestore Operations**:
- 1 read (inside transaction)
- 2 writes (user update + withdrawal record, both atomic)

**Total Cost**: 2 writes = $0.000012  
**Why Atomic**: Both writes succeed or both fail. User can't lose coins if withdrawal record fails.

---

## 📝 OPTIMIZED ENDPOINT: Referral (with Dual-User Transaction)

### `src/endpoints/referral.js` - Multi-User Atomic Transaction

```javascript
import admin from 'firebase-admin';
import { handleError } from '../utils/validation.js';
import { REWARDS } from '../utils/constants.js';

export async function handleReferral(request, db, userId, ctx) {
  try {
    const { referralCode } = await request.json();

    if (!referralCode || referralCode.length !== 6) {
      return handleError('Invalid referral code', 400);
    }

    // Find referrer by code
    const referrerSnap = await db
      .collection('users')
      .where('referralCode', '==', referralCode)
      .limit(1)
      .get();

    if (referrerSnap.empty) {
      return handleError('Referral code not found', 404);
    }

    const referrerId = referrerSnap.docs[0].id;

    if (referrerId === userId) {
      return handleError('Cannot use own referral code', 400);
    }

    // MULTI-USER ATOMIC TRANSACTION
    const claimedRef = db.collection('users').doc(userId);
    const referrerRef = db.collection('users').doc(referrerId);
    
    let result;

    await db.runTransaction(async (transaction) => {
      // Read both users within transaction
      const claimedSnap = await transaction.get(claimedRef);
      const referrerSnap = await transaction.get(referrerRef);

      if (!claimedSnap.exists || !referrerSnap.exists) {
        throw new Error('User not found');
      }

      // Check if already claimed referral
      const claimedData = claimedSnap.data();
      if (claimedData.referredBy) {
        throw new Error('Already claimed a referral', {status: 400});
      }

      // ATOMIC: Update both users simultaneously
      // Claimer gets bonus coins
      transaction.update(claimedRef, {
        coins: admin.firestore.FieldValue.increment(REWARDS.REFERRAL_CLAIMED),
        referredBy: referrerId,
        referralClaimedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Referrer gets bonus for recruiting
      transaction.update(referrerRef, {
        coins: admin.firestore.FieldValue.increment(REWARDS.REFERRAL_BONUS),
        totalReferrals: admin.firestore.FieldValue.increment(1),
        lastReferralAt: admin.firestore.FieldValue.serverTimestamp()
      });

      result = {
        success: true,
        claimerBonus: REWARDS.REFERRAL_CLAIMED,
        referrerBonus: REWARDS.REFERRAL_BONUS,
        referrerId
      };
    });

    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    });

  } catch (error) {
    return handleError(error.message, error.status || 500);
  }
}
```

**Firestore Operations**:
- 1 query (find referrer by code)
- 2 reads (both users inside transaction)
- 2 writes (both users update atomically)

**Total Cost**: 1 query + 2 writes = $0.000016  
**Why Atomic**: Both users receive bonuses simultaneously. No race conditions.

---

## ⚙️ UTILITIES: Shared Transaction Helper

### `src/utils/firebase.js` - DRY Principle

```javascript
import admin from 'firebase-admin';
import { cert } from 'firebase-admin/app';

let db = null;

export function initFirebase(config) {
  if (!db) {
    const serviceAccount = JSON.parse(config);
    admin.initializeApp({
      credential: cert(serviceAccount)
    });
    db = admin.firestore();
  }
  return db;
}

// Reusable atomic update pattern
export async function atomicUpdate(db, updates) {
  /**
   * @param updates: Array of {ref, data}
   * Example:
   * atomicUpdate(db, [
   *   {ref: userRef, data: {coins: increment(10)}},
   *   {ref: auditRef, data: {type: 'BONUS'}}
   * ])
   */
  await db.runTransaction(async (transaction) => {
    updates.forEach(({ref, data}) => {
      transaction.update(ref, data);
    });
  });
}

// Reusable read-validate-write pattern
export async function readValidateWrite(db, readRef, validator, updates) {
  /**
   * @param validator: function(snapshot) throws if invalid
   * Example:
   * readValidateWrite(
   *   db, 
   *   userRef,
   *   (snap) => {
   *     if (snap.data().coins < 100) throw new Error('Insufficient');
   *   },
   *   (snap) => ({coins: increment(100)})
   * )
   */
  let result;
  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(readRef);
    validator(snap); // Throws if invalid
    const updateData = typeof updates === 'function' ? updates(snap) : updates;
    transaction.update(readRef, updateData);
    result = snap.data();
  });
  return result;
}

export { admin };
```

---

## 📝 OPTIMIZED Main Router

### `src/index.js` - Centralized Transaction Handling

```javascript
import { initFirebase } from './utils/firebase.js';
import { verifyFirebaseToken } from './auth.js';
import { handleAdReward } from './endpoints/ad.js';
import { handleGameReward } from './endpoints/game.js';
import { handleSpin } from './endpoints/spin.js';
import { handleStreak } from './endpoints/streak.js';
import { handleWithdrawal } from './endpoints/withdrawal.js';
import { handleReferral } from './endpoints/referral.js';

export default {
  async fetch(request, env, ctx) {
    // CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization'
        }
      });
    }

    if (request.method !== 'POST') {
      return new Response(JSON.stringify({error: 'Method not allowed'}), {
        status: 405,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    try {
      const db = initFirebase(env.FIREBASE_CONFIG);
      const authHeader = request.headers.get('Authorization');
      const userId = await verifyFirebaseToken(authHeader, env.FIREBASE_CONFIG);

      const url = new URL(request.url);
      const path = url.pathname;

      let response;

      switch (path) {
        case '/verify-ad':
          response = await handleAdReward(request, db, userId, ctx);
          break;
        case '/verify-game':
          response = await handleGameReward(request, db, userId, ctx);
          break;
        case '/spin-wheel':
          response = await handleSpin(request, db, userId, ctx);
          break;
        case '/claim-streak':
          response = await handleStreak(request, db, userId, ctx);
          break;
        case '/request-withdrawal':
          response = await handleWithdrawal(request, db, userId, ctx);
          break;
        case '/claim-referral':
          response = await handleReferral(request, db, userId, ctx);
          break;
        default:
          response = new Response(JSON.stringify({error: 'Endpoint not found'}), {
            status: 404,
            headers: { 'Content-Type': 'application/json' }
          });
      }

      const headers = new Headers(response.headers);
      headers.set('Access-Control-Allow-Origin', '*');

      return new Response(response.body, {
        status: response.status,
        headers
      });

    } catch (error) {
      console.error('Worker error:', error);
      return new Response(JSON.stringify({error: error.message}), {
        status: error.status || 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      });
    }
  }
};
```

---

## 🔐 Firebase Token Verification

### `src/auth.js` - Reusable Token Verification

```javascript
import { initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

let app;

export async function verifyFirebaseToken(authHeader, config) {
  if (!authHeader?.startsWith('Bearer ')) {
    throw {status: 401, message: 'Missing Authorization header'};
  }

  const token = authHeader.substring(7);

  if (!app) {
    const serviceAccount = JSON.parse(config);
    app = initializeApp({
      credential: cert(serviceAccount)
    });
  }

  try {
    const decodedToken = await getAuth(app).verifyIdToken(token);
    return decodedToken.uid;
  } catch (error) {
    throw {status: 401, message: 'Invalid or expired token'};
  }
}
```

---

## ⚙️ Optimized Worker Configuration

### `wrangler.toml`

```toml
name = "earnplay-api"
main = "src/index.js"
compatibility_date = "2024-01-01"
compatibility_flags = ["nodejs_compat"]

[env.production]
routes = [
  { pattern = "api.earnplay.com/*", zone_id = "your-zone-id" }
]

[vars]
FIREBASE_CONFIG = '''
{
  "type": "service_account",
  "project_id": "your-project-id",
  "private_key_id": "...",
  "private_key": "...",
  "client_email": "...",
  "client_id": "...",
  "auth_uri": "...",
  "token_uri": "...",
  "auth_provider_x509_cert_url": "...",
  "client_x509_cert_url": "..."
}
'''

# Optional: Only needed if using distributed locks
# [kv_namespaces]
# binding = "KV"
# id = "your-kv-id"
# preview_id = "your-preview-id"
```

### `package.json`

```json
{
  "name": "earnplay-api",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "wrangler dev",
    "deploy": "wrangler deploy",
    "format": "prettier --write \"src/**/*.js\"",
    "lint": "eslint src/"
  },
  "dependencies": {
    "firebase-admin": "^12.0.0"
  },
  "devDependencies": {
    "wrangler": "^3.0.0",
    "eslint": "^8.0.0",
    "prettier": "^3.0.0"
  }
}
```


---

## 📊 FIRESTORE OPTIMIZATION RESULTS

### Before vs After Optimization

| Metric | Before | After | Savings |
|--------|--------|-------|---------|
| **Reads per endpoint** | 1 (separate) | 1 (inside transaction) | 0% (no change) |
| **Writes per endpoint** | 1-2 (separate) | 1 (batched) | **50-66%** |
| **Cost per ad claim** | $0.000012 | $0.000012 | Break-even |
| **Cost per withdrawal** | $0.000018 | $0.000012 | **33% savings** |
| **Cost per referral** | $0.000024 | $0.000016 | **33% savings** |
| **Monthly (1K DAU, 35 req/user)** | $0.72 | $0.48 | **33% savings** |

### How Transactions Reduce Write Costs

**Example: Ad Reward (Batched Write)**
```
Before (3 separate updates):
await userRef.update({coins: increment(5)});      // Write #1
await userRef.update({watchedAdsToday: 1});       // Write #2
await userRef.update({lastAdResetDate: now});     // Write #3
Total: 3 writes per user = $0.000018

After (1 atomic transaction):
await db.runTransaction((tx) => {
  tx.update(userRef, {
    coins: increment(5),
    watchedAdsToday: 1,
    lastAdResetDate: now
  });
});
Total: 1 write per user = $0.000006 (66% savings!)
```

---

## 💰 REALISTIC COST PROJECTIONS

### 1,000 Daily Active Users

| Component | Requests | Reads | Writes | Cost/Month |
|-----------|----------|-------|--------|------------|
| **Cloudflare Workers** | 35K | - | - | FREE |
| **Firestore Reads** | - | 9K | - | FREE (< 50K) |
| **Firestore Writes** | - | - | 28K | $0.36 |
| **Firebase Auth** | - | - | - | FREE |
| **Audit Logs (async)** | - | - | 8K | $0.12 |
| **TOTAL** | | | | **$0.48/month** |

### 5,000 Daily Active Users

| Component | Requests | Reads | Writes | Cost/Month |
|-----------|----------|-------|--------|------------|
| **Cloudflare Workers** | 175K | - | - | $5.00 |
| **Firestore Reads** | - | 45K | - | FREE |
| **Firestore Writes** | - | - | 140K | $2.16 |
| **Audit Logs (async)** | - | - | 40K | $0.60 |
| **TOTAL** | | | | **$7.76/month** |

### 10,000 Daily Active Users

| Component | Requests | Reads | Writes | Cost/Month |
|-----------|----------|-------|--------|------------|
| **Cloudflare Workers** | 350K | - | - | $10.00 |
| **Firestore Reads** | - | 90K | - | $0.30 |
| **Firestore Writes** | - | - | 280K | $4.32 |
| **Audit Logs (async)** | - | - | 80K | $1.20 |
| **TOTAL** | | | | **$15.82/month** |

---

## 🚀 SETUP INSTRUCTIONS (Already Done by User)

### ✅ Step 1: Install Wrangler (COMPLETED)
```bash
npm install -g wrangler
wrangler --version
```

### ✅ Step 2: Log in to Cloudflare (COMPLETED)
```bash
wrangler login
```

### ✅ Step 3: Create Worker Project (COMPLETED)
```bash
wrangler init my-backend
```

### Step 4: Install Dependencies
```bash
cd my-backend
npm install firebase-admin
npm install -D wrangler eslint prettier
```

### Step 5: Add Firebase Service Account
1. Go to Firebase Console → Settings → Service Accounts
2. Click "Generate New Private Key"
3. Copy the JSON key
4. Update `wrangler.toml` with the config

### Step 6: Create Directory Structure
```bash
mkdir -p src/endpoints src/utils src/middleware
touch src/index.js src/auth.js src/utils/firebase.js src/utils/validation.js src/utils/constants.js
touch src/endpoints/{ad,game,spin,streak,withdrawal,referral}.js
```

### Step 7: Deploy Worker
```bash
wrangler deploy
```

---

## 🎯 DEPLOYMENT PHASES (Optimized)

### Phase 1 (Week 1): Ad Verification Only
**Goal**: Minimal viable worker, single endpoint, test production behavior

1. Deploy `/verify-ad` endpoint
2. Update Flutter app to call worker for ad rewards
3. Monitor Firestore writes (should see 1 write per ad claim)
4. Verify audit logs appear async

**Expected costs**: $0.001-0.002/month for 100 testers

### Phase 2 (Week 2): Game Verification
**Goal**: Add game score validation with transaction safety

1. Deploy `/verify-game` endpoint
2. Update Tictactoe & Whack-a-Mole screens to call worker
3. Verify atomic game updates (coin + stats + audit log)

**Expected costs**: $0.005-0.010/month for 100 testers

### Phase 3 (Week 3): Spin Wheel & Streak
**Goal**: Server-side RNG, atomic daily checks

1. Deploy `/spin-wheel` endpoint
2. Deploy `/claim-streak` endpoint
3. Test daily reset logic in worker (not Flutter)

**Expected costs**: $0.010-0.020/month for 100 testers

### Phase 4 (Week 4): Withdrawal & Referral
**Goal**: Multi-document atomic transactions

1. Deploy `/request-withdrawal` endpoint
2. Deploy `/claim-referral` endpoint
3. Test that both users update atomically
4. Load test with concurrent requests (verify no double-withdrawals)

**Expected costs**: $0.020-0.050/month for 100 testers

---

## 🔐 FIRESTORE SECURITY RULES (Worker-Aware)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ✅ Users can only read own document
    match /users/{uid} {
      allow read: if request.auth.uid == uid;
      allow write: if false; // Workers write via Admin SDK (bypasses rules)
    }

    // ✅ Workers write audit logs (verified via Admin SDK)
    match /users/{uid}/actions/{actionId} {
      allow read: if request.auth.uid == uid;
      allow write: if false; // Workers only
    }

    // ✅ Withdrawals are admin-only reads
    match /withdrawals/{docId} {
      allow read: if false; // Admin dashboard only
      allow write: if false; // Workers only
    }

    // ✅ Public read for leaderboards (no worker needed)
    match /leaderboard/{docId} {
      allow read: if true;
      allow write: if false; // Workers/Admin only
    }
  }
}
```

---

## ⚠️ CRITICAL: What NOT to Do

### ❌ Don't Create Multiple Transactions

```javascript
// WRONG: 2 transactions = potential race condition
await db.runTransaction(async (tx) => {
  tx.update(userRef, {coins: increment(10)});
});
await db.runTransaction(async (tx) => {
  tx.update(userRef, {totalEarned: increment(10)});
});

// RIGHT: 1 transaction = atomic
await db.runTransaction(async (tx) => {
  tx.update(userRef, {
    coins: increment(10),
    totalEarned: increment(10)
  });
});
```

### ❌ Don't Read Without Transaction Context

```javascript
// WRONG: Read outside transaction (race condition possible)
const snap = await userRef.get();
const coins = snap.data().coins;

if (coins < 100) throw new Error('Insufficient');

await userRef.update({coins: increment(-100)}); // What if another write happened?

// RIGHT: Read + validate inside transaction
await db.runTransaction(async (tx) => {
  const snap = await tx.get(userRef); // Free read within transaction
  const coins = snap.data().coins;
  if (coins < 100) throw new Error('Insufficient');
  tx.update(userRef, {coins: increment(-100)}); // Atomic
});
```

### ❌ Don't Fire-and-Forget Audit Logs in Transaction

```javascript
// WRONG: Blocks user response
await db.runTransaction(async (tx) => {
  tx.update(userRef, {coins: increment(10)});
  // Don't add audit log here, it's a separate collection
});
await userRef.collection('actions').add({...}); // Blocks response

// RIGHT: Use ctx.waitUntil for async logging
await db.runTransaction(async (tx) => {
  tx.update(userRef, {coins: increment(10)});
});

ctx.waitUntil(
  userRef.collection('actions').add({...})
);
```

### ❌ Don't Increment Without Checking Date

```javascript
// WRONG: watchedAdsToday can exceed 10 on new day
if (userData.watchedAdsToday < 10) {
  await userRef.update({
    watchedAdsToday: increment(1) // BUG: If it's a new day, this was already 10 yesterday!
  });
}

// RIGHT: Check date inside transaction
await db.runTransaction(async (tx) => {
  const snap = await tx.get(userRef);
  const userData = snap.data();
  
  const today = new Date().toISOString().split('T')[0];
  const lastAdDate = userData.lastAdResetDate?.toDate().toISOString().split('T')[0];
  
  const watchedToday = (today === lastAdDate) ? userData.watchedAdsToday : 0;
  
  if (watchedToday >= 10) throw new Error('Limit reached');
  
  tx.update(userRef, {
    watchedAdsToday: watchedToday + 1, // Correct reset on new day
    lastAdResetDate: admin.firestore.FieldValue.serverTimestamp()
  });
});
```

---

## 🧪 TESTING THE WORKER LOCALLY

### Test Ad Verification Endpoint

```bash
# Start local worker
wrangler dev

# In another terminal, get Firebase ID token
# From Flutter app console or Firebase console

# Test request
curl -X POST http://localhost:8787/verify-ad \
  -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "adUnitId": "ca-app-pub-3940256099942544/5224354917",
    "timestamp": '$(date +%s000)'
  }'

# Expected response
{
  "success": true,
  "reward": 5,
  "newBalance": 105,
  "adsWatchedToday": 1
}
```

### Monitor Firestore Writes

Open Firebase Console → Firestore → Monitor tab. Watch write counts increase as you test.

---

## 🎯 FINAL CHECKLIST

- [ ] Wrangler installed & logged in
- [ ] Worker project created (`my-backend/`)
- [ ] Firebase Admin SDK installed
- [ ] Service account key configured in `wrangler.toml`
- [ ] All 6 endpoints implemented
- [ ] Transaction pattern used consistently
- [ ] Async audit logs use `ctx.waitUntil()`
- [ ] CORS headers added to all responses
- [ ] Error handling implemented (no transaction retries needed)
- [ ] Deployed to production
- [ ] Flutter app updated to call worker endpoints
- [ ] Load tested with concurrent requests
- [ ] Firestore write costs verified (should be 66% lower than before)

---

## 📚 REFERENCE DOCS

- **Cloudflare Workers**: https://developers.cloudflare.com/workers/
- **Firebase Admin SDK**: https://firebase.google.com/docs/database/admin/start
- **Firestore Transactions**: https://cloud.google.com/firestore/docs/transactions
- **Wrangler CLI**: https://developers.cloudflare.com/workers/wrangler/

---

## 🚨 SUPPORT

**Issue**: Worker timeout  
**Solution**: Increase timeout in `wrangler.toml` → `compatibility_date = "2024-01-01"` (allows higher limits)

**Issue**: Token verification fails  
**Solution**: Ensure Firebase service account has "Firebase Authentication Service" role in Google Cloud Console

**Issue**: High write costs  
**Solution**: Verify all endpoints use transactions (check each endpoint for separate updates)

**Issue**: Audit logs missing  
**Solution**: Check `ctx.waitUntil()` is used. If worker crashes before logging, async logs won't complete.
