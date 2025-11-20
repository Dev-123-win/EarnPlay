import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:earnplay/services/event_queue_service.dart';

void main() {
  group('EventQueueService', () {
    late EventQueueService eventQueue;

    setUp(() async {
      // Initialize Hive for testing
      await Hive.initFlutter();
      eventQueue = EventQueueService();
      await eventQueue.initialize();
    });

    tearDown(() async {
      await eventQueue.dispose();
    });

    test('addEvent persists to Hive immediately', () async {
      await eventQueue.addEvent(userId: 'user1', type: 'GAME_WON', coins: 10);

      final pending = eventQueue.getPendingEvents();
      expect(pending.length, 1);
      expect(pending[0]['type'], 'GAME_WON');
      expect(pending[0]['coins'], 10);
      expect(pending[0]['status'], 'PENDING');
    });

    test('multiple events persist to Hive', () async {
      await eventQueue.addEvent(userId: 'user1', type: 'GAME_WON', coins: 10);
      await eventQueue.addEvent(userId: 'user1', type: 'AD_WATCHED', coins: 12);
      await eventQueue.addEvent(
        userId: 'user1',
        type: 'SPIN_CLAIMED',
        coins: 20,
      );

      final pending = eventQueue.getPendingEvents();
      expect(pending.length, 3);
      expect(pending[0]['type'], 'GAME_WON');
      expect(pending[1]['type'], 'AD_WATCHED');
      expect(pending[2]['type'], 'SPIN_CLAIMED');
    });

    test('markInflight updates event status to INFLIGHT', () async {
      await eventQueue.addEvent(userId: 'user1', type: 'GAME_WON', coins: 10);

      final pending = eventQueue.getPendingEvents();
      final eventId = pending[0]['id'] as String;

      await eventQueue.markInflight([eventId]);

      final inflight = eventQueue.getPendingEvents();
      expect(inflight.isEmpty, true); // INFLIGHT events not in pending
    });

    test('markSynced removes event from queue', () async {
      await eventQueue.addEvent(userId: 'user1', type: 'GAME_WON', coins: 10);

      final pending = eventQueue.getPendingEvents();
      final eventId = pending[0]['id'] as String;

      await eventQueue.markInflight([eventId]);
      await eventQueue.markSynced([eventId]);

      final remaining = eventQueue.getPendingEvents();
      expect(remaining.isEmpty, true);
    });

    test('markPending requeues events on failure', () async {
      await eventQueue.addEvent(userId: 'user1', type: 'GAME_WON', coins: 10);

      final pending = eventQueue.getPendingEvents();
      final eventId = pending[0]['id'] as String;

      await eventQueue.markInflight([eventId]);

      var pending2 = eventQueue.getPendingEvents();
      expect(pending2.isEmpty, true); // No pending after inflight

      await eventQueue.markPending([eventId]);

      final pending3 = eventQueue.getPendingEvents();
      expect(pending3.length, 1);
      expect(pending3[0]['status'], 'PENDING');
    });

    test('shouldFlushBySize returns true at threshold', () async {
      // Add 49 events (below threshold)
      for (int i = 0; i < 49; i++) {
        await eventQueue.addEvent(userId: 'user1', type: 'GAME_WON', coins: 10);
      }

      expect(eventQueue.shouldFlushBySize(threshold: 50), false);

      // Add 1 more (reaches threshold)
      await eventQueue.addEvent(userId: 'user1', type: 'GAME_WON', coins: 10);

      expect(eventQueue.shouldFlushBySize(threshold: 50), true);
    });

    test('clear removes all events', () async {
      await eventQueue.addEvent(userId: 'user1', type: 'GAME_WON', coins: 10);
      await eventQueue.addEvent(userId: 'user1', type: 'AD_WATCHED', coins: 12);

      await eventQueue.clear();

      final pending = eventQueue.getPendingEvents();
      expect(pending.isEmpty, true);
    });

    test('idempotency key is unique per event', () async {
      await eventQueue.addEvent(userId: 'user1', type: 'GAME_WON', coins: 10);
      await eventQueue.addEvent(userId: 'user1', type: 'GAME_WON', coins: 10);

      final pending = eventQueue.getPendingEvents();
      expect(pending[0]['idempotencyKey'], isNotEmpty);
      expect(pending[1]['idempotencyKey'], isNotEmpty);
      expect(
        pending[0]['idempotencyKey'] != pending[1]['idempotencyKey'],
        true,
      );
    });

    test('events persist across app restart', () async {
      // Add events
      await eventQueue.addEvent(userId: 'user1', type: 'GAME_WON', coins: 10);

      // Simulate app restart
      await eventQueue.dispose();
      final eventQueue2 = EventQueueService();
      await eventQueue2.initialize();

      // Events should still be there
      final pending = eventQueue2.getPendingEvents();
      expect(pending.length, 1);
      expect(pending[0]['type'], 'GAME_WON');
      expect(pending[0]['coins'], 10);

      await eventQueue2.dispose();
    });

    test('metadata is preserved in events', () async {
      await eventQueue.addEvent(
        userId: 'user1',
        type: 'GAME_WON',
        coins: 10,
        metadata: {
          'gameName': 'tictactoe',
          'duration': 300,
          'difficulty': 'hard',
        },
      );

      final pending = eventQueue.getPendingEvents();
      expect(pending[0]['metadata']['gameName'], 'tictactoe');
      expect(pending[0]['metadata']['duration'], 300);
      expect(pending[0]['metadata']['difficulty'], 'hard');
    });

    test('queue length getter works correctly', () async {
      expect(eventQueue.length, 0);

      await eventQueue.addEvent(userId: 'user1', type: 'GAME_WON', coins: 10);

      expect(eventQueue.length, 1);

      await eventQueue.addEvent(userId: 'user1', type: 'AD_WATCHED', coins: 12);

      expect(eventQueue.length, 2);
    });
  });
}
