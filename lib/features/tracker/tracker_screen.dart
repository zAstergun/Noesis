import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants.dart';
import '../../core/supabase_service.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  // Timer State
  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isTimerRunning = false;

  // Controllers para Registro Rápido
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

  String _formatTime(int seconds) {
    final hours = (seconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$secs';
  }

  void _openAddSessionModal({int? defaultDurationMinutes}) {
    if (defaultDurationMinutes != null) {
      _durationController.text = defaultDurationMinutes.toString();
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AsterConstants.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Registrar Sessão de Estudo', style: TextStyle(color: AsterConstants.textLight)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _subjectController,
                decoration: const InputDecoration(labelText: 'Matéria / Disciplina (ex: Matemática, Criptografia)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _topicController,
                decoration: const InputDecoration(labelText: 'Tópico Específico (ex: Álgebra Linear, RSA)'),
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
                decoration: const InputDecoration(labelText: 'Anotações do Estudo (resumo, dúvidas)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AsterConstants.textMuted)),
          ),
          ElevatedButton(
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
            child: const Text('Salvar'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracker de Estudos & Métricas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AsterConstants.secondary),
            tooltip: 'Registro Manual',
            onPressed: () => _openAddSessionModal(),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: SupabaseService.studySessionsStream(),
        builder: (context, snapshot) {
          final sessions = snapshot.data ?? [];

          // Calcular Métricas
          int totalMinutes = 0;
          final Map<String, int> subjectMinutes = {};
          for (var s in sessions) {
            final int m = (s['duration_minutes'] as num?)?.toInt() ?? 0;
            totalMinutes += m;
            final String sub = (s['subject'] as String?) ?? 'Outros';
            subjectMinutes[sub] = (subjectMinutes[sub] ?? 0) + m;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Cronômetro / Timer Ativo
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Column(
                      children: [
                        const Text(
                          'SESSÃO ATIVA (CRONÔMETRO)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: AsterConstants.textMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _formatTime(_secondsElapsed),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            color: AsterConstants.secondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!_isTimerRunning)
                              ElevatedButton.icon(
                                onPressed: _startTimer,
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Iniciar'),
                              )
                            else
                              ElevatedButton.icon(
                                onPressed: _pauseTimer,
                                style: ElevatedButton.styleFrom(backgroundColor: AsterConstants.accentOrange),
                                icon: const Icon(Icons.pause_rounded),
                                label: const Text('Pausar'),
                              ),
                            const SizedBox(width: 12),
                            if (_secondsElapsed > 0) ...[
                              OutlinedButton.icon(
                                onPressed: () {
                                  final minutes = (_secondsElapsed / 60).ceil();
                                  _openAddSessionModal(defaultDurationMinutes: minutes > 0 ? minutes : 1);
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AsterConstants.secondary),
                                  foregroundColor: AsterConstants.secondary,
                                ),
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Concluir & Salvar'),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: _resetTimer,
                                icon: const Icon(Icons.replay, color: AsterConstants.textDim),
                                tooltip: 'Zerar',
                              ),
                            ]
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Painel de Métricas & Gráfico
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('TEMPO TOTAL ESTUDADO', style: TextStyle(color: AsterConstants.textMuted, fontSize: 11)),
                              const SizedBox(height: 6),
                              Text(
                                '${(totalMinutes / 60).toStringAsFixed(1)}h',
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AsterConstants.textLight),
                              ),
                              Text('$totalMinutes minutos', style: const TextStyle(color: AsterConstants.textDim, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('SESSÕES REGISTRADAS', style: TextStyle(color: AsterConstants.textMuted, fontSize: 11)),
                              const SizedBox(height: 6),
                              Text(
                                '${sessions.length}',
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AsterConstants.primary),
                              ),
                              Text('${subjectMinutes.keys.length} matérias', style: const TextStyle(color: AsterConstants.textDim, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 3. Gráfico de Distribuição por Matéria
                if (subjectMinutes.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DISTRIBUIÇÃO DE TEMPO POR DISCIPLINA',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AsterConstants.textMuted),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 180,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 3,
                                centerSpaceRadius: 40,
                                sections: subjectMinutes.entries.map((entry) {
                                  final colors = [
                                    AsterConstants.primary,
                                    AsterConstants.secondary,
                                    AsterConstants.accentOrange,
                                    AsterConstants.accentRose,
                                    AsterConstants.accentAmber,
                                  ];
                                  final color = colors[entry.key.hashCode.abs() % colors.length];
                                  final double percentage = (entry.value / totalMinutes) * 100;
                                  return PieChartSectionData(
                                    color: color,
                                    value: entry.value.toDouble(),
                                    title: '${percentage.toStringAsFixed(0)}%',
                                    radius: 45,
                                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: subjectMinutes.entries.map((e) {
                              return Chip(
                                backgroundColor: AsterConstants.surfaceDark,
                                side: const BorderSide(color: AsterConstants.borderDark),
                                label: Text(
                                  '${e.key}: ${e.value}m',
                                  style: const TextStyle(color: AsterConstants.textLight, fontSize: 12),
                                ),
                              );
                            }).toList(),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 4. Histórico Recente de Estudos
                const Text(
                  'HISTÓRICO DE ESTUDOS',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AsterConstants.textMuted),
                ),
                const SizedBox(height: 10),

                if (sessions.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: const Text('Nenhuma sessão registrada ainda. Comece com o cronômetro ou adicione manualmente!',
                        textAlign: TextAlign.center, style: TextStyle(color: AsterConstants.textDim)),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sessions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final item = sessions[idx];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AsterConstants.primary.withValues(alpha: 0.2),
                            child: const Icon(Icons.menu_book, color: AsterConstants.secondary, size: 20),
                          ),
                          title: Text(
                            '${item['subject']} • ${item['topic']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AsterConstants.textLight),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${item['study_date']} • ${item['duration_minutes']} min',
                                  style: const TextStyle(color: AsterConstants.textMuted, fontSize: 12)),
                              if (item['notes'] != null && item['notes'].toString().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  item['notes'],
                                  style: const TextStyle(color: AsterConstants.textDim, fontSize: 13, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AsterConstants.accentRose),
                            onPressed: () => SupabaseService.deleteStudySession(item['id']),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
