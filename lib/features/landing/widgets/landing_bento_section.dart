import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants.dart';
import '../../../core/gemini_service.dart';
import '../../../core/theme.dart';
import '../../../widgets/insight_icon.dart';
import '../../../widgets/noesis_logo.dart';
import '../../ranking/models/ranking_league_model.dart';
import 'landing_motion.dart';

/// Seção Bento Grid ("Arquitetura modular, experiência única") com
/// dados reais do Noesis: 7 provedores de IA orbitando, 20 ferramentas,
/// Aster Account SSO com sincronização na nuvem, Calendário em 4 visões (Dia/Sem/Mês/Timeline),
/// 8 Elos reais (Faísca → Noesis) e 39 modelos de simulados RAG.
class LandingBentoSection extends StatefulWidget {
  const LandingBentoSection({super.key, required this.width});

  final double width;

  @override
  State<LandingBentoSection> createState() => _LandingBentoSectionState();
}

class _LandingBentoSectionState extends State<LandingBentoSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbitController;

  String _selectedTool = 'Gerar Simulados';
  int? _selectedProviderIndex;
  String _selectedCalView = 'mes';
  int _selectedEloIndex = 4; // Episteme (5º de 8)

  static const Map<String, String> _toolDescriptions = {
    'Gerar Simulados': 'Monta um simulado inédito a partir do tema, banca ou documento RAG que você indicar.',
    'Criar Flashcards': 'Gera baralhos 3D prontos para revisão espaçada (Difícil, Bom, Fácil) direto da conversa.',
    'Agendar Blocos': 'Agenda blocos de estudo, revisões, labs ou provas nas 4 visões do Calendário.',
    'Montar Trilhas': 'Estrutura uma trilha de aprendizado passo a passo com etapas e semanas estimadas.',
  };

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 32),
    );
    if (!WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      _orbitController.repeat();
    }
  }

  @override
  void dispose() {
    _orbitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = widget.width < 600;
    final isWide = widget.width >= 960;
    final primary = AsterTheme.primary(context);
    final textCol = AsterTheme.text(context);
    final mutedCol = AsterTheme.textMuted(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  ),
                  child: Text(
                    'MÓDULOS',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Arquitetura modular, experiência única',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: isWide ? 48 : (isCompact ? 30 : 38),
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.4,
                    height: 1.08,
                    color: textCol,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Cada módulo funciona sozinho — e todos conversam entre si pelo agente cognitivo e pela sua conta Aster.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: isCompact ? 15 : 17,
                    height: 1.55,
                    color: mutedCol,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 36),

        // Linha 1 do Bento: Multi-IA (4 cols) + Aster Account SSO (2 cols)
        if (isWide) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 4, child: _buildMultiAiCard(context, isCompact: isCompact)),
                const SizedBox(width: 18),
                Expanded(flex: 2, child: _buildSsoCard(context)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Linha 2 do Bento: Calendário 4 visões + Insights & 8 Elos + Simulados RAG
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildCalendarCard(context)),
                const SizedBox(width: 18),
                Expanded(child: _buildElosCard(context)),
                const SizedBox(width: 18),
                Expanded(child: _buildRagCard(context)),
              ],
            ),
          ),
        ] else ...[
          _buildMultiAiCard(context, isCompact: isCompact),
          const SizedBox(height: 16),
          _buildSsoCard(context),
          const SizedBox(height: 16),
          _buildCalendarCard(context),
          const SizedBox(height: 16),
          _buildElosCard(context),
          const SizedBox(height: 16),
          _buildRagCard(context),
        ],
      ],
    );
  }

  Widget _buildMultiAiCard(BuildContext context, {required bool isCompact}) {
    final primary = AsterTheme.primary(context);
    final textCol = AsterTheme.text(context);
    final mutedCol = AsterTheme.textMuted(context);
    final altCol = AsterTheme.surfaceAlt(context);
    final insetCol = AsterTheme.surfaceInset(context);
    final cardCol = AsterTheme.card(context);

    final providers = GeminiService.providers;
    final infoText = _selectedProviderIndex != null
        ? '${providers[_selectedProviderIndex!].label} · modelo padrão: ${providers[_selectedProviderIndex!].defaultModel.isEmpty ? "endpoint OpenAI-compatível" : providers[_selectedProviderIndex!].defaultModel} (com benchmark de latência)'
        : (_toolDescriptions[_selectedTool] ?? '');

    final copyPart = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BentoIconBadge(icon: Icons.layers_rounded, color: primary),
        const SizedBox(height: 14),
        Text(
          'Multi-IA, um só agente',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: textCol,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sete provedores conectados às mesmas 20 ferramentas, com benchmark de latência em ms e suporte a 15 idiomas.',
          style: GoogleFonts.manrope(
            fontSize: 14.5,
            height: 1.5,
            color: mutedCol,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _toolDescriptions.keys.map((tool) {
            final on = _selectedProviderIndex == null && _selectedTool == tool;
            return InkWell(
              onTap: () => setState(() {
                _selectedProviderIndex = null;
                _selectedTool = tool;
              }),
              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: on ? primary : altCol,
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  border: Border.all(color: on ? primary : insetCol),
                ),
                child: Text(
                  tool,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: on ? AsterTheme.onPrimary(context) : mutedCol,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            infoText,
            style: GoogleFonts.manrope(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: textCol,
              height: 1.4,
            ),
          ),
        ),
      ],
    );

    final orbitPart = Center(
      child: SizedBox(
        width: 240,
        height: 240,
        child: AnimatedBuilder(
          animation: _orbitController,
          builder: (context, _) {
            final t = _orbitController.value * 2 * math.pi;
            return Stack(
              alignment: Alignment.center,
              children: [
                // Anéis tracejados/sutis
                Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: primary.withValues(alpha: 0.22), width: 1.4),
                  ),
                ),
                Container(
                  width: 174,
                  height: 174,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: primary.withValues(alpha: 0.30), width: 1.4),
                  ),
                ),
                // Núcleo central Noesis AI
                const NoesisLogo(
                  size: 62,
                  withShadow: true,
                ),
                // 7 nós orbitando (1 por provedor real do GeminiService.providers)
                ...List.generate(providers.length, (i) {
                  final angle = t + (i * (2 * math.pi / providers.length));
                  const radius = 94.0;
                  final dx = math.cos(angle) * radius;
                  final dy = math.sin(angle) * radius;
                  final p = providers[i];
                  final isSel = _selectedProviderIndex == i;
                  final shortLabel = switch (p.id) {
                    'google' => 'Gem',
                    'openai' => 'GPT',
                    'anthropic' => 'CLD',
                    'xai' => 'Grok',
                    'deepseek' => 'DS',
                    'openrouter' => 'OR',
                    _ => 'API',
                  };
                  return Transform.translate(
                    offset: Offset(dx, dy),
                    child: Tooltip(
                      message: p.label,
                      child: InkWell(
                        onTap: () => setState(() => _selectedProviderIndex = i),
                        onHover: (hovered) {
                          if (hovered) setState(() => _selectedProviderIndex = i);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSel ? primary : cardCol,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSel ? primary : insetCol,
                              width: 1.4,
                            ),
                            boxShadow: AsterConstants.claySubtleShadow,
                          ),
                          child: Center(
                            child: Text(
                              shortLabel,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: isSel ? AsterTheme.onPrimary(context) : primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );

    return _BentoCardShell(
      child: widget.width >= 760
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: copyPart),
                const SizedBox(width: 24),
                orbitPart,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                copyPart,
                const SizedBox(height: 22),
                orbitPart,
              ],
            ),
    );
  }

  Widget _buildSsoCard(BuildContext context) {
    final primary = AsterTheme.primary(context);
    final textCol = AsterTheme.text(context);
    final mutedCol = AsterTheme.textMuted(context);
    final altCol = AsterTheme.surfaceAlt(context);
    final cardCol = AsterTheme.card(context);
    final insetCol = AsterTheme.surfaceInset(context);

    return _BentoCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BentoIconBadge(icon: Icons.lock_rounded, color: primary),
              const SizedBox(height: 14),
              Text(
                'Aster Account SSO',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: textCol,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Entre uma única vez com Email, Google, GitHub, Discord ou Apple e mantenha seus estudos sincronizados em tempo real.',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  height: 1.5,
                  color: mutedCol,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: altCol,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: insetCol.withValues(alpha: 0.7)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SsoNodeRow(
                      icon: Icons.person_rounded,
                      iconColor: primary,
                      label: 'Aster Account · Login único',
                      cardCol: cardCol,
                      insetCol: insetCol,
                      textCol: textCol,
                    ),
                    _AnimatedSsoFlow(color: primary),
                    _SsoNodeRow(
                      leading: const NoesisLogo(size: 19),
                      label: 'Noesis · Sincronizado na nuvem',
                      cardCol: cardCol,
                      insetCol: insetCol,
                      textCol: textCol,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard(BuildContext context) {
    final primary = AsterTheme.primary(context);
    final textCol = AsterTheme.text(context);
    final altCol = AsterTheme.surfaceAlt(context);
    final cardCol = AsterTheme.card(context);
    final insetCol = AsterTheme.surfaceInset(context);

    const views = [
      (id: 'mes', label: 'Mês'),
      (id: 'semana', label: 'Semana'),
      (id: 'dia', label: 'Dia'),
      (id: 'timeline', label: 'Timeline'),
    ];

    return _BentoCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BentoIconBadge(icon: Icons.calendar_today_rounded, color: primary),
          const SizedBox(height: 14),
          Text(
            'Calendário em 4 visões',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: textCol,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: views.map((v) {
              final on = _selectedCalView == v.id;
              return InkWell(
                onTap: () => setState(() => _selectedCalView = v.id),
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: on ? primary : altCol,
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    border: Border.all(color: on ? primary : insetCol),
                  ),
                  child: Text(
                    v.label,
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: on ? AsterTheme.onPrimary(context) : AsterTheme.textMuted(context),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Container(
            height: 120,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: altCol,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: insetCol.withValues(alpha: 0.7)),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: switch (_selectedCalView) {
                'mes' => _buildMonthMiniPreview(cardCol, primary),
                'semana' => _buildWeekMiniPreview(primary),
                'dia' => _buildDayMiniPreview(cardCol, primary),
                _ => _buildTimelineMiniPreview(cardCol, primary, textCol),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthMiniPreview(Color cardCol, Color primary) {
    const pattern = [
      1, 0, 0, 2, 0, 3, 0,
      0, 1, 0, 0, 0, 2, 0,
      3, 0, 0, 1, 0, 0, 2,
    ];
    return GridView.count(
      key: const ValueKey('cal_mes'),
      crossAxisCount: 7,
      mainAxisSpacing: 5,
      crossAxisSpacing: 5,
      childAspectRatio: 1.6,
      physics: const NeverScrollableScrollPhysics(),
      children: pattern.map((p) {
        final col = switch (p) {
          1 => primary,
          2 => AsterConstants.menta,
          3 => AsterConstants.ambar,
          _ => cardCol,
        };
        return Container(
          decoration: BoxDecoration(
            color: col,
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWeekMiniPreview(Color primary) {
    const heights = [0.42, 0.72, 0.56, 0.90, 0.36, 0.64, 0.28];
    return Row(
      key: const ValueKey('cal_semana'),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(heights.length, (i) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == 6 ? 0 : 5),
            child: FractionallySizedBox(
              heightFactor: heights[i],
              child: Container(
                decoration: BoxDecoration(
                  color: i == 3 ? primary : primary.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDayMiniPreview(Color cardCol, Color primary) {
    final bars = [
      (left: 0.05, width: 0.45, color: primary.withValues(alpha: 0.35)),
      (left: 0.42, width: 0.38, color: AsterConstants.menta.withValues(alpha: 0.4)),
      (left: 0.18, width: 0.55, color: AsterConstants.ambar.withValues(alpha: 0.4)),
    ];
    return Column(
      key: const ValueKey('cal_dia'),
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: bars.map((b) {
        return Container(
          height: 22,
          decoration: BoxDecoration(
            color: cardCol,
            borderRadius: BorderRadius.circular(8),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Positioned(
                    left: constraints.maxWidth * b.left,
                    width: constraints.maxWidth * b.width,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: b.color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimelineMiniPreview(Color cardCol, Color primary, Color textCol) {
    final items = [
      (label: '09:00 · Estudo', color: primary),
      (label: '14:00 · Lab / Simulado', color: AsterConstants.ambar),
      (label: '19:00 · Revisão', color: AsterConstants.menta),
    ];
    return Column(
      key: const ValueKey('cal_timeline'),
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: items.map((it) {
        return Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: cardCol,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: it.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                it.label,
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: textCol,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildElosCard(BuildContext context) {
    final primary = AsterTheme.primary(context);
    final textCol = AsterTheme.text(context);
    final mutedCol = AsterTheme.textMuted(context);
    final insetCol = AsterTheme.surfaceInset(context);
    final tiers = RankingEloCatalog.tiers;
    final selTier = tiers[_selectedEloIndex];
    final bonusPct = _selectedEloIndex * 10;
    final dailyCap = 150 + _selectedEloIndex * 20;

    return _BentoCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _BentoIconBadge(
                    color: AsterConstants.ambar,
                    customChild: InsightCoinIcon(size: 24),
                  ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: selTier.badgeColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    ),
                    child: Text(
                      'Elo ${_selectedEloIndex + 1}/8',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color.lerp(selTier.badgeColor, textCol, 0.25),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Insights & 8 Elos',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: textCol,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'De Faísca a Noesis: cada Elo soma +10% em Insights e +20 no teto diário.',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  height: 1.5,
                  color: mutedCol,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 14),
              SizedBox(
                height: 88,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(tiers.length, (i) {
                      final tier = tiers[i];
                      final on = i == _selectedEloIndex;
                      final frac = 0.26 + (i * 0.105);
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i == tiers.length - 1 ? 0 : 6),
                          child: Tooltip(
                            message: tier.name,
                            child: _EloBarItem(
                              fraction: frac,
                              selected: on,
                              badgeColor: tier.badgeColor,
                              inactiveColor: tier.badgeColor.withValues(alpha: 0.24),
                              onTap: () => setState(() => _selectedEloIndex = i),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tiers.first.name,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: mutedCol,
                    ),
                  ),
                  Text(
                    tiers.last.name,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: kLandingFluidCurve,
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                decoration: BoxDecoration(
                  color: selTier.badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selTier.badgeColor.withValues(alpha: 0.32),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: selTier.badgeColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        selTier.icon,
                        size: 15,
                        color: Color.lerp(selTier.badgeColor, textCol, 0.2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selTier.name,
                            style: GoogleFonts.manrope(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: textCol,
                            ),
                          ),
                          Text(
                            selTier.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: mutedCol,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: AsterTheme.card(context),
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                        border: Border.all(color: insetCol.withValues(alpha: 0.85)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const InsightCoinIcon(size: 13),
                          const SizedBox(width: 5),
                          Text(
                            '+$bonusPct% · $dailyCap/d',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: textCol,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRagCard(BuildContext context) {
    final primary = AsterTheme.primary(context);
    final textCol = AsterTheme.text(context);
    final mutedCol = AsterTheme.textMuted(context);
    final altCol = AsterTheme.surfaceAlt(context);
    final insetCol = AsterTheme.surfaceInset(context);

    return _BentoCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BentoIconBadge(icon: Icons.assignment_rounded, color: primary),
              const SizedBox(height: 14),
              Text(
                'Simulados RAG & 39 Bancas',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: textCol,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ENEM, FUVEST, OAB, AWS, Security+, USMLE e mais — ou gere direto dos seus arquivos.',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  height: 1.5,
                  color: mutedCol,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              LandingHoverLift(
                liftY: -2.0,
                child: _RagMiniPill(
                  icon: Icons.description_rounded,
                  iconColor: primary,
                  label: 'Seu arquivo (.pdf/.md/.json)',
                  trailing: '→ RAG',
                  altCol: altCol,
                  insetCol: insetCol,
                  textCol: textCol,
                  mutedCol: mutedCol,
                ),
              ),
              const SizedBox(height: 8),
              LandingHoverLift(
                liftY: -2.0,
                child: _RagMiniPill(
                  icon: Icons.check_circle_rounded,
                  iconColor: AsterConstants.menta,
                  label: 'Questões com fonte citada',
                  trailing: '39 bancas',
                  altCol: altCol,
                  insetCol: insetCol,
                  textCol: textCol,
                  mutedCol: mutedCol,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BentoCardShell extends StatelessWidget {
  const _BentoCardShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LandingSpotlightCard(child: child);
  }
}

class _EloBarItem extends StatefulWidget {
  const _EloBarItem({
    required this.fraction,
    required this.selected,
    required this.badgeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final double fraction;
  final bool selected;
  final Color badgeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  State<_EloBarItem> createState() => _EloBarItemState();
}

class _EloBarItemState extends State<_EloBarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _hovered;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: FractionallySizedBox(
          heightFactor: _hovered ? (widget.fraction + 0.08).clamp(0.0, 1.0) : widget.fraction,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: kLandingSpringCurve,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              gradient: active
                  ? LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        widget.badgeColor,
                        Color.lerp(widget.badgeColor, Colors.white, 0.25)!,
                      ],
                    )
                  : null,
              color: active ? null : widget.inactiveColor,
              boxShadow: widget.selected
                  ? [
                      BoxShadow(
                        color: widget.badgeColor.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedSsoFlow extends StatefulWidget {
  const _AnimatedSsoFlow({required this.color});
  final Color color;

  @override
  State<_AnimatedSsoFlow> createState() => _AnimatedSsoFlowState();
}

class _AnimatedSsoFlowState extends State<_AnimatedSsoFlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (!isLandingTestEnvironment()) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 22,
      margin: const EdgeInsets.only(left: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 2,
            height: 22,
            color: widget.color.withValues(alpha: 0.35),
          ),
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final dy = (_ctrl.value * 16.0) - 8.0;
              return Transform.translate(
                offset: Offset(0, dy),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.45),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BentoIconBadge extends StatelessWidget {
  const _BentoIconBadge({
    this.icon,
    this.customChild,
    required this.color,
  });

  final IconData? icon;
  final Widget? customChild;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final hovered = LandingSpotlightHoverScope.isHoveredOf(context);
    final matrix = Matrix4.identity()
      ..rotateZ(hovered ? -0.14 : 0.0)
      ..scaleByDouble(hovered ? 1.08 : 1.0, hovered ? 1.08 : 1.0, 1.0, 1.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 360),
      curve: kLandingFluidCurve,
      transform: matrix,
      transformAlignment: Alignment.center,
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withValues(alpha: hovered ? 0.20 : 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: customChild ?? Icon(icon, size: 22, color: color),
      ),
    );
  }
}

class _SsoNodeRow extends StatelessWidget {
  const _SsoNodeRow({
    this.icon,
    this.iconColor,
    this.leading,
    required this.label,
    required this.cardCol,
    required this.insetCol,
    required this.textCol,
  });

  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final String label;
  final Color cardCol;
  final Color insetCol;
  final Color textCol;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardCol,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: insetCol.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          leading ?? Icon(icon, size: 17, color: iconColor),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textCol,
              ),
            ),
          ),
          const Icon(Icons.check_rounded, size: 17, color: AsterConstants.menta),
        ],
      ),
    );
  }
}

class _RagMiniPill extends StatefulWidget {
  const _RagMiniPill({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.trailing,
    required this.altCol,
    required this.insetCol,
    required this.textCol,
    required this.mutedCol,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String trailing;
  final Color altCol;
  final Color insetCol;
  final Color textCol;
  final Color mutedCol;

  @override
  State<_RagMiniPill> createState() => _RagMiniPillState();
}

class _RagMiniPillState extends State<_RagMiniPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _nudgeCtrl;

  @override
  void initState() {
    super.initState();
    _nudgeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (!isLandingTestEnvironment() && widget.trailing.startsWith('→')) {
      _nudgeCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _nudgeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trailingText = Text(
      widget.trailing,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: widget.mutedCol,
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: widget.altCol,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: widget.insetCol.withValues(alpha: 0.75)),
      ),
      child: Row(
        children: [
          Icon(widget.icon, size: 17, color: widget.iconColor),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              widget.label,
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: widget.textCol,
              ),
            ),
          ),
          if (widget.trailing.startsWith('→'))
            AnimatedBuilder(
              animation: _nudgeCtrl,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(math.sin(_nudgeCtrl.value * math.pi) * 4.0, 0),
                  child: child,
                );
              },
              child: trailingText,
            )
          else
            trailingText,
        ],
      ),
    );
  }
}
