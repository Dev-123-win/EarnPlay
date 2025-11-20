# EarnPlay: Worker-Batched Architecture (Complete Redesign)

**Status**: Architecture Design (Ready for Implementation)  
**Date**: November 19, 2025  
**Version**: 2.0

---

## Executive Summary

This document redesigns EarnPlay's backend to **eliminate direct Firestore writes from the client** and route all state updates through **Cloudflare Workers with intelligent batching**.

### Key Innovation: Event Batching Pipeline

Instead of client → Firestore writes:

```
Client (local) → Worker Queue → Batch Aggregation → Single Firestore Write
```

This reduces:
- **Worker requests**: From 2,450/day to ~500/day (80% reduction)
- **Firestore writes**: From 14,500/day to ~200/day (99% reduction)
- **Monthly cost**: Stays within $0 (free tier)
- **DAU capacity**: Supports 10,000+ concurrent users

### Critical Design Principles

1. **Client never writes Firestore directly** — All writes via Worker
2. **Optimistic UI updates** — Coins update instantly (while queued for batch)
3. **Batching strategy** — Events grouped by user and type, flushed every 60 seconds
4. **Idempotency everywhere** — Prevents double rewards on network retries
5. **Real-time feel** — User sees coin increases instantly despite delayed Firestore writes

---

## Architecture Overview

### 1. Event Flow Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                         CLIENT (Flutter)                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  User Action (Watched Ad, Game Won, Spin, etc.)                 │
│         ↓                                                         │
│  ┌──────────────────────────────────────┐                       │
│  │ 1. Optimistic Local Update (Instant) │                       │
│  │    - Update coins in Provider        │                       │
│  │    - Save to SharedPreferences       │                       │
│  │    - Notify listeners (UI updates)   │                       │
│  └──────────────────────────────────────┘                       │
│         ↓                                                         │
│  ┌──────────────────────────────────────┐                       │
│  │ 2. Queue Event to Local Storage      │                       │
│  │    - Store in Hive (off-device cache)│                       │
│  │    - Add idempotencyKey              │                       │
│  │    - Include timestamp               │                       │
│  └──────────────────────────────────────┘                       │
│         ↓                                                         │
│  ┌──────────────────────────────────────┐                       │
│  │ 3. Trigger Periodic Flush            │                       │
│  │    - Every 60 seconds OR             │                       │
│  │    - When 50 events queued OR        │                       │
│  │    - On app background pause         │                       │
│  └──────────────────────────────────────┘                       │
│         ↓ (via HTTP)                                             │
├─────────────────────────────────────────────────────────────────┤
│              CLOUDFLARE WORKER (Batch Processor)                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  POST /batch-events                                              │
│  ├─ Receives: [event1, event2, ..., eventN]                     │
│  │                                                                │
│  ├─ Phase 1: Validate & Deduplicate                             │
│  │   ├─ Check idempotencyKey against Redis cache                │
│  │   ├─ If cached → Return cached response (idempotent)         │
│  │   └─ If new → Proceed to Phase 2                             │
│  │                                                                │
│  ├─ Phase 2: Aggregate Events                                   │
│  │   ├─ Group by type: [GAME_WON: 5, AD_WATCHED: 3, ...]       │
│  │   ├─ Verify totals don't exceed daily limits                 │
│  │   ├─ Calculate total coins delta                             │
│  │   └─ Build merged action log                                 │
│  │                                                                │
│  ├─ Phase 3: Atomic Firestore Transaction                       │
│  │   ├─ Read user document                                       │
│  │   ├─ Update: coins += delta                                   │
│  │   ├─ Update: daily stats (ads watched, spins used, etc.)     │
│  │   ├─ Update/Create: monthly stats                            │
│  │   ├─ Append: daily action log                                │
│  │   └─ Verify: All operations succeed (all-or-nothing)         │
│  │                                                                │
│  └─ Phase 4: Cache Result & Return                              │
│     ├─ Store idempotencyKey + response in Redis (1 hour TTL)    │
│     ├─ Return updated balance to client                         │
│     └─ (Client silently ignores if already updated locally)     │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
         ↓ (via Firestore)
┌─────────────────────────────────────────────────────────────────┐
│                 FIRESTORE (Single, Atomic Write)                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  /users/{uid}                                                    │
│  ├─ coins: increment(totalDelta) ← ATOMIC, prevents race        │
│  ├─ daily.watchedAdsToday: increment(adCount)                   │
│  ├─ daily.spinsRemaining: decrement(spinCount)                  │
│  ├─ totalGamesWon: increment(gameCount)                         │
│  └─ lastUpdated: serverTimestamp()                              │
│                                                                   │
│  /users/{uid}/monthly_stats/{YYYY-MM}                           │
│  ├─ gamesPlayed: increment(count)                               │
│  ├─ coinsEarned: increment(delta)                               │
│  ├─ adsWatched: increment(adCount)                              │
│  └─ lastUpdated: serverTimestamp()                              │
│                                                                   │
│  /users/{uid}/actions/{YYYY-MM-DD}                              │
│  ├─ events: [                                                    │
│  │    {type: "GAME_WON", coins: 50, timestamp},                 │
│  │    {type: "AD_WATCHED", coins: 5, timestamp},                │
│  │    ...                                                        │
│  │  ]                                                            │
│  └─ totalCoinsEarned: sum(events.coins)                         │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Event Queueing Strategy

### 2.1 Event Types & Batching Rules

| Event Type | Frequency | Batch Window | Max Per Day | Worker Calls |
|------------|-----------|--------------|------------|------------|
| `GAME_WON` | Per game (5 games/day) | 60s or 50 events | Unlimited | Batched |
| `AD_WATCHED` | Per ad (10/day) | 60s or 50 events | 10 | Batched |
| `SPIN_CLAIMED` | Per spin (3/day) | 60s or 50 events | 3 | Batched |
| `STREAK_CLAIMED` | Once/day | 60s or 50 events | 1 | Batched |
| `WITHDRAWAL_REQ` | 1-7/day | Immediate | 7 | Individual call |
| `REFERRAL_CLAIMED` | 1-2/day | Immediate | 1 | Individual call |

**Batching Strategy**:
- **Regular events** (games, ads, spins): Batch every 60 seconds OR when 50 events queued
- **Critical events** (withdrawals, referrals): Send immediately (avoid user confusion)
- **On app pause**: Force-flush all pending events

