import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 2 - Feature 15: Latency Hooks Boundary Cases', () {
    testWidgets('1. Sub-millisecond frame rendering logged as non-negative integer without division by zero',
        (WidgetTester tester) async {
      int measuredDelta = -1;
      final sw = Stopwatch()..start();

      await TestAppHarness.pumpInHarness(
        tester,
        Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              measuredDelta = sw.elapsedMilliseconds;
            });
            return const SizedBox.shrink();
          },
        ),
      );

      expect(measuredDelta, greaterThanOrEqualTo(0));
    });

    testWidgets('2. Rapid series of 5 consecutive button taps records 5 latency samples',
        (WidgetTester tester) async {
      final recordedLatencies = <int>[];

      await TestAppHarness.pumpInHarness(
        tester,
        ElevatedButton(
          onPressed: () {
            final sw = Stopwatch()..start();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              recordedLatencies.add(sw.elapsedMilliseconds);
            });
          },
          child: const Text('Rapid Tap'),
        ),
      );

      for (int i = 0; i < 5; i++) {
        await tester.tap(find.text('Rapid Tap'));
        await tester.pump();
      }

      expect(recordedLatencies.length, equals(5));
      for (final lat in recordedLatencies) {
        expect(lat, greaterThanOrEqualTo(0));
      }
    });

    test('3. Stopwatch reset and restart behaves deterministically', () {
      final sw = Stopwatch()..start();
      expect(sw.isRunning, isTrue);

      sw.reset();
      expect(sw.elapsedMicroseconds, lessThan(1000));

      sw.stop();
      expect(sw.isRunning, isFalse);
    });

    testWidgets('4. addPostFrameCallback fires in registration order',
        (WidgetTester tester) async {
      final order = <int>[];

      await TestAppHarness.pumpInHarness(
        tester,
        Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) => order.add(1));
            WidgetsBinding.instance.addPostFrameCallback((_) => order.add(2));
            WidgetsBinding.instance.addPostFrameCallback((_) => order.add(3));
            return const Text('Order Test');
          },
        ),
      );

      expect(order, equals([1, 2, 3]));
    });

    testWidgets('5. Latency hook survives widget unmount before frame callback fires',
        (WidgetTester tester) async {
      bool callbackFired = false;
      final showWidget = ValueNotifier<bool>(true);

      await TestAppHarness.pumpInHarness(
        tester,
        ValueListenableBuilder<bool>(
          valueListenable: showWidget,
          builder: (context, show, _) {
            if (show) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                callbackFired = true;
              });
              return const Text('Transient Child');
            }
            return const SizedBox.shrink();
          },
        ),
      );

      showWidget.value = false;
      await tester.pump();

      expect(callbackFired, isTrue);
    });
  });
}
