import 'package:uuid/uuid.dart';

/// Represents a queued event (game win, ad watched, spin claimed, etc.)
/// These events are batched and sent to Worker in bulk every 60 seconds or when 50 events accumulated
class EventModel {
  final String id;
  final String type; // GAME_WON, AD_WATCHED, SPIN_CLAIMED, STREAK_CLAIMED
  final int coins;
  final Map<String, dynamic> metadata;
  final int timestamp; // milliseconds since epoch
  final String idempotencyKey;
  String status; // PENDING, INFLIGHT, SYNCED

  EventModel({
    String? id,
    required this.type,
    required this.coins,
    required this.metadata,
    int? timestamp,
    String? idempotencyKey,
    this.status = 'PENDING',
  }) : id = id ?? const Uuid().v4(),
       timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch,
       idempotencyKey = idempotencyKey ?? const Uuid().v4();

  /// Convert to JSON for HTTP/storage
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'coins': coins,
    'metadata': metadata,
    'timestamp': timestamp,
    'idempotencyKey': idempotencyKey,
    'status': status,
  };

  /// Convert from JSON
  factory EventModel.fromJson(Map<String, dynamic> json) => EventModel(
    id: json['id'] as String?,
    type: json['type'] as String,
    coins: json['coins'] as int,
    metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    timestamp: json['timestamp'] as int?,
    idempotencyKey: json['idempotencyKey'] as String?,
    status: json['status'] as String? ?? 'PENDING',
  );
}
