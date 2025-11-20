# EarnPlay Worker-Batched Architecture: Implementation Guide

**Status**: Ready to Implement  
**Difficulty**: High (requires careful coordination)  
**Estimated Duration**: 3 weeks  

---

## Quick Start: Architecture at a Glance

```
┌─ CLIENT ────────┐
│ Action Happens  │
│ (Game Win, Ad)  │
└────────┬────────┘
         │
      1. Optimistic Update (INSTANT)
         └─ Update coins in memory
         └─ Notify UI (refresh)
         │
      2. Queue Event (LOCAL)
         └─ Save to Hive storage
         └─ Add unique idempotency key
         │
      3. Batch Flush (EVERY 60s OR 50 events)
         ↓
┌─ CLOUDFLARE WORKER ─┐
│ /batch-events       │
│ ┌─────────────────┐ │
│ │ 1. Deduplicate  │ │  Check Redis cache
│ │ 2. Aggregate    │ │  Group events by type
│ │ 3. Transaction  │ │  Atomic Firestore write
│ │ 4. Cache Result │ │  Store in Redis (1h TTL)
│ └─────────────────┘ │
└─────────┬───────────┘
          │
      Returns { success: true, newBalance: 1500 }
          │
┌─ CLIENT ────────────┐
│ Clear queue         │  Remove synced events
│ Update balance      │  Reflect server value
└─ FIRESTORE ────────┐│
   /users/{uid}       ││  coins += delta
   /monthly_stats     ││  gamesPlayed++
   /actions/{date}    ││  events.append(...)
                      ││
                      v (1 write instead of 50!)
```

---

## Phase 1: Local Queue Implementation (Days 1-3)

### Step 1.1: Add Event Model

Create `lib/models/event_model.dart`:

```dart
import 'package:uuid/uuid.dart';

/// Represents a queued event (game win, ad watched, etc.)
class EventModel {
  final String id;
  final String type;  // GAME_WON, AD_WATCHED, SPIN_CLAIMED, STREAK_CLAIMED
  final int coins;
  final Map<String, dynamic> metadata;
  final int timestamp;  // milliseconds since epoch
  final String idempotencyKey;
  String status;  // PENDING, INFLIGHT, SYNCED

  EventModel({
    String? id,
    required this.type,
    required this.coins,
    required this.metadata,
    int? timestamp,
    String? idempotencyKey,
    this.status = 'PENDING',
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch,
        idempotencyKey = idempotencyKey ?? const Uuid().v4();

  /// Convert to JSON for HTTP/storage
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'coins': coins,
    'metadata': metadata,
    'timestamp': timestamp,
    'idempotencyKey': idempotencyKey,
    'status': status,
  };

  /// Convert from JSON
  factory EventModel.fromJson(Map<String, dynamic> json) => EventModel(
    id: json['id'],
    type: json['type'],
    coins: json['coins'],
    metadata: json['metadata'] ?? {},
    timestamp: json['timestamp'],
    idempotencyKey: json['idempotencyKey'],
    status: json['status'] ?? 'PENDING',
  );
}
```

### Step 1.2: Create Event Queue Manager

Create `lib/services/event_queue_service.dart`:

```dart
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import '../models/event_model.dart';

/// Manages local event queue with Hive persistence
class EventQueueService {
  static const String _boxName = 'earnplay_event_queue';
  static const int _maxBatchSize = 50;
  static const int _flushIntervalSeconds = 60;

  late Box<dynamic> _box;
  List<EventModel> _events = [];

  /// Initialize the queue (call on app startup)
  Future<void> initialize() async {
    _box = await Hive.openBox(_boxName);
    await _loadFromStorage();
  }

  /// Add event to queue
  Future<void> addEvent(EventModel event) async {
    _events.add(event);
    await _persistToStorage();
  }

  /// Get all pending events
  List<EventModel> getPendingEvents() {
    return _events.where((e) => e.status == 'PENDING').toList();
  }

  /// Get all events (for debugging)
  List<EventModel> getAllEvents() => List.from(_events);

  /// Get queue size
  int getQueueSize() => _events.length;

  /// Mark events as INFLIGHT (prevent duplicate sends)
  Future<void> markInflight(List<String> eventIds) async {
    for (var event in _events) {
      if (eventIds.contains(event.id)) {
        event.status = 'INFLIGHT';
      }
    }
    await _persistToStorage();
  }

  /// Mark events as SYNCED and remove from queue
  Future<void> markSynced(List<String> eventIds) async {
    _events.removeWhere((e) => eventIds.contains(e.id));
    await _persistToStorage();
  }

  /// Mark events as PENDING (for retry)
  Future<void> markPending(List<String> eventIds) async {
    for (var event in _events) {
      if (eventIds.contains(event.id)) {
        event.status = 'PENDING';
      }
    }
    await _persistToStorage();
  }

  /// Check if should flush by size
  bool shouldFlushBySize() => _events.length >= _maxBatchSize;

  /// Clear all events
  Future<void> clear() async {
    _events.clear();
    await _persistToStorage();
  }

  /// Load events from Hive
  Future<void> _loadFromStorage() async {
    try {
      final data = _box.get('events');
      if (data is List) {
        _events = data
            .map((e) => EventModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      debugPrint('Failed to load event queue: $e');
    }
  }

  /// Persist events to Hive
  Future<void> _persistToStorage() async {
    try {
      await _box.put('events', _events.map((e) => e.toJson()).toList());
    } catch (e) {
      debugPrint('Failed to persist event queue: $e');
    }
  }

  /// Cleanup
  Future<void> dispose() async {
    await _box.close();
  }
}
```

