import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

/// Paleta resolvida para desenhar o [NoesisLogo] em sincronia com o tema ativo.
class NoesisLogoPalette {
  const NoesisLogoPalette({
    required this.bgTopLeft,
    required this.bgBottomRight,
    required this.foreground,
    required this.irisRing,
    required this.pupil,
    required this.rayLeft,
    required this.rayCenter,
    required this.rayRight,
  });

  final Color bgTopLeft;
  final Color bgBottomRight;
  final Color foreground;
  final Color irisRing;
  final Color pupil;
  final Color rayLeft;
  final Color rayCenter;
  final Color rayRight;

  static NoesisLogoPalette forTheme(NoesisThemeOption option) {
    if (option.id == 'soft_clay_nevoa') {
      return const NoesisLogoPalette(
        bgTopLeft: Color(0xFF8B7CF6),
        bgBottomRight: Color(0xFF5B4BDB),
        foreground: Colors.white,
        irisRing: Color(0xFF8B7CF6),
        pupil: Color(0xFF5B4BDB),
        rayLeft: Color(0xFF3DD598),
        rayCenter: Color(0xFFF5A524),
        rayRight: Color(0xFFFF6B8A),
      );
    }

    final bgTop = option.primary;
    final bgBottom = Color.lerp(option.primary, Colors.black, 0.24)!;
    final fg = option.onPrimary;

    // Seleciona 3 cores de raio que contrastem bem e não se confundam com o fundo primário
    final distinctAccents = option.accents
        .where((c) => _colorDistance(c, option.primary) > 40)
        .toList();
    final ray1 = distinctAccents.isNotEmpty ? distinctAccents[0] : const Color(0xFF3DD598);
    final ray2 = distinctAccents.length > 1 ? distinctAccents[1] : const Color(0xFFF5A524);
    final ray3 = distinctAccents.length > 2 ? distinctAccents[2] : const Color(0xFFFF6B8A);

    return NoesisLogoPalette(
      bgTopLeft: bgTop,
      bgBottomRight: bgBottom,
      foreground: fg,
      irisRing: bgTop,
      pupil: bgBottom,
      rayLeft: ray1,
      rayCenter: ray2,
      rayRight: ray3,
    );
  }

  static int _colorDistance(Color a, Color b) {
    final dr = ((a.r - b.r) * 255).abs().round();
    final dg = ((a.g - b.g) * 255).abs().round();
    final db = ((a.b - b.b) * 255).abs().round();
    return dr + dg + db;
  }
}

/// Permite aplicar um tema de demonstração local (ex.: na Landing Page)
/// sem alterar o tema global do aplicativo.
class NoesisLogoThemeScope extends InheritedWidget {
  const NoesisLogoThemeScope({
    super.key,
    required this.themeOption,
    required super.child,
  });

  final NoesisThemeOption themeOption;

  static NoesisThemeOption? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<NoesisLogoThemeScope>()
        ?.themeOption;
  }

  @override
  bool updateShouldNotify(NoesisLogoThemeScope oldWidget) =>
      oldWidget.themeOption.id != themeOption.id;
}

/// Logo vetorial oficial do Noesis sincronizado com as cores do tema ativo.
class NoesisLogo extends StatelessWidget {
  const NoesisLogo({
    super.key,
    this.size = 36,
    this.withShadow = false,
    this.sparkProgress = 0.0,
  });

  final double size;
  final bool withShadow;
  final double sparkProgress;

