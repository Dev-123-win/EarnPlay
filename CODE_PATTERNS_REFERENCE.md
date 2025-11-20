# EarnPlay Architecture: Code Patterns & Reference

**Quick Access Guide for Developers**

---

## 1. Event Queueing Pattern

### When to Queue vs When to Send Immediately

```
QUEUE (Batched at 60s):
├─ recordGameWin()         → Queue
├─ recordAdWatched()       → Queue
├─ recordSpinClaimed()     → Queue
└─ recordStreakClaimed()   → Queue (but send immediately at midnight)

SEND IMMEDIATELY (No batching):
├─ requestWithdrawal()     → User expects instant feedback
├─ claimReferral()         → User expects instant feedback
└─ Emergency payouts       → Fraud detection triggers
```

### Code Template: Queued Event

```dart
Future<void> recordGameWin({required int coins}) async {
  // STEP 1: Update UI optimistically (INSTANT)
  _userData!.coins += coins;
  notifyListeners();

  // STEP 2: Persist locally
  await LocalStorageService.saveUserData(_userData!);

  // STEP 3: Queue for batch
  await _eventQueue.addEvent(
    EventModel(
      type: 'GAME_WON',
      coins: coins,
      metadata: {'gameName': 'tictactoe'},
    ),
  );

  // STEP 4: Check if should flush (no await - fire and forget)
  if (_eventQueue.shouldFlushBySize()) {
    unawaited(_flushEventQueue());
  }
}
```

### Code Template: Immediate Event

```dart
Future<void> requestWithdrawal({required int amount}) async {
  // STEP 1: Validate locally
  if (_userData!.coins < amount) {
    throw Exception('Insufficient balance');
  }

  // STEP 2: Call Worker immediately (no queue)
  final result = await WorkerService().requestWithdrawal(
    userId: _userData!.uid,
    amount: amount,
    idempotencyKey: Uuid().v4(),  // ← CRITICAL
  );

  // STEP 3: Update if successful
  if (result['success']) {
    _userData!.coins = result['newBalance'];
    notifyListeners();
  }
}
```

---

## 1.1 Client-Side Device Hashing

To support the "one account per device" policy, clients must compute a unique `deviceHash` for the current device. This hash is sent to the Worker for verification and binding.

### Code Template: Compute `deviceHash` (Dart)

```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb

/// Computes a unique, privacy-preserving hash for the current device.
/// This hash is used to enforce the one-account-per-device policy.
Future<String> computeDeviceHash() async {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  String deviceIdentifier;

  try {
    if (kIsWeb) {
      final WebBrowserInfo webBrowserInfo = await deviceInfo.webBrowserInfo();
      deviceIdentifier = webBrowserInfo.userAgent ?? 'web_unknown';
    } else if (Theme.of(context).platform == TargetPlatform.android) {
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo();
      deviceIdentifier = androidInfo.id; // Android ID is unique per device per app install
    } else if (Theme.of(context).platform == TargetPlatform.iOS) {
      final IosDeviceInfo iosInfo = await deviceInfo.iosInfo();
      deviceIdentifier = iosInfo.identifierForVendor ?? 'ios_unknown'; // Unique per device per vendor
    } else {
      deviceIdentifier = 'unknown_platform_device';
    }
  } catch (e) {
    debugPrint('Error getting device info: $e');
    deviceIdentifier = 'error_device_info';
  }

  // Add a salt to the device identifier for better privacy and uniqueness
  // The salt should ideally be a constant known to the backend or derived securely.
  // For simplicity, using a hardcoded string here.
  const String salt = "earnplay_device_salt_v1"; 
  final String combinedIdentifier = '$deviceIdentifier-$salt';

  // Compute SHA256 hash
  final List<int> bytes = utf8.encode(combinedIdentifier);
  final Digest digest = sha256.convert(bytes);
  
  final String deviceHash = digest.toString();

  // Privacy Note:
  // The deviceHash is a one-way hash and does not directly expose raw device identifiers.
  // However, it is still a persistent identifier. Ensure users are informed about
  // the one-account-per-device policy and how their device is identified for security purposes.
  // Avoid collecting or storing raw device identifiers directly unless absolutely necessary
  // and with explicit user consent.
  debugPrint('Computed Device Hash: $deviceHash');
  return deviceHash;
}
```

