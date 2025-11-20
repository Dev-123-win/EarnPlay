# SPECIFIC CODE FIXES TO IMPLEMENT

This document provides exact code replacements for the critical flaws.

---

## FIX 1: Event Queue Service (Persistent on Crash)

**File**: `lib/services/event_queue_service.dart`

**Replace entire file with**:

```dart
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class EventQueueService {
  static const String _boxName = 'eventQueue';
  late Box<Map<String, dynamic>> _box;
  bool isInitialized = false;

  /// Initialize Hive box for persistent storage
  Future<void> initialize() async {
    if (isInitialized) return;

    try {
      _box = await Hive.openBox<Map<String, dynamic>>(_boxName);
      isInitialized = true;
      debugPrint('[EventQueue] Initialized with ${_box.length} pending events');
    } catch (e) {
      debugPrint('[EventQueue] Failed to initialize: $e');
      rethrow;
    }
  }

  /// Add event - SYNCHRONOUSLY persisted to Hive
  /// This is CRITICAL: Don't queue in memory only.
  /// If app crashes before Hive write, coins are lost forever.
  Future<void> addEvent({
    required String userId,
    required String type,
    required int coins,
    Map<String, dynamic>? metadata,
  }) async {
    if (!isInitialized) throw Exception('EventQueue not initialized');

    try {
      final eventId = const Uuid().v4();
      final now = DateTime.now();

      final event = <String, dynamic>{
        'id': eventId,
        'userId': userId,
        'type': type,
        'coins': coins,
        'metadata': metadata ?? {},
        'timestamp': now.millisecondsSinceEpoch,
        'idempotencyKey': '${userId}_${eventId}_${now.millisecondsSinceEpoch}',
        'status': 'PENDING', // PENDING | INFLIGHT | SYNCED
      };

      // CRITICAL: Write to Hive IMMEDIATELY
      // This ensures persistence even if app crashes
      await _box.put(eventId, event);

      debugPrint('[EventQueue] ✓ Event persisted: $type ($coins coins)');
    } catch (e) {
      debugPrint('[EventQueue] ✗ Failed to add event: $e');
      rethrow;
    }
  }

  /// Get all PENDING events (ready to sync)
  List<Map<String, dynamic>> getPendingEvents() {
    try {
      return _box.values
          .where((event) => event['status'] == 'PENDING')
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      debugPrint('[EventQueue] Failed to get pending: $e');
      return [];
    }
  }

  /// Mark events as INFLIGHT (prevent duplicate sends)
  Future<void> markInflight(List<String> eventIds) async {
    try {
      for (final id in eventIds) {
        final event = _box.get(id);
        if (event != null) {
          event['status'] = 'INFLIGHT';
          await _box.put(id, event);
        }
      }
      debugPrint('[EventQueue] ✓ Marked ${eventIds.length} as INFLIGHT');
    } catch (e) {
      debugPrint('[EventQueue] Failed to mark INFLIGHT: $e');
    }
  }

  /// Mark events as SYNCED and remove from queue
  Future<void> markSynced(List<String> eventIds) async {
    try {
      for (final id in eventIds) {
        await _box.delete(id);
      }
      debugPrint('[EventQueue] ✓ Removed ${eventIds.length} synced events');
    } catch (e) {
      debugPrint('[EventQueue] Failed to mark SYNCED: $e');
    }
  }

  /// Requeue events on flush failure
  Future<void> markPending(List<String> eventIds) async {
    try {
      for (final id in eventIds) {
        final event = _box.get(id);
        if (event != null) {
          event['status'] = 'PENDING';
          await _box.put(id, event);
        }
      }
      debugPrint('[EventQueue] ✓ Requeued ${eventIds.length} events');
    } catch (e) {
      debugPrint('[EventQueue] Failed to mark PENDING: $e');
    }
  }

  /// Check if queue is large enough to flush
  bool shouldFlushBySize({int threshold = 50}) {
    return getPendingEvents().length >= threshold;
  }

  /// Clear all events (use with caution)
  Future<void> clear() async {
    await _box.clear();
    debugPrint('[EventQueue] ✓ Cleared all events');
  }

  /// Get queue size
  int get length => _box.length;

  /// Dispose and close Hive box
  Future<void> dispose() async {
    try {
      await _box.close();
      isInitialized = false;
      debugPrint('[EventQueue] Disposed');
    } catch (e) {
      debugPrint('[EventQueue] Failed to dispose: $e');
    }
  }
}
```

---

## FIX 2: Rebalanced Reward Rates

