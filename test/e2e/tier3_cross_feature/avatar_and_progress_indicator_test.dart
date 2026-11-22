import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/constants.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 3: Avatar Optimization & Progress Indicator Interaction', () {
    testWidgets('1. TopBar profile section renders optimized avatar and direct borderRadius progress bar',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0x267C6CF0),
                child: Text('VT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Victor Torres · Nível 14'),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: 0.76,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      backgroundColor: AsterConstants.surfaceInset,
                      valueColor: const AlwaysStoppedAnimation(AsterConstants.menta),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(ClipRRect), findsNothing,
          reason: 'Progress bar inside TopBar header must not be wrapped in ClipRRect');
    });
  });
}
