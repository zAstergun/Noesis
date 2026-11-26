import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/supabase_service.dart';
import 'package:noesis/core/theme.dart';
import 'package:noesis/main.dart';
import 'package:noesis/features/auth/auth_screen.dart';
import 'package:noesis/features/tracker/tracker_screen.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 4 - Scenario 1: Auth Gate & Core Study Loop Workflow', () {
    testWidgets(
        'Complete journey: AuthScreen enforces login (no guest bypass) -> Tracker -> Start Timer Loop -> Toggle Subject Chip',
        (WidgetTester tester) async {
      await SupabaseService.addStudySession(
        subject: 'Criptografia',
        topic: 'AES-GCM',
        durationMinutes: 60,
        studyDate: DateTime.now(),
      );
      await SupabaseService.addStudySession(
        subject: 'Cloud / AWS',
        topic: 'IAM',
        durationMinutes: 45,
        studyDate: DateTime.now(),
      );

      RootScreen.bypassAuthForTesting = false;
      addTearDown(() => RootScreen.bypassAuthForTesting = true);

      await TestAppHarness.pumpInHarness(
        tester,
        const RootScreen(),
      );

      // Step 1: Real AuthScreen is initially visible without any guest/test account bypass
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.textContaining('Modo de Teste'), findsNothing);
      expect(find.textContaining('Entrar sem login'), findsNothing);

      // Step 2: Mount authenticated RootScreen via test harness bypass to test Tracker loop
      RootScreen.bypassAuthForTesting = true;
      await tester.pumpWidget(const SizedBox.shrink());
      await TestAppHarness.pumpInHarness(
        tester,
        const RootScreen(),
      );
      await tester.pumpAndSettle();

      // Step 3: AuthScreen is dismissed, real TrackerScreen is mounted
      expect(find.byType(AuthScreen), findsNothing);
      expect(find.byType(TrackerScreen), findsOneWidget);

      // Step 4: Verify core Tracker elements rendered
      expect(find.textContaining('Consistência · '), findsOneWidget);
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

      // Step 6: Open subject picker and select Criptografia
      final tagFinder = find.widgetWithText(SoftClayTag, 'Cloud / AWS').first;
      await tester.ensureVisible(tagFinder);
      await tester.tap(tagFinder);
      await tester.pumpAndSettle();
      expect(find.text('Disciplina da Sessão'), findsOneWidget);
      await tester.tap(find.text('Criptografia').last);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SoftClayTag, 'Criptografia'), findsWidgets);
    });
  });
}
