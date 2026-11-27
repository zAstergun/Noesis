import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../core/localization/noesis_l10n.dart';
import '../core/supabase_service.dart';
import '../features/auth/auth_screen.dart';

/// Cor dourada assinatura VIP do ecossistema Aster / StudioOS.
class AsterVipColors {
  static const Color gold = Color(0xFFF2B33D);
  static const Color goldLight = Color(0xFFFFF1B8);
  static const Color goldDark = Color(0xFFD97706);
  static const Color inkBase = Color(0xFF0E0F14);
  static const Color cardTop = Color(0xFF15161F);
  static const Color cardBottom = Color(0xFF090A0F);
}

/// Vetor da Coroa VIP estilo StudioOS.
class VipCrownIcon extends StatelessWidget {
  final double size;
  final Color color;

  const VipCrownIcon({
    super.key,
    this.size = 14,
    this.color = AsterVipColors.gold,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _VipCrownPainter(color: color),
    );
  }
}

class _VipCrownPainter extends CustomPainter {
  final Color color;
  const _VipCrownPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24.0, size.height / 24.0);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;

    final crownPath = Path()
      ..moveTo(2, 5)
      ..lineTo(5, 16)
      ..lineTo(19, 16)
      ..lineTo(22, 5)
      ..lineTo(16, 11)
      ..lineTo(12, 4)
      ..lineTo(8, 11)
      ..close();

    canvas.drawPath(crownPath, fill);
    canvas.drawPath(crownPath, stroke);
    canvas.drawLine(const Offset(5, 20), const Offset(19, 20), stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VipCrownPainter oldDelegate) =>
      oldDelegate.color != color;
}

enum VipBadgeSize { xs, sm, md, lg }

/// Selo VIP com brilho dourado e coroa (estilo StudioOS `VipBadge`).
class VipBadgePill extends StatelessWidget {
  final VipBadgeSize size;
  final bool interactive;
  final String label;
  final VoidCallback? onTap;

  const VipBadgePill({
    super.key,
    this.size = VipBadgeSize.sm,
    this.interactive = true,
    this.label = 'VIP',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double fontSize;
    final double iconSize;
    final EdgeInsets padding;

    switch (size) {
      case VipBadgeSize.xs:
        fontSize = 7.5;
        iconSize = 9;
        padding = const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5);
      case VipBadgeSize.sm:
        fontSize = 8.5;
        iconSize = 10;
        padding = const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2);
      case VipBadgeSize.md:
        fontSize = 9.5;
        iconSize = 11.5;
        padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5);
      case VipBadgeSize.lg:
        fontSize = 10.5;
        iconSize = 13;
        padding = const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5);
    }

    final pill = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AsterVipColors.inkBase,
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        border: Border.all(
          color: AsterVipColors.gold.withValues(alpha: 0.72),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: AsterVipColors.gold.withValues(alpha: 0.34),
            blurRadius: 10,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (size != VipBadgeSize.xs) ...[
            VipCrownIcon(size: iconSize),
            const SizedBox(width: 4),
          ] else ...[
            VipCrownIcon(size: iconSize),
            const SizedBox(width: 2.5),
          ],
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: AsterVipColors.gold,
              height: 1.0,
            ),
          ),
        ],
      ),
    );

    if (!interactive) return pill;
    return Tooltip(
      message: context.tr('Membro VIP Aster · Clique para ver privilégios VIP'),
      child: InkWell(
        onTap: onTap ?? () => showVipPrivilegesModal(context),
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        child: pill,
      ),
    );
  }
}

/// Círculo de foto com aro dourado brilhante + badge VIP estilo StudioOS.
class VipAvatarCircle extends StatelessWidget {
  final Widget child;
  final bool isVip;
  final VipBadgeSize badgeSize;
  final bool showBadge;
  final bool interactiveBadge;
  final Color? fallbackBorderColor;
  final double borderWidth;
  final List<Color>? customGradientColors;
  final Color? customGlowColor;

  const VipAvatarCircle({
    super.key,
    required this.child,
    required this.isVip,
    this.badgeSize = VipBadgeSize.xs,
    this.showBadge = true,
    this.interactiveBadge = false,
    this.fallbackBorderColor,
    this.borderWidth = 2.0,
    this.customGradientColors,
    this.customGlowColor,
  });

