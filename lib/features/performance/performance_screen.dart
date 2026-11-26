import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../widgets/insight_icon.dart';
import '../tracker/dashboard_analytics.dart';
import 'data/performance_analytics_service.dart';
import 'models/performance_report_model.dart';

/// Página **Desempenho Analítico**:
/// reúne toda a utilização da conta em um painel analítico com filtros de período,
/// curvas/gráficos evolutivos, distribuição por matéria e reviews longitudinais da IA.
class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  PerformancePeriod _period = PerformancePeriod.days30;
  DateTimeRange? _customRange;
  AccountPerformanceReport? _report;
  bool _loading = true;
  bool _generatingAiReview = false;
  int _selectedReviewIndex = 0;

  @override
  void initState() {
    super.initState();
    _refreshReport();
  }

  Future<void> _refreshReport() async {
    setState(() => _loading = true);
    final report = await PerformanceAnalyticsService.instance.loadReport(
      period: _period,
      customRange: _customRange,
    );
    if (!mounted) return;
    setState(() {
      _report = report;
      _loading = false;
    });
  }

  Future<void> _selectPeriod(PerformancePeriod next) async {
    if (next == PerformancePeriod.custom) {
      final now = PerformanceAnalyticsService.currentNow();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2023),
        lastDate: now,
        initialDateRange: _customRange ??
            DateTimeRange(
              start: now.subtract(const Duration(days: 14)),
              end: now,
            ),
      );
      if (picked == null || !mounted) return;
      _customRange = picked;
    }
    setState(() => _period = next);
    await _refreshReport();
  }

  Future<void> _generateAiReview() async {
    final report = _report;
    if (report == null || _generatingAiReview) return;
    setState(() => _generatingAiReview = true);
    try {
      await PerformanceAnalyticsService.instance.generateAndSaveAiReview(report);
      if (mounted) {
        setState(() => _selectedReviewIndex = 0);
      }
    } finally {
      if (mounted) {
        setState(() => _generatingAiReview = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final report = _report;

    return SingleChildScrollView(
      key: const Key('performance_screen_root'),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 36.0 : 16.0,
        vertical: 18.0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Cabeçalho ───
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const NoesisCollapsedMenuSpacer(width: 82),
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isDesktop ? 560 : MediaQuery.sizeOf(context).width - 72,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: AsterTheme.primary(context).withValues(alpha: 0.14),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.analytics_rounded,
                                  size: 23,
                                  color: AsterTheme.primary(context),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Desempenho & Analytics',
                                      style: GoogleFonts.manrope(
                                        fontSize: isDesktop ? 21 : 19,
                                        fontWeight: FontWeight.w900,
                                        color: AsterTheme.text(context),
                                      ),
                                    ),
                                    Text(
                                      'Panorama analítico completo da conta, filtros por período e reviews da IA',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12.5,
                                        color: AsterTheme.textMuted(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Atualizar métricas',
                          onPressed: _refreshReport,
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ─── Barra de Filtro por Período ───
              SoftClayCard(
                key: const Key('performance_period_bar'),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'PERÍODO:',
                          style: GoogleFonts.manrope(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
                            color: AsterTheme.textMuted(context),
                          ),
                        ),
                        SoftClayChoiceChip(
                          key: const Key('perf_period_7d'),
                          label: '7 dias',
                          selected: _period == PerformancePeriod.days7,
                          compact: true,
                          onTap: () => _selectPeriod(PerformancePeriod.days7),
                        ),
                        SoftClayChoiceChip(
                          key: const Key('perf_period_30d'),
                          label: '30 dias',
                          selected: _period == PerformancePeriod.days30,
                          compact: true,
                          onTap: () => _selectPeriod(PerformancePeriod.days30),
                        ),
                        SoftClayChoiceChip(
                          key: const Key('perf_period_90d'),
                          label: '90 dias',
                          selected: _period == PerformancePeriod.days90,
                          compact: true,
                          onTap: () => _selectPeriod(PerformancePeriod.days90),
                        ),
                        SoftClayChoiceChip(
                          key: const Key('perf_period_all'),
                          label: 'Todo o histórico',
                          selected: _period == PerformancePeriod.allTime,
                          compact: true,
                          onTap: () => _selectPeriod(PerformancePeriod.allTime),
                        ),
                        SoftClayChoiceChip(
                          key: const Key('perf_period_custom'),
                          label: _period == PerformancePeriod.custom && report != null
                              ? report.range.label
                              : 'Personalizado',
                          icon: Icons.date_range_rounded,
                          selected: _period == PerformancePeriod.custom,
                          compact: true,
                          onTap: () => _selectPeriod(PerformancePeriod.custom),
                        ),
                      ],
                    ),
                    if (report != null)
                      SoftClayTag(
                        label: '${report.range.spanDays} ${report.range.spanDays == 1 ? 'dia analisado' : 'dias analisados'}',
                        color: AsterTheme.primary(context),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              if (_loading || report == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                // ─── 1. KPIs Executivos da Conta no Período ───
                _buildExecutiveKpis(context, report, isDesktop),
                const SizedBox(height: 18),

                // ─── 2. Reviews da IA ao Longo do Tempo ───
                _buildAiReviewsSection(context, report),
                const SizedBox(height: 18),

                // ─── 3. Gráficos Analíticos (Tempo & Curva de Simulados) ───
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildStudyTimeChartCard(context, report)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildExamCurveChartCard(context, report)),
                    ],
                  )
                else ...[
                  _buildStudyTimeChartCard(context, report),
                  const SizedBox(height: 16),
                  _buildExamCurveChartCard(context, report),
                ],
                const SizedBox(height: 18),

                // ─── 4. Breakdown por Matéria / Disciplina ───
                _buildSubjectsBreakdownCard(context, report),
                const SizedBox(height: 18),

                // ─── 5. Consolidado Geral de Uso do Ecossistema ───
                _buildEcosystemUtilizationGrid(context, report),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExecutiveKpis(
    BuildContext context,
    AccountPerformanceReport report,
    bool isDesktop,
  ) {
    final hoursStr = DashboardAnalytics.formatReadableDuration(report.periodMinutes);
    final delta = report.minutesDeltaPct;
    final deltaSub = delta == null
        ? '${report.sessionsCount} sessões · média ${DashboardAnalytics.formatCompactDuration(report.dailyAverageMinutes)}/dia'
        : '${delta >= 0 ? '+' : ''}$delta% vs ciclo anterior · ${report.sessionsCount} sessões';

    final examAvg = report.averageExamScore != null ? '${report.averageExamScore!.round()}%' : '—';
    final examSub = report.examsCount == 0
        ? 'Nenhum simulado no período'
        : '${report.examsCount} provas · ${report.totalQuestionsAnswered} questões · máx ${report.bestExamScore?.round() ?? 0}%';

    final retentionVal = report.totalCards > 0 ? '${report.retentionRatePct}%' : '—';
    final retentionSub = '${report.cardsReviewedInPeriod} revisados no período · ${report.cardsDueCount} pendentes';

    final cards = [
      _kpiCard(
        context,
        key: const Key('perf_kpi_hours'),
        title: 'TEMPO ESTUDADO',
        value: hoursStr,
        subtitle: deltaSub,
        icon: Icons.schedule_rounded,
        accent: AsterTheme.primary(context),
      ),
      _kpiCard(
        context,
        key: const Key('perf_kpi_exams'),
        title: 'ACURÁCIA EM SIMULADOS',
        value: examAvg,
        subtitle: examSub,
        icon: Icons.assignment_turned_in_rounded,
        accent: AsterConstants.menta,
      ),
      _kpiCard(
        context,
        key: const Key('perf_kpi_flashcards'),
        title: 'RETENÇÃO FLASHCARDS',
        value: retentionVal,
        subtitle: retentionSub,
        icon: Icons.style_rounded,
        accent: AsterConstants.ambar,
      ),
      _kpiCard(
        context,
        key: const Key('perf_kpi_insights'),
        title: 'INSIGHTS NO PERÍODO',
        value: '+${report.insightsEarnedInPeriod}',
        subtitle: '-${report.insightsInvestedInPeriod} investidos · Elo ${report.currentEloName} (#${report.currentWeeklyRank})',
        icon: Icons.auto_awesome_rounded,
        accent: AsterConstants.coral,
        showCoin: true,
      ),
    ];

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards,
    );
  }

  Widget _kpiCard(
    BuildContext context, {
    Key? key,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accent,
    bool showCoin = false,
  }) {
    return SoftClayCard(
      key: key,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 15, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: AsterTheme.textMuted(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AsterTheme.text(context),
                  ),
                ),
              ),
              if (showCoin) ...[
                const SizedBox(width: 6),
                const InsightCoinIcon(size: 16),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AsterTheme.textMuted(context),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiReviewsSection(BuildContext context, AccountPerformanceReport report) {
    final primaryCol = AsterTheme.primary(context);

    return ValueListenableBuilder<List<PerformanceAiReview>>(
      valueListenable: PerformanceAnalyticsService.instance.reviewsNotifier,
      builder: (context, savedReviews, _) {
        final safeIdx = savedReviews.isEmpty
            ? 0
            : _selectedReviewIndex.clamp(0, savedReviews.length - 1);
        final activeReview = savedReviews.isNotEmpty ? savedReviews[safeIdx] : null;

        return SoftClayCard(
          key: const Key('performance_ai_review_card'),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width >= 900
                          ? 560
                          : MediaQuery.sizeOf(context).width - 68,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: primaryCol.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.psychology_rounded, color: primaryCol, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reviews da IA sobre sua Evolução',
                                style: GoogleFonts.manrope(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AsterTheme.text(context),
                                ),
                              ),
                              Text(
                                'Diagnóstico longitudinal cruzando tempo estudado, simulados, flashcards, trilhas e hábitos',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: AsterTheme.textMuted(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SoftClayPillButton(
                    key: const Key('performance_generate_ai_review_button'),
                    text: _generatingAiReview ? 'Analisando...' : 'Gerar Review com IA',
                    icon: Icons.auto_awesome_rounded,
                    onPressed: _generatingAiReview ? null : _generateAiReview,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (savedReviews.isNotEmpty) ...[
                Text(
                  'HISTÓRICO DE REVIEWS AO LONGO DO TEMPO (${savedReviews.length})',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AsterTheme.textMuted(context),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  key: const Key('performance_ai_reviews_timeline'),
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int i = 0; i < savedReviews.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        SoftClayChoiceChip(
                          key: Key('perf_review_chip_${i}_${savedReviews[i].id}'),
                          label:
                              '${savedReviews[i].createdAt.day.toString().padLeft(2, '0')}/${savedReviews[i].createdAt.month.toString().padLeft(2, '0')} · ${savedReviews[i].periodLabel}',
                          icon: savedReviews[i].generatedWithLlm
                              ? Icons.auto_awesome_rounded
                              : Icons.analytics_outlined,
                          selected: i == safeIdx,
                          compact: true,
                          onTap: () => setState(() => _selectedReviewIndex = i),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              if (activeReview != null)
                Container(
                  key: const Key('performance_active_ai_review_body'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AsterTheme.surfaceAlt(context),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                    border: Border.all(color: primaryCol.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SoftClayTag(
                            label: activeReview.summaryHeadline,
                            color: primaryCol,
                          ),
                          Text(
                            'Gerado em ${activeReview.createdAt.day.toString().padLeft(2, '0')}/${activeReview.createdAt.month.toString().padLeft(2, '0')}/${activeReview.createdAt.year} às ${activeReview.createdAt.hour.toString().padLeft(2, '0')}:${activeReview.createdAt.minute.toString().padLeft(2, '0')}',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: AsterTheme.textMuted(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      MarkdownBody(
                        data: activeReview.markdownContent,
                        styleSheet: MarkdownStyleSheet(
                          h3: GoogleFonts.manrope(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AsterTheme.text(context),
                          ),
                          p: GoogleFonts.manrope(
                            fontSize: 12.5,
                            height: 1.5,
                            color: AsterTheme.text(context),
                          ),
                          listBullet: GoogleFonts.manrope(
                            fontSize: 12.5,
                            color: primaryCol,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AsterTheme.surfaceAlt(context),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                    border: Border.all(color: AsterTheme.surfaceInset(context)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.tips_and_updates_rounded, color: primaryCol, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Clique em "Gerar Review com IA" para criar uma análise completa do período "${report.range.label}" e salvar na sua linha do tempo evolutiva.',
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            color: AsterTheme.textMuted(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static double _resolveDurationAxisInterval(int maxMinutes) {
    final targetStep = (maxMinutes <= 0 ? 60.0 : maxMinutes * 1.15) / 3.0;
    const niceSteps = <double>[
      15,
      20,
      30,
      45,
      60,
      90,
      120,
      150,
      180,
      240,
      300,
      360,
      480,
      600,
      720,
    ];
    for (final s in niceSteps) {
      if (s >= targetStep) return s;
    }
    return (targetStep / 60.0).ceil() * 60.0;
  }

  Widget _buildStudyTimeChartCard(BuildContext context, AccountPerformanceReport report) {
    final buckets = report.timeBuckets;
    final maxMins = buckets.fold<int>(0, (m, b) => b.minutes > m ? b.minutes : m);
    final intervalY = _resolveDurationAxisInterval(maxMins);
    final maxY = intervalY * 3.0;
    final primaryCol = AsterTheme.primary(context);

    return SoftClayCard(
      key: const Key('performance_time_chart_card'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'RITMO DE ESTUDO NO PERÍODO',
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: AsterTheme.textMuted(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Distribuição de tempo estudado (${report.range.label})',
            style: GoogleFonts.manrope(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AsterTheme.text(context),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 190,
            child: buckets.isEmpty
                ? Center(
                    child: Text(
                      'Sem registros no período.',
                      style: GoogleFonts.manrope(fontSize: 12.5, color: AsterTheme.textMuted(context)),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      maxY: maxY,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final idx = group.x;
                            if (idx < 0 || idx >= buckets.length) return null;
                            final b = buckets[idx];
                            return BarTooltipItem(
                              '${b.label}\n${DashboardAnalytics.formatReadableDuration(b.minutes)}',
                              GoogleFonts.manrope(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: intervalY,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: AsterTheme.surfaceInset(context),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            interval: intervalY,
                            getTitlesWidget: (v, _) => Text(
                              DashboardAnalytics.formatCompactDuration(v.round()),
                              maxLines: 1,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                color: AsterTheme.textMuted(context),
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            getTitlesWidget: (v, _) {
                              final idx = v.toInt();
                              if (idx < 0 || idx >= buckets.length) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  buckets[idx].label,
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AsterTheme.textMuted(context),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (int i = 0; i < buckets.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: buckets[i].minutes.toDouble(),
                                width: buckets.length <= 7 ? 20 : 24,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                color: buckets[i].minutes > 0
                                    ? primaryCol
                                    : AsterTheme.surfaceInset(context),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamCurveChartCard(BuildContext context, AccountPerformanceReport report) {
    final points = report.examTrend;

    return SoftClayCard(
      key: const Key('performance_exam_chart_card'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'EVOLUÇÃO EM SIMULADOS',
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: AsterTheme.textMuted(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            points.isEmpty
                ? 'Sem simulados neste recorte'
                : 'Curva de acurácia (${points.length} ${points.length == 1 ? 'prova' : 'provas'})',
            style: GoogleFonts.manrope(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AsterTheme.text(context),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 190,
            child: points.isEmpty
                ? Container(
                    decoration: BoxDecoration(
                      color: AsterTheme.surfaceAlt(context),
                      borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                    ),
                    child: Center(
                      child: Text(
                        'Conclua simulados no período para acompanhar sua curva de acerto.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AsterTheme.textMuted(context),
                        ),
                      ),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 100,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 25,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: AsterTheme.surfaceInset(context),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            interval: 25,
                            getTitlesWidget: (v, _) => Text(
                              '${v.round()}%',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                color: AsterTheme.textMuted(context),
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            interval: 1,
                            getTitlesWidget: (v, _) {
                              final idx = v.toInt();
                              if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'S${idx + 1}',
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AsterTheme.textMuted(context),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (int i = 0; i < points.length; i++)
                              FlSpot(i.toDouble(), points[i].scorePercentage.clamp(0, 100)),
                          ],
                          isCurved: points.length > 2,
                          barWidth: 3,
                          color: AsterConstants.menta,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AsterConstants.menta.withValues(alpha: 0.14),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectsBreakdownCard(BuildContext context, AccountPerformanceReport report) {
    final items = report.subjectBreakdowns;
    final primaryCol = AsterTheme.primary(context);

    return SoftClayCard(
      key: const Key('performance_subjects_breakdown'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'DESEMPENHO POR DISCIPLINA',
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: AsterTheme.textMuted(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Esforço dedicado e aproveitamento em simulados por matéria',
            style: GoogleFonts.manrope(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AsterTheme.text(context),
            ),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Text(
              'Nenhuma disciplina registrada neste período ainda.',
              style: GoogleFonts.manrope(fontSize: 12.5, color: AsterTheme.textMuted(context)),
            )
          else
            ...items.take(8).map((item) {
              final pct = (item.shareFraction * 100).round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.subject,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AsterTheme.text(context),
                            ),
                          ),
                        ),
                        if (item.averageExamScore != null) ...[
                          SoftClayTag(
                            label: 'Média ${item.averageExamScore!.round()}% (${item.examCount})',
                            color: AsterConstants.menta,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          '${DashboardAnalytics.formatReadableDuration(item.minutes)} ($pct%)',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: primaryCol,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      child: LinearProgressIndicator(
                        value: item.shareFraction > 0 ? item.shareFraction : (item.examCount > 0 ? 0.12 : 0),
                        minHeight: 7,
                        backgroundColor: AsterTheme.surfaceInset(context),
                        valueColor: AlwaysStoppedAnimation(primaryCol),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEcosystemUtilizationGrid(BuildContext context, AccountPerformanceReport report) {
    final blocks = [
      _ecoBlock(
        context,
        icon: Icons.style_rounded,
        accent: AsterConstants.ambar,
        title: 'Flashcards & Memória',
        rows: [
          ('Baralhos / Cartões', '${report.totalDecks} baralhos · ${report.totalCards} cards'),
          ('Domínio (Fácil / Bom)', '${report.easyCards} fáceis · ${report.goodCards} bons'),
          ('Difíceis / Pendentes', '${report.hardCards} difíceis · ${report.cardsDueCount} p/ revisar'),
        ],
      ),
      _ecoBlock(
        context,
        icon: Icons.menu_book_rounded,
        accent: AsterConstants.menta,
        title: 'Cadernos & Trilhas',
        rows: [
          ('Cadernos & Anotações', '${report.totalNotebooks} cadernos · ${report.totalNotes} notas'),
          ('Notas no período / Revisão', '${report.notesUpdatedInPeriod} no período · ${report.notesNeedingReview} p/ revisar'),
          ('Trilhas de Estudo', '${report.completedRoadmapSteps}/${report.totalRoadmapSteps} etapas (${report.roadmapProgressPct}%)'),
        ],
      ),
      _ecoBlock(
        context,
        icon: Icons.calendar_today_rounded,
        accent: AsterTheme.primary(context),
        title: 'Agenda & Metas',
        rows: [
          ('Eventos no período', '${report.calendarCompletedInPeriod}/${report.calendarEventsInPeriod} concluídos'),
          ('Próximos agendamentos', '${report.calendarPendingUpcoming} pendentes'),
          (
            'Meta diária / semanal',
            '${report.dailyGoalMinutes > 0 ? DashboardAnalytics.formatCompactDuration(report.dailyGoalMinutes) : 'Livre'} · ${report.weeklyGoalMinutes > 0 ? DashboardAnalytics.formatCompactDuration(report.weeklyGoalMinutes) : 'Livre'}',
          ),
        ],
      ),
      _ecoBlock(
        context,
        icon: Icons.emoji_events_rounded,
        accent: AsterConstants.coral,
        title: 'Ranking, Economia & Rede',
        rows: [
          ('Elo Atual / Recorde', '${report.currentEloName} · Melhor: ${report.bestEloName}'),
          ('Saldo & Selos', '${report.currentInsightsBalance} Insights · ${report.consistencySealsCount} selos'),
          ('Comunidade', '${report.joinedGroupsCount} grupos · ${report.mutualConnectionsCount} conexões mútuas'),
        ],
      ),
    ];

    return SoftClayCard(
      key: const Key('performance_ecosystem_matrix'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'UTILIZAÇÃO COMPLETA DA CONTA',
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: AsterTheme.textMuted(context),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoCols = constraints.maxWidth >= 680;
              final tileW = twoCols ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: blocks.map((b) => SizedBox(width: tileW, child: b)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _ecoBlock(
    BuildContext context, {
    required IconData icon,
    required Color accent,
    required String title,
    required List<(String, String)> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AsterTheme.surfaceAlt(context),
        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AsterTheme.text(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      r.$1,
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        color: AsterTheme.textMuted(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    r.$2,
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AsterTheme.text(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
