import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/supabase_service.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 2 - Feature 14: Guest Mode In-Memory Boundary Cases', () {
    test('1. Concurrent addition of 5 calendar events in Guest Mode retains all entries', () async {
      final initialEvents = await SupabaseService.getCalendarEvents();
      final countBefore = initialEvents.length;

      final futures = List.generate(5, (i) {
        final start = DateTime(2026, 12, 1, 10 + i);
        return SupabaseService.addCalendarEvent(
          title: 'Concurrent Event $i',
          category: 'study',
          startTime: start,
          endTime: start.add(const Duration(hours: 1)),
        );
      });

      await Future.wait(futures);

      final updatedEvents = await SupabaseService.getCalendarEvents();
      expect(updatedEvents.length, equals(countBefore + 5));
    });

    test('2. Updating non-existent event ID in Guest Mode does not throw exception', () async {
      await expectLater(
        SupabaseService.updateCalendarEvent(
          id: 'non-existent-uuid-999',
          title: 'Updated Non-Existent',
        ),
        completes,
      );
    });

    test('3. Deleting non-existent event ID in Guest Mode does not throw exception', () async {
      await expectLater(
        SupabaseService.deleteCalendarEvent('non-existent-uuid-888'),
        completes,
      );
    });

    test('4. In-memory calendar events can be updated with partial fields', () async {
      final events = await SupabaseService.getCalendarEvents();
      final firstId = events.first['id'] as String;

      await SupabaseService.updateCalendarEvent(
        id: firstId,
        title: 'Title Changed Only',
      );

      final reloaded = await SupabaseService.getCalendarEvents();
      final updated = reloaded.firstWhere((e) => e['id'] == firstId);
      expect(updated['title'], equals('Title Changed Only'));
    });

    test('5. SignOut call in Guest Mode executes cleanly without network exception', () async {
      await expectLater(
        SupabaseService.signOut(),
        completes,
      );
    });
  });
}
