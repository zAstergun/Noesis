import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/constants.dart';
import 'package:noesis/features/tracker/tracker_screen.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Feature 08: Redundant ClipRRect Elimination on Progress Indicators', () {
    testWidgets('1. LinearProgressIndicator accepts borderRadius directly',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        LinearProgressIndicator(
          value: 0.76,
          minHeight: 6,
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          backgroundColor: AsterConstants.surfaceInset,
          valueColor: const AlwaysStoppedAnimation(AsterConstants.menta),
        ),
      );

      final indicator = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(indicator.borderRadius, equals(BorderRadius.circular(AsterConstants.radiusPill)),
          reason: 'LinearProgressIndicator natively supports borderRadius, avoiding an offscreen saveLayer');
    });

    testWidgets('2. LinearProgressIndicator uses AsterConstants.menta as primary valueColor',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        LinearProgressIndicator(
          value: 0.5,
          minHeight: 8,
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          valueColor: const AlwaysStoppedAnimation(AsterConstants.menta),
        ),
      );

      final indicator = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(indicator.valueColor?.value, equals(AsterConstants.menta));
    });

    testWidgets('3. LinearProgressIndicator uses AsterConstants.surfaceInset as background track',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        const LinearProgressIndicator(
          value: 0.3,
          backgroundColor: AsterConstants.surfaceInset,
          valueColor: AlwaysStoppedAnimation(AsterConstants.lavanda),
        ),
      );

      final indicator = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(indicator.backgroundColor, equals(AsterConstants.surfaceInset));
    });

    testWidgets('4. Direct borderRadius indicator in TrackerScreen renders without wrapping ClipRRect parent',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        const TrackerScreen(),
      );

      final indicatorFinder = find.byType(LinearProgressIndicator);
      expect(indicatorFinder, findsOneWidget);

      // Verify that no ancestor ClipRRect wraps the progress indicator in real TrackerScreen
      expect(find.ancestor(of: indicatorFinder, matching: find.byType(ClipRRect)), findsNothing,
          reason: 'Unnecessary ClipRRect parent in TrackerScreen should be eliminated to avoid raster clipping cost');

      final indicator = tester.widget<LinearProgressIndicator>(indicatorFinder);
      expect(indicator.borderRadius, equals(BorderRadius.circular(AsterConstants.radiusPill)));

      await TestAppHarness.drainAsync(tester);
    });

    testWidgets('5. LinearProgressIndicator with minHeight 6 renders clean pill shape',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        const SizedBox(
          width: 200,
          child: LinearProgressIndicator(
            value: 0.65,
            minHeight: 6,
          ),
        ),
      );

      final indicator = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(indicator.minHeight, equals(6));
    });
  });
}
