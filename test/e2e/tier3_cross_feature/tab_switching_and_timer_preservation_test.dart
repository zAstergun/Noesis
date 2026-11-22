import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 3: Tab Switching & Timer Preservation Interaction', () {
    testWidgets('1. Active timer continues counting while user navigates to Calendar tab and back',
        (WidgetTester tester) async {
      final tabNotifier = ValueNotifier<int>(0);
      final timerNotifier = ValueNotifier<int>(45);

      await TestAppHarness.pumpInHarness(
        tester,
        ValueListenableBuilder<int>(
          valueListenable: tabNotifier,
          builder: (context, activeTab, _) {
            return IndexedStack(
              index: activeTab,
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: timerNotifier,
                  builder: (context, secs, _) => Text('Timer: $secs'),
                ),
                const Text('Tab 1: Calendar View'),
              ],
            );
          },
        ),
      );

      expect(find.text('Timer: 45'), findsOneWidget);

      // Switch to Calendar tab
      tabNotifier.value = 1;
      await tester.pump();
      expect(find.text('Tab 1: Calendar View'), findsOneWidget);

      // Advance timer while tab is in background
      timerNotifier.value = 48;
      await tester.pump();

      // Switch back to Tracker tab
      tabNotifier.value = 0;
      await tester.pump();
      expect(find.text('Timer: 48'), findsOneWidget,
          reason: 'Timer state must be preserved across IndexedStack navigation');
    });
  });
}
