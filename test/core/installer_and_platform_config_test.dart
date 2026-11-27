import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, List<String>> _parseIniSections(List<String> lines) {
  final sections = <String, List<String>>{};
  var currentSection = '';
  for (final rawLine in lines) {
    final trimmed = rawLine.trim();
    if (trimmed.isEmpty || trimmed.startsWith(';')) {
      continue;
    }
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      currentSection = trimmed.substring(1, trimmed.length - 1).trim();
      sections.putIfAbsent(currentSection, () => <String>[]);
      continue;
    }
    sections.putIfAbsent(currentSection, () => <String>[]).add(trimmed);
  }
  return sections;
}

Map<String, String> _parseKeyValues(List<String> lines) {
  final result = <String, String>{};
  for (final line in lines) {
    final idx = line.indexOf('=');
    if (idx <= 0) continue;
    final key = line.substring(0, idx).trim();
    final value = line.substring(idx + 1);
    result[key] = value;
  }
  return result;
}

Directory? _findInnoSetupDir() {
  final candidates = <String>[
    if (Platform.environment['LOCALAPPDATA'] != null)
      '${Platform.environment['LOCALAPPDATA']}\\Programs\\Inno Setup 6',
    if (Platform.environment['ProgramFiles(x86)'] != null)
      '${Platform.environment['ProgramFiles(x86)']}\\Inno Setup 6',
    if (Platform.environment['ProgramFiles'] != null)
      '${Platform.environment['ProgramFiles']}\\Inno Setup 6',
  ];
  for (final path in candidates) {
    final dir = Directory(path);
    if (dir.existsSync() && File('${dir.path}\\Default.isl').existsSync()) {
      return dir;
    }
  }
  return null;
}

List<String> _extractTokens(String value) {
  final matches = RegExp(
    r'%[1-9]|\[name(?:/ver)?\]|\[gb\]|\[mb\]',
  ).allMatches(value);
  final tokens = matches.map((m) => m.group(0)!).toList()..sort();
  return tokens;
}

