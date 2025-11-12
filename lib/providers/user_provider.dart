import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
        _userData = UserData.fromMap(data);
        await LocalStorageService.saveUserData(_userData!);
      }
    } catch (e) {
      _error = 'Failed to load user data: $e';
      // Try to load from local cache
      _userData = await LocalStorageService.getUserData();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update coins using Cloud Function (secure)
  /// [amount] - positive or negative coin amount
  /// [reason] - why coins are being updated
  Future<void> updateCoins(int amount, {String reason = 'admin_bonus'}) async {
    if (_userData == null) return;

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'updateUserCoins',
      );
      final result = await callable.call({
        'uid': _userData!.uid,
        'amount': amount,
        'reason': reason,
      });

      final newBalance = result.data['newBalance'] as int;
      _userData!.coins = newBalance;

      await LocalStorageService.saveUserData(_userData!);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update coins: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Claim daily streak reward using Cloud Function (secure)
  Future<void> claimDailyStreak() async {
    if (_userData == null) return;

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'claimDailyStreak',
      );
      final result = await callable.call({});

      _userData!.dailyStreak.currentStreak = result.data['newStreak'] as int;
      _userData!.dailyStreak.lastCheckIn = DateTime.now();
      _userData!.coins = result.data['newBalance'] as int;

      await LocalStorageService.saveUserData(_userData!);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to claim streak: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Request withdrawal using Cloud Function (secure)
  Future<String> requestWithdrawal({
    required int amount,
    required String method,
    required String paymentId,
  }) async {
    if (_userData == null) throw Exception('User not loaded');

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'requestWithdrawal',
      );
      final result = await callable.call({
        'amount': amount,
        'method': method,
        'paymentId': paymentId,
      });

      final newBalance = result.data['newBalance'] as int;
      final withdrawalId = result.data['withdrawalId'] as String;

      _userData!.coins = newBalance;
      await LocalStorageService.saveUserData(_userData!);
      notifyListeners();

      return withdrawalId;
    } catch (e) {
      _error = 'Failed to request withdrawal: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Process referral bonus using Cloud Function (secure)
  Future<void> processReferral(String referralCode) async {
    if (_userData == null) throw Exception('User not loaded');

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'processReferralBonus',
      );
      final result = await callable.call({
        'referralCode': referralCode,
        'newUserId': _userData!.uid,
      });

      _userData!.coins = result.data['newUserCoins'] as int;
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