---

## 1.2 Client-Side Authentication Retry

If a Worker endpoint returns an `HTTP 401 Unauthorized` status code with an `INVALID_TOKEN` error, it indicates that the client's Firebase ID Token is invalid or expired. The client should attempt to refresh the token and retry the request.

### Code Template: Token Refresh and Retry (Dart)

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Generic function to make an authenticated Worker request with token refresh logic.
Future<Map<String, dynamic>> makeAuthenticatedWorkerRequest({
  required String endpoint,
  required Map<String, dynamic> body,
  int maxRetries = 1, // Only one retry after token refresh
}) async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('User not authenticated.');
  }

  String? idToken = await user.getIdToken();
  int retryCount = 0;

  while (retryCount <= maxRetries) {
    try {
      final response = await http.post(
        Uri.parse('${WorkerService.workerBaseUrl}/$endpoint'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401 && jsonDecode(response.body)['error'] == 'INVALID_TOKEN') {
        // Token invalid/expired, try to refresh and retry
        debugPrint('Worker returned 401 INVALID_TOKEN. Attempting to refresh token...');
        idToken = await user.getIdToken(true); // Force refresh token
        retryCount++;
        continue; // Retry the request with the new token
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Worker request failed');
      }
    } on Exception catch (e) {
      if (retryCount >= maxRetries) {
        rethrow; // Re-throw after max retries
      }
      retryCount++;
      // For other network errors, consider exponential backoff before retrying
      await Future.delayed(const Duration(seconds: 2)); // Small delay before retry
    }
  }
  throw Exception('Failed to make authenticated request after retries.');
}

// USAGE EXAMPLE (for an immediate endpoint like /request-withdrawal):
Future<void> requestWithdrawalWithRetry({
  required int amount,
  required String method,
  required Map<String, dynamic> paymentDetails,
  required String deviceHash,
  required String idempotencyKey,
}) async {
  final result = await makeAuthenticatedWorkerRequest(
    endpoint: 'request-withdrawal',
    body: {
      'amount': amount,
      'method': method,
      'paymentDetails': paymentDetails,
      'deviceHash': deviceHash,
      'idempotencyKey': idempotencyKey,
    },
  );

  if (result['success']) {
    // Update UI with new balance
    // _userData!.coins = result['newBalance'];
    // notifyListeners();
  } else {
    throw Exception(result['error'] ?? 'Withdrawal failed.');
  }
}

// IMPORTANT: Ensure queued events are not stuck
// If a batch flush fails with 401 INVALID_TOKEN, the client should:
// 1. Force refresh the ID token: `FirebaseAuth.instance.currentUser.getIdToken(true)`
// 2. Mark the events as PENDING again in the local queue.
// 3. The next periodic flush will automatically retry with the new token.
// The `flushEventQueue()` logic in `UserProvider` already handles marking events PENDING on failure.
```

---

## 2. Idempotency Key Pattern & KV Conventions

### 2.1 How to Generate Idempotency Keys

```dart
// Option 1: Random UUID (recommended for most events)
String generateIdempotencyKey() {
  return Uuid().v4();  // Globally unique, collision probability ~0
}

// Option 2: Deterministic (for replay scenarios)
String generateDeterministicKey(String eventType, int coins, int timestamp) {
  final data = '$eventType:$coins:$timestamp';
  return sha256.convert(utf8.encode(data)).toString();
}