  /// Rasteriza o logo vetorial em PNG RGBA (usado para favicons/ícones).
  static Future<Uint8List?> renderPngBytes(
    int pixelSize, {
    NoesisThemeOption? themeOption,
    bool roundedCorners = true,
    bool includeBackground = true,
    double contentScale = 1.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final palette = NoesisLogoPalette.forTheme(themeOption ?? AsterTheme.currentTheme);
    _NoesisLogoPainter(
      palette: palette,
      roundedCorners: roundedCorners,
      includeBackground: includeBackground,
      contentScale: contentScale,
    ).paint(
      canvas,
      Size(pixelSize.toDouble(), pixelSize.toDouble()),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(pixelSize, pixelSize);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final override = NoesisLogoThemeScope.maybeOf(context);
    if (override != null) {
      return _buildLogoForTheme(override);
    }
    return ValueListenableBuilder<String>(
      valueListenable: AsterTheme.activeThemeIdNotifier,
      builder: (context, _, _) => _buildLogoForTheme(AsterTheme.currentTheme),
    );
  }

  Widget _buildLogoForTheme(NoesisThemeOption themeOption) {
    final palette = NoesisLogoPalette.forTheme(themeOption);

    final painter = CustomPaint(
      size: Size(size, size),
      painter: _NoesisLogoPainter(
        palette: palette,
        sparkProgress: sparkProgress,
      ),
    );

    if (!withShadow) return painter;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.25),
        boxShadow: [
          BoxShadow(
            color: palette.bgBottomRight.withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: painter,
    );
  }
}

class _NoesisLogoPainter extends CustomPainter {
  const _NoesisLogoPainter({
    required this.palette,
    this.sparkProgress = 0.0,
    this.roundedCorners = true,
    this.includeBackground = true,
    this.contentScale = 1.0,
  });

  final NoesisLogoPalette palette;
  final double sparkProgress;
  final bool roundedCorners;
  final bool includeBackground;
  final double contentScale;

  double _pulseWindow(double t, double start, double duration) {
    if (t <= start || t >= start + duration) return 0.0;
    final local = (t - start) / duration;
    return math.sin(local * math.pi);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 512.0;
    final sy = size.height / 512.0;

    canvas.save();
    canvas.scale(sx, sy);

    // Fundo com gradiente arredondado adaptado ao tema ativo
    if (includeBackground) {
      final bgRect = const Rect.fromLTWH(0, 0, 512, 512);
      final bgPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.bgTopLeft, palette.bgBottomRight],
        ).createShader(bgRect);
      if (roundedCorners) {
        final bgRRect = RRect.fromRectAndRadius(bgRect, const Radius.circular(128));
        canvas.drawRRect(bgRRect, bgPaint);
      } else {
        canvas.drawRect(bgRect, bgPaint);
      }
    }

    if (contentScale != 1.0) {
      canvas.translate(256, 256);
      canvas.scale(contentScale, contentScale);
      canvas.translate(-256, -256);
    }

    // Piscada suave do olho durante a animação
    final blink = _pulseWindow(sparkProgress, 0.08, 0.30);
    final eyeOpenY = 1.0 - (0.86 * blink);

    canvas.save();
    if (blink > 0.001) {
      canvas.translate(256, 276);
      canvas.scale(1.0, eyeOpenY);
      canvas.translate(-256, -276);
    }

    // Contorno estilizado do olho
    final eyePath = Path()
      ..moveTo(72, 276)
      ..cubicTo(132, 190, 204, 160, 256, 160)
      ..cubicTo(308, 160, 380, 190, 440, 276)
      ..cubicTo(380, 362, 308, 392, 256, 392)
      ..cubicTo(204, 392, 132, 362, 72, 276)
      ..close();
    final eyePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = palette.foreground
      ..strokeWidth = 30
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(eyePath, eyePaint);

    // Íris e pupila centradas em (256, 276)
    const center = Offset(256, 276);
    canvas.drawCircle(center, 82, Paint()..color = palette.foreground);
    canvas.drawCircle(
      center,
      58,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = palette.irisRing
        ..strokeWidth = 10,
    );
    canvas.drawCircle(center, 38, Paint()..color = palette.pupil);
    canvas.drawCircle(
      const Offset(270, 262),
      11,
      Paint()..color = palette.foreground,
    );
    canvas.restore();

    // Raios superiores com onda sequencial de faísca ao clicar
    void drawAnimatedRay(Offset p1, Offset p2, Color color, double pulse) {
      final dir = p2 - p1;
      final len = dir.distance;
      final unit = len > 0 ? dir / len : Offset.zero;
      final extendedTip = p2 + unit * (20.0 * pulse);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24 + (8.0 * pulse)
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(color, Colors.white, 0.35 * pulse)!;
      canvas.drawLine(p1, extendedTip, paint);
    }

    drawAnimatedRay(
      const Offset(166, 132),
      const Offset(146, 98),
      palette.rayLeft,
      _pulseWindow(sparkProgress, 0.24, 0.40),
    );
    drawAnimatedRay(
      const Offset(256, 110),
      const Offset(256, 68),
      palette.rayCenter,
      _pulseWindow(sparkProgress, 0.34, 0.40),
    );
    drawAnimatedRay(
      const Offset(346, 132),
      const Offset(366, 98),
      palette.rayRight,
      _pulseWindow(sparkProgress, 0.44, 0.40),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NoesisLogoPainter oldDelegate) =>
      oldDelegate.sparkProgress != sparkProgress ||
      oldDelegate.palette.bgTopLeft != palette.bgTopLeft ||
      oldDelegate.palette.bgBottomRight != palette.bgBottomRight ||
      oldDelegate.palette.foreground != palette.foreground ||
      oldDelegate.palette.rayLeft != palette.rayLeft;
}

/// Bloco interativo da marca Noesis: ao clicar, dispara efeito de piscada,
/// onda nos raios, bounce tátil e brilho no wordmark, além de executar [onTap].
class NoesisInteractiveBrand extends StatefulWidget {
  const NoesisInteractiveBrand({
    super.key,
    required this.onTap,
    this.logoSize = 30,
    this.fontSize = 18.5,
    this.spacing = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    this.trailing,
  });