### Step 1.3: Update UserProvider to Use Queue

Modify `lib/providers/user_provider.dart`:

```dart
import '../services/event_queue_service.dart';

class UserProvider extends ChangeNotifier {
  final EventQueueService _eventQueue = EventQueueService();
  Timer? _flushTimer;

  @override
  Future<void> initialize(String uid) async {
    await _eventQueue.initialize();
    _startFlushTimer();
  }

  /// Record game win with optimistic update
  Future<void> recordGameWin({
    required int coinsReward,
    required String gameName,
    required int duration,
  }) async {
    if (_userData == null) return;

    // ✅ Phase 1: Optimistic update (INSTANT)
    _userData!.coins += coinsReward;
    _userData!.totalGamesWon++;
    notifyListeners();
    await LocalStorageService.saveUserData(_userData!);

    // ✅ Phase 2: Queue for batch sync
    await _eventQueue.addEvent(
      EventModel(
        type: 'GAME_WON',
        coins: coinsReward,
        metadata: {
          'gameName': gameName,
          'duration': duration,
        },
      ),
    );

    // ✅ Phase 3: Check if should flush
    if (_eventQueue.shouldFlushBySize()) {
      await flushEventQueue();
    }
  }

  /// Record ad watch with optimistic update
  Future<void> recordAdWatched({required int coinsReward}) async {
    if (_userData == null) return;

    // ✅ Phase 1: Optimistic update
    _userData!.coins += coinsReward;
    _userData!.watchedAdsToday++;
    _userData!.totalAdsWatched++;
    notifyListeners();
    await LocalStorageService.saveUserData(_userData!);

    // ✅ Phase 2: Queue for batch sync
    await _eventQueue.addEvent(
      EventModel(
        type: 'AD_WATCHED',
        coins: coinsReward,
        metadata: {'timestamp': DateTime.now().millisecondsSinceEpoch},
      ),
    );
  }

  /// Flush pending events to Worker
  Future<void> flushEventQueue() async {
    try {
      final pendingEvents = _eventQueue.getPendingEvents();
      if (pendingEvents.isEmpty) return;

      // Mark as INFLIGHT to prevent duplicate sends
      await _eventQueue.markInflight(pendingEvents.map((e) => e.id).toList());

      // Call Worker endpoint
      final result = await WorkerService().batchEvents(
        userId: _userData!.uid,
        events: pendingEvents,
      );

      if (result['success'] == true) {
        // ✅ Confirmed by server: Remove from queue
        await _eventQueue.markSynced(
          pendingEvents.map((e) => e.id).toList(),
        );

        // Update balance if server differs
        if (result['newBalance'] != null) {
          _userData!.coins = result['newBalance'];
        }

        notifyListeners();
      } else {
        // Mark as PENDING for retry
        await _eventQueue.markPending(
          pendingEvents.map((e) => e.id).toList(),
        );
        throw Exception('Worker returned success=false');
      }
    } catch (e) {
      _error = 'Failed to flush queue: $e';
      notifyListeners();
      // Silently fail (will retry on next timer)
    }
  }

  /// Start periodic flush timer (60 seconds)
  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => flushEventQueue(),
    );
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    _eventQueue.dispose();
    super.dispose();
  }
}
```

### Step 1.4: Add Lifecycle Observer to Game Screens

Update `lib/screens/games/tictactoe_screen.dart`:

```dart
class _TicTacToeScreenState extends State<TicTacToeScreen> 
    with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    super.dispose();
  }
}
```

---

## Phase 2: Worker Endpoint Implementation (Days 4-7)

### 2.0 Authentication & Authorization

As detailed in `WORKER_BATCHED_ARCHITECTURE.md` (Section 3.0), all immediate endpoints require `Authorization: Bearer <idToken>`. The Worker will verify this token to derive the `uid` for all operations. Client-sent `uid`s are ignored.

### 2.0.1 Rate Limiting Design

To prevent abuse and ensure fair usage, immediate endpoints will implement per-UID and per-IP rate limits using Cloudflare KV / Durable Objects.

*   **Mechanism**: For each incoming request to an immediate endpoint, the Worker will:
    1.  Extract the `uid` from the verified `idToken` and the client's IP address (`CF-Connecting-IP` header).
    2.  Increment counters in Cloudflare KV for `rate:uid:{window}:{uid}` and `rate:ip:{window}:{ip}`.
    3.  If a counter exceeds its configured threshold within the `window` (e.g., 60 seconds), the request is rejected.
