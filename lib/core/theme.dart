import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart' show GoogleFonts;
import 'constants.dart';

class AsterTheme {
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

  static bool get isDarkMode => themeModeNotifier.value == ThemeMode.dark;

  static void setThemeMode(ThemeMode mode) {
    themeModeNotifier.value = mode;
  }

  static ThemeData get softClayTheme {
    return ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      highlightColor: Colors.transparent,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AsterConstants.bgNevoa,
      primaryColor: AsterConstants.lavanda,
      colorScheme: const ColorScheme.light(
        primary: AsterConstants.lavanda,
        secondary: AsterConstants.menta,
        surface: AsterConstants.surfaceCard,
        error: AsterConstants.coral,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AsterConstants.textDark,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.manrope(
          color: AsterConstants.textDark,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        displayMedium: GoogleFonts.manrope(
          color: AsterConstants.textDark,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
        titleLarge: GoogleFonts.manrope(
          color: AsterConstants.textDark,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: GoogleFonts.manrope(
          color: AsterConstants.textDark,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: GoogleFonts.manrope(
          color: AsterConstants.textDark,
          fontSize: 15,
        ),
        bodyMedium: GoogleFonts.manrope(
          color: AsterConstants.textDark,
          fontSize: 14,
        ),
        bodySmall: GoogleFonts.manrope(
          color: AsterConstants.textMuted,
          fontSize: 12,
        ),
      ),
      cardTheme: CardThemeData(
        color: AsterConstants.surfaceCard,
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
          color: AsterConstants.textDark,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: AsterConstants.textDark),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AsterConstants.surfaceAlt,
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
        hintStyle: GoogleFonts.manrope(color: AsterConstants.textFaint, fontSize: 13),
        labelStyle: GoogleFonts.manrope(color: AsterConstants.textMuted, fontSize: 13),
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
        color: AsterConstants.surfaceInset,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    const bgDark = Color(0xFF13141F);
    const surfaceCardDark = Color(0xFF1D1F2E);
    const surfaceAltDark = Color(0xFF26283B);
    const textLight = Color(0xFFF1F2F8);
    const textMutedDark = Color(0xFF9093B5);

    return ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      highlightColor: Colors.transparent,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: AsterConstants.lavanda,
      colorScheme: const ColorScheme.dark(
        primary: AsterConstants.lavanda,
        secondary: AsterConstants.menta,
        surface: surfaceCardDark,
        error: AsterConstants.coral,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textLight,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.manrope(color: textLight, fontWeight: FontWeight.w800, letterSpacing: -0.8),
        displayMedium: GoogleFonts.manrope(color: textLight, fontWeight: FontWeight.w800, letterSpacing: -0.6),
        titleLarge: GoogleFonts.manrope(color: textLight, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleMedium: GoogleFonts.manrope(color: textLight, fontWeight: FontWeight.w700),
        bodyLarge: GoogleFonts.manrope(color: textLight, fontSize: 15),
        bodyMedium: GoogleFonts.manrope(color: textLight, fontSize: 14),
        bodySmall: GoogleFonts.manrope(color: textMutedDark, fontSize: 12),
      ),
      cardTheme: CardThemeData(
        color: surfaceCardDark,
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
        titleTextStyle: GoogleFonts.manrope(color: textLight, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
        iconTheme: const IconThemeData(color: textLight),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAltDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusMedium), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusMedium), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusMedium), borderSide: const BorderSide(color: AsterConstants.lavanda, width: 1.5)),
        hintStyle: GoogleFonts.manrope(color: textMutedDark.withValues(alpha: 0.6), fontSize: 13),
        labelStyle: GoogleFonts.manrope(color: textMutedDark, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AsterConstants.lavanda,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusMedium)),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF282A3E),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF13141F) : AsterConstants.bgNevoa;

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
                    isDark ? const Color(0x287C6CF0) : const Color(0x1F7C6CF0), // 12-16% Lavanda
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
                              isDark ? const Color(0x283CCF9A) : const Color(0x1F3CCF9A), // 12-16% Menta
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

/// Cartão Soft Clay Oficial com Cantos de 28px e Zero Bordas
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = color ?? (isDark ? const Color(0xFF1D1F2E) : AsterConstants.surfaceCard);
    final defaultShadow = useListShadow ? AsterConstants.clayListShadow : AsterConstants.clayShadow;

    final decoration = BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: shadow ?? (isDark
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ]
          : defaultShadow),
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

/// Botão Primário Soft Clay com Sombra Suave
class SoftClayPillButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final bool isSecondary;
  final EdgeInsetsGeometry padding;

  const SoftClayPillButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.color = AsterConstants.lavanda,
    this.textColor = Colors.white,
    this.isSecondary = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    if (isSecondary) {
      return Container(
        decoration: BoxDecoration(
          color: AsterConstants.surfaceAlt,
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          boxShadow: AsterConstants.claySubtleShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
            child: Padding(
              padding: padding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: AsterConstants.textDark),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AsterConstants.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        boxShadow: AsterConstants.primaryButtonShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          child: Padding(
            padding: padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: textColor),
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
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
