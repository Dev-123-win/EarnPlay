import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../services/local_storage_service.dart';
import '../services/worker_service.dart';

/// Manages all coin-related operations (balance, updates, withdrawals)
/// EXTRACTED from UserProvider to reduce god object complexity
///
/// Responsibilities:
/// - Track user coin balance
/// - Handle coin increments/decrements
/// - Manage withdrawal requests
/// - Cache coin data locally
class CoinsProvider extends ChangeNotifier {
  int _coins = 0;
  String? _error;
  bool _isProcessing = false;

  int get coins => _coins;
  String? get error => _error;
  bool get isProcessing => _isProcessing;

  /// Update coins using FieldValue.increment() for atomicity
  /// Never use direct SET - always increment to prevent race conditions
  /// [amount] - positive or negative coin amount
  /// [reason] - why coins are being updated (for audit trail)
  Future<void> updateCoins(int amount, {String reason = 'admin_bonus'}) async {
    try {
      _isProcessing = true;
      _error = null;
      notifyListeners();
      // Prefer Worker batch for auditability/idempotency
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final uid = user.uid;

      // Optimistic update for UI responsiveness
      _coins += amount;
      await LocalStorageService.saveUserCoins(_coins);
      notifyListeners();

      // Prepare single-event batch to Worker
      final eventId = const Uuid().v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      final event = {
        'id': eventId,
        'type': 'MANUAL_BONUS',
        'coins': amount,
        'metadata': {'reason': reason},
        'timestamp': now,
        'idempotencyKey': '${uid}_${eventId}_$now',
      };

      final workerResult = await WorkerService().batchEvents(
        userId: uid,
        events: [event],
      );

      if (workerResult['success'] == true) {
        final data = workerResult['data'] as Map<String, dynamic>;
        if (data['newBalance'] != null) {
          _coins = data['newBalance'];
          await LocalStorageService.saveUserCoins(_coins);
          notifyListeners();
        }
      } else {
        // Revert optimistic update on failure
        _coins -= amount;
        await LocalStorageService.saveUserCoins(_coins);
        notifyListeners();
        throw Exception('Worker failed to process coin update');
      }
    } catch (e) {
      _error = 'Failed to update coins: $e';
      notifyListeners();
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Request withdrawal using Worker (optimized for Firestore cost)
  /// Atomic transaction prevents double-spending
  Future<String> requestWithdrawal({
    required int amount,
    required String method,
    required String paymentId,
  }) async {
    try {
      _isProcessing = true;
      _error = null;
      notifyListeners();

      if (amount < 500) {
        throw Exception('Minimum withdrawal amount is 500 coins');
      }
      if (_coins < amount) {
        throw Exception('Insufficient balance for withdrawal');
      }

      // Validate payment details
      if (method == 'UPI' && !_isValidUPI(paymentId)) {
        throw Exception('Invalid UPI ID format');
      }
      if (method == 'BANK' && !_isValidBankAccount(paymentId)) {
        throw Exception('Invalid bank account details');
      }

      // ✅ Call Worker for atomic withdrawal
      final workerService = WorkerService();
      final result = await workerService.requestWithdrawal(
        amount: amount,
        method: method,
        paymentId: paymentId,
      );

      if (result['success'] == true) {
        // Update local state with worker response
        final data = result['data'] as Map<String, dynamic>;
        _coins = data['newBalance'] ?? _coins - amount;

        // Cache locally
        await LocalStorageService.saveUserCoins(_coins);
        notifyListeners();

        return data['withdrawalId'] ?? '';
      } else {
        throw Exception('Worker returned success=false');
      }
    } catch (e) {
      _error = 'Failed to request withdrawal: $e';
      notifyListeners();
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
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

  /// Load coins from Firestore
  Future<void> loadCoins(String uid) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final doc = await userRef.get();
      if (doc.exists) {
        _coins = doc['coins'] as int? ?? 0;
        await LocalStorageService.saveUserCoins(_coins);
      }
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load coins: $e';
      // Try local cache
      _coins = (await LocalStorageService.getUserCoins()) ?? 0;
      notifyListeners();
    }
  }

  /// Get current user ID (will be injected or fetched from AuthProvider)
  // NOTE: _getUserId removed; use FirebaseAuth.instance.currentUser

  void clearCoins() {
    _coins = 0;
    notifyListeners();
  }
}