*   **KV Keys & TTLs**:
    *   `rate:uid:{window}:{uid}`: Stores the count of requests for a specific user within a time window.
        *   **TTL**: Matches the `window` duration (e.g., 60 seconds).
    *   `rate:ip:{window}:{ip}`: Stores the count of requests for a specific IP address within a time window.
        *   **TTL**: Matches the `window` duration (e.g., 60 seconds).
*   **Default Limits (Configurable)**:
    *   Per-UID: 10 requests per minute
    *   Per-IP: 50 requests per minute
*   **Responses**: If a rate limit is exceeded, the Worker will return an `HTTP 429 Too Many Requests` status code. The response body will include an error message, and the `Retry-After` header will indicate how many seconds the client should wait before retrying.

```javascript
// Example Rate Limiting Helper (Worker-side)
async function checkRateLimits(uid, ip, kvBinding, endpointName = 'default') {
  const now = Date.now();
  const windowMs = 60 * 1000; // 60 seconds
  const uidLimit = 10; // 10 requests per minute per UID
  const ipLimit = 50;  // 50 requests per minute per IP

  let limited = false;
  let retryAfter = 0;

  // Check UID rate limit
  if (uid) {
    const uidKey = `rate:uid:${endpointName}:${uid}`;
    let uidCount = parseInt(await kvBinding.get(uidKey) || '0');
    if (uidCount >= uidLimit) {
      limited = true;
      retryAfter = Math.max(retryAfter, (parseInt(await kvBinding.get(uidKey, { type: 'metadata' })) - now) / 1000);
    } else {
      await kvBinding.put(uidKey, (uidCount + 1).toString(), { expirationTtl: windowMs / 1000 });
    }
  }

  // Check IP rate limit
  if (ip) {
    const ipKey = `rate:ip:${endpointName}:${ip}`;
    let ipCount = parseInt(await kvBinding.get(ipKey) || '0');
    if (ipCount >= ipLimit) {
      limited = true;
      retryAfter = Math.max(retryAfter, (parseInt(await kvBinding.get(ipKey, { type: 'metadata' })) - now) / 1000);
    } else {
      await kvBinding.put(ipKey, (ipCount + 1).toString(), { expirationTtl: windowMs / 1000 });
    }
  }

  return { limited, retryAfter: Math.ceil(retryAfter) };
}
```

### Step 2.1: Create Batch Events Endpoint

Create `my-backend/src/endpoints/batch.js`:

