import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Ícone oficial da moeda **Insight** do Noesis (baseado em `assets/images/insight.svg`).
///
/// Representa a convergência de ideias: dois círculos em Lavanda (`#8B7CF6`) e
/// Menta (`#3DD598`) cuja interseção forma uma lente branca (`#FFFFFF`) com
/// núcleo em Violeta (`#5B4BDB`).
class InsightCoinIcon extends StatelessWidget {
  const InsightCoinIcon({
    super.key,
    this.size = 18,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Ícone Insight Noesis',
      child: SizedBox(
        width: size,
        height: size,
        child: const CustomPaint(
          painter: _InsightCoinPainter(),
        ),
      ),
    );
  }
}

class _InsightCoinPainter extends CustomPainter {
  const _InsightCoinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 64.0;
    final sy = size.height / 64.0;

    canvas.save();
    canvas.scale(sx, sy);

    const leftCenter = Offset(24, 32);
    const rightCenter = Offset(40, 32);
    const radius = 17.0;

    // Círculo esquerdo (#8B7CF6)
    canvas.drawCircle(
      leftCenter,
      radius,
      Paint()..color = const Color(0xFF8B7CF6),
    );

    // Círculo direito (#3DD598)
    canvas.drawCircle(
      rightCenter,
      radius,
      Paint()..color = const Color(0xFF3DD598),
    );

    // Interseção dos dois círculos preenchida em branco (#FFFFFF)
    final leftClip = Path()
      ..addOval(Rect.fromCircle(center: leftCenter, radius: radius));
    canvas.save();
    canvas.clipPath(leftClip);
    canvas.drawCircle(
      rightCenter,
      radius,
      Paint()..color = Colors.white,
    );
    canvas.restore();

    // Núcleo de convergência (#5B4BDB)
    canvas.drawCircle(
      const Offset(32, 32),
      4.5,
      Paint()..color = const Color(0xFF5B4BDB),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _InsightCoinPainter oldDelegate) => false;
}

/// Ícone vetorial exclusivo do **Selo de Consistência** do Noesis.
///
/// Matriz de pontos no estilo do painel de consistência (estilo GitHub)
/// com um anel vazado em destaque no centro, simbolizando um dia protegido
/// sem quebrar a sequência de estudos.
class ConsistencySealIcon extends StatelessWidget {
  const ConsistencySealIcon({
    super.key,
    this.size = 24,
    this.accentColor,
  });

  final double size;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? const Color(0xFF22C55E);
    return Semantics(
      label: 'Ícone Selo de Consistência Noesis',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _ConsistencySealPainter(accent: accent),
        ),
      ),
    );
  }
}

/// Alias compatível para referências legadas.
typedef StreakShieldIcon = ConsistencySealIcon;

class _ConsistencySealPainter extends CustomPainter {
  const _ConsistencySealPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 64.0;
    final sy = size.height / 64.0;

    canvas.save();
    canvas.scale(sx, sy);

    // Tile arredondado suave combinando com a paleta de consistência
    final tile = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4, 4, 56, 56),
      const Radius.circular(16),
    );
    canvas.drawRRect(
      tile,
      Paint()..color = accent.withValues(alpha: 0.14),
    );
    canvas.drawRRect(
      tile,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = accent.withValues(alpha: 0.34),
    );

    // 4 pontos de consistência nos cantos (simulando grade de atividade)
    const corners = [
      Offset(18, 18),
      Offset(46, 18),
      Offset(18, 46),
      Offset(46, 46),
    ];
    for (int i = 0; i < corners.length; i++) {
      canvas.drawCircle(
        corners[i],
        3.8,
        Paint()..color = accent.withValues(alpha: i == 1 || i == 2 ? 0.55 : 0.28),
      );
    }

    // 4 pontos intermediários sutis
    const mids = [
      Offset(32, 16),
      Offset(16, 32),
      Offset(48, 32),
      Offset(32, 48),
    ];
    for (final p in mids) {
      canvas.drawCircle(
        p,
        3.1,
        Paint()..color = accent.withValues(alpha: 0.22),
      );
    }

    // Anel central vazado = Selo de dia protegido na consistência
    canvas.drawCircle(
      const Offset(32, 32),
      8.6,
      Paint()..color = accent.withValues(alpha: 0.18),
    );
    canvas.drawCircle(
      const Offset(32, 32),
      8.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.8
        ..color = accent,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ConsistencySealPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

/// Slot circular para representar cada **Selo de Consistência** guardado:
/// anel sólido/vazado em destaque quando preenchido, ou tracejado quando vazio.
class ConsistencySlotRing extends StatelessWidget {
  const ConsistencySlotRing({
    super.key,
    required this.filled,
    this.size = 24,
    this.activeColor = const Color(0xFF22C55E),
    this.emptyColor = const Color(0xFF94A3B8),
    this.strokeWidth = 2.1,
  });

  final bool filled;
  final double size;
  final Color activeColor;
  final Color emptyColor;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ConsistencySlotRingPainter(
          filled: filled,
          activeColor: activeColor,
          emptyColor: emptyColor,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _ConsistencySlotRingPainter extends CustomPainter {
  const _ConsistencySlotRingPainter({
    required this.filled,
    required this.activeColor,
    required this.emptyColor,
    required this.strokeWidth,
  });

  final bool filled;
  final Color activeColor;
  final Color emptyColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    if (filled) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = activeColor.withValues(alpha: 0.12),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = activeColor,
      );
      return;
    }

    // Círculo tracejado para vaga disponível
    final rect = Rect.fromCircle(center: center, radius: radius);
    const dashCount = 8;
    const step = (math.pi * 2) / dashCount;
    const sweep = step * 0.56;
    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth * 0.85
      ..color = emptyColor.withValues(alpha: 0.55);

    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(rect, i * step, sweep, false, dashPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConsistencySlotRingPainter oldDelegate) =>
      oldDelegate.filled != filled ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.emptyColor != emptyColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
