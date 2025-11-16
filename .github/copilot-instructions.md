# EarnPlay AI Coding Agent Instructions

## Project Overview
**EarnPlay** is a **pure Firestore, offline-first Flutter rewards app** with no backend server. Users earn coins through games, ads, referrals, and daily streaks—all synced daily at 22:00 IST via batch operations.

**Key Architecture**: Firebase Auth → Firestore (security rules enforce logic) → Provider-based state management → Material 3 UI

---

## Critical "Big Picture" Patterns

### 1. **Offline-First Batch Sync Strategy**
Users play games/earn rewards **locally** without Firestore writes. All actions batch-sync **daily at 22:00 IST (±30s random delay)**.

- **What this means**: Never write individual game results to Firestore. Use `OfflineStorageService` to queue actions locally.
- **Why**: 8 games = 1 Firestore write (not 8), reducing costs from $0.003→$0.00003 per user/day.
- **Key files**: `lib/services/offline_storage_service.dart` (handles queueing), `lib/services/firebase_service.dart` (batch commits)
- **Pattern**: Local updates → notifyListeners() → sync at 22:00 IST

**Example decision tree**:
- User plays tic-tac-toe game → Add to offline queue (`queueAction()`) → Update local UI immediately → No Firestore write yet
- 22:00 IST arrives → `syncNow()` batches all queued actions → Single Firestore write with all 8 actions

### 2. **Firestore Operations MUST Use FieldValue.increment()**
All coin updates must use **atomic `FieldValue.increment()`** to prevent race conditions with concurrent writes.

```dart
// ✅ CORRECT: Atomic, handles concurrent updates
await userRef.update({
  'coins': FieldValue.increment(amount),  // Firestore does math, not client
  'lastUpdated': FieldValue.serverTimestamp(),
});

// ❌ WRONG: Loses updates if multiple clients write simultaneously
final snapshot = await userRef.get();
int coins = snapshot['coins'];
await userRef.set({'coins': coins + amount});  // Race condition!
```

- **Where this matters**: `lib/providers/user_provider.dart` (updateCoins), ad rewards, referral bonuses
- **Impact**: Missing this causes phantom coin losses in production

### 3. **Daily Reset Pattern: Lazy Evaluation, Not Scheduled Tasks**
Daily limits (ads watched, spins available) don't reset on a schedule. They reset **on first access after midnight**.

```dart
// Check if today's date differs from last reset date
final isNewDay = now.day != lastResetDate.day || 
                 now.month != lastResetDate.month || 
                 now.year != lastResetDate.year;

if (isNewDay) {
  // Reset counter to 1 (not increment), update reset date
  await userRef.update({
    'watchedAdsToday': 1,  // Reset, don't increment
    'lastAdResetDate': FieldValue.serverTimestamp(),
  });
} else {
  // Same day, increment normally
  await userRef.update({
    'watchedAdsToday': FieldValue.increment(1),
  });
}
```

- **Where this matters**: `lib/providers/user_provider.dart` (incrementWatchedAds, resetSpins)
- **Common bug**: Using `FieldValue.increment()` without checking if day changed → rolls over limit on new day

### 4. **Provider-Based State Management (NOT GetX/Riverpod)**
All state flows through `MultiProvider` wrapping root app:

```dart
// lib/main.dart
runApp(
  MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => UserProvider()),
      ChangeNotifierProvider(create: (_) => GameProvider()),
    ],
    child: const MyApp(),
  ),
);
```

**Key providers**:
- `UserProvider` (lib/providers/user_provider.dart): Coins, streak, daily limits, user data
- `GameProvider` (lib/providers/game_provider.dart): Game results, stats, session batching

**Pattern**: Always use `context.watch<UserProvider>()` in build, `context.read<UserProvider>()` in callbacks.

### 5. **Material 3 Design System MUST Be Used**
All UI must use Material 3 components from `lib/theme/app_theme.dart`:

