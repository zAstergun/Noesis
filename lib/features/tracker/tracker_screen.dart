import 'dart:async';
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
  bool _isTimerRunning = false;
  String _activeSubject = 'Criptografia';

  // Modal Controllers
  final _subjectController = TextEditingController();
  final _topicController = TextEditingController();
  final _durationController = TextEditingController();
  final _notesController = TextEditingController();

  void _startTimer() {
    setState(() => _isTimerRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _secondsElapsed++);
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isTimerRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _secondsElapsed = 0;
      _isTimerRunning = false;
    });
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
            onPressed: () async {
              final subject = _subjectController.text.trim();
              final topic = _topicController.text.trim();
              final duration = int.tryParse(_durationController.text.trim()) ?? 0;

              if (subject.isNotEmpty && topic.isNotEmpty && duration > 0) {
                await SupabaseService.addStudySession(
                  subject: subject,
                  topic: topic,
                  durationMinutes: duration,
                  studyDate: DateTime.now(),
                  notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
                );
                if (mounted && ctx.mounted) {
                  Navigator.pop(ctx);
                  _subjectController.clear();
                  _topicController.clear();
                  _durationController.clear();
                  _notesController.clear();
                  _resetTimer();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sessão registrada com sucesso!')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.studySessionsStream(),
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? [];

        // Agregação de Métricas
        int totalMinutes = 0;
        final Map<String, int> subjectMinutes = {};
        for (var s in sessions) {
          final int m = (s['duration_minutes'] as num?)?.toInt() ?? 0;
          totalMinutes += m;
          final String sub = (s['subject'] as String?) ?? 'Outros';
          subjectMinutes[sub] = (subjectMinutes[sub] ?? 0) + m;
        }

        // Mock fallback se o banco for novo, para exibir a rica distribuição do design de Obsidian
        if (subjectMinutes.isEmpty) {
          subjectMinutes['Criptografia'] = 42 * 60;
          subjectMinutes['Cloud / AWS'] = 31 * 60;
          subjectMinutes['Redes & OWASP'] = 27 * 60;
          subjectMinutes['Sistemas Dist.'] = 23 * 60;
          totalMinutes = 123 * 60;
        }

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
                    Expanded(flex: 2, child: _buildHoursStatsCard(totalMinutes)),
                  ],
                )
              else ...[
                _buildTimerHeroCard(),
                const SizedBox(height: 16),
                _buildHoursStatsCard(totalMinutes),
              ],

              const SizedBox(height: 20),

              // ─── Linha 2: Distribuição & Heatmap de Consistência ───
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildDistributionCard(subjectMinutes, totalMinutes)),
                    const SizedBox(width: 20),
                    Expanded(flex: 3, child: _buildHeatmapCard()),
                  ],
                )
              else ...[
                _buildDistributionCard(subjectMinutes, totalMinutes),
                const SizedBox(height: 16),
                _buildHeatmapCard(),
              ],

              const SizedBox(height: 20),

              // ─── Linha 3: Sessões Recentes & Insight do Agente ───
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildRecentSessionsCard(sessions)),
                    const SizedBox(width: 20),
                    Expanded(flex: 2, child: _buildAgentInsightCard()),
                  ],
                )
              else ...[
                _buildRecentSessionsCard(sessions),
                const SizedBox(height: 16),
                _buildAgentInsightCard(),
              ],

              const SizedBox(height: 32),
            ],
          ),
        );
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

          // Mostrador do Timer
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${_formatHours(_secondsElapsed)}:${_formatMinutes(_secondsElapsed)}',
                style: GoogleFonts.manrope(
                  fontSize: 54,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                  color: AsterConstants.textDark,
                ),
              ),
              Text(
                ':${_formatSecs(_secondsElapsed)}',
                style: GoogleFonts.manrope(
                  fontSize: 54,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                  color: AsterConstants.lavanda.withValues(alpha: 0.65),
                ),
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
              Container(
                decoration: const BoxDecoration(
                  color: AsterConstants.lavanda,
                  borderRadius: BorderRadius.all(Radius.circular(AsterConstants.radiusPill)),
                  boxShadow: AsterConstants.primaryButtonShadow,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    onTap: _isTimerRunning ? _pauseTimer : _startTimer,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            _isTimerRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isTimerRunning ? 'Pausar' : 'Iniciar',
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
              SoftClayTag(
                label: _activeSubject,
                color: AsterConstants.lavanda,
                onTap: () {
                  setState(() {
                    _activeSubject = _activeSubject == 'Criptografia' ? 'Cloud / AWS' : 'Criptografia';
                  });
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
          ClipRRect(
            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
            child: LinearProgressIndicator(
              value: (_secondsElapsed / (90 * 60)).clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: AsterConstants.surfaceInset,
              valueColor: const AlwaysStoppedAnimation(AsterConstants.lavanda),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Widget: Horas Estudadas nos Últimos 7 Dias ───
  Widget _buildHoursStatsCard(int totalMinutes) {
    final hours = (totalMinutes / 60).toStringAsFixed(0);

    return SoftClayCard(
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
            height: 64,
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
          height: 48 * heightFraction,
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

    return SoftClayCard(
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
                    PieChart(
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
    return SoftClayCard(
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
              Expanded(
                child: SizedBox(
                  height: 110,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(26, (col) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(7, (row) {
                              // Determinar densidade simulada
                              final seed = (col * 7 + row);
                              int level = 0;
                              if (seed % 11 == 0) {
                                level = 4;
                              } else if (seed % 5 == 0) {
                                level = 3;
                              } else if (seed % 3 == 0) {
                                level = 2;
                              } else if (seed % 2 == 0) {
                                level = 1;
                              }
                              return _buildDot(level);
                            }),
                          ),
                        );
                      }),
                    ),
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
    Color dotColor;
    switch (level) {
      case 4:
        dotColor = AsterConstants.menta;
        break;
      case 3:
        dotColor = AsterConstants.menta.withValues(alpha: 0.7);
        break;
      case 2:
        dotColor = AsterConstants.menta.withValues(alpha: 0.45);
        break;
      case 1:
        dotColor = AsterConstants.menta.withValues(alpha: 0.22);
        break;
      default:
        dotColor = AsterConstants.surfaceInset;
    }

    return Container(
      width: 9,
      height: 9,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: dotColor,
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

    return SoftClayCard(
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
    return SoftClayCard(
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
            ],
          ),
        ],
      ),
    );
  }
}