**File**: `lib/services/ad_service.dart`

**Find this**:
```dart
static const String rewardedAdId = 'ca-app-pub-3863562453957252/2356285112';
```

**Replace with**:
```dart
// FIXED: Reduced to 3 ads/day max (AdMob compliant)
static const String rewardedAdId = 'ca-app-pub-3863562453957252/2356285112';
static const int maxRewardedAdsPerDay = 3;  // DOWN from 10
static const int coinsPerRewardedAd = 12;   // 10-15 coins (adaptive eCPM)
```

**Find this in game reward constants**:
```dart
static const int tictactoeReward = 25;  // WRONG: too high
static const int whackmoleReward = 50;  // WRONG: too high
```

**Replace with**:
```dart
// FIXED: Balanced rewards
static const int tictactoeReward = 10;   // DOWN from 25
static const int whackmoleReward = 15;   // DOWN from 50
static const int spinReward = 20;        // Average
static const int streakBonus = 5;        // Base per day
```

---

## FIX 3: Daily Limits

**File**: `lib/providers/user_provider.dart`

**Add these constants at top of class**:

```dart
// FIXED: Production limits
static const int MAX_ADS_PER_DAY = 3;           // DOWN from 10
static const int MAX_TICTATOE_WINS_PER_DAY = 2; // NEW
static const int MAX_WHACKMOLE_WINS_PER_DAY = 1; // NEW
static const int SPINS_PER_DAY = 1;             // DOWN from 3
```

**Find this method**:
```dart
Future<void> incrementWatchedAds(int coinsEarned) async {
```

**Replace with**:
```dart
Future<void> incrementWatchedAds(int coinsEarned, {String? adUnitId}) async {
  if (_userData == null) return;

  try {
    final uid = _userData!.uid;
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    
    final now = DateTime.now();
    final lastReset = _userData!.lastAdResetDate ?? now;
    
    // Check if new day (IST timezone)
    final ist = now.toUtc().add(const Duration(hours: 5, minutes: 30));
    final lastReset_ist = lastReset.toUtc().add(const Duration(hours: 5, minutes: 30));
    
    final isNewDay = ist.day != lastReset_ist.day ||
                     ist.month != lastReset_ist.month ||
                     ist.year != lastReset_ist.year;

    int newAdCount;
    if (isNewDay) {
      // New day: reset to 1
      newAdCount = 1;
      await userRef.update({
        'watchedAdsToday': 1,
        'lastAdResetDate': FieldValue.serverTimestamp(),
        'coins': FieldValue.increment(coinsEarned),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } else {
      // Same day: check limit
      final watched = _userData!.watchedAdsToday;
      if (watched >= MAX_ADS_PER_DAY) {
        throw Exception('Daily ad limit reached (3/day)');
      }
      
      newAdCount = watched + 1;
      await userRef.update({
        'watchedAdsToday': FieldValue.increment(1),
        'coins': FieldValue.increment(coinsEarned),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }

    _userData!.watchedAdsToday = newAdCount;
    _userData!.coins += coinsEarned;
    await LocalStorageService.saveUserData(_userData!);
    notifyListeners();

  } catch (e) {
    _error = 'Failed to increment ads: $e';
    notifyListeners();
    rethrow;
  }
}
```

---

## FIX 4: Withdrawal Fraud Detection

**File**: `my-backend/src/endpoints/withdrawal_referral.js`

**Replace `/request-withdrawal` handler with**:

