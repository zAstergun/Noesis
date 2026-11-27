import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../features/quizzes/data/saved_exams_store_stub.dart'
    if (dart.library.io) '../../features/quizzes/data/saved_exams_store_io.dart'
    if (dart.library.js_interop) '../../features/quizzes/data/saved_exams_store_web.dart'
    as local_store;
import '../supabase_service.dart';
import 'locale_dom_stub.dart'
    if (dart.library.js_interop) 'locale_dom_web.dart' as locale_dom;

/// Metadados de cada um dos 15 idiomas suportados no ecossistema Aster / Noesis.
class NoesisLanguageOption {
  const NoesisLanguageOption({
    required this.code,
    required this.locale,
    required this.intlLocale,
    required this.bcp47,
    required this.nativeName,
    required this.regionKey,
    required this.aiLanguageName,
    this.isRtl = false,
  });

  final String code;
  final Locale locale;
  final String intlLocale;
  final String bcp47;
  final String nativeName;
  final String regionKey;
  final String aiLanguageName;
  final bool isRtl;
}

/// Origem da seleção de idioma ativa para respeitar a precedência:
/// manual > perfil salvo > detecção automática do dispositivo/navegador (fallback 'en').
enum NoesisLocaleSource {
  auto,
  profile,
  manual,
}

/// Serviço central de internacionalização, detecção automática do sistema/navegador,
/// persistência local + perfil Aster e suporte RTL (Árabe) do Noesis.
class NoesisLocaleService {
  NoesisLocaleService._();

  static const String _preferenceStorageKey = 'noesis_locale_preference_v1';
  static const String _localProfileStorageKey = 'noesis_local_profile_v1';
  static const String defaultFallbackCode = 'en';

  static const List<NoesisLanguageOption> supportedLanguages = [
    NoesisLanguageOption(
      code: 'br',
      locale: Locale('pt', 'BR'),
      intlLocale: 'pt_BR',
      bcp47: 'pt-BR',
      nativeName: 'Português',
      regionKey: 'Brasil',
      aiLanguageName: 'Brazilian Portuguese (pt-BR)',
    ),
    NoesisLanguageOption(
      code: 'en',
      locale: Locale('en', 'GB'),
      intlLocale: 'en_GB',
      bcp47: 'en-GB',
      nativeName: 'English',
      regionKey: 'United Kingdom / Global',
      aiLanguageName: 'English',
    ),
    NoesisLanguageOption(
      code: 'es',
      locale: Locale('es', 'ES'),
      intlLocale: 'es_ES',
      bcp47: 'es-ES',
      nativeName: 'Español',
      regionKey: 'España / América Latina',
      aiLanguageName: 'Spanish',
    ),
    NoesisLanguageOption(
      code: 'jp',
      locale: Locale('ja', 'JP'),
      intlLocale: 'ja_JP',
      bcp47: 'ja-JP',
      nativeName: '日本語',
      regionKey: 'Japão',
      aiLanguageName: 'Japanese',
    ),
    NoesisLanguageOption(
      code: 'cn',
      locale: Locale('zh', 'CN'),
      intlLocale: 'zh_CN',
      bcp47: 'zh-CN',
      nativeName: '中文',
      regionKey: 'China',
      aiLanguageName: 'Simplified Chinese',
    ),
    NoesisLanguageOption(
      code: 'kr',
      locale: Locale('ko', 'KR'),
      intlLocale: 'ko_KR',
      bcp47: 'ko-KR',
      nativeName: '한국어',
      regionKey: 'Coreia do Sul',
      aiLanguageName: 'Korean',
    ),
    NoesisLanguageOption(
      code: 'vn',
      locale: Locale('vi', 'VN'),
      intlLocale: 'vi_VN',
      bcp47: 'vi-VN',
      nativeName: 'Tiếng Việt',
      regionKey: 'Vietnã',
      aiLanguageName: 'Vietnamese',
    ),
    NoesisLanguageOption(
      code: 'id',
      locale: Locale('id', 'ID'),
      intlLocale: 'id_ID',
      bcp47: 'id-ID',
      nativeName: 'Bahasa Indonesia',
      regionKey: 'Indonésia',
      aiLanguageName: 'Indonesian',
    ),
    NoesisLanguageOption(
      code: 'fr',
      locale: Locale('fr', 'FR'),
      intlLocale: 'fr_FR',
      bcp47: 'fr-FR',
      nativeName: 'Français',
      regionKey: 'França',
      aiLanguageName: 'French',
    ),
    NoesisLanguageOption(
      code: 'de',
      locale: Locale('de', 'DE'),
      intlLocale: 'de_DE',
      bcp47: 'de-DE',
      nativeName: 'Deutsch',
      regionKey: 'Alemanha',
      aiLanguageName: 'German',
    ),
    NoesisLanguageOption(
      code: 'it',
      locale: Locale('it', 'IT'),
      intlLocale: 'it_IT',
      bcp47: 'it-IT',
      nativeName: 'Italiano',
      regionKey: 'Itália',
      aiLanguageName: 'Italian',
    ),
    NoesisLanguageOption(
      code: 'nl',
      locale: Locale('nl', 'NL'),
      intlLocale: 'nl_NL',
      bcp47: 'nl-NL',
      nativeName: 'Nederlands',
      regionKey: 'Holanda',
      aiLanguageName: 'Dutch',
    ),
    NoesisLanguageOption(
      code: 'ru',
      locale: Locale('ru', 'RU'),
      intlLocale: 'ru_RU',
      bcp47: 'ru-RU',
      nativeName: 'Русский',
      regionKey: 'Rússia',
      aiLanguageName: 'Russian',
    ),
    NoesisLanguageOption(
      code: 'ar',
      locale: Locale('ar', 'SA'),
      intlLocale: 'ar_SA',
      bcp47: 'ar-SA',
      nativeName: 'العربية',
      regionKey: 'Mundo Árabe',
      aiLanguageName: 'Arabic',
      isRtl: true,
    ),
    NoesisLanguageOption(
      code: 'pt',
      locale: Locale('pt', 'PT'),
      intlLocale: 'pt_PT',
      bcp47: 'pt-PT',
      nativeName: 'Português',
      regionKey: 'Portugal',
      aiLanguageName: 'European Portuguese (pt-PT)',
    ),
  ];