// USAGE:
final event = EventModel(
  type: 'AD_WATCHED',
  coins: 5,
  metadata: {},
  idempotencyKey: Uuid().v4(),  // ← Each event gets unique key
);
```

### 2.2 Worker-Side Idempotency KV Caching (Production-Ready)

**Key Convention**:
```
idempotency:{endpoint}:{userId}:{idempotencyKey}

Examples:
  - idempotency:batch-events:user123:550e8400-e29b-41d4-a716
  - idempotency:claim-referral:user456:f47ac10b-58cc-4372
  - idempotency:request-withdrawal:user789:c3fa36c0-0ef5-4784

TTL: Varies by endpoint
  - batch-events: 3600 seconds (1 hour)
  - claim-referral: 86400 seconds (24 hours)
  - request-withdrawal: 86400 seconds (24 hours)
```

**Implementation**:
```javascript
async function checkIdempotency(userId, idempotencyKey, endpoint, kvBinding) {
  const cacheKey = `idempotency:${endpoint}:${userId}:${idempotencyKey}`;
  const cached = await kvBinding.get(cacheKey);
  
  if (cached) {
    return { isCached: true, result: JSON.parse(cached) };
  }
  return { isCached: false };
}

async function cacheIdempotencyResult(userId, idempotencyKey, endpoint, result, kvBinding, ttlSeconds) {
  const cacheKey = `idempotency:${endpoint}:${userId}:${idempotencyKey}`;
  await kvBinding.put(cacheKey, JSON.stringify(result), { expirationTtl: ttlSeconds });
}
```

### 2.3 Rate-Limiter Counter KV Conventions (Production-Ready)

**Key Format & TTLs**:
```
Per-Endpoint Rate Limiting:

batch-events:
  - rate:batch-events:uid:{userId}         → 10 requests/minute (TTL 60s)
  - rate:batch-events:ip:{clientIP}        → 50 requests/minute (TTL 60s)

claim-referral:
  - rate:claim-referral:uid:{userId}       → 5 requests/minute (TTL 60s)
  - rate:claim-referral:ip:{clientIP}      → 20 requests/minute (TTL 60s)

request-withdrawal:
  - rate:request-withdrawal:uid:{userId}   → 3 requests/minute (TTL 60s)
  - rate:request-withdrawal:ip:{clientIP}  → 10 requests/minute (TTL 60s)
```

**Implementation**:
```javascript
async function checkRateLimits(userId, ip, endpoint, kvBinding) {
  const limits = {
    'batch-events': { uid: 10, ip: 50 },
    'claim-referral': { uid: 5, ip: 20 },
    'request-withdrawal': { uid: 3, ip: 10 },
  };
  
  const { uid: uidLimit, ip: ipLimit } = limits[endpoint];
  
  // Check UID limit
  if (userId) {
    const uidKey = `rate:${endpoint}:uid:${userId}`;
    let uidCount = parseInt(await kvBinding.get(uidKey) || '0');
    if (uidCount >= uidLimit) {
      return { limited: true, retryAfter: 60 };
    }
    await kvBinding.put(uidKey, (uidCount + 1).toString(), { expirationTtl: 60 });
  }
  
  // Check IP limit
  if (ip) {
    const ipKey = `rate:${endpoint}:ip:${ip}`;
    let ipCount = parseInt(await kvBinding.get(ipKey) || '0');
    if (ipCount >= ipLimit) {
      return { limited: true, retryAfter: 60 };
    }
    await kvBinding.put(ipKey, (ipCount + 1).toString(), { expirationTtl: 60 });
  }
  
  return { limited: false };
}
```

---

## 3. Optimistic Update Pattern

### Template

```dart
// Pattern: Optimistic -> Queue -> Verify -> Sync
Future<void> performAction(int coinsReward) async {
  // PHASE 1: Optimistic (assume success)
  final previousCoins = _userData!.coins;
  _userData!.coins += coinsReward;
  notifyListeners();
  
  try {
    // PHASE 2: Queue for processing
    await _queueAndWait(coinsReward);
    
    // PHASE 3: Success - nothing more needed
    // (optimistic was correct)
  } catch (e) {
    // PHASE 4: Rollback on error
    _userData!.coins = previousCoins;
    notifyListeners();
    
    _error = 'Failed: $e';
    rethrow;
  }
}
```

### Pitfall: Don't Do This

```dart
// ❌ WRONG: This causes UI jank
Future<void> recordGameWin(int coins) async {
  // Wait for Firestore confirmation before updating UI
  await firestore.update('/users/{uid}', coins: coins);
  
  // Only THEN update UI (2-5 second delay!)
  _userData!.coins += coins;
  notifyListeners();
}

