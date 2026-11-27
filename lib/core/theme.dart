import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart' show GoogleFonts;
import '../features/quizzes/data/saved_exams_store_stub.dart'
    if (dart.library.io) '../features/quizzes/data/saved_exams_store_io.dart'
    if (dart.library.js_interop) '../features/quizzes/data/saved_exams_store_web.dart' as local_store;
import 'constants.dart';
import 'desktop_window_service.dart';
import 'localization/noesis_l10n.dart';

/// Conjunto das 6 cores personalizáveis via RGB para membros VIP.
class NoesisCustomThemeColors {
  final Color bg;
  final Color surface;
  final Color primary;
  final Color accent1;
  final Color accent2;
  final Color accent3;

  const NoesisCustomThemeColors({
    required this.bg,
    required this.surface,
    required this.primary,
    required this.accent1,
    required this.accent2,
    required this.accent3,
  });

  static const NoesisCustomThemeColors defaults = NoesisCustomThemeColors(
    bg: Color(0xFF0E0F1A),
    surface: Color(0xFF17192A),
    primary: Color(0xFFF2B33D),
    accent1: Color(0xFF3CCF9A),
    accent2: Color(0xFF7C6CF0),
    accent3: Color(0xFFFF7A90),
  );

  List<Color> get asList => [bg, surface, primary, accent1, accent2, accent3];

  NoesisCustomThemeColors copyWithSlot(int index, Color color) {
    switch (index) {
      case 0:
        return NoesisCustomThemeColors(
          bg: color,
          surface: surface,
          primary: primary,
          accent1: accent1,
          accent2: accent2,
          accent3: accent3,
        );
      case 1:
        return NoesisCustomThemeColors(
          bg: bg,
          surface: color,
          primary: primary,
          accent1: accent1,
          accent2: accent2,
          accent3: accent3,
        );
      case 2:
        return NoesisCustomThemeColors(
          bg: bg,
          surface: surface,
          primary: color,
          accent1: accent1,
          accent2: accent2,
          accent3: accent3,
        );
      case 3:
        return NoesisCustomThemeColors(
          bg: bg,
          surface: surface,
          primary: primary,
          accent1: color,
          accent2: accent2,
          accent3: accent3,
        );
      case 4:
        return NoesisCustomThemeColors(
          bg: bg,
          surface: surface,
          primary: primary,
          accent1: accent1,
          accent2: color,
          accent3: accent3,
        );
      case 5:
        return NoesisCustomThemeColors(
          bg: bg,
          surface: surface,
          primary: primary,
          accent1: accent1,
          accent2: accent2,
          accent3: color,
        );
      default:
        return this;
    }
  }

  Map<String, dynamic> toJson() => {
        'bg': bg.toARGB32(),
        'surface': surface.toARGB32(),
        'primary': primary.toARGB32(),
        'accent1': accent1.toARGB32(),
        'accent2': accent2.toARGB32(),
        'accent3': accent3.toARGB32(),
      };

  factory NoesisCustomThemeColors.fromJson(Map<String, dynamic> json) {
    Color readCol(String key, Color fallback) {
      final raw = json[key];
      if (raw is int) return Color(raw);
      return fallback;
    }

    return NoesisCustomThemeColors(
      bg: readCol('bg', defaults.bg),
      surface: readCol('surface', defaults.surface),
      primary: readCol('primary', defaults.primary),
      accent1: readCol('accent1', defaults.accent1),
      accent2: readCol('accent2', defaults.accent2),
      accent3: readCol('accent3', defaults.accent3),
    );
  }

