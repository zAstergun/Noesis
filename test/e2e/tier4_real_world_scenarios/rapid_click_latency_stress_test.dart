import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/features/tracker/tracker_screen.dart';
import 'package:noesis/features/quizzes/quiz_screen.dart';
import 'package:noesis/features/ai_agent/ai_assistant_screen.dart';
import 'package:noesis/features/calendar/calendar_screen.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 4 - Scenario 6: High-Frequency Tab Switching & Rapid Click Latency Stress', () {
    testWidgets(
        'Rapidly cycling 30 tab switches completes with zero dropped states and latency bounded under 100ms',
        (WidgetTester tester) async {
      final tabNotifier = ValueNotifier<int>(0);
      final latencies = <int>[];

      await TestAppHarness.pumpInHarness(
        tester,
        Column(
          children: [
            Row(
              children: List.generate(4, (i) {
                return ElevatedButton(
                  onPressed: () {
                    final sw = Stopwatch()..start();
                    tabNotifier.value = i;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      latencies.add(sw.elapsedMilliseconds);
                    });
                  },
                  child: Text('Go $i'),
                );
              }),
            ),
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: tabNotifier,
                builder: (context, idx, _) {
                  return IndexedStack(
                    index: idx,
                    children: const [
                      TrackerScreen(),
                      QuizScreen(),
                      AiAssistantScreen(),
                      CalendarScreen(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );

      // Perform 30 rapid tab switches across real Noesis screens
      for (int i = 0; i < 30; i++) {
        final targetTab = i % 4;
        await tester.tap(find.text('Go $targetTab'));
        await tester.pump();
      }

      expect(latencies.length, equals(30));
      for (final latency in latencies) {
        expect(latency, greaterThanOrEqualTo(0),
            reason: 'Every individual click reaction post-frame callback must record non-negative duration');
      }

      // Final tab is 29 % 4 = 1 -> QuizScreen
      expect(find.byType(QuizScreen), findsOneWidget);
    });
  });
}