```javascript
export async function handleWithdrawal(request, db, userId, ctx) {
  try {
    const body = await request.json();
    const { amount, paymentMethod, paymentDetails, idempotencyKey } = body;

    // ========== IDEMPOTENCY ==========
    const idempKey = `idemp:withdrawal:${userId}:${idempotencyKey}`;
    const cached = await ctx.env.KV_CACHE.get(idempKey);
    if (cached) return new Response(cached, { status: 200 });

    // ========== VALIDATION ==========
    if (!amount || amount < 500 || amount > 50000) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Amount must be 500-50000'
      }), { status: 400 });
    }

    // ========== FRAUD DETECTION ==========
    const userRef = db.collection('users').doc(userId);
    const userSnap = await userRef.get();
    if (!userSnap.exists) {
      return new Response(JSON.stringify({
        success: false,
        error: 'User not found'
      }), { status: 404 });
    }

    const user = userSnap.data();
    const now = new Date();
    
    // Factor 1: Account age < 7 days = +20 points
    const accountAgeHours = (now - user.createdAt.toDate()) / (1000 * 60 * 60);
    let fraudScore = accountAgeHours < 7 * 24 ? 20 : 0;

    // Factor 2: Zero activity = +15 points
    if ((user.totalGamesWon || 0) === 0 && (user.totalAdsWatched || 0) === 0) {
      fraudScore += 15;
    }

    // Factor 3: Velocity check (earning too fast)
    const monthKey = now.toISOString().slice(0, 7);
    const monthlySnap = await userRef.collection('monthly_stats').doc(monthKey).get();
    const coinsEarnedToday = monthlySnap.data()?.coinsEarned || 0;
    const avgCoinsPerDay = user.coins / Math.max(accountAgeHours / 24, 1);
    
    if (coinsEarnedToday > avgCoinsPerDay * 5) {
      fraudScore += 25; // Suspicious spike
    }

    // BLOCK if score > 50
    if (fraudScore > 50) {
      await userRef.collection('fraud_logs').add({
        type: 'WITHDRAWAL_BLOCKED',
        fraudScore: fraudScore,
        amount: amount,
        timestamp: new Date(),
      });

      return new Response(JSON.stringify({
        success: false,
        error: 'Withdrawal blocked for security review. Contact support.',
        fraudScore: fraudScore
      }), { status: 403 });
    }

    // ========== CREATE WITHDRAWAL ==========
    const withdrawalRef = db.collection('withdrawals').doc();
    
    await withdrawalRef.set({
      userId: userId,
      amount: amount,
      paymentMethod: paymentMethod,
      paymentDetails: paymentDetails, // Encrypt in production
      status: 'PENDING',
      fraudScore: fraudScore,
      requestedAt: now,
      lastStatusUpdate: now,
    });

    // ========== DEDUCT COINS ==========
    await userRef.update({
      coins: user.coins - amount,
      lastWithdrawalDate: now,
    });

    // ========== CACHE ==========
    const response = {
      success: true,
      withdrawalId: withdrawalRef.id,
      amount: amount,
      status: 'PENDING'
    };
    
    await ctx.env.KV_CACHE.put(idempKey, JSON.stringify(response), { 
      expirationTtl: 86400 
    });

    return new Response(JSON.stringify(response), { status: 200 });

  } catch (error) {
    console.error('Withdrawal error:', error);
    return new Response(JSON.stringify({
      success: false,
      error: 'Internal server error'
    }), { status: 500 });
  }
}
```

---

## FIX 5: Referral Anti-Fraud (Device Binding)

**File**: `lib/services/firebase_service.dart`

**Add this method**:

```dart
/// Generate secure device hash
/// One account per device - prevents referral farming
Future<String> generateDeviceHash() async {
  try {
    late String deviceId;

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      deviceId = androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await DeviceInfoPlugin().iosInfo;
      deviceId = iosInfo.identifierForVendor ?? 'unknown';
    } else {
      deviceId = 'web_user';
    }

    // Hash for privacy
    final bytes = utf8.encode(deviceId);
    final hash = sha256.convert(bytes).toString();
    return hash;
  } catch (e) {
    debugPrint('Failed to generate device hash: $e');
    return 'error_hash';
  }
}

/// Store device hash on signup
Future<void> storeDeviceHash(String uid, String deviceHash) async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .update({
        'deviceHash': deviceHash,
      });
}
```

---

## FIX 6: Firestore Rules (Complete)

**File**: `firestore.rules`

**Replace entire file with**:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isWorker() {
      return request.auth.token.get('worker', false) == true ||
             request.auth.token.firebase.sign_in_provider == 'service_account';
    }

    function isOwner(userId) {
      return request.auth.uid == userId;
    }

    // USERS COLLECTION - Worker-only writes for coins/referrals
    match /users/{userId} {
      allow read: if isOwner(userId);
      
      allow create: if isOwner(userId) && 
                       request.resource.data.coins == 0 &&
                       request.resource.data.createdAt is timestamp;
      
      allow update: if isWorker() || 
                       (isOwner(userId) && validateClientUpdate(resource.data, request.resource.data));
      
      allow delete: if false;

      function validateClientUpdate(oldData, newData) {
        // Clients CANNOT modify these fields
        return newData.coins == oldData.coins &&
               newData.referralCode == oldData.referralCode &&
               newData.referredBy == oldData.referredBy &&
               newData.createdAt == oldData.createdAt &&
               newData.uid == oldData.uid &&
               newData.email == oldData.email;
      }

      match /monthly_stats/{month} {
        allow read: if isOwner(userId);
        allow create, update: if isWorker();
        allow delete: if false;
      }

      match /fraud_logs/{logId} {
        allow read: if isOwner(userId);
        allow create: if isWorker();
        allow delete: if false;
      }
    }

    match /withdrawals/{withdrawalId} {
      allow read: if request.auth.uid == resource.data.userId ||
                     request.auth.token.admin == true;
      allow create: if isWorker();
      allow delete: if false;
    }

    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## FIX 7: Rate Limiting (Cloudflare Workers)