  @override
  Widget build(BuildContext context) {
    final customColors = customGradientColors;
    final hasCustomGradient = customColors != null && customColors.length >= 2;
    final hasRing = hasCustomGradient || isVip || fallbackBorderColor != null;
    final effectiveGlow = customGlowColor ?? (isVip ? AsterVipColors.gold : null);

    final ring = Container(
      padding: EdgeInsets.all(hasRing ? borderWidth : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasCustomGradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: customColors,
              )
            : (isVip
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AsterVipColors.goldLight,
                      AsterVipColors.gold,
                      AsterVipColors.goldDark,
                    ],
                  )
                : null),
        border: !hasCustomGradient && !isVip && fallbackBorderColor != null
            ? Border.all(color: fallbackBorderColor!, width: borderWidth)
            : null,
        boxShadow: effectiveGlow != null
            ? [
                BoxShadow(
                  color: effectiveGlow.withValues(alpha: 0.45),
                  blurRadius: 12,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (!isVip || !showBadge) return ring;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ring,
        PositionedDirectional(
          top: -4,
          end: -6,
          child: VipBadgePill(
            key: const Key('vip_avatar_badge'),
            size: badgeSize,
            interactive: interactiveBadge,
          ),
        ),
      ],
    );
  }
}

Future<void> showVipPrivilegesModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (_) => const VipPrivilegesModal(),
  );
}

class VipPrivilegesModal extends StatefulWidget {
  const VipPrivilegesModal({super.key});

  @override
  State<VipPrivilegesModal> createState() => _VipPrivilegesModalState();
}

class _VipPrivilegesModalState extends State<VipPrivilegesModal> {
  bool _copiedEmail = false;

