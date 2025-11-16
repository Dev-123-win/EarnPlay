class UserData {
  final String uid;
  int coins;
  DailyStreak dailyStreak;
  int spinsRemaining;
  int watchedAdsToday;
  DateTime?
  lastAdResetDate; // Track when ads were last reset (for lazy reset logic)
  DateTime?
  lastSpinResetDate; // Track when spins were last reset (for lazy reset logic)
  String referralCode;
  DateTime lastSync;
  String email;
  String displayName;
  DateTime createdAt;
  int totalGamesWon;
  int totalAdsWatched;
  int totalReferrals;
  int totalSpins;
  String? referredBy;

  UserData({
    required this.uid,
    this.coins = 0,
    required this.dailyStreak,
    this.spinsRemaining = 3,
    this.watchedAdsToday = 0,
    this.lastAdResetDate,
    this.lastSpinResetDate,
    required this.referralCode,
    required this.lastSync,
    required this.email,
    required this.displayName,
    required this.createdAt,
    this.totalGamesWon = 0,
    this.totalAdsWatched = 0,
    this.totalReferrals = 0,
    this.totalSpins = 0,
    this.referredBy,
  });

  factory UserData.fromMap(Map<String, dynamic> map) {
    return UserData(
      uid: map['uid'] ?? '',
      coins: map['coins'] ?? 0,
      dailyStreak: DailyStreak.fromMap(map['dailyStreak'] ?? {}),
      spinsRemaining: map['spinsRemaining'] ?? 3,
      watchedAdsToday: map['watchedAdsToday'] ?? 0,
      lastAdResetDate: _parseTimestamp(map['lastAdResetDate']),
      lastSpinResetDate: _parseTimestamp(map['lastSpinResetDate']),
      referralCode: map['referralCode'] ?? '',
      lastSync: _parseTimestamp(map['lastSync']) ?? DateTime.now(),
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
      totalGamesWon: map['totalGamesWon'] ?? 0,
      totalAdsWatched: map['totalAdsWatched'] ?? 0,
      totalReferrals: map['totalReferrals'] ?? 0,
      totalSpins: map['totalSpins'] ?? 0,
      referredBy: map['referredBy']?.toString(),
    );
  }

  static DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;

    // Handle Firestore Timestamp objects
    if (timestamp.runtimeType.toString().contains('Timestamp')) {
      try {
        return (timestamp as dynamic).toDate();
      } catch (e) {
        return DateTime.now();
      }
    }

    // Handle string timestamps
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        return DateTime.now();
      }
    }

    // Handle DateTime objects
    if (timestamp is DateTime) {
      return timestamp;
    }

    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'coins': coins,
      'dailyStreak': dailyStreak.toMap(),
      'spinsRemaining': spinsRemaining,
      'watchedAdsToday': watchedAdsToday,
      'lastAdResetDate': lastAdResetDate?.toIso8601String(),
      'lastSpinResetDate': lastSpinResetDate?.toIso8601String(),
      'referralCode': referralCode,
      'lastSync': lastSync.toIso8601String(),
      'email': email,
      'displayName': displayName,
      'createdAt': createdAt.toIso8601String(),
      'totalGamesWon': totalGamesWon,
      'totalAdsWatched': totalAdsWatched,
      'totalReferrals': totalReferrals,
      'totalSpins': totalSpins,
      'referredBy': referredBy,
    };
  }
}

class DailyStreak {
  int currentStreak;
  DateTime? lastCheckIn;
  List<String> checkInDates;

  DailyStreak({
    this.currentStreak = 0,
    this.lastCheckIn,
    List<String>? checkInDates,
  }) : checkInDates = checkInDates ?? [];

  factory DailyStreak.fromMap(Map<String, dynamic> map) {
    return DailyStreak(
      currentStreak: map['currentStreak'] ?? 0,
      lastCheckIn: _parseTimestampNullable(map['lastCheckIn']),
      checkInDates: List<String>.from(map['checkInDates'] ?? []),
    );
  }

  static DateTime? _parseTimestampNullable(dynamic timestamp) {
    if (timestamp == null) return null;

    // Handle Firestore Timestamp objects
    if (timestamp.runtimeType.toString().contains('Timestamp')) {
      try {
        return (timestamp as dynamic).toDate();
      } catch (e) {
        return null;
      }
    }

    // Handle string timestamps
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        return null;
      }
    }

    // Handle DateTime objects
    if (timestamp is DateTime) {
      return timestamp;
    }

    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'currentStreak': currentStreak,
      'lastCheckIn': lastCheckIn?.toIso8601String(),
      'checkInDates': checkInDates,
    };
  }
}
