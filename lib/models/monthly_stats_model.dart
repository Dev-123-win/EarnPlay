import 'package:cloud_firestore/cloud_firestore.dart';

/// Monthly aggregated stats for a user
/// Replaces per-game records to reduce Firestore writes
/// Document path: users/{uid}/monthly_stats/{YYYY-MM}
class MonthlyStats {
  final String month; // Format: "2025-11"
  int coinsEarned;
  int adsWatched;
  int gamesPlayed;
  int gameWins;
  int spinsUsed;
  int withdrawalRequests;
  DateTime lastUpdated;

  MonthlyStats({
    required this.month,
    this.coinsEarned = 0,
    this.adsWatched = 0,
    this.gamesPlayed = 0,
    this.gameWins = 0,
    this.spinsUsed = 0,
    this.withdrawalRequests = 0,
    required this.lastUpdated,
  });

  factory MonthlyStats.fromMap(Map<String, dynamic> map) {
    return MonthlyStats(
      month: map['month'] ?? '',
      coinsEarned: map['coinsEarned'] ?? 0,
      adsWatched: map['adsWatched'] ?? 0,
      gamesPlayed: map['gamesPlayed'] ?? 0,
      gameWins: map['gameWins'] ?? 0,
      spinsUsed: map['spinsUsed'] ?? 0,
      withdrawalRequests: map['withdrawalRequests'] ?? 0,
      lastUpdated: _parseTimestamp(map['lastUpdated']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp.runtimeType.toString().contains('Timestamp')) {
      try {
        return (timestamp as dynamic).toDate();
      } catch (e) {
        return DateTime.now();
      }
    }
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        return DateTime.now();
      }
    }
    if (timestamp is DateTime) {
      return timestamp;
    }
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'month': month,
      'coinsEarned': coinsEarned,
      'adsWatched': adsWatched,
      'gamesPlayed': gamesPlayed,
      'gameWins': gameWins,
      'spinsUsed': spinsUsed,
      'withdrawalRequests': withdrawalRequests,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  /// Get current month in format "2025-11"
  static String getCurrentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }
}

/// Audit trail for fraud detection
/// Document path: users/{uid}/actions/{actionId}
/// Immutable records of ALL coin-earning actions
class AuditAction {
  final String actionId;
  final String type; // GAME_WON, AD_WATCHED, SPIN_REWARD, REFERRAL_BONUS
  final int amount; // Coins earned
  final DateTime timestamp; // Server-generated, immutable
  final String userId;

  AuditAction({
    required this.actionId,
    required this.type,
    required this.amount,
    required this.timestamp,
    required this.userId,
  });

  factory AuditAction.fromMap(Map<String, dynamic> map, String actionId) {
    return AuditAction(
      actionId: actionId,
      type: map['type'] ?? '',
      amount: map['amount'] ?? 0,
      timestamp: _parseTimestamp(map['timestamp']) ?? DateTime.now(),
      userId: map['userId'] ?? '',
    );
  }

  static DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp.runtimeType.toString().contains('Timestamp')) {
      try {
        return (timestamp as dynamic).toDate();
      } catch (e) {
        return DateTime.now();
      }
    }
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        return DateTime.now();
      }
    }
    if (timestamp is DateTime) {
      return timestamp;
    }
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'amount': amount,
      'timestamp': FieldValue.serverTimestamp(),
      'userId': userId,
    };
  }
}