  NoesisThemeOption toNoesisThemeOption() {
    final isBgDark = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark;
    final isSurfaceDark = ThemeData.estimateBrightnessForColor(surface) == Brightness.dark;
    final isPrimaryDark = ThemeData.estimateBrightnessForColor(primary) == Brightness.dark;

    final surface2 = isSurfaceDark
        ? Color.lerp(surface, Colors.white, 0.08)!
        : Color.lerp(surface, bg, 0.35)!;

    return NoesisThemeOption(
      id: AsterTheme.customThemeId,
      name: NoesisL10n.tr('Personalizado'),
      tag: NoesisL10n.tr('VIP · 6 cores RGB'),
      description: NoesisL10n.tr('Tema exclusivo VIP com 6 cores personalizáveis no espectro RGB e HEX.'),
      mode: isBgDark ? ThemeMode.dark : ThemeMode.light,
      bg: bg,
      surface: surface,
      surface2: surface2,
      textColor: isSurfaceDark ? const Color(0xFFF4F5FB) : const Color(0xFF1E2033),
      mutedColor: isSurfaceDark ? const Color(0xFF9EA2C0) : const Color(0xFF666985),
      primary: primary,
      onPrimary: isPrimaryDark ? Colors.white : const Color(0xFF11121C),
      accents: [accent1, accent2, accent3, primary],
      icon: Icons.tune_rounded,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NoesisCustomThemeColors &&
      other.bg == bg &&
      other.surface == surface &&
      other.primary == primary &&
      other.accent1 == accent1 &&
      other.accent2 == accent2 &&
      other.accent3 == accent3;

  @override
  int get hashCode => Object.hash(bg, surface, primary, accent1, accent2, accent3);
}

/// Opção selecionável de tema visual no ecossistema Noesis.
class NoesisThemeOption {
  const NoesisThemeOption({
    required this.id,
    required this.name,
    required this.tag,
    required this.description,
    required this.mode,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.textColor,
    required this.mutedColor,
    required this.primary,
    required this.onPrimary,
    required this.accents,
    required this.icon,
  });

  final String id;
  final String name;
  final String tag;
  final String description;
  final ThemeMode mode;
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color textColor;
  final Color mutedColor;
  final Color primary;
  final Color onPrimary;
  final List<Color> accents;
  final IconData icon;

  String get localizedName => NoesisL10n.tr(name);
  String get localizedTag => NoesisL10n.tr(tag);
  String get localizedDescription => NoesisL10n.tr(description);

  Color get accentColor => primary;
}

class AsterTheme {
  static const List<String> scriptFontFamilyFallback = <String>[
    'Noto Sans Arabic',
    'Geeza Pro',
    'Tahoma',
    'Noto Sans CJK SC',
    'Noto Sans CJK JP',
    'Noto Sans CJK KR',
    'Microsoft YaHei',
    'PingFang SC',
    'Meiryo',
    'Hiragino Sans',
    'Malgun Gothic',
    'Apple SD Gothic Neo',
    'Segoe UI',
    'Roboto',
    'Noto Sans',
    'sans-serif',
  ];

  /// Estado global de recolhimento do menu lateral em telas largas (>= 900px),
  /// permitindo que cabeçalhos e botões de retorno se alinhem ao lado do menu fechado.
  static final ValueNotifier<bool> sidebarCollapsedNotifier = ValueNotifier<bool>(false);

  static List<NoesisThemeOption> get availableThemes => [
    NoesisThemeOption(
      id: 'soft_clay_nevoa',
      name: NoesisL10n.tr('Névoa'),
      tag: NoesisL10n.tr('Claro · base oficial'),
      description: NoesisL10n.tr('Tema claro padrão do Noesis: suave, luminoso e equilibrado com lavanda e menta.'),
      mode: ThemeMode.light,
      bg: AsterConstants.bgNevoa,
      surface: AsterConstants.surfaceCard,
      surface2: AsterConstants.surfaceAlt,
      textColor: AsterConstants.textDark,
      mutedColor: AsterConstants.textMuted,
      primary: AsterConstants.lavanda,
      onPrimary: Colors.white,
      accents: const [AsterConstants.menta, AsterConstants.ambar, AsterConstants.coral, AsterConstants.lavanda],
      icon: Icons.light_mode_rounded,
    ),
    NoesisThemeOption(
      id: 'aurora',
      name: NoesisL10n.tr('Aurora'),
      tag: NoesisL10n.tr('Escuro · análogas'),
      description: NoesisL10n.tr('Versão noturna da Névoa: azul-noite com violeta no destaque e âmbar pontual para estudar à noite.'),
      mode: ThemeMode.dark,
      bg: const Color(0xFF0E0F1F),
      surface: const Color(0xFF171936),
      surface2: const Color(0xFF262A55),
      textColor: const Color(0xFFECEBFF),
      mutedColor: const Color(0xFF9A9CC4),
      primary: const Color(0xFF8B7CF6),
      onPrimary: const Color(0xFFFFFFFF),
      accents: const [Color(0xFF3DD598), Color(0xFFF5A524), Color(0xFFFF6B8A), Color(0xFF4CC9F0)],
      icon: Icons.nights_stay_rounded,
    ),
    NoesisThemeOption(
      id: 'floresta',
      name: NoesisL10n.tr('Floresta'),
      tag: NoesisL10n.tr('Claro · análogas + complementar'),
      description: NoesisL10n.tr('Verde como cor principal: associado a calma, foco e crescimento, com coral apenas em alertas.'),
      mode: ThemeMode.light,
      bg: const Color(0xFFEEF4EF),
      surface: const Color(0xFFFFFFFF),
      surface2: const Color(0xFFDDEBE1),
      textColor: const Color(0xFF1D2B24),
      mutedColor: const Color(0xFF6B7F74),
      primary: const Color(0xFF2F9E75),
      onPrimary: const Color(0xFFFFFFFF),
      accents: const [Color(0xFF2F9E75), Color(0xFFE9A23B), Color(0xFFE5604D), Color(0xFF4A8FD9)],
      icon: Icons.park_rounded,
    ),
    NoesisThemeOption(
      id: 'oceano',
      name: NoesisL10n.tr('Oceano'),
      tag: NoesisL10n.tr('Claro · complementar'),
      description: NoesisL10n.tr('Azul que passa confiança e concentração, com laranja e teal para ações e constância.'),
      mode: ThemeMode.light,
      bg: const Color(0xFFEAF3FB),
      surface: const Color(0xFFFFFFFF),
      surface2: const Color(0xFFD9E8F6),
      textColor: const Color(0xFF14263A),
      mutedColor: const Color(0xFF637A91),
      primary: const Color(0xFF2F7DE1),
      onPrimary: const Color(0xFFFFFFFF),
      accents: const [Color(0xFF2F7DE1), Color(0xFF14B8A6), Color(0xFFF59E0B), Color(0xFFEC5B7A)],
      icon: Icons.waves_rounded,
    ),
    NoesisThemeOption(
      id: 'brasa',
      name: NoesisL10n.tr('Brasa'),
      tag: NoesisL10n.tr('Claro · tríade'),
      description: NoesisL10n.tr('Tema quente e energético: coral, violeta e teal em tríade equilibrada sobre fundo rosado leve.'),
      mode: ThemeMode.light,
      bg: const Color(0xFFFFF0EB),
      surface: const Color(0xFFFFFFFF),
      surface2: const Color(0xFFFFDDD2),
      textColor: const Color(0xFF2E1F27),
      mutedColor: const Color(0xFF86707A),
      primary: const Color(0xFFF0625F),
      onPrimary: const Color(0xFFFFFFFF),
      accents: const [Color(0xFFF0625F), Color(0xFF7C6AF0), Color(0xFF14B8A6), Color(0xFFF5A524)],
      icon: Icons.local_fire_department_rounded,
    ),
    NoesisThemeOption(
      id: 'grafite',
      name: NoesisL10n.tr('Grafite'),
      tag: NoesisL10n.tr('Escuro · acento único'),
      description: NoesisL10n.tr('Preto neutro com lima vibrante de alto contraste para destacar foco, timer e ações.'),
      mode: ThemeMode.dark,
      bg: const Color(0xFF0A0A0C),
      surface: const Color(0xFF151518),
      surface2: const Color(0xFF26262C),
      textColor: const Color(0xFFF2F2F4),
      mutedColor: const Color(0xFF8D8D98),
      primary: const Color(0xFFC6F432),
      onPrimary: const Color(0xFF111111),
      accents: const [Color(0xFFC6F432), Color(0xFF6EE7F9), Color(0xFFFF8A5B), Color(0xFFB69CFF)],
      icon: Icons.bolt_rounded,
    ),
    NoesisThemeOption(
      id: 'lagoa',
      name: NoesisL10n.tr('Lagoa'),
      tag: NoesisL10n.tr('Claro · análogas frias'),
      description: NoesisL10n.tr('Teal-ciano limpo e leve sobre fundo azul-esverdeado suave com acento complementar em violeta.'),
      mode: ThemeMode.light,
      bg: const Color(0xFFE8F7F6),
      surface: const Color(0xFFFFFFFF),
      surface2: const Color(0xFFD2EFEC),
      textColor: const Color(0xFF12302F),
      mutedColor: const Color(0xFF5E8280),
      primary: const Color(0xFF0FA3A3),
      onPrimary: const Color(0xFFFFFFFF),
      accents: const [Color(0xFF0FA3A3), Color(0xFF8B7CF6), Color(0xFFF5A524), Color(0xFFF0627F)],
      icon: Icons.water_rounded,
    ),
    NoesisThemeOption(
      id: 'sakura',
      name: NoesisL10n.tr('Sakura'),
      tag: NoesisL10n.tr('Claro · análogas rosa-violeta'),
      description: NoesisL10n.tr('Rosa-magenta acolhedor com violeta vizinho e verde-menta como contraste para metas batidas.'),
      mode: ThemeMode.light,
      bg: const Color(0xFFFDEEF5),
      surface: const Color(0xFFFFFFFF),
      surface2: const Color(0xFFFADCEA),
      textColor: const Color(0xFF341A29),
      mutedColor: const Color(0xFF8E6D7F),
      primary: const Color(0xFFE0509A),
      onPrimary: const Color(0xFFFFFFFF),
      accents: const [Color(0xFFE0509A), Color(0xFF8B7CF6), Color(0xFF2FBF8A), Color(0xFFF5A524)],
      icon: Icons.local_florist_rounded,
    ),
    NoesisThemeOption(
      id: 'esmeralda',
      name: NoesisL10n.tr('Esmeralda'),
      tag: NoesisL10n.tr('Escuro · análogas verdes'),
      description: NoesisL10n.tr('Preto-esverdeado profundo com esmeralda no destaque transmitindo foco e evolução constante.'),
      mode: ThemeMode.dark,
      bg: const Color(0xFF0A1512),
      surface: const Color(0xFF12211C),
      surface2: const Color(0xFF1D352C),
      textColor: const Color(0xFFE6F5EE),
      mutedColor: const Color(0xFF86A89A),
      primary: const Color(0xFF34D399),
      onPrimary: const Color(0xFF06241A),
      accents: const [Color(0xFF34D399), Color(0xFFFBBF24), Color(0xFFF472B6), Color(0xFF60A5FA)],
      icon: Icons.diamond_rounded,
    ),
    NoesisThemeOption(
      id: 'crepusculo',
      name: NoesisL10n.tr('Crepúsculo'),
      tag: NoesisL10n.tr('Escuro · split-complementar'),
      description: NoesisL10n.tr('Roxo-berinjela profundo com rosa vibrante, âmbar e ciano nos gráficos. Expressivo e ousado.'),
      mode: ThemeMode.dark,
      bg: const Color(0xFF1A0F2E),
      surface: const Color(0xFF251640),
      surface2: const Color(0xFF36205C),
      textColor: const Color(0xFFF3EAFF),
      mutedColor: const Color(0xFFB09BD0),
      primary: const Color(0xFFFF7AB6),
      onPrimary: const Color(0xFF2A0B1E),
      accents: const [Color(0xFFFF7AB6), Color(0xFFFFB454), Color(0xFF7DD3FC), Color(0xFFA78BFA)],
      icon: Icons.wb_twilight_rounded,
    ),
    NoesisThemeOption(
      id: 'nordico',
      name: NoesisL10n.tr('Nórdico'),
      tag: NoesisL10n.tr('Claro · neutro + acentos'),
      description: NoesisL10n.tr('Cinza-azulado frio com ardósia sóbria e profissional, destacando dados e gráficos com clareza.'),
      mode: ThemeMode.light,
      bg: const Color(0xFFF0F2F6),
      surface: const Color(0xFFFFFFFF),
      surface2: const Color(0xFFE1E5EC),
      textColor: const Color(0xFF1B2430),
      mutedColor: const Color(0xFF667385),
      primary: const Color(0xFF33415C),
      onPrimary: const Color(0xFFFFFFFF),
      accents: const [Color(0xFF4F6BED), Color(0xFF2FB5A0), Color(0xFFF2A33A), Color(0xFFE5677D)],
      icon: Icons.ac_unit_rounded,
    ),
  ];

  static const String customThemeId = 'custom';
  static const String _customThemeStorageKey = 'noesis_custom_theme_v1';

  static final ValueNotifier<NoesisCustomThemeColors> customThemeColorsNotifier =
      ValueNotifier<NoesisCustomThemeColors>(NoesisCustomThemeColors.defaults);

  static List<NoesisThemeOption> get availableThemesWithCustom => [
        ...availableThemes,
        customThemeColorsNotifier.value.toNoesisThemeOption(),
      ];

  static final ValueNotifier<String> activeThemeIdNotifier =
      ValueNotifier<String>('soft_clay_nevoa');

  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

  static bool get isDarkMode => themeModeNotifier.value == ThemeMode.dark;

  static NoesisThemeOption get currentTheme {
    final id = activeThemeIdNotifier.value;
    if (id == customThemeId) {
      return customThemeColorsNotifier.value.toNoesisThemeOption();
    }
    return availableThemes.firstWhere(
      (t) => t.id == id,
      orElse: () => availableThemes.first,
    );
  }

  static void setThemeMode(ThemeMode mode) {
    if (themeModeNotifier.value != mode) {
      themeModeNotifier.value = mode;
    }
    DesktopWindowService.setDarkMode(mode == ThemeMode.dark);
  }

  static Color lastTransitionBgColor = AsterConstants.bgNevoa;

  static void selectThemeOption(String themeId) {
    final prev = currentTheme;
    final option = availableThemesWithCustom.firstWhere(
      (t) => t.id == themeId,
      orElse: () => availableThemes.first,
    );
    if (prev.id == option.id) return;
    lastTransitionBgColor = prev.bg;
    // Pré-compila o tema destino antes de notificar para eliminar jank no 1º frame
    themeDataFor(option);
    activeThemeIdNotifier.value = option.id;
    setThemeMode(option.mode);
  }

  static Future<void> loadCustomTheme({bool isVip = false}) async {
    try {
      final raw = await local_store.readSavedExamsRaw(_customThemeStorageKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          if (map['colors'] is Map) {
            customThemeColorsNotifier.value = NoesisCustomThemeColors.fromJson(
              Map<String, dynamic>.from(map['colors'] as Map),
            );
            _compiledThemeCache.remove(customThemeId);
          }
          if (isVip && map['active'] == true) {
            selectThemeOption(customThemeId);
          }
        }
      }
    } catch (_) {}
  }

  static Future<void> updateCustomThemeColors(
    NoesisCustomThemeColors colors, {
    bool activateIfVip = false,
  }) async {
    _compiledThemeCache.remove(customThemeId);
    customThemeColorsNotifier.value = colors;
    final opt = colors.toNoesisThemeOption();
    themeDataFor(opt);
    if (activateIfVip || activeThemeIdNotifier.value == customThemeId) {
      activeThemeIdNotifier.value = customThemeId;
      setThemeMode(opt.mode);
    }
    try {
      await local_store.writeSavedExamsRaw(
        _customThemeStorageKey,
        jsonEncode({
          'colors': colors.toJson(),
          'active': activeThemeIdNotifier.value == customThemeId,
        }),
      );
    } catch (_) {}
  }

  static Future<void> resetCustomThemeForTesting() async {
    _compiledThemeCache.remove(customThemeId);
    customThemeColorsNotifier.value = NoesisCustomThemeColors.defaults;
    if (activeThemeIdNotifier.value == customThemeId) {
      selectThemeOption('soft_clay_nevoa');
    }
    try {
      await local_store.writeSavedExamsRaw(_customThemeStorageKey, '');
    } catch (_) {}
  }

  static final Map<String, ThemeData> _compiledThemeCache = {};

  static ThemeData themeDataFor(NoesisThemeOption option) {
    return _compiledThemeCache.putIfAbsent(option.id, () => _buildThemeFromOption(option));
  }

  static ThemeData activeLightThemeData() {
    final active = currentTheme;
    if (active.mode == ThemeMode.light) {
      return themeDataFor(active);
    }
    return softClayTheme;
  }

  static ThemeData activeDarkThemeData() {
    final active = currentTheme;
    if (active.mode == ThemeMode.dark) {
      return themeDataFor(active);
    }
    return darkTheme;
  }

  /// Cor primária de destaque do tema ativo (botões, foco, ativo).
  static Color primary(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }

  /// Cor de texto/ícone sobre a cor primária (ex.: texto preto no tema Grafite).
  static Color onPrimary(BuildContext context) {
    return Theme.of(context).colorScheme.onPrimary;
  }

  /// Cor secundária de destaque do tema ativo (constância, revisão, sucesso).
  static Color secondary(BuildContext context) {
    return Theme.of(context).colorScheme.secondary;
  }

  /// Cores de acento do tema ativo (índices 0..3 para gráficos e categorias).
  static Color accent(BuildContext context, int index) {
    final accents = currentTheme.accents;
    if (accents.isEmpty) return Theme.of(context).colorScheme.primary;
    return accents[index % accents.length];
  }

  /// Sombra colorida de botão/pílula primária adaptada à cor do tema ativo.
  static List<BoxShadow> primaryShadow(BuildContext context, [Color? overrideColor]) {
    final base = overrideColor ?? Theme.of(context).colorScheme.primary;
    return [
      BoxShadow(
        color: base.withValues(alpha: 0.28),
        blurRadius: 16,
        offset: const Offset(0, 6),
        spreadRadius: -3,
      ),
    ];
  }

  /// Retorna a cor de texto primária com alto contraste de acordo com o tema
  static Color text(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  /// Retorna a cor de texto secundária/muted com legibilidade e contraste WCAG AA
  static Color textMuted(BuildContext context) {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  /// Retorna a cor de fundo de cartões apropriada para o tema ativo
  static Color card(BuildContext context) {
    return Theme.of(context).cardColor;
  }

  /// Retorna a cor de superfícies alternativas/inputs para o tema ativo
  static Color surfaceAlt(BuildContext context) {
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  /// Retorna a cor de divisores e trilhas de progresso
  static Color surfaceInset(BuildContext context) {
    return Theme.of(context).dividerTheme.color ??
        (Theme.of(context).brightness == Brightness.dark
            ? AsterConstants.surfaceInsetDark
            : AsterConstants.surfaceInset);
  }

  // Instâncias imutáveis pré-compiladas em memória para eliminar re-alocações na troca de tema
  static final ThemeData softClayTheme = _buildSoftClayTheme();
  static final ThemeData darkTheme = _buildDarkTheme();

  static ChipThemeData _buildChipTheme({
    required bool isDark,
    required Color surfaceAlt,
    required Color primary,
    required Color onPrimary,
    required Color textColor,
    required Color mutedColor,
    required Color dividerCol,
  }) {
    return ChipThemeData(
      backgroundColor: surfaceAlt,
      selectedColor: primary,
      secondarySelectedColor: primary,
      disabledColor: surfaceAlt.withValues(alpha: 0.5),
      deleteIconColor: mutedColor,
      checkmarkColor: onPrimary,
      elevation: 0,
      pressElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: const StadiumBorder(),
      side: WidgetStateBorderSide.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return BorderSide.none;
        }
        return BorderSide(
          color: dividerCol.withValues(alpha: isDark ? 0.65 : 0.85),
          width: 1,
        );
      }),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      iconTheme: IconThemeData(size: 15, color: mutedColor),
      labelStyle: WidgetStateTextStyle.resolveWith((states) {
        final isSel = states.contains(WidgetState.selected);
        return GoogleFonts.manrope(
          fontSize: 12.5,
          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
          color: isSel ? onPrimary : textColor,
        ).copyWith(fontFamilyFallback: scriptFontFamilyFallback);
      }),
      secondaryLabelStyle: GoogleFonts.manrope(
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        color: onPrimary,
      ).copyWith(fontFamilyFallback: scriptFontFamilyFallback),
    );
  }

  static ThemeData _buildThemeFromOption(NoesisThemeOption opt) {
    final isDark = opt.mode == ThemeMode.dark;
    final secondary = opt.accents.isNotEmpty ? opt.accents[0] : AsterConstants.menta;
    final errorCol = opt.accents.length >= 3 ? opt.accents[2] : AsterConstants.coral;
    final dividerCol = isDark ? opt.surface2 : Color.lerp(opt.surface2, opt.bg, 0.35)!;

    return ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      highlightColor: Colors.transparent,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: opt.bg,
      primaryColor: opt.primary,
      cardColor: opt.surface,
      canvasColor: opt.bg,
      dialogBackgroundColor: opt.surface,
      dialogTheme: DialogThemeData(
        backgroundColor: opt.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: opt.surface,
        modalBackgroundColor: opt.surface,
      ),
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: opt.primary,
              secondary: secondary,
              surface: opt.surface,
              surfaceContainerHighest: opt.surface2,
              error: errorCol,
              onPrimary: opt.onPrimary,
              onSecondary: opt.onPrimary,
              onSurface: opt.textColor,
              onSurfaceVariant: opt.mutedColor,
            )
          : ColorScheme.light(
              primary: opt.primary,
              secondary: secondary,
              surface: opt.surface,
              surfaceContainerHighest: opt.surface2,
              error: errorCol,
              onPrimary: opt.onPrimary,
              onSecondary: opt.onPrimary,
              onSurface: opt.textColor,
              onSurfaceVariant: opt.mutedColor,
            ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.manrope(
          color: opt.textColor,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        displayMedium: GoogleFonts.manrope(
          color: opt.textColor,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
        titleLarge: GoogleFonts.manrope(
          color: opt.textColor,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: GoogleFonts.manrope(
          color: opt.textColor,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: GoogleFonts.manrope(
          color: opt.textColor,
          fontSize: 15,
        ),
        bodyMedium: GoogleFonts.manrope(
          color: opt.textColor,
          fontSize: 14,
        ),
        bodySmall: GoogleFonts.manrope(
          color: opt.mutedColor,
          fontSize: 12,
        ),
      ).apply(fontFamilyFallback: scriptFontFamilyFallback),
      cardTheme: CardThemeData(
        color: opt.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
          side: BorderSide.none,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          color: opt.textColor,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ).copyWith(fontFamilyFallback: scriptFontFamilyFallback),
        iconTheme: IconThemeData(color: opt.textColor),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: opt.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
          borderSide: BorderSide(color: opt.primary, width: 1.5),
        ),
        hintStyle: GoogleFonts.manrope(
          color: opt.mutedColor.withValues(alpha: 0.7),
          fontSize: 13,
        ).copyWith(fontFamilyFallback: scriptFontFamilyFallback),
        labelStyle: GoogleFonts.manrope(
          color: opt.mutedColor,
          fontSize: 13,
        ).copyWith(fontFamilyFallback: scriptFontFamilyFallback),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: opt.primary,
          foregroundColor: opt.onPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
          ),
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ).copyWith(fontFamilyFallback: scriptFontFamilyFallback),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: dividerCol,
        thickness: 1,
        space: 1,
      ),
      chipTheme: _buildChipTheme(
        isDark: isDark,
        surfaceAlt: opt.surface2,
        primary: opt.primary,
        onPrimary: opt.onPrimary,
        textColor: opt.textColor,
        mutedColor: opt.mutedColor,
        dividerCol: dividerCol,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: opt.mode == ThemeMode.dark ? opt.surface2 : AsterConstants.textDark,
        contentTextStyle: GoogleFonts.manrope(
          color: opt.mode == ThemeMode.dark ? opt.textColor : Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ).copyWith(fontFamilyFallback: scriptFontFamilyFallback),
        actionTextColor: opt.primary,
      ),
    );
  }

  static ThemeData _buildSoftClayTheme() => _buildThemeFromOption(availableThemes.first);

  static ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      highlightColor: Colors.transparent,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AsterConstants.bgDark,
      primaryColor: AsterConstants.lavanda,
      cardColor: AsterConstants.surfaceCardDark,
      canvasColor: AsterConstants.bgDark,
      dialogBackgroundColor: AsterConstants.surfaceCardDark,
      dialogTheme: DialogThemeData(
        backgroundColor: AsterConstants.surfaceCardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AsterConstants.surfaceCardDark,
        modalBackgroundColor: AsterConstants.surfaceCardDark,
      ),
      colorScheme: const ColorScheme.dark(
        primary: AsterConstants.lavanda,
        secondary: AsterConstants.menta,
        surface: AsterConstants.surfaceCardDark,
        surfaceContainerHighest: AsterConstants.surfaceAltDark,
        error: AsterConstants.coral,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AsterConstants.textLight,
        onSurfaceVariant: AsterConstants.textMutedDark,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.manrope(
          color: AsterConstants.textLight,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        displayMedium: GoogleFonts.manrope(
          color: AsterConstants.textLight,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
        titleLarge: GoogleFonts.manrope(
          color: AsterConstants.textLight,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: GoogleFonts.manrope(
          color: AsterConstants.textLight,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: GoogleFonts.manrope(
          color: AsterConstants.textLight,
          fontSize: 15,
        ),
        bodyMedium: GoogleFonts.manrope(
          color: AsterConstants.textLight,
          fontSize: 14,
        ),
        bodySmall: GoogleFonts.manrope(
          color: AsterConstants.textMutedDark,
          fontSize: 12,
        ),
      ).apply(fontFamilyFallback: scriptFontFamilyFallback),
      cardTheme: CardThemeData(
        color: AsterConstants.surfaceCardDark,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
          side: BorderSide.none,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          color: AsterConstants.textLight,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ).copyWith(fontFamilyFallback: scriptFontFamilyFallback),
        iconTheme: const IconThemeData(color: AsterConstants.textLight),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AsterConstants.surfaceAltDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
          borderSide: const BorderSide(color: AsterConstants.lavanda, width: 1.5),
        ),
        hintStyle: GoogleFonts.manrope(
          color: AsterConstants.textFaintDark,
          fontSize: 13,
        ).copyWith(fontFamilyFallback: scriptFontFamilyFallback),
        labelStyle: GoogleFonts.manrope(
          color: AsterConstants.textMutedDark,
          fontSize: 13,
        ).copyWith(fontFamilyFallback: scriptFontFamilyFallback),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AsterConstants.lavanda,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
          ),
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ).copyWith(fontFamilyFallback: scriptFontFamilyFallback),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AsterConstants.surfaceInsetDark,
        thickness: 1,
        space: 1,
      ),
      chipTheme: _buildChipTheme(
        isDark: true,
        surfaceAlt: AsterConstants.surfaceAltDark,
        primary: AsterConstants.lavanda,
        onPrimary: Colors.white,
        textColor: AsterConstants.textLight,
        mutedColor: AsterConstants.textMutedDark,
        dividerCol: AsterConstants.surfaceInsetDark,
      ),
    );
  }
}

