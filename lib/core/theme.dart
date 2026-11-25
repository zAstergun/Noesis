import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart' show GoogleFonts;
import 'constants.dart';

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

  Color get accentColor => primary;
}

class AsterTheme {
  /// Estado global de recolhimento do menu lateral em telas largas (>= 900px),
  /// permitindo que cabeçalhos e botões de retorno se alinhem ao lado do menu fechado.
  static final ValueNotifier<bool> sidebarCollapsedNotifier = ValueNotifier<bool>(false);

  static const List<NoesisThemeOption> availableThemes = [
    NoesisThemeOption(
      id: 'soft_clay_nevoa',
      name: 'Névoa',
      tag: 'Claro · base oficial',
      description: 'Tema claro padrão do Noesis: suave, luminoso e equilibrado com lavanda e menta.',
      mode: ThemeMode.light,
      bg: AsterConstants.bgNevoa,
      surface: AsterConstants.surfaceCard,
      surface2: AsterConstants.surfaceAlt,
      textColor: AsterConstants.textDark,
      mutedColor: AsterConstants.textMuted,
      primary: AsterConstants.lavanda,
      onPrimary: Colors.white,
      accents: [AsterConstants.menta, AsterConstants.ambar, AsterConstants.coral, AsterConstants.lavanda],
      icon: Icons.light_mode_rounded,
    ),
    NoesisThemeOption(
      id: 'aurora',
      name: 'Aurora',
      tag: 'Escuro · análogas',
      description: 'Versão noturna da Névoa: azul-noite com violeta no destaque e âmbar pontual para estudar à noite.',
      mode: ThemeMode.dark,
      bg: Color(0xFF0E0F1F),
      surface: Color(0xFF171936),
      surface2: Color(0xFF262A55),
      textColor: Color(0xFFECEBFF),
      mutedColor: Color(0xFF9A9CC4),
      primary: Color(0xFF8B7CF6),
      onPrimary: Color(0xFFFFFFFF),
      accents: [Color(0xFF3DD598), Color(0xFFF5A524), Color(0xFFFF6B8A), Color(0xFF4CC9F0)],
      icon: Icons.nights_stay_rounded,
    ),
    NoesisThemeOption(
      id: 'floresta',
      name: 'Floresta',
      tag: 'Claro · análogas + complementar',
      description: 'Verde como cor principal: associado a calma, foco e crescimento, com coral apenas em alertas.',
      mode: ThemeMode.light,
      bg: Color(0xFFEEF4EF),
      surface: Color(0xFFFFFFFF),
      surface2: Color(0xFFDDEBE1),
      textColor: Color(0xFF1D2B24),
      mutedColor: Color(0xFF6B7F74),
      primary: Color(0xFF2F9E75),
      onPrimary: Color(0xFFFFFFFF),
      accents: [Color(0xFF2F9E75), Color(0xFFE9A23B), Color(0xFFE5604D), Color(0xFF4A8FD9)],
      icon: Icons.park_rounded,
    ),
    NoesisThemeOption(
      id: 'oceano',
      name: 'Oceano',
      tag: 'Claro · complementar',
      description: 'Azul que passa confiança e concentração, com laranja e teal para ações e constância.',
      mode: ThemeMode.light,
      bg: Color(0xFFEAF3FB),
      surface: Color(0xFFFFFFFF),
      surface2: Color(0xFFD9E8F6),
      textColor: Color(0xFF14263A),
      mutedColor: Color(0xFF637A91),
      primary: Color(0xFF2F7DE1),
      onPrimary: Color(0xFFFFFFFF),
      accents: [Color(0xFF2F7DE1), Color(0xFF14B8A6), Color(0xFFF59E0B), Color(0xFFEC5B7A)],
      icon: Icons.waves_rounded,
    ),
    NoesisThemeOption(
      id: 'brasa',
      name: 'Brasa',
      tag: 'Claro · tríade',
      description: 'Tema quente e energético: coral, violeta e teal em tríade equilibrada sobre fundo rosado leve.',
      mode: ThemeMode.light,
      bg: Color(0xFFFFF0EB),
      surface: Color(0xFFFFFFFF),
      surface2: Color(0xFFFFDDD2),
      textColor: Color(0xFF2E1F27),
      mutedColor: Color(0xFF86707A),
      primary: Color(0xFFF0625F),
      onPrimary: Color(0xFFFFFFFF),
      accents: [Color(0xFFF0625F), Color(0xFF7C6AF0), Color(0xFF14B8A6), Color(0xFFF5A524)],
      icon: Icons.local_fire_department_rounded,
    ),
    NoesisThemeOption(
      id: 'grafite',
      name: 'Grafite',
      tag: 'Escuro · acento único',
      description: 'Preto neutro com lima vibrante de alto contraste para destacar foco, timer e ações.',
      mode: ThemeMode.dark,
      bg: Color(0xFF0A0A0C),
      surface: Color(0xFF151518),
      surface2: Color(0xFF26262C),
      textColor: Color(0xFFF2F2F4),
      mutedColor: Color(0xFF8D8D98),
      primary: Color(0xFFC6F432),
      onPrimary: Color(0xFF111111),
      accents: [Color(0xFFC6F432), Color(0xFF6EE7F9), Color(0xFFFF8A5B), Color(0xFFB69CFF)],
      icon: Icons.bolt_rounded,
    ),
    NoesisThemeOption(
      id: 'lagoa',
      name: 'Lagoa',
      tag: 'Claro · análogas frias',
      description: 'Teal-ciano limpo e leve sobre fundo azul-esverdeado suave com acento complementar em violeta.',
      mode: ThemeMode.light,
      bg: Color(0xFFE8F7F6),
      surface: Color(0xFFFFFFFF),
      surface2: Color(0xFFD2EFEC),
      textColor: Color(0xFF12302F),
      mutedColor: Color(0xFF5E8280),
      primary: Color(0xFF0FA3A3),
      onPrimary: Color(0xFFFFFFFF),
      accents: [Color(0xFF0FA3A3), Color(0xFF8B7CF6), Color(0xFFF5A524), Color(0xFFF0627F)],
      icon: Icons.water_rounded,
    ),
    NoesisThemeOption(
      id: 'sakura',
      name: 'Sakura',
      tag: 'Claro · análogas rosa-violeta',
      description: 'Rosa-magenta acolhedor com violeta vizinho e verde-menta como contraste para metas batidas.',
      mode: ThemeMode.light,
      bg: Color(0xFFFDEEF5),
      surface: Color(0xFFFFFFFF),
      surface2: Color(0xFFFADCEA),
      textColor: Color(0xFF341A29),
      mutedColor: Color(0xFF8E6D7F),
      primary: Color(0xFFE0509A),
      onPrimary: Color(0xFFFFFFFF),
      accents: [Color(0xFFE0509A), Color(0xFF8B7CF6), Color(0xFF2FBF8A), Color(0xFFF5A524)],
      icon: Icons.local_florist_rounded,
    ),
    NoesisThemeOption(
      id: 'esmeralda',
      name: 'Esmeralda',
      tag: 'Escuro · análogas verdes',
      description: 'Preto-esverdeado profundo com esmeralda no destaque transmitindo foco e evolução constante.',
      mode: ThemeMode.dark,
      bg: Color(0xFF0A1512),
      surface: Color(0xFF12211C),
      surface2: Color(0xFF1D352C),
      textColor: Color(0xFFE6F5EE),
      mutedColor: Color(0xFF86A89A),
      primary: Color(0xFF34D399),
      onPrimary: Color(0xFF06241A),
      accents: [Color(0xFF34D399), Color(0xFFFBBF24), Color(0xFFF472B6), Color(0xFF60A5FA)],
      icon: Icons.diamond_rounded,
    ),
    NoesisThemeOption(
      id: 'crepusculo',
      name: 'Crepúsculo',
      tag: 'Escuro · split-complementar',
      description: 'Roxo-berinjela profundo com rosa vibrante, âmbar e ciano nos gráficos. Expressivo e ousado.',
      mode: ThemeMode.dark,
      bg: Color(0xFF1A0F2E),
      surface: Color(0xFF251640),
      surface2: Color(0xFF36205C),
      textColor: Color(0xFFF3EAFF),
      mutedColor: Color(0xFFB09BD0),
      primary: Color(0xFFFF7AB6),
      onPrimary: Color(0xFF2A0B1E),
      accents: [Color(0xFFFF7AB6), Color(0xFFFFB454), Color(0xFF7DD3FC), Color(0xFFA78BFA)],
      icon: Icons.wb_twilight_rounded,
    ),
    NoesisThemeOption(
      id: 'nordico',
      name: 'Nórdico',
      tag: 'Claro · neutro + acentos',
      description: 'Cinza-azulado frio com ardósia sóbria e profissional, destacando dados e gráficos com clareza.',
      mode: ThemeMode.light,
      bg: Color(0xFFF0F2F6),
      surface: Color(0xFFFFFFFF),
      surface2: Color(0xFFE1E5EC),
      textColor: Color(0xFF1B2430),
      mutedColor: Color(0xFF667385),
      primary: Color(0xFF33415C),
      onPrimary: Color(0xFFFFFFFF),
      accents: [Color(0xFF4F6BED), Color(0xFF2FB5A0), Color(0xFFF2A33A), Color(0xFFE5677D)],
      icon: Icons.ac_unit_rounded,
    ),
  ];

