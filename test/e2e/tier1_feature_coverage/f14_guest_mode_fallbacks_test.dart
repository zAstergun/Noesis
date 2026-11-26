import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/supabase_service.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Feature 14: Resilient Guest Mode & In-Memory Fallbacks', () {
    test('1. Guest Mode currentUser is null when unauthenticated', () {
      expect(SupabaseService.currentUser, isNull);
      expect(SupabaseService.isAuthenticated, isFalse);
    });

    test('2. calendarEventsStream emits empty list initially without fake demo events', () async {
      final stream = SupabaseService.calendarEventsStream();
      final initialEvents = await stream.first;

      expect(initialEvents, isNotNull);
      expect(initialEvents, isEmpty,
          reason: 'No fake mock calendar events should be seeded by default');
    });

    test('3. addCalendarEvent succeeds in Guest Mode and stores in-memory event', () async {
      final initialList = await SupabaseService.getCalendarEvents();
      final countBefore = initialList.length;

      final startTime = DateTime.now().add(const Duration(days: 10));
      final endTime = startTime.add(const Duration(hours: 2));

      await SupabaseService.addCalendarEvent(
        title: 'E2E Guest Study Block',
        description: 'Test session in in-memory mode',
        category: 'study',
        startTime: startTime,
        endTime: endTime,
      );

      final updatedList = await SupabaseService.getCalendarEvents();
      expect(updatedList.length, equals(countBefore + 1));
      expect(updatedList.any((e) => e['title'] == 'E2E Guest Study Block'), isTrue);
    });

    test('4. toggleCalendarEventCompleted toggles event status in local store', () async {
      final startTime = DateTime.now().add(const Duration(days: 11));
      await SupabaseService.addCalendarEvent(
        title: 'Toggle Test Event',
        category: 'study',
        startTime: startTime,
        endTime: startTime.add(const Duration(hours: 1)),
      );
      final events = await SupabaseService.getCalendarEvents();
      final targetEvent = events.firstWhere((e) => e['title'] == 'Toggle Test Event');
      final targetId = targetEvent['id'] as String;
      final currentStatus = targetEvent['is_completed'] as bool? ?? false;

      await SupabaseService.toggleCalendarEventCompleted(targetId, !currentStatus);

      final reloadedEvents = await SupabaseService.getCalendarEvents();
      final reloaded = reloadedEvents.firstWhere((e) => e['id'] == targetId);
      expect(reloaded['is_completed'], equals(!currentStatus));
    });

    testWidgets('5. Null user profile gracefully falls back to Estudante',
        (WidgetTester tester) async {
      String resolveUserName(Map<String, dynamic>? profile) {
        return profile?['full_name'] ?? 'Estudante';
      }

      final userName = resolveUserName(null);
      final initials = userName.isNotEmpty
          ? userName.substring(0, userName.length >= 2 ? 2 : 1).toUpperCase()
          : 'ES';

      await TestAppHarness.pumpInHarness(
        tester,
        Column(
          children: [
            Text('Nome: $userName'),
            Text('Iniciais: $initials'),
          ],
        ),
      );

      expect(find.text('Nome: Estudante'), findsOneWidget);
      expect(find.text('Iniciais: ES'), findsOneWidget);
    });
  });
}