/// Fundo oficial com iluminação radial suave em Lavanda e Menta (Isolado em GPU Layer)
class SoftClayBackground extends StatelessWidget {
  final Widget child;

  const SoftClayBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = theme.scaffoldBackgroundColor;
    final primaryGlow = theme.colorScheme.primary.withValues(alpha: isDark ? 0.21 : 0.12);
    final secondaryGlow = theme.colorScheme.secondary.withValues(alpha: isDark ? 0.16 : 0.12);

    return Stack(
      fit: StackFit.expand,
      children: [
        // ─── Camada de Fundo Estática Isolada (Zero repaints na interação) ───
        Positioned.fill(
          child: RepaintBoundary(
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                gradient: RadialGradient(
                  center: const Alignment(0.85, -0.9),
                  radius: 1.1,
                  colors: [
                    primaryGlow,
                    Colors.transparent,
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: -150,
                    bottom: -150,
                    width: 450,
                    height: 450,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              secondaryGlow,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ─── Conteúdo Interativo do App ───
        child,
      ],
    );
  }
}

/// Cartão Soft Clay Oficial com Cantos de 28px, Sombras Táteis e Transição Fluida
class SoftClayCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? color;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool useListShadow;
  final List<BoxShadow>? shadow;

  const SoftClayCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.margin,
    this.width,
    this.height,
    this.color,
    this.borderRadius = AsterConstants.radiusLarge,
    this.onTap,
    this.useListShadow = false,
    this.shadow,
  });

