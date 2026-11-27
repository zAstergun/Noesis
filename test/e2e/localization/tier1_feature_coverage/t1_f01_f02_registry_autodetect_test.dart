import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/localization/noesis_locale_service.dart';
import 'package:noesis/widgets/country_flag_icon.dart';

import '../helpers/localization_test_helpers.dart';

void main() {
  setUpAll(() => LocalizationTestHelpers.setUpSuite());
  setUp(() => LocalizationTestHelpers.resetState());
  tearDown(() => LocalizationTestHelpers.resetState());

  group('Feature 01: 15-Language Canonical Registry', () {
    test(
      'supportedLanguages exposes all 15 canonical Aster codes in order with complete metadata',
      () {
        final languages = NoesisLocaleService.supportedLanguages;
        expect(
          languages,
          hasLength(15),
          reason: 'Aster ecosystem requires exactly 15 supported languages',
        );

        final codes = languages.map((lang) => lang.code).toList();
        expect(
          codes,
          equals(LocalizationTestHelpers.all15LanguageCodes),
          reason: 'Canonical registry order must match the 15 Aster flag codes',
        );
        expect(codes.toSet(), hasLength(15));

        final flutterLocales = NoesisLocaleService.supportedFlutterLocales;
        expect(flutterLocales, hasLength(15));
        expect(flutterLocales.toSet(), hasLength(15));

        final bcp47Tags = languages.map((lang) => lang.bcp47).toSet();
        final intlTags = languages.map((lang) => lang.intlLocale).toSet();
        expect(bcp47Tags, hasLength(15));
        expect(intlTags, hasLength(15));

        for (final lang in languages) {
          expect(lang.nativeName.trim(), isNotEmpty, reason: lang.code);
          expect(lang.regionKey.trim(), isNotEmpty, reason: lang.code);
          expect(lang.aiLanguageName.trim(), isNotEmpty, reason: lang.code);
          expect(lang.bcp47.trim(), isNotEmpty, reason: lang.code);
          expect(lang.intlLocale.trim(), isNotEmpty, reason: lang.code);
        }
      },
    );

    test(
      'only Arabic (ar) is marked RTL and resolves TextDirection.rtl',
      () async {
        final rtlLanguages = NoesisLocaleService.supportedLanguages
            .where((lang) => lang.isRtl)
            .map((lang) => lang.code)
            .toList();
        expect(rtlLanguages, equals(<String>['ar']));

        await LocalizationTestHelpers.resetState(initialCode: 'ar');
        expect(NoesisLocaleService.isRtl, isTrue);
        expect(NoesisLocaleService.textDirection, TextDirection.rtl);

        await LocalizationTestHelpers.resetState(initialCode: 'en');
        expect(NoesisLocaleService.isRtl, isFalse);
        expect(NoesisLocaleService.textDirection, TextDirection.ltr);

        await LocalizationTestHelpers.resetState(initialCode: 'br');
        expect(NoesisLocaleService.isRtl, isFalse);
        expect(NoesisLocaleService.textDirection, TextDirection.ltr);
      },
    );

    test(
      'isSupportedCode, optionForCode, and normalizeCode resolve all 15 codes and BCP-47/POSIX aliases',
      () {
        for (final code in LocalizationTestHelpers.all15LanguageCodes) {
          expect(
            NoesisLocaleService.isSupportedCode(code),
            isTrue,
            reason: 'Code $code must be supported',
          );
          expect(
            NoesisLocaleService.isSupportedCode(' ${code.toUpperCase()} '),
            isTrue,
            reason: 'Trim/case normalization for $code',
          );
          expect(NoesisLocaleService.optionForCode(code).code, equals(code));
        }

        expect(NoesisLocaleService.isSupportedCode('xx'), isFalse);
        expect(NoesisLocaleService.isSupportedCode(''), isFalse);
        expect(NoesisLocaleService.isSupportedCode(null), isFalse);

        expect(NoesisLocaleService.normalizeCode('ja'), equals('jp'));
        expect(NoesisLocaleService.normalizeCode('zh'), equals('cn'));
        expect(NoesisLocaleService.normalizeCode('ko'), equals('kr'));
        expect(NoesisLocaleService.normalizeCode('vi'), equals('vn'));
        expect(NoesisLocaleService.normalizeCode('in'), equals('id'));
        expect(NoesisLocaleService.normalizeCode('pt-PT'), equals('pt'));
        expect(NoesisLocaleService.normalizeCode('pt_PT'), equals('pt'));
        expect(NoesisLocaleService.normalizeCode('pt-BR'), equals('br'));
        expect(NoesisLocaleService.normalizeCode('pt_BR'), equals('br'));

        expect(NoesisLocaleService.optionForCode('ja').code, equals('jp'));
        expect(NoesisLocaleService.optionForCode('zh').code, equals('cn'));
        expect(NoesisLocaleService.optionForCode('ko').code, equals('kr'));
        expect(NoesisLocaleService.optionForCode('vi').code, equals('vn'));
        expect(NoesisLocaleService.optionForCode('pt-PT').code, equals('pt'));
        expect(NoesisLocaleService.optionForCode('pt-BR').code, equals('br'));
      },
    );

    testWidgets(
      'CountryFlagIcon renders cleanly for all 15 canonical language codes',
      (tester) async {
        await LocalizationTestHelpers.pumpScreen(
          tester,
          Center(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final code in LocalizationTestHelpers.all15LanguageCodes)
                  CountryFlagIcon(code: code),
              ],
            ),
          ),
        );

        expect(find.byType(CountryFlagIcon), findsNWidgets(15));
        expect(tester.takeException(), isNull);
      },
    );

    test(
      'activeAiLanguageName, bcp47, and intlLocale reflect the active registered language',
      () async {
        await LocalizationTestHelpers.resetState(initialCode: 'ar');
        expect(NoesisLocaleService.activeAiLanguageName, equals('Arabic'));
        expect(NoesisLocaleService.bcp47, equals('ar-SA'));
        expect(NoesisLocaleService.intlLocale, equals('ar_SA'));

        await LocalizationTestHelpers.resetState(initialCode: 'jp');
        expect(NoesisLocaleService.activeAiLanguageName, equals('Japanese'));
        expect(NoesisLocaleService.bcp47, equals('ja-JP'));
        expect(NoesisLocaleService.intlLocale, equals('ja_JP'));

        await LocalizationTestHelpers.resetState(initialCode: 'pt');
        expect(
          NoesisLocaleService.activeAiLanguageName,
          equals('European Portuguese (pt-PT)'),
        );
        expect(NoesisLocaleService.bcp47, equals('pt-PT'));
        expect(NoesisLocaleService.intlLocale, equals('pt_PT'));

        await LocalizationTestHelpers.resetState(initialCode: 'br');
        expect(
          NoesisLocaleService.activeAiLanguageName,
          equals('Brazilian Portuguese (pt-BR)'),
        );
        expect(NoesisLocaleService.bcp47, equals('pt-BR'));
        expect(NoesisLocaleService.intlLocale, equals('pt_BR'));
      },
    );
  });

  group('Feature 02: Auto-Detection & English Fallback', () {
    test(
      'distinguishes European Portuguese (pt-PT) from Brazilian Portuguese (pt-BR)',
      () {
        expect(
          NoesisLocaleService.detectLanguageCodeFromLocales(
            const <Locale>[Locale('pt', 'PT')],
          ),
          equals('pt'),
        );
        expect(
          NoesisLocaleService.detectLanguageCodeFromLocales(
            const <Locale>[Locale('pt', 'BR')],
          ),
          equals('br'),
        );
        expect(
          NoesisLocaleService.detectLanguageCodeFromLocales(
            const <Locale>[Locale('pt')],
          ),
          equals('br'),
        );
        expect(
          NoesisLocaleService.detectLanguageCodeFromLocales(
            const <Locale>[Locale.fromSubtags(languageCode: 'pt', countryCode: 'PT')],
          ),
          equals('pt'),
        );
      },
    );

    test(
      'matches regional and script subtags for all supported base languages',
      () {
        final regionalCases = <Locale, String>{
          const Locale('es', 'MX'): 'es',
          const Locale('es', '419'): 'es',
          const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hans',
            countryCode: 'CN',
          ): 'cn',
          const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
            countryCode: 'TW',
          ): 'cn',
          const Locale('fr', 'CA'): 'fr',
          const Locale('en', 'US'): 'en',
          const Locale('de', 'AT'): 'de',
          const Locale('it', 'CH'): 'it',
          const Locale('nl', 'BE'): 'nl',
          const Locale('ru', 'BY'): 'ru',
          const Locale('ar', 'EG'): 'ar',
          const Locale('id', 'ID'): 'id',
          const Locale('vi', 'VN'): 'vn',
          const Locale('ja', 'JP'): 'jp',
          const Locale('ko', 'KR'): 'kr',
        };

        regionalCases.forEach((locale, expectedCode) {
          expect(
            NoesisLocaleService.detectLanguageCodeFromLocales(<Locale>[locale]),
            equals(expectedCode),
            reason: 'Locale ${locale.toLanguageTag()} should map to $expectedCode',
          );
        });
      },
    );

    test(
      'selects the first supported locale in an ordered preference list',
      () {
        expect(
          NoesisLocaleService.detectLanguageCodeFromLocales(
            const <Locale>[
              Locale('sv', 'SE'),
              Locale('ja', 'JP'),
              Locale('fr', 'FR'),
            ],
          ),
          equals('jp'),
        );

        expect(
          NoesisLocaleService.detectLanguageCodeFromLocales(
            const <Locale>[
              Locale('pl', 'PL'),
              Locale('pt', 'PT'),
              Locale('pt', 'BR'),
            ],
          ),
          equals('pt'),
        );
      },
    );

    test(
      'falls back to English (en) when no locale is supported or list is empty',
      () async {
        expect(
          NoesisLocaleService.detectLanguageCodeFromLocales(
            const <Locale>[Locale('sv', 'SE'), Locale('pl', 'PL')],
          ),
          equals('en'),
        );
        expect(
          NoesisLocaleService.detectLanguageCodeFromLocales(const <Locale>[]),
          equals('en'),
        );

        await LocalizationTestHelpers.resetState(
          platformLocalesOverride: const <Locale>[Locale('th', 'TH')],
        );
        expect(NoesisLocaleService.currentCode, equals('en'));
        expect(NoesisLocaleService.selectionSource, NoesisLocaleSource.auto);
      },
    );

    testWidgets(
      'NoesisApp startup auto-detects OS locale and updates on didChangeLocales when source is auto',
      (tester) async {
        await LocalizationTestHelpers.resetState(
          platformLocalesOverride: const <Locale>[Locale('de', 'DE')],
        );
        await LocalizationTestHelpers.pumpNoesisApp(
          tester,
          platformLocalesOverride: const <Locale>[Locale('de', 'DE')],
        );

        expect(NoesisLocaleService.currentCode, equals('de'));
        expect(NoesisLocaleService.selectionSource, NoesisLocaleSource.auto);

        // Allow didChangeLocales -> handlePlatformLocalesChanged to read platformDispatcher
        NoesisLocaleService.platformLocalesOverrideForTesting = null;
        tester.platformDispatcher.localesTestValue = const <Locale>[
          Locale('ko', 'KR'),
        ];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        addTearDown(
          () => tester.binding.setLocales(const <Locale>[Locale('pt', 'BR')]),
        );

        await tester.binding.setLocales(const <Locale>[Locale('ko', 'KR')]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(NoesisLocaleService.currentCode, equals('kr'));
        expect(NoesisLocaleService.selectionSource, NoesisLocaleSource.auto);
      },
    );
  });
}
