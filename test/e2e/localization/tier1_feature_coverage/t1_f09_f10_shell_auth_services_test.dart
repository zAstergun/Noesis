import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/insights_economy_config.dart';
import 'package:noesis/core/localization/noesis_locale_service.dart';
import 'package:noesis/core/noesis_crm_service.dart';
import 'package:noesis/core/notifications_service.dart';
import 'package:noesis/core/oauth_loopback_io.dart' as oauth_loopback;
import 'package:noesis/core/shop_service.dart';
import 'package:noesis/core/supabase_service.dart';
import 'package:noesis/features/auth/auth_screen.dart';
import 'package:noesis/features/landing/widgets/landing_bento_section.dart';
import 'package:noesis/features/landing/widgets/landing_community_section.dart';
import 'package:noesis/features/landing/widgets/landing_hero_stage.dart';
import 'package:noesis/features/landing/widgets/landing_showcase_section.dart';
import 'package:noesis/main.dart';
import 'package:noesis/widgets/desktop_top_bar.dart';
import 'package:noesis/widgets/insight_gain_toast_overlay.dart';
import 'package:noesis/widgets/profile_settings_dialog.dart';
import 'package:noesis/widgets/vip_privileges.dart';
import 'package:noesis/widgets/vip_rgb_theme_editor.dart';
import 'package:noesis/widgets/weekly_goal_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../harness/test_app_harness.dart';
import '../helpers/localization_test_helpers.dart';

String _extractAllTextUnder(WidgetTester tester, Finder rootFinder) {
  final textFinder = find.descendant(
    of: rootFinder,
    matching: find.byType(Text),
  );
  final buffer = StringBuffer();
  for (final widget in tester.widgetList<Text>(textFinder)) {
    final text = widget.data ?? widget.textSpan?.toPlainText() ?? '';
    if (text.trim().isNotEmpty) {
      buffer.writeln(text);
    }
  }
  return buffer.toString();
}

