import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:noesis/core/localization/noesis_locale_service.dart';
import 'package:noesis/features/landing/landing_screen.dart';
import 'package:noesis/features/settings/settings_screen.dart';
import 'package:noesis/widgets/country_flag_icon.dart';

import '../../harness/test_app_harness.dart';
import '../helpers/localization_test_helpers.dart';

void main() {
  setUpAll(() => LocalizationTestHelpers.setUpSuite());
  setUp(() => LocalizationTestHelpers.resetState());
  tearDown(() => LocalizationTestHelpers.resetState());

  group('Feature 05: Landing Top-Bar Language Switcher', () {
    testWidgets(
      'desktop top bar places landing_language_button directly left of landing_theme_button and login CTA',
      (tester) async {
        await LocalizationTestHelpers.pumpScreen(
          tester,
          LandingScreen(onOpenLogin: () {}),
          screenSize: const Size(1280, 800),
        );

        final langFinder = find.byKey(const Key('landing_language_button'));
        final themeFinder = find.byKey(const Key('landing_theme_button'));
        final loginFinder = find.byKey(const Key('landing_nav_login_button'));

        expect(langFinder, findsOneWidget);
        expect(themeFinder, findsOneWidget);
        expect(loginFinder, findsOneWidget);

        final langRect = tester.getRect(langFinder);
        final themeRect = tester.getRect(themeFinder);
        final loginRect = tester.getRect(loginFinder);

        expect(langRect.right, lessThanOrEqualTo(themeRect.left));
        expect(themeRect.left - langRect.right, lessThanOrEqualTo(24.0));
        expect(themeRect.right, lessThanOrEqualTo(loginRect.left));
        expect((langRect.center.dy - themeRect.center.dy).abs(), lessThan(4.0));
      },
    );

    testWidgets(
      'compact mobile top bar (360x780) renders landing_language_button without overflow and opens dialog',
      (tester) async {
        final previousOnError = FlutterError.onError;
        final capturedErrors = <FlutterErrorDetails>[];
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          FlutterError.onError = previousOnError;
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        try {
          FlutterError.onError = (FlutterErrorDetails details) {
            capturedErrors.add(details);
            if (details.exceptionAsString().contains('RenderFlex overflowed')) {
              return;
            }
            previousOnError?.call(details);
          };

          await tester.pumpWidget(
            TestAppHarness.wrapWidget(
              LandingScreen(onOpenLogin: () {}),
              screenSize: const Size(360, 780),
            ),
          );
          await tester.pump();
          await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pump();
          await GoogleFonts.pendingFonts();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          final langFinder = find.byKey(const Key('landing_language_button'));
          if (langFinder.evaluate().isNotEmpty) {
            await tester.tap(langFinder);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
          }
        } finally {
          FlutterError.onError = previousOnError;
        }

        final overflowMessages = capturedErrors
            .map((e) => e.exceptionAsString())
            .where((msg) => msg.contains('RenderFlex overflowed'))
            .toList();
        expect(
          overflowMessages,
          isEmpty,
          reason:
              'Compact mobile top bar and dialog must render without RenderFlex overflow: $overflowMessages',
        );
        expect(find.byKey(const Key('landing_language_button')), findsOneWidget);
        expect(find.byKey(const Key('landing_language_dialog')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'landing_language_dialog displays all 15 language options',
      (tester) async {
        await LocalizationTestHelpers.pumpScreen(
          tester,
          LandingScreen(onOpenLogin: () {}),
          screenSize: const Size(1280, 800),
        );

        await tester.tap(find.byKey(const Key('landing_language_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(const Key('landing_language_dialog')), findsOneWidget);
        for (final code in LocalizationTestHelpers.all15LanguageCodes) {
          expect(
            find.byKey(Key('landing_lang_option_$code')),
            findsOneWidget,
            reason: 'Landing dialog must display option for $code',
          );
        }
      },
    );

    testWidgets(
      'selecting a language option updates NoesisLocaleService, closes dialog, and updates header flag',
      (tester) async {
        await LocalizationTestHelpers.pumpScreen(
          tester,
          LandingScreen(onOpenLogin: () {}),
          screenSize: const Size(1280, 800),
        );

        await tester.tap(find.byKey(const Key('landing_language_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final jpOption = find.byKey(const Key('landing_lang_option_jp'));
        await tester.ensureVisible(jpOption);
        await tester.tap(jpOption);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(const Key('landing_language_dialog')), findsNothing);
        expect(NoesisLocaleService.currentCode, equals('jp'));

        final flag = tester.widget<CountryFlagIcon>(
          find.descendant(
            of: find.byKey(const Key('landing_language_button')),
            matching: find.byType(CountryFlagIcon),
          ),
        );
        expect(flag.code, equals('jp'));
      },
    );

    testWidgets(
      'selecting English updates LandingScreen visible UI text immediately without Portuguese residue',
      (tester) async {
        await LocalizationTestHelpers.resetState(initialCode: 'br');
        await LocalizationTestHelpers.pumpScreen(
          tester,
          LandingScreen(onOpenLogin: () {}),
          screenSize: const Size(1280, 800),
        );

        await tester.tap(find.byKey(const Key('landing_language_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final enOption = find.byKey(const Key('landing_lang_option_en'));
        await tester.ensureVisible(enOption);
        await tester.tap(enOption);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(NoesisLocaleService.currentCode, equals('en'));

        final tooltip = tester.widget<Tooltip>(
          find.ancestor(
            of: find.byKey(const Key('landing_language_button')),
            matching: find.byType(Tooltip),
          ),
        );
        final tooltipMsg = tooltip.message ?? '';
        expect(
          tooltipMsg.startsWith('Idioma:'),
          isFalse,
          reason: 'Header language tooltip must be translated when English is active',
        );
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(tooltipMsg),
          isFalse,
        );

        final loginText = tester.widget<Text>(
          find.descendant(
            of: find.byKey(const Key('landing_nav_login_button')),
            matching: find.byType(Text),
          ),
        );
        expect(
          loginText.data,
          isNot(equals('Acessar ferramenta')),
          reason: 'Header login CTA must update immediately when English is selected',
        );
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(loginText.data ?? ''),
          isFalse,
        );
      },
    );
  });

  group('Feature 06: Settings Language & Region Screen', () {
    testWidgets(
      'SettingsScreen displays all 15 settings_lang_option_<code> tiles',
      (tester) async {
        await LocalizationTestHelpers.pumpScreen(
          tester,
          const SettingsScreen(),
        );

        await tester.ensureVisible(
          find.byKey(const Key('settings_lang_option_br')),
        );
        await tester.pump();

        for (final code in LocalizationTestHelpers.all15LanguageCodes) {
          expect(
            find.byKey(Key('settings_lang_option_$code')),
            findsOneWidget,
            reason: 'SettingsScreen must list option for $code',
          );
        }
      },
    );

    testWidgets(
      'SettingsScreen does not display legacy development warning banner',
      (tester) async {
        await LocalizationTestHelpers.pumpScreen(
          tester,
          const SettingsScreen(),
        );

        await tester.ensureVisible(
          find.byKey(const Key('settings_lang_option_br')),
        );
        await tester.pump();

        expect(
          find.textContaining('As traduções completas estão em desenvolvimento'),
          findsNothing,
        );
        expect(
          find.textContaining('Sua seleção fica registrada no perfil'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'tapping settings_lang_option_fr switches locale to fr and displays confirmation SnackBar',
      (tester) async {
        await LocalizationTestHelpers.pumpScreen(
          tester,
          const SettingsScreen(),
        );

        final frOption = find.byKey(const Key('settings_lang_option_fr'));
        await tester.ensureVisible(frOption);
        await tester.pump();
        await tester.tap(frOption);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(NoesisLocaleService.currentCode, equals('fr'));
        expect(find.byType(SnackBar), findsOneWidget);

        // Drain 2-second SnackBar timer
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'tapping settings_lang_option_ar switches active locale and Directionality to RTL',
      (tester) async {
        await LocalizationTestHelpers.pumpScreen(
          tester,
          const SettingsScreen(),
        );

        final arOption = find.byKey(const Key('settings_lang_option_ar'));
        await tester.ensureVisible(arOption);
        await tester.pump();
        await tester.tap(arOption);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(NoesisLocaleService.currentCode, equals('ar'));
        expect(NoesisLocaleService.isRtl, isTrue);
        expect(
          Directionality.of(tester.element(find.byType(SettingsScreen))),
          equals(TextDirection.rtl),
        );

        // Drain 2-second SnackBar timer
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'SettingsScreen renders localized region labels and heading when English is active',
      (tester) async {
        await LocalizationTestHelpers.resetState(initialCode: 'en');
        await LocalizationTestHelpers.pumpScreen(
          tester,
          const SettingsScreen(),
          locale: const Locale('en', 'GB'),
        );

        await tester.ensureVisible(
          find.byKey(const Key('settings_lang_option_ar')),
        );
        await tester.pump();

        expect(find.text('Idioma e Região'), findsNothing);
        expect(find.text('Japão'), findsNothing);
        expect(find.text('Coreia do Sul'), findsNothing);
        expect(find.text('Mundo Árabe'), findsNothing);

        final languageHeaderRow = find.ancestor(
          of: find.byIcon(Icons.language_rounded),
          matching: find.byType(Row),
        ).first;
        final headerTexts = tester
            .widgetList<Text>(
              find.descendant(
                of: languageHeaderRow,
                matching: find.byType(Text),
              ),
            )
            .toList();
        expect(headerTexts, hasLength(2));
        for (final textWidget in headerTexts) {
          final text = (textWidget.data ?? '').trim();
          expect(text, isNotEmpty);
          expect(
            LocalizationTestHelpers.containsPortugueseLeakage(text),
            isFalse,
            reason:
                'Language section header text "$text" must not contain Portuguese leakage',
          );
        }

        final arOptionTexts = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byKey(const Key('settings_lang_option_ar')),
                matching: find.byType(Text),
              ),
            )
            .toList();
        expect(arOptionTexts, hasLength(2));
        for (final textWidget in arOptionTexts) {
          final text = (textWidget.data ?? '').trim();
          expect(text, isNotEmpty);
          expect(
            LocalizationTestHelpers.containsPortugueseLeakage(text),
            isFalse,
            reason:
                'Arabic option text "$text" must not contain Portuguese leakage',
          );
        }

        for (final code in LocalizationTestHelpers.all15LanguageCodes) {
          final optionTexts = tester
              .widgetList<Text>(
                find.descendant(
                  of: find.byKey(Key('settings_lang_option_$code')),
                  matching: find.byType(Text),
                ),
              )
              .toList();
          expect(
            optionTexts,
            hasLength(2),
            reason: 'Option $code must render native name and region subtitle',
          );
          for (final textWidget in optionTexts) {
            final text = (textWidget.data ?? '').trim();
            expect(
              text,
              isNotEmpty,
              reason: 'Option $code text must be non-empty',
            );
            expect(
              LocalizationTestHelpers.containsPortugueseLeakage(text),
              isFalse,
              reason:
                  'Option $code text "$text" must not leak Portuguese when English is active',
            );
          }
        }
      },
    );
  });
}
