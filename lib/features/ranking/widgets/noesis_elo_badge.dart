import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/ranking_league_model.dart';

/// Emblema vetorial progressivo exclusivo dos 8 elos da Escala Noética
/// (`Faísca` → `Vigília` → `Logos` → `Síntese` → `Episteme` → `Ápice` → `Sophia` → `Noesis`).
class NoesisEloBadge extends StatelessWidget {
  const NoesisEloBadge({
    super.key,
    required this.tier,
    this.size = 48,
    this.locked = false,
    this.highlighted = false,
  });

  final RankingEloTier tier;
  final double size;
  final bool locked;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final body = CustomPaint(
      size: Size.square(size),
      painter: _NoesisEloCrestPainter(
        tierIndex: tier.index,
        badgeColor: tier.badgeColor,
        accentColor: tier.accentColor,
        locked: locked,
        isDark: isDark,
      ),
    );

    if (!highlighted || locked) return body;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: tier.badgeColor.withValues(alpha: isDark ? 0.42 : 0.34),
            blurRadius: size * 0.34,
            offset: Offset(0, size * 0.08),
            spreadRadius: -size * 0.08,
          ),
        ],
      ),
      child: body,
    );
  }
}

class _NoesisEloCrestPainter extends CustomPainter {
  const _NoesisEloCrestPainter({
    required this.tierIndex,
    required this.badgeColor,
    required this.accentColor,
    required this.locked,
    required this.isDark,
  });

  final int tierIndex;
  final Color badgeColor;
  final Color accentColor;
  final bool locked;
  final bool isDark;

  Color _tone(Color c, {double lockedDesaturate = 0.45}) {
    if (!locked) return c;
    final gray = isDark ? const Color(0xFF4B506B) : const Color(0xFF9EA4BE);
    return Color.lerp(c, gray, lockedDesaturate)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = Offset(w * 0.5, h * 0.52);
    final r = w * (tierIndex >= 5 ? 0.34 : 0.38);

    final lightStop = _tone(Color.lerp(badgeColor, Colors.white, 0.38)!);
    final midStop = _tone(badgeColor);
    final darkStop = _tone(accentColor);
    final rimGold = _tone(
      tierIndex >= 6
          ? const Color(0xFFFDE047)
          : Color.lerp(badgeColor, Colors.white, 0.55)!,
      lockedDesaturate: 0.55,
    );

    // ─── 1. Asas / Louros / Coroa progressivos (Níveis 4..8) ───
    if (tierIndex >= 4) {
      _drawPrestigedBackdrop(canvas, w, h, c, r, midStop, darkStop, rimGold);
    }

    // ─── 2. Silhueta principal da insígnia (evolui por elo) ───
    final Path framePath = _buildCrestPath(c, r, tierIndex);

    // Sombra suave da peça
    if (!locked) {
      canvas.drawPath(
        framePath.shift(Offset(0, h * 0.04)),
        Paint()
          ..color = darkStop.withValues(alpha: 0.28)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.06),
      );
    }

    // Preenchimento metálico/cristalino com gradiente
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [lightStop, midStop, darkStop],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawPath(framePath, bodyPaint);

