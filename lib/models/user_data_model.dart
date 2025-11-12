class UserData {
  final String uid;
  int coins;
  DailyStreak dailyStreak;
  int spinsRemaining;
  int watchedAdsToday;
  String referralCode;
  DateTime lastSync;
  String email;
  String displayName;
  DateTime createdAt;

  UserData({
    required this.uid,
    this.coins = 0,
    required this.dailyStreak,
    this.spinsRemaining = 3,
    this.watchedAdsToday = 0,
    required this.referralCode,
    required this.lastSync,
    required this.email,
    required this.displayName,
    required this.createdAt,
  });

  factory UserData.fromMap(Map<String, dynamic> map) {
    return UserData(
      uid: map['uid'] ?? '',
      coins: map['coins'] ?? 0,
      dailyStreak: DailyStreak.fromMap(map['dailyStreak'] ?? {}),
      spinsRemaining: map['spinsRemaining'] ?? 3,
      watchedAdsToday: map['watchedAdsToday'] ?? 0,
      referralCode: map['referralCode'] ?? '',
      lastSync: map['lastSync'] != null
          ? DateTime.parse(map['lastSync'].toString())
          : DateTime.now(),
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'coins': coins,
      'dailyStreak': dailyStreak.toMap(),
      'spinsRemaining': spinsRemaining,
      'watchedAdsToday': watchedAdsToday,
      'referralCode': referralCode,
      'lastSync': lastSync.toIso8601String(),
      'email': email,
      'displayName': displayName,
      'createdAt': createdAt.toIso8601String(),
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
      lastCheckIn: map['lastCheckIn'] != null
          ? DateTime.parse(map['lastCheckIn'].toString())
          : null,
      checkInDates: List<String>.from(map['checkInDates'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currentStreak': currentStreak,
      'lastCheckIn': lastCheckIn?.toIso8601String(),
      'checkInDates': checkInDates,
    };
  }
}