// ✅ CORRECT: Update UI first
Future<void> recordGameWin(int coins) async {
  _userData!.coins += coins;
  notifyListeners();  // UI updates immediately
  
  // Server sync happens in background
  await _eventQueue.addEvent(...);
}
```

---

## 4. Batch Aggregation Pattern

### Worker-side aggregation logic

```javascript
function aggregateEvents(events) {
  const result = {
    totalCoins: 0,
    eventCounts: {},
    allEvents: [],
    metadata: {
      firstTimestamp: Infinity,
      lastTimestamp: 0,
    },
  };

  for (const event of events) {
    // Count by type
    if (!result.eventCounts[event.type]) {
      result.eventCounts[event.type] = 0;
    }
    result.eventCounts[event.type]++;

    // Sum coins
    result.totalCoins += event.coins;

    // Track timestamps
    result.metadata.firstTimestamp = Math.min(
      result.metadata.firstTimestamp,
      event.timestamp
    );
    result.metadata.lastTimestamp = Math.max(
      result.metadata.lastTimestamp,
      event.timestamp
    );

    // Keep full event
    result.allEvents.push(event);
  }

  return result;
}

// Usage in transaction:
const aggregated = aggregateEvents(events);
transaction.update(userRef, {
  coins: FieldValue.increment(aggregated.totalCoins),
  'daily.watchedAdsToday': FieldValue.increment(
    aggregated.eventCounts.AD_WATCHED || 0
  ),
});
```

---

## 5. Flush Timer Pattern

### Recommended Implementation

```dart
class EventQueueService {
  Timer? _flushTimer;
  static const int _flushIntervalSeconds = 60;

  /// Start periodic flush timer
  void startFlushTimer(Function() onFlush) {
    _flushTimer?.cancel();
    
    _flushTimer = Timer.periodic(
      Duration(seconds: _flushIntervalSeconds),
      (_) async {
        await onFlush();
        
        // Reschedule after flush completes
        // (prevents overlapping flushes)
      },
    );
  }

  /// Cancel timer
  void stopFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  /// Dispose (for cleanup)
  void dispose() {
    _flushTimer?.cancel();
  }
}

// In UserProvider
void initializeEventQueue() {
  _eventQueue.startFlushTimer(() => flushEventQueue());
}

// In Widget.dispose()
@override
void dispose() {
  _eventQueue.dispose();  // Stops timer
  super.dispose();
}
```

---

## 6. Error Handling & Retry Pattern

### Retry with Exponential Backoff

```dart
Future<T> retryWithBackoff<T>(
  Future<T> Function() operation, {
  int maxRetries = 3,
  Duration initialDelay = const Duration(seconds: 1),
}) async {
  int retryCount = 0;
  
  while (true) {
    try {
      return await operation();
    } catch (e) {
      retryCount++;
      
      if (retryCount >= maxRetries) {
        rethrow;  // Give up
      }
      
      // Exponential backoff: 1s, 2s, 4s
      final delay = initialDelay * (1 << (retryCount - 1));
      await Future.delayed(delay);
    }
  }
}

