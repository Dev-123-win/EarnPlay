import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_data_model.dart';
import '../services/local_storage_service.dart';
import '../services/firebase_service.dart';
import '../services/worker_service.dart';

class UserProvider extends ChangeNotifier {
  UserData? _userData;
  bool _isLoading = false;
  String? _error;

  UserData? get userData => _userData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadUserData(String uid) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final firebaseService = FirebaseService();
      final data = await firebaseService.getUserData(uid);

      if (data != null) {
        try {
          _userData = UserData.fromMap(data);
          await LocalStorageService.saveUserData(_userData!);
          _error = null;
        } catch (parseError) {
          _error = 'Error parsing user data: $parseError';
          // Try to load from local cache as fallback
          _userData = await LocalStorageService.getUserData();
          if (_userData == null) {
            throw Exception(
              'Failed to parse user data and local cache is empty',
            );
          }
        }
      } else {
        _error = 'No user data found';
      }
    } catch (e) {
      _error = 'Failed to load user data: $e';
      // Try to load from local cache
      _userData = await LocalStorageService.getUserData();
      if (_userData == null) {
        _error = 'Failed to load user data. Please login again.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update coins using FieldValue.increment() for atomicity
  /// Never use direct SET - always increment to prevent race conditions
  /// [amount] - positive or negative coin amount
  /// [reason] - why coins are being updated (for audit trail)
  Future<void> updateCoins(int amount, {String reason = 'admin_bonus'}) async {
    if (_userData == null) return;

    try {
      final uid = _userData!.uid;
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      // CRITICAL: Use FieldValue.increment() NOT direct set
      // This ensures atomicity even with concurrent writes
      await userRef.update({
        'coins': FieldValue.increment(amount),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Create audit trail for fraud detection
      await userRef.collection('actions').add({
        'type': 'MANUAL_BONUS',
        'amount': amount,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': uid,
      });

      _userData!.coins += amount;
      await LocalStorageService.saveUserData(_userData!);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update coins: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Check if streak should be reset (missed a day)
  bool _shouldResetStreak() {
    if (_userData?.dailyStreak.lastCheckIn == null) return false;

    final lastCheckIn = _userData!.dailyStreak.lastCheckIn!;
    final now = DateTime.now();
    final daysSinceCheckIn = now.difference(lastCheckIn).inDays;

    // Reset if more than 1 day has passed
    return daysSinceCheckIn > 1;
  }

  /// Reset daily streak to 0
  Future<void> resetDailyStreak() async {
    if (_userData == null) return;

    try {
      final uid = _userData!.uid;
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      await userRef.update({
        'dailyStreak.currentStreak': 0,
        'dailyStreak.lastCheckIn': null,
        'dailyStreak.checkInDates': [],
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      _userData!.dailyStreak.currentStreak = 0;
      _userData!.dailyStreak.lastCheckIn = null;
      _userData!.dailyStreak.checkInDates = [];

      await LocalStorageService.saveUserData(_userData!);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to reset streak: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Claim daily streak reward using atomic Firestore transaction
  Future<void> claimDailyStreak() async {
    if (_userData == null) return;

    try {
      // Check if streak should be reset
      if (_shouldResetStreak()) {
        await resetDailyStreak();
        throw Exception(
          'Streak was reset due to missed day. Start a new streak!',
        );
      }

      final uid = _userData!.uid;
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final today = DateTime.now();
      final todayString =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Use transaction to ensure consistency
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final doc = await transaction.get(userRef);
        final currentData = doc.data() as Map<String, dynamic>;

        final currentStreak =
            ((currentData['dailyStreak']?['currentStreak'] as int?) ?? 0);
        final checkInDates = List<String>.from(
          currentData['dailyStreak']?['checkInDates'] ?? [],
        );

        // Don't allow double claiming on same day
        if (checkInDates.contains(todayString)) {
          throw Exception('You have already claimed today!');
        }

        final newStreak = currentStreak + 1;
        final streakReward = newStreak * 10; // 10 coins per day of streak

        // Add today's date to check-in dates
        checkInDates.add(todayString);

        // Update in transaction
        transaction.update(userRef, {
          'dailyStreak.currentStreak': newStreak,
          'dailyStreak.lastCheckIn': FieldValue.serverTimestamp(),
          'dailyStreak.checkInDates': checkInDates,
          'coins': FieldValue.increment(streakReward),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // Create audit trail
        transaction.set(userRef.collection('actions').doc(), {
          'type': 'DAILY_STREAK_REWARD',
          'amount': streakReward,
          'streak': newStreak,
          'timestamp': FieldValue.serverTimestamp(),
          'userId': uid,
        });
      });

      // Update local data with same calculation
      _userData!.dailyStreak.currentStreak += 1;
      _userData!.dailyStreak.lastCheckIn = DateTime.now();
      final todayString2 =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      if (!_userData!.dailyStreak.checkInDates.contains(todayString2)) {
        _userData!.dailyStreak.checkInDates.add(todayString2);
      }
      final reward = (_userData!.dailyStreak.currentStreak) * 10;
      _userData!.coins += reward;

      await LocalStorageService.saveUserData(_userData!);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to claim streak: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Request withdrawal using Worker (optimized for Firestore cost)
  /// Atomic transaction prevents double-spending
  Future<String> requestWithdrawal({
    required int amount,
    required String method,
    required String paymentId,
  }) async {
    if (_userData == null) throw Exception('User not loaded');

    try {
      // ✅ Phase 1.5: Call Worker instead of direct Firestore update
      final workerService = WorkerService();

      // Call worker endpoint for atomic withdrawal
      final result = await workerService.requestWithdrawal(
        amount: amount,
        method: method,
        paymentId: paymentId,
      );

      if (result['success'] == true) {
        // Update local state with worker response
        final data = result['data'] as Map<String, dynamic>;

        _userData!.coins = data['newBalance'] ?? _userData!.coins - amount;

        // Cache locally
        await LocalStorageService.saveUserData(_userData!);
        notifyListeners();

        return data['withdrawalId'] ?? '';
      } else {
        throw Exception('Worker returned success=false');
      }
    } catch (e) {
      _error = 'Failed to request withdrawal: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Fallback: Request withdrawal using direct Firestore (not optimized)
  /// ONLY USE IF WORKER IS DOWN
  Future<String> requestWithdrawalFallback({
    required int amount,
    required String method,
    required String paymentId,
  }) async {
    if (_userData == null) throw Exception('User not loaded');
    if (amount < 500) throw Exception('Minimum withdrawal amount is 500 coins');
    if (_userData!.coins < amount) {
      throw Exception('Insufficient balance for withdrawal');
    }

    // Validate payment details
    if (method == 'UPI' && !_isValidUPI(paymentId)) {
      throw Exception('Invalid UPI ID format');
    }
    if (method == 'BANK' && !_isValidBankAccount(paymentId)) {
      throw Exception('Invalid bank account details');
    }

    try {
      final uid = _userData!.uid;
      final firestore = FirebaseFirestore.instance;

      // Use transaction to ensure atomicity
      final withdrawalId = await firestore.runTransaction((transaction) async {
        final userRef = firestore.collection('users').doc(uid);
        final userSnap = await transaction.get(userRef);
        final currentBalance = userSnap['coins'] ?? 0;

        if (currentBalance < amount) {
          throw Exception('Insufficient balance for withdrawal');
        }

        // Create withdrawal document
        final withdrawalRef = firestore.collection('withdrawals').doc();
        transaction.set(withdrawalRef, {
          'userId': uid,
          'amount': amount,
          'paymentMethod': method,
          'paymentDetails': paymentId,
          'status': 'PENDING',
          'requestedAt': FieldValue.serverTimestamp(),
          'lastActionTimestamp': FieldValue.serverTimestamp(),
        });

        // Deduct coins from user (atomic)
        transaction.update(userRef, {'coins': FieldValue.increment(-amount)});

        // Create audit trail for withdrawal
        transaction.set(userRef.collection('actions').doc(), {
          'type': 'WITHDRAWAL_REQUEST',
          'amount': -amount,
          'withdrawalId': withdrawalRef.id,
          'timestamp': FieldValue.serverTimestamp(),
          'userId': uid,
        });

        return withdrawalRef.id;
      });

      _userData!.coins -= amount;
      await LocalStorageService.saveUserData(_userData!);
      notifyListeners();

      return withdrawalId;
    } catch (e) {
      _error = 'Failed to request withdrawal: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Validate UPI ID format (name@bank)
  bool _isValidUPI(String upi) {
    final regex = RegExp(r'^[a-zA-Z0-9.\-_]{3,}@[a-zA-Z]{3,}$');
    return regex.hasMatch(upi);
  }

  /// Validate bank account (9-18 digits)
  bool _isValidBankAccount(String account) {
    final digits = account.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 9 && digits.length <= 18;
  }

  /// Process referral bonus using Worker (optimized for Firestore cost)
  /// Atomic transaction ensures referrer and new user both get bonuses or neither do
  Future<void> processReferral(String referralCode) async {
    if (_userData == null) throw Exception('User not loaded');
    if (_userData!.referredBy != null) {
      throw Exception('You have already used a referral code');
    }
    if (referralCode == _userData!.referralCode) {
      throw Exception('Cannot use your own referral code');
    }

    try {
      // ✅ Phase 1.5: Call Worker instead of direct Firestore update
      final workerService = WorkerService();

      // Call worker endpoint for atomic referral claim
      final result = await workerService.claimReferral(
        referralCode: referralCode,
      );

      if (result['success'] == true) {
        // Update local state with worker response
        final data = result['data'] as Map<String, dynamic>;

        _userData!.coins += (data['claimerBonus'] as num?)?.toInt() ?? 50;
        _userData!.referredBy = referralCode;

        // Cache locally
        await LocalStorageService.saveUserData(_userData!);
        notifyListeners();
      } else {
        throw Exception('Worker returned success=false');
      }
    } catch (e) {
      _error = 'Failed to process referral: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Fallback: Process referral using direct Firestore (not optimized)
  /// ONLY USE IF WORKER IS DOWN
  Future<void> processReferralFallback(String referralCode) async {
    if (_userData == null) throw Exception('User not loaded');
    if (_userData!.referredBy != null) {
      throw Exception('You have already used a referral code');
    }
    if (referralCode == _userData!.referralCode) {
      throw Exception('Cannot use your own referral code');
    }

    try {
      final firestore = FirebaseFirestore.instance;

      // Find user with this referral code
      final referrerQuery = await firestore
          .collection('users')
          .where('referralCode', isEqualTo: referralCode)
          .limit(1)
          .get();

      if (referrerQuery.docs.isEmpty) {
        throw Exception('Invalid referral code');
      }

      final referrerId = referrerQuery.docs.first.id;
      final referralBonus = 50;

      // Use transaction for atomicity
      await firestore.runTransaction((transaction) async {
        final userRef = firestore.collection('users').doc(_userData!.uid);
        final referrerRef = firestore.collection('users').doc(referrerId);

        // Read current state
        final userSnap = await transaction.get(userRef);
        final userData = userSnap.data() as Map<String, dynamic>;

        // CRITICAL: Check that referredBy is still null (prevents double-claim)
        if (userData['referredBy'] != null) {
          throw Exception('You have already used a referral code');
        }

        // Give bonus to new user
        transaction.update(userRef, {
          'coins': FieldValue.increment(referralBonus),
          'referredBy': referralCode,
        });

        // Create audit trail for new user
        transaction.set(userRef.collection('actions').doc(), {
          'type': 'REFERRAL_BONUS',
          'amount': referralBonus,
          'referrerCode': referralCode,
          'timestamp': FieldValue.serverTimestamp(),
          'userId': _userData!.uid,
        });

        // Give bonus to referrer
        transaction.update(referrerRef, {
          'coins': FieldValue.increment(referralBonus),
          'totalReferrals': FieldValue.increment(1),
        });

        // Create audit trail for referrer
        transaction.set(referrerRef.collection('actions').doc(), {
          'type': 'REFERRAL_REWARD',
          'amount': referralBonus,
          'referredUserId': _userData!.uid,
          'timestamp': FieldValue.serverTimestamp(),
          'userId': referrerId,
        });
      });

      _userData!.coins += referralBonus;
      _userData!.referredBy = referralCode;
      await LocalStorageService.saveUserData(_userData!);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to process referral: $e';
      notifyListeners();
      rethrow;
    }
  }

  void clearUserData() {
    _userData = null;
    notifyListeners();
  }

  /// Increment watched ads counter with lazy daily reset
  /// Called after a rewarded ad gives coins
  /// CRITICAL: Checks if day changed before incrementing
  /// If new day, resets counter to 1 instead of incrementing from old value
  /// Prevents "can't watch ads on new day" bug when watchedAdsToday was at limit
  Future<void> incrementWatchedAds(int coinsEarned, {String? adUnitId}) async {
    if (_userData == null) return;

    try {
      // ✅ Phase 1: Call Worker instead of direct Firestore update
      final workerService = WorkerService();

      // Validate ad unit ID
      if (adUnitId == null || adUnitId.isEmpty) {
        throw Exception('Ad unit ID is required');
      }

      // Call worker endpoint for atomic verification & reward
      final result = await workerService.verifyAdReward(adUnitId: adUnitId);

      if (result['success'] == true) {
        // Update local state with worker response
        final data = result['data'] as Map<String, dynamic>;

        _userData!.coins = data['newBalance'] ?? _userData!.coins + coinsEarned;
        _userData!.watchedAdsToday =
            data['adsWatchedToday'] ?? _userData!.watchedAdsToday + 1;
        _userData!.totalAdsWatched += 1;
        _userData!.lastAdResetDate = DateTime.now();

        // Cache locally
        await LocalStorageService.saveUserData(_userData!);
        notifyListeners();
      } else {
        throw Exception('Worker returned success=false');
      }
    } catch (e) {
      _error = 'Failed to claim ad reward: $e';
      notifyListeners();
      rethrow; // Re-throw so UI can handle the error
    }
  }

  /// Fallback method: Direct Firestore update (if worker is unavailable)
  /// ONLY USE FOR EMERGENCY FALLBACK - Uses direct writes (not optimized)
  Future<void> incrementWatchedAdsFallback(int coinsEarned) async {
    if (_userData == null) return;

    try {
      final uid = _userData!.uid;
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final now = DateTime.now();
      final lastReset = _userData!.lastAdResetDate ?? now;

      // CRITICAL: Check if today's date differs from last reset date
      final isNewDay =
          now.day != lastReset.day ||
          now.month != lastReset.month ||
          now.year != lastReset.year;

      if (isNewDay) {
        // Reset counter for new day (don't increment old value)
        await userRef.update({
          'watchedAdsToday': 1, // ← Reset to 1, not increment
          'lastAdResetDate': FieldValue.serverTimestamp(),
          'coins': FieldValue.increment(coinsEarned),
        });

        _userData!.watchedAdsToday = 1;
        _userData!.lastAdResetDate = DateTime.now();
      } else {
        // Same day, increment normally
        await userRef.update({
          'watchedAdsToday': FieldValue.increment(1),
          'coins': FieldValue.increment(coinsEarned),
        });

        _userData!.watchedAdsToday++;
      }

      // Create audit trail
      await userRef.collection('actions').add({
        'type': 'AD_WATCHED',
        'amount': coinsEarned,
        'isNewDay': isNewDay,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': uid,
      });

      _userData!.coins += coinsEarned;
      _userData!.totalAdsWatched += 1;
      await LocalStorageService.saveUserData(_userData!);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to increment watched ads: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Add a bonus spin to the user's spinsRemaining
  Future<void> addBonusSpin() async {
    if (_userData == null) return;

    try {
      _userData!.totalSpins += 1;
      _userData!.spinsRemaining += 1;
      await LocalStorageService.saveUserData(_userData!);

      final uid = _userData!.uid;
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      await userRef.update({
        'totalSpins': FieldValue.increment(1),
        'spinsRemaining': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      notifyListeners();
    } catch (e) {
      _error = 'Failed to add bonus spin: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Reset spins for new day with lazy evaluation
  /// CRITICAL: Resets spins only on new day when first spin is used
  /// Prevents "stuck at 0 spins" bug on new day
  Future<void> resetSpinsIfNewDay() async {
    if (_userData == null) return;

    try {
      final now = DateTime.now();
      final lastReset = _userData!.lastSpinResetDate ?? now;

      // Check if today's date differs from last reset date
      final isNewDay =
          now.day != lastReset.day ||
          now.month != lastReset.month ||
          now.year != lastReset.year;

      if (!isNewDay) {
        return; // Same day, no reset needed
      }

      final uid = _userData!.uid;
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      // Reset to 3 spins for new day
      await userRef.update({
        'spinsRemaining': 3, // ← Reset to 3, not increment
        'lastSpinResetDate': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      _userData!.spinsRemaining = 3;
      _userData!.lastSpinResetDate = DateTime.now();

      // Create audit trail
      await userRef.collection('actions').add({
        'type': 'DAILY_SPIN_RESET',
        'newSpins': 3,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': uid,
      });

      await LocalStorageService.saveUserData(_userData!);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to reset spins: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Claim spin reward with optional ad watch bonus
  /// Uses transaction to ensure atomicity
  Future<void> claimSpinReward(int coinAmount, {bool watchedAd = false}) async {
    if (_userData == null) throw Exception('User not loaded');

    try {
      final uid = _userData!.uid;
      final firestore = FirebaseFirestore.instance;
      final userRef = firestore.collection('users').doc(uid);

      // Use transaction to ensure atomicity
      await firestore.runTransaction((transaction) async {
        final userSnap = await transaction.get(userRef);
        final currentSpins = (userSnap['totalSpins'] as int?) ?? 0;

        if (currentSpins <= 0) {
          throw Exception('No spins remaining');
        }

        // Update user with coins and spin decrement
        transaction.update(userRef, {
          'coins': FieldValue.increment(coinAmount),
          'totalSpins': FieldValue.increment(-1),
          'lastSpinTime': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // Create audit trail
        transaction.set(userRef.collection('actions').doc(), {
          'type': 'SPIN_REWARD',
          'amount': coinAmount,
          'watchedAd': watchedAd,
          'timestamp': FieldValue.serverTimestamp(),
          'userId': uid,
        });
      });

      // Update local data
      _userData!.coins += coinAmount;
      _userData!.totalSpins = (_userData!.totalSpins - 1).clamp(0, spinsPerDay);
      await LocalStorageService.saveUserData(_userData!);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to claim spin reward: $e';
      notifyListeners();
      rethrow;
    }
  }
}

const int spinsPerDay = 3;
