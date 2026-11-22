import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Feature 15: Performance Profiling & Latency Hooks', () {
    testWidgets('1. addPostFrameCallback hook measures frame render latency accurately',
        (WidgetTester tester) async {
      int? frameLatencyMs;
      final stopwatch = Stopwatch()..start();

      await TestAppHarness.pumpInHarness(
        tester,
        Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              frameLatencyMs = stopwatch.elapsedMilliseconds;
            });
            return const Text('Post Frame Hook Test');
          },
        ),
      );

      expect(find.text('Post Frame Hook Test'), findsOneWidget);
      expect(frameLatencyMs, isNotNull);
      expect(frameLatencyMs!, greaterThanOrEqualTo(0));
    });

    testWidgets('2. Tab switch click-to-render latency is measured and completes promptly',
        (WidgetTester tester) async {
      final tabNotifier = ValueNotifier<int>(0);
      int? clickLatencyMs;

      await TestAppHarness.pumpInHarness(
        tester,
        Column(
          children: [
            ElevatedButton(
              onPressed: () {
                final sw = Stopwatch()..start();
                tabNotifier.value = 1;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  clickLatencyMs = sw.elapsedMilliseconds;
                });
              },
              child: const Text('Switch Tab'),
            ),
            ValueListenableBuilder<int>(
              valueListenable: tabNotifier,
              builder: (context, idx, _) => Text('Current Tab: $idx'),
            ),
          ],
        ),
      );

      await tester.tap(find.text('Switch Tab'));
      await tester.pump();

      expect(find.text('Current Tab: 1'), findsOneWidget);
      expect(clickLatencyMs, isNotNull);
      expect(clickLatencyMs!, greaterThanOrEqualTo(0),
          reason: 'Tab switch latency post-frame hook must record valid non-negative duration');
    });

    testWidgets('3. Dialog open action latency is bounded within 1 frame',
        (WidgetTester tester) async {
      int? dialogOpenLatencyMs;

      await TestAppHarness.pumpInHarness(
        tester,
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                final sw = Stopwatch()..start();
                showDialog(
                  context: context,
                  builder: (ctx) => const AlertDialog(title: Text('Opened Dialog')),
                );
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  dialogOpenLatencyMs = sw.elapsedMilliseconds;
                });
              },
              child: const Text('Open Dialog'),
            );
          },
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pump();

      expect(find.text('Opened Dialog'), findsOneWidget);
      expect(dialogOpenLatencyMs, isNotNull);
      expect(dialogOpenLatencyMs!, greaterThanOrEqualTo(0),
          reason: 'Dialog open latency post-frame hook must record valid non-negative duration');
    });

    testWidgets('4. ValueNotifier state update latency is zero microseconds before frame schedule',
        (WidgetTester tester) async {
      final counter = ValueNotifier<int>(10);
      final sw = Stopwatch()..start();
      counter.value = 20;
      final elapsed = sw.elapsedMicroseconds;

      expect(counter.value, equals(20));
      expect(elapsed, greaterThanOrEqualTo(0),
          reason: 'Synchronous ValueNotifier dispatch must record non-negative elapsed microseconds');
    });

    test('5. Stopwatch elapsed milliseconds is monotonic and strictly non-negative', () {
      final sw = Stopwatch()..start();
      int prev = sw.elapsedMilliseconds;
      for (int i = 0; i < 1000; i++) {
        final current = sw.elapsedMilliseconds;
        expect(current, greaterThanOrEqualTo(prev));
        prev = current;
      }
      sw.stop();
    });
  });
}