  static final Map<String, NoesisLanguageOption> _byCode = {
    for (final lang in supportedLanguages) lang.code: lang,
  };

  static List<Locale> get supportedFlutterLocales =>
      supportedLanguages.map((e) => e.locale).toList(growable: false);

  static final ValueNotifier<String> currentCodeNotifier =
      ValueNotifier<String>('br');
  static final ValueNotifier<Locale> localeNotifier =
      ValueNotifier<Locale>(const Locale('pt', 'BR'));

  static NoesisLocaleSource _source = NoesisLocaleSource.auto;
  static bool _initialized = false;
  static final Set<String> _initializedIntlLocales = <String>{};

  @visibleForTesting
  static List<Locale>? platformLocalesOverrideForTesting;

  static NoesisLocaleSource get selectionSource => _source;
  static String get currentCode => currentCodeNotifier.value;
  static Locale get currentLocale => localeNotifier.value;
  static NoesisLanguageOption get currentLanguage =>
      _byCode[currentCode] ?? _byCode[defaultFallbackCode]!;
  static bool get isRtl => currentLanguage.isRtl;
  static TextDirection get textDirection =>
      isRtl ? TextDirection.rtl : TextDirection.ltr;
  static String get intlLocale => currentLanguage.intlLocale;
  static String get bcp47 => currentLanguage.bcp47;
  static String get activeAiLanguageName => currentLanguage.aiLanguageName;

  static bool isSupportedCode(String? code) {
    if (code == null) return false;
    return _byCode.containsKey(code.trim().toLowerCase());
  }

  static NoesisLanguageOption optionForCode(String? code) {
    final normalized = normalizeCode(code);
    return _byCode[normalized] ?? _byCode[defaultFallbackCode]!;
  }

