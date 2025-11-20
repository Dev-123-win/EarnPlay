import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class EventQueueService {
  static const String _boxName = 'eventQueue';
  late Box<Map<String, dynamic>> _box;
  bool isInitialized = false;

  /// Initialize Hive box for persistent storage
  /// CRITICAL: Call this on app startup before any events are added
  Future<void> initialize() async {
    if (isInitialized) return;

    try {
      _box = await Hive.openBox<Map<String, dynamic>>(_boxName);
      isInitialized = true;
      debugPrint('[EventQueue] Initialized with ${_box.length} pending events');
    } catch (e) {
      debugPrint('[EventQueue] Failed to initialize: $e');
      rethrow;
    }
  }

  /// Add event - SYNCHRONOUSLY persisted to Hive
  /// CRITICAL: Don't queue in memory only.
  /// If app crashes before Hive write, coins are lost forever.
  Future<void> addEvent({
    required String userId,
    required String type,
    required int coins,
    Map<String, dynamic>? metadata,
  }) async {
    if (!isInitialized) throw Exception('EventQueue not initialized');

    try {
      final eventId = const Uuid().v4();
      final now = DateTime.now();

      final event = <String, dynamic>{
        'id': eventId,
        'userId': userId,
        'type': type,
        'coins': coins,
        'metadata': metadata ?? {},
        'timestamp': now.millisecondsSinceEpoch,
        'idempotencyKey': '${userId}_${eventId}_${now.millisecondsSinceEpoch}',
        'status': 'PENDING', // PENDING | INFLIGHT | SYNCED
      };

      // CRITICAL: Write to Hive IMMEDIATELY
      // This ensures persistence even if app crashes
      await _box.put(eventId, event);

      debugPrint('[EventQueue] ✓ Event persisted: $type ($coins coins)');
    } catch (e) {
      debugPrint('[EventQueue] ✗ Failed to add event: $e');
      rethrow;
    }
  }

  /// Get all PENDING events (ready to sync)
  List<Map<String, dynamic>> getPendingEvents() {
    try {
      return _box.values
          .where((event) => event['status'] == 'PENDING')
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      debugPrint('[EventQueue] Failed to get pending: $e');
      return [];
    }
  }

  /// Mark events as INFLIGHT (prevent duplicate sends)
  Future<void> markInflight(List<String> eventIds) async {
    try {
      for (final id in eventIds) {
        final event = _box.get(id);
        if (event != null) {
          event['status'] = 'INFLIGHT';
          await _box.put(id, event);
        }
      }
      debugPrint('[EventQueue] ✓ Marked ${eventIds.length} as INFLIGHT');
    } catch (e) {
      debugPrint('[EventQueue] Failed to mark INFLIGHT: $e');
    }
  }

  /// Mark events as SYNCED and remove from queue
  Future<void> markSynced(List<String> eventIds) async {
    try {
      for (final id in eventIds) {
        await _box.delete(id);
      }
      debugPrint('[EventQueue] ✓ Removed ${eventIds.length} synced events');
    } catch (e) {
      debugPrint('[EventQueue] Failed to mark SYNCED: $e');
    }
  }

  /// Requeue events on flush failure
  Future<void> markPending(List<String> eventIds) async {
    try {
      for (final id in eventIds) {
        final event = _box.get(id);
        if (event != null) {
          event['status'] = 'PENDING';
          await _box.put(id, event);
        }
      }
      debugPrint('[EventQueue] ✓ Requeued ${eventIds.length} events');
    } catch (e) {
      debugPrint('[EventQueue] Failed to mark PENDING: $e');
    }
  }

  /// Check if queue is large enough to flush
  bool shouldFlushBySize({int threshold = 50}) {
    return getPendingEvents().length >= threshold;
  }

  /// Clear all events (use with caution)
  Future<void> clear() async {
    await _box.clear();
    debugPrint('[EventQueue] ✓ Cleared all events');
  }

  /// Get queue size
  int get length => _box.length;

  /// Dispose and close Hive box
  Future<void> dispose() async {
    try {
      await _box.close();
      isInitialized = false;
      debugPrint('[EventQueue] Disposed');
    } catch (e) {
      debugPrint('[EventQueue] Failed to dispose: $e');
    }
  }
}
