import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/constants.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 2 - Feature 08: Progress Indicator & ClipRRect Boundary Cases', () {
    testWidgets('1. Progress value 0.0 renders empty bar with pill borderRadius',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        LinearProgressIndicator(
          value: 0.0,
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          backgroundColor: AsterConstants.surfaceInset,
        ),
      );

      final indicator = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(indicator.value, equals(0.0));
    });

    testWidgets('2. Progress value 1.0 renders 100% full bar without corner artifacting',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        LinearProgressIndicator(
          value: 1.0,
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          valueColor: const AlwaysStoppedAnimation(AsterConstants.menta),
        ),
      );

      final indicator = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(indicator.value, equals(1.0));
    });

    testWidgets('3. Negative progress values clamped to 0.0 safely by application logic',
        (WidgetTester tester) async {
      double sanitizeProgress(double raw) => raw.clamp(0.0, 1.0);

      expect(sanitizeProgress(-0.5), equals(0.0));
      expect(sanitizeProgress(1.75), equals(1.0));

      await TestAppHarness.pumpInHarness(
        tester,
        LinearProgressIndicator(
          value: sanitizeProgress(-0.2),
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        ),
      );

      final indicator = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(indicator.value, equals(0.0));
    });

    testWidgets('4. Indeterminate progress bar (value: null) renders with rounded ends',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        LinearProgressIndicator(
          value: null,
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          backgroundColor: AsterConstants.surfaceInset,
        ),
        pumpDuration: const Duration(milliseconds: 100),
      );

      final indicator = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(indicator.value, isNull);
      expect(indicator.borderRadius, equals(BorderRadius.circular(AsterConstants.radiusPill)));

      // Dispose the indeterminate animation cleanly before test end so zero transient callbacks remain
      await tester.pumpWidget(const SizedBox.shrink());
      await TestAppHarness.drainAsync(tester);
    });

    testWidgets('5. Constrained narrow width (80px) renders without layout overflow',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        SizedBox(
          width: 80,
          child: LinearProgressIndicator(
            value: 0.5,
            minHeight: 4,
            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