  static final ValueNotifier<String> activeThemeIdNotifier =
      ValueNotifier<String>('soft_clay_nevoa');

  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

  static bool get isDarkMode => themeModeNotifier.value == ThemeMode.dark;

  static NoesisThemeOption get currentTheme {
    final id = activeThemeIdNotifier.value;
    return availableThemes.firstWhere(
      (t) => t.id == id,
      orElse: () => availableThemes.first,
    );
  }

  static void setThemeMode(ThemeMode mode) {
    if (themeModeNotifier.value != mode) {
      themeModeNotifier.value = mode;
    }
  }

  static Color lastTransitionBgColor = AsterConstants.bgNevoa;

  static void selectThemeOption(String themeId) {
    final prev = currentTheme;
    final option = availableThemes.firstWhere(
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
      ),
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
        ),
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
        hintStyle: GoogleFonts.manrope(color: opt.mutedColor.withValues(alpha: 0.7), fontSize: 13),
        labelStyle: GoogleFonts.manrope(color: opt.mutedColor, fontSize: 13),
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
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: dividerCol,
        thickness: 1,
        space: 1,
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
      ),
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
        ),
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
        hintStyle: GoogleFonts.manrope(color: AsterConstants.textFaintDark, fontSize: 13),
        labelStyle: GoogleFonts.manrope(color: AsterConstants.textMutedDark, fontSize: 13),
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
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AsterConstants.surfaceInsetDark,
        thickness: 1,
        space: 1,
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

/// Espaçador horizontal responsivo exibido apenas no topo das telas quando o menu lateral
/// está recolhido em telas largas, mantendo botões de voltar e títulos alinhados ao lado do ícone.
class NoesisCollapsedMenuSpacer extends StatelessWidget {
  const NoesisCollapsedMenuSpacer({super.key, this.width = 84});

  final double width;

  @override
  Widget build(BuildContext context) {
    if (width <= 0) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: AsterTheme.sidebarCollapsedNotifier,
      builder: (context, isCollapsed, _) {
        final isWide = MediaQuery.sizeOf(context).width >= 900;
        return SizedBox(width: (isWide && isCollapsed) ? width : 0);
      },
    );
  }
}
