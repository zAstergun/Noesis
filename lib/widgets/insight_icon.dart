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
/// Grade 3×3 de blocos arredondados no estilo do novo heatmap de consistência
/// com um bloco protegido em destaque no centro, simbolizando um dia protegido
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
      Paint()..color = accent.withValues(alpha: 0.12),
    );
    canvas.drawRRect(
      tile,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = accent.withValues(alpha: 0.32),
    );

    // Grade 3×3 de blocos arredondados alinhada ao novo heatmap
    const double cell = 11.0;
    const double gap = 3.5;
    const double start = 12.0; // (64 - (3*11 + 2*3.5)) / 2
    const double radius = 3.2;

    const intensities = <List<double>>[
      [0.24, 0.46, 0.22],
      [0.40, 1.00, 0.72],
      [0.62, 0.30, 0.48],
    ];

    final fillPaint = Paint()..style = PaintingStyle.fill;
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        final rect = Rect.fromLTWH(
          start + col * (cell + gap),
          start + row * (cell + gap),
          cell,
          cell,
        );
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(radius));

        if (row == 1 && col == 1) {
          // Bloco central = Selo de dia protegido na consistência
          fillPaint.color = accent.withValues(alpha: 0.16);
          canvas.drawRRect(rrect, fillPaint);
          canvas.drawRRect(
            rrect,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.4
              ..color = accent,
          );
        } else {
          fillPaint.color = accent.withValues(alpha: intensities[row][col]);
          canvas.drawRRect(rrect, fillPaint);
        }
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ConsistencySealPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

/// Slot em bloco arredondado para representar cada **Selo de Consistência** guardado:
/// borda sólida com preenchimento suave quando preenchido, ou tracejado quando vazio.
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
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      math.max(0.0, size.width - strokeWidth),
      math.max(0.0, size.height - strokeWidth),
    );
    final cornerRadius = (size.width * 0.28).clamp(2.5, 6.5);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius));

    if (filled) {
      canvas.drawRRect(
        rrect,
        Paint()..color = activeColor.withValues(alpha: 0.14),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = activeColor,
      );
      return;
    }

    // Bloco arredondado tracejado para vaga disponível
    final outlinePath = Path()..addRRect(rrect);
    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth * 0.85
      ..color = emptyColor.withValues(alpha: 0.55);

    for (final metric in outlinePath.computeMetrics()) {
      final totalLen = metric.length;
      if (totalLen <= 0) continue;
      const int dashCount = 8;
      final double step = totalLen / dashCount;
      final double dashLen = step * 0.54;
      for (int i = 0; i < dashCount; i++) {
        final start = i * step;
        final end = math.min(start + dashLen, totalLen);
        canvas.drawPath(metric.extractPath(start, end), dashPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConsistencySlotRingPainter oldDelegate) =>
      oldDelegate.filled != filled ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.emptyColor != emptyColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