void main() {
  setUpAll(() => LocalizationTestHelpers.setUpSuite());

  setUp(() => LocalizationTestHelpers.resetState());

  tearDown(() => LocalizationTestHelpers.resetState());

  group('F09 — App Shell, Landing Sections & Shared Dialogs', () {
    testWidgets(
      'F09-T1: RootScreen nav sections and greeting/date localize in English (en)',
      (tester) async {
        await LocalizationTestHelpers.pumpScreen(
          tester,
          const RootScreen(),
          locale: const Locale('en', 'GB'),
        );
        await TestAppHarness.drainAsync(tester);

        expect(find.byType(RootScreen), findsOneWidget);

        // Portuguese sidebar navigation labels must not leak in English mode.
        expect(find.text('Simulados'), findsNothing);
        expect(find.text('Cadernos'), findsNothing);
        expect(find.text('Configurações'), findsNothing);
        expect(find.text('Desempenho'), findsNothing);
        expect(find.text('Diário de Estudos'), findsNothing);

        // Greeting and formatted date must not contain Portuguese "de" connector or PT greeting.
        final shellText = _extractAllTextUnder(tester, find.byType(RootScreen));
        expect(shellText, isNot(contains('Bom dia')));
        expect(shellText, isNot(contains('Boa tarde')));
        expect(shellText, isNot(contains('Boa noite')));
        expect(
          RegExp(r'\d+\s+de\s+[a-zç]+').hasMatch(shellText.toLowerCase()),
          isFalse,
          reason: 'Formatted shell date should use English locale, not Portuguese "de"',
        );
      },
    );

    testWidgets(
      'F09-T2: DesktopTopBar tooltips and RootScreen notifications popover localize in English',
      (tester) async {
        await LocalizationTestHelpers.pumpScreen(
          tester,
          Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(DesktopTopBar.height),
              child: DesktopTopBar(onOpenNotifications: () {}),
            ),
            body: const SizedBox.shrink(),
          ),
          locale: const Locale('en', 'GB'),
        );

        final themeTooltip = tester.widget<Tooltip>(
          find.descendant(
            of: find.byKey(const Key('top_bar_theme_toggle')),
            matching: find.byType(Tooltip),
          ),
        );
        final bellTooltip = tester.widget<Tooltip>(
          find.descendant(
            of: find.byKey(const Key('notifications_bell_button')),
            matching: find.byType(Tooltip),
          ),
        );
        final settingsTooltip = tester.widget<Tooltip>(
          find.descendant(
            of: find.byKey(const Key('top_bar_settings_button')),
            matching: find.byType(Tooltip),
          ),
        );

        for (final entry in <(String, Tooltip, String)>[
          ('top_bar_theme_toggle', themeTooltip, 'Selecionar tema'),
          ('notifications_bell_button', bellTooltip, 'Notificações'),
          ('top_bar_settings_button', settingsTooltip, 'Configurações'),
        ]) {
          final msg = (entry.$2.message ?? '').trim();
          expect(
            msg,
            isNotEmpty,
            reason: 'Tooltip for ${entry.$1} must be non-empty in English',
          );
          expect(
            msg,
            isNot(entry.$3),
            reason: 'Tooltip for ${entry.$1} remained untranslated Portuguese',
          );
          expect(
            LocalizationTestHelpers.containsPortugueseLeakage(msg),
            isFalse,
            reason: 'Tooltip for ${entry.$1} leaked Portuguese: $msg',
          );
        }

        // Pump RootScreen in English and open the notifications popover.
        await LocalizationTestHelpers.pumpScreen(
          tester,
          const RootScreen(),
          locale: const Locale('en', 'GB'),
        );
        await TestAppHarness.drainAsync(tester);

        await tester.tap(find.byKey(const Key('notifications_bell_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final popoverFinder = find.byWidgetPredicate(
          (w) =>
              w is ConstrainedBox &&
              w.constraints.maxWidth == 390 &&
              w.constraints.maxHeight == 520,
        );
        expect(popoverFinder, findsOneWidget);

        final popoverTexts = tester
            .widgetList<Text>(
              find.descendant(of: popoverFinder, matching: find.byType(Text)),
            )
            .map((w) => (w.data ?? w.textSpan?.toPlainText() ?? '').trim())
            .toList();
        expect(popoverTexts, isNotEmpty);

        final popoverTitle = popoverTexts.first;
        expect(
          popoverTitle,
          isNotEmpty,
          reason: 'Notifications popover title must be non-empty',
        );
        expect(popoverTitle, isNot('Notificações'));
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(popoverTitle),
          isFalse,
          reason: 'Notifications popover title leaked Portuguese: $popoverTitle',
        );

        final initialPopoverText = _extractAllTextUnder(tester, popoverFinder);
        expect(initialPopoverText.trim(), isNotEmpty);
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(initialPopoverText),
          isFalse,
        );
        expect(find.text('Notificações'), findsNothing);
        expect(find.text('Tudo em dia'), findsNothing);
        expect(find.text('Marcar lidas'), findsNothing);

        // Ensure the empty-state view is also explicitly rendered and validated.
        if (NotificationsService.instance.notificationsNotifier.value.isNotEmpty) {
          NotificationsService.instance.notificationsNotifier.value = const [];
          await tester.pump();
        }
        expect(
          find.descendant(
            of: popoverFinder,
            matching: find.byIcon(Icons.done_all_rounded),
          ),
          findsOneWidget,
        );
        final emptyStateTexts = tester
            .widgetList<Text>(
              find.descendant(of: popoverFinder, matching: find.byType(Text)),
            )
            .map((w) => (w.data ?? w.textSpan?.toPlainText() ?? '').trim())
            .toList();
        expect(emptyStateTexts.length, greaterThanOrEqualTo(3));
        for (final label in emptyStateTexts) {
          expect(
            label,
            isNotEmpty,
            reason: 'Notifications popover empty-state label must be non-empty',
          );
          expect(label, isNot('Notificações'));
          expect(label, isNot('Tudo em dia'));
          expect(label, isNot('Tudo em dia!'));
          expect(
            LocalizationTestHelpers.containsPortugueseLeakage(label),
            isFalse,
            reason: 'Notifications popover empty-state leaked Portuguese: $label',
          );
        }
      },
    );

    testWidgets(
      'F09-T3: ProfileSettingsDialog and WeeklyGoalDialog render localized tabs/labels in English',
      (tester) async {
        await LocalizationTestHelpers.pumpScreen(
          tester,
          Builder(
            builder: (context) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    key: const Key('open_profile_dialog_btn'),
                    onPressed: () => showProfileSettingsDialog(context),
                    child: const Text('Profile'),
                  ),
                  ElevatedButton(
                    key: const Key('open_goal_dialog_btn'),
                    onPressed: () => showWeeklyGoalEditorDialog(context),
                    child: const Text('Goal'),
                  ),
                ],
              );
            },
          ),
          locale: const Locale('en', 'GB'),
        );

        await tester.tap(find.byKey(const Key('open_goal_dialog_btn')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await TestAppHarness.drainAsync(tester);

        final weeklyTabText = _extractAllTextUnder(
          tester,
          find.byKey(const Key('goal_mode_weekly_tab')),
        );
        final dailyTabText = _extractAllTextUnder(
          tester,
          find.byKey(const Key('goal_mode_daily_tab')),
        );
        expect(weeklyTabText.trim(), isNotEmpty);
        expect(dailyTabText.trim(), isNotEmpty);
        expect(weeklyTabText, isNot(contains('Meta Semanal')));
        expect(dailyTabText, isNot(contains('Meta Diária')));
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(
            '$weeklyTabText $dailyTabText',
          ),
          isFalse,
        );

        // Dismiss WeeklyGoalDialog via Navigator pop before opening ProfileSettingsDialog.
        final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
        navigator.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await tester.tap(find.byKey(const Key('open_profile_dialog_btn')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await TestAppHarness.drainAsync(tester);

        final generalTabText = _extractAllTextUnder(
          tester,
          find.byKey(const Key('profile_tab_general')),
        );
        final securityTabText = _extractAllTextUnder(
          tester,
          find.byKey(const Key('profile_tab_security')),
        );
        expect(generalTabText.trim(), isNotEmpty);
        expect(securityTabText.trim(), isNotEmpty);
        expect(generalTabText, isNot(contains('Geral')));
        expect(securityTabText, isNot(contains('Segurança')));
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(
            '$generalTabText $securityTabText',
          ),
          isFalse,
        );

        // Dismiss ProfileSettingsDialog and drain any pending font relayout callbacks.
        navigator.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await TestAppHarness.drainAsync(tester);
      },
    );

    testWidgets(
      'F09-T4: VipPrivilegesModal and VipRgbSpectrumPicker render localized copy in English',
      (tester) async {
        await LocalizationTestHelpers.pumpScreen(
          tester,
          SingleChildScrollView(
            child: Column(
              children: [
                const VipPrivilegesModal(),
                VipRgbSpectrumPicker(
                  color: Colors.amber,
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
          locale: const Locale('en', 'GB'),
        );

        final vipModalText = _extractAllTextUnder(
          tester,
          find.byType(VipPrivilegesModal),
        );
        final rgbText = _extractAllTextUnder(
          tester,
          find.byType(VipRgbSpectrumPicker),
        );

        expect(vipModalText.trim(), isNotEmpty);
        expect(rgbText.trim(), isNotEmpty);
        expect(vipModalText, isNot(contains('Discord do Aster')));
        expect(vipModalText, isNot(contains('Fechar')));
        expect(rgbText, isNot(contains('TONS VIP')));
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage('$vipModalText $rgbText'),
          isFalse,
        );
      },
    );

    testWidgets(
      'F09-T5: InsightGainToastOverlay localizes source category label in English without pending timers',
      (tester) async {
        await LocalizationTestHelpers.pumpScreen(
          tester,
          const InsightGainToastOverlay(
            child: SizedBox(width: 400, height: 300),
          ),
          locale: const Locale('en', 'GB'),
        );

        ShopService.instance.latestGainNotifier.value = InsightGainEvent(
          id: 't1',
          amount: 25,
          reason: 'Quiz completed',
          source: 'quiz_question',
          isVipBoosted: false,
          createdAt: DateTime(2026, 11, 27, 12),
        );

        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byKey(const Key('insight_gain_toast_container')), findsOneWidget);
        expect(find.byKey(const Key('insight_gain_toast_t1')), findsOneWidget);

        final toastText = _extractAllTextUnder(
          tester,
          find.byKey(const Key('insight_gain_toast_t1')),
        );
        expect(toastText, isNot(contains('Simulado')));
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(toastText),
          isFalse,
        );

        // Advance fake clock past auto-dismiss (3000ms) + exit animation (220ms) timers.
        await tester.pump(const Duration(seconds: 4));
        expect(find.byKey(const Key('insight_gain_toast_t1')), findsNothing);
      },
    );

    testWidgets(
      'F09-T6: LandingHeroSection, LandingBentoSection, LandingShowcaseSection, and LandingCommunitySection localize in English',
      (tester) async {
        await LocalizationTestHelpers.pumpScreen(
          tester,
          SingleChildScrollView(
            child: Column(
              children: [
                LandingHeroSection(
                  width: 1280,
                  onOpenLogin: () {},
                  onExploreResources: () {},
                ),
                const LandingBentoSection(width: 1280),
                const LandingShowcaseSection(width: 1280),
                const LandingCommunitySection(width: 1280),
              ],
            ),
          ),
          locale: const Locale('en', 'GB'),
        );

        expect(
          find.textContaining('Arquitetura modular, experiência única'),
          findsNothing,
        );
        expect(find.textContaining('Foco & Consistência'), findsNothing);
        expect(
          find.textContaining('Estudar em grupo muda o jogo'),
          findsNothing,
        );
        expect(
          find.textContaining('Fluxo Cognitivo Completo'),
          findsNothing,
        );

        final allSectionsText = _extractAllTextUnder(
          tester,
          find.byType(SingleChildScrollView),
        );
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(allSectionsText),
          isFalse,
        );
      },
    );
  });

  group('F10 — Auth, System Services & OAuth Loopback HTML', () {
    testWidgets(
      'F10-T1: AuthScreen renders localized login, labels, and recovery copy in English',
      (tester) async {
        await LocalizationTestHelpers.pumpScreen(
          tester,
          AuthScreen(onAuthenticated: () {}),
          locale: const Locale('en', 'GB'),
        );

        expect(find.text('Entrar na Aster Account'), findsNothing);
        expect(find.text('Esqueceu a senha?'), findsNothing);
        expect(find.text('E-MAIL'), findsNothing);
        expect(find.text('SENHA'), findsNothing);

        final authText = _extractAllTextUnder(tester, find.byType(AuthScreen));
        expect(authText.trim(), isNotEmpty);
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(authText),
          isFalse,
        );
      },
    );

    test(
      'F10-T2: SupabaseService.translateAuthError and extractOAuthCallbackError localize per active locale',
      () async {
        await NoesisLocaleService.setLanguage('en');
        final enInvalidCreds = SupabaseService.translateAuthError(
          'Invalid login credentials',
        );
        final enUnconfirmed = SupabaseService.translateAuthError(
          'Email not confirmed',
        );
        final enOAuthDenied = SupabaseService.extractOAuthCallbackError(
          Uri.parse('http://127.0.0.1/?error=access_denied'),
        );

        expect(enInvalidCreds, isNot('E-mail ou senha incorretos.'));
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(enInvalidCreds),
          isFalse,
        );
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(enUnconfirmed),
          isFalse,
        );
        expect(enOAuthDenied, isNotNull);
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(enOAuthDenied!),
          isFalse,
        );

        await NoesisLocaleService.setLanguage('es');
        final esInvalidCreds = SupabaseService.translateAuthError(
          'Invalid login credentials',
        );
        expect(esInvalidCreds, isNot('E-mail ou senha incorretos.'));
        expect(esInvalidCreds, isNot(enInvalidCreds));
      },
    );

    test(
      'F10-T3: NotificationsService.buildNotificationsFromData emits localized notifications in English',
      () async {
        await NoesisLocaleService.setLanguage('en');

        final notifications = NotificationsService.buildNotificationsFromData(
          now: DateTime(2026, 11, 27, 10),
          events: const [],
          sessions: const [],
          weeklyGoalMinutes: 600,
          dailyGoalMinutes: 60,
          decks: const [],
          notebooks: const [],
          exams: const [],
          roadmaps: const [],
          hasConfiguredAiKey: false,
          hasWelcomeBonus: true,
          isEmailConfirmed: false,
        );

        expect(notifications, isNotEmpty);
        for (final n in notifications) {
          expect(n.title, isNot('Confirme seu e-mail'));
          expect(n.timeLabel, isNot('Conta'));
          expect(n.timeLabel, isNot('Boas-vindas'));
          expect(
            LocalizationTestHelpers.containsPortugueseLeakage(
              '${n.title} ${n.message} ${n.timeLabel}',
            ),
            isFalse,
            reason: 'Notification ${n.id} leaked Portuguese: ${n.title}',
          );
        }
      },
    );

    test(
      'F10-T4: NoesisCrmService, InsightsEconomyConfig, and ShopService localize defaults and tier labels',
      () async {
        await NoesisLocaleService.setLanguage('en');

        const platformConfig = NoesisRemotePlatformConfig();
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(
            platformConfig.maintenanceMessage,
          ),
          isFalse,
        );

        for (final tier in ThemePriceTier.values) {
          final label = InsightsEconomyConfig.tierLabel(tier);
          expect(
            LocalizationTestHelpers.containsPortugueseLeakage(label),
            isFalse,
            reason: 'ThemePriceTier.$tier label leaked Portuguese: $label',
          );
        }
        expect(
          InsightsEconomyConfig.tierLabel(ThemePriceTier.essential),
          isNot('Essenciais'),
        );

        final awarded = ShopService.instance.claimAchievementReward(
          achievementId: 'first_step_test',
          title: 'First Step',
          amount: 50,
        );
        expect(awarded, greaterThan(0));
        final gainEvent = ShopService.instance.latestGainNotifier.value;
        expect(gainEvent, isNotNull);
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(gainEvent!.reason),
          isFalse,
          reason: 'ShopService achievement reason leaked Portuguese: ${gainEvent.reason}',
        );
      },
    );

    test(
      'F10-T5: Desktop OAuth loopback HTML uses active BCP-47 lang attribute and localized status copy',
      () async {
        for (final code in ['en', 'ar']) {
          await NoesisLocaleService.setLanguage(code);
          final expectedBcp47 = NoesisLocaleService.bcp47;
          String? capturedRedirectUrl;
          var htmlResponse = '';

          final ok = await oauth_loopback.runDesktopOAuthLoopback(
            client: SupabaseService.client,
            startAuthFlow: (redirectUrl) async {
              capturedRedirectUrl = redirectUrl;
              return OAuthResponse(
                provider: OAuthProvider.google,
                url: 'https://accounts.google.com/o/oauth2/v2/auth?redirect_to=${Uri.encodeComponent(redirectUrl)}',
              );
            },
            launchBrowserOverride: (authUri) async {
              final callbackBase = Uri.parse(capturedRedirectUrl!);
              final socket = await Socket.connect(
                InternetAddress.loopbackIPv4,
                callbackBase.port,
              );
              socket.write(
                'GET /?code=pkce-test-code HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n',
              );
              await socket.flush();
              htmlResponse = await utf8.decoder.bind(socket).join();
              await socket.close();
              return true;
            },
            sessionFromUrlOverride: (_) async {},
          );

          expect(ok, isTrue);
          expect(htmlResponse, contains('lang="$expectedBcp47"'));
          expect(htmlResponse, isNot(contains('lang="pt-BR"')));
          expect(htmlResponse, isNot(contains('Login concluído no Noesis!')));
          expect(
            LocalizationTestHelpers.containsPortugueseLeakage(htmlResponse),
            isFalse,
          );
          if (code == 'ar') {
            expect(htmlResponse.toLowerCase(), contains('dir="rtl"'));
          }
        }
      },
    );
  });
}