### 2.2 Local Queue Format (Hive Storage)

```dart
// Stored in Hive: box('earnplay_event_queue')
{
  "userId": "user123",
  "events": [
    {
      "id": "evt_uuid_1",  // Unique per event
      "type": "GAME_WON",
      "coins": 50,
      "metadata": {
        "gameName": "tictactoe",
        "duration": 300,
        "opponentType": "ai"
      },
      "timestamp": 1700000000000,  // Client-side timestamp (ms)
      "idempotencyKey": "idempotency_uuid_xxx",
      "status": "PENDING"  // PENDING, INFLIGHT, SYNCED
    },
    {
      "id": "evt_uuid_2",
      "type": "AD_WATCHED",
      "coins": 5,
      "metadata": {
        "adUnitId": "ca-app-pub-xxx",
        "adNetwork": "admob",
        "watchDuration": 30
      },
      "timestamp": 1700000050000,
      "idempotencyKey": "idempotency_uuid_yyy",
      "status": "PENDING"
    }
  ],
  "lastFlushedAt": 1700000000000,
  "nextFlushAt": 1700000060000,  // Scheduled flush time
  "queueSize": 2
}
```

### 2.3 Flush Triggers

```dart
// Timer-based: Flush every 60 seconds
Timer.periodic(Duration(seconds: 60), (timer) {
  flushEventQueue();
});

// Size-based: Flush when 50 events queued
if (queueSize >= 50) {
  flushEventQueue();
}

// Lifecycle-based: Flush on app pause
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused) {
    flushEventQueue();  // Don't lose data on force-close
  }
}

// Manual: User can trigger sync on-demand
Future<void> syncNow() {
  return flushEventQueue();
}
```

---

## 3. Worker Implementation (Cloudflare)

### 3.0 Authentication & Authorization

All immediate endpoints (e.g., `/create-user`, `/claim-referral`, `/request-withdrawal`) **MUST** accept an `Authorization: Bearer <idToken>` header. The Worker will then perform the following:

1.  **`verifyIdToken(idToken)` Helper**:
    *   **Purpose**: Securely validate the Firebase ID Token provided by the client.
    *   **Mechanism**: The Worker will use the Firebase Admin SDK (or a REST API call to Firebase Auth) to verify the `idToken`. This process ensures the token is valid, unexpired, and issued by Firebase for the correct project.
    *   **Output**: Upon successful verification, the helper will return the decoded token, from which the authenticated user's `uid` can be extracted.
    *   **Constraint**: Any `uid` sent by the client in the request body **MUST be ignored**. The canonical `uid` for all operations will always be derived directly from the verified `idToken`.
    *   **Error Handling**: If `idToken` verification fails (e.g., invalid, expired, malformed token), the Worker **MUST** reject the request with an `HTTP 401 Unauthorized` status code and a clear error message (e.g., `INVALID_TOKEN`).

2.  **Worker-Only Writes**: All writes that change `coins`, `referredBy`, `withdrawals`, or `devices` **MUST** be performed by the Worker (acting as a service account) via atomic Firestore transactions. This is enforced by Firestore Security Rules (see Section 10).

### 3.1 POST /batch-events Endpoint

#### 3.1.0 Input & Output Shapes (Copy-Paste Ready)

**Request Body**:
```json
{
  "userId": "user123",
  "events": [
    {
      "id": "evt_uuid_1",
      "type": "GAME_WON",
      "coins": 50,
      "metadata": {
        "gameName": "tictactoe",
        "duration": 300
      },
      "timestamp": 1700000000000,
      "idempotencyKey": "idemp_uuid_1"
    }
  ]
}
```

**Success Response (HTTP 200)**:
```json
{
  "success": true,
  "processedCount": 45,
  "newBalance": 1500,
  "deltaCoins": 250,
  "stats": {
    "GAME_WON": 10,
    "AD_WATCHED": 20,
    "SPIN_CLAIMED": 15
  },
  "timestamp": 1700000120000,
  "isCached": false
}
```

**Error Response (HTTP 400/429/500)**:
```json
{
  "success": false,
  "error": "Daily ad limit exceeded | Rate limit exceeded | Unknown error",
  "retryAfter": 60
}
```

#### 3.1.1 Idempotency KV Key Conventions & TTLs

**KV Key Format**:
```
idempotency:{endpoint}:{userId}:{idempotencyKey}
Example: idempotency:batch-events:user123:uuid-abc-123
TTL: 3600 seconds (1 hour)
Purpose: Cache response to return on retry (idempotent)
```

**Implementation**:
```javascript
const idempotencyCacheKey = `idempotency:batch-events:${userId}:${event.idempotencyKey}`;
const cached = await ctx.env.KV_IDEMPOTENCY.get(idempotencyCacheKey);

if (cached) {
  return new Response(cached, { status: 200 });  // Idempotent response
}

// ... process event ...

await ctx.env.KV_IDEMPOTENCY.put(
  idempotencyCacheKey,
  JSON.stringify(responseData),
  { expirationTtl: 3600 }  // Expire after 1 hour
);
```

#### 3.1.2 Rate-Limit Counter KV Key Conventions & TTLs

**Per-UID Rate Limiting**:
```
KV Key: rate:batch-events:uid:{userId}
Limit: 10 requests per 60 seconds
TTL: 60 seconds (sliding window)
Example: rate:batch-events:uid:user123
```

**Per-IP Rate Limiting**:
```
KV Key: rate:batch-events:ip:{clientIP}
Limit: 50 requests per 60 seconds
TTL: 60 seconds (sliding window)
Example: rate:batch-events:ip:203.0.113.45
```

**Implementation**:
```javascript
async function checkRateLimits(userId, ip, kvBinding, endpoint) {
  const windowMs = 60 * 1000;  // 60 seconds
  const uidLimit = 10;
  const ipLimit = 50;
  
  // Per-UID check
  const uidKey = `rate:${endpoint}:uid:${userId}`;
  let uidCount = parseInt(await kvBinding.get(uidKey) || '0');
  if (uidCount >= uidLimit) {
    return { limited: true, retryAfter: 60 };
  }
  await kvBinding.put(uidKey, (uidCount + 1).toString(), { expirationTtl: 60 });
  
  // Per-IP check
  const ipKey = `rate:${endpoint}:ip:${ip}`;
  let ipCount = parseInt(await kvBinding.get(ipKey) || '0');
  if (ipCount >= ipLimit) {
    return { limited: true, retryAfter: 60 };
  }
  await kvBinding.put(ipKey, (ipCount + 1).toString(), { expirationTtl: 60 });
  
  return { limited: false };
}
```

