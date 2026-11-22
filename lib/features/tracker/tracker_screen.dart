import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/supabase_service.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  // Timer State
  Timer? _timer;
  int _secondsElapsed = 47 * 60 + 12; // Inicia em 00:47:12 para demonstrar o visual idêntico ao mock
  late final ValueNotifier<int> _secondsNotifier;
  late final ValueNotifier<bool> _isTimerRunningNotifier;
  late final ValueNotifier<String> _activeSubjectNotifier;
  late final Stream<List<Map<String, dynamic>>> _sessionsStream;
  bool _isTimerRunning = false;
  String _activeSubject = 'Criptografia';

  // Modal Controllers
  final _subjectController = TextEditingController();
  final _topicController = TextEditingController();
  final _durationController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _secondsNotifier = ValueNotifier<int>(_secondsElapsed);
    _isTimerRunningNotifier = ValueNotifier<bool>(_isTimerRunning);
    _activeSubjectNotifier = ValueNotifier<String>(_activeSubject);
    _sessionsStream = SupabaseService.studySessionsStream().distinct((prev, next) {
      if (prev.length != next.length) return false;
      for (int i = 0; i < prev.length; i++) {
        if (!mapEquals(prev[i], next[i])) return false;
      }
      return true;
    });
  }

  void _startTimer() {
    _isTimerRunning = true;
    _isTimerRunningNotifier.value = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _secondsElapsed++;
      _secondsNotifier.value = _secondsElapsed;
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    _isTimerRunning = false;
    _isTimerRunningNotifier.value = false;
  }

  void _resetTimer() {
    _timer?.cancel();
    _secondsElapsed = 0;
    _secondsNotifier.value = 0;
    _isTimerRunning = false;
    _isTimerRunningNotifier.value = false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _secondsNotifier.dispose();
    _isTimerRunningNotifier.dispose();
    _activeSubjectNotifier.dispose();
    _subjectController.dispose();
    _topicController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatHours(int seconds) => (seconds ~/ 3600).toString().padLeft(2, '0');
  String _formatMinutes(int seconds) => ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
  String _formatSecs(int seconds) => (seconds % 60).toString().padLeft(2, '0');

  void _openAddSessionModal({int? defaultDurationMinutes}) {
    if (defaultDurationMinutes != null) {
      _durationController.text = defaultDurationMinutes.toString();
    }
    _subjectController.text = _activeSubject;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AsterConstants.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
        title: Text(
          'Registrar Sessão de Estudo',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AsterConstants.textDark),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _subjectController,
                decoration: const InputDecoration(labelText: 'Disciplina (ex: Criptografia, Cloud)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _topicController,
                decoration: const InputDecoration(labelText: 'Tópico (ex: AES-GCM, Modos de Operação)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Duração em Minutos (ex: 90)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Anotações e Insights'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: GoogleFonts.manrope(color: AsterConstants.textMuted)),
          ),
          SoftClayPillButton(
            text: 'Salvar Sessão',
            onPressed: () {
              final subject = _subjectController.text.trim();
              final topic = _topicController.text.trim();
              final duration = int.tryParse(_durationController.text.trim()) ?? 0;
              final notes = _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null;

              if (subject.isNotEmpty && topic.isNotEmpty && duration > 0) {
                // Fechamento imediato do modal (0ms UI feedback otimista)
                Navigator.pop(ctx);
                _subjectController.clear();
                _topicController.clear();
                _durationController.clear();
                _notesController.clear();
                _resetTimer();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sessão registrada com sucesso!')),
                  );
                }

                // Sincronização em segundo plano via SupabaseService com tratamento de erro
                SupabaseService.addStudySession(
                  subject: subject,
                  topic: topic,
                  durationMinutes: duration,
                  studyDate: DateTime.now(),
                  notes: notes,
                ).catchError((e) {
                  debugPrint('Erro ao sincronizar sessão de estudo: $e');
                });
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28.0 : 16.0,
        vertical: 12.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Linha 1: Timer Hero & Horas Estudadas ───
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildTimerHeroCard()),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: _buildLoweredHoursStatsCard()),
              ],
            )
          else ...[
            _buildTimerHeroCard(),
            const SizedBox(height: 16),
            _buildLoweredHoursStatsCard(),
          ],

          const SizedBox(height: 20),

          // ─── Linha 2: Distribuição & Heatmap de Consistência ───
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildLoweredDistributionCard()),
                const SizedBox(width: 20),
                Expanded(flex: 3, child: _buildHeatmapCard()),
              ],
            )
          else ...[
            _buildLoweredDistributionCard(),
            const SizedBox(height: 16),
            _buildHeatmapCard(),
          ],

          const SizedBox(height: 20),

          // ─── Linha 3: Sessões Recentes & Insight do Agente ───
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildLoweredRecentSessionsCard()),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: _buildAgentInsightCard()),
              ],
            )
          else ...[
            _buildLoweredRecentSessionsCard(),
            const SizedBox(height: 16),
            _buildAgentInsightCard(),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildLoweredHoursStatsCard() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _sessionsStream,
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? [];
        int totalMinutes = 0;
        for (var s in sessions) {
          totalMinutes += (s['duration_minutes'] as num?)?.toInt() ?? 0;
        }
        if (totalMinutes == 0) totalMinutes = 123 * 60;
        return _buildHoursStatsCard(totalMinutes);
      },
    );
  }

  Widget _buildLoweredDistributionCard() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _sessionsStream,
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? [];
        int totalMinutes = 0;
        final Map<String, int> subjectMinutes = {};
        for (var s in sessions) {
          final int m = (s['duration_minutes'] as num?)?.toInt() ?? 0;
          totalMinutes += m;
          final String sub = (s['subject'] as String?) ?? 'Outros';
          subjectMinutes[sub] = (subjectMinutes[sub] ?? 0) + m;
        }
        if (subjectMinutes.isEmpty) {
          subjectMinutes['Criptografia'] = 42 * 60;
          subjectMinutes['Cloud / AWS'] = 31 * 60;
          subjectMinutes['Redes & OWASP'] = 27 * 60;
          subjectMinutes['Sistemas Dist.'] = 23 * 60;
          totalMinutes = 123 * 60;
        }
        return _buildDistributionCard(subjectMinutes, totalMinutes);
      },
    );
  }

  Widget _buildLoweredRecentSessionsCard() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _sessionsStream,
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? [];
        return _buildRecentSessionsCard(sessions);
      },
    );
  }

  // ─── Widget: Timer Hero Card (Identidade Soft Clay) ───
  Widget _buildTimerHeroCard() {
    return SoftClayCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag de Sessão Ativa
          Row(
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
                  letterSpacing: 1.2,
                  color: AsterConstants.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Mostrador do Timer com ValueListenableBuilder (apenas os dígitos re-renderizam a cada segundo)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ValueListenableBuilder<int>(
                valueListenable: _secondsNotifier,
                builder: (context, seconds, _) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_formatHours(seconds)}:${_formatMinutes(seconds)}',
                        style: GoogleFonts.manrope(
                          fontSize: 54,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.5,
                          color: AsterConstants.textDark,
                        ),
                      ),
                      Text(
                        ':${_formatSecs(seconds)}',
                        style: GoogleFonts.manrope(
                          fontSize: 54,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.5,
                          color: AsterConstants.lavanda.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const Spacer(),

              // Botão Flag (Marcador de volta/anotação)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AsterConstants.surfaceAlt,
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                ),
                child: IconButton(
                  icon: const Icon(Icons.flag_outlined, size: 20, color: AsterConstants.textDark),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Marcador de ciclo registrado!')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),

              // Botão Play / Pausar Primário
              ValueListenableBuilder<bool>(
                valueListenable: _isTimerRunningNotifier,
                builder: (context, isRunning, _) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: AsterConstants.lavanda,
                      borderRadius: BorderRadius.all(Radius.circular(AsterConstants.radiusPill)),
                      boxShadow: AsterConstants.primaryButtonShadow,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                        onTap: isRunning ? _pauseTimer : _startTimer,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isRunning ? 'Pausar' : 'Iniciar',
                                style: GoogleFonts.manrope(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),

              // Botão Salvar / Concluir
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AsterConstants.surfaceAlt,
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                ),
                child: IconButton(
                  icon: const Icon(Icons.check_rounded, size: 20, color: AsterConstants.textDark),
                  tooltip: 'Concluir & Salvar',
                  onPressed: () {
                    final mins = (_secondsElapsed / 60).ceil();
                    _openAddSessionModal(defaultDurationMinutes: mins > 0 ? mins : 1);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Chips de Disciplina & Meta da Sessão
          Row(
            children: [
              ValueListenableBuilder<String>(
                valueListenable: _activeSubjectNotifier,
                builder: (context, activeSubject, _) {
                  return SoftClayTag(
                    label: activeSubject,
                    color: AsterConstants.lavanda,
                    onTap: () {
                      final next = activeSubject == 'Criptografia' ? 'Cloud / AWS' : 'Criptografia';
                      _activeSubject = next;
                      _activeSubjectNotifier.value = next;
                    },
                  );
                },
              ),
              const SizedBox(width: 12),
              Text(
                'Meta da sessão: 1h30',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: AsterConstants.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Linha de Progresso Suave Inferior
          ValueListenableBuilder<int>(
            valueListenable: _secondsNotifier,
            builder: (context, seconds, _) {
              return LinearProgressIndicator(
                value: (seconds / (90 * 60)).clamp(0.0, 1.0),
                minHeight: 4,
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                backgroundColor: AsterConstants.surfaceInset,
                valueColor: const AlwaysStoppedAnimation(AsterConstants.lavanda),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Widget: Horas Estudadas nos Últimos 7 Dias ───
  Widget _buildHoursStatsCard(int totalMinutes) {
    final hours = (totalMinutes / 60).toStringAsFixed(0);

    return SoftClayCard.list(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Horas estudadas',
                style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: AsterConstants.textDark),
              ),
              Text(
                'últimos 7 dias',
                style: GoogleFonts.manrope(fontSize: 11, color: AsterConstants.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${hours}h',
                style: GoogleFonts.manrope(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  color: AsterConstants.textDark,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '↑ 18% vs. semana ant.',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AsterConstants.menta,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Mini Gráfico de Barras em Pílula
          SizedBox(
            height: 72,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildMiniBar('S', 0.45),
                _buildMiniBar('T', 0.65),
                _buildMiniBar('Q', 0.35),
                _buildMiniBar('Q', 0.85),
                _buildMiniBar('S', 0.70),
                _buildMiniBar('S', 0.50),
                _buildMiniBar('D', 1.0, isHighlight: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBar(String day, double heightFraction, {bool isHighlight = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 16,
          height: 44 * heightFraction,
          decoration: BoxDecoration(
            color: isHighlight ? AsterConstants.lavanda : AsterConstants.lavanda.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          day,
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
            color: isHighlight ? AsterConstants.lavanda : AsterConstants.textMuted,
          ),
        ),
      ],
    );
  }

  // ─── Widget: Distribuição por Disciplina (Donut Chart) ───
  Widget _buildDistributionCard(Map<String, int> subjectMinutes, int totalMinutes) {
    final colors = [
      AsterConstants.lavanda,
      AsterConstants.menta,
      AsterConstants.ambar,
      AsterConstants.coral,
    ];

    return SoftClayCard.list(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Distribuição',
                style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: AsterConstants.textDark),
              ),
              Text(
                'por disciplina',
                style: GoogleFonts.manrope(fontSize: 12, color: AsterConstants.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              // Donut Chart com centro "4 áreas"
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    RepaintBoundary(
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 36,
                          sections: subjectMinutes.entries.toList().asMap().entries.map((item) {
                            final color = colors[item.key % colors.length];
                            final val = item.value.value.toDouble();
                            return PieChartSectionData(
                              color: color,
                              value: val,
                              radius: 14,
                              showTitle: false,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${subjectMinutes.length}',
                          style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w900, color: AsterConstants.textDark),
                        ),
                        Text(
                          'áreas',
                          style: GoogleFonts.manrope(fontSize: 10, color: AsterConstants.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),

              // Legenda com métricas
              Expanded(
                child: Column(
                  children: subjectMinutes.entries.toList().asMap().entries.map((item) {
                    final color = colors[item.key % colors.length];
                    final hours = (item.value.value / 60).toStringAsFixed(0);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.value.key,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: AsterConstants.textDark),
                            ),
                          ),
                          Text(
                            '${hours}h',
                            style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: AsterConstants.textDark),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Widget: Consistência · 182 dias (Heatmap) ───
  Widget _buildHeatmapCard() {
    return SoftClayCard.list(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Consistência · 182 dias',
                style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: AsterConstants.textDark),
              ),
              Row(
                children: [
                  Text('Menos ', style: GoogleFonts.manrope(fontSize: 10, color: AsterConstants.textMuted)),
                  _buildDot(0),
                  _buildDot(1),
                  _buildDot(2),
                  _buildDot(3),
                  _buildDot(4),
                  Text(' Mais', style: GoogleFonts.manrope(fontSize: 10, color: AsterConstants.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grid de Pontos Suaves
              const Expanded(
                child: SizedBox(
                  height: 110,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConsistencyHeatmap(),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Estatísticas Laterais
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STREAK ATUAL',
                    style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: AsterConstants.textMuted, letterSpacing: 0.5),
                  ),
                  Text(
                    '42d',
                    style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w900, color: AsterConstants.textDark),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'MELHOR DIA',
                    style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: AsterConstants.textMuted, letterSpacing: 0.5),
                  ),
                  Text(
                    '6h20',
                    style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: AsterConstants.textDark),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int level) {
    return Container(
      width: 9,
      height: 9,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: ConsistencyHeatmap.colorForLevel(level),
        shape: BoxShape.circle,
      ),
    );
  }

  // ─── Widget: Sessões Recentes com Tags e Ações ───
  Widget _buildRecentSessionsCard(List<Map<String, dynamic>> realSessions) {
    // Se não houver dados reais, exibe os itens conceituais fiéis ao design de Obsidian
    final sampleSessions = [
      {
        'id': '1',
        'title': 'AES-GCM e modos de operação',
        'subject': 'Criptografia',
        'subtitle': 'Hoje · 08:10 · Revisar nonce reuse e padding oracle.',
        'time': '1h30',
        'color': AsterConstants.lavanda,
      },
      {
        'id': '2',
        'title': 'IAM Policies — Least privilege',
        'subject': 'Cloud',
        'subtitle': 'Ontem · 21:00 · Praticar policy evaluation logic.',
        'time': '55m',
        'color': AsterConstants.menta,
      },
      {
        'id': '3',
        'title': 'OWASP Top 10 — SSRF lab',
        'subject': 'AppSec',
        'subtitle': 'Ontem · 14:30 · Lab finalizado. Flag capturada.',
        'time': '2h05',
        'color': AsterConstants.ambar,
      },
    ];

    return SoftClayCard.list(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sessões recentes',
                style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: AsterConstants.textDark),
              ),
              InkWell(
                onTap: () => _openAddSessionModal(),
                child: Text(
                  '+ Nova Sessão',
                  style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: AsterConstants.lavanda),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (realSessions.isNotEmpty)
            ...realSessions.take(4).map((s) {
              final sub = s['subject'] ?? 'Estudo';
              final top = s['topic'] ?? '';
              final mins = s['duration_minutes'] ?? 0;
              final notes = s['notes'] ?? '';
              final hours = mins >= 60 ? '${mins ~/ 60}h${(mins % 60).toString().padLeft(2, '0')}' : '${mins}m';

              return _buildSessionRow(
                title: '$sub — $top',
                tag: sub,
                subtitle: notes.isNotEmpty ? notes : '${s['study_date']}',
                duration: hours,
                color: AsterConstants.lavanda,
                onDelete: () => SupabaseService.deleteStudySession(s['id']),
              );
            })
          else
            ...sampleSessions.map((s) {
              return _buildSessionRow(
                title: s['title'] as String,
                tag: s['subject'] as String,
                subtitle: s['subtitle'] as String,
                duration: s['time'] as String,
                color: s['color'] as Color,
                onDelete: null,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSessionRow({
    required String title,
    required String tag,
    required String subtitle,
    required String duration,
    required Color color,
    VoidCallback? onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AsterConstants.surfaceInset, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AsterConstants.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SoftClayTag(label: tag, color: color),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: AsterConstants.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                duration,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AsterConstants.textDark,
                ),
              ),
              if (onDelete != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.delete_outline_rounded, size: 16, color: AsterConstants.coral),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Widget: Insight do Agente (Noesis AI) ───
  Widget _buildAgentInsightCard() {
    return SoftClayCard.list(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Insight do agente',
                style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: AsterConstants.textDark),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AsterConstants.surfaceAlt,
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                ),
                child: Text(
                  'Noesis AI',
                  style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: AsterConstants.lavanda),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Sua retenção em Criptografia assimétrica caiu 12% nos simulados. Sugiro uma revisão espaçada de 25 min antes da prova de sexta.',
            style: GoogleFonts.manrope(
              fontSize: 12,
              height: 1.5,
              color: AsterConstants.textDark,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              SoftClayPillButton(
                text: 'Agendar revisão',
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Revisão agendada para sexta-feira às 14:00!')),
                  );
                },
              ),
              const SizedBox(width: 8),
              SoftClayPillButton(
                text: 'Ver análise',
                isSecondary: true,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Mini Gráfico de Acurácia
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ACURÁCIA NOS SIMULADOS',
                    style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w800, color: AsterConstants.textMuted, letterSpacing: 0.5),
                  ),
                  Text(
                    '78%',
                    style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w900, color: AsterConstants.textDark),
                  ),
                ],
              ),
              SizedBox(
                width: 90,
                height: 32,
                child: RepaintBoundary(
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: 6,
                      minY: 50,
                      maxY: 100,
                      lineBarsData: [
                        LineChartBarData(
                          spots: const [
                            FlSpot(0, 65),
                            FlSpot(1, 68),
                            FlSpot(2, 60),
                            FlSpot(3, 72),
                            FlSpot(4, 70),
                            FlSpot(5, 75),
                            FlSpot(6, 78),
                          ],
                          isCurved: true,
                          color: AsterConstants.menta,
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Widget de Heatmap de Consistência Otimizado com CustomPainter
class ConsistencyHeatmap extends StatelessWidget {
  final int columns;
  final int rows;
  final List<List<int>>? levels;

  const ConsistencyHeatmap({
    super.key,
    this.columns = 26,
    this.rows = 7,
    this.levels,
  });

  static Color colorForLevel(int level) {
    switch (level) {
      case 4:
        return AsterConstants.menta;
      case 3:
        return AsterConstants.menta.withValues(alpha: 0.7);
      case 2:
        return AsterConstants.menta.withValues(alpha: 0.45);
      case 1:
        return AsterConstants.menta.withValues(alpha: 0.22);
      default:
        return AsterConstants.surfaceInset;
    }
  }

  static int simulatedLevelFor(int col, int row) {
    final seed = col * 7 + row;
    if (seed % 11 == 0) return 4;
    if (seed % 5 == 0) return 3;
    if (seed % 3 == 0) return 2;
    if (seed % 2 == 0) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    const double colWidth = 17.0;
    final totalWidth = columns * colWidth;

    return RepaintBoundary(
      child: CustomPaint(
        size: Size(totalWidth, 110),
        painter: _HeatmapPainter(
          columns: columns,
          rows: rows,
          levels: levels,
        ),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final int columns;
  final int rows;
  final List<List<int>>? levels;

  _HeatmapPainter({
    required this.columns,
    required this.rows,
    this.levels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double dotDiameter = 9.0;
    const double dotRadius = dotDiameter / 2.0;
    const double colStep = 17.0;
    const double startX = 1.5 + dotRadius;
    final double rowStep = (size.height - dotDiameter) / (rows - 1);

    final paint = Paint()..style = PaintingStyle.fill;

    for (int col = 0; col < columns; col++) {
      final double cx = col * colStep + startX;
      for (int row = 0; row < rows; row++) {
        final double cy = row * rowStep + dotRadius;
        final int level;
        if (levels != null && col < levels!.length && row < levels![col].length) {
          level = levels![col][row];
        } else {
          level = ConsistencyHeatmap.simulatedLevelFor(col, row);
        }

        paint.color = ConsistencyHeatmap.colorForLevel(level);
        canvas.drawCircle(Offset(cx, cy), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) {
    return oldDelegate.columns != columns ||
        oldDelegate.rows != rows ||
        oldDelegate.levels != levels;
  }
}