```javascript
import admin from 'firebase-admin';

/**
 * POST /batch-events
 * 
 * Processes a batch of events from a single user
 * Returns aggregated results and updated balance
 */
export async function handleBatchEvents(request, db, userId, ctx) {
  try {
    const body = await request.json();
    const { events } = body;

    // Validate input
    if (!events || !Array.isArray(events) || events.length === 0) {
      return errorResponse('Events array is empty or missing', 400);
    }

    if (events.length > 500) {
      return errorResponse('Too many events (max 500)', 400);
    }

    // Validate each event
    for (const event of events) {
      if (!event.type || event.coins === undefined) {
        return errorResponse(`Invalid event: ${JSON.stringify(event)}`, 400);
      }
      if (!event.idempotencyKey) {
        return errorResponse('Missing idempotencyKey', 400);
      }
    }

    // Check idempotency cache
    const uniqueIdempotencyKeys = [...new Set(events.map(e => e.idempotencyKey))];
    const cachedResults = {};
    const newEvents = [];

    for (const event of events) {
      const cacheKey = `idempotency:event:${userId}:${event.idempotencyKey}`; // Use KV_IDEMPOTENCY
      const cached = await ctx.env.KV_IDEMPOTENCY.get(cacheKey);

      if (cached) {
        cachedResults[event.idempotencyKey] = JSON.parse(cached);
      } else {
        newEvents.push(event);
      }
    }

    // If all events cached, return early
    if (newEvents.length === 0 && Object.keys(cachedResults).length > 0) {
      const cachedResponse = Object.values(cachedResults)[0];
      return successResponse({
        success: true,
        processedCount: 0,
        newBalance: cachedResponse.newBalance,
        isCached: true,
      });
    }

    // Aggregate new events
    const aggregated = aggregateEvents(newEvents);

    // Atomic Firestore transaction
    let newBalance;
    try {
      await db.runTransaction(async (transaction) => {
        const userRef = db.collection('users').doc(userId);
        const userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
          throw new Error('User not found');
        }

        const userData = userDoc.data();
        const currentBalance = userData.coins || 0;
        const today = new Date().toISOString().split('T')[0];
        const thisMonth = today.substring(0, 7);

        // Validate daily limits
        const adsWatchedToday = userData.daily?.watchedAdsToday || 0;
        const newAdsCount = aggregated.eventCounts.AD_WATCHED || 0;

        if (adsWatchedToday + newAdsCount > 10) {
          throw new Error('Daily ad limit exceeded');
        }

        // Calculate new balance
        newBalance = currentBalance + aggregated.totalCoins;

        // Update user document
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

        // Update monthly stats
        const monthlyStatsRef = userRef.collection('monthly_stats').doc(thisMonth);
        transaction.set(
          monthlyStatsRef,
          {
            month: thisMonth,
            gamesPlayed: admin.firestore.FieldValue.increment(
              aggregated.eventCounts.GAME_WON || 0
            ),
            coinsEarned: admin.firestore.FieldValue.increment(aggregated.totalCoins),
            adsWatched: admin.firestore.FieldValue.increment(
              aggregated.eventCounts.AD_WATCHED || 0
            ),
            spinsUsed: admin.firestore.FieldValue.increment(
              aggregated.eventCounts.SPIN_CLAIMED || 0
            ),
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        // Append to daily action log
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
            totalEvents: admin.firestore.FieldValue.increment(newEvents.length),
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      });
    } catch (txError) {
      return errorResponse(`Firestore error: ${txError.message}`, 500);
    }

    // Build response
    const responseData = {
      success: true,
      processedCount: newEvents.length,
      newBalance,
      deltaCoins: aggregated.totalCoins,
      stats: aggregated.eventCounts,
      timestamp: Date.now(),
    };

    // Cache all idempotency keys
    for (const event of newEvents) {
      const cacheKey = `idempotency:event:${userId}:${event.idempotencyKey}`;
      await ctx.env.KV_IDEMPOTENCY.put( // Use KV_IDEMPOTENCY
        cacheKey,
        JSON.stringify(responseData),
        { expirationTtl: 3600 }  // 1 hour
      );
    }

    return successResponse(responseData);

  } catch (error) {
    console.error('[/batch-events] Error:', error);
    return errorResponse(error.message || 'Unknown error', 500);
  }
}

/**
 * Helper: Aggregate events by type
 */
function aggregateEvents(events) {
  const eventCounts = {};
  const allEvents = [];
  let totalCoins = 0;

  for (const event of events) {
    eventCounts[event.type] = (eventCounts[event.type] || 0) + 1;
    totalCoins += event.coins || 0;
    allEvents.push(event);
  }

  return {
    totalCoins,
    eventCounts,
    allEvents,
  };
}

function successResponse(data) {
  return new Response(JSON.stringify(data), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

function errorResponse(message, status) {
  return new Response(JSON.stringify({ success: false, error: message }), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

### Step 2.2: Implement /create-user Endpoint

Create `my-backend/src/endpoints/create_user.js`:

```javascript
import admin from 'firebase-admin';

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
  // userId is derived from verified idToken (see 2.0)
  try {
    const body = await request.json();
    const { deviceHash, idempotencyKey } = body;

    if (!deviceHash) {
      return errorResponse("deviceHash is required", 400);
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
      return errorResponse("Device already bound to an account.", 409);
    }
    return errorResponse(error.message || 'Unknown error', 500);
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
```

### Step 2.3: Implement /request-withdrawal Endpoint

Update `my-backend/src/endpoints/withdrawal.js` (or create if it doesn't exist):

```javascript
import admin from 'firebase-admin';

/**
 * POST /request-withdrawal (IMMEDIATE - No batching)
 * 
 * Purpose: Handle user withdrawal requests with fraud checks and idempotency.
 * 
 * Request body:
 * {
 *   "amount": 500,
 *   "method": "paypal",
 *   "paymentDetails": { "email": "user@example.com" },
 *   "deviceHash": "sha256_hash_of_device_info",
 *   "idempotencyKey": "uuid_for_this_request"
 * }
 * 
 * Headers:
 *   Authorization: Bearer <idToken>
 * 
 * Response:
 * {
 *   "success": true,
 *   "withdrawalId": "firestore_doc_id",
 *   "newBalance": 9500
 * }
 * 
 * Error Responses:
 *   400 Bad Request: Invalid amount, missing deviceHash
 *   401 Unauthorized: Invalid idToken
 *   403 Forbidden: Fraud detected, insufficient balance, withdrawal limits
 *   429 Too Many Requests: Rate limit exceeded
 *   500 Internal Server Error: Firestore transaction failed, etc.
 */
export async function handleWithdrawal(request, db, userId, ctx) {
  // userId is derived from verified idToken (see 2.0)
  try {
    const body = await request.json();
    const { amount, method, paymentDetails, deviceHash, idempotencyKey } = body;

    // 1. Input Validation
    if (!amount || amount < 500 || amount > 100000) {
      return errorResponse('Invalid withdrawal amount (500-100000 coins)', 400);
    }
    if (!method || !paymentDetails || !deviceHash || !idempotencyKey) {
      return errorResponse('Missing required fields (method, paymentDetails, deviceHash, idempotencyKey)', 400);
    }

    // 2. Rate Limiting (per-UID and per-IP)
    const ip = request.headers.get('CF-Connecting-IP');
    const rateLimitResult = await checkRateLimits(userId, ip, ctx.env.KV_RATE_COUNTERS, 'request_withdrawal');
    if (rateLimitResult.limited) {
      return new Response(JSON.stringify({
        success: false,
        error: `Rate limit exceeded. Try again in ${rateLimitResult.retryAfter} seconds.`
      }), { status: 429, headers: { 'Retry-After': rateLimitResult.retryAfter.toString() } });
    }

    // 3. Idempotency Check
    const idempotencyCacheKey = `idempotency:withdrawal:${userId}:${idempotencyKey}`;
    const cachedResponse = await ctx.env.KV_IDEMPOTENCY.get(idempotencyCacheKey);
    if (cachedResponse) {
      return new Response(cachedResponse, { status: 200 });
    }

    let withdrawalId;
    let newBalance;

    // 4. Atomic Firestore Transaction (Worker-only write)
    await db.runTransaction(async (txn) => {
      const userRef = db.collection('users').doc(userId);
      const userDoc = await txn.get(userRef);
      
      if (!userDoc.exists) {
        throw new Error('User not found');
      }
      const userData = userDoc.data();

      // Verify device binding
      const deviceRef = db.collection('devices').doc(deviceHash);
      const deviceDoc = await txn.get(deviceRef);
      if (!deviceDoc.exists || deviceDoc.data().uid !== userId) {
        throw new Error('Device not bound to this user or invalid deviceHash.');
      }

      // 5. Fraud Checks & Business Rules
      const currentCoins = userData.coins || 0;
      if (currentCoins < amount) {
        throw new Error('Insufficient balance for withdrawal.');
      }
      const MIN_WITHDRAWAL = 500; // Default minimum withdrawal amount
      if (amount < MIN_WITHDRAWAL) {
        throw new Error(`Withdrawal amount must be at least ${MIN_WITHDRAWAL} coins.`);
      }

      const lastWithdrawalAt = userData.lastWithdrawalAt?.toDate();
      const now = new Date();
      if (lastWithdrawalAt && (now.getTime() - lastWithdrawalAt.getTime()) < (24 * 60 * 60 * 1000)) {
        throw new Error('You can only request one withdrawal every 24 hours.');
      }
      
      const withdrawalsCountToday = userData.withdrawalsCountToday || 0; // Assuming this is reset daily
      if (withdrawalsCountToday >= 1) { // Limit to 1 withdrawal per day
        throw new Error('Daily withdrawal limit exceeded.');
      }

      // Additional fraud checks (e.g., user activity thresholds, riskScore)
      // Example: if (userData.totalGamesWon < 10 || userData.totalAdsWatched < 50) { throw new Error('Insufficient activity for withdrawal'); }
      // Example: if (userData.riskScore > 5) { throw new Error('High risk score, withdrawal blocked'); }

      // 6. Create Withdrawal Document
      const newWithdrawalRef = db.collection('withdrawals').doc();
      withdrawalId = newWithdrawalRef.id;
      txn.set(newWithdrawalRef, {
        id: withdrawalId,
        userId: userId,
        amount: amount,
        method: method,
        paymentDetails: paymentDetails,
        status: 'PENDING', // PENDING, APPROVED, REJECTED, COMPLETED
        requestedAt: admin.firestore.FieldValue.serverTimestamp(),
        deviceHash: deviceHash,
        ipAddress: ip,
      });

      // 7. Deduct Coins and Update User Stats
      newBalance = currentCoins - amount;
      txn.update(userRef, {
        coins: admin.firestore.FieldValue.increment(-amount),
        totalCoinsWithdrawn: admin.firestore.FieldValue.increment(amount),
        lastWithdrawalAt: admin.firestore.FieldValue.serverTimestamp(),
        withdrawalsCountToday: admin.firestore.FieldValue.increment(1), // Increment daily count
      });
    });

    const responseData = JSON.stringify({
      success: true,
      withdrawalId: withdrawalId,
      newBalance: newBalance,
    });

    // Cache idempotency result (TTL 24-72 hours)
    await ctx.env.KV_IDEMPOTENCY.put(idempotencyCacheKey, responseData, { expirationTtl: 24 * 3600 }); // 24 hours

    return new Response(responseData, { status: 200 });

  } catch (error) {
    console.error('[/request-withdrawal] Error:', error);
    let statusCode = 500;
    if (error.message.includes('Insufficient balance') || error.message.includes('Invalid withdrawal amount') || error.message.includes('withdrawal limit') || error.message.includes('activity for withdrawal') || error.message.includes('risk score')) {
      statusCode = 403; // Forbidden for business logic/fraud
    } else if (error.message.includes('Device not bound')) {
      statusCode = 400; // Bad Request for device issue
    }
    return errorResponse(error.message || 'Unknown error', statusCode);
  }
}

### Step 2.4: Implement /claim-referral Endpoint

Create `my-backend/src/endpoints/referral.js`:

```javascript
import admin from 'firebase-admin';

/**
 * POST /claim-referral (IMMEDIATE - No batching)
 * 
 * Purpose: Handle referral code claims with fraud checks and idempotency.
 * 
 * Request body:
 * {
 *   "referralCode": "ABCDEF12",
 *   "deviceHash": "sha256_hash_of_device_info",
 *   "idempotencyKey": "uuid_for_this_request"
 * }
 * 
 * Headers:
 *   Authorization: Bearer <idToken>
 * 
 * Response:
 * {
 *   "success": true,
 *   "message": "Referral claimed successfully!",
 *   "newBalance": 1050 // New balance for the referred user
 * }
 * 
 * Error Responses:
 *   400 Bad Request: Invalid referral code, missing deviceHash
 *   401 Unauthorized: Invalid idToken
 *   403 Forbidden: Fraud detected, already referred, self-referral
 *   404 Not Found: Referral code does not exist
 *   429 Too Many Requests: Rate limit exceeded
 *   500 Internal Server Error: Firestore transaction failed, etc.
 */
export async function handleReferral(request, db, userId, ctx) {
  // userId is derived from verified idToken (see 2.0)
  try {
    const body = await request.json();
    const { referralCode, deviceHash, idempotencyKey } = body;

    // 1. Input Validation
    if (!referralCode || !deviceHash || !idempotencyKey) {
      return errorResponse('Missing required fields (referralCode, deviceHash, idempotencyKey)', 400);
    }

    // 2. Rate Limiting (per-UID and per-IP)
    const ip = request.headers.get('CF-Connecting-IP');
    const rateLimitResult = await checkRateLimits(userId, ip, ctx.env.KV_RATE_COUNTERS, 'claim_referral');
    if (rateLimitResult.limited) {
      return new Response(JSON.stringify({
        success: false,
        error: `Rate limit exceeded. Try again in ${rateLimitResult.retryAfter} seconds.`
      }), { status: 429, headers: { 'Retry-After': rateLimitResult.retryAfter.toString() } });
    }

    // 3. Idempotency Check
    const idempotencyCacheKey = `idempotency:referral:${userId}:${idempotencyKey}`;
    const cachedResponse = await ctx.env.KV_IDEMPOTENCY.get(idempotencyCacheKey);
    if (cachedResponse) {
      return new Response(cachedResponse, { status: 200 });
    }

    let newReferredUserBalance;

    // 4. Atomic Firestore Transaction (Worker-only write)
    await db.runTransaction(async (txn) => {
      const referredUserRef = db.collection('users').doc(userId);
      const referredUserDoc = await txn.get(referredUserRef);
      if (!referredUserDoc.exists) {
        throw new Error('Referred user not found.');
      }
      const referredUserData = referredUserDoc.data();

      // Verify device binding for referred user
      const referredUserDeviceRef = db.collection('devices').doc(deviceHash);
      const referredUserDeviceDoc = await txn.get(referredUserDeviceRef);
      if (!referredUserDeviceDoc.exists || referredUserDeviceDoc.data().uid !== userId) {
        throw new Error('Device not bound to this user or invalid deviceHash for referred user.');
      }

      // Validate referral code and find referrer
      const referrerQuery = db.collection('users').where('referralCode', '==', referralCode).limit(1);
      const referrerSnapshot = await txn.get(referrerQuery);

      if (referrerSnapshot.empty) {
        throw new Error('Referral code not found.');
      }
      const referrerDoc = referrerSnapshot.docs[0];
      const referrerUid = referrerDoc.id;
      const referrerData = referrerDoc.data();

      // 5. Fraud Checks & Business Rules
      if (referrerUid === userId) {
        throw new Error('Self-referral is not allowed.');
      }
      if (referredUserData.referredBy !== null) {
        throw new Error('User has already claimed a referral.');
      }

      // Fraud Scoring
      let fraudScore = 0;
      const now = Date.now();
      const X_HOURS = 48 * 3600 * 1000; // 48 hours in milliseconds

      // +1 if referredUser.createdAt is older than X hours (default 48h)
      if (now - referredUserData.createdAt.toDate().getTime() > X_HOURS) {
        fraudScore += 1;
      }
      // +1 if hasEarnedBefore == true (assuming a field for this)
      if (referredUserData.hasEarnedBefore === true) { // Placeholder
        fraudScore += 1;
      }
      // +1 if adsWatched > 0 or spinsUsed > 0 (already active)
      if ((referredUserData.totalAdsWatched || 0) > 0 || (referredUserData.totalSpinsUsed || 0) > 0) { // Placeholder
        fraudScore += 1;
      }

      // Device/IP checks (more advanced fraud detection)
      // +1 if same IP as referrer (requires storing IP on user doc or checking device history)
      // +1 if repeated deviceHash (requires checking device history for multiple UIDs)
      // +1 if multiple referrals from same IP in short window (requires KV counter for IP referrals)

      if (fraudScore > 3) {
        // Block referral rewards for high fraud score
        console.warn(`Referral fraud detected for user ${userId}, score: ${fraudScore}. Logging for manual review.`);
        // Log for manual review (e.g., to a separate fraud collection)
        db.collection('fraud_logs').add({
          type: 'referral',
          userId: userId,
          referrerUid: referrerUid,
          referralCode: referralCode,
          deviceHash: deviceHash,
          ipAddress: ip,
          fraudScore: fraudScore,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          action: 'BLOCKED_REWARD',
        });
        throw new Error('Referral blocked due to potential fraud.');
      }

      const REFERRAL_REWARD_COINS = 100; // Example reward

      // 6. Update Referred User
      newReferredUserBalance = referredUserData.coins + REFERRAL_REWARD_COINS;
      txn.update(referredUserRef, {
        coins: admin.firestore.FieldValue.increment(REFERRAL_REWARD_COINS),
        referredBy: referrerUid,
        totalCoinsEarned: admin.firestore.FieldValue.increment(REFERRAL_REWARD_COINS),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 7. Update Referrer User
      txn.update(referrerDoc.ref, {
        coins: admin.firestore.FieldValue.increment(REFERRAL_REWARD_COINS),
        totalReferrals: admin.firestore.FieldValue.increment(1),
        totalCoinsEarned: admin.firestore.FieldValue.increment(REFERRAL_REWARD_COINS),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    const responseData = JSON.stringify({
      success: true,
      message: "Referral claimed successfully!",
      newBalance: newReferredUserBalance,
    });

    // Cache idempotency result (TTL 24 hours)
    await ctx.env.KV_IDEMPOTENCY.put(idempotencyCacheKey, responseData, { expirationTtl: 24 * 3600 }); // 24 hours

    return new Response(responseData, { status: 200 });

  } catch (error) {
    console.error('[/claim-referral] Error:', error);
    let statusCode = 500;
    if (error.message.includes('Referral code not found')) {
      statusCode = 404;
    } else if (error.message.includes('Self-referral') || error.message.includes('already claimed') || error.message.includes('potential fraud')) {
      statusCode = 403; // Forbidden for business logic/fraud
    } else if (error.message.includes('Device not bound')) {
      statusCode = 400; // Bad Request for device issue
    }
    return errorResponse(error.message || 'Unknown error', statusCode);
  }
}

### Step 2.5: Update Worker Router

Update `my-backend/src/index.js`:

```javascript
import { handleBatchEvents } from './endpoints/batch.js';
import { handleCreateUser } from './endpoints/create_user.js'; // NEW
import { handleWithdrawal } from './endpoints/withdrawal.js'; // UPDATED
import { handleReferral } from './endpoints/referral.js';     // NEW

export default {
  async fetch(request, env, ctx) {
    if (request.method === 'OPTIONS') {
      return handleCorsPreFlight();
    }

    if (request.method !== 'POST') {
      return addCorsHeaders(handleError('Method not allowed', 405));
    }

    try {
      const db = initFirebase(env.FIREBASE_CONFIG);
      // userId is derived from verified idToken for all authenticated requests
      const userId = await verifyFirebaseToken(request.headers.get('Authorization'), env.FIREBASE_CONFIG);

      const url = new URL(request.url);
      const path = url.pathname;

      let response;

      switch (path) {
        case '/create-user':
          response = await handleCreateUser(request, db, userId, ctx);
          break;
        case '/batch-events':
          response = await handleBatchEvents(request, db, userId, ctx);
          break;
        case '/request-withdrawal':
          response = await handleWithdrawal(request, db, userId, ctx);
          break;
        case '/claim-referral':
          response = await handleReferral(request, db, userId, ctx);
          break;
        // case '/verify-ad': // This endpoint might be deprecated if ad rewards are batched
        //   response = await handleAdReward(request, db, userId, ctx);
        //   break;
        default:
          response = handleError(`Endpoint not found: ${path}`, 404);
      }

      return addCorsHeaders(response);
    } catch (error) {
      console.error('[Worker Error]', error);
      // Handle specific authentication errors
      if (error.message === 'Firebase ID token has expired.' || error.message === 'Firebase ID token is invalid.') {
        return addCorsHeaders(errorResponse('INVALID_TOKEN', 401));
      }
      return addCorsHeaders(handleError('Internal server error', 500));
    }
  }
};
```

---

## Phase 3: Flutter Integration (Days 8-10)

### Step 3.1: Update WorkerService

Add to `lib/services/worker_service.dart`:

```dart
/// Batch send multiple events to Worker
Future<Map<String, dynamic>> batchEvents({
  required String userId,
  required List<EventModel> events,
}) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final idToken = await user.getIdToken();

    final response = await http
        .post(
          Uri.parse('$workerBaseUrl/batch-events'),
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'userId': userId,
            'events': events.map((e) => e.toJson()).toList(),
          }),
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () =>
              throw TimeoutException('Worker batch request timed out'),
        );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Batch request failed');
    }
  } on SocketException catch (e) {
    throw Exception('Network error: ${e.message}');
  } catch (e) {
    rethrow;
  }
}
```

### Step 3.2: Update Game Screens

Update `lib/screens/games/tictactoe_screen.dart`:

```dart
// On game end, record result
void _gameEnd({required bool won, required int duration}) {
  if (won) {
    final reward = _calculateReward();
    context.read<UserProvider>().recordGameWin(
      coinsReward: reward,
      gameName: 'tictactoe',
      duration: duration,
    );
  }
}
```

Update `lib/screens/watch_earn_screen.dart`:

```dart
// On ad reward callback
void _onAdRewarded() {
  context.read<UserProvider>().recordAdWatched(
    coinsReward: 5,  // Per ad
  );
}
```

---

## Phase 4: Testing Plan

### Unit Tests

```dart
// test/services/event_queue_service_test.dart

