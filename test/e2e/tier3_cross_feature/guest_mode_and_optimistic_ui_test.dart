import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/supabase_service.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 3: Guest Mode & Optimistic UI Interaction', () {
    testWidgets('1. Optimistic event addition immediately reflects in UI and synchronizes to in-memory store',
        (WidgetTester tester) async {
      final eventsNotifier = ValueNotifier<List<Map<String, dynamic>>>([]);

      // Load initial guest events
      final initial = await SupabaseService.getCalendarEvents();
      eventsNotifier.value = List.from(initial);

      await TestAppHarness.pumpInHarness(
        tester,
        ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: eventsNotifier,
          builder: (context, list, _) {
            return ListView.builder(
              itemCount: list.length,
              itemBuilder: (ctx, i) => Text(list[i]['title'] as String),
            );
          },
        ),
      );

      final countBefore = eventsNotifier.value.length;
      final newEvt = {
        'id': 'optimistic-evt-1',
        'title': 'Optimistic Guest Event',
        'category': 'study',
        'start_time': DateTime.now().toIso8601String(),
        'end_time': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      };

      // Synchronous optimistic update
      eventsNotifier.value = [newEvt, ...eventsNotifier.value];
      await tester.pump();

      expect(find.text('Optimistic Guest Event'), findsOneWidget);
      expect(eventsNotifier.value.length, equals(countBefore + 1));

      // Async persistence
      await SupabaseService.addCalendarEvent(
        title: 'Optimistic Guest Event',
        category: 'study',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
      );

      final persisted = await SupabaseService.getCalendarEvents();
      expect(persisted.any((e) => e['title'] == 'Optimistic Guest Event'), isTrue);
    });
  });
}