void main() {
  group('M2 Desktop Installer (scripts/noesis_setup.iss & scripts/isl)', () {
    const expectedLanguages = <String, String>{
      'brazilianportuguese': r'compiler:Languages\BrazilianPortuguese.isl',
      'english': 'compiler:Default.isl',
      'spanish': r'compiler:Languages\Spanish.isl',
      'japanese': r'compiler:Languages\Japanese.isl',
      'chinesesimplified': r'isl\ChineseSimplified.isl',
      'korean': r'compiler:Languages\Korean.isl',
      'vietnamese': r'isl\Vietnamese.isl',
      'indonesian': r'isl\Indonesian.isl',
      'french': r'compiler:Languages\French.isl',
      'german': r'compiler:Languages\German.isl',
      'italian': r'compiler:Languages\Italian.isl',
      'dutch': r'compiler:Languages\Dutch.isl',
      'russian': r'compiler:Languages\Russian.isl',
      'arabic': r'compiler:Languages\Arabic.isl',
      'portuguese': r'compiler:Languages\Portuguese.isl',
    };

    const expectedCustomIslSpecs = <String, ({String langId, String codePage, List<String> forbiddenLeaks})>{
      'ChineseSimplified.isl': (
        langId: r'$0804',
        codePage: '936',
        forbiddenLeaks: <String>[
          'Create a &desktop',
          'Launch %1',
          'Additional shortcuts:',
          'Área de trabalho',
          'Executar',
        ],
      ),
      'Vietnamese.isl': (
        langId: r'$042A',
        codePage: '1258',
        forbiddenLeaks: <String>[
          'Create a &desktop',
          'Launch %1',
          'Additional shortcuts:',
          'Área de trabalho',
          'Executar',
        ],
      ),
      'Indonesian.isl': (
        langId: r'$0421',
        codePage: '1252',
        forbiddenLeaks: <String>[
          'Create a &desktop',
          'Launch %1',
          'Additional shortcuts:',
          'Área de trabalho',
          'Executar',
        ],
      ),
    };

    const requiredCustomMessageKeys = <String>[
      'NameAndVersion',
      'AdditionalIcons',
      'CreateDesktopIcon',
      'CreateQuickLaunchIcon',
      'ProgramOnTheWeb',
      'UninstallProgram',
      'LaunchProgram',
      'AssocFileExtension',
      'AssocingFileExtension',
      'AutoStartProgramGroupDescription',
      'AutoStartProgram',
      'AddonHostProgramNotFound',
    ];

    late String issContent;
    late Map<String, List<String>> issSections;

    setUpAll(() {
      final issFile = File('scripts/noesis_setup.iss');
      expect(issFile.existsSync(), isTrue, reason: 'scripts/noesis_setup.iss must exist');
      issContent = issFile.readAsStringSync();
      issSections = _parseIniSections(const LineSplitter().convert(issContent));
    });

    test('legacy scripts/installer_languages directory is removed', () {
      expect(
        Directory('scripts/installer_languages').existsSync(),
        isFalse,
        reason: 'Custom .isl files must live under scripts/isl/, not scripts/installer_languages/',
      );
    });

    test('Setup section enables ShowLanguageDialog and uses neutral English VersionInfoDescription', () {
      final setupMap = _parseKeyValues(issSections['Setup'] ?? const <String>[]);
      expect(setupMap['ShowLanguageDialog'], equals('yes'));

      final desc = setupMap['VersionInfoDescription'];
      expect(desc, equals('Noesis Windows Desktop Installer (x64)'));
      expect(desc, isNot(contains('{cm:')));
      expect(desc!.toLowerCase(), isNot(contains('instalador')));
      expect(desc.toLowerCase(), isNot(contains('oficial')));
    });

    test('Languages section declares all 15 Aster languages and every referenced .isl file exists', () {
      final langLines = issSections['Languages'] ?? const <String>[];
      expect(langLines.length, equals(15));

      final parsedLanguages = <String, String>{};
      final lineRegex = RegExp(r'^Name:\s*"([^"]+)";\s*MessagesFile:\s*"([^"]+)"$');
      for (final line in langLines) {
        final match = lineRegex.firstMatch(line);
        expect(match, isNotNull, reason: 'Invalid [Languages] line: $line');
        parsedLanguages[match!.group(1)!] = match.group(2)!;
      }

      expect(parsedLanguages.keys.toList(), equals(expectedLanguages.keys.toList()));
      for (final entry in expectedLanguages.entries) {
        expect(parsedLanguages[entry.key], equals(entry.value));
      }

      final innoDir = _findInnoSetupDir();
      for (final messagesFile in parsedLanguages.values) {
        if (messagesFile.startsWith('compiler:')) {
          if (innoDir != null) {
            final relativePath = messagesFile
                .substring('compiler:'.length)
                .replaceAll(r'\', Platform.pathSeparator);
            final resolved = File('${innoDir.path}${Platform.pathSeparator}$relativePath');
            expect(
              resolved.existsSync(),
              isTrue,
              reason: 'Built-in Inno Setup file missing: ${resolved.path}',
            );
          }
        } else {
          final normalized = messagesFile.replaceAll(r'\', '/');
          final localFile = File('scripts/$normalized');
          expect(
            localFile.existsSync(),
            isTrue,
            reason: 'Custom .isl file missing: ${localFile.path}',
          );
        }
      }
    });

    test('R4 Independence: no Registry, INI, Code locale injection, or locale CLI args in Icons/Run', () {
      expect(issSections.containsKey('Registry'), isFalse);
      expect(issSections.containsKey('INI'), isFalse);
      expect(issSections.containsKey('Code'), isFalse);

      final iconsAndRun = <String>[
        ...(issSections['Icons'] ?? const <String>[]),
        ...(issSections['Run'] ?? const <String>[]),
        ...(issSections['Files'] ?? const <String>[]),
      ];
      for (final line in iconsAndRun) {
        final lower = line.toLowerCase();
        expect(lower, isNot(contains('--locale')));
        expect(lower, isNot(contains('--lang')));
        expect(lower, isNot(contains('{language}')));
      }
    });

    for (final entry in expectedCustomIslSpecs.entries) {
      test('scripts/isl/${entry.key} is BOM-less UTF-8 with valid LangOptions, 281 Messages, and 12 CustomMessages', () {
        final file = File('scripts/isl/${entry.key}');
        expect(file.existsSync(), isTrue);

        final bytes = file.readAsBytesSync();
        expect(bytes.length, greaterThan(1000));
        final hasBom = bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF;
        expect(hasBom, isFalse, reason: '${entry.key} must be UTF-8 without BOM');

        final decoded = utf8.decode(bytes);
        final sections = _parseIniSections(const LineSplitter().convert(decoded));

        final langOptions = _parseKeyValues(sections['LangOptions'] ?? const <String>[]);
        expect(langOptions['LanguageName'], isNotNull);
        expect(langOptions['LanguageName']!.trim(), isNotEmpty);
        expect(langOptions['LanguageID'], equals(entry.value.langId));
        expect(langOptions['LanguageCodePage'], equals(entry.value.codePage));
        expect(int.tryParse(langOptions['LanguageCodePage'] ?? '0'), greaterThan(0));

        final messages = _parseKeyValues(sections['Messages'] ?? const <String>[]);
        expect(messages.length, equals(281));
        expect(messages['SetupAppTitle']?.trim(), isNotEmpty);
        expect(messages['SelectLanguageTitle']?.trim(), isNotEmpty);
        expect(messages['FileNotInDir2'], allOf(contains('%1'), contains('%2')));
        expect(messages['LastErrorMessage'], allOf(contains('%1'), contains('%2'), contains('%3')));

        final customMessages = _parseKeyValues(sections['CustomMessages'] ?? const <String>[]);
        expect(customMessages.length, equals(requiredCustomMessageKeys.length));
        for (final cmKey in requiredCustomMessageKeys) {
          expect(
            customMessages[cmKey]?.trim(),
            isNotEmpty,
            reason: '${entry.key} missing CustomMessage $cmKey',
          );
        }

        for (final leak in entry.value.forbiddenLeaks) {
          expect(decoded, isNot(contains(leak)));
        }

        final innoDir = _findInnoSetupDir();
        if (innoDir != null) {
          final defaultText = File('${innoDir.path}${Platform.pathSeparator}Default.isl').readAsStringSync();
          final defaultSections = _parseIniSections(const LineSplitter().convert(defaultText));
          final defaultMessages = _parseKeyValues(defaultSections['Messages'] ?? const <String>[]);
          final defaultCustom = _parseKeyValues(defaultSections['CustomMessages'] ?? const <String>[]);

          expect(messages.keys.toSet(), equals(defaultMessages.keys.toSet()));
          expect(customMessages.keys.toSet(), equals(defaultCustom.keys.toSet()));

          for (final msgEntry in defaultMessages.entries) {
            final defaultTokens = _extractTokens(msgEntry.value);
            final translatedValue = messages[msgEntry.key]!;
            final translatedTokens = _extractTokens(translatedValue);
            expect(
              translatedTokens,
              equals(defaultTokens),
              reason: '${entry.key} placeholder mismatch for Messages.${msgEntry.key}',
            );
            if (msgEntry.value.trim().isNotEmpty) {
              expect(
                translatedValue.trim(),
                isNotEmpty,
                reason: '${entry.key} has empty translation for Messages.${msgEntry.key}',
              );
            }
          }
        }
      });
    }
  });

  group('M2 Multiplatform Native Configs', () {
    test('AndroidManifest.xml enables RTL support and preserves configChanges, INTERNET, and OAuth intent-filter', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);
      final manifest = manifestFile.readAsStringSync();

      final appTagMatch = RegExp(r'<application\b[^>]*>', dotAll: true).firstMatch(manifest);
      expect(appTagMatch, isNotNull);
      expect(appTagMatch!.group(0), contains('android:supportsRtl="true"'));

      final configChangesMatch = RegExp(r'android:configChanges="([^"]+)"').firstMatch(manifest);
      expect(configChangesMatch, isNotNull);
      final configFlags = configChangesMatch!.group(1)!.split('|');
      expect(configFlags, containsAll(<String>['locale', 'layoutDirection']));

      expect(manifest, contains('android.permission.INTERNET'));
      expect(manifest, contains('android:scheme="io.supabase.noesis"'));
      expect(manifest, contains('android:host="login-callback"'));
    });

    test('ios/Runner/Info.plist is valid plist XML with exact 15 BCP-47 CFBundleLocalizations', () {
      final plistFile = File('ios/Runner/Info.plist');
      expect(plistFile.existsSync(), isTrue);
      final plist = plistFile.readAsStringSync();

      expect(plist, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(plist, contains('<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'));
      expect(plist, contains('<plist version="1.0">'));
      expect(plist, contains('</plist>'));
      expect(RegExp(r'<dict>').allMatches(plist).length, equals(RegExp(r'</dict>').allMatches(plist).length));
      expect(RegExp(r'<array>').allMatches(plist).length, equals(RegExp(r'</array>').allMatches(plist).length));

      final localizationsMatch = RegExp(
        r'<key>CFBundleLocalizations</key>\s*<array>(.*?)</array>',
        dotAll: true,
      ).firstMatch(plist);
      expect(localizationsMatch, isNotNull, reason: 'CFBundleLocalizations <array> must be present');

      final locales = RegExp(r'<string>([^<]+)</string>')
          .allMatches(localizationsMatch!.group(1)!)
          .map((m) => m.group(1)!.trim())
          .toList();

      const expectedBcp47 = <String>[
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
      expect(locales.length, equals(15));
      expect(locales.toSet().length, equals(15));
      expect(locales, equals(expectedBcp47));
      expect(locales.any((l) => l.contains('_')), isFalse);
    });

    test('web/index.html has lang attribute, neutral English metadata, 15-lang pre-bootstrap resolver, and preserved bootstrap markers', () {
      final indexFile = File('web/index.html');
      expect(indexFile.existsSync(), isTrue);
      final html = indexFile.readAsStringSync();

      expect(html, contains('<html lang="en">'));
      expect(html, contains('<meta name="description" content="Noesis — Cognitive OS & AI Study Engine of the Aster ecosystem.">'));
      expect(html.toLowerCase(), isNot(contains('do ecossistema aster')));
      expect(html.toLowerCase(), isNot(contains('aceita http://')));

      expect(html, contains("window.location.hostname === 'localhost'"));
      expect(html, contains('document.documentElement.lang'));
      expect(html, contains("'pt-PT'"));
      expect(html, contains("'pt-BR'"));
      expect(html, contains("var resolved = 'en'"));
      for (final code in const <String>[
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
      ]) {
        expect(html, contains("'$code'"));
      }

      expect(html, contains('<base href="\$FLUTTER_BASE_HREF">'));
      expect(html, contains('<title>Noesis</title>'));
      expect(html, contains('<link rel="manifest" href="manifest.json">'));
      expect(html, contains('<script src="flutter_bootstrap.js" async></script>'));
    });

    test('web/manifest.json is valid JSON with lang=en and required PWA metadata', () {
      final manifestFile = File('web/manifest.json');
      expect(manifestFile.existsSync(), isTrue);
      final decoded = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;

      expect(decoded['lang'], equals('en'));
      expect(decoded['name'], equals('Noesis'));
      expect(decoded['short_name'], equals('Noesis'));
      expect(decoded['display'], equals('standalone'));
      expect(decoded['background_color'], isA<String>());
      expect(decoded['theme_color'], isA<String>());
      expect(decoded['description'], equals('Noesis - Cognitive OS & AI Study Engine'));
    });
  });
}
