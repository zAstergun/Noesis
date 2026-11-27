import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/localization/noesis_l10n.dart';
import 'package:noesis/core/localization/noesis_locale_service.dart';
import 'package:noesis/core/theme.dart';
import 'package:noesis/features/flashcards/flashcards_screen.dart';
import 'package:noesis/features/settings/settings_screen.dart';
import 'package:noesis/main.dart';

import '../../harness/test_app_harness.dart';
import '../helpers/localization_test_helpers.dart';

void main() {
  setUpAll(() => LocalizationTestHelpers.setUpSuite());

  setUp(() => LocalizationTestHelpers.resetState());

  tearDown(() => LocalizationTestHelpers.resetState());

  group('F15 — Arabic (ar) RTL Mirroring & Typography', () {
    testWidgets(
      'F15-T1: NoesisApp resolves Directionality = TextDirection.rtl when Arabic (ar) is active',
      (tester) async {
        await LocalizationTestHelpers.resetState(initialCode: 'ar');
        await LocalizationTestHelpers.pumpNoesisApp(tester);

        expect(NoesisLocaleService.isRtl, isTrue);
        expect(NoesisLocaleService.textDirection, equals(TextDirection.rtl));

        final rootFinder = find.byType(RootScreen);
        expect(rootFinder, findsOneWidget);
        expect(
          Directionality.of(tester.element(rootFinder)),
          equals(TextDirection.rtl),
        );
      },
    );

    testWidgets(
      'F15-T2: RootScreen and DesktopTopBar mirror horizontal coordinates in Arabic RTL vs English LTR',
      (tester) async {
        await LocalizationTestHelpers.pumpScreen(
          tester,
          const RootScreen(),
          screenSize: const Size(1280, 800),
          locale: const Locale('en', 'GB'),
        );
        await TestAppHarness.drainAsync(tester);

        final ltrSidebarDx = tester
            .getTopLeft(find.byKey(const ValueKey('sidebar_expanded_panel')))
            .dx;
        final ltrBellDx = tester
            .getCenter(find.byKey(const Key('notifications_bell_button')))
            .dx;

        expect(ltrSidebarDx, lessThan(100));
        expect(ltrBellDx, greaterThan(800));

        await LocalizationTestHelpers.resetState(initialCode: 'ar');
        await LocalizationTestHelpers.pumpScreen(
          tester,
          const RootScreen(),
          screenSize: const Size(1280, 800),
          locale: const Locale('ar', 'SA'),
        );
        await TestAppHarness.drainAsync(tester);

        final rtlSidebarDx = tester
            .getTopLeft(find.byKey(const ValueKey('sidebar_expanded_panel')))
            .dx;
        final rtlBellDx = tester
            .getCenter(find.byKey(const Key('notifications_bell_button')))
            .dx;

        expect(
          rtlSidebarDx,
          greaterThan(800),
          reason: 'Sidebar panel should mirror to the right edge in Arabic RTL',
        );
        expect(
          rtlBellDx,
          lessThan(400),
          reason: 'Top-bar notifications bell should mirror to the left side in Arabic RTL',
        );
      },
    );

    testWidgets(
      'F15-T3: SettingsScreen and FlashcardsScreen render Arabic glyphs cleanly in RTL',
      (tester) async {
        await LocalizationTestHelpers.pumpScreen(
          tester,
          const SettingsScreen(),
          locale: const Locale('ar', 'SA'),
        );
        await TestAppHarness.drainAsync(tester);

        final settingsFinder = find.byType(SettingsScreen);
        expect(settingsFinder, findsOneWidget);
        expect(
          Directionality.of(tester.element(settingsFinder)),
          equals(TextDirection.rtl),
        );
        expect(find.textContaining('العربية'), findsWidgets);

        await LocalizationTestHelpers.pumpScreen(
          tester,
          const FlashcardsScreen(),
          locale: const Locale('ar', 'SA'),
        );
        await TestAppHarness.drainAsync(tester);

        final flashcardsFinder = find.byType(FlashcardsScreen);
        expect(flashcardsFinder, findsOneWidget);
        expect(
          Directionality.of(tester.element(flashcardsFinder)),
          equals(TextDirection.rtl),
        );
      },
    );

    test(
      'F15-T4: Static scan confirms zero unconditional TextDirection.ltr overrides in flashcards_screen.dart and main.dart',
      () {
        final targets = <String>[
          'lib/features/flashcards/flashcards_screen.dart',
          'lib/main.dart',
        ];
        final allowedPattern = RegExp(
          r'(\?\?\s*TextDirection\.ltr|:\s*TextDirection\.ltr)',
        );

        for (final path in targets) {
          final lines = LocalizationTestHelpers.readProjectFile(path).split('\n');
          final violations = <String>[];
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            if (line.contains('TextDirection.ltr') &&
                !allowedPattern.hasMatch(line)) {
              violations.add('L${i + 1}: ${line.trim()}');
            }
          }
          expect(
            violations,
            isEmpty,
            reason: 'Unconditional TextDirection.ltr overrides in $path: $violations',
          );
        }
      },
    );

    testWidgets(
      'F15-T5: Theme configures multi-script fontFamilyFallback and renders Arabic/CJK/Cyrillic scripts',
      (tester) async {
        final themeSource = LocalizationTestHelpers.readProjectFile(
          'lib/core/theme.dart',
        );
        expect(themeSource, contains('fontFamilyFallback'));

        final lightFallback =
            AsterTheme.softClayTheme.textTheme.bodyMedium?.fontFamilyFallback;
        final darkFallback =
            AsterTheme.darkTheme.textTheme.bodyMedium?.fontFamilyFallback;
        expect(lightFallback, isNotNull);
        expect(lightFallback, isNotEmpty);
        expect(darkFallback, isNotNull);
        expect(darkFallback, isNotEmpty);

        const samples = <({Locale locale, String text})>[
          (locale: Locale('ar', 'SA'), text: 'العربية · لوحة الدراسة'),
          (locale: Locale('ja', 'JP'), text: '日本語 · 学習ダッシュボード'),
          (locale: Locale('zh', 'CN'), text: '中文 · 学习仪表盘'),
          (locale: Locale('ko', 'KR'), text: '한국어 · 학습 대시보드'),
          (locale: Locale('ru', 'RU'), text: 'Русский · Панель обучения'),
        ];

        for (final sample in samples) {
          await LocalizationTestHelpers.pumpScreen(
            tester,
            Center(child: Text(sample.text)),
            locale: sample.locale,
          );
          expect(find.text(sample.text), findsOneWidget);
        }
      },
    );
  });

  group('F16 — Static Residue Audit & 15-Locale Parity', () {
    test(
      'F16-T1: All 15 translation files exist and NoesisL10n.translations registers non-empty maps for all 15 codes',
      () {
        final codes = LocalizationTestHelpers.all15LanguageCodes;
        expect(codes.length, equals(15));
        expect(NoesisL10n.translations.keys.toSet(), equals(codes.toSet()));

        final rootPath = LocalizationTestHelpers.projectRoot().path;
        for (final code in codes) {
          final file = File(
            '$rootPath${Platform.pathSeparator}lib${Platform.pathSeparator}core'
            '${Platform.pathSeparator}localization${Platform.pathSeparator}translations'
            '${Platform.pathSeparator}lang_$code.dart',
          );
          expect(
            file.existsSync(),
            isTrue,
            reason: 'Missing translation file: ${file.path}',
          );

          final map = NoesisL10n.translations[code];
          expect(map, isNotNull);
          expect(
            map,
            isNotEmpty,
            reason: 'Translation map for "$code" must not be empty',
          );
        }
      },
    );

    test(
      'F16-T2: 100% key parity and zero empty values across all 15 translation maps',
      () {
        final maps = LocalizationTestHelpers.parseTranslationMaps();
        final brKeys = maps['br']!.keys.toSet();
        expect(brKeys, isNotEmpty);

        for (final code in LocalizationTestHelpers.all15LanguageCodes) {
          final langMap = maps[code]!;
          final langKeys = langMap.keys.toSet();

          final missing = brKeys.difference(langKeys);
          final extra = langKeys.difference(brKeys);
          expect(
            missing,
            isEmpty,
            reason: 'Language "$code" is missing keys: ${missing.take(10)}',
          );
          expect(
            extra,
            isEmpty,
            reason: 'Language "$code" has extra keys: ${extra.take(10)}',
          );

          final emptyValues = langMap.entries
              .where((e) => e.value.trim().isEmpty)
              .map((e) => e.key)
              .toList();
          expect(
            emptyValues,
            isEmpty,
            reason: 'Language "$code" has empty translations: ${emptyValues.take(10)}',
          );
        }
      },
    );

    test(
      'F16-T3: Placeholder tokens ({name}, {count}, etc.) match identically across all 15 languages',
      () {
        final maps = LocalizationTestHelpers.parseTranslationMaps();
        final brMap = maps['br']!;
        expect(brMap, isNotEmpty);

        final tokenRegex = RegExp(r'\{[a-zA-Z0-9_]+\}');
        for (final entry in brMap.entries) {
          final expectedTokens = tokenRegex
              .allMatches(entry.value)
              .map((m) => m.group(0)!)
              .toSet();

          for (final code in LocalizationTestHelpers.all15LanguageCodes) {
            if (code == 'br') continue;
            final translated = maps[code]![entry.key] ?? '';
            final actualTokens = tokenRegex
                .allMatches(translated)
                .map((m) => m.group(0)!)
                .toSet();
            expect(
              actualTokens,
              equals(expectedTokens),
              reason:
                  'Placeholder mismatch for key "${entry.key}" in "$code": '
                  'expected $expectedTokens, got $actualTokens',
            );
          }
        }
      },
    );

    test(
      'F16-T4: Static scan finds zero hardcoded pt_BR locale strings and zero Portuguese UI residue',
      () {
        final rootPath = LocalizationTestHelpers.projectRoot().path;
        final filesToScan = <File>[
          File('$rootPath${Platform.pathSeparator}lib${Platform.pathSeparator}main.dart'),
          ...LocalizationTestHelpers.listDartFilesUnder('lib/features'),
          ...LocalizationTestHelpers.listDartFilesUnder('lib/widgets'),
          ...LocalizationTestHelpers.listDartFilesUnder('lib/core'),
        ];

        final ptBrLiteralPattern = RegExp(r'''['"]pt_BR['"]''');
        final ptBrViolations = <String>[];
        final uiResidueViolations = <String>[];

        for (final file in filesToScan) {
          final normalizedPath = file.path.replaceAll('\\', '/');
          if (normalizedPath.contains('/lib/core/localization/') ||
              normalizedPath.contains('/lib/core/l10n/') ||
              normalizedPath.endsWith('/lib/core/locale_service.dart')) {
            continue;
          }

          final source = file.readAsStringSync();
          if (ptBrLiteralPattern.hasMatch(source)) {
            ptBrViolations.add(normalizedPath);
          }

          final markers = LocalizationTestHelpers.findPortugueseUiMarkers(source);
          if (markers.isNotEmpty) {
            uiResidueViolations.add('$normalizedPath -> ${markers.take(5).join("; ")}');
          }
        }

        expect(
          ptBrViolations,
          isEmpty,
          reason: 'Hardcoded pt_BR locale literals found in: $ptBrViolations',
        );
        expect(
          uiResidueViolations,
          isEmpty,
          reason: 'Untranslated Portuguese UI markers found in: ${uiResidueViolations.take(10).toList()}',
        );
      },
    );

    test(
      'F16-T5: Project declares flutter_localizations, 38 exam blueprint assets, installer test, and 15 supported languages',
      () {
        final pubspec = LocalizationTestHelpers.readProjectFile('pubspec.yaml');
        expect(pubspec, contains('flutter_localizations:'));
        expect(
          RegExp(r'exemplos_simulados/[^\s]+/').allMatches(pubspec).length,
          equals(38),
        );

        final rootPath = LocalizationTestHelpers.projectRoot().path;
        final installerTest = File(
          '$rootPath${Platform.pathSeparator}test${Platform.pathSeparator}core'
          '${Platform.pathSeparator}installer_and_platform_config_test.dart',
        );
        expect(installerTest.existsSync(), isTrue);

        expect(NoesisLocaleService.supportedLanguages.length, equals(15));
      },
    );
  });
}
