import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:noesis/core/localization/noesis_locale_service.dart';
import 'package:noesis/core/supabase_service.dart';
import 'package:noesis/core/theme.dart';
import 'package:noesis/main.dart';

import '../helpers/localization_test_helpers.dart';

void main() {
  setUpAll(() => LocalizationTestHelpers.setUpSuite());
  setUp(() => LocalizationTestHelpers.resetState());
  tearDown(() => LocalizationTestHelpers.resetState());

  group('Feature 03: Persistence & Precedence', () {
    test(
      'setLanguage persists manual preference across simulated app restart and overrides OS locale',
      () async {
        await LocalizationTestHelpers.resetState(
          platformLocalesOverride: const <Locale>[Locale('de', 'DE')],
        );
        expect(NoesisLocaleService.currentCode, equals('de'));
        expect(NoesisLocaleService.selectionSource, NoesisLocaleSource.auto);

        await NoesisLocaleService.setLanguage('fr');
        expect(NoesisLocaleService.currentCode, equals('fr'));
        expect(NoesisLocaleService.selectionSource, NoesisLocaleSource.manual);

        // Simulate app restart without clearing stored preference while OS reports German
        await NoesisLocaleService.resetForTesting(
          clearStoredPreference: false,
          platformLocalesOverride: const <Locale>[Locale('de', 'DE')],
        );

        expect(NoesisLocaleService.currentCode, equals('fr'));
        expect(NoesisLocaleService.selectionSource, NoesisLocaleSource.manual);
      },
    );

    test(
      'saveUserLanguagePreference stores profile language locally and restores on startup when no manual override exists',
      () async {
        await SupabaseService.saveUserLanguagePreference('kr');
        expect(
          SupabaseService.userProfileNotifier.value?['stats']?['noesis_language'],
          equals('kr'),
        );

        await NoesisLocaleService.resetForTesting(
          clearStoredPreference: true,
          platformLocalesOverride: const <Locale>[Locale('de', 'DE')],
        );

        expect(NoesisLocaleService.currentCode, equals('kr'));
        expect(NoesisLocaleService.selectionSource, NoesisLocaleSource.profile);
      },
    );

    test(
      'manual selection takes precedence over saved profile language (manual > profile > auto > en)',
      () async {
        await LocalizationTestHelpers.resetState(
          platformLocalesOverride: const <Locale>[Locale('de', 'DE')],
        );
        await NoesisLocaleService.setLanguage('es');

        await NoesisLocaleService.applyProfileLanguageIfNoManualOverride(
          const <String, dynamic>{
            'stats': <String, dynamic>{'noesis_language': 'it'},
          },
        );

        expect(NoesisLocaleService.currentCode, equals('es'));
        expect(NoesisLocaleService.selectionSource, NoesisLocaleSource.manual);

        // Simulate restart: manual local preference still beats profile & OS locale
        await NoesisLocaleService.resetForTesting(
          clearStoredPreference: false,
          platformLocalesOverride: const <Locale>[Locale('de', 'DE')],
        );
        expect(NoesisLocaleService.currentCode, equals('es'));
        expect(NoesisLocaleService.selectionSource, NoesisLocaleSource.manual);
      },
    );

    test(
      'saved profile language overrides OS auto-detection when source is auto',
      () async {
        await LocalizationTestHelpers.resetState(
          platformLocalesOverride: const <Locale>[Locale('de', 'DE')],
        );
        expect(NoesisLocaleService.currentCode, equals('de'));
        expect(NoesisLocaleService.selectionSource, NoesisLocaleSource.auto);

        await NoesisLocaleService.applyProfileLanguageIfNoManualOverride(
          const <String, dynamic>{
            'stats': <String, dynamic>{'noesis_language': 'it'},
          },
        );

        expect(NoesisLocaleService.currentCode, equals('it'));
        expect(NoesisLocaleService.selectionSource, NoesisLocaleSource.profile);
      },
    );

    test(
      'loadFullProfile returns cached profile language when unauthenticated and extractLanguageFromProfile normalizes tags',
      () async {
        await SupabaseService.saveUserLanguagePreference('jp');
        SupabaseService.userProfileNotifier.value = null;

        final profile = await SupabaseService.loadFullProfile();
        expect(
          NoesisLocaleService.extractLanguageFromProfile(profile),
          equals('jp'),
        );
        expect(
          NoesisLocaleService.extractLanguageFromProfile(
            const <String, dynamic>{'noesis_language': 'pt-PT'},
          ),
          equals('pt'),
        );
        expect(
          NoesisLocaleService.extractLanguageFromProfile(
            const <String, dynamic>{
              'stats': <String, dynamic>{'noesis_language': 'ar'},
            },
          ),
          equals('ar'),
        );
      },
    );
  });

  group('Feature 04: App Locale Binding & Date/Font Setup', () {
    testWidgets(
      'NoesisApp MaterialApp binds all 15 supportedLocales and Global*Localizations delegates',
      (tester) async {
        await LocalizationTestHelpers.pumpNoesisApp(tester);

        final appFinder = find.byType(MaterialApp);
        expect(appFinder, findsOneWidget);

        final materialApp = tester.widget<MaterialApp>(appFinder);
        final supported = materialApp.supportedLocales.toList();
        expect(supported, hasLength(15));
        for (final expectedLocale in NoesisLocaleService.supportedFlutterLocales) {
          expect(supported, contains(expectedLocale));
        }

        final delegates = materialApp.localizationsDelegates?.toList() ?? const [];
        expect(delegates, contains(GlobalMaterialLocalizations.delegate));
        expect(delegates, contains(GlobalWidgetsLocalizations.delegate));
        expect(delegates, contains(GlobalCupertinoLocalizations.delegate));
      },
    );

    testWidgets(
      'NoesisApp MaterialApp.locale updates dynamically when NoesisLocaleService.setLanguage is called',
      (tester) async {
        await LocalizationTestHelpers.pumpNoesisApp(tester);

        await NoesisLocaleService.setLanguage('jp');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        var materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(materialApp.locale, equals(const Locale('ja', 'JP')));

        await NoesisLocaleService.setLanguage('ar');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(materialApp.locale, equals(const Locale('ar', 'SA')));
      },
    );

    testWidgets(
      'NoesisApp wraps tree in Directionality matching active locale',
      (tester) async {
        await LocalizationTestHelpers.resetState(initialCode: 'ar');
        await LocalizationTestHelpers.pumpNoesisApp(tester);

        expect(
          Directionality.of(tester.element(find.byType(RootScreen))),
          equals(TextDirection.rtl),
        );

        await NoesisLocaleService.setLanguage('en');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          Directionality.of(tester.element(find.byType(RootScreen))),
          equals(TextDirection.ltr),
        );
      },
    );

    test(
      'intl DateFormat formats dates without LocaleDataException across all 15 supported locales',
      () async {
        await NoesisLocaleService.ensureInitialized(forceReload: true);
        final sampleDate = DateTime(2026, 5, 14);

        for (final lang in NoesisLocaleService.supportedLanguages) {
          final formattedLong = DateFormat.yMMMMd(lang.intlLocale).format(sampleDate);
          final formattedWeekday = DateFormat.E(lang.intlLocale).format(sampleDate);
          expect(
            formattedLong.trim(),
            isNotEmpty,
            reason: 'Long date for ${lang.code} (${lang.intlLocale})',
          );
          expect(
            formattedWeekday.trim(),
            isNotEmpty,
            reason: 'Weekday for ${lang.code} (${lang.intlLocale})',
          );
        }
      },
    );

    test(
      'AsterTheme configures non-empty fontFamilyFallback for multi-script typography',
      () {
        final lightFallback =
            AsterTheme.softClayTheme.textTheme.bodyMedium?.fontFamilyFallback;
        final lightTitleFallback =
            AsterTheme.softClayTheme.textTheme.titleMedium?.fontFamilyFallback;
        final darkFallback =
            AsterTheme.darkTheme.textTheme.bodyMedium?.fontFamilyFallback;

        expect(lightFallback, isNotNull);
        expect(lightFallback, isNotEmpty);
        expect(lightTitleFallback, isNotNull);
        expect(lightTitleFallback, isNotEmpty);
        expect(darkFallback, isNotNull);
        expect(darkFallback, isNotEmpty);

        final joined = lightFallback!.join(',').toLowerCase();
        expect(joined, contains('arabic'));
        expect(joined, contains('cjk'));
      },
    );
  });
}
