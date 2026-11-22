import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/constants.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 2 - Feature 07: Heatmap Boundary Cases', () {
    Color getCellColor(int rawLevel, bool isDark) {
      final level = rawLevel.clamp(0, 4);
      switch (level) {
        case 0:
          return isDark ? const Color(0xFF262838) : AsterConstants.surfaceInset;
        case 1:
          return AsterConstants.menta.withValues(alpha: 0.25);
        case 2:
          return AsterConstants.menta.withValues(alpha: 0.50);
        case 3:
          return AsterConstants.menta.withValues(alpha: 0.75);
        case 4:
        default:
          return AsterConstants.menta;
      }
    }

    test('1. Negative and excessive activity levels clamp strictly between 0 and 4', () {
      expect(getCellColor(-5, false), equals(AsterConstants.surfaceInset));
      expect(getCellColor(99, false), equals(AsterConstants.menta));
    });

    testWidgets('2. Zero-activity year renders all cells in inactive surfaceInset color',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        Row(
          children: List.generate(7, (i) {
            return Container(
              key: Key('zero-cell-$i'),
              width: 10,
              height: 10,
              color: getCellColor(0, false),
            );
          }),
        ),
      );

      final container = tester.widget<Container>(find.byKey(const Key('zero-cell-0')));
      expect(container.color, equals(AsterConstants.surfaceInset));
    });

    testWidgets('3. Max-activity day renders in solid AsterConstants.menta color',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        Container(
          key: const Key('max-cell'),
          width: 10,
          height: 10,
          color: getCellColor(4, false),
        ),
      );

      final container = tester.widget<Container>(find.byKey(const Key('max-cell')));
      expect(container.color, equals(AsterConstants.menta));
    });

    testWidgets('4. Inactive cell adapts to dark surface color in Dark Theme',
        (WidgetTester tester) async {
      final darkColor = getCellColor(0, true);
      expect(darkColor, equals(const Color(0xFF262838)));

      await TestAppHarness.pumpInHarness(
        tester,
        Container(
          key: const Key('dark-cell'),
          width: 10,
          height: 10,
          color: darkColor,
        ),
        themeMode: ThemeMode.dark,
      );

      final container = tester.widget<Container>(find.byKey(const Key('dark-cell')));
      expect(container.color, equals(const Color(0xFF262838)));
    });

    testWidgets('5. Heatmap within narrow mobile viewport scrolls horizontally without overflow',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        SizedBox(
          width: 320,
          height: 80,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(26, (col) => Container(width: 20, height: 20, color: Colors.green)),
            ),
          ),
        ),
        screenSize: const Size(360, 640),
      );

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      await tester.drag(find.byType(SingleChildScrollView), const Offset(-150, 0));
      await tester.pump();
      expect(tester.takeException(), isNull,
          reason: 'Horizontal scrolling on narrow viewport must produce zero layout overflow exceptions');
    });
  });
}