  const SoftClayCard.list({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.margin,
    this.width,
    this.height,
    this.color,
    this.borderRadius = AsterConstants.radiusLarge,
    this.onTap,
    this.shadow,
  }) : useListShadow = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = color ?? theme.cardColor;
    final List<BoxShadow> defaultShadow = isDark
        ? AsterConstants.clayDarkShadow
        : (AsterTheme.activeThemeIdNotifier.value == 'soft_clay_nevoa'
            ? (useListShadow ? AsterConstants.clayListShadow : AsterConstants.clayShadow)
            : (useListShadow
                ? [
                    BoxShadow(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                      spreadRadius: -2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                      spreadRadius: -4,
                    ),
                    BoxShadow(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]));

    final decoration = BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: shadow ?? defaultShadow,
    );

    Widget content = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    return content;
  }
}

/// Tag Semântica Soft Clay com cor diluída
class SoftClayTag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;

  const SoftClayTag({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        child: chip,
      );
    }
    return chip;
  }
}

/// Pílula interativa Soft Clay para filtros, seleções e ações rápidas,
/// substituindo chips genéricos do Material 3 com borda escura.
class SoftClayChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? accentColor;
  final bool showCheckmark;
  final bool compact;
  final bool enabled;

  const SoftClayChoiceChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.accentColor,
    this.showCheckmark = false,
    this.compact = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeBg = accentColor ?? theme.colorScheme.primary;
    final activeFg = accentColor == null
        ? theme.colorScheme.onPrimary
        : (ThemeData.estimateBrightnessForColor(activeBg) == Brightness.dark
            ? Colors.white
            : AsterConstants.textDark);
    final inactiveBg = isDark ? AsterConstants.surfaceAltDark : theme.colorScheme.surface;
    final inactiveBorder = AsterTheme.surfaceInset(context);
    final fgColor = selected
        ? activeFg
        : (enabled ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant);

    final IconData? effectiveIcon =
        icon ?? (selected && showCheckmark ? Icons.check_rounded : null);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? activeBg : inactiveBg,
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        border: Border.all(
          color: selected ? Colors.transparent : inactiveBorder,
          width: 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: activeBg.withValues(alpha: isDark ? 0.34 : 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                  spreadRadius: -2,
                ),
              ]
            : (isDark ? AsterConstants.claySubtleDarkShadow : AsterConstants.claySubtleShadow),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 11 : 14,
              vertical: compact ? 6.5 : 8.5,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (effectiveIcon != null) ...[
                  Icon(
                    effectiveIcon,
                    size: compact ? 13.5 : 15,
                    color: fgColor,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: compact ? 11.5 : 12.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: fgColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão Primário Soft Clay com Sombra Suave e Transição Adaptativa
class SoftClayPillButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? textColor;
  final bool isSecondary;
  final EdgeInsetsGeometry padding;
  final double? fontSize;
  final double? iconSize;

  const SoftClayPillButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.color,
    this.textColor,
    this.isSecondary = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.fontSize,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final resolvedPadding = padding.resolve(Directionality.maybeOf(context) ?? TextDirection.ltr);
    // Garante espaçamento horizontal equilibrado e seguro contra a borda arredondada da pílula
    final effectivePadding = EdgeInsets.only(
      top: resolvedPadding.top,
      bottom: resolvedPadding.bottom,
      left: math.max(resolvedPadding.left, 16.0),
      right: math.max(resolvedPadding.right, 16.0),
    );

    if (isSecondary) {
      final secondaryBg = theme.colorScheme.surfaceContainerHighest;
      final secondaryText = theme.colorScheme.onSurface;
      final secondaryShadow = isDark ? AsterConstants.claySubtleDarkShadow : AsterConstants.claySubtleShadow;

      return Container(
        decoration: BoxDecoration(
          color: secondaryBg,
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          boxShadow: secondaryShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
            child: Padding(
              padding: effectivePadding,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: iconSize ?? 17, color: secondaryText),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: fontSize ?? 13,
                          fontWeight: FontWeight.w700,
                          color: secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final effectiveBtnColor = color ?? theme.colorScheme.primary;
    final effectiveTextColor =
        textColor ?? (color == null ? theme.colorScheme.onPrimary : Colors.white);

    return Container(
      decoration: BoxDecoration(
        color: effectiveBtnColor,
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        boxShadow: AsterTheme.primaryShadow(context, effectiveBtnColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          child: Padding(
            padding: effectivePadding,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: iconSize ?? 17, color: effectiveTextColor),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: fontSize ?? 13,
                        fontWeight: FontWeight.w700,
                        color: effectiveTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Transição de tema acelerada na GPU sem interpolar dezenas de TextStyles na árvore inteira.
class NoesisThemeTransitionOverlay extends StatefulWidget {
  const NoesisThemeTransitionOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<NoesisThemeTransitionOverlay> createState() => _NoesisThemeTransitionOverlayState();
}

class _NoesisThemeTransitionOverlayState extends State<NoesisThemeTransitionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  Color _veilColor = AsterConstants.bgNevoa;
  String _lastId = AsterTheme.activeThemeIdNotifier.value;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _opacity = Tween<double>(begin: 0.52, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    AsterTheme.activeThemeIdNotifier.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    final nextId = AsterTheme.activeThemeIdNotifier.value;
    if (nextId == _lastId || !mounted) return;
    _lastId = nextId;
    setState(() {
      _veilColor = AsterTheme.lastTransitionBgColor;
    });
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    AsterTheme.activeThemeIdNotifier.removeListener(_onThemeChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (!_controller.isAnimating) {
              return const SizedBox.shrink();
            }
            return IgnorePointer(
              child: RepaintBoundary(
            child: FadeTransition(
              opacity: _opacity,
              child: ColoredBox(color: _veilColor),
            ),
          ),
        );
          },
        ),
      ],
    );
  }
}

/// No layout com barra lateral fixa em trilho (rail), as telas já ficam
/// enquadradas fora da barra lateral e não precisam de espaçador extra.
class NoesisCollapsedMenuSpacer extends StatelessWidget {
  const NoesisCollapsedMenuSpacer({super.key, this.width = 84});

  final double width;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