void main() {
  group('EventQueueService', () {
    late EventQueueService queue;

    setUp(() async {
      await Hive.deleteBoxFromDisk('test_queue');
      queue = EventQueueService();
      await queue.initialize();
    });

    test('adds event to queue', () async {
      final event = EventModel(
        type: 'GAME_WON',
        coins: 50,
        metadata: {},
      );
      
      await queue.addEvent(event);
      
      expect(queue.getQueueSize(), 1);
    });

    test('flushes events correctly', () async {
      final event1 = EventModel(type: 'GAME_WON', coins: 50, metadata: {});
      final event2 = EventModel(type: 'AD_WATCHED', coins: 5, metadata: {});
      
      await queue.addEvent(event1);
      await queue.addEvent(event2);
      
      await queue.markInflight([event1.id, event2.id]);
      expect(queue.getPendingEvents().length, 0);
      
      await queue.markSynced([event1.id, event2.id]);
      expect(queue.getQueueSize(), 0);
    });

    test('persists events to Hive', () async {
      final event = EventModel(type: 'GAME_WON', coins: 50, metadata: {});
      await queue.addEvent(event);
      
      final queue2 = EventQueueService();
      await queue2.initialize();
      
      expect(queue2.getQueueSize(), 1);
    });
  });
}
```

### Integration Tests

```dart
// test_driver/batch_sync_test.dart

