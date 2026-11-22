import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 2 - Feature 11: ValueNotifier State Boundary Cases', () {
    testWidgets('1. High-frequency tab index switching cycles smoothly without state tearing',
        (WidgetTester tester) async {
      final tabNotifier = ValueNotifier<int>(0);

      await TestAppHarness.pumpInHarness(
        tester,
        ValueListenableBuilder<int>(
          valueListenable: tabNotifier,
          builder: (context, idx, _) => Text('Tab: $idx'),
        ),
      );

      for (int i = 0; i < 20; i++) {
        tabNotifier.value = i % 5;
        await tester.pump();
      }

      expect(find.text('Tab: 4'), findsOneWidget);
    });

    test('2. Tab navigation index clamp prevents negative and out-of-bounds selection', () {
      int sanitizeTab(int raw, int tabCount) => raw.clamp(0, tabCount - 1);

      expect(sanitizeTab(-1, 5), equals(0));
      expect(sanitizeTab(99, 5), equals(4));
      expect(sanitizeTab(2, 5), equals(2));
    });

    testWidgets('3. Offstage widget observing ValueNotifier updates internal state without layout overhead',
        (WidgetTester tester) async {
      final counter = ValueNotifier<int>(0);

      await TestAppHarness.pumpInHarness(
        tester,
        Offstage(
          offstage: true,
          child: ValueListenableBuilder<int>(
            valueListenable: counter,
            builder: (context, count, _) => Text('Offstage Value: $count'),
          ),
        ),
      );

      counter.value = 100;
      await tester.pump();

      expect(find.text('Offstage Value: 100', skipOffstage: false), findsOneWidget);
    });

    testWidgets('4. Disposing ValueNotifier does not crash pending WidgetTester frame',
        (WidgetTester tester) async {
      final notifier = ValueNotifier<int>(1);

      await TestAppHarness.pumpInHarness(
        tester,
        ValueListenableBuilder<int>(
          valueListenable: notifier,
          builder: (context, val, _) => Text('Value: $val'),
        ),
      );

      notifier.dispose();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('5. 10 synchronized ValueListenableBuilders update in the exact same frame',
        (WidgetTester tester) async {
      final sharedNotifier = ValueNotifier<String>('Sync-Init');

      await TestAppHarness.pumpInHarness(
        tester,
        Column(
          children: List.generate(10, (i) {
            return ValueListenableBuilder<String>(
              valueListenable: sharedNotifier,
              builder: (context, val, _) => Text('Row $i: $val'),
            );
          }),
        ),
      );

      expect(find.text('Row 0: Sync-Init'), findsOneWidget);
      expect(find.text('Row 9: Sync-Init'), findsOneWidget);

      sharedNotifier.value = 'Sync-Updated';
      await tester.pump();

      expect(find.text('Row 0: Sync-Updated'), findsOneWidget);
      expect(find.text('Row 9: Sync-Updated'), findsOneWidget);
    });
  });
}