  Future<void> _copyEmail() async {
    await Clipboard.setData(const ClipboardData(text: 'donate@asterdev.me'));
    if (!mounted) return;
    setState(() => _copiedEmail = true);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedEmail = false);
    });
  }

  Future<void> _openDonate() async {
    final uri = Uri.parse('https://donate.asterdev.me');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _openDiscord() async {
    final uri = Uri.parse(AsterConstants.asterDiscordUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isVip = SupabaseService.isCurrentUserVip;
    final compact = MediaQuery.sizeOf(context).width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 24,
        vertical: 14,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 820),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AsterVipColors.cardTop,
                Color(0xFF0E0F16),
                AsterVipColors.cardBottom,
              ],
            ),
            borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
            border: Border.all(
              color: AsterVipColors.gold.withValues(alpha: 0.36),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.75),
                blurRadius: 36,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: AsterVipColors.gold.withValues(alpha: 0.18),
                blurRadius: 32,
                spreadRadius: -4,
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Emblema Dourado estilo StudioOS + botão fechar na mesma faixa superior
                SizedBox(
                  width: double.infinity,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      PositionedDirectional(
                        top: 0,
                        end: 0,
                        child: IconButton(
                          tooltip: context.tr('Fechar'),
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF989BB8)),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                        ),
                      ),
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AsterVipColors.gold.withValues(alpha: 0.25),
                                  AsterVipColors.goldDark.withValues(alpha: 0.14),
                                ],
                              ),
                              border: Border.all(
                                color: AsterVipColors.gold.withValues(alpha: 0.55),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AsterVipColors.gold.withValues(alpha: 0.32),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: VipCrownIcon(size: 30),
                            ),
                          ),
                          Positioned(
                            bottom: -8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                              decoration: BoxDecoration(
                                color: AsterVipColors.inkBase,
                                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                border: Border.all(color: AsterVipColors.gold.withValues(alpha: 0.65)),
                              ),
                              child: Text(
                                'VIP PASS',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                  color: AsterVipColors.gold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
                  decoration: BoxDecoration(
                    color: AsterVipColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    border: Border.all(color: AsterVipColors.gold.withValues(alpha: 0.32)),
                  ),
                  child: Text(
                    context.tr('CARGO DE APOIADOR DOS PROJETOS DO ASTER'),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: AsterVipColors.goldLight,
                    ),
                  ),
                ),
                const SizedBox(height: 7),

                Text(
                  context.tr('Privilégios VIP no Noesis'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFF4F5FB),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('O VIP é o cargo oficial para apoiadores do ecossistema Aster. Ao se tornar VIP, seus privilégios são válidos em todos os projetos do Aster!'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    height: 1.35,
                    color: const Color(0xFFB3B6D4),
                  ),
                ),

                if (isVip) ...[
                  const SizedBox(height: 9),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AsterConstants.menta.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AsterConstants.menta.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 15, color: AsterConstants.menta),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            context.tr('Você já é um membro VIP ativo! Muito obrigado pelo apoio.'),
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AsterConstants.menta,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr('PRIVILÉGIOS & VANTAGENS INCLUSAS'),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: const Color(0xFF8C90B0),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AsterVipColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        context.tr('Acesso Completo'),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AsterVipColors.gold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = constraints.maxWidth >= 560
                        ? 3
                        : (constraints.maxWidth >= 380 ? 2 : 1);
                    const gap = 8.0;
                    final tileW = (constraints.maxWidth - (cols - 1) * gap) / cols;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        SizedBox(
                          width: tileW,
                          child: _VipPerkTile(
                            icon: Icons.workspace_premium_rounded,
                            title: context.tr('Destaque & Selo VIP'),
                            description: context.tr('Aro dourado e selo VIP em todos os projetos do Aster.'),
                          ),
                        ),
                        SizedBox(
                          width: tileW,
                          child: _VipPerkTile(
                            icon: Icons.gif_box_rounded,
                            title: context.tr('Avatar com GIF Animado'),
                            description: context.tr('Use GIFs animados como foto nos projetos do Aster.'),
                          ),
                        ),
                        SizedBox(
                          width: tileW,
                          child: _VipPerkTile(
                            icon: Icons.palette_rounded,
                            title: context.tr('Tema & Cores RGB VIP'),
                            description: context.tr('Tema personalizado 6 cores e seletor RGB livre no app.'),
                          ),
                        ),
                        SizedBox(
                          width: tileW,
                          child: _VipPerkTile(
                            icon: Icons.history_rounded,
                            title: context.tr('Histórico do Noesis AI'),
                            description: context.tr('Acesse e retome conversas salvas no Noesis AI.'),
                          ),
                        ),
                        SizedBox(
                          width: tileW,
                          child: _VipPerkTile(
                            icon: Icons.bolt_rounded,
                            title: context.tr('Insights em Dobro (2×)'),
                            description: context.tr('Dobra (2×) seus Insights base + bônus de Elo em simulados, flashcards e metas.'),
                          ),
                        ),
                        SizedBox(
                          width: tileW,
                          child: _VipPerkTile(
                            icon: Icons.all_inclusive_rounded,
                            title: context.tr('Ganho Diário Ilimitado'),
                            description: context.tr('Sem limite diário ou redução de ganhos em nenhum Elo (dobro sobre todos os bônus).'),
                          ),
                        ),
                        SizedBox(
                          width: constraints.maxWidth,
                          child: _VipPerkTile(
                            icon: Icons.donut_large_rounded,
                            title: context.tr('Selo de Consistência VIP (10 + 2/mês grátis)'),
                            description: context.tr('Guarde até 10 selos de consistência (dobro de 5) e receba 2 grátis por mês.'),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  decoration: BoxDecoration(
                    color: AsterVipColors.gold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AsterVipColors.gold.withValues(alpha: 0.28)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('⚡ Como ativar seus privilégios VIP:'),
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('1. Faça uma contribuição em donate.asterdev.me.\n2. Envie um e-mail para donate@asterdev.me com seu @usuario para ativarmos na sua conta Aster.'),
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          height: 1.38,
                          color: const Color(0xFFC8CBE2),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final donateButton = SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: _openDonate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AsterVipColors.gold,
                          foregroundColor: AsterVipColors.inkBase,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: Text(
                          context.tr('Apoiar no donate.asterdev.me'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    );

                    final copyEmailButton = SizedBox(
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: _copyEmail,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _copiedEmail ? AsterConstants.menta : Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.03),
                          side: BorderSide(
                            color: _copiedEmail
                                ? AsterConstants.menta
                                : Colors.white.withValues(alpha: 0.18),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(
                          _copiedEmail ? Icons.check_rounded : Icons.copy_rounded,
                          size: 15,
                          color: _copiedEmail ? AsterConstants.menta : AsterVipColors.gold,
                        ),
                        label: Text(
                          _copiedEmail ? context.tr('Copiado!') : 'donate@asterdev.me',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );

                    final discordButton = SizedBox(
                      height: 36,
                      child: OutlinedButton.icon(
                        key: const Key('vip_discord_button'),
                        onPressed: _openDiscord,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD6DCFF),
                          side: BorderSide(
                            color: const Color(0xFF5865F2).withValues(alpha: 0.65),
                          ),
                          backgroundColor: const Color(0xFF5865F2).withValues(alpha: 0.18),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        icon: const DiscordLogoWidget(size: 15),
                        label: Text(
                          context.tr('Discord do Aster'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    );

                    final closeButton = SizedBox(
                      height: 36,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFA0A4C4),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        child: Text(
                          context.tr('Fechar'),
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          donateButton,
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: copyEmailButton),
                              const SizedBox(width: 8),
                              Expanded(child: discordButton),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                          const SizedBox(height: 8),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: closeButton,
                          ),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(flex: 3, child: donateButton),
                            const SizedBox(width: 10),
                            Expanded(flex: 2, child: copyEmailButton),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            discordButton,
                            closeButton,
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VipPerkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _VipPerkTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AsterVipColors.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AsterVipColors.gold.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, size: 16, color: AsterVipColors.gold),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFF4F5FB),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    height: 1.3,
                    color: const Color(0xFFA6A9C8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