  /// Normaliza um código interno ou tag BCP-47/POSIX para um dos 15 códigos suportados.
  static String? normalizeCode(String? raw) {
    if (raw == null) return null;
    final clean = raw.trim().toLowerCase().replaceAll('_', '-');
    if (clean.isEmpty) return null;
    if (_byCode.containsKey(clean)) return clean;

    final parts = clean.split('-');
    final lang = parts.first;
    final region = parts.length > 1 ? parts[1].toUpperCase() : '';
    final last = parts.last.toUpperCase();

    switch (lang) {
      case 'pt':
        return (region == 'PT' || last == 'PT') ? 'pt' : 'br';
      case 'en':
        return 'en';
      case 'es':
        return 'es';
      case 'ja':
      case 'jp':
        return 'jp';
      case 'zh':
      case 'cn':
        return 'cn';
      case 'ko':
      case 'kr':
        return 'kr';
      case 'vi':
      case 'vn':
        return 'vn';
      case 'id':
      case 'in':
        return 'id';
      case 'fr':
        return 'fr';
      case 'de':
        return 'de';
      case 'it':
        return 'it';
      case 'nl':
        return 'nl';
      case 'ru':
        return 'ru';
      case 'ar':
        return 'ar';
      default:
        return null;
    }
  }

  /// Detecta o código de idioma a partir da lista ordenada de locales do dispositivo/navegador.
  /// Usa Inglês ('en') como fallback caso nenhum dos 15 idiomas seja compatível.
  static String detectLanguageCodeFromLocales(List<Locale> locales) {
    for (final locale in locales) {
      if (locale.languageCode.trim().toLowerCase() == 'pt') {
        final country = (locale.countryCode ?? '').trim().toUpperCase();
        return country == 'PT' ? 'pt' : 'br';
      }
      final tag = [
        locale.languageCode,
        if (locale.scriptCode != null && locale.scriptCode!.isNotEmpty)
          locale.scriptCode!,
        if (locale.countryCode != null && locale.countryCode!.isNotEmpty)
          locale.countryCode!,
      ].join('-');
      final mapped = normalizeCode(tag);
      if (mapped != null) return mapped;
    }
    return defaultFallbackCode;
  }

  static List<Locale> _effectivePlatformLocales() {
    if (platformLocalesOverrideForTesting != null) {
      return platformLocalesOverrideForTesting!;
    }
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    if (dispatcher.locales.isNotEmpty) {
      return dispatcher.locales;
    }
    return <Locale>[dispatcher.locale];
  }

  static Future<void> ensureDateFormattingInitialized([String? intlTag]) async {
    final tag = intlTag ?? intlLocale;
    if (_initializedIntlLocales.contains(tag)) return;
    try {
      await initializeDateFormatting(tag, null);
      _initializedIntlLocales.add(tag);
    } catch (_) {
      try {
        await initializeDateFormatting('en_GB', null);
        _initializedIntlLocales.add('en_GB');
      } catch (_) {}
    }
  }

  static Future<void> _ensureAllDateFormattingsInitialized() async {
    await Future.wait(
      supportedLanguages.map((l) => ensureDateFormattingInitialized(l.intlLocale)),
    );
  }

  static Future<void> ensureInitialized({bool forceReload = false}) async {
    if (_initialized && !forceReload) return;

    // 1. Verificar escolha manual salva localmente
    final savedPref = await _readLocalPreference();
    if (savedPref != null &&
        savedPref.source == NoesisLocaleSource.manual &&
        isSupportedCode(savedPref.code)) {
      await _applyCode(savedPref.code, source: NoesisLocaleSource.manual);
      await _ensureAllDateFormattingsInitialized();
      _initialized = true;
      return;
    }

    // 2. Verificar idioma salvo no perfil (notificador ou cache local)
    final profileLang = extractLanguageFromProfile(
          SupabaseService.userProfileNotifier.value,
        ) ??
        await _readProfileLanguageFromLocalCache();
    if (profileLang != null && isSupportedCode(profileLang)) {
      await _applyCode(profileLang, source: NoesisLocaleSource.profile);
      await _ensureAllDateFormattingsInitialized();
      _initialized = true;
      return;
    }

    // 3. Caso contrário, detectar automaticamente do sistema/navegador (fallback 'en')
    final detected = detectLanguageCodeFromLocales(_effectivePlatformLocales());
    await _applyCode(detected, source: NoesisLocaleSource.auto);
    await _ensureAllDateFormattingsInitialized();
    _initialized = true;
  }

