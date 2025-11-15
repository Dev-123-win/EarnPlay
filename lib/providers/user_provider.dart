import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_data_model.dart';
import '../services/local_storage_service.dart';
import '../services/firebase_service.dart';

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

  /// Update coins using Firestore directly (secure via Firestore rules)
  /// [amount] - positive or negative coin amount
  /// [reason] - why coins are being updated
  Future<void> updateCoins(int amount, {String reason = 'admin_bonus'}) async {
    if (_userData == null) return;

    try {
      final uid = _userData!.uid;
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      // Record transaction in subcollection
      await userRef.collection('coin_transactions').add({
        'amount': amount,
        'reason': reason,
        'timestamp': Timestamp.now(),
      });

      // Update user coins
      await userRef.update({
        'coins': FieldValue.increment(amount),
        'lastUpdated': Timestamp.now(),
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

  /// Claim daily streak reward using atomic Firestore transaction
  Future<void> claimDailyStreak() async {
    if (_userData == null) return;

    try {
      final uid = _userData!.uid;
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      // Use transaction to ensure consistency
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final doc = await transaction.get(userRef);
        final currentData = doc.data() as Map<String, dynamic>;

        final currentStreak =
            ((currentData['dailyStreak']?['currentStreak'] as int?) ?? 0);
        final newStreak = currentStreak + 1;
        final streakReward = newStreak * 10; // 10 coins per day of streak

        // Update in transaction
        transaction.update(userRef, {
          'dailyStreak.currentStreak': newStreak,
          'dailyStreak.lastCheckIn': Timestamp.now(),
          'coins': FieldValue.increment(streakReward),
          'lastUpdated': Timestamp.now(),
        });
      });

      // Update local data with same calculation
      _userData!.dailyStreak.currentStreak += 1;
      _userData!.dailyStreak.lastCheckIn = DateTime.now();
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

  /// Request withdrawal using Firestore transaction (atomic operation)
  Future<String> requestWithdrawal({
    required int amount,
    required String method,
    required String paymentId,
  }) async {
    if (_userData == null) throw Exception('User not loaded');
    if (amount < 100) throw Exception('Minimum withdrawal amount is 100');
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
          'method': method,
          'paymentId': paymentId,
          'status': 'pending',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });

        // Deduct coins from user (atomic)
        transaction.update(userRef, {
          'coins': FieldValue.increment(-amount),
          'withdrawalHistory': FieldValue.arrayUnion([
            {'id': withdrawalRef.id, 'amount': amount, 'date': Timestamp.now()},
          ]),
          'lastUpdated': Timestamp.now(),
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

  /// Process referral bonus using Firestore directly (secure via Firestore rules)
  Future<void> processReferral(String referralCode) async {
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

      // Use batch to update both users atomically
      final batch = firestore.batch();

      final userRef = firestore.collection('users').doc(_userData!.uid);
      final referrerRef = firestore.collection('users').doc(referrerId);

      // Give bonus to new user
      batch.update(userRef, {
        'coins': FieldValue.increment(referralBonus),
        'referredBy': referralCode,
        'lastUpdated': Timestamp.now(),
      });

      // Give bonus to referrer
      batch.update(referrerRef, {
        'coins': FieldValue.increment(referralBonus),
        'totalReferrals': FieldValue.increment(1),
        'lastUpdated': Timestamp.now(),
      });

      await batch.commit();

      _userData!.coins += referralBonus;
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

  /// Increment watched ads counter locally and persist to Firestore.
  /// Called after a rewarded ad gives coins.
  Future<void> incrementWatchedAds() async {
    if (_userData == null) return;

    try {
      _userData!.watchedAdsToday = _userData!.watchedAdsToday + 1;
      await LocalStorageService.saveUserData(_userData!);
      // Persist to Firestore
      await FirebaseService().updateUserFields(_userData!.uid, {
        'watchedAdsToday': _userData!.watchedAdsToday,
      });
      notifyListeners();
    } catch (e) {
      _error = 'Failed to increment watched ads: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Add a bonus spin to the user's spinsRemaining and persist.
  Future<void> addBonusSpin() async {
    if (_userData == null) return;

    try {
      _userData!.spinsRemaining = _userData!.spinsRemaining + 1;
      await LocalStorageService.saveUserData(_userData!);
      await FirebaseService().updateUserFields(_userData!.uid, {
        'spinsRemaining': _userData!.spinsRemaining,
      });
      notifyListeners();
    } catch (e) {
      _error = 'Failed to add bonus spin: $e';
      notifyListeners();
      rethrow;
    }
  }
}
