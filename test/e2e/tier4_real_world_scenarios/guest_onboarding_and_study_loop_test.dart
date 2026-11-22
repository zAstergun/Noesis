import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/main.dart';
import 'package:noesis/features/auth/auth_screen.dart';
import 'package:noesis/features/tracker/tracker_screen.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 4 - Scenario 1: Guest Onboarding & Core Study Loop Workflow', () {
    testWidgets(
        'Complete journey: Enter as Guest -> View Tracker -> Start Timer Loop -> Toggle Subject Chip',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        const RootScreen(),
      );

      // Step 1: Real AuthScreen is initially visible with guest login option
      expect(find.byType(AuthScreen), findsOneWidget);
      final guestButton = find.text('Entrar sem login · Modo de Teste');
      expect(guestButton, findsOneWidget);

      // Step 2: Tap Continue as Guest to transition into Noesis Guest Mode
      await tester.tap(guestButton);
      await tester.pumpAndSettle();

      // Step 3: AuthScreen is dismissed, real TrackerScreen is mounted
      expect(find.byType(AuthScreen), findsNothing);
      expect(find.byType(TrackerScreen), findsOneWidget);

      // Step 4: Verify core Tracker elements rendered in Guest Mode
      expect(find.text('Consistência · 182 dias'), findsOneWidget);
      expect(find.text('Iniciar'), findsOneWidget);
      expect(find.text('Criptografia'), findsWidgets);

      // Step 5: Start the focus timer loop (Feature 11: ValueNotifier timer)
      await tester.tap(find.text('Iniciar'));
      await tester.pump();
      expect(find.text('Pausar'), findsOneWidget);

      // Advance time by 2 seconds to verify active timer ticking
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Pausar'), findsOneWidget);

      // Pause the timer cleanly
      await tester.tap(find.text('Pausar'));
      await tester.pump();
      expect(find.text('Iniciar'), findsOneWidget);

      // Step 6: Toggle subject chip between Criptografia and Cloud / AWS
      await tester.tap(find.widgetWithText(InkWell, 'Criptografia').first);
      await tester.pump();
      expect(find.text('Cloud / AWS'), findsWidgets);
    });
  });
}
