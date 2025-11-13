/// Game result model for storing game history
class GameResult {
  final String id;
  final String gameName;
  final bool isWon;
  final int coinsEarned;
  final DateTime playedAt;
  final int duration; // in seconds
  final Map<String, dynamic> gameData;

  GameResult({
    required this.id,
    required this.gameName,
    required this.isWon,
    required this.coinsEarned,
    required this.playedAt,
    required this.duration,
    Map<String, dynamic>? gameData,
  }) : gameData = gameData ?? {};

  factory GameResult.fromMap(Map<String, dynamic> map) {
    return GameResult(
      id: map['id'] ?? '',
      gameName: map['gameName'] ?? '',
      isWon: map['isWon'] ?? false,
      coinsEarned: map['coinsEarned'] ?? 0,
      playedAt: map['playedAt'] != null
          ? DateTime.parse(map['playedAt'].toString())
          : DateTime.now(),
      duration: map['duration'] ?? 0,
      gameData: map['gameData'] ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gameName': gameName,
      'isWon': isWon,
      'coinsEarned': coinsEarned,
      'playedAt': playedAt.toIso8601String(),
      'duration': duration,
      'gameData': gameData,
    };
  }
}

/// Withdrawal record model
class WithdrawalRecord {
  final String id;
  final String userId;
  final int amount;
  final String paymentMethod; // 'UPI' or 'BANK_TRANSFER'
  final String paymentDetails; // UPI ID or bank account
  final String status; // 'PENDING', 'APPROVED', 'REJECTED'
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? rejectionReason;

  WithdrawalRecord({
    required this.id,
    required this.userId,
    required this.amount,
    required this.paymentMethod,
    required this.paymentDetails,
    required this.status,
    required this.requestedAt,
    this.processedAt,
    this.rejectionReason,
  });

  factory WithdrawalRecord.fromMap(Map<String, dynamic> map) {
    return WithdrawalRecord(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      amount: map['amount'] ?? 0,
      paymentMethod: map['paymentMethod'] ?? '',
      paymentDetails: map['paymentDetails'] ?? '',
      status: map['status'] ?? 'PENDING',
      requestedAt: map['requestedAt'] != null
          ? DateTime.parse(map['requestedAt'].toString())
          : DateTime.now(),
      processedAt: map['processedAt'] != null
          ? DateTime.parse(map['processedAt'].toString())
          : null,
      rejectionReason: map['rejectionReason'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'paymentDetails': paymentDetails,
      'status': status,
      'requestedAt': requestedAt.toIso8601String(),
      'processedAt': processedAt?.toIso8601String(),
      'rejectionReason': rejectionReason,
    };
  }
}

/// Referral record model
class ReferralRecord {
  final String id;
  final String referrerUserId;
  final String referredUserId;
  final int rewardAmount;
  final DateTime referralDate;
  final bool isCompleted;

  ReferralRecord({
    required this.id,
    required this.referrerUserId,
    required this.referredUserId,
    required this.rewardAmount,
    required this.referralDate,
    required this.isCompleted,
  });

  factory ReferralRecord.fromMap(Map<String, dynamic> map) {
    return ReferralRecord(
      id: map['id'] ?? '',
      referrerUserId: map['referrerUserId'] ?? '',
      referredUserId: map['referredUserId'] ?? '',
      rewardAmount: map['rewardAmount'] ?? 0,
      referralDate: map['referralDate'] != null
          ? DateTime.parse(map['referralDate'].toString())
          : DateTime.now(),
      isCompleted: map['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'referrerUserId': referrerUserId,
      'referredUserId': referredUserId,
      'rewardAmount': rewardAmount,
      'referralDate': referralDate.toIso8601String(),
      'isCompleted': isCompleted,
    };
  }
}

/// Action queue for offline-first sync
class ActionQueue {
  final String id;
  final String userId;
  final String actionType; // 'GAME_WON', 'AD_WATCHED', 'SPIN', 'REFERRAL'
  final int coinsChange;
  final DateTime createdAt;
  final DateTime? syncedAt;
  final Map<String, dynamic> metadata;

  ActionQueue({
    required this.id,
    required this.userId,
    required this.actionType,
    required this.coinsChange,
    required this.createdAt,
    this.syncedAt,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};

  factory ActionQueue.fromMap(Map<String, dynamic> map) {
    return ActionQueue(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      actionType: map['actionType'] ?? '',
      coinsChange: map['coinsChange'] ?? 0,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'].toString())
          : DateTime.now(),
      syncedAt: map['syncedAt'] != null
          ? DateTime.parse(map['syncedAt'].toString())
          : null,
      metadata: map['metadata'] ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'actionType': actionType,
      'coinsChange': coinsChange,
      'createdAt': createdAt.toIso8601String(),
      'syncedAt': syncedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }
}