#### 3.1.3 Worker Endpoint Implementation

```javascript
/**
 * POST /batch-events
 * 
 * Purpose: Batch process 50-100 events from a single user
 * 
 * Request body:
 * {
 *   "userId": "user123",
 *   "events": [
 *     {
 *       "id": "evt_1",
 *       "type": "GAME_WON",
 *       "coins": 50,
 *       "metadata": {...},
 *       "timestamp": 1700000000000,
 *       "idempotencyKey": "idemp_xxx"
 *     },
 *     ...
 *   ]
 * }
 * 
 * Response:
 * {
 *   "success": true,
 *   "processedCount": 45,
 *   "newBalance": 1500,
 *   "deltaCoins": 250,
 *   "stats": {
 *     "gamesProcessed": 10,
 *     "adsProcessed": 20,
 *     "spinsProcessed": 15
 *   },
 *   "timestamp": 1700000120000
 * }
 */

export async function handleBatchEvents(request, db, userId, ctx) {
  // userId is derived from verified idToken (see 3.0)
  try {
    // 1. Parse request
    const body = await request.json();
    const { events } = body;
    
    if (!events || !Array.isArray(events) || events.length === 0) {
      return new Response(JSON.stringify({
        success: false,
        error: "Events array is empty or missing"
      }), { status: 400 });
    }
    
    if (events.length > 500) {
      return new Response(JSON.stringify({
        success: false,
        error: "Too many events (max 500 per request)"
      }), { status: 400 });
    }

    // 2. Rate Limiting (per-UID and per-IP)
    const ip = request.headers.get('CF-Connecting-IP');
    const rateLimitResult = await checkRateLimits(userId, ip, ctx.env.KV_RATE_COUNTERS);
    if (rateLimitResult.limited) {
      return new Response(JSON.stringify({
        success: false,
        error: `Rate limit exceeded. Try again in ${rateLimitResult.retryAfter} seconds.`
      }), { status: 429, headers: { 'Retry-After': rateLimitResult.retryAfter.toString() } });
    }

    // 3. Validate & deduplicate against idempotency cache
    const deduplicatedEvents = [];
    const cachedEvents = [];
    
    for (const event of events) {
      const cacheKey = `idempotency:event:${userId}:${event.idempotencyKey}`; // Updated KV key
      const cached = await ctx.env.KV_IDEMPOTENCY.get(cacheKey); // Using KV for idempotency
      
      if (cached) {
        // Event already processed
        cachedEvents.push(JSON.parse(cached));
        continue;
      }
      
      // Validate event structure
      if (!event.type || event.coins === undefined) { // Check for undefined coins
        return new Response(JSON.stringify({
          success: false,
          error: `Invalid event structure: ${JSON.stringify(event)}`
        }), { status: 400 });
      }
      
      deduplicatedEvents.push(event);
    }

    // 4. If all events were cached, return summary without Firestore write
    if (deduplicatedEvents.length === 0 && cachedEvents.length > 0) {
      const totalCoins = cachedEvents.reduce((sum, e) => sum + e.coins, 0);
      return new Response(JSON.stringify({
        success: true,
        processedCount: 0,
        newBalance: cachedEvents[0].newBalance,  // From first cached event
        deltaCoins: totalCoins,
        isCached: true
      }), { status: 200 });
    }

    // 5. Aggregate deduplicated events
    const aggregated = aggregateEvents(deduplicatedEvents);
    
    // Example aggregation result:
    // {
    //   totalCoins: 250,
    //   eventCounts: { GAME_WON: 5, AD_WATCHED: 3, SPIN_CLAIMED: 2 },
    //   dailyStats: {
    //     watchedAdsToday: 3,
    //     spinsUsedToday: 2,
    //     gamesWonToday: 5
    //   },
    //   allEvents: [...]
    // }

    // 6. Atomic Firestore transaction (Worker-only write)
    let newBalance;
    
    try {
      await db.runTransaction(async (transaction) => {
        // Read user
        const userRef = db.collection('users').doc(userId);
        const userDoc = await transaction.get(userRef);
        
        if (!userDoc.exists) {
          throw new Error('User document not found');
        }
        
        const userData = userDoc.data();
        const currentBalance = userData.coins || 0;
        const today = new Date().toISOString().split('T')[0];  // YYYY-MM-DD
        const thisMonth = today.substring(0, 7);  // YYYY-MM
        
        // Validate daily limits
        const adsWatchedToday = userData.daily?.watchedAdsToday || 0;
        const newAdsCount = aggregated.eventCounts.AD_WATCHED || 0;
        
        if (adsWatchedToday + newAdsCount > 10) {
          throw new Error('Daily ad limit exceeded');
        }
        
        // ✅ Update user document
        newBalance = currentBalance + aggregated.totalCoins;
        
        transaction.update(userRef, {
          coins: admin.firestore.FieldValue.increment(aggregated.totalCoins),
          'daily.watchedAdsToday': admin.firestore.FieldValue.increment(
            aggregated.eventCounts.AD_WATCHED || 0
          ),
          'daily.spinsRemaining': admin.firestore.FieldValue.increment(
            -(aggregated.eventCounts.SPIN_CLAIMED || 0)
          ),
          totalGamesWon: admin.firestore.FieldValue.increment(
            aggregated.eventCounts.GAME_WON || 0
          ),
          totalAdsWatched: admin.firestore.FieldValue.increment(
            aggregated.eventCounts.AD_WATCHED || 0
          ),
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          lastSyncAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        // ✅ Update/Create monthly stats (merge)
        const monthlyStatsRef = userRef.collection('monthly_stats').doc(thisMonth);
        transaction.set(
          monthlyStatsRef,
          {
            month: thisMonth,
            gamesPlayed: admin.firestore.FieldValue.increment(
              aggregated.eventCounts.GAME_WON || 0
            ),
            coinsEarned: admin.firestore.FieldValue.increment(
              aggregated.totalCoins
            ),
            adsWatched: admin.firestore.FieldValue.increment(
              aggregated.eventCounts.AD_WATCHED || 0
            ),
            spinsUsed: admin.firestore.FieldValue.increment(
              aggregated.eventCounts.SPIN_CLAIMED || 0
            ),
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }  // Create if missing, update if exists
        );
        
        // ✅ Append to daily action log
        const dailyActionsRef = userRef.collection('actions').doc(today);
        transaction.set(
          dailyActionsRef,
          {
            date: today,
            events: admin.firestore.FieldValue.arrayUnion(
              aggregated.allEvents.map(e => ({
                type: e.type,
                coins: e.coins,
                timestamp: e.timestamp,
                idempotencyKey: e.idempotencyKey,
              }))
            ),
            totalCoinsEarned: admin.firestore.FieldValue.increment(
              aggregated.totalCoins
            ),
            totalEvents: admin.firestore.FieldValue.increment(
              deduplicatedEvents.length
            ),
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }  // Create if missing
        );
      });
    } catch (txError) {
      throw new Error(`Firestore transaction failed: ${txError.message}`);
    }

    // 7. Cache idempotency keys
    const responseData = {
      success: true,
      processedCount: deduplicatedEvents.length,
      newBalance,
      deltaCoins: aggregated.totalCoins,
      stats: aggregated.eventCounts,
      timestamp: Date.now(),
    };
    
    for (const event of deduplicatedEvents) {
      const cacheKey = `idempotency:event:${userId}:${event.idempotencyKey}`;
      await ctx.env.KV_IDEMPOTENCY.put( // Using KV for idempotency
        cacheKey,
        JSON.stringify(responseData),
        { expirationTtl: 3600 }  // 1 hour TTL
      );
    }
    
    return new Response(JSON.stringify(responseData), { status: 200 });
    
  } catch (error) {
    console.error('[/batch-events] Error:', error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message || 'Unknown error'
    }), { status: 500 });
  }
}

/**
 * Helper: Aggregate events by type and calculate totals
 */
function aggregateEvents(events) {
  const eventCounts = {};
  const allEvents = [];
  let totalCoins = 0;
  
  for (const event of events) {
    // Increment count by type
    eventCounts[event.type] = (eventCounts[event.type] || 0) + 1;
    
    // Sum coins
    totalCoins += event.coins || 0;
    
    // Keep full event for audit trail
    allEvents.push(event);
  }
  
  return {
    totalCoins,
    eventCounts,
    allEvents,
  };
}
```

