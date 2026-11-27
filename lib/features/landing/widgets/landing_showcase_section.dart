import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../widgets/insight_icon.dart';
import '../../../widgets/noesis_logo.dart';
import '../../ranking/models/ranking_league_model.dart';
import '../../ranking/widgets/noesis_elo_badge.dart';
import 'landing_motion.dart';

/// Seção "Fluxo Cognitivo Completo" (5 pilares interativos do Noesis).
class LandingShowcaseSection extends StatefulWidget {
  const LandingShowcaseSection({super.key, required this.width});

  final double width;

  @override
  State<LandingShowcaseSection> createState() => _LandingShowcaseSectionState();
}

class _LandingShowcaseSectionState extends State<LandingShowcaseSection> {
  int _activeIndex = 0;
  bool _flashcardFlipped = false;
  String? _lastCardRating;
  int _activeRoadmapStep = 2; // Etapa 3 de 5 em andamento

  static const List<
      ({
        IconData icon,
        String label,
        String num,
        String title,
        String description,
        List<String> checks,
      })> _pillars = [
    (
      icon: Icons.timer_rounded,
      label: 'Foco & Consistência',
      num: '01 / 05',
      title: 'Foco que vira hábito mensurável',
      description:
          'Cronômetro dual (Stopwatch e Pomodoro), metas diária e semanal, Diário de Estudos, análise de Desempenho e Protetores de Ofensiva para proteger sua sequência.',
      checks: [
        'Timer Stopwatch e Pomodoro por disciplina',
        'Meta semanal, Diário de Estudos e Desempenho',
        'Heatmap de consistência e Protetores de Ofensiva',
      ],
    ),
    (
      icon: Icons.assignment_rounded,
      label: 'Simulados RAG',
      num: '02 / 05',
      title: 'Simulados ancorados no seu material',
      description:
          'Escolha entre 39 modelos oficiais (ENEM, FUVEST, OAB, AWS, Security+, USMLE) ou envie seus próprios arquivos (.pdf, .txt, .md, .json) para gerar questões inéditas via RAG.',
      checks: [
        '39 modelos oficiais em 7 áreas do conhecimento',
        'Ingestão RAG de .pdf, .txt, .md e .json',
        'Flag de revisão, gabarito comentado e Insights',
      ],
    ),
    (
      icon: Icons.style_rounded,
      label: 'Flashcards & Trilhas',
      num: '03 / 05',
      title: 'Memorização ativa e caminho claro',
      description:
          'Revise com cartões 3D e avaliação espaçada (Difícil, Bom, Fácil), importe baralhos prontos e conecte tudo a Cadernos e Trilhas de aprendizado por etapas.',
      checks: [
        'Flashcards 3D com revisão espaçada (Difícil / Bom / Fácil)',
        'Importação de baralhos e geração via IA',
        'Cadernos de estudo e Trilhas com metas semanais',
      ],
    ),
    (
      icon: Icons.auto_awesome_rounded,
      label: 'Noesis AI & Agenda',
      num: '04 / 05',
      title: 'Um agente que age direto na sua conta',
      description:
          'Com 20 ações integradas e suporte a anexos, o Noesis AI cria simulados, baralhos, trilhas e agenda revisões no Calendário em 4 visões.',
      checks: [
        '20 ferramentas autônomas no agente cognitivo',
        'Calendário em 4 visões: Dia, Semana, Mês e Timeline',
        'Sugestões proativas de blocos pela IA + 7 provedores',
      ],
    ),
    (
      icon: Icons.groups_rounded,
      label: 'Comunidade & Elos',
      num: '05 / 05',
      title: 'Estudar junto, subir nos 8 Elos',
      description:
          'Compartilhe cadernos, simulados, baralhos e trilhas em Grupos de Estudo, dispute a Liga semanal de Faísca até Noesis e desbloqueie temas na Loja.',
      checks: [
        'Grupos colaborativos com Chat, Materiais e Ranking',
        'Liga semanal com 8 Elos reais (Faísca → Noesis)',
        'Economia de Insights, 10 temas e VIP RGB',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isCompact = widget.width < 600;
    final isWide = widget.width >= 900;
    final primary = AsterTheme.primary(context);
    final cardCol = AsterTheme.card(context);
    final altCol = AsterTheme.surfaceAlt(context);
    final insetCol = AsterTheme.surfaceInset(context);
    final textCol = AsterTheme.text(context);
    final mutedCol = AsterTheme.textMuted(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final current = _pillars[_activeIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabeçalho fiel à referência (.sec-head)
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 740),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: cardCol.withValues(alpha: isDark ? 0.9 : 0.85),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    border: Border.all(
                      color: insetCol.withValues(alpha: isDark ? 0.75 : 0.95),
                    ),
                    boxShadow: isDark
                        ? AsterConstants.claySubtleDarkShadow
                        : AsterConstants.claySubtleShadow,
                  ),
                  child: Text(
                    'Fluxo cognitivo completo',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: mutedCol,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text.rich(
                  TextSpan(
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: isWide ? 50 : (isCompact ? 30 : 38),
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.4,
                      height: 1.08,
                      color: textCol,
                    ),
                    children: [
                      const TextSpan(text: 'Do foco à comunidade, '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [primary, AsterConstants.menta],
                          ).createShader(bounds),
                          child: Text(
                            'um fluxo contínuo.',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: isWide ? 50 : (isCompact ? 30 : 38),
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.4,
                              height: 1.08,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Text(
                  'Cada pilar conversa com os outros: o que você estuda alimenta a agenda, os simulados e a sua posição na Liga.',
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
        const SizedBox(height: 34),

        // Pill Tabs de seleção dos 5 pilares com pílula clara elevada (estilo referência .pills)
        Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                boxShadow: isDark
                    ? AsterConstants.claySubtleDarkShadow
                    : AsterConstants.claySubtleShadow,
              ),
              child: LandingSlidingPillTabs(
                items: _pillars
                    .map((p) => (icon: p.icon, label: p.label))
                    .toList(growable: false),
                selectedIndex: _activeIndex,
                onSelect: (i) => setState(() => _activeIndex = i),
                activeFillColor: cardCol,
                activeTextColor: textCol,
                backgroundColor: altCol.withValues(alpha: isDark ? 0.9 : 0.85),
                compact: isCompact,
              ),
            ),
          ),
        ),
        const SizedBox(height: 26),

        // Painel principal estilo Soft Clay limpo (.sc) sem caixa dupla
        Container(
          constraints: isWide ? const BoxConstraints(minHeight: 420) : null,
          decoration: BoxDecoration(
            color: cardCol.withValues(alpha: isDark ? 0.96 : 0.94),
            borderRadius: BorderRadius.circular(isCompact ? 26 : 36),
            border: Border.all(color: insetCol.withValues(alpha: isDark ? 0.8 : 0.95)),
            boxShadow: isDark ? AsterConstants.clayDarkShadow : AsterConstants.clayShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Brilho radial suave no canto superior direito (.sc::before)
              Positioned(
                right: -110,
                top: -110,
                width: 360,
                height: 360,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          primary.withValues(alpha: isDark ? 0.16 : 0.12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(isCompact ? 20 : 36),
                child: LandingSequentialSwitcher(
                  outDuration: const Duration(milliseconds: 170),
                  inDuration: const Duration(milliseconds: 380),
                  outOffset: const Offset(0, 14),
                  inOffset: const Offset(24, 0),
                  child: isWide
                      ? Row(
                          key: ValueKey('pillar_wide_$_activeIndex'),
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 10,
                              child: _buildCopyColumn(context, current, isCompact: isCompact),
                            ),
                            const SizedBox(width: 30),
                            Expanded(
                              flex: 11,
                              child: TweenAnimationBuilder<double>(
                                key: ValueKey('pillar_vis_anim_$_activeIndex'),
                                tween: Tween<double>(begin: 0.0, end: 1.0),
                                duration: isLandingTestEnvironment()
                                    ? Duration.zero
                                    : const Duration(milliseconds: 480),
                                curve: kLandingFluidCurve,
                                builder: (context, t, child) {
                                  return Transform.translate(
                                    offset: Offset((1.0 - t) * 20.0, 0),
                                    child: child,
                                  );
                                },
                                child: _buildVisualBox(context, _activeIndex, isCompact: isCompact),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          key: ValueKey('pillar_narrow_$_activeIndex'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildCopyColumn(context, current, isCompact: isCompact),
                            const SizedBox(height: 24),
                            _buildVisualBox(context, _activeIndex, isCompact: isCompact),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCopyColumn(
    BuildContext context,
    ({
      IconData icon,
      String label,
      String num,
      String title,
      String description,
      List<String> checks,
    }) pillar, {
    required bool isCompact,
  }) {
    final primary = AsterTheme.primary(context);
    final textCol = AsterTheme.text(context);
    final mutedCol = AsterTheme.textMuted(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pillar.num,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: primary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          pillar.title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: isCompact ? 24 : 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.9,
            height: 1.12,
            color: textCol,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          pillar.description,
          style: GoogleFonts.manrope(
            fontSize: isCompact ? 14.5 : 16,
            height: 1.55,
            fontWeight: FontWeight.w500,
            color: mutedCol,
          ),
        ),
        const SizedBox(height: 22),
        ...pillar.checks.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AsterConstants.menta.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 15,
                    color: AsterConstants.menta,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item,
                    style: GoogleFonts.manrope(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: textCol,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVisualBox(
    BuildContext context,
    int index, {
    required bool isCompact,
  }) {
    final primary = AsterTheme.primary(context);
    final cardCol = AsterTheme.card(context);
    final altCol = AsterTheme.surfaceAlt(context);
    final insetCol = AsterTheme.surfaceInset(context);
    final textCol = AsterTheme.text(context);
    final mutedCol = AsterTheme.textMuted(context);

    return switch (index) {
      0 => _buildPillarFocusVisual(context, cardCol, altCol, insetCol, primary, textCol, mutedCol, isCompact: isCompact),
      1 => _buildPillarRagVisual(cardCol, altCol, insetCol, primary, textCol, mutedCol),
      2 => _buildPillarFlashcardVisual(context, cardCol, altCol, insetCol, primary, textCol, mutedCol),
      3 => _buildPillarAgentCalendarVisual(cardCol, altCol, insetCol, primary, textCol, mutedCol),
      _ => _buildPillarCommunityVisual(cardCol, altCol, insetCol, primary, textCol, mutedCol),
    };
  }

  Widget _buildPillarFocusVisual(
    BuildContext context,
    Color cardCol,
    Color altCol,
    Color insetCol,
    Color primary,
    Color textCol,
    Color mutedCol, {
    required bool isCompact,
  }) {
    final onPrimary = AsterTheme.onPrimary(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card real do TrackerScreen ("SESSÃO EM ANDAMENTO")
        _ShowcaseVcard(
          cardCol: cardCol,
          insetCol: insetCol,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AsterConstants.menta,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'SESSÃO EM ANDAMENTO',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: mutedCol,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                        ),
                        child: Text(
                          '1 checkpoint',
                          style: GoogleFonts.manrope(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AsterConstants.ambar.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const InsightCoinIcon(size: 12),
                            const SizedBox(width: 4),
                            Text(
                              '+24',
                              style: GoogleFonts.manrope(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color.lerp(AsterConstants.ambar, textCol, 0.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '01:12',
                              style: GoogleFonts.manrope(
                                fontSize: isCompact ? 32 : 38,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.4,
                                color: textCol,
                              ),
                            ),
                            Text(
                              ':09',
                              style: GoogleFonts.manrope(
                                fontSize: isCompact ? 32 : 38,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.4,
                                color: primary.withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: altCol,
                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                          ),
                          child: Text(
                            'Estruturas de Dados · Pomodoro',
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: mutedCol,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(width: 10),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                        boxShadow: AsterTheme.primaryShadow(context, primary),
                      ),
                      child: Icon(Icons.pause_rounded, size: 20, color: onPrimary),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Card real de "Horas estudadas · últimos 7 dias" + Selos de Consistência
        _ShowcaseVcard(
          cardCol: cardCol,
          insetCol: insetCol,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Horas estudadas',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: textCol,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: altCol,
                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const ConsistencySealIcon(size: 13, accentColor: AsterConstants.ambar),
                        const SizedBox(width: 5),
                        Text(
                          '2 Selos · 14 dias',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: mutedCol,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '12h 30m',
                    style: GoogleFonts.manrope(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.9,
                      color: textCol,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      '+2h15m vs semana anterior',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AsterConstants.menta,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ShowcaseWeekBars(primary: primary, mutedCol: mutedCol),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPillarRagVisual(
    Color cardCol,
    Color altCol,
    Color insetCol,
    Color primary,
    Color textCol,
    Color mutedCol,
  ) {
    Widget optRow(String letter, String label, {bool isCorrect = false}) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isCorrect ? AsterConstants.menta.withValues(alpha: 0.09) : cardCol,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCorrect
                ? AsterConstants.menta
                : insetCol.withValues(alpha: 0.85),
            width: isCorrect ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCorrect ? AsterConstants.menta : altCol,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  letter,
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isCorrect ? Colors.white : textCol,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
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
            if (isCorrect)
              const Icon(Icons.check_rounded, size: 16, color: AsterConstants.menta),
          ],
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ShowcaseVcard(
          cardCol: cardCol,
          insetCol: insetCol,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    ),
                    child: Text(
                      'Simulado RAG · 39 Bancas',
                      style: GoogleFonts.manrope(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '1 / 15',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: mutedCol,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'SELECIONE UMA ALTERNATIVA',
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: mutedCol,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Qual organela realiza a respiração celular e síntese de ATP?',
                style: GoogleFonts.manrope(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: textCol,
                ),
              ),
              optRow('A', 'Ribossomo'),
              optRow('B', 'Mitocôndria', isCorrect: true),
              optRow('C', 'Lisossomo'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ShowcaseVcard(
          cardCol: cardCol,
          insetCol: insetCol,
          child: Row(
            children: [
              Icon(Icons.menu_book_rounded, size: 15, color: mutedCol),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'caderno_biologia.pdf · p. 12',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11.5,
                    color: mutedCol,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AsterConstants.menta.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const InsightCoinIcon(size: 13),
                    const SizedBox(width: 5),
                    Text(
                      'Gabarito +3',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
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
    );
  }

  Widget _buildPillarFlashcardVisual(
    BuildContext context,
    Color cardCol,
    Color altCol,
    Color insetCol,
    Color primary,
    Color textCol,
    Color mutedCol,
  ) {
    final onPrimary = AsterTheme.onPrimary(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Baralho 3D empilhado com camadas de profundidade (.fc-stack)
        Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 20,
              right: 20,
              top: 16,
              bottom: -14,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color.lerp(altCol, primary, 0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: insetCol.withValues(alpha: 0.9),
                    width: 1.2,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              top: 8,
              bottom: -7,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color.lerp(cardCol, altCol, 0.45),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: insetCol.withValues(alpha: 0.95),
                    width: 1.2,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _flashcardFlipped = !_flashcardFlipped),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: _flashcardFlipped ? math.pi : 0),
                duration: isLandingTestEnvironment()
                    ? Duration.zero
                    : const Duration(milliseconds: 520),
                curve: kLandingFluidCurve,
                builder: (context, angle, _) {
                  final isBack = angle > math.pi / 2;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0014)
                      ..rotateY(angle),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(isBack ? math.pi : 0),
                      child: Container(
                        width: double.infinity,
                        height: 148,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: isBack
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    primary,
                                    Color.lerp(primary, AsterConstants.coral, 0.45)!,
                                  ],
                                )
                              : null,
                          color: isBack ? null : cardCol,
                          border: Border.all(
                            color: isBack ? Colors.transparent : insetCol,
                          ),
                          boxShadow: AsterConstants.claySubtleShadow,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isBack
                                        ? Colors.white.withValues(alpha: 0.22)
                                        : primary.withValues(alpha: 0.13),
                                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                  ),
                                  child: Text(
                                    isBack ? 'VERSO · EXPLICAÇÃO' : 'FRENTE · ACTIVE RECALL',
                                    style: GoogleFonts.manrope(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.7,
                                      color: isBack ? onPrimary : primary,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isBack ? Colors.white.withValues(alpha: 0.16) : altCol,
                                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                  ),
                                  child: Text(
                                    'Editar',
                                    style: GoogleFonts.manrope(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: isBack ? onPrimary : textCol,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.flip_camera_android_rounded,
                                  size: 16,
                                  color: isBack ? onPrimary.withValues(alpha: 0.85) : mutedCol,
                                ),
                              ],
                            ),
                            Center(
                              child: Text(
                                isBack
                                    ? 'Estrutura que mapeia chaves a valores em O(1) médio usando função de espalhamento.'
                                    : 'O que é uma tabela hash?',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.manrope(
                                  fontSize: 17.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1.3,
                                  color: isBack ? onPrimary : textCol,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 3 botões reais de avaliação do Noesis (Difícil 🔴, Bom 🟡, Fácil 🟢)
        Row(
          children: [
            Expanded(
              child: _RatingPill(
                label: 'Difícil 🔴',
                color: AsterConstants.coral,
                selected: _lastCardRating == 'Difícil',
                onTap: () => setState(() => _lastCardRating = 'Difícil'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RatingPill(
                label: 'Bom 🟡',
                color: AsterConstants.ambar,
                selected: _lastCardRating == 'Bom',
                onTap: () => setState(() => _lastCardRating = 'Bom'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RatingPill(
                label: 'Fácil 🟢',
                color: AsterConstants.menta,
                selected: _lastCardRating == 'Fácil',
                onTap: () => setState(() => _lastCardRating = 'Fácil'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Trilha interativa com etapas conectadas estilo RoadmapsScreen
        _ShowcaseVcard(
          cardCol: cardCol,
          insetCol: insetCol,
          child: Builder(
            builder: (context) {
              const stepTitles = [
                'Fundamentos & Complexidade',
                'Tabela Hash & Colisões',
                'Árvores AVL & Simulado',
                'Grafos & Caminho Mínimo',
                'Revisão Espaçada 3D',
              ];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.route_rounded, size: 14, color: primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'TRILHA · ESTRUTURAS DE DADOS',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                            color: mutedCol,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                        ),
                        child: Text(
                          'Etapa ${_activeRoadmapStep + 1}/5',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: List.generate(9, (index) {
                      if (index.isOdd) {
                        final connectorStep = index ~/ 2;
                        final done = connectorStep < _activeRoadmapStep;
                        return Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: done
                                  ? AsterConstants.menta
                                  : insetCol.withValues(alpha: 0.8),
                            ),
                          ),
                        );
                      }
                      final step = index ~/ 2;
                      final done = step < _activeRoadmapStep;
                      final current = step == _activeRoadmapStep;
                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => setState(() => _activeRoadmapStep = step),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: done
                                  ? AsterConstants.menta
                                  : (current
                                      ? primary
                                      : altCol),
                              border: Border.all(
                                color: done
                                    ? AsterConstants.menta
                                    : (current
                                        ? primary
                                        : insetCol),
                                width: current ? 2 : 1.2,
                              ),
                              boxShadow: current
                                  ? [
                                      BoxShadow(
                                        color: primary.withValues(alpha: 0.28),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: done
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                  : Text(
                                      '${step + 1}',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: current ? Colors.white : mutedCol,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stepTitles[_activeRoadmapStep],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: textCol,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Clique na etapa',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: mutedCol,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPillarAgentCalendarVisual(
    Color cardCol,
    Color altCol,
    Color insetCol,
    Color primary,
    Color textCol,
    Color mutedCol,
  ) {
    Widget doneBadge(String text) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: AsterConstants.menta.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          border: Border.all(color: AsterConstants.menta.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 15,
              height: 15,
              decoration: const BoxDecoration(
                color: AsterConstants.menta,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, size: 11, color: Colors.white),
            ),
            const SizedBox(width: 7),
            Text(
              text,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textCol,
              ),
            ),
          ],
        ),
      );
    }

    Widget eventRow(Color barColor, String label, String time) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: altCol,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 11),
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
            Text(
              time,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: mutedCol,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ShowcaseVcard(
          cardCol: cardCol,
          insetCol: insetCol,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const NoesisLogo(size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Noesis AI · Agente Cognitivo',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: textCol,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  doneBadge('Simulado gerado'),
                  doneBadge('Baralho 3D criado'),
                  doneBadge('Agenda atualizada'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _ShowcaseVcard(
          cardCol: cardCol,
          insetCol: insetCol,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'AGENDA · SEXTA',
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: mutedCol,
                ),
              ),
              eventRow(primary, 'Bloco de foco', '08:00'),
              eventRow(AsterConstants.coral, 'Simulado RAG', '14:00'),
              eventRow(AsterConstants.menta, 'Revisão · flashcards', '19:00'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPillarCommunityVisual(
    Color cardCol,
    Color altCol,
    Color insetCol,
    Color primary,
    Color textCol,
    Color mutedCol,
  ) {
    final sophiaTier = RankingEloCatalog.tiers[5];

    Widget rankRow(
      int pos,
      String name,
      String handle,
      String insights,
      String avatarAsset, {
      bool isPromoted = false,
    }) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isPromoted ? AsterConstants.menta.withValues(alpha: 0.08) : altCol,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPromoted
                ? AsterConstants.menta.withValues(alpha: 0.45)
                : insetCol.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '#$pos',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: pos == 1 ? AsterConstants.ambar : mutedCol,
                ),
              ),
            ),
            ClipOval(
              child: Image.asset(
                avatarAsset,
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => CircleAvatar(
                  radius: 14,
                  backgroundColor: primary,
                  child: Text(
                    name.substring(0, 1),
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: textCol,
                    ),
                  ),
                  Text(
                    handle,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isPromoted ? AsterConstants.menta : mutedCol,
                    ),
                  ),
                ],
              ),
            ),
            const InsightCoinIcon(size: 13),
            const SizedBox(width: 4),
            Text(
              insights,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textCol,
              ),
            ),
          ],
        ),
      );
    }

    return _ShowcaseVcard(
      cardCol: cardCol,
      insetCol: insetCol,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              NoesisEloBadge(tier: sophiaTier, size: 28),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Elo ${sophiaTier.name} · Chave da Semana',
                      style: GoogleFonts.manrope(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: textCol,
                      ),
                    ),
                    Text(
                      'Zona de Promoção · +50% Insights',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: mutedCol,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined, size: 13, color: primary),
                    const SizedBox(width: 4),
                    Text(
                      '3d 14h',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          rankRow(1, 'Marina', '@marina · Zona de Promoção', '420', 'assets/images/avatar_marina.jpg', isPromoted: true),
          rankRow(2, 'Caio', '@caio.dev · Zona de Promoção', '365', 'assets/images/avatar_davi.jpg', isPromoted: true),
          rankRow(3, 'Luna', '@luna · Zona Segura', '310', 'assets/images/avatar_luna.jpg'),
        ],
      ),
    );
  }
}

class _ShowcaseVcard extends StatelessWidget {
  const _ShowcaseVcard({
    required this.cardCol,
    required this.insetCol,
    required this.child,
  });

  final Color cardCol;
  final Color insetCol;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardCol,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: insetCol.withValues(alpha: isDark ? 0.75 : 0.9)),
        boxShadow: isDark ? AsterConstants.claySubtleDarkShadow : AsterConstants.claySubtleShadow,
      ),
      child: child,
    );
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LandingHoverLift(
      liftY: -2.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? 0.25 : 0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.35),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AsterTheme.text(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShowcaseWeekBars extends StatelessWidget {
  const _ShowcaseWeekBars({
    required this.primary,
    required this.mutedCol,
  });

  final Color primary;
  final Color mutedCol;

  static const _bars = [
    (day: 'S', pct: 0.55),
    (day: 'T', pct: 0.70),
    (day: 'Q', pct: 0.40),
    (day: 'Q', pct: 0.85),
    (day: 'S', pct: 0.62),
    (day: 'S', pct: 0.30),
    (day: 'D', pct: 0.76),
  ];

  @override
  Widget build(BuildContext context) {
    final animMs = isLandingTestEnvironment() ? 0 : 480;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(_bars.length, (i) {
        final b = _bars[i];
        final isToday = i == _bars.length - 1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == _bars.length - 1 ? 0 : 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 54,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.12, end: b.pct),
                      duration: Duration(milliseconds: animMs + (i * 65)),
                      curve: kLandingFluidCurve,
                      builder: (context, v, _) {
                        return FractionallySizedBox(
                          heightFactor: v,
                          widthFactor: 0.62,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: isToday
                                  ? primary
                                  : primary.withValues(alpha: 0.42),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  b.day,
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w700,
                    color: isToday ? primary : mutedCol,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
