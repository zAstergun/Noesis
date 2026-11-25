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

/// Logo vetorial oficial do Noesis sincronizado com as cores do tema ativo.
class NoesisLogo extends StatelessWidget {
  const NoesisLogo({
    super.key,
    this.size = 36,
    this.withShadow = false,
  });

  final double size;
  final bool withShadow;

  /// Rasteriza o logo vetorial em PNG RGBA (usado para favicons/ícones).
  static Future<Uint8List?> renderPngBytes(int pixelSize, {NoesisThemeOption? themeOption}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final palette = NoesisLogoPalette.forTheme(themeOption ?? AsterTheme.currentTheme);
    _NoesisLogoPainter(palette: palette).paint(
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
    return ValueListenableBuilder<String>(
      valueListenable: AsterTheme.activeThemeIdNotifier,
      builder: (context, _, _) {
        final themeOption = AsterTheme.currentTheme;
        final palette = NoesisLogoPalette.forTheme(themeOption);

        final painter = CustomPaint(
          size: Size(size, size),
          painter: _NoesisLogoPainter(palette: palette),
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
      },
    );
  }
}

class _NoesisLogoPainter extends CustomPainter {
  const _NoesisLogoPainter({required this.palette});

  final NoesisLogoPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 512.0;
    final sy = size.height / 512.0;

    canvas.save();
    canvas.scale(sx, sy);

    // Fundo com gradiente arredondado adaptado ao tema ativo
    final bgRect = const Rect.fromLTWH(0, 0, 512, 512);
    final bgRRect = RRect.fromRectAndRadius(bgRect, const Radius.circular(128));
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [palette.bgTopLeft, palette.bgBottomRight],
      ).createShader(bgRect);
    canvas.drawRRect(bgRRect, bgPaint);

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

    // Raios superiores adaptados às cores de destaque do tema
    final rayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      const Offset(166, 132),
      const Offset(146, 98),
      rayPaint..color = palette.rayLeft,
    );
    canvas.drawLine(
      const Offset(256, 110),
      const Offset(256, 68),
      rayPaint..color = palette.rayCenter,
    );
    canvas.drawLine(
      const Offset(346, 132),
      const Offset(366, 98),
      rayPaint..color = palette.rayRight,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NoesisLogoPainter oldDelegate) =>
      oldDelegate.palette.bgTopLeft != palette.bgTopLeft ||
      oldDelegate.palette.bgBottomRight != palette.bgBottomRight ||
      oldDelegate.palette.foreground != palette.foreground ||
      oldDelegate.palette.rayLeft != palette.rayLeft;
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
