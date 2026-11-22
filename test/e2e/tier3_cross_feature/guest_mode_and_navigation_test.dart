import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/supabase_service.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 3: Guest Mode & ValueNotifier Navigation Interaction', () {
    testWidgets('1. In-memory calendar events remain persistent across tab switches 0 -> 1 -> 3 -> 0',
        (WidgetTester tester) async {
      final tabNotifier = ValueNotifier<int>(0);

      // Seed a unique guest event
      await SupabaseService.addCalendarEvent(
        title: 'Nav Persistence Event',
        category: 'study',
        startTime: DateTime(2026, 12, 10, 9),
        endTime: DateTime(2026, 12, 10, 11),
      );

      await TestAppHarness.pumpInHarness(
        tester,
        ValueListenableBuilder<int>(
          valueListenable: tabNotifier,
          builder: (context, activeTab, _) {
            return IndexedStack(
              index: activeTab,
              children: [
                const Text('Tab 0: Tracker'),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: SupabaseService.getCalendarEvents(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const Text('Carregando...');
                    return Text('Tab 1: Eventos (${snap.data!.length})');
                  },
                ),
                const Text('Tab 2: AI Agent'),
                const Text('Tab 3: Simulados'),
              ],
            );
          },
        ),
      );

      expect(find.text('Tab 0: Tracker'), findsOneWidget);

      // Switch to Calendar
      tabNotifier.value = 1;
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      expect(find.textContaining('Tab 1: Eventos'), findsOneWidget);

      // Switch to Simulados
      tabNotifier.value = 3;
      await tester.pump();
      expect(find.text('Tab 3: Simulados'), findsOneWidget);

      // Switch back to Tracker
      tabNotifier.value = 0;
      await tester.pump();
      expect(find.text('Tab 0: Tracker'), findsOneWidget);

      // Verify guest data is intact
      final events = await SupabaseService.getCalendarEvents();
      expect(events.any((e) => e['title'] == 'Nav Persistence Event'), isTrue);
    });
  });
}
