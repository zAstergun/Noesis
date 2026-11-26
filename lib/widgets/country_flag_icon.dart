import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Renderiza bandeiras nacionais em Canvas vetorial para evitar que o Windows
/// exiba códigos textuais ("BR", "GB") no lugar de emojis regionais.
class CountryFlagIcon extends StatelessWidget {
  const CountryFlagIcon({
    super.key,
    required this.code,
    this.width = 28,
    this.height = 20,
    this.borderRadius = 4.5,
  });

  final String code;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.14),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular((borderRadius - 0.6).clamp(0.0, 12.0)),
        child: CustomPaint(
          size: Size(width, height),
          painter: _CountryFlagPainter(code: code.toLowerCase()),
        ),
      ),
    );
  }
}

class _CountryFlagPainter extends CustomPainter {
  const _CountryFlagPainter({required this.code});

  final String code;

  void _fillRect(Canvas canvas, double x, double y, double w, double h, Color c) {
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..color = c);
  }

  void _drawHorizontalBands(Canvas canvas, Size size, List<Color> colors, [List<double>? weights]) {
    final total = weights == null
        ? colors.length.toDouble()
        : weights.fold<double>(0, (a, b) => a + b);
    double y = 0;
    for (int i = 0; i < colors.length; i++) {
      final w = weights == null ? 1.0 : weights[i];
      final h = size.height * (w / total);
      _fillRect(canvas, 0, y, size.width, h + 0.5, colors[i]);
      y += h;
    }
  }

  void _drawVerticalBands(Canvas canvas, Size size, List<Color> colors, [List<double>? weights]) {
    final total = weights == null
        ? colors.length.toDouble()
        : weights.fold<double>(0, (a, b) => a + b);
    double x = 0;
    for (int i = 0; i < colors.length; i++) {
      final w = weights == null ? 1.0 : weights[i];
      final bw = size.width * (w / total);
      _fillRect(canvas, x, 0, bw + 0.5, size.height, colors[i]);
      x += bw;
    }
  }

  void _drawStar(Canvas canvas, Offset center, double outerR, Color color, {double rotation = -math.pi / 2}) {
    final innerR = outerR * 0.382;
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final r = i.isEven ? outerR : innerR;
      final angle = rotation + (i * math.pi / 5);
      final pt = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    switch (code) {
      case 'br':
        _fillRect(canvas, 0, 0, w, h, const Color(0xFF009B3A));
        final diamond = Path()
          ..moveTo(w * 0.5, h * 0.12)
          ..lineTo(w * 0.88, h * 0.5)
          ..lineTo(w * 0.5, h * 0.88)
          ..lineTo(w * 0.12, h * 0.5)
          ..close();
        canvas.drawPath(diamond, Paint()..color = const Color(0xFFFEDF00));
        final r = h * 0.23;
        final center = Offset(w * 0.5, h * 0.5);
        canvas.drawCircle(center, r, Paint()..color = const Color(0xFF002776));
        canvas.save();
        canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r)));
        canvas.drawArc(
          Rect.fromCenter(center: Offset(w * 0.45, h * 0.72), width: r * 3.1, height: r * 1.9),
          math.pi * 1.15,
          math.pi * 0.7,
          false,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = (h * 0.065).clamp(1.0, 2.5),
        );
        canvas.restore();
        break;

      case 'en': // Reino Unido (GB)
        _fillRect(canvas, 0, 0, w, h, const Color(0xFF012169));
        final whiteDiag = Paint()
          ..color = Colors.white
          ..strokeWidth = h * 0.22;
        final redDiag = Paint()
          ..color = const Color(0xFFC8102E)
          ..strokeWidth = h * 0.10;
        canvas.drawLine(Offset.zero, Offset(w, h), whiteDiag);
        canvas.drawLine(Offset(0, h), Offset(w, 0), whiteDiag);
        canvas.drawLine(Offset.zero, Offset(w, h), redDiag);
        canvas.drawLine(Offset(0, h), Offset(w, 0), redDiag);
        // Cruz de São Jorge
        _fillRect(canvas, w * 0.40, 0, w * 0.20, h, Colors.white);
        _fillRect(canvas, 0, h * 0.36, w, h * 0.28, Colors.white);
        _fillRect(canvas, w * 0.44, 0, w * 0.12, h, const Color(0xFFC8102E));
        _fillRect(canvas, 0, h * 0.41, w, h * 0.18, const Color(0xFFC8102E));
        break;

      case 'es':
        _drawHorizontalBands(
          canvas,
          size,
          const [Color(0xFFAA151B), Color(0xFFF1BF00), Color(0xFFAA151B)],
          const [1, 2, 1],
        );
        // Brasão simplificado
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(w * 0.29, h * 0.5), width: w * 0.11, height: h * 0.26),
            const Radius.circular(1.5),
          ),
          Paint()..color = const Color(0xFFAA151B),
        );
        break;

      case 'jp':
        _fillRect(canvas, 0, 0, w, h, Colors.white);
        canvas.drawCircle(
          Offset(w * 0.5, h * 0.5),
          h * 0.29,
          Paint()..color = const Color(0xFFBC002D),
        );
        break;

      case 'cn':
        _fillRect(canvas, 0, 0, w, h, const Color(0xFFDE2910));
        const starCol = Color(0xFFFFDE00);
        _drawStar(canvas, Offset(w * 0.22, h * 0.34), h * 0.17, starCol);
        _drawStar(canvas, Offset(w * 0.38, h * 0.18), h * 0.055, starCol);
        _drawStar(canvas, Offset(w * 0.44, h * 0.30), h * 0.055, starCol);
        _drawStar(canvas, Offset(w * 0.44, h * 0.45), h * 0.055, starCol);
        _drawStar(canvas, Offset(w * 0.38, h * 0.56), h * 0.055, starCol);
        break;

      case 'kr':
        _fillRect(canvas, 0, 0, w, h, Colors.white);
        final r = h * 0.24;
        final c = Offset(w * 0.5, h * 0.5);
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          math.pi,
          math.pi,
          true,
          Paint()..color = const Color(0xFFCD2E3A),
        );
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          0,
          math.pi,
          true,
          Paint()..color = const Color(0xFF0047A0),
        );
        // Trigramas nos 4 cantos
        final barPaint = Paint()
          ..color = const Color(0xFF111111)
          ..strokeWidth = (h * 0.075).clamp(1.0, 2.2)
          ..strokeCap = StrokeCap.butt;
        void drawCornerBars(double cx, double cy, double angle) {
          canvas.save();
          canvas.translate(cx, cy);
          canvas.rotate(angle);
          for (final dy in [-h * 0.07, 0.0, h * 0.07]) {
            canvas.drawLine(Offset(-w * 0.07, dy), Offset(w * 0.07, dy), barPaint);
          }
          canvas.restore();
        }
        drawCornerBars(w * 0.21, h * 0.24, -0.58);
        drawCornerBars(w * 0.79, h * 0.24, 0.58);
        drawCornerBars(w * 0.21, h * 0.76, 0.58);
        drawCornerBars(w * 0.79, h * 0.76, -0.58);
        break;

      case 'vn':
        _fillRect(canvas, 0, 0, w, h, const Color(0xFFDA251D));
        _drawStar(canvas, Offset(w * 0.5, h * 0.52), h * 0.27, const Color(0xFFFFFF00));
        break;

      case 'id':
        _drawHorizontalBands(canvas, size, const [Color(0xFFCE1126), Colors.white]);
        break;

      case 'fr':
        _drawVerticalBands(canvas, size, const [Color(0xFF002395), Colors.white, Color(0xFFED2939)]);
        break;

      case 'de':
        _drawHorizontalBands(canvas, size, const [Color(0xFF111111), Color(0xFFDD0000), Color(0xFFFFCE00)]);
        break;

      case 'it':
        _drawVerticalBands(canvas, size, const [Color(0xFF009246), Colors.white, Color(0xFFCE2B37)]);
        break;

      case 'nl':
        _drawHorizontalBands(canvas, size, const [Color(0xFFAE1C28), Colors.white, Color(0xFF21468B)]);
        break;

      case 'ru':
        _drawHorizontalBands(canvas, size, const [Colors.white, Color(0xFF0039A6), Color(0xFFD52B1E)]);
        break;

      case 'ar': // Arábia Saudita (SA)
        _fillRect(canvas, 0, 0, w, h, const Color(0xFF006C35));
        final stroke = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = (h * 0.08).clamp(1.2, 2.2)
          ..strokeCap = StrokeCap.round;
        // Traço estilizado da caligrafia + espada abaixo
        canvas.drawLine(Offset(w * 0.24, h * 0.38), Offset(w * 0.76, h * 0.38), stroke);
        canvas.drawLine(Offset(w * 0.32, h * 0.48), Offset(w * 0.68, h * 0.48), stroke);
        canvas.drawLine(Offset(w * 0.26, h * 0.67), Offset(w * 0.74, h * 0.67), stroke);
        canvas.drawLine(Offset(w * 0.70, h * 0.62), Offset(w * 0.70, h * 0.72), stroke);
        break;

      case 'pt':
        _drawVerticalBands(
          canvas,
          size,
          const [Color(0xFF006600), Color(0xFFFF0000)],
          const [2, 3],
        );
        final emblemCenter = Offset(w * 0.40, h * 0.5);
        canvas.drawCircle(emblemCenter, h * 0.22, Paint()..color = const Color(0xFFFFFF00));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: emblemCenter, width: h * 0.20, height: h * 0.24),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xFFFF0000),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: emblemCenter, width: h * 0.11, height: h * 0.14),
            const Radius.circular(1),
          ),
          Paint()..color = Colors.white,
        );
        break;

      default:
        _fillRect(canvas, 0, 0, w, h, const Color(0xFF64748B));
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _CountryFlagPainter oldDelegate) => oldDelegate.code != code;
}