  static String? extractLanguageFromProfile(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    final direct = normalizeCode(profile['noesis_language']?.toString());
    if (direct != null) return direct;
    final stats = profile['stats'];
    if (stats is Map) {
      final fromStats = normalizeCode(stats['noesis_language']?.toString());
      if (fromStats != null) return fromStats;
    }
    return null;
  }

  static Future<void> setLanguage(
    String code, {
    bool persistManual = true,
    bool syncProfile = true,
  }) async {
    final normalized = normalizeCode(code) ?? defaultFallbackCode;
    final source = persistManual
        ? NoesisLocaleSource.manual
        : NoesisLocaleSource.profile;
    await _applyCode(normalized, source: source);

    if (persistManual) {
      await _writeLocalPreference(normalized, NoesisLocaleSource.manual);
    }
    if (syncProfile) {
      unawaited(SupabaseService.saveUserLanguagePreference(normalized));
    }
  }

  static Future<void> applyProfileLanguageIfNoManualOverride(
    Map<String, dynamic>? profile,
  ) async {
    if (_source == NoesisLocaleSource.manual) return;
    final savedPref = await _readLocalPreference();
    if (savedPref != null && savedPref.source == NoesisLocaleSource.manual) {
      return;
    }
    final profileCode = extractLanguageFromProfile(profile);
    if (profileCode != null && isSupportedCode(profileCode)) {
      await _applyCode(profileCode, source: NoesisLocaleSource.profile);
      await _writeLocalPreference(profileCode, NoesisLocaleSource.profile);
    }
  }

  static Future<void> handlePlatformLocalesChanged() async {
    if (_source != NoesisLocaleSource.auto) return;
    final detected = detectLanguageCodeFromLocales(_effectivePlatformLocales());
    if (detected != currentCode) {
      await _applyCode(detected, source: NoesisLocaleSource.auto);
    }
  }

  static Future<void> _applyCode(
    String code, {
    required NoesisLocaleSource source,
  }) async {
    final opt = optionForCode(code);
    _source = source;
    await ensureDateFormattingInitialized(opt.intlLocale);
    if (localeNotifier.value != opt.locale) {
      localeNotifier.value = opt.locale;
    }
    if (currentCodeNotifier.value != opt.code) {
      currentCodeNotifier.value = opt.code;
    }
    locale_dom.syncDocumentLocale(opt.bcp47, opt.isRtl);
  }

  static Future<({String code, NoesisLocaleSource source})?>
      _readLocalPreference() async {
    try {
      final raw = await local_store.readSavedExamsRaw(_preferenceStorageKey);
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final code = normalizeCode(decoded['code']?.toString());
        if (code == null) return null;
        final srcRaw = decoded['source']?.toString();
        final src = srcRaw == 'manual'
            ? NoesisLocaleSource.manual
            : (srcRaw == 'profile'
                ? NoesisLocaleSource.profile
                : NoesisLocaleSource.auto);
        return (code: code, source: src);
      }
    } catch (_) {}
    return null;
  }

  static Future<void> _writeLocalPreference(
    String code,
    NoesisLocaleSource source,
  ) async {
    try {
      await local_store.writeSavedExamsRaw(
        _preferenceStorageKey,
        jsonEncode({'code': code, 'source': source.name}),
      );
    } catch (_) {}
  }

  static Future<String?> _readProfileLanguageFromLocalCache() async {
    try {
      final raw = await local_store.readSavedExamsRaw(_localProfileStorageKey);
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return extractLanguageFromProfile(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return null;
  }

  @visibleForTesting
  static Future<void> resetForTesting({
    String? initialCode,
    NoesisLocaleSource initialSource = NoesisLocaleSource.auto,
    List<Locale>? platformLocalesOverride,
    bool clearStoredPreference = true,
  }) async {
    _initialized = false;
    platformLocalesOverrideForTesting = platformLocalesOverride;
    if (clearStoredPreference) {
      try {
        await local_store.writeSavedExamsRaw(_preferenceStorageKey, '');
      } catch (_) {}
    }
    if (initialCode != null) {
      final opt = optionForCode(initialCode);
      _source = initialSource;
      localeNotifier.value = opt.locale;
      currentCodeNotifier.value = opt.code;
      await ensureDateFormattingInitialized(opt.intlLocale);
    } else {
      await ensureInitialized(forceReload: true);
    }
  }
}
