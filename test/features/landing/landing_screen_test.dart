import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/theme.dart';
import 'package:noesis/features/auth/auth_screen.dart';
import 'package:noesis/features/landing/landing_screen.dart';
import 'package:noesis/main.dart';
import '../../e2e/harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  tearDown(() {
    AsterTheme.selectThemeOption('soft_clay_nevoa');
    RootScreen.bypassAuthForTesting = true;
    RootScreen.isWebOverrideForTesting = null;
  });

  group('LandingScreen redesigned layout & real Noesis details', () {
    testWidgets(
        'renders cleanly on desktop (1280x800), switches interactive sections, and triggers login',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var loginOpened = 0;
      await TestAppHarness.pumpInHarness(
        tester,
        LandingScreen(onOpenLogin: () => loginOpened++),
        screenSize: const Size(1280, 800),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );

      expect(find.byKey(const Key('landing_nav_login_button')), findsOneWidget);
      expect(find.byKey(const Key('landing_open_login_button')), findsOneWidget);
      expect(find.byKey(const Key('landing_theme_button')), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode_rounded), findsNothing);
      expect(find.text('Acessar ferramenta'), findsAtLeastNWidgets(2));

      // Open Theme Picker and verify all 11 themes + VIP Personalizado option
      // Changing the landing theme must remain local (demo) without mutating global AsterTheme
      await tester.tap(find.byKey(const Key('landing_theme_button')));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(find.text('Temas do Noesis (Prévia)'), findsOneWidget);
      expect(find.byKey(const Key('landing_theme_option_custom')), findsOneWidget);
      expect(find.text('VIP · 6 cores RGB'), findsOneWidget);
      await tester.tap(find.byKey(const Key('landing_theme_option_custom')));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(AsterTheme.activeThemeIdNotifier.value, 'soft_clay_nevoa');
      final customOpt = AsterTheme.customThemeColorsNotifier.value.toNoesisThemeOption();
      final themedScaffold = tester.widget<Scaffold>(
        find.descendant(
          of: find.byType(LandingScreen),
          matching: find.byType(Scaffold),
        ),
      );
      expect(themedScaffold.backgroundColor, customOpt.bg);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      await TestAppHarness.drainAsync(tester);

      // Switch interactive Hero preview tabs
      await tester.tap(find.text('Noesis AI').first);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(find.text('7 provedores · 20 ferramentas ativas'), findsOneWidget);

      await tester.ensureVisible(find.text('Simulados').first);
      await tester.tap(find.text('Simulados').first);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(find.text('Simulado RAG · 39 Bancas'), findsOneWidget);

      // Answer interactive quiz question
      await tester.ensureVisible(find.text('O(1)'));
      await tester.tap(find.text('O(1)'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(find.textContaining('Acertou! (+3 Insights)'), findsOneWidget);

      // Scroll down to Showcase, Bento and Community sections and verify real Noesis terms
      final mainScrollable = find
          .descendant(
            of: find.byKey(const Key('landing_scroll_view')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Flashcards & Trilhas'),
        300,
        scrollable: mainScrollable,
      );
      await tester.tap(find.text('Flashcards & Trilhas'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(find.text('Difícil 🔴'), findsOneWidget);
      expect(find.text('Bom 🟡'), findsOneWidget);
      expect(find.text('Fácil 🟢'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Calendário em 4 visões'),
        300,
        scrollable: mainScrollable,
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text('Insights & 8 Elos'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Estudar em grupo muda o jogo'),
        300,
        scrollable: mainScrollable,
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(find.text('Chat do Grupo'), findsOneWidget);

      // Tap Download link in navbar and verify download options appear
      expect(find.byKey(const Key('landing_nav_download_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('landing_nav_download_button')));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(find.text('PLATAFORMAS & DOWNLOADS · v1.0.0'), findsOneWidget);
      expect(find.byKey(const Key('landing_github_button')), findsOneWidget);
      expect(find.text('GitHub (zAstergun/Noesis)'), findsOneWidget);
      expect(find.text('Baixar para Windows (.zip)'), findsOneWidget);
      expect(find.text('Baixar APK Android'), findsOneWidget);
      expect(find.text('Abrir Web App'), findsNothing);
      expect(find.text('Ver Releases'), findsNothing);

      // Tap primary Hero CTA via navbar button
      await tester.tap(find.byKey(const Key('landing_nav_login_button')));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(loginOpened, 1);
      AsterTheme.selectThemeOption('soft_clay_nevoa');
      await TestAppHarness.drainAsync(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly on compact mobile (360x780) without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await TestAppHarness.pumpInHarness(
        tester,
        LandingScreen(onOpenLogin: () {}),
        screenSize: const Size(360, 780),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('landing_nav_login_button')), findsOneWidget);
      expect(find.byKey(const Key('landing_open_login_button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'RootScreen shows LandingScreen first on Web and navigates between Landing and AuthScreen',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      RootScreen.bypassAuthForTesting = false;
      RootScreen.isWebOverrideForTesting = true;
      await TestAppHarness.pumpInHarness(
        tester,
        const NoesisApp(),
        screenSize: const Size(1280, 800),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LandingScreen), findsOneWidget);
      expect(find.byType(AuthScreen), findsNothing);

      // Navigate to AuthScreen via navbar CTA
      await tester.tap(find.byKey(const Key('landing_nav_login_button')));
      await tester.pumpAndSettle();

      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.byKey(const Key('auth_back_to_landing_button')), findsOneWidget);

      // Navigate back to LandingScreen
      await tester.tap(find.byKey(const Key('auth_back_to_landing_button')));
      await tester.pumpAndSettle();

      expect(find.byType(LandingScreen), findsOneWidget);
      expect(find.byType(AuthScreen), findsNothing);

      await TestAppHarness.drainAsync(tester);
    });

    testWidgets(
        'RootScreen skips LandingScreen on Desktop/Mobile and opens AuthScreen directly',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      RootScreen.bypassAuthForTesting = false;
      RootScreen.isWebOverrideForTesting = false;
      await TestAppHarness.pumpInHarness(
        tester,
        const NoesisApp(),
        screenSize: const Size(1280, 800),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LandingScreen), findsNothing);
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.byKey(const Key('auth_back_to_landing_button')), findsNothing);

      await TestAppHarness.drainAsync(tester);
    });
  });
}