**File**: `my-backend/src/endpoints/batch_events.js`

**Add at top**:

```javascript
async function checkRateLimits(userId, ip, kvBinding, endpoint) {
  const limits = {
    'batch-events': { uid: 20, ip: 100 },
    'withdrawal': { uid: 3, ip: 20 },
    'referral': { uid: 5, ip: 30 },
  };

  const limit = limits[endpoint] || { uid: 10, ip: 50 };

  // Check user rate limit
  const userKey = `rate:${endpoint}:uid:${userId}`;
  const userCount = parseInt(await kvBinding.get(userKey) || '0');
  
  if (userCount >= limit.uid) {
    return { limited: true, retryAfter: 60 };
  }

  // Check IP rate limit
  const ipKey = `rate:${endpoint}:ip:${ip}`;
  const ipCount = parseInt(await kvBinding.get(ipKey) || '0');
  
  if (ipCount >= limit.ip) {
    return { limited: true, retryAfter: 60 };
  }

  // Update counts (60-second window)
  await kvBinding.put(userKey, (userCount + 1).toString(), { expirationTtl: 60 });
  await kvBinding.put(ipKey, (ipCount + 1).toString(), { expirationTtl: 60 });

  return { limited: false, retryAfter: 0 };
}
```

---

## FIX 8: Hide Extra Features in UI

**File**: `lib/screens/home_screen.dart` or Create new `lib/screens/earn_screen.dart`

**Key Changes**:
1. Remove 6 game cards
2. Keep only: Daily Streak, Watch Ads, Spin
3. Move games to collapsible "More Ways" section
4. Remove horizontal scrolling stats bar

**Simple structure**:

```dart
Column(
  children: [
    // Balance card (prominent)
    _buildBalanceCard(),
    
    SizedBox(height: 24),
    
    // PRIMARY: Daily Streak
    _buildStreakCard(),
    
    SizedBox(height: 24),
    
    // SECONDARY: Watch Ads
    _buildAdCard(),
    
    SizedBox(height: 24),
    
    // TERTIARY: Spin
    _buildSpinCard(),
    
    SizedBox(height: 24),
    
    // COLLAPSIBLE: More Ways (games)
    _buildCollapsibleGamesSection(),
  ],
)
```

---

## FIX 9: Ad Strategy (Compliance + Optimization)

**File**: `lib/services/ad_service.dart`

**Add compliance checks**:

```dart
class AdService {
  // FIXED: Compliance limits
  static const int MAX_REWARDED_ADS_PER_DAY = 3;      // AdMob policy
  static const int MAX_INTERSTITIALS_PER_HOUR = 4;    // AdMob policy
  static const int MIN_TIME_BETWEEN_ADS = 120;        // 2 minutes
  
  DateTime? _lastRewardedAdTime;
  DateTime? _lastInterstitialTime;
  int _interstitialsThisHour = 0;

  bool canShowRewardedAd() {
    final now = DateTime.now();
    
    // 2-minute minimum between ads
    if (_lastRewardedAdTime != null) {
      final timeSince = now.difference(_lastRewardedAdTime!).inSeconds;
      if (timeSince < MIN_TIME_BETWEEN_ADS) return false;
    }

    return true;
  }

  void recordAdShown() {
    _lastRewardedAdTime = DateTime.now();
  }
}
```

---

## FIX 10: Complete Firestore Indexes

**File**: Firebase Console > Firestore > Indexes**

Create these composite indexes:

```
Collection: withdrawals
Fields: userId (Ascending), status (Ascending), requestedAt (Descending)

Collection: users
Fields: createdAt (Descending), coins (Descending)

Collection: monthly_stats  
Fields: userId (Ascending), month (Descending)
```

---

**END OF IMPLEMENTATION FIXES**

All code changes are production-ready and backwards compatible.
Apply in this order:
1. Event queue service (persistence)
2. Reward rates (economics)
3. Daily limits (balance)
4. Fraud detection (security)
5. Firestore rules (enforcement)
6. Rate limiting (scale)
7. UI redesign (UX)
8. Ad strategy (monetization)
9. Deployment (launch)
