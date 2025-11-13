import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Offline-first storage system with daily batch sync at 22:00 IST
class OfflineStorageService {
  static const String actionQueueCollection = 'action_queue';
  static const int batchSyncHour = 22; // 22:00 IST
  static const int randomDelaySeconds = 30;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<QueuedAction> _localQueue = [];
  Timer? _syncTimer;

  /// Initialize offline storage with automatic daily sync
  Future<void> initialize(String userId) async {
    _setupDailySync(userId);
    await _loadQueueFromFirestore(userId);
  }

  /// Add action to local queue (will be synced later)
  Future<void> queueAction({
    required String userId,
    required String actionType,
    required Map<String, dynamic> data,
  }) async {
    final action = QueuedAction(
      userId: userId,
      type: actionType,
      data: data,
      timestamp: DateTime.now(),
      synced: false,
    );

    _localQueue.add(action);
    await _persistLocalQueue(userId);
  }

  /// Get all pending actions
  List<QueuedAction> getPendingActions() =>
      _localQueue.where((a) => !a.synced).toList();

  /// Get queue size
  int getQueueSize() => _localQueue.length;

  /// Manual sync (can be called anytime)
  Future<bool> syncNow(String userId) async {
    if (_localQueue.isEmpty) return true;

    try {
      final batch = _firestore.batch();
      final timestamp = FieldValue.serverTimestamp();

      for (var action in _localQueue) {
        if (!action.synced) {
          final docRef = _firestore
              .collection('users')
              .doc(userId)
              .collection(actionQueueCollection)
              .doc(action.timestamp.millisecondsSinceEpoch.toString());

          batch.set(docRef, {
            'type': action.type,
            'data': action.data,
            'timestamp': timestamp,
            'clientTimestamp': action.timestamp.toIso8601String(),
          });

          action.synced = true;
        }
      }

      await batch.commit();

      // Clear synced actions
      _localQueue.removeWhere((a) => a.synced);
      await _persistLocalQueue(userId);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Setup daily sync at 22:00 IST ±30 seconds random delay
  void _setupDailySync(String userId) {
    _syncTimer?.cancel();

    final now = DateTime.now();
    final syncTime = DateTime(now.year, now.month, now.day, batchSyncHour, 0);

    Duration timeUntilSync;
    if (now.isBefore(syncTime)) {
      timeUntilSync = syncTime.difference(now);
    } else {
      // Next day
      final tomorrow = syncTime.add(const Duration(days: 1));
      timeUntilSync = tomorrow.difference(now);
    }

    // Add random delay (±30 seconds)
    final randomDelay = Duration(
      seconds: (DateTime.now().millisecond % randomDelaySeconds).toInt(),
    );
    final finalDelay = timeUntilSync + randomDelay;

    _syncTimer = Timer(finalDelay, () {
      _performDailySync(userId);
      _setupDailySync(userId); // Reschedule for next day
    });
  }

  /// Perform daily batch sync
  Future<void> _performDailySync(String userId) async {
    await syncNow(userId);
  }

  /// Load queue from Firestore subcollection
  Future<void> _loadQueueFromFirestore(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection(actionQueueCollection)
          .orderBy('timestamp')
          .get();

      _localQueue.clear();
      for (var doc in snapshot.docs) {
        _localQueue.add(
          QueuedAction(
            userId: userId,
            type: doc['type'] ?? '',
            data: doc['data'] ?? {},
            timestamp: DateTime.parse(
              doc['clientTimestamp'] ?? DateTime.now().toIso8601String(),
            ),
            synced: true,
          ),
        );
      }
    } catch (e) {
      // Silently handle load errors
    }
  }

  /// Persist local queue to device storage (for future SQLite/Hive implementation)
  Future<void> _persistLocalQueue(String userId) async {
    // TODO: Implement SQLite or Hive for persistent local storage
    // For now, queue is in-memory
  }

  /// Clear all queued actions
  Future<void> clearQueue(String userId) async {
    _localQueue.clear();
    await _persistLocalQueue(userId);
  }

  /// Cleanup
  void dispose() {
    _syncTimer?.cancel();
  }
}

/// Model for queued actions
class QueuedAction {
  final String userId;
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  bool synced;

  QueuedAction({
    required this.userId,
    required this.type,
    required this.data,
    required this.timestamp,
    required this.synced,
  });

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'type': type,
    'data': data,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'synced': synced,
  };

  factory QueuedAction.fromMap(Map<String, dynamic> map) => QueuedAction(
    userId: map['userId'] ?? '',
    type: map['type'] ?? '',
    data: map['data'] ?? {},
    timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
    synced: map['synced'] ?? false,
  );
}
