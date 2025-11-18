import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Service to communicate with Cloudflare Worker for reward verification
/// Handles: Ad verification, game validation, spin wheel, streak claims, withdrawals, referrals
class WorkerService {
  static final WorkerService _instance = WorkerService._internal();

  factory WorkerService() {
    return _instance;
  }

  WorkerService._internal();

  /// Cloudflare Worker base URL
  /// TODO: Replace with your actual deployed worker URL
  /// Example: 'https://earnplay-api.your-subdomain.workers.dev'
  static const String workerBaseUrl =
      'http://localhost:8787'; // Local development
  // static const String workerBaseUrl =
  //     'https://earnplay-api.your-subdomain.workers.dev'; // Production

  /// Request timeout duration
  static const Duration requestTimeout = Duration(seconds: 30);

  /// Verify ad watch and claim reward
  /// @param adUnitId: Google AdMob ad unit ID
  /// @return: Map with success status and new balance
  Future<Map<String, dynamic>> verifyAdReward({
    required String adUnitId,
  }) async {
    try {
      // Get Firebase ID token
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final idToken = await user.getIdToken();

      // Prepare request payload
      final payload = {
        'adUnitId': adUnitId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // Make HTTP request to worker
      final response = await http
          .post(
            Uri.parse('$workerBaseUrl/verify-ad'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(
            requestTimeout,
            onTimeout: () {
              throw Exception(
                'Worker request timed out. Check network connection.',
              );
            },
          );

      // Parse response
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'data': data,
          'reward': data['reward'] ?? 5,
          'newBalance': data['newBalance'] ?? 0,
          'adsWatchedToday': data['adsWatchedToday'] ?? 1,
        };
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error'] ?? 'Unknown error';

        // Handle specific HTTP status codes
        if (response.statusCode == 429) {
          throw Exception('Daily ad limit reached (10/day)');
        } else if (response.statusCode == 401) {
          throw Exception('Authentication failed. Please re-login.');
        } else if (response.statusCode == 404) {
          throw Exception('User profile not found.');
        } else if (response.statusCode == 400) {
          throw Exception(errorMessage);
        } else {
          throw Exception('Worker error: $errorMessage');
        }
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: ${e.message}. Is the worker running?');
    } catch (e) {
      rethrow;
    }
  }

  /// Verify game reward claim
  Future<Map<String, dynamic>> verifyGameReward({
    required String gameType, // 'tictactoe', 'whack_mole'
    required bool isWin,
    required int score,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final idToken = await user.getIdToken();

      final payload = {
        'gameType': gameType,
        'isWin': isWin,
        'score': score,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final response = await http
          .post(
            Uri.parse('$workerBaseUrl/verify-game'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Game verification failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Verify spin wheel claim
  Future<Map<String, dynamic>> verifySpin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final idToken = await user.getIdToken();

      final response = await http
          .post(
            Uri.parse('$workerBaseUrl/spin-wheel'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        throw Exception('Spin verification failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Verify daily streak claim
  Future<Map<String, dynamic>> claimStreak() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final idToken = await user.getIdToken();

      final response = await http
          .post(
            Uri.parse('$workerBaseUrl/claim-streak'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        throw Exception('Streak claim failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Request withdrawal
  /// Request withdrawal
  Future<Map<String, dynamic>> requestWithdrawal({
    required int amount,
    required String method,
    required String paymentId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final idToken = await user.getIdToken();

      final response = await http
          .post(
            Uri.parse('$workerBaseUrl/request-withdrawal'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'amount': amount,
              'method': method,
              'paymentId': paymentId,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
          'withdrawalId': data['withdrawalId'],
          'newBalance': data['newBalance'],
        };
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Withdrawal request failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Claim referral bonus
  Future<Map<String, dynamic>> claimReferral({
    required String referralCode,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final idToken = await user.getIdToken();

      final response = await http
          .post(
            Uri.parse('$workerBaseUrl/claim-referral'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'referralCode': referralCode,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        throw Exception('Referral claim failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Check if worker is reachable
  Future<bool> isWorkerHealthy() async {
    try {
      final response = await http
          .post(
            Uri.parse('$workerBaseUrl/verify-ad'),
            headers: {
              'Authorization': 'Bearer invalid-token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'adUnitId': 'test',
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            }),
          )
          .timeout(const Duration(seconds: 5));

      // Worker responds (even with 401 means it's working)
      return response.statusCode < 500;
    } catch (e) {
      return false;
    }
  }
}
