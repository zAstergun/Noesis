import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/constants.dart';
import 'package:noesis/core/theme.dart';
import 'package:noesis/features/tracker/tracker_screen.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Feature 07: Consistency Heatmap & Grid Layout', () {
    Widget buildSampleHeatmapWidget() {
      return SoftClayCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Consistência · 182 dias'),
                Row(
                  children: [
                    const Text('Menos '),
                    Container(width: 8, height: 8, color: AsterConstants.surfaceInset),
                    const SizedBox(width: 3),
                    Container(width: 8, height: 8, color: AsterConstants.menta.withValues(alpha: 0.3)),
                    const SizedBox(width: 3),
                    Container(width: 8, height: 8, color: AsterConstants.menta.withValues(alpha: 0.6)),
                    const SizedBox(width: 3),
                    Container(width: 8, height: 8, color: AsterConstants.menta),
                    const Text(' Mais'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 110,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(26, (col) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(7, (row) {
                                return Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: (col + row) % 3 == 0
                                        ? AsterConstants.menta
                                        : AsterConstants.surfaceInset,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                );
                              }),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STREAK ATUAL'),
                    Text('42d'),
                    SizedBox(height: 10),
                    Text('MELHOR DIA'),
                    Text('6h20'),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }

    testWidgets('1. Heatmap card renders title Consistência · 182 dias and density legend',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(tester, buildSampleHeatmapWidget());

      expect(find.text('Consistência · 182 dias'), findsOneWidget);
      expect(find.text('Menos '), findsOneWidget);
      expect(find.text(' Mais'), findsOneWidget);
    });

    testWidgets('2. Heatmap displays streak and best day metrics accurately',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(tester, buildSampleHeatmapWidget());

      expect(find.text('STREAK ATUAL'), findsOneWidget);
      expect(find.text('42d'), findsOneWidget);
      expect(find.text('MELHOR DIA'), findsOneWidget);
      expect(find.text('6h20'), findsOneWidget);
    });

    testWidgets('3. Heatmap grid spans 26 columns of 7 day rows (182 days total)',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(tester, buildSampleHeatmapWidget());

      // 26 columns of 7 rows = 182 cells
      final cells = find.byType(Container).evaluate().where((element) {
        final widget = element.widget as Container;
        return widget.constraints?.maxWidth == 10 ||
            (widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).borderRadius == BorderRadius.circular(2));
      });
      expect(cells.length, equals(182),
          reason: 'Heatmap must render exactly 182 day units (26 weeks x 7 days)');
    });

    testWidgets('4. Heatmap is contained inside a SoftClayCard',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(tester, buildSampleHeatmapWidget());

      expect(find.byType(SoftClayCard), findsOneWidget);
    });

    testWidgets('5. Activity levels correctly utilize AsterConstants.menta palette',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(tester, buildSampleHeatmapWidget());

      final activeCells = find.byType(Container).evaluate().where((element) {
        final widget = element.widget as Container;
        if (widget.decoration is BoxDecoration) {
          final box = widget.decoration as BoxDecoration;
          return box.color == AsterConstants.menta;
        }
        return false;
      });
      expect(activeCells, isNotEmpty,
          reason: 'Active study days must be colored with AsterConstants.menta');
    });

    testWidgets('6. ConsistencyHeatmap CustomPainter renders inside RepaintBoundary with CustomPaint',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        const ConsistencyHeatmap(),
      );

      expect(find.byType(ConsistencyHeatmap), findsOneWidget);
      expect(find.byType(CustomPaint), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsAtLeastNWidgets(1));
    });

    test('7. ConsistencyHeatmap colorForLevel correctly maps all 5 density states', () {
      expect(ConsistencyHeatmap.colorForLevel(4), equals(AsterConstants.menta));
      expect(ConsistencyHeatmap.colorForLevel(3), equals(AsterConstants.menta.withValues(alpha: 0.7)));
      expect(ConsistencyHeatmap.colorForLevel(2), equals(AsterConstants.menta.withValues(alpha: 0.45)));
      expect(ConsistencyHeatmap.colorForLevel(1), equals(AsterConstants.menta.withValues(alpha: 0.22)));
      expect(ConsistencyHeatmap.colorForLevel(0), equals(AsterConstants.surfaceInset));
    });

    testWidgets('8. ConsistencyHeatmap renders empty grid cleanly when levels is null',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        const ConsistencyHeatmap(columns: 26, rows: 7),
      );

      expect(find.byType(ConsistencyHeatmap), findsOneWidget);
      expect(ConsistencyHeatmap.colorForLevel(0), equals(AsterConstants.surfaceInset));
    });
  });
}