    // Chanfro interno / profundidade
    final innerPath = _buildCrestPath(c, r * 0.78, tierIndex);
    canvas.drawPath(
      innerPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
          colors: [
            Colors.black.withValues(alpha: locked ? 0.08 : 0.16),
            Colors.white.withValues(alpha: locked ? 0.12 : 0.24),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.8)),
    );

    // Borda biselada externa
    canvas.drawPath(
      framePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (w * 0.042).clamp(1.0, 2.6)
        ..color = rimGold.withValues(alpha: locked ? 0.55 : 0.92),
    );

    // Reflexo especular no topo esquerdo
    canvas.save();
    canvas.clipPath(framePath);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx - r * 0.22, c.dy - r * 0.48),
        width: r * 1.15,
        height: r * 0.55,
      ),
      Paint()..color = Colors.white.withValues(alpha: locked ? 0.10 : 0.22),
    );
    canvas.restore();

    // ─── 3. Símbolo central exclusivo de cada Elo ───
    _drawCentralGlyph(canvas, c, r * 0.56, w);
  }

  void _drawPrestigedBackdrop(
    Canvas canvas,
    double w,
    double h,
    Offset c,
    double r,
    Color midStop,
    Color darkStop,
    Color rimGold,
  ) {
    final wingPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [rimGold, midStop],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    if (tierIndex == 4) {
      // Episteme: dois louros laterais
      for (final sign in [-1.0, 1.0]) {
        final path = Path()
          ..moveTo(c.dx + sign * r * 0.82, c.dy + r * 0.42)
          ..quadraticBezierTo(
            c.dx + sign * r * 1.28,
            c.dy + r * 0.05,
            c.dx + sign * r * 1.05,
            c.dy - r * 0.55,
          )
          ..quadraticBezierTo(
            c.dx + sign * r * 0.98,
            c.dy - r * 0.1,
            c.dx + sign * r * 0.78,
            c.dy + r * 0.24,
          )
          ..close();
        canvas.drawPath(path, wingPaint);
      }
    } else if (tierIndex >= 5) {
      // Ápice, Sophia e Noesis: par de asas angulares (duplas no Noesis)
      final feathers = tierIndex == 7 ? 3 : 2;
      for (final sign in [-1.0, 1.0]) {
        for (int f = 0; f < feathers; f++) {
          final yOff = -r * (0.38 - f * 0.26);
          final reach = r * (1.38 - f * 0.16);
          final wing = Path()
            ..moveTo(c.dx + sign * r * 0.55, c.dy + yOff + r * 0.16)
            ..lineTo(c.dx + sign * reach, c.dy + yOff - r * 0.22)
            ..lineTo(c.dx + sign * (reach * 0.86), c.dy + yOff + r * 0.14)
            ..lineTo(c.dx + sign * r * 0.55, c.dy + yOff + r * 0.30)
            ..close();
          canvas.drawPath(wing, wingPaint);
        }
      }
    }

    // Coroa superior para Sophia (6) e tríplice coroa para Noesis (7)
    if (tierIndex >= 6) {
      final crown = Path();
      final topY = c.dy - r * 0.86;
      if (tierIndex == 6) {
        crown
          ..moveTo(c.dx - r * 0.36, topY + r * 0.12)
          ..lineTo(c.dx, topY - r * 0.34)
          ..lineTo(c.dx + r * 0.36, topY + r * 0.12)
          ..close();
      } else {
        crown
          ..moveTo(c.dx - r * 0.48, topY + r * 0.16)
          ..lineTo(c.dx - r * 0.34, topY - r * 0.24)
          ..lineTo(c.dx - r * 0.14, topY + r * 0.02)
          ..lineTo(c.dx, topY - r * 0.42)
          ..lineTo(c.dx + r * 0.14, topY + r * 0.02)
          ..lineTo(c.dx + r * 0.34, topY - r * 0.24)
          ..lineTo(c.dx + r * 0.48, topY + r * 0.16)
          ..close();
      }
      canvas.drawPath(crown, Paint()..color = rimGold);
    }
  }

  Path _buildCrestPath(Offset c, double r, int idx) {
    switch (idx) {
      case 0:
        // Faísca: medalhão circular facetado com 8 chanfros suaves
        return _regularPolygon(c, r, 8, rotationOffset: math.pi / 8);
      case 1:
        // Vigília: escudo clássico pontiagudo
        return Path()
          ..moveTo(c.dx - r * 0.82, c.dy - r * 0.72)
          ..quadraticBezierTo(c.dx, c.dy - r * 0.96, c.dx + r * 0.82, c.dy - r * 0.72)
          ..lineTo(c.dx + r * 0.84, c.dy + r * 0.05)
          ..quadraticBezierTo(c.dx + r * 0.65, c.dy + r * 0.70, c.dx, c.dy + r * 0.96)
          ..quadraticBezierTo(c.dx - r * 0.65, c.dy + r * 0.70, c.dx - r * 0.84, c.dy + r * 0.05)
          ..close();
      case 2:
        // Logos: escudo diamante real
        return Path()
          ..moveTo(c.dx, c.dy - r * 0.95)
          ..lineTo(c.dx + r * 0.86, c.dy - r * 0.34)
          ..lineTo(c.dx + r * 0.62, c.dy + r * 0.62)
          ..lineTo(c.dx, c.dy + r * 0.98)
          ..lineTo(c.dx - r * 0.62, c.dy + r * 0.62)
          ..lineTo(c.dx - r * 0.86, c.dy - r * 0.34)
          ..close();
      case 3:
        // Síntese: hexágono cristalino vertical
        return _regularPolygon(c, r, 6, rotationOffset: -math.pi / 2);
      case 4:
        // Episteme: octógono prismático
        return _regularPolygon(c, r, 8, rotationOffset: 0);
      case 5:
        // Ápice: escudo ponta-de-lança ascendente
        return Path()
          ..moveTo(c.dx, c.dy - r * 1.02)
          ..lineTo(c.dx + r * 0.84, c.dy - r * 0.25)
          ..lineTo(c.dx + r * 0.56, c.dy + r * 0.78)
          ..lineTo(c.dx, c.dy + r * 0.98)
          ..lineTo(c.dx - r * 0.56, c.dy + r * 0.78)
          ..lineTo(c.dx - r * 0.84, c.dy - r * 0.25)
          ..close();
      case 6:
        // Sophia: estrela-brasão solar de 6 pontas suaves
        return _starPolygon(c, r * 1.02, r * 0.78, 6, rotationOffset: -math.pi / 2);
      case 7:
      default:
        // Noesis: diamante-brasão imperial facetado
        return Path()
          ..moveTo(c.dx, c.dy - r * 1.02)
          ..lineTo(c.dx + r * 0.88, c.dy - r * 0.38)
          ..lineTo(c.dx + r * 0.74, c.dy + r * 0.42)
          ..lineTo(c.dx, c.dy + r * 1.04)
          ..lineTo(c.dx - r * 0.74, c.dy + r * 0.42)
          ..lineTo(c.dx - r * 0.88, c.dy - r * 0.38)
          ..close();
    }
  }

  Path _regularPolygon(Offset c, double r, int sides, {double rotationOffset = 0}) {
    final path = Path();
    for (int i = 0; i < sides; i++) {
      final angle = rotationOffset + (2 * math.pi * i / sides);
      final pt = Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    return path;
  }

  Path _starPolygon(
    Offset c,
    double outerR,
    double innerR,
    int points, {
    double rotationOffset = 0,
  }) {
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? outerR : innerR;
      final angle = rotationOffset + (math.pi * i / points);
      final pt = Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    return path;
  }

  void _drawCentralGlyph(Canvas canvas, Offset c, double gr, double fullW) {
    final glyphColor = Colors.white.withValues(alpha: locked ? 0.78 : 0.96);
    final fillPaint = Paint()..color = glyphColor;
    final strokePaint = Paint()
      ..color = glyphColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = (fullW * 0.048).clamp(1.2, 2.6)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (tierIndex) {
      case 0:
        // Faísca: raio dinâmico facetado
        final bolt = Path()
          ..moveTo(c.dx + gr * 0.14, c.dy - gr * 0.95)
          ..lineTo(c.dx - gr * 0.62, c.dy + gr * 0.08)
          ..lineTo(c.dx - gr * 0.02, c.dy + gr * 0.08)
          ..lineTo(c.dx - gr * 0.16, c.dy + gr * 0.95)
          ..lineTo(c.dx + gr * 0.62, c.dy - gr * 0.10)
          ..lineTo(c.dx + gr * 0.02, c.dy - gr * 0.10)
          ..close();
        canvas.drawPath(bolt, fillPaint);
      case 1:
        // Vigília: olho sentinela estilizado
        final eye = Path()
          ..moveTo(c.dx - gr * 0.92, c.dy)
          ..quadraticBezierTo(c.dx, c.dy - gr * 0.72, c.dx + gr * 0.92, c.dy)
          ..quadraticBezierTo(c.dx, c.dy + gr * 0.72, c.dx - gr * 0.92, c.dy)
          ..close();
        canvas.drawPath(eye, strokePaint);
        canvas.drawCircle(c, gr * 0.30, fillPaint);
      case 2:
        // Logos: livro aberto / compasso geométrico
        final pages = Path()
          ..moveTo(c.dx, c.dy - gr * 0.35)
          ..lineTo(c.dx - gr * 0.85, c.dy - gr * 0.65)
          ..lineTo(c.dx - gr * 0.85, c.dy + gr * 0.45)
          ..lineTo(c.dx, c.dy + gr * 0.72)
          ..lineTo(c.dx + gr * 0.85, c.dy + gr * 0.45)
          ..lineTo(c.dx + gr * 0.85, c.dy - gr * 0.65)
          ..close();
        canvas.drawPath(pages, strokePaint);
        canvas.drawLine(Offset(c.dx, c.dy - gr * 0.35), Offset(c.dx, c.dy + gr * 0.72), strokePaint);
      case 3:
        // Síntese: rede tríade conectada
        final top = Offset(c.dx, c.dy - gr * 0.72);
        final left = Offset(c.dx - gr * 0.68, c.dy + gr * 0.52);
        final right = Offset(c.dx + gr * 0.68, c.dy + gr * 0.52);
        canvas.drawLine(top, left, strokePaint);
        canvas.drawLine(left, right, strokePaint);
        canvas.drawLine(right, top, strokePaint);
        for (final pt in [top, left, right]) {
          canvas.drawCircle(pt, gr * 0.24, fillPaint);
        }
      case 4:
        // Episteme: estrela de 4 pontas + anel orbital
        canvas.drawCircle(c, gr * 0.66, strokePaint);
        canvas.drawPath(_starPolygon(c, gr * 0.82, gr * 0.26, 4), fillPaint);
      case 5:
        // Ápice: dupla divisa ascendente + losango no topo
        for (final dy in [-0.12, 0.34]) {
          final chev = Path()
            ..moveTo(c.dx - gr * 0.74, c.dy + gr * (dy + 0.38))
            ..lineTo(c.dx, c.dy + gr * (dy - 0.34))
            ..lineTo(c.dx + gr * 0.74, c.dy + gr * (dy + 0.38));
          canvas.drawPath(chev, strokePaint);
        }
        canvas.drawPath(_regularPolygon(Offset(c.dx, c.dy - gr * 0.64), gr * 0.22, 4), fillPaint);
      case 6:
        // Sophia: estrela solar de 6 pontas + núcleo brilhante
        canvas.drawPath(_starPolygon(c, gr * 0.90, gr * 0.34, 6), fillPaint);
        canvas.drawCircle(
          c,
          gr * 0.22,
          Paint()..color = _tone(accentColor),
        );
      case 7:
      default:
        // Noesis: Olho-Prisma característico do Noesis com raios dourados
        final eye = Path()
          ..moveTo(c.dx - gr * 0.94, c.dy + gr * 0.05)
          ..quadraticBezierTo(c.dx, c.dy - gr * 0.66, c.dx + gr * 0.94, c.dy + gr * 0.05)
          ..quadraticBezierTo(c.dx, c.dy + gr * 0.76, c.dx - gr * 0.94, c.dy + gr * 0.05)
          ..close();
        canvas.drawPath(eye, strokePaint);
        canvas.drawPath(
          _regularPolygon(Offset(c.dx, c.dy + gr * 0.05), gr * 0.34, 4),
          Paint()..color = _tone(const Color(0xFFFDE047)),
        );
    }
  }

  @override
  bool shouldRepaint(covariant _NoesisEloCrestPainter oldDelegate) {
    return oldDelegate.tierIndex != tierIndex ||
        oldDelegate.badgeColor != badgeColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.locked != locked ||
        oldDelegate.isDark != isDark;
  }
}