void main() {
  group('Batch Sync E2E', () {
    testWidgets('records game win and syncs to Firestore', (tester) async {
      await tester.pumpWidget(const MyApp());
      
      // Navigate to game screen
      await tester.tap(find.byIcon(Icons.sports_esports));
      await tester.pumpAndSettle();
      
      // Play game (mock with taps)
      // Game wins, coins increase optimistically
      expect(find.text('1050 coins'), findsOneWidget);
      
      // Trigger flush manually
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);  // Custom for testing
      await tester.pumpAndSettle(const Duration(seconds: 2));
      
      // Verify Firestore updated
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(testUserId)
          .get();
      
      expect(userDoc['coins'], 1050);
    });
  });
}

### New Integration Test Requirements

*   **`create-user` collision**: Test that attempting to create a user with a `deviceHash` already bound to another user (or the same user) results in a `409 Conflict`.
*   **Referral race**: Test concurrent `/claim-referral` requests for the same user/referral code, ensuring only one succeeds due to idempotency and `referredBy` check.
*   **Withdrawal idempotency**: Test that repeated `/request-withdrawal` calls with the same `idempotencyKey` only process once.
*   **Rate limits**: Test that exceeding per-UID and per-IP rate limits for immediate endpoints results in `429 Too Many Requests` with `Retry-After` header.
*   **Abuse scenario tests**:
    *   Same device signups: Attempt multiple `/create-user` calls from the same `deviceHash` to ensure the one-account-per-device policy is enforced.
    *   Mass referrals from same IP: Simulate multiple users claiming referrals from the same IP address to trigger fraud scoring and blocking.
