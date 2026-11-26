import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/shop_service.dart';
import 'package:noesis/core/theme.dart';
import 'package:noesis/main.dart';
import 'package:noesis/widgets/country_flag_icon.dart';
import '../e2e/harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  tearDown(() async {
    AsterTheme.selectThemeOption('soft_clay_nevoa');
    await ShopService.instance.resetForTesting(
      unlockedThemes: {ShopService.defaultFreeThemeId},
    );
  });

  testWidgets('Desktop shell shows top bar, toggles rail, and respects theme unlocks', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await ShopService.instance.resetForTesting(
      unlockedThemes: {ShopService.defaultFreeThemeId},
    );

    await TestAppHarness.pumpInHarness(
      tester,
      const NoesisApp(),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('top_bar_sidebar_toggle')), findsOneWidget);
    expect(find.byKey(const Key('top_bar_account_button')), findsNothing);
    expect(find.byKey(const Key('top_bar_theme_toggle')), findsOneWidget);
    expect(find.byKey(const Key('notifications_bell_button')), findsOneWidget);
    expect(find.byKey(const Key('top_bar_settings_button')), findsOneWidget);
    expect(find.byKey(const Key('window_minimize_button')), findsOneWidget);
    expect(find.byKey(const Key('window_maximize_button')), findsOneWidget);
    expect(find.byKey(const Key('window_close_button')), findsOneWidget);
    expect(find.byType(Scrollbar), findsNothing);

    // Toggle sidebar via top bar Noesis brand -> collapses to 62px icon rail
    expect(find.byKey(const ValueKey('sidebar_expanded_panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('sidebar_collapsed_rail')), findsNothing);

    await tester.tap(find.byKey(const Key('top_bar_sidebar_toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sidebar_expanded_panel')), findsNothing);
    expect(find.byKey(const ValueKey('sidebar_collapsed_rail')), findsOneWidget);

    // Abre o seletor de temas e garante que tema bloqueado (Aurora) NÃO seja ativado
    await tester.tap(find.byKey(const Key('top_bar_theme_toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Selecionar tema'), findsOneWidget);

    await tester.tap(find.byKey(const Key('theme_picker_item_aurora')));
    await tester.pumpAndSettle();
    expect(AsterTheme.activeThemeIdNotifier.value, 'soft_clay_nevoa');
    expect(AsterTheme.isDarkMode, isFalse);

    // Desbloqueia Crepúsculo (que originalmente fica no fim da lista) e garante que apareça antes dos bloqueados
    await ShopService.instance.resetForTesting(
      unlockedThemes: {ShopService.defaultFreeThemeId, 'crepusculo'},
    );
    await tester.tap(find.byKey(const Key('top_bar_theme_toggle')));
    await tester.pumpAndSettle();

    final crepusculoRect = tester.getRect(find.byKey(const Key('theme_picker_item_crepusculo')));
    final auroraLockedRect = tester.getRect(find.byKey(const Key('theme_picker_item_aurora')));
    expect(crepusculoRect.top, lessThan(auroraLockedRect.top));

    await tester.tap(find.byKey(const Key('theme_picker_item_crepusculo')));
    await tester.pumpAndSettle();

    expect(AsterTheme.activeThemeIdNotifier.value, 'crepusculo');
    expect(AsterTheme.isDarkMode, isTrue);

    // Clicar no botão de configurações na barra superior abre a aba Configurações (6)
    await tester.tap(find.byKey(const Key('top_bar_settings_button')));
    await tester.pumpAndSettle();
    expect(RootScreen.activeTabNotifier.value, 6);
    expect(find.byType(CountryFlagIcon), findsNWidgets(15));

    await TestAppHarness.drainAsync(tester);
  });
}
