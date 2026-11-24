import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/main.dart';
import 'package:noesis/features/tracker/tracker_screen.dart';
import 'package:noesis/features/quizzes/quiz_screen.dart';
import 'package:noesis/features/ai_agent/ai_assistant_screen.dart';
import 'package:noesis/features/calendar/calendar_screen.dart';
import 'package:noesis/features/flashcards/flashcards_screen.dart';
import 'package:noesis/features/notebooks/notebooks_screen.dart';
import 'package:noesis/features/settings/settings_screen.dart';
import '../harness/test_app_harness.dart';
import '../harness/mock_http_overrides.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  setUp(() {
    MockHttpOverrides.reset();
  });

  group('Tier 4 - Scenario 5: Offline Resilience & Zero-Network Degradation', () {
    testWidgets('Real NoesisApp operates smoothly across all 5 tabs in Guest Mode with zero network calls',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        const RootScreen(),
      );

      // Transition to Guest Mode
      final guestButton = find.text('Entrar sem login · Modo de Teste');
      expect(guestButton, findsOneWidget);
      await tester.tap(guestButton);
      await tester.pumpAndSettle();

      // Tab 0: Dashboard / Tracker
      expect(find.byType(TrackerScreen), findsOneWidget);

      // Tab 1: Simulados
      await tester.tap(find.text('Simulados').first);
      await tester.pumpAndSettle();
      expect(find.byType(QuizScreen), findsOneWidget);

      // Tab 2: Flashcards
      await tester.tap(find.text('Flashcards').first);
      await tester.pumpAndSettle();
      expect(find.byType(FlashcardsScreen), findsOneWidget);

      // Tab 3: Cadernos
      await tester.tap(find.text('Cadernos').first);
      await tester.pumpAndSettle();
      expect(find.byType(NotebooksScreen), findsOneWidget);

      // Tab 4: Noesis AI
      await tester.tap(find.text('Noesis AI').first);
      await tester.pumpAndSettle();
      expect(find.byType(AiAssistantScreen), findsOneWidget);

      // Tab 4: Calendário
      await tester.tap(find.text('Calendário').first);
      await tester.pumpAndSettle();
      expect(find.byType(CalendarScreen), findsOneWidget);

      // Tab 5: Configurações
      await tester.tap(find.text('Configurações').first);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      // Return to Tab 0: Dashboard
      await tester.tap(find.text('Dashboard').first);
      await tester.pumpAndSettle();
      expect(find.byType(TrackerScreen), findsOneWidget);

      // Verify zero external network requests were made across the real app navigation
      expect(MockHttpOverrides.recordedRequests, isEmpty,
          reason: 'All screens, tabs, and local assets must operate offline with zero network requests');
      expect(tester.takeException(), isNull);

      // Drain all font loading futures and callbacks
      await TestAppHarness.drainAsync(tester);
    });
  });
}