  final VoidCallback? onTap;
  final double logoSize;
  final double fontSize;
  final double spacing;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;

  @override
  State<NoesisInteractiveBrand> createState() => _NoesisInteractiveBrandState();
}

class _NoesisInteractiveBrandState extends State<NoesisInteractiveBrand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerTap() {
    _controller.forward(from: 0.0);
    widget.onTap?.call();
  }

  double _bounceScale(double t) {
    if (t <= 0.0 || t >= 1.0) return 1.0;
    if (t < 0.16) {
      return 1.0 - (0.09 * (t / 0.16));
    }
    if (t < 0.38) {
      final k = (t - 0.16) / 0.22;
      return 0.91 + (0.18 * math.sin(k * math.pi * 0.5));
    }
    if (t < 0.62) {
      final k = (t - 0.38) / 0.24;
      return 1.09 - (0.09 * k);
    }
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AsterTheme.primary(context);
    final hoverBg = primary.withValues(alpha: isDark ? 0.12 : 0.08);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _triggerTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: _hovered ? hoverBg : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final scale = _bounceScale(t);
              final shimmerActive = t > 0.12 && t < 0.96;
              final shimmerPos = ((t - 0.12) / 0.84).clamp(0.0, 1.0);

              Widget wordmark = NoesisWordmark(fontSize: widget.fontSize);
              if (shimmerActive) {
                final slide = -0.6 + (shimmerPos * 2.2);
                wordmark = ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      begin: Alignment(slide - 0.45, -0.3),
                      end: Alignment(slide + 0.45, 0.3),
                      colors: [
                        Colors.transparent,
                        primary.withValues(alpha: 0.78),
                        Colors.white.withValues(alpha: 0.85),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.38, 0.54, 1.0],
                    ).createShader(bounds);
                  },
                  child: wordmark,
                );
              }

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: scale,
                    child: NoesisLogo(
                      size: widget.logoSize,
                      withShadow: true,
                      sparkProgress: t,
                    ),
                  ),
                  SizedBox(width: widget.spacing),
                  wordmark,
                  if (widget.trailing != null) ...[
                    const SizedBox(width: 8),
                    widget.trailing!,
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Wordmark tipográfico oficial do Noesis com Space Grotesk (geométrico e cognitivo).
class NoesisWordmark extends StatelessWidget {
  const NoesisWordmark({
    super.key,
    this.fontSize = 21,
    this.textAlign,
    this.color,
  });

  final double fontSize;
  final TextAlign? textAlign;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Noesis',
      textAlign: textAlign,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.fade,
      style: GoogleFonts.spaceGrotesk(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.65,
        height: 1.05,
        color: color ?? AsterTheme.text(context),
      ),
    );
  }
}
