import 'package:flutter/widgets.dart';
import 'noesis_locale_service.dart';
import 'translations/lang_ar.dart';
import 'translations/lang_br.dart';
import 'translations/lang_cn.dart';
import 'translations/lang_de.dart';
import 'translations/lang_en.dart';
import 'translations/lang_es.dart';
import 'translations/lang_fr.dart';
import 'translations/lang_id.dart';
import 'translations/lang_it.dart';
import 'translations/lang_jp.dart';
import 'translations/lang_kr.dart';
import 'translations/lang_nl.dart';
import 'translations/lang_pt.dart';
import 'translations/lang_ru.dart';
import 'translations/lang_vn.dart';

/// Escopo reativo de idioma para reconstruir qualquer widget dependente
/// imediatamente após a troca de idioma (inclusive dialogs e overlays).
class NoesisLocaleScope extends InheritedNotifier<ValueNotifier<String>> {
  const NoesisLocaleScope({
    super.key,
    required ValueNotifier<String> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static String? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<NoesisLocaleScope>()
        ?.notifier
        ?.value;
  }
}

/// Motor central de traduções do Noesis para todos os 15 idiomas suportados.
class NoesisL10n {
  NoesisL10n._();

  static const Map<String, Map<String, String>> translations = {
    'br': langBr,
    'en': langEn,
    'es': langEs,
    'jp': langJp,
    'cn': langCn,
    'kr': langKr,
    'vn': langVn,
    'id': langId,
    'fr': langFr,
    'de': langDe,
    'it': langIt,
    'nl': langNl,
    'ru': langRu,
    'ar': langAr,
    'pt': langPt,
  };

  /// Inscreve [context] no idioma ativo (via [NoesisLocaleScope] ou [Localizations]).
  static String watchCode(BuildContext context) {
    final scoped = NoesisLocaleScope.maybeOf(context);
    if (scoped != null) return scoped;
    final widgetLocale = Localizations.maybeLocaleOf(context);
    if (widgetLocale != null) {
      return NoesisLocaleService.normalizeCode(widgetLocale.toLanguageTag()) ??
          NoesisLocaleService.currentCode;
    }
    return NoesisLocaleService.currentCode;
  }

  static const String defaultRoadmapLevel = 'Intermediário';
  static const List<String> roadmapLevels = [
    'Iniciante',
    'Intermediário',
    'Avançado',
  ];

  static String tr(
    String key, [
    Map<String, Object?>? args,
    String? overrideCode,
  ]) {
    final code = overrideCode ?? NoesisLocaleService.currentCode;
    var template = translations[code]?[key] ??
        (code == 'br' ? key : translations['en']?[key]) ??
        key;
    if (args != null && args.isNotEmpty) {
      args.forEach((param, value) {
        template = template.replaceAll('{$param}', '${value ?? ''}');
      });
    }
    return template;
  }

  static String trContext(
    BuildContext context,
    String key, [
    Map<String, Object?>? args,
  ]) {
    final code = watchCode(context);
    return tr(key, args, code);
  }
}

extension NoesisL10nContext on BuildContext {
  String tr(String key, [Map<String, Object?>? args]) =>
      NoesisL10n.trContext(this, key, args);
}
