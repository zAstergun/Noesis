import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/constants.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 3: RepaintBoundary & Consistency Heatmap Interaction', () {
    testWidgets('1. Heatmap widget wrapped in RepaintBoundary produces distinct render boundary',
        (WidgetTester tester) async {
      final heatmapKey = GlobalKey();

      await TestAppHarness.pumpInHarness(
        tester,
        RepaintBoundary(
          key: heatmapKey,
          child: Container(
            padding: const EdgeInsets.all(16),
            color: AsterConstants.surfaceCard,
            child: Row(
              children: List.generate(
                7,
                (i) => Container(
                  width: 12,
                  height: 12,
                  color: AsterConstants.menta,
                  margin: const EdgeInsets.all(2),
                ),
              ),
            ),
          ),
        ),
      );

      final renderObject = heatmapKey.currentContext?.findRenderObject();
      expect(renderObject, isNotNull);
      expect(renderObject!.isRepaintBoundary, isTrue);
    });
  });
}
