import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../helpers/localization_test_helpers.dart';

void main() {
  setUpAll(() => LocalizationTestHelpers.setUpSuite());
  setUp(() => LocalizationTestHelpers.resetState());
  tearDown(() => LocalizationTestHelpers.resetState());

  group('Feature 07: Multiplatform Native Configs', () {
    test(
      'AndroidManifest.xml enables RTL support and locale/layoutDirection configChanges',
      () {
        final manifest = LocalizationTestHelpers.readProjectFile(
          'android/app/src/main/AndroidManifest.xml',
        );

        expect(manifest, contains('android:supportsRtl="true"'));

        final configChangesMatch = RegExp(
          r'android:configChanges="([^"]+)"',
        ).firstMatch(manifest);
        expect(configChangesMatch, isNotNull);

        final tokens = configChangesMatch!.group(1)!.split('|');
        expect(tokens, contains('locale'));
        expect(tokens, contains('layoutDirection'));
      },
    );

    test(
      'ios/Runner/Info.plist declares CFBundleLocalizations for all 15 supported languages',
      () {
        final plist = LocalizationTestHelpers.readProjectFile(
          'ios/Runner/Info.plist',
        );

        final blockMatch = RegExp(
          r'<key>CFBundleLocalizations</key>\s*<array>([\s\S]*?)</array>',
        ).firstMatch(plist);
        expect(blockMatch, isNotNull);

        final locales = RegExp(r'<string>([^<]+)</string>')
            .allMatches(blockMatch!.group(1)!)
            .map((m) => m.group(1)!.trim())
            .toList();

        const expectedTags = <String>[
          'pt-BR',
          'en',
          'es',
          'ja',
          'zh',
          'ko',
          'vi',
          'id',
          'fr',
          'de',
          'it',
          'nl',
          'ru',
          'ar',
          'pt-PT',
        ];

        expect(locales, hasLength(15));
        expect(locales.toSet(), equals(expectedTags.toSet()));
      },
    );

    test(
      'web/index.html detects browser language dynamically across all 15 supported tags',
      () {
        final indexHtml = LocalizationTestHelpers.readProjectFile('web/index.html');

        expect(
          RegExp(r'<html\b[^>]*\blang="pt-BR"', caseSensitive: false)
              .hasMatch(indexHtml),
          isFalse,
          reason: 'index.html must not hardcode pt-BR on root <html>',
        );
        expect(indexHtml, contains('navigator.languages'));
        expect(indexHtml, contains('document.documentElement.lang'));

        const expectedTags = <String>[
          'pt-BR',
          'pt-PT',
          'en',
          'es',
          'ja',
          'zh',
          'ko',
          'vi',
          'id',
          'fr',
          'de',
          'it',
          'nl',
          'ru',
          'ar',
        ];
        for (final tag in expectedTags) {
          expect(
            indexHtml,
            contains("'$tag'"),
            reason: 'web/index.html auto-detect list must include $tag',
          );
        }
      },
    );

    test(
      'web/manifest.json is valid JSON with neutral language declaration',
      () {
        final raw = LocalizationTestHelpers.readProjectFile('web/manifest.json');
        final decoded = jsonDecode(raw) as Map<String, dynamic>;

        expect(decoded['name'], equals('Noesis'));
        expect(decoded['lang'], equals('en'));
        expect(decoded['lang'], isNot(equals('pt-BR')));
      },
    );

    test(
      'locale_dom_web.dart updates html lang and dir attributes for RTL/LTR',
      () {
        final source = LocalizationTestHelpers.readProjectFile(
          'lib/core/localization/locale_dom_web.dart',
        );

        expect(source, contains("setAttribute('lang', bcp47)"));
        expect(source, contains("setAttribute('dir', isRtl ? 'rtl' : 'ltr')"));
      },
    );
  });

  group('Feature 08: 15-Language Desktop Installer', () {
    test(
      'scripts/noesis_setup.iss enables ShowLanguageDialog and UI language detection',
      () {
        final iss = LocalizationTestHelpers.readProjectFile(
          'scripts/noesis_setup.iss',
        );

        expect(iss, contains('ShowLanguageDialog=yes'));
        expect(iss, contains('LanguageDetectionMethod=uilanguage'));
      },
    );

    test(
      'scripts/noesis_setup.iss [Languages] declares all 15 supported installer languages',
      () {
        final iss = LocalizationTestHelpers.readProjectFile(
          'scripts/noesis_setup.iss',
        );

        final languagesSectionMatch = RegExp(
          r'\[Languages\]([\s\S]*?)(?:\r?\n\[|$)',
        ).firstMatch(iss);
        expect(languagesSectionMatch, isNotNull);

        final entries = RegExp(
          r'Name:\s*"([^"]+)";\s*MessagesFile:\s*"([^"]+)"',
        ).allMatches(languagesSectionMatch!.group(1)!).toList();

        expect(entries, hasLength(15));
        final names = entries.map((m) => m.group(1)!).toList();

        const expectedNames = <String>[
          'brazilianportuguese',
          'english',
          'spanish',
          'japanese',
          'chinesesimplified',
          'korean',
          'vietnamese',
          'indonesian',
          'french',
          'german',
          'italian',
          'dutch',
          'russian',
          'arabic',
          'portuguese',
        ];
        expect(names, equals(expectedNames));
      },
    );

    test(
      'all custom .isl files referenced by noesis_setup.iss exist under scripts/isl/',
      () {
        final iss = LocalizationTestHelpers.readProjectFile(
          'scripts/noesis_setup.iss',
        );
        final root = LocalizationTestHelpers.projectRoot();

        final entries = RegExp(
          r'Name:\s*"([^"]+)";\s*MessagesFile:\s*"([^"]+)"',
        ).allMatches(iss).toList();

        final customFiles = entries
            .map((m) => m.group(2)!)
            .where((path) => !path.startsWith('compiler:'))
            .toList();

        expect(
          customFiles,
          equals(<String>[
            r'isl\ChineseSimplified.isl',
            r'isl\Vietnamese.isl',
            r'isl\Indonesian.isl',
          ]),
        );

        for (final rel in customFiles) {
          final normalized = rel.replaceAll('\\', Platform.pathSeparator);
          final file = File(
            '${root.path}${Platform.pathSeparator}scripts${Platform.pathSeparator}$normalized',
          );
          expect(file.existsSync(), isTrue, reason: 'Missing $rel');
          expect(file.lengthSync(), greaterThan(1000), reason: 'Empty $rel');
        }
      },
    );

    test(
      'custom .isl files are valid UTF-8 with [LangOptions] and [Messages] headers',
      () {
        const customIslPaths = <String>[
          'scripts/isl/ChineseSimplified.isl',
          'scripts/isl/Vietnamese.isl',
          'scripts/isl/Indonesian.isl',
        ];

        for (final relPath in customIslPaths) {
          final content = LocalizationTestHelpers.readProjectFile(relPath);
          expect(content, contains('[LangOptions]'), reason: relPath);
          expect(content, contains('LanguageName='), reason: relPath);
          expect(content, contains('LanguageID='), reason: relPath);
          expect(content, contains('LanguageCodePage='), reason: relPath);
          expect(content, contains('[Messages]'), reason: relPath);
          expect(
            RegExp(r'^SetupAppTitle=.+$', multiLine: true).hasMatch(content),
            isTrue,
            reason: '$relPath must define SetupAppTitle',
          );
          expect(
            RegExp(r'^SetupWindowTitle=.+$', multiLine: true).hasMatch(content),
            isTrue,
            reason: '$relPath must define SetupWindowTitle',
          );
        }
      },
    );

    test(
      'installer configuration remains independent of app runtime auto-detection',
      () {
        final iss = LocalizationTestHelpers.readProjectFile(
          'scripts/noesis_setup.iss',
        );
        final localeService = LocalizationTestHelpers.readProjectFile(
          'lib/core/localization/noesis_locale_service.dart',
        );

        expect(iss, isNot(contains('[Registry]')));
        expect(iss, isNot(contains('noesis_locale_preference_v1')));
        expect(iss, isNot(contains('noesis_local_profile_v1')));

        final runSectionMatch = RegExp(
          r'\[Run\]([\s\S]*?)(?:\r?\n\[|$)',
        ).firstMatch(iss);
        expect(runSectionMatch, isNotNull);
        final runSection = runSectionMatch!.group(1)!;
        expect(runSection, contains('noesis.exe'));
        expect(runSection, isNot(contains('{language}')));
        expect(runSection, isNot(contains('Parameters:')));

        expect(localeService, isNot(contains('Inno Setup')));
        expect(localeService, isNot(contains('HKEY_')));
      },
    );
  });
}