### 3.2 Immediate Events: Withdrawals & Referrals

For events that need **immediate user feedback**, send directly to Worker (no batching):

```javascript
/**
 * POST /request-withdrawal (IMMEDIATE - No batching)
 * 
 * Called immediately when user submits withdrawal request
 * Returns within 2 seconds (no delay)
 */
export async function handleWithdrawal(request, db, userId, ctx) {
  try {
    const body = await request.json();
    const { amount, method, paymentDetails, idempotencyKey } = body;
    
    // Idempotency check
    const cacheKey = `withdrawal:${userId}:${idempotencyKey}`;
    const cached = await ctx.env.CACHE.get(cacheKey);
    if (cached) {
      return new Response(cached, { status: 200 });
    }

    // Validation
    if (amount < 500 || amount > 100000) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Invalid withdrawal amount (500-100000 coins)'
      }), { status: 400 });
    }

    // Transaction
    const withdrawalId = await db.runTransaction(async (txn) => {
      const userRef = db.collection('users').doc(userId);
      const userDoc = await txn.get(userRef);
      
      if (!userDoc.exists) throw new Error('User not found');
      
      const balance = userDoc.data().coins;
      if (balance < amount) {
        throw new Error('Insufficient balance');
      }
      
      // Create withdrawal
      const withdrawalRef = db.collection('withdrawals').doc();
      txn.set(withdrawalRef, {
        userId,
        amount,
        method,
        paymentDetails,
        status: 'PENDING',
        requestedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      // Deduct coins
      txn.update(userRef, {
        coins: admin.firestore.FieldValue.increment(-amount),
      });
      
      return withdrawalRef.id;
    });

    const responseData = {
      success: true,
      withdrawalId,
      newBalance: (await db.collection('users').doc(userId).get()).data().coins,
    };

    // Cache result
    await ctx.env.CACHE.put(
      cacheKey,
      JSON.stringify(responseData),
      { expirationTtl: 3600 }
    );

    return new Response(JSON.stringify(responseData), { status: 200 });
  } catch (error) {
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), { status: 500 });
  }
}

### 3.3 One-Account-Per-Device: /devices Collection & /create-user Endpoint

To enforce a "one account per device" policy and enhance security, a new `/devices` Firestore collection will be introduced.

#### 3.3.1 /devices Collection Schema

The `/devices/{deviceHash}` collection will store a mapping between a unique device identifier and the user `uid` currently bound to it.

```
/devices/{deviceHash}
├── deviceHash: string (SHA256 hash of device_info_plus data)
├── uid: string (Firebase User ID)
├── createdAt: timestamp (When the device was first bound)
└── lastBoundAt: timestamp? (Optional: Last time this device was successfully bound/verified)
```

#### 3.3.2 /create-user Endpoint (Immediate)

This new endpoint handles user registration and device binding. It is an **immediate** endpoint, meaning it is not batched. Clients **MUST** send the `deviceHash` in the request body.

```javascript
/**
 * POST /create-user (IMMEDIATE - No batching)
 * 
 * Purpose: Register a new user and bind their device.
 * 
 * Request body:
 * {
 *   "deviceHash": "sha256_hash_of_device_info",
 *   "idempotencyKey": "uuid_for_this_request"
 * }
 * 
 * Headers:
 *   Authorization: Bearer <idToken> (from Firebase Auth)
 * 
 * Response:
 * {
 *   "success": true,
 *   "uid": "firebase_user_id",
 *   "message": "User created and device bound successfully."
 * }
 * 
 * Error Responses:
 *   401 Unauthorized: Invalid idToken
 *   409 Conflict: Device already bound to another user
 *   429 Too Many Requests: Rate limit exceeded
 *   500 Internal Server Error: Firestore transaction failed, etc.
 */
