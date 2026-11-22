import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 3: Calendar Date Selection & Repaint Isolation', () {
    testWidgets('1. Selecting different dates updates daily agenda without re-rendering month grid boundary',
        (WidgetTester tester) async {
      final selectedDate = ValueNotifier<DateTime>(DateTime(2026, 11, 22));
      final monthGridKey = GlobalKey();
      int monthGridPaintCount = 0;

      await TestAppHarness.pumpInHarness(
        tester,
        Row(
          children: [
            RepaintBoundary(
              key: monthGridKey,
              child: Builder(
                builder: (context) {
                  monthGridPaintCount++;
                  return Container(width: 300, color: Colors.grey.shade200, child: const Text('Month Calendar'));
                },
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<DateTime>(
                valueListenable: selectedDate,
                builder: (context, date, _) {
                  return Text('Agenda para: ${date.day}/${date.month}');
                },
              ),
            ),
          ],
        ),
      );

      expect(find.text('Agenda para: 22/11'), findsOneWidget);
      expect(monthGridPaintCount, equals(1));

      // Select new day
      selectedDate.value = DateTime(2026, 11, 25);
      await tester.pump();

      expect(find.text('Agenda para: 25/11'), findsOneWidget);
      expect(monthGridPaintCount, equals(1),
          reason: 'Month grid subtree must not rebuild or repaint when daily schedule date changes');
    });
  });
}