*   **Migration tests for `bind-device`**: (To be added in MIGRATION_DEEP_DIVE.md)

---

## Firestore Security Rules (Copy-Paste Ready)

This block should be copied directly into your `firestore.rules` file. It enforces the one-account-per-device policy, worker-only writes for sensitive operations, and read access for owners.

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
      
      // Only Worker can CREATE user documents (via /create-user endpoint)
      allow create: if isWorker();
      
      // Only Worker can UPDATE user document (coins, stats, referredBy, metadata.deviceId)
      allow update: if isWorker() &&
                       validateWorkerUserUpdate(resource.data, request.resource.data);
      
      // Client cannot UPDATE
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
        
        // Enforce that referredBy transitions only from null to a string (only once)
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

## Deployment Checklist

- [ ] Phase 1 code ready and tested locally
- [ ] Phase 2 Worker endpoint deployed to staging
- [ ] Phase 2 integration tests passing
- [ ] Phase 3 Flutter code ready
- [ ] E2E tests passing on staging environment
- [ ] Staged rollout plan documented
- [ ] Monitoring and alerts set up
- [ ] Fallback procedure tested
- [ ] Documentation updated
- [ ] Team trained on new architecture

---

## Monitoring During Rollout

### Key Metrics to Track

```
Real-time Dashboard:
├─ Queue Size: Should stay <500 events
├─ Batch Success Rate: Should be >99%
├─ Worker Latency: Should be <2 seconds
├─ Sync Latency: Should be <5 seconds
├─ Coin Discrepancies: Should be 0
└─ Error Rate: Should be <0.1%
```

### Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Queue stuck at 500 events | Firestore errors | Check Firestore quota, Worker logs |
| Coins not updating | Network issue | Check connectivity, retry logic |
| Duplicate coins | Idempotency cache miss | Increase Redis TTL to 24h |
| Worker timeout | Too many batch requests | Reduce batch frequency or size |

---

**Ready to proceed? Start with Phase 1!**
