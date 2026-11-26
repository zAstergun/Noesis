import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/theme.dart';
import 'package:noesis/features/auth/auth_screen.dart';
import 'package:noesis/main.dart';
import 'package:noesis/widgets/noesis_logo.dart';
import '../e2e/harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  tearDown(() {
    AsterTheme.selectThemeOption('soft_clay_nevoa');
  });

  test('Official SVG logo files exist in assets/images and web directories', () {
    expect(File('assets/images/logo.svg').existsSync(), isTrue);
    expect(File('web/favicon.svg').existsSync(), isTrue);
    expect(File('web/icons/logo.svg').existsSync(), isTrue);
    expect(File('logo.svg').existsSync(), isFalse);
  });

  test('NoesisLogoPalette adapts colors cleanly to every active theme', () {
    final nevoa = AsterTheme.availableThemes.firstWhere((t) => t.id == 'soft_clay_nevoa');
    final nevoaPal = NoesisLogoPalette.forTheme(nevoa);
    expect(nevoaPal.bgTopLeft, const Color(0xFF8B7CF6));
    expect(nevoaPal.foreground, Colors.white);

    final floresta = AsterTheme.availableThemes.firstWhere((t) => t.id == 'floresta');
    final florestaPal = NoesisLogoPalette.forTheme(floresta);
    expect(florestaPal.bgTopLeft, floresta.primary);
    expect(florestaPal.rayLeft, isNot(floresta.primary));

    final grafite = AsterTheme.availableThemes.firstWhere((t) => t.id == 'grafite');
    final grafitePal = NoesisLogoPalette.forTheme(grafite);
    expect(grafitePal.bgTopLeft, const Color(0xFFC6F432));
    expect(grafitePal.foreground, const Color(0xFF111111));
  });

  testWidgets('NoesisLogo renders cleanly in AuthScreen and RootScreen sidebar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await TestAppHarness.pumpInHarness(
      tester,
      AuthScreen(onAuthenticated: () {}),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NoesisLogo), findsOneWidget);
    expect(find.text('Noesis'), findsOneWidget);

    await TestAppHarness.drainAsync(tester);
  });

  testWidgets('Tapping Noesis logo collapses and expands the desktop sidebar smoothly', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await TestAppHarness.pumpInHarness(
      tester,
      const NoesisApp(),
    );
    await tester.pumpAndSettle();

    // Entra em modo visitante caso apareça a AuthScreen
    final guestBtn = find.text('Entrar sem login · Modo de Teste');
    if (guestBtn.evaluate().isNotEmpty) {
      await tester.tap(guestBtn);
      await tester.pumpAndSettle();
    }

    // Sidebar aberta inicialmente
    expect(find.byKey(const Key('sidebar_logo_toggle')), findsOneWidget);
    expect(find.byKey(const Key('collapsed_logo_toggle')), findsNothing);
    expect(find.byType(NoesisWordmark), findsOneWidget);
    final wordmarkStyle = tester.widget<Text>(find.text('Noesis')).style;
    expect(wordmarkStyle?.fontFamily, contains('SpaceGrotesk'));

    // Toca no logo da sidebar para ocultar o menu lateral
    await tester.tap(find.byKey(const Key('sidebar_logo_toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sidebar_logo_toggle')), findsNothing);
    expect(find.byKey(const Key('collapsed_logo_toggle')), findsOneWidget);

    // Toca no logo recolhido para reabrir o menu lateral
    await tester.tap(find.byKey(const Key('collapsed_logo_toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sidebar_logo_toggle')), findsOneWidget);
    expect(find.byKey(const Key('collapsed_logo_toggle')), findsNothing);

    // Navega para Cadernos, abre um caderno e recolhe o menu lateral:
    // o botão de voltar deve ficar ao lado do menu recolhido (mesma linha do topo), e não abaixo dele.
    await tester.tap(find.text('Cadernos').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sidebar_logo_toggle')));
    await tester.pumpAndSettle();

    final openNotebookBtn = find.textContaining('Abrir Caderno');
    if (openNotebookBtn.evaluate().isNotEmpty) {
      await tester.tap(openNotebookBtn.first);
      await tester.pumpAndSettle();

      final backFinder = find.byIcon(Icons.arrow_back_rounded);
      expect(backFinder, findsOneWidget);
      final pillRect = tester.getRect(find.byKey(const Key('collapsed_logo_toggle')));
      final backRect = tester.getRect(backFinder);
      expect(pillRect.right <= backRect.left, isTrue);
      expect((pillRect.center.dy - backRect.center.dy).abs() < 16, isTrue);
    }

    await TestAppHarness.drainAsync(tester);
  });
}
