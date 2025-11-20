import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'ad_service.dart';

/// Service to communicate with Cloudflare Worker for reward verification
/// Handles: Ad verification, game validation, spin wheel, streak claims, withdrawals, referrals
class WorkerService {
  static final WorkerService _instance = WorkerService._internal();

  factory WorkerService() {
    return _instance;
  }

  WorkerService._internal();

  /// Cloudflare Worker base URL
  /// ✅ Production: Connected to earnplay12345.workers.dev
  static const String workerBaseUrl =
      'https://earnplay12345.workers.dev'; // Production
  // static const String workerBaseUrl =
  //     'http://localhost:8787'; // Local development (commented out)

  /// Request timeout duration
  static const Duration requestTimeout = Duration(seconds: 30);

  /// Idempotency key tracking to prevent duplicate requests
  /// Maps request hash to response to enable deduplication
  final Map<String, Map<String, dynamic>> _idempotencyCache = {};

  /// Generate idempotency key from request parameters
  /// Unique per second to allow retry within 1 second to return same result
  String _generateIdempotencyKey(String requestType, String adUnitId) {
    final now = DateTime.now();
    // Create key that changes per second (allows dedup within same second)
    final timeWindow = now.millisecondsSinceEpoch ~/ 1000;
    final key = '$requestType-$adUnitId-$timeWindow';
    return sha256.convert(utf8.encode(key)).toString();
  }

  /// Verify ad watch and claim reward
  /// @param adUnitId: Google AdMob ad unit ID
  /// @return: Map with success status and new balance
  /// IDEMPOTENT: Multiple calls with same adUnitId within 1 second return cached result
  Future<Map<String, dynamic>> verifyAdReward({
    required String adUnitId,
  }) async {
    try {
      // DEDUPLICATION: Check if request was already processed this second
      final idempotencyKey = _generateIdempotencyKey('ad-reward', adUnitId);
      if (_idempotencyCache.containsKey(idempotencyKey)) {
        debugPrint('⚠️ Returning cached ad reward result (idempotent request)');
        return _idempotencyCache[idempotencyKey]!;
      }

      // Get Firebase ID token
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final idToken = await user.getIdToken();

      // Step 1: Request a short-lived server challenge
      final challengeResp = await http
          .post(
            Uri.parse('$workerBaseUrl/ad-challenge'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'adUnitId': adUnitId,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            }),
          )
          .timeout(requestTimeout);

      if (challengeResp.statusCode != 200) {
        final err = jsonDecode(challengeResp.body);
        throw Exception(err['error'] ?? 'Failed to obtain ad challenge');
      }

      final challengeData =
          jsonDecode(challengeResp.body) as Map<String, dynamic>;
      final challengeId = challengeData['challengeId'] as String;

      // At this point request the AdService to show a rewarded ad to the user.
      // Only proceed to verify with server after the SDK confirms reward was earned.
      final adService = AdService();

      final rewarded = await adService.showRewardedAd(
        onUserEarnedReward: (reward) {},
      );

      if (!rewarded) {
        throw Exception('Rewarded ad was not watched/completed');
      }

      // After user earned reward from SDK, call verify endpoint with challengeId.

      final payload = {
        'adUnitId': adUnitId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'challengeId': challengeId,
        'idempotencyKey': idempotencyKey,
      };

      // Make HTTP request to worker verify endpoint
      final response = await http
          .post(
            Uri.parse('$workerBaseUrl/verify-ad'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
              'Idempotency-Key': idempotencyKey,
            },
            body: jsonEncode(payload),
          )
          .timeout(requestTimeout);

      // Parse response
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = {
          'success': true,
          'data': data,
          'reward': data['reward'] ?? 5,
          'newBalance': data['newBalance'] ?? 0,
          'adsWatchedToday': data['adsWatchedToday'] ?? 1,
        };

        // CACHE: Store result for deduplication within this second
        _idempotencyCache[idempotencyKey] = result;

        return result;
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
  /// IDEMPOTENT: Multiple calls with same parameters within 1 second return cached result
  Future<Map<String, dynamic>> verifyGameReward({
    required String gameType, // 'tictactoe', 'whack_mole'
    required bool isWin,
    required int score,
  }) async {
    try {
      // DEDUPLICATION: Check if request was already processed this second
      final idempotencyKey = _generateIdempotencyKey(
        'game-reward',
        '$gameType-$isWin-$score',
      );
      if (_idempotencyCache.containsKey(idempotencyKey)) {
        debugPrint(
          '⚠️ Returning cached game reward result (idempotent request)',
        );
        return _idempotencyCache[idempotencyKey]!;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final idToken = await user.getIdToken();

      final payload = {
        'gameType': gameType,
        'isWin': isWin,
        'score': score,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'idempotencyKey':
            idempotencyKey, // ← Send to worker for server-side dedup
      };

      final response = await http
          .post(
            Uri.parse('$workerBaseUrl/verify-game'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
              'Idempotency-Key': idempotencyKey, // ← Also as HTTP header
            },
            body: jsonEncode(payload),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final result = {'success': true, 'data': jsonDecode(response.body)};

        // CACHE: Store result for deduplication within this second
        _idempotencyCache[idempotencyKey] = result;

        return result;
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

  /// ✅ PHASE 1.5: Batch multiple events to Worker for atomic processing
  /// Used for: game wins, ad watches, spin claims, streak claims
  /// Events are batched locally and sent every 60 seconds or when 50 events queued
  Future<Map<String, dynamic>> batchEvents({
    required String userId,
    required List<dynamic> events, // List<EventModel>
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final idToken = await user.getIdToken();

      // Convert EventModel list to JSON
      final eventJsonList = events.map((e) {
        if (e is Map) {
          return e;
        } else {
          return e.toJson(); // EventModel.toJson()
        }
      }).toList();

      final payload = {
        'userId': userId,
        'events': eventJsonList,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final response = await http
          .post(
            Uri.parse('$workerBaseUrl/batch-events'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'data': data,
          'newBalance': data['newBalance'] ?? 0,
          'deltaCoins': data['deltaCoins'] ?? 0,
          'processedCount': data['processedCount'] ?? 0,
        };
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error'] ?? 'Unknown error';

        if (response.statusCode == 429) {
          throw Exception('Rate limit exceeded: $errorMessage');
        } else if (response.statusCode == 401) {
          throw Exception('Authentication failed: Please re-login');
        } else if (response.statusCode == 400) {
          throw Exception('Invalid request: $errorMessage');
        } else {
          throw Exception('Worker error: $errorMessage');
        }
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