// Usage
await retryWithBackoff(
  () => WorkerService().batchEvents(userId, events),
  maxRetries: 3,
  initialDelay: Duration(seconds: 5),
);
```

### Fallback Pattern

```dart
Future<void> flushWithFallback() async {
  try {
    // Try new Worker-batched approach
    await flushEventQueue();
  } on TimeoutException catch (_) {
    // Timeout → fallback to direct writes
    debugPrint('⚠️ Worker timeout, using direct Firestore fallback');
    
    await fallbackToDirectWrites();
  } catch (e) {
    // Other errors → log but don't crash
    debugPrint('❌ Flush failed: $e');
    _error = 'Sync failed. Will retry automatically.';
    notifyListeners();
  }
}
```

---

## 7. Race Condition Patterns

### Client-Side Debounce Pattern

```dart
class WatchEarnScreen extends StatefulWidget {
  @override
  State<WatchEarnScreen> createState() => _WatchEarnScreenState();
}

class _WatchEarnScreenState extends State<WatchEarnScreen> {
  bool _isProcessingAd = false;

  Future<void> _onAdRewarded() async {
    // Prevent double-taps
    if (_isProcessingAd) return;
    
    _isProcessingAd = true;
    
    try {
      await context.read<UserProvider>().recordAdWatched(coinsReward: 5);
      
      if (mounted) {
        SnackbarHelper.showSuccess(context, '5 coins earned!');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAd = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: _isProcessingAd ? null : _onAdRewarded,
      child: const Text('Watch Ad'),
    );
  }
}
```

### Firestore Transaction Pattern (Double-Check)

```dart
Future<void> claimSpinRewardSafely(int coins) async {
  final userRef = FirebaseFirestore.instance
      .collection('users')
      .doc(_userData!.uid);

  // Atomic transaction with double-check
  await FirebaseFirestore.instance.runTransaction((txn) async {
    final userDoc = await txn.get(userRef);
    final data = userDoc.data() as Map<String, dynamic>;
    
    // CRITICAL: Double-check within transaction
    final spinsRemaining = data['spinsRemaining'] as int;
    if (spinsRemaining <= 0) {
      throw Exception('No spins remaining (checked in transaction)');
    }
    
    // Atomic update
    txn.update(userRef, {
      'coins': FieldValue.increment(coins),
      'spinsRemaining': FieldValue.increment(-1),
    });
  });
}
```

---

## 8. Lifecycle Observer Pattern

### For Game Screens (Save on Background)

```dart
class GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startGameSession();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // App going to background or closing
        // ← CRITICAL: Flush events before losing them!
        context.read<UserProvider>().flushEventQueue();
        break;
      case AppLifecycleState.resumed:
        // App coming to foreground (if needed)
        break;
      default:
        break;
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

## 9. Firestore Security Rules Pattern

### Allow Worker to Write, Client to Read

```javascript
match /users/{userId} {
  // Client can READ
  allow read: if request.auth.uid == userId;
  
  // Client can CREATE (signup)
  allow create: if request.auth.uid == userId;
  
  // Client CANNOT UPDATE
  allow update: if false;
  
  // Worker can UPDATE (via service account or custom claim)
  // This is handled in backend security via:
  // - Service account impersonation
  // - Custom Firebase claims (role: 'worker')
  // - IP allowlist (Cloudflare IP range)
}
```

### Daily Limit Check Pattern

```javascript
function isWithinDailyLimit(oldData, newData) {
  let adsToday = (oldData.daily?.watchedAdsToday || 0) + 1;
  return adsToday <= 10;  // Max 10 ads per day
}
```

---

## 10. Testing Patterns

### Unit Test: Event Queueing

```dart
void main() {
  group('Event Queue', () {
    late EventQueueService queue;

    setUp(() async {
      await Hive.deleteBoxFromDisk('test_queue');
      queue = EventQueueService();
      await queue.initialize();
    });

    test('persists events to Hive', () async {
      final event = EventModel(
        type: 'GAME_WON',
        coins: 50,
        metadata: {},
      );

      await queue.addEvent(event);
      
      // Simulate app restart
      final queue2 = EventQueueService();
      await queue2.initialize();

      expect(queue2.getQueueSize(), 1);
      expect(queue2.getPendingEvents().first.type, 'GAME_WON');
    });

    test('deduplicates events by idempotencyKey', () async {
      final event1 = EventModel(
        type: 'AD_WATCHED',
        coins: 5,
        metadata: {},
        idempotencyKey: 'key123',
      );
      
      await queue.addEvent(event1);
      await queue.addEvent(event1);  // Same key
      
      // Both should be in queue, but Worker will deduplicate
      expect(queue.getQueueSize(), 2);
    });
  });
}
```

### Integration Test: Full Sync

```dart
void main() {
  group('Full Event Sync E2E', () {
    testWidgets('queues game win and flushes to Firestore', (tester) async {
      // Setup
      await setupTestApp(tester);
      
      // Record optimistic update
      final initialCoins = getUserCoins();
      context.read<UserProvider>().recordGameWin(coins: 50);
      
      // UI updates immediately
      expect(getUserCoins(), initialCoins + 50);
      
      // Manually flush
      await context.read<UserProvider>().flushEventQueue();
      await tester.pumpAndSettle();
      
      // Verify Firestore updated
      final firebaseCoins = await getFirestoreCoins();
      expect(firebaseCoins, initialCoins + 50);
    });
  });
}
```

---

## 11. Constants & Configuration

### Recommended Values

```dart
// Event Queueing
const int MAX_BATCH_SIZE = 50;
const int FLUSH_INTERVAL_SECONDS = 60;
const int MAX_QUEUE_SIZE = 5000;  // Warn if exceeded

// Retry Policy
const int MAX_RETRIES = 3;
const int INITIAL_RETRY_DELAY_MS = 1000;  // 1 second
const int MAX_RETRY_DELAY_MS = 30000;     // 30 seconds

// Idempotency Cache
const int IDEMPOTENCY_CACHE_TTL_HOURS = 1;

// Daily Limits
const int MAX_ADS_PER_DAY = 10;
const int MAX_SPINS_PER_DAY = 3;

// Timeouts
const int WORKER_TIMEOUT_SECONDS = 30;
const int FIRESTORE_TIMEOUT_SECONDS = 30;
```

---

## 12. Monitoring & Logging

### Key Metrics to Log

```dart
void _logQueueEvent(EventModel event) {
  AnalyticsService.logEvent('event_queued', {
    'timestamp': DateTime.now().toIso8601String(),
    'event_type': event.type,
    'coins': event.coins,
    'queue_size': _eventQueue.getQueueSize(),
    'idempotency_key': event.idempotencyKey,
  });
}

void _logFlushSuccess(int eventCount, int totalCoins) {
  AnalyticsService.logEvent('queue_flushed', {
    'timestamp': DateTime.now().toIso8601String(),
    'events_processed': eventCount,
    'total_coins': totalCoins,
    'duration_ms': flushDuration.inMilliseconds,
  });
}

void _logFlushFailure(String error, int retryCount) {
  AnalyticsService.logEvent('queue_flush_failed', {
    'timestamp': DateTime.now().toIso8601String(),
    'error': error,
    'retry_count': retryCount,
    'queue_size': _eventQueue.getQueueSize(),
  });
}
```

---

## Quick Reference Checklist

When implementing any reward feature:

- [ ] Add event model with unique idempotency key
- [ ] Implement optimistic UI update
- [ ] Queue event to local storage
- [ ] Implement periodic flush (60s or 50 events)
- [ ] Add lifecycle observer to save on app background
- [ ] Add client-side debounce for button taps
- [ ] Implement retry logic with exponential backoff
- [ ] Add error handling and user feedback
- [ ] Test for race conditions
- [ ] Log metrics for monitoring
- [ ] Document in team wiki

---

**More detailed examples in IMPLEMENTATION_GUIDE.md**