- Color scheme: Purple primary (#6B5BFF), Pink secondary (#FF6B9D), Green tertiary (#1DD1A1)
- Components: Use `FilledButton`, `OutlinedButton`, `Card.filled()`, `SegmentedButton` (not legacy RaisedButton)
- Text: Use `Theme.of(context).textTheme.headlineMedium` (not hardcoded sizes)

**File**: `lib/theme/app_theme.dart` defines everything. Reference it, don't create custom colors.

---

## Service Layer Boundaries

### Firebase Service (`lib/services/firebase_service.dart`)
- **Responsibility**: Firebase Auth, Firestore reads, Cloud Function calls
- **Does NOT**: Handle game logic, validation (Firestore rules do that)
- **Pattern**: Singleton factory constructor—only one instance per app
- **Key methods**: `signInWithEmail()`, `getUserData()`, `signInWithGoogle()`, `getIdToken()`

### Offline Storage Service (`lib/services/offline_storage_service.dart`)
- **Responsibility**: Local queue for game actions, daily batch sync scheduling
- **Key methods**: `queueAction()`, `syncNow()`, `getPendingActions()`
- **Timer management**: Handles 22:00 IST sync window; cancels previous timer on new initialization

### Local Storage Service (`lib/services/local_storage_service.dart`)
- **Responsibility**: SharedPreferences caching (user data, sync timestamps)
- **NOT for**: Game queues (use `OfflineStorageService`), auth tokens (Firebase handles)
- **Pattern**: Silently swallows errors (corrupted cache shouldn't crash app)

### Ad Service (`lib/services/ad_service.dart`)
- **Responsibility**: Google Mobile Ads (rewarded, interstitial, banner)
- **Test unit IDs**: Use Google-provided test IDs during dev (`ca-app-pub-3940256099942544/*`)
- **Preload strategy**: Load next ad immediately after user sees one (not on demand)

---

## Data Models & Firestore Schema

### User Document Structure
```
/users/{uid}
├── uid: string
├── email: string
├── coins: number (FieldValue.increment updates ONLY)
├── createdAt: timestamp
├── referralCode: string (6 chars, auto-generated)
├── referredBy: string | null (uid of referrer)
├── dailyStreak: {
│   ├── currentStreak: number
│   ├── lastCheckIn: timestamp | null
│   └── checkInDates: array
├── totalSpins: number
├── lastSpinResetDate: timestamp
├── watchedAdsToday: number (0-10 daily limit)
├── lastAdResetDate: timestamp
└── totalReferrals: number
```

**Key**: All coin fields use `FieldValue.increment()` in updates. Dates use `FieldValue.serverTimestamp()`.

### Game Session Batching
Games don't write per-play. Instead:
1. User plays 5 games locally → stored in memory
2. On session end OR 10 games played → flush to offline queue
3. 22:00 IST → batch all queued games to Firestore

**Files**: `lib/screens/games/tictactoe_screen.dart` shows session batching pattern (saves on app pause lifecycle event).

---

## Common Developer Workflows

### Adding a New Reward Feature
1. **Define earning rule** in Firestore security rules (if needed)
2. **Add method to UserProvider** using `FieldValue.increment()`
3. **Queue action** via `OfflineStorageService.queueAction()`
4. **Update local state** → `notifyListeners()` for instant UI update
5. **Test**: Verify coins increment locally, then check Firestore after 22:00 IST sync

**Example**: Adding "bonus spin" reward
```dart
// In UserProvider
Future<void> addBonusSpin() async {
  try {
    // Queue for sync
    await _offlineStorage.queueAction(
      userId: _userData!.uid,
      actionType: 'ADD_BONUS_SPIN',
      data: {'timestamp': DateTime.now().toIso8601String()},
    );
    
    // Update locally
    _userData!.totalSpins += 1;
    notifyListeners();
  } catch (e) {
    _error = 'Failed to add spin: $e';
    notifyListeners();
  }
}
```

### Debugging Firestore Issues
- **Phantom coin losses**: Check if using `FieldValue.increment()` everywhere. If using direct `set()`, concurrent writes lose data.
- **Daily reset not working**: Check `isNewDay` logic in UserProvider. Common bug: comparing with IST midnight when device is in different timezone.
- **Missing ad/spin increments**: Verify lazy reset logic fires. Add logs: `print('isNewDay: $isNewDay, lastReset: $lastResetDate, now: $now')`.

### Testing Offline Features
1. **Disable network** in device settings
2. **Play games** → verify coins update in UI
3. **Reconnect network** → manually call `syncNow()` or wait for 22:00 IST
4. **Check Firestore** → games should appear in user's action queue collection

---

## Project Structure Reference

```
lib/
├── main.dart                          # App bootstrap, Provider setup
├── app.dart                           # MaterialApp, routes, theme
├── admob_init.dart                    # Google Mobile Ads initialization
├── firebase_options.dart              # Firebase project config
│
├── models/                            # Data models
│   ├── user_data_model.dart           # User profile, coins, streak data
│   ├── game_models.dart               # GameResult, WithdrawalRecord
│   └── monthly_stats_model.dart       # Monthly game statistics
│
├── providers/                         # State management (Provider pattern)
│   ├── user_provider.dart             # Auth, coins, daily limits
│   └── game_provider.dart             # Game results, stats, session batching
│
├── services/                          # Backend integrations
│   ├── firebase_service.dart          # Firestore, Auth, Cloud Functions
│   ├── local_storage_service.dart     # SharedPreferences caching
│   ├── offline_storage_service.dart   # Game queue, batch sync at 22:00 IST
│   └── ad_service.dart                # Google Mobile Ads
│
├── screens/                           # UI screens
│   ├── splash_screen.dart             # Initialization, auth check
│   ├── auth/
│   │   ├── login_screen.dart          # Email/Google sign-in
│   │   └── register_screen.dart       # Signup with referral code
│   ├── app_shell.dart                 # Bottom navigation wrapper
│   ├── home_screen.dart               # Main dashboard
│   ├── daily_streak_screen.dart       # 7-day streak with coin rewards
│   ├── watch_earn_screen.dart         # Ad watching (10/day limit)
│   ├── spin_win_screen.dart           # Fortune wheel (3 free spins)
│   ├── games/
│   │   ├── tictactoe_screen.dart      # Tic-tac-toe vs AI (batched saves)
│   │   └── whack_mole_screen.dart     # Whack-a-mole game
│   ├── profile_screen.dart            # User info, settings, logout
│   ├── referral_screen.dart           # Share code, track referrals
│   └── withdrawal_screen.dart         # Cash out coins
│
├── theme/
│   └── app_theme.dart                 # Material 3 colors, text styles, component themes
│
├── utils/                             # Helpers (parsing, formatting, validators)
└── widgets/                           # Reusable UI components
    ├── coin_balance_card.dart         # Coin display card
    └── feature_card.dart              # Feature grid item
```

---

## Critical Security Patterns

### Firestore Security Rules
- **NEVER trust client**: All validation in rules (increment limits, daily resets, referral bonuses)
- **Atomic transactions**: Use `runTransaction()` for multi-document updates (e.g., referral processing)
- **FieldValue server operations**: Prevents timestamp spoofing, ensures atomicity

**Example rule** (check `firestore.rules` for full rules):
```javascript
match /users/{uid} {
  // Only owner can read/write their document
  allow read, write: if request.auth.uid == uid;
  
  // Only allow increment operations (no direct set of coins)
  allow update: if request.resource.data.coins == 
    resource.data.coins + request.resource.data.coinsDelta;
}
```

---

## Docs & References

### Key Documentation Files
- **EARNPLAY_MASTER_IMPLEMENTATION_GUIDE.md**: Architecture, data flow, cost analysis
- **CRITICAL_FIXES_IMPLEMENTED.md**: Daily reset logic, session batching edge cases
- **GAME_ADS_IMPLEMENTATION_COMPLETE.md**: Ad placement, test IDs, reward tracking
- **PRE_LAUNCH_CHECKLIST.md**: Testing procedures, verification steps

### Version Info
- **Flutter SDK**: ^3.9.2
- **Firebase**: ^3.0.0 (firebase_core, firebase_auth, cloud_firestore)
- **Provider**: ^6.1.0 (state management)
- **Google Mobile Ads**: ^6.0.0 (ad serving)

---

## Red Flags & Anti-Patterns

❌ **Don't**:
- Use direct Firestore `set()` for coins (causes race conditions)
- Create scheduled Cloud Functions (batch sync is daily at fixed time, not real-time)
- Store game results per-play in Firestore (batch them first)
- Use hardcoded colors instead of `Theme.of(context).colorScheme`
- Compare dates without checking year/month/day (timezone issues)
- Call Firestore directly in UI widgets (use Provider or services layer)
- **Increment daily counters without checking if day changed** (lazy reset bug)
- **Set SetOptions(merge: true) with only partial fields** in batch operations (missing required fields)
- **Leave game sessions unflushed when app closes** (data loss bug)

✅ **Do**:
- Always use `FieldValue.increment()` for numeric updates
- Queue game actions before syncing
- Check `isNewDay` before resetting daily counters
- Use Provider's `context.watch()` for reactive UI
- Test offline features by disabling network
- Log errors but don't crash on Firestore failures (fallback to local cache)
- **Always initialize ALL fields when creating monthly stats** (not just incremented ones)
- **Add WidgetsBindingObserver to game screens** to flush on app background
- **Call resetSpinsIfNewDay()** before allowing user to claim spins on new day

---

## CRITICAL BUGS FIXED (From REFERENCE.md)

### 1. ❌ Session Flush on App Close **NOW FIXED** ✅
**Problem**: User plays 9 games → force closes app → 9 games lost forever

**Solution**: Added `WidgetsBindingObserver` to both game screens
- **Files**: `lib/screens/games/tictactoe_screen.dart`, `lib/screens/games/whack_mole_screen.dart`
- **Pattern**: `didChangeAppLifecycleState(AppLifecycleState.paused)` → `flushGameSession(uid)`
- **Result**: Games automatically saved when app goes to background

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
      final uid = context.read<UserProvider>().userData?.uid;
      if (uid != null) {
        context.read<GameProvider>().flushGameSession(uid);
      }
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
```

### 2. ❌ Lazy Reset Not Implemented **NOW FIXED** ✅
**Problem**: User on Jan 2 with `watchedAdsToday: 10` tries to watch ad → Firebase rule rejects (11 > 10)

**Solution**: Implemented proper lazy reset with day-change detection
- **File**: `lib/providers/user_provider.dart`
- **Method**: `incrementWatchedAds()` now checks `isNewDay` before incrementing
- **Pattern**: If new day, set to 1. If same day, increment. Never increment from old day's value.

```dart
Future<void> incrementWatchedAds(int coinsEarned) async {
  final now = DateTime.now();
  final lastReset = _userData!.lastAdResetDate ?? now;
  
  // CRITICAL: Check if date changed
  final isNewDay = now.day != lastReset.day || 
                   now.month != lastReset.month || 
                   now.year != lastReset.year;
  
  if (isNewDay) {
    // New day: RESET to 1, don't increment
    await userRef.update({
      'watchedAdsToday': 1,  // ← Important: not increment!
      'lastAdResetDate': FieldValue.serverTimestamp(),
      'coins': FieldValue.increment(coinsEarned),
    });
    _userData!.watchedAdsToday = 1;
  } else {
    // Same day: increment normally
    await userRef.update({
      'watchedAdsToday': FieldValue.increment(1),
      'coins': FieldValue.increment(coinsEarned),
    });
    _userData!.watchedAdsToday++;
  }
}
```

### 3. ❌ Spin Reset Not Implemented **NOW FIXED** ✅
**Problem**: Same as ads - user stuck at 0 spins on new day

**Solution**: Added `resetSpinsIfNewDay()` method with lazy evaluation
- **File**: `lib/providers/user_provider.dart`
- **Call this**: In spin_win_screen.dart before user claims spins
- **Pattern**: Identical to ads fix - check day changed, reset to 3 if new day

```dart
Future<void> resetSpinsIfNewDay() async {
  final now = DateTime.now();
  final lastReset = _userData!.lastSpinResetDate ?? now;
  
  final isNewDay = now.day != lastReset.day || 
                   now.month != lastReset.month || 
                   now.year != lastReset.year;
  
  if (isNewDay) {
    await userRef.update({
      'spinsRemaining': 3,  // Reset to 3 spins for new day
      'lastSpinResetDate': FieldValue.serverTimestamp(),
    });
    _userData!.spinsRemaining = 3;
  }
}
```

### 4. ❌ Monthly Stats First-Write Bug **NOW FIXED** ✅
**Problem**: First user to play in new month → `SetOptions(merge: true)` with only incremented fields → Firestore rule requires ALL fields → REJECTED

**Solution**: Initialize ALL fields in monthly stats, not just incremented ones
- **File**: `lib/providers/game_provider.dart`
- **Method**: `flushGameSession()` - now initializes optional fields to 0
- **Impact**: Monthly stats create successfully on first write

```dart
batch.set(
  monthlyStatsRef,
  {
    'month': currentMonth,
    'gamesPlayed': FieldValue.increment(_sessionGamesPlayed),
    'gameWins': FieldValue.increment(_sessionGamesWon),
    'coinsEarned': FieldValue.increment(_sessionCoinsEarned),
    'adsWatched': 0,           // ← Initialize missing
    'spinsUsed': 0,            // ← Initialize missing
    'withdrawalRequests': 0,   // ← Initialize missing
    'whackMoleHighScore': 0,   // ← Initialize missing
    'lastUpdated': FieldValue.serverTimestamp(),
  },
  SetOptions(merge: true),
);
```

---

## Data Model Updates

`UserData` class now includes reset date tracking:
```dart
DateTime? lastAdResetDate;    // Track when ads last reset (for lazy reset)
DateTime? lastSpinResetDate;  // Track when spins last reset (for lazy reset)
```

These are serialized/deserialized in `fromMap()` and `toMap()` methods.

---

## For AI Agents: Implementation Checklist

When implementing new features:

1. **[ ] Service layer first**: Create method in appropriate service (Firebase/Offline/Ad)
2. **[ ] Provider integration**: Add state update method in UserProvider or GameProvider
3. **[ ] Offline-aware**: Use offline queue if data needs persistence
4. **[ ] Material 3 UI**: Use theme colors and typography from `app_theme.dart`
5. **[ ] Error handling**: Silent fallback to local cache on Firestore errors
6. **[ ] Type safety**: Use models (GameResult, UserData, etc.), not raw Maps
7. **[ ] Testing**: Verify offline-first behavior (disable network, check local state)
8. **[ ] Documentation**: Update relevant markdown files (especially REFERENCE.md for known issues)