export async function handleCreateUser(request, db, userId, ctx) {
  // userId is derived from verified idToken (see 3.0)
  try {
    const body = await request.json();
    const { deviceHash, idempotencyKey } = body;

    if (!deviceHash) {
      return new Response(JSON.stringify({ success: false, error: "deviceHash is required" }), { status: 400 });
    }

    // 1. Rate Limiting (per-IP)
    const ip = request.headers.get('CF-Connecting-IP');
    const rateLimitResult = await checkRateLimits(null, ip, ctx.env.KV_RATE_COUNTERS, 'create_user'); // Only IP rate limit for new users
    if (rateLimitResult.limited) {
      return new Response(JSON.stringify({
        success: false,
        error: `Rate limit exceeded. Try again in ${rateLimitResult.retryAfter} seconds.`
      }), { status: 429, headers: { 'Retry-After': rateLimitResult.retryAfter.toString() } });
    }

    // 2. Idempotency Check
    const idempotencyCacheKey = `idempotency:create-user:${userId}:${idempotencyKey}`;
    const cachedResponse = await ctx.env.KV_IDEMPOTENCY.get(idempotencyCacheKey);
    if (cachedResponse) {
      return new Response(cachedResponse, { status: 200 });
    }

    let newUid = userId; // Use UID from verified token

    // 3. Atomic Firestore Transaction (Worker-only write)
    await db.runTransaction(async (transaction) => {
      const deviceRef = db.collection('devices').doc(deviceHash);
      const deviceDoc = await transaction.get(deviceRef);

      if (deviceDoc.exists) {
        // Device already bound to an account
        throw new Error('DEVICE_ALREADY_BOUND');
      }

      // Create /users/{uid} document
      const userRef = db.collection('users').doc(newUid);
      transaction.set(userRef, {
        uid: newUid,
        email: newUid, // Placeholder, actual email from idToken if available
        coins: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        referralCode: generateReferralCode(), // Implement this helper
        referredBy: null,
        totalGamesWon: 0,
        totalAdsWatched: 0,
        totalReferrals: 0,
        totalCoinsEarned: 0,
        totalCoinsWithdrawn: 0,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        lastSyncAt: admin.firestore.FieldValue.serverTimestamp(),
        daily: {
          watchedAdsToday: 0,
          lastAdResetDate: admin.firestore.FieldValue.serverTimestamp(),
          spinsRemaining: 3,
          lastSpinResetDate: admin.firestore.FieldValue.serverTimestamp(),
        },
        dailyStreak: {
          currentStreak: 0,
          lastCheckIn: null,
          checkInDates: [],
        },
        metadata: {
          lastActiveAt: admin.firestore.FieldValue.serverTimestamp(),
          deviceId: deviceHash,
          appVersion: request.headers.get('X-App-Version') || 'unknown',
        },
      });

      // Create /devices/{deviceHash} mapping
      transaction.set(deviceRef, {
        deviceHash: deviceHash,
        uid: newUid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastBoundAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    const responseData = JSON.stringify({
      success: true,
      uid: newUid,
      message: "User created and device bound successfully."
    });

    // Cache idempotency result
    await ctx.env.KV_IDEMPOTENCY.put(idempotencyCacheKey, responseData, { expirationTtl: 3600 }); // 1 hour TTL

    return new Response(responseData, { status: 200 });

  } catch (error) {
    console.error('[/create-user] Error:', error);
    if (error.message === 'DEVICE_ALREADY_BOUND') {
      return new Response(JSON.stringify({ success: false, error: "Device already bound to an account." }), { status: 409 });
    }
    return new Response(JSON.stringify({ success: false, error: error.message || 'Unknown error' }), { status: 500 });
  }
}

/**
 * Helper: Generate a unique referral code (e.g., 8 alphanumeric characters)
 * This should be robust to collisions.
 */
function generateReferralCode() {
  // Placeholder for actual implementation
  // In a real system, this would involve checking for uniqueness in Firestore
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let result = '';
  for (let i = 0; i < 8; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

#### 3.3.3 Client Requirements for DeviceHash

Clients **MUST** compute and send the `deviceHash` on the following immediate endpoints:
*   `/create-user`
*   `/claim-referral`
*   `/request-withdrawal`

This ensures that all critical user actions are tied to a specific device, enabling fraud detection and enforcing the one-account-per-device policy.

---

## 4. Client-Side Implementation (Flutter)
```

---

## 4. Client-Side Implementation (Flutter)

### 4.1 Optimistic Update Pattern

```dart
// In UserProvider
Future<void> recordGameWin({
  required int coinsReward,
  required String gameName,
  required int duration,
}) async {
  // ✅ Phase 1: Optimistic update (INSTANT)
  _userData!.coins += coinsReward;
  _userData!.totalGamesWon++;
  notifyListeners();  // UI updates immediately
  
  // Save to local cache (for offline persistence)
  await LocalStorageService.saveUserData(_userData!);
  
  // ✅ Phase 2: Queue for batch sync (background)
  await _queueEvent(
    type: 'GAME_WON',
    coins: coinsReward,
    metadata: {
      'gameName': gameName,
      'duration': duration,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    },
  );
  
  // ✅ Phase 3: Trigger periodic flush if needed
  _checkAndFlushQueue();
}

Future<void> _queueEvent({
  required String type,
  required int coins,
  required Map<String, dynamic> metadata,
}) async {
  final event = {
    'id': Uuid().v4(),
    'type': type,
    'coins': coins,
    'metadata': metadata,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'idempotencyKey': Uuid().v4(),
    'status': 'PENDING',
  };
  
  // Store in Hive
  final box = await Hive.openBox('earnplay_event_queue');
  final queue = box.get('events') as List<dynamic>? ?? [];
  queue.add(event);
  await box.put('events', queue);
}

Future<void> _checkAndFlushQueue() async {
  final box = await Hive.openBox('earnplay_event_queue');
  final queue = box.get('events') as List<dynamic>? ?? [];
  
  // Flush if: (1) 50 events, (2) 60 seconds passed, (3) app pausing
  if (queue.length >= 50 || _shouldFlushByTimer()) {
    await flushEventQueue();
  }
}

Future<void> flushEventQueue() async {
  try {
    final box = await Hive.openBox('earnplay_event_queue');
    final events = (box.get('events') as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    
    if (events.isEmpty) return;

    // Mark as INFLIGHT to prevent duplicate sends
    for (var event in events) {
      event['status'] = 'INFLIGHT';
    }
    await box.put('events', events);

    // Call Worker endpoint
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final idToken = await user.getIdToken();
    
    final response = await http.post(
      Uri.parse('${WorkerService.workerBaseUrl}/batch-events'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'userId': user.uid,
        'events': events,
      }),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('Worker timeout'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      // ✅ Server confirmed: Clear queue and update local balance
      _userData!.coins = data['newBalance'] ?? _userData!.coins;
      await box.delete('events');
      await LocalStorageService.saveUserData(_userData!);
      notifyListeners();
    } else {
      // Mark as PENDING again (retry on next flush)
      for (var event in events) {
        event['status'] = 'PENDING';
      }
      await box.put('events', events);
      throw Exception('Worker returned ${response.statusCode}');
    }
  } catch (e) {
    _error = 'Queue flush failed: $e';
    notifyListeners();
    // Silently fail (retry on next flush timer)
  }
}
```

### 4.2 Lifecycle Integration

```dart
class GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Start flush timer: every 60 seconds
    _flushTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => context.read<UserProvider>().flushEventQueue(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App going to background: FORCE flush immediately
      context.read<UserProvider>().flushEventQueue();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flushTimer?.cancel();
    super.dispose();
  }
}
```

---

## 5. Updated Firestore Schema

### 5.1 Users Collection

```
/users/{uid}
├── uid: string
├── email: string
├── coins: number (FieldValue.increment only)
├── createdAt: timestamp
├── referralCode: string (8 chars)
├── referredBy: string | null (Set by Worker only, transitions from null -> string)
├── totalGamesWon: number
├── totalAdsWatched: number
├── totalReferrals: number
├── totalCoinsEarned: number (lifetime)
├── totalCoinsWithdrawn: number
├── lastUpdated: timestamp
├── lastSyncAt: timestamp (← NEW: when Worker last synced events)
├── daily: {
│   ├── watchedAdsToday: number (0-10)
│   ├── lastAdResetDate: timestamp
│   ├── spinsRemaining: number (0-3)
│   └── lastSpinResetDate: timestamp
├── dailyStreak: {
│   ├── currentStreak: number
│   ├── lastCheckIn: timestamp
│   └── checkInDates: array (last 7 dates)
└── metadata: {
    ├── lastActiveAt: timestamp
    ├── deviceId: string (Bound deviceHash, set by Worker only)
    └── appVersion: string
```

### 5.4 Devices Collection

```
/devices/{deviceHash}
├── deviceHash: string (SHA256 hash of device_info_plus data)
├── uid: string (Firebase User ID)
├── createdAt: timestamp (When the device was first bound)
└── lastBoundAt: timestamp? (Optional: Last time this device was successfully bound/verified)
```

### 5.2 Monthly Stats (On-Demand, Merged)

```
/users/{uid}/monthly_stats/{YYYY-MM}
├── month: string (YYYY-MM)
├── gamesPlayed: number
├── coinsEarned: number (total from games, ads, etc.)
├── adsWatched: number
├── spinsUsed: number
├── lastUpdated: timestamp
└── (Worker creates on first event if missing)
```

### 5.3 Daily Action Log (Append-Only)

```
/users/{uid}/actions/{YYYY-MM-DD}
├── date: string
├── events: array [
│   {
│     "type": "GAME_WON",
│     "coins": 50,
│     "timestamp": 1700000000000,
│     "idempotencyKey": "uuid"
│   },
│   ...
│ ]
├── totalCoinsEarned: number (sum of events)
├── totalEvents: number (count of events)
└── lastUpdated: timestamp
```

---

## 6. Idempotency & Race Condition Prevention

### 6.1 Idempotency Key Generation

```dart
// Generate unique key per event (UUID-based)
String generateIdempotencyKey(String eventType) {
  return Uuid().v4();  // Globally unique
}

// Alternative: Deterministic key (for replay safety)
String generateDeterministicKey(String eventType, int coins, int timestamp) {
  return sha256.convert(
    utf8.encode('$eventType-$coins-$timestamp')
  ).toString();
}
```

### 6.2 Race Condition Scenarios & Mitigations

| Scenario | Problem | Mitigation |
|----------|---------|-----------|
| **Double Queue Flush** | User force-closes app twice → events sent 2x | Idempotency key + Redis cache (1 hour TTL) |
| **Duplicate Event in Batch** | Same event added to queue twice | Client-side event deduplication before flush |
| **Network Retry** | Timeout → client retries same batch | Idempotency cache returns cached response |
| **Concurrent Events** | User plays game while flush in progress | Mark events INFLIGHT (no new flush until done) |
| **Worker Timeout** | Worker takes >30s on batch | Mark PENDING, retry on next timer cycle |
| **Firestore Race** | Two fields update simultaneously | Use FieldValue.increment() for atomicity |
| **Monthly Stats Missing** | First event of month → stats doc missing | Worker uses SetOptions(merge: true) |

### 6.3 Idempotency Cache Strategy

```javascript
// In Worker: Redis-backed idempotency cache

const cacheKey = `idempotency:${userId}:${event.idempotencyKey}`;

// Check cache first
const cached = await ctx.env.CACHE.get(cacheKey);
if (cached) {
  // Return cached response (idempotent)
  return new Response(cached, { status: 200 });
}

// Process event
// ... (Firestore transaction)

// Cache result for future retries
await ctx.env.CACHE.put(
  cacheKey,
  JSON.stringify(responseData),
  { expirationTtl: 3600 }  // 1 hour = 3600 seconds
);
```

---

## 7. Worker Request Usage Estimate

### 7.1 Calculation (1,000 DAU)

```
Scenario 1: Baseline (All batched)

Active users per day: 1,000
Average events per user per day:
  - Games: 5 × 1 call = 5 events
  - Ads: 10 × 1 call = 10 events
  - Spins: 3 × 1 call = 3 events
  - Streak: 1 × 1 call = 1 event
  Total: 19 events/user/day

Total events/day: 1,000 × 19 = 19,000 events

Batch size: 50 events per request
Requests per user per day: 19,000 ÷ 50 = 380 events needed
But: Batching by time (60s) and size (50), average ~6 flushes/day per user

Total Worker requests/day:
  - Batch requests: 1,000 users × 6 flushes = 6,000 requests
  - Immediate (withdrawals, referrals): 200 requests
  - Health checks, retries: 50 requests
  TOTAL: ~6,250 requests/day

Cloudflare Pricing:
  Free plan: 100,000 requests/day ✅
  Paid plan (if scaled): $0.50 per million requests
  Cost at 6,250/day = $0 (free tier)
```

### 7.2 Comparison: Old vs New Architecture

| Metric | Old (Direct Writes) | New (Batched) | Reduction |
|--------|-------------------|----------------|-----------|
| **Worker Requests/Day** | 14,500 | 6,250 | -57% |
| **Firestore Writes/Day** | 14,500 | 200 | -99% |
| **Firestore Reads/Day** | 9,000 | 500 | -94% |
| **Monthly Cost** | $0.18 | $0 | ✅ Free |
| **DAU Capacity** | 1,000 | 10,000+ | 10x |

---

## 8. Scalability Plan

### 8.1 Stage 1: 1,000 DAU (Current)
- Batch interval: 60 seconds
- Max batch size: 50 events
- Worker requests: 6,250/day ✅ Within free tier

### 8.2 Stage 2: 5,000 DAU
- Batch interval: 60 seconds (same)
- Max batch size: 100 events (increased)
- Worker requests: ~30,000/day ✅ Still within free tier (100,000/day)

### 8.3 Stage 3: 20,000 DAU
- Batch interval: 120 seconds (relaxed, reduce requests)
- Max batch size: 200 events
- Worker requests: ~80,000/day ✅ Still within free tier

### 8.4 Stage 4: 100,000+ DAU
- Batch interval: 300 seconds (5 min)
- Max batch size: 500 events
- Worker requests: ~100,000/day → **Requires paid plan**
- Cost: $0.50 per 1M requests = ~$1.50/month for 100k DAU

---

## 9. Migration Plan

### Phase 1: Preparation (Days 1-3)

**Deliverables**:
- Update Flutter `UserProvider` with event queue
- Create Hive schema for event storage
- Add lifecycle observer to all game screens

**Code Changes**:
- `lib/providers/user_provider.dart`: Add `queueEvent()`, `flushEventQueue()`
- `lib/screens/games/tictactoe_screen.dart`: Add `WidgetsBindingObserver`
- `lib/screens/games/whack_mole_screen.dart`: Add `WidgetsBindingObserver`

**Testing**:
- Unit test: Event queuing and deduplication
- Integration test: Queue persistence across app restarts

### Phase 2: Worker Endpoint (Days 4-7)

**Deliverables**:
- Implement `/batch-events` Worker endpoint
- Add Redis idempotency caching
- Add Firestore batch transaction logic

**Code Changes**:
- `my-backend/src/endpoints/batch.js`: New endpoint
- `my-backend/src/utils/aggregator.js`: New helper functions
- `wrangler.toml`: Add Redis/KV bindings

**Testing**:
- Unit test: Event aggregation
- Integration test: Firestore transaction logic
- Load test: 1,000 concurrent users

### Phase 3: Client Integration (Days 8-10)

**Deliverables**:
- Update Flutter to call `/batch-events`
- Add retry logic with exponential backoff
- Add metrics/logging

**Code Changes**:
- `lib/services/worker_service.dart`: Add `batchEvents()` method
- `lib/utils/error_handler.dart`: Add retry logic

**Testing**:
- E2E test: Game → Queue → Flush → Firestore
- Network simulation: Test timeout and retry scenarios

### Phase 4: Gradual Rollout (Days 11-17)

**Week 1**: Soft launch to internal testers (10 users)
- Monitor queue behavior
- Check for stuck events
- Verify balance consistency

**Week 2**: Beta rollout (100 beta testers)
- Increase monitoring
- A/B test: 50% batch, 50% direct (fallback)
- Collect metrics on queue success rate

**Week 3**: Full rollout (all users)
- Enable batch mode for 100% of users
- Disable direct-write fallback after 1 week

### Phase 5: Monitoring & Optimization (Week 4+)

**Metrics to Track**:
- Queue success rate (%) = (successful flushes / total flushes) × 100
- Flush latency (seconds) = time from queue to Firestore write
- Event dedup rate (%) = (idempotency cache hits / total requests) × 100
- Worker error rate (%) = (errors / total requests) × 100

---

## 10. Firestore Security Rules (Updated)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isUserOwner(userId) {
      return request.auth.uid == userId;
    }
    
    function isWorker() {
      // Verify request comes from Cloudflare Worker
      // (uses custom claim or service account)
      // IMPORTANT: In a real deployment, ensure this is secured via
      // service account credentials or a robust custom claim check.
      return request.auth.token.email == 'cloudflare-worker-service-account@your-project-id.iam.gserviceaccount.com' ||
             request.auth.token.worker === true; // Custom claim for worker role
    }
    
    // ============================================
    // USERS COLLECTION
    // ============================================
    match /users/{userId} {
      // Client can READ own document
      allow read: if isUserOwner(userId);
      
      // Client can CREATE own document (signup only)
      // Worker creates the initial user document via /create-user endpoint
      allow create: if isWorker(); // Only Worker can create user documents
      
      // WORKER can UPDATE user document (coins, stats, referredBy, metadata.deviceId)
      allow update: if isWorker() &&
                       validateWorkerUserUpdate(resource.data, request.resource.data);
      
      // Client cannot UPDATE (only Worker can)
      allow update: if false;
      
      function validateWorkerUserUpdate(oldData, newData) {
        // Allow increment operations for coins and stats
        let coinsChanged = newData.coins != oldData.coins;
        let statsChanged = newData.daily != oldData.daily ||
                           newData.totalGamesWon != oldData.totalGamesWon ||
                           newData.totalAdsWatched != oldData.totalAdsWatched ||
                           newData.totalReferrals != oldData.totalReferrals ||
                           newData.totalCoinsEarned != oldData.totalCoinsEarned ||
                           newData.totalCoinsWithdrawn != oldData.totalCoinsWithdrawn;
        
        // Allow referredBy to transition from null to a string (only once)
        let referredByChanged = (oldData.referredBy == null && newData.referredBy is string);
        
        // Allow metadata.deviceId to be set or updated by worker
        let deviceIdChanged = newData.metadata.deviceId != oldData.metadata.deviceId;

        return (coinsChanged || statsChanged || referredByChanged || deviceIdChanged) &&
               newData.lastUpdated is timestamp;
      }
      
      // Subcollection: Monthly Stats
      match /monthly_stats/{monthYear} {
        allow read: if isUserOwner(userId);
        allow write: if isWorker();
      }
      
      // Subcollection: Daily Actions
      match /actions/{date} {
        allow read: if isUserOwner(userId);
        allow write: if isWorker();
      }
    }
    
    // ============================================
    // DEVICES COLLECTION (One-account-per-device enforcement)
    // ============================================
    match /devices/{deviceHash} {
      // Only Worker can create device mappings
      allow create: if isWorker() &&
                       request.resource.data.uid is string &&
                       request.resource.data.createdAt is timestamp &&
                       request.resource.data.deviceHash == deviceHash;
      
      // No client update/delete
      allow update, delete: if false;
      
      // Read by Worker only (for verification during /create-user, /bind-device)
      allow read: if isWorker();
    }

    // ============================================
    // WITHDRAWALS COLLECTION
    // ============================================
    match /withdrawals/{withdrawalId} {
      // Client can READ own withdrawal documents
      allow read: if isUserOwner(resource.data.userId);
      
      // Only Worker can CREATE/UPDATE withdrawal documents
      allow create, update: if isWorker();
      
      // Client cannot UPDATE/DELETE
      allow update, delete: if false;
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

## 11. Error Handling & Fallback Strategy

### 11.1 Queue Flush Failures

```dart
Future<void> flushEventQueueWithRetry() async {
  int retryCount = 0;
  const maxRetries = 3;
  const baseDelay = Duration(seconds: 5);
  
  while (retryCount < maxRetries) {
    try {
      await flushEventQueue();
      return;  // Success
    } catch (e) {
      retryCount++;
      
      if (retryCount >= maxRetries) {
        // After 3 retries, log error but don't crash
        _error = 'Queue flush failed after 3 retries. Will retry on next cycle.';
        notifyListeners();
        
        // Mark events as PENDING for next flush
        final box = await Hive.openBox('earnplay_event_queue');
        final events = box.get('events') as List<dynamic>? ?? [];
        for (var event in events) {
          event['status'] = 'PENDING';
        }
        await box.put('events', events);
        
        return;
      }
      
      // Exponential backoff: 5s, 10s, 20s
      final delay = baseDelay * (1 << retryCount);
      await Future.delayed(delay);
    }
  }
}
```

### 11.2 Worker Down Fallback

If Worker is unreachable for >10 minutes:

```dart
// Use direct Firestore writes as emergency fallback
if (!workerService.isHealthy()) {
  // Worker down: use direct write (not batched)
  // This temporarily increases Firestore writes but keeps app functional
  
  await firebaseService.updateUserCoins(uid, coinsReward);
  _userData!.coins += coinsReward;
  notifyListeners();
  
  // Log incident for debugging
  debugPrint('⚠️ Worker unavailable, using direct Firestore fallback');
}
```

---

## 12. Monitoring & Alerts

### 12.1 Key Metrics Dashboard

```
Real-time Metrics:
├─ Active Users: 1,234
├─ Pending Events (Queued): 5,678
├─ Worker Requests/Min: 45
├─ Batch Success Rate: 99.8%
├─ Avg Flush Latency: 1.2s
├─ Firestore Writes/Min: 10
└─ Estimated Monthly Cost: $0.02

Alerts (PagerDuty):
├─ 🔴 Worker Error Rate > 5% (Page on-call)
├─ 🟡 Queue Backlog > 100k events (Slack alert)
├─ 🟡 Flush Latency > 10s (Slack alert)
└─ 🔴 Firestore writes > 1000/min (Page on-call)
```

### 12.2 Logging Strategy

```dart
// In UserProvider
void _logQueueEvent(String type, int coins) {
  final log = {
    'timestamp': DateTime.now().toIso8601String(),
    'event_type': type,
    'coins': coins,
    'user_id': _userData!.uid,
    'queue_size': _eventQueue.length,
  };
  
  AnalyticsService.logEvent('event_queued', log);
}

void _logFlush(int eventCount, int coinsTotal) {
  AnalyticsService.logEvent('queue_flushed', {
    'timestamp': DateTime.now().toIso8601String(),
    'events_processed': eventCount,
    'total_coins': coinsTotal,
    'user_id': _userData!.uid,
  });
}
```

---

## 13. Summary of Changes

### What Changes

| Component | Old | New |
|-----------|-----|-----|
| **Client → Firestore** | Direct writes per action | Events queued locally |
| **Flush Timing** | Per action (~2s) | Every 60s or 50 events |
| **Worker Calls/Day** | 2,450 | 6,250 (batched) |
| **Firestore Writes/Day** | 14,500 | 200 |
| **User Experience** | Coins update in 2-5s | Coins update instantly (optimistic) |
| **Offline Support** | No | Yes (queue persists) |
| **Race Conditions** | Unmitigated | Prevented via idempotency |

### What Stays the Same

- UI/UX experience (coin updates feel instant)
- Firestore schema (mostly same fields)
- Security model (only authenticated users)
- Game mechanics (same rewards)

---

## 14. Success Criteria

✅ **Architecture Complete When**:

1. **Correctness**: No coin losses on network errors or app crashes
2. **Performance**: Batch flush completes in <2 seconds
3. **Cost**: Monthly cost stays at $0 (free tier)
4. **Scale**: Supports 10,000+ DAU without degradation
5. **Reliability**: 99.9% queue success rate
6. **User Experience**: Coins update instantly (optimistic)

---

## Appendix A: Comparison Matrix

### Cost Breakdown (1,000 DAU, 1 Month)

| Resource | Old | New | Savings |
|----------|-----|-----|---------|
| **Firestore Reads** | 270k @ $0.06/100k | 15k @ $0.06/100k | -$0.17 |
| **Firestore Writes** | 435k @ $0.18/100k | 6k @ $0.18/100k | -$0.77 |
| **Worker Requests** | 73.5k @ $0.50/1M | 187.5k @ $0.50/1M | +$0.09 |
| **Storage** | 2 GB @ $0.18/GB | 500 MB @ $0 | -$0.18 |
| **TOTAL** | $0.18 | $0.00 | **100% savings** ✅ |

---

**Document Status**: Ready for Implementation  
**Next Steps**: Begin Phase 1 (Flutter Provider updates)
