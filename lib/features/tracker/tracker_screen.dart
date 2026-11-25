import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../core/gemini_service.dart';
import '../../core/supabase_service.dart';
import '../../core/theme.dart';
import '../../main.dart' show RootScreen;
import '../../widgets/weekly_goal_dialog.dart';
import '../flashcards/models/flashcard_model.dart';
import '../notebooks/models/notebook_model.dart';
import '../quizzes/data/saved_exams_repository.dart';
import '../roadmaps/data/roadmaps_repository.dart';
import '../roadmaps/models/roadmap_model.dart';
import 'dashboard_analytics.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  // ─── Estado do Cronômetro / Sessão Ativa ───
  Timer? _timer;
  int _secondsElapsed = 0;
  late final ValueNotifier<int> _secondsNotifier;
  late final ValueNotifier<bool> _isTimerRunningNotifier;
  late final ValueNotifier<String> _activeSubjectNotifier;
  late final ValueNotifier<int> _sessionGoalMinutesNotifier;
  final List<String> _laps = [];
  bool _isTimerRunning = false;
  String _activeSubject = 'Geral';
  int _sessionGoalMinutes = 90;

  // ─── Streams e Snapshot Integrado do Ecossistema ───
  late final Stream<List<Map<String, dynamic>>> _sessionsStream;
  final ValueNotifier<DashboardEcosystemSnapshot> _ecosystemNotifier =
      ValueNotifier<DashboardEcosystemSnapshot>(const DashboardEcosystemSnapshot());
  final ValueNotifier<int?> _distributionDaysWindow = ValueNotifier<int?>(30);
  final ValueNotifier<String?> _hoveredDayLabel = ValueNotifier<String?>(null);
  bool _scheduledReviewThisSession = false;
  String? _lastInsightMessage;

  // ─── Controllers do Modal de Nova Sessão ───
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
    _sessionGoalMinutesNotifier = ValueNotifier<int>(_sessionGoalMinutes);

    _sessionsStream = SupabaseService.studySessionsStream().distinct((prev, next) {
      if (prev.length != next.length) return false;
      for (int i = 0; i < prev.length; i++) {
        if (!mapEquals(prev[i], next[i])) return false;
      }
      return true;
    });

    RootScreen.activeTabListenable?.addListener(_onRootTabChanged);
    _refreshEcosystemAndSubject();
  }

  void _onRootTabChanged() {
    if (RootScreen.activeTabListenable?.value == 0) {
      _refreshEcosystemAndSubject();
    }
  }

  Future<void> _refreshEcosystemAndSubject() async {
    try {
      final results = await Future.wait<dynamic>([
        SavedExamsRepository.loadAll(),
        SupabaseService.getFlashcardDecks(),
        SupabaseService.getNotebooks(),
        RoadmapsRepository.loadAll(),
        SupabaseService.getCalendarEvents(),
        SupabaseService.getStudySessions(limit: 200),
        SupabaseService.loadWeeklyGoalMinutes(),
      ]);

      if (!mounted) return;
      final snapshot = DashboardEcosystemSnapshot(
        savedExams: results[0] as List<SavedExamAttempt>,
        decks: results[1] as List<FlashcardDeck>,
        notebooks: results[2] as List<StudyNotebook>,
        roadmaps: results[3] as List<StudyRoadmap>,
        calendarEvents: results[4] as List<Map<String, dynamic>>,
      );
      final sessions = results[5] as List<Map<String, dynamic>>;

      _ecosystemNotifier.value = snapshot;

      final subjects = DashboardAnalytics.collectAllUserSubjects(
        sessions: sessions,
        ecosystem: snapshot,
      );
      if (subjects.isNotEmpty && (_activeSubject == 'Geral' || !subjects.contains(_activeSubject))) {
        _activeSubject = subjects.first;
        _activeSubjectNotifier.value = _activeSubject;
      }
    } catch (e) {
      debugPrint('Erro ao carregar panorama integrado do Dashboard: $e');
    }
  }

  void _startTimer() {
    _isTimerRunning = true;
    _isTimerRunningNotifier.value = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
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
    setState(() {
      _laps.clear();
    });
  }

  void _recordLap() {
    final formatted =
        '${_formatHours(_secondsElapsed)}:${_formatMinutes(_secondsElapsed)}:${_formatSecs(_secondsElapsed)}';
    final now = TimeOfDay.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    setState(() {
      _laps.add('Checkpoint ${_laps.length + 1} às $hh:$mm ($formatted)');
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AsterTheme.primary(context),
        content: Text('Checkpoint #${_laps.length} registrado em $formatted.'),
      ),
    );
  }

  @override
  void dispose() {
    RootScreen.activeTabListenable?.removeListener(_onRootTabChanged);
    _timer?.cancel();
    _secondsNotifier.dispose();
    _isTimerRunningNotifier.dispose();
    _activeSubjectNotifier.dispose();
    _sessionGoalMinutesNotifier.dispose();
    _ecosystemNotifier.dispose();
    _distributionDaysWindow.dispose();
    _hoveredDayLabel.dispose();
    _subjectController.dispose();
    _topicController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatHours(int seconds) => (seconds ~/ 3600).toString().padLeft(2, '0');
  String _formatMinutes(int seconds) => ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
  String _formatSecs(int seconds) => (seconds % 60).toString().padLeft(2, '0');

  Future<void> _openSubjectPicker(List<Map<String, dynamic>> sessions) async {
    final subjects = DashboardAnalytics.collectAllUserSubjects(
      sessions: sessions,
      ecosystem: _ecosystemNotifier.value,
    );
    final customController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
          title: Text(
            'Disciplina da Sessão',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
            ),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: subjects.map((subj) {
                    final selected = subj == _activeSubject;
                    return ChoiceChip(
                      label: Text(subj),
                      selected: selected,
                      selectedColor: AsterTheme.primary(context).withValues(alpha: 0.2),
                      onSelected: (_) {
                        _activeSubject = subj;
                        _activeSubjectNotifier.value = subj;
                        Navigator.of(ctx).pop();
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: customController,
                  decoration: const InputDecoration(
                    labelText: 'Ou digite outra disciplina',
                    hintText: 'Ex.: Cálculo II, Direito Constitucional...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            SoftClayPillButton(
              text: 'Aplicar',
              onPressed: () {
                final custom = customController.text.trim();
                if (custom.isNotEmpty) {
                  _activeSubject = custom;
                  _activeSubjectNotifier.value = custom;
                }
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
    customController.dispose();
  }

  Future<void> _openSessionGoalPicker() async {
    const options = [25, 45, 60, 90, 120, 180];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
          title: Text(
            'Meta da Sessão Atual',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
            ),
          ),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((mins) {
              final selected = _sessionGoalMinutes == mins;
              return ChoiceChip(
                label: Text(DashboardAnalytics.formatCompactDuration(mins)),
                selected: selected,
                selectedColor: AsterTheme.primary(context).withValues(alpha: 0.2),
                onSelected: (_) {
                  _sessionGoalMinutes = mins;
                  _sessionGoalMinutesNotifier.value = mins;
                  Navigator.of(ctx).pop();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _openAddSessionModal({
    int? defaultDurationMinutes,
    List<String> suggestedSubjects = const [],
  }) {
    if (defaultDurationMinutes != null) {
      _durationController.text = defaultDurationMinutes.toString();
    } else if (_durationController.text.trim().isEmpty) {
      _durationController.text = _sessionGoalMinutes.toString();
    }
    _subjectController.text = _activeSubject;
    if (_laps.isNotEmpty && _notesController.text.trim().isEmpty) {
      _notesController.text = _laps.join('\n');
    }

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
              ),
              title: Text(
                'Registrar Sessão de Estudo',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                ),
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (suggestedSubjects.isNotEmpty) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: suggestedSubjects.take(6).map((subj) {
                            return ActionChip(
                              label: Text(subj, style: const TextStyle(fontSize: 12)),
                              onPressed: () {
                                setModalState(() {
                                  _subjectController.text = subj;
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _subjectController,
                        decoration: const InputDecoration(
                          labelText: 'Disciplina (ex: Matemática, Cloud, Idiomas)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _topicController,
                        decoration: const InputDecoration(
                          labelText: 'Tópico estudado',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duração em Minutos (ex: 60)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [25, 45, 60, 90, 120].map((m) {
                          return ActionChip(
                            label: Text(
                              DashboardAnalytics.formatCompactDuration(m),
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            onPressed: () {
                              setModalState(() {
                                _durationController.text = m.toString();
                              });
                            },
                          );
                        }).toList(),
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
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.manrope(
                      color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                    ),
                  ),
                ),
                SoftClayPillButton(
                  text: 'Salvar Sessão',
                  onPressed: () {
                    final subject = _subjectController.text.trim();
                    final topic = _topicController.text.trim();
                    final duration = int.tryParse(_durationController.text.trim()) ?? 0;
                    final notes =
                        _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null;

                    if (subject.isNotEmpty && topic.isNotEmpty && duration > 0) {
                      Navigator.pop(ctx);
                      _activeSubject = subject;
                      _activeSubjectNotifier.value = subject;
                      _subjectController.clear();
                      _topicController.clear();
                      _durationController.clear();
                      _notesController.clear();
                      _resetTimer();

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AsterConstants.menta,
                            content: Text('Sessão registrada e métricas atualizadas!'),
                          ),
                        );
                      }

                      SupabaseService.addStudySession(
                        subject: subject,
                        topic: topic,
                        durationMinutes: duration,
                        studyDate: DateTime.now(),
                        notes: notes,
                      ).then((_) {
                        _refreshEcosystemAndSubject();
                      }).catchError((e) {
                        debugPrint('Erro ao sincronizar sessão de estudo: $e');
                      });
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28.0 : 16.0,
        vertical: 12.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Linha 1: Timer Hero & Horas Estudadas (últimos 7 dias reais) ───
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildLoweredTimerHeroCard(isDark)),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: _buildLoweredHoursStatsCard(isDark)),
              ],
            )
          else ...[
            _buildLoweredTimerHeroCard(isDark),
            const SizedBox(height: 16),
            _buildLoweredHoursStatsCard(isDark),
          ],

          const SizedBox(height: 18),

          // ─── Linha 2: Panorama Integrado (Meta Semanal, Simulados, Flashcards/Cadernos, Trilhas/Agenda) ───
          _buildEcosystemOverviewStrip(isDesktop, isDark),

          const SizedBox(height: 18),

          // ─── Linha 3: Distribuição & Consistência Funcional (182 dias) ───
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildLoweredDistributionCard(isDark)),
                const SizedBox(width: 20),
                Expanded(flex: 3, child: _buildLoweredHeatmapCard(isDark)),
              ],
            )
          else ...[
            _buildLoweredDistributionCard(isDark),
            const SizedBox(height: 16),
            _buildLoweredHeatmapCard(isDark),
          ],

          const SizedBox(height: 18),

          // ─── Linha 4: Sessões Recentes & Insight Funcional do Agente ───
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildLoweredRecentSessionsCard(isDark)),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: _buildLoweredAgentInsightCard(isDark)),
              ],
            )
          else ...[
            _buildLoweredRecentSessionsCard(isDark),
            const SizedBox(height: 16),
            _buildLoweredAgentInsightCard(isDark),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildLoweredTimerHeroCard(bool isDark) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _sessionsStream,
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? const [];
        return _buildTimerHeroCard(sessions, isDark);
      },
    );
  }

  Widget _buildLoweredHoursStatsCard(bool isDark) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _sessionsStream,
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? const [];
        final stats = DashboardAnalytics.computeLast7DaysStats(sessions);
        return _buildHoursStatsCard(stats, isDark);
      },
    );
  }

  Widget _buildLoweredDistributionCard(bool isDark) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _sessionsStream,
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? const [];
        return ValueListenableBuilder<int?>(
          valueListenable: _distributionDaysWindow,
          builder: (context, daysWindow, _) {
            final distribution = DashboardAnalytics.computeSubjectDistribution(
              sessions,
              daysWindow: daysWindow,
            );
            return _buildDistributionCard(distribution, daysWindow, isDark);
          },
        );
      },
    );
  }

  Widget _buildLoweredHeatmapCard(bool isDark) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _sessionsStream,
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? const [];
        return ValueListenableBuilder<DashboardEcosystemSnapshot>(
          valueListenable: _ecosystemNotifier,
          builder: (context, ecosystem, _) {
            final consistency = DashboardAnalytics.computeConsistencyStats(
              sessions,
              exams: ecosystem.savedExams,
            );
            return _buildHeatmapCard(consistency, isDark);
          },
        );
      },
    );
  }

  Widget _buildLoweredRecentSessionsCard(bool isDark) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _sessionsStream,
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? const [];
        final subjects = DashboardAnalytics.collectAllUserSubjects(
          sessions: sessions,
          ecosystem: _ecosystemNotifier.value,
        );
        return _buildRecentSessionsCard(sessions, subjects, isDark);
      },
    );
  }

  Widget _buildLoweredAgentInsightCard(bool isDark) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _sessionsStream,
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? const [];
        return ValueListenableBuilder<DashboardEcosystemSnapshot>(
          valueListenable: _ecosystemNotifier,
          builder: (context, ecosystem, _) {
            return ValueListenableBuilder<int>(
              valueListenable: SupabaseService.weeklyGoalMinutesNotifier,
              builder: (context, weeklyGoalMinutes, _) {
                final consistency = DashboardAnalytics.computeConsistencyStats(
                  sessions,
                  exams: ecosystem.savedExams,
                );
                final currentWeekMinutes =
                    SupabaseService.computeCurrentWeekStudiedMinutes(sessions);
                final insight = DashboardAnalytics.buildInsight(
                  ecosystem,
                  sessions: sessions,
                  consistency: consistency,
                  weeklyGoalMinutes: weeklyGoalMinutes,
                  currentWeekMinutes: currentWeekMinutes,
                );
                if (_lastInsightMessage != insight.message) {
                  _lastInsightMessage = insight.message;
                  _scheduledReviewThisSession = false;
                }
                return _buildAgentInsightCard(
                  insight: insight,
                  ecosystem: ecosystem,
                  consistency: consistency,
                  weeklyGoalMinutes: weeklyGoalMinutes,
                  currentWeekMinutes: currentWeekMinutes,
                  isDark: isDark,
                );
              },
            );
          },
        );
      },
    );
  }

  // ─── Panorama Integrado com todos os novos recursos ───
  Widget _buildEcosystemOverviewStrip(bool isDesktop, bool isDark) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _sessionsStream,
      builder: (context, sessionSnap) {
        final sessions = sessionSnap.data ?? const [];
        final weekStudied = SupabaseService.computeCurrentWeekStudiedMinutes(sessions);

        return ValueListenableBuilder<int>(
          valueListenable: SupabaseService.weeklyGoalMinutesNotifier,
          builder: (context, goalMinutes, _) {
            return ValueListenableBuilder<DashboardEcosystemSnapshot>(
              valueListenable: _ecosystemNotifier,
              builder: (context, ecosystem, _) {
                final goalPct =
                    ((weekStudied / (goalMinutes > 0 ? goalMinutes : 1)) * 100)
                        .round()
                        .clamp(0, 999);
                final avgExam = ecosystem.averageExamScore;
                final upcoming = ecosystem.upcomingEvents();

                final tiles = [
                  _EcosystemTileData(
                    key: const Key('dashboard_kpi_weekly_goal'),
                    title: 'Meta Semanal',
                    value:
                        '${SupabaseService.formatGoalDuration(weekStudied)} / ${SupabaseService.formatGoalDuration(goalMinutes)}',
                    subtitle: '$goalPct% concluído · clique p/ editar',
                    icon: Icons.track_changes_rounded,
                    color: AsterConstants.menta,
                    onTap: () => showWeeklyGoalEditorDialog(
                      context,
                      currentWeekStudiedMinutes: weekStudied,
                    ),
                  ),
                  _EcosystemTileData(
                    key: const Key('dashboard_kpi_exams'),
                    title: 'Simulados',
                    value: '${ecosystem.examsCount} ${ecosystem.examsCount == 1 ? 'feito' : 'feitos'}',
                    subtitle: avgExam != null
                        ? 'Média ${avgExam.round()}% de acerto'
                        : 'Crie um simulado com IA',
                    icon: Icons.assignment_turned_in_rounded,
                    color: AsterTheme.primary(context),
                    onTap: () => RootScreen.switchTab(1),
                  ),
                  _EcosystemTileData(
                    key: const Key('dashboard_kpi_cards_notebooks'),
                    title: 'Flashcards & Cadernos',
                    value: '${ecosystem.cardsNeedingReview} p/ revisar',
                    subtitle:
                        '${ecosystem.notebooksCount} cadernos · ${ecosystem.notesCount} notas',
                    icon: Icons.style_rounded,
                    color: AsterConstants.ambar,
                    onTap: () => RootScreen.switchTab(2),
                  ),
                  _EcosystemTileData(
                    key: const Key('dashboard_kpi_roadmaps_calendar'),
                    title: 'Trilhas & Agenda',
                    value: '${ecosystem.overallRoadmapProgressPct}% das trilhas',
                    subtitle:
                        '${ecosystem.roadmapsCount} trilha${ecosystem.roadmapsCount == 1 ? '' : 's'} · ${upcoming.length} evento${upcoming.length == 1 ? '' : 's'} próx.',
                    icon: Icons.route_rounded,
                    color: AsterConstants.coral,
                    onTap: () => RootScreen.switchTab(8),
                  ),
                ];

                if (isDesktop) {
                  return Row(
                    children: [
                      for (int i = 0; i < tiles.length; i++) ...[
                        Expanded(child: _buildEcosystemKpiCard(tiles[i], isDark)),
                        if (i < tiles.length - 1) const SizedBox(width: 14),
                      ],
                    ],
                  );
                }

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: tiles.map((tile) {
                    return SizedBox(
                      width: (MediaQuery.of(context).size.width - 44) / 2,
                      child: _buildEcosystemKpiCard(tile, isDark),
                    );
                  }).toList(),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEcosystemKpiCard(_EcosystemTileData data, bool isDark) {
    return SoftClayCard.list(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: data.key,
          onTap: data.onTap,
          borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: data.color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(data.icon, size: 19, color: data.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                        ),
                      ),
                      Text(
                        data.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Widget: Timer Hero Card (Funcional com Laps, Matérias Reais e Meta Editável) ───
  Widget _buildTimerHeroCard(List<Map<String, dynamic>> sessions, bool isDark) {
    final subjects = DashboardAnalytics.collectAllUserSubjects(
      sessions: sessions,
      ecosystem: _ecosystemNotifier.value,
    );

    return SoftClayCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: _isTimerRunningNotifier,
                builder: (context, isRunning, _) {
                  return Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isRunning ? AsterConstants.menta : AsterConstants.ambar,
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Text(
                'SESSÃO EM ANDAMENTO',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                ),
              ),
              const Spacer(),
              if (_laps.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AsterTheme.primary(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  ),
                  child: Text(
                    '${_laps.length} checkpoint${_laps.length == 1 ? '' : 's'}',
                    style: GoogleFonts.manrope(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AsterTheme.primary(context),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

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
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.5,
                          color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                        ),
                      ),
                      Text(
                        ':${_formatSecs(seconds)}',
                        style: GoogleFonts.manrope(
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.5,
                          color: AsterTheme.primary(context).withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const Spacer(),

              // Botão Checkpoint / Volta
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                ),
                child: IconButton(
                  tooltip: 'Marcar checkpoint na sessão',
                  icon: Icon(
                    Icons.flag_outlined,
                    size: 19,
                    color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                  ),
                  onPressed: _recordLap,
                ),
              ),
              const SizedBox(width: 8),

              // Botão Zerar
              ValueListenableBuilder<int>(
                valueListenable: _secondsNotifier,
                builder: (context, seconds, _) {
                  if (seconds == 0 && _laps.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      ),
                      child: IconButton(
                        tooltip: 'Reiniciar cronômetro',
                        icon: Icon(
                          Icons.refresh_rounded,
                          size: 19,
                          color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                        ),
                        onPressed: _resetTimer,
                      ),
                    ),
                  );
                },
              ),

              // Botão Play / Pausar
              ValueListenableBuilder<bool>(
                valueListenable: _isTimerRunningNotifier,
                builder: (context, isRunning, _) {
                  final primaryCol = AsterTheme.primary(context);
                  final onPrimaryCol = AsterTheme.onPrimary(context);
                  return Container(
                    decoration: BoxDecoration(
                      color: primaryCol,
                      borderRadius: const BorderRadius.all(Radius.circular(AsterConstants.radiusPill)),
                      boxShadow: AsterTheme.primaryShadow(context, primaryCol),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                        onTap: isRunning ? _pauseTimer : _startTimer,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: onPrimaryCol,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isRunning ? 'Pausar' : 'Iniciar',
                                style: GoogleFonts.manrope(
                                  color: onPrimaryCol,
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
              const SizedBox(width: 8),

              // Botão Concluir & Salvar
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AsterTheme.secondary(context).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                ),
                child: IconButton(
                  icon: Icon(Icons.check_rounded, size: 20, color: AsterTheme.secondary(context)),
                  tooltip: 'Concluir & Registrar no Diário',
                  onPressed: () {
                    final mins = (_secondsElapsed / 60).ceil();
                    _openAddSessionModal(
                      defaultDurationMinutes: mins > 0 ? mins : _sessionGoalMinutes,
                      suggestedSubjects: subjects,
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              ValueListenableBuilder<String>(
                valueListenable: _activeSubjectNotifier,
                builder: (context, activeSubject, _) {
                  return SoftClayTag(
                    label: activeSubject,
                    color: AsterTheme.primary(context),
                    onTap: () => _openSubjectPicker(sessions),
                  );
                },
              ),
              const SizedBox(width: 12),
              ValueListenableBuilder<int>(
                valueListenable: _sessionGoalMinutesNotifier,
                builder: (context, goalMins, _) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    onTap: _openSessionGoalPicker,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Meta da sessão: ${DashboardAnalytics.formatCompactDuration(goalMins)}',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit_rounded,
                            size: 12,
                            color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          ValueListenableBuilder<int>(
            valueListenable: _secondsNotifier,
            builder: (context, seconds, _) {
              return ValueListenableBuilder<int>(
                valueListenable: _sessionGoalMinutesNotifier,
                builder: (context, goalMins, _) {
                  final safeGoalSeconds = goalMins > 0 ? goalMins * 60 : 1;
                  return LinearProgressIndicator(
                    value: (seconds / safeGoalSeconds).clamp(0.0, 1.0),
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    backgroundColor: AsterTheme.surfaceInset(context),
                    valueColor: AlwaysStoppedAnimation(AsterTheme.primary(context)),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Widget: Horas Estudadas nos Últimos 7 Dias (Real) ───
  Widget _buildHoursStatsCard(DashboardSevenDaysStats stats, bool isDark) {
    final totalFormatted = DashboardAnalytics.formatReadableDuration(stats.totalMinutes);

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
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                ),
              ),
              Text(
                'últimos 7 dias',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                totalFormatted,
                style: GoogleFonts.manrope(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  stats.deltaLabel,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: stats.deltaPositive ? AsterConstants.menta : AsterConstants.coral,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 72,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: stats.bars.map((bar) {
                return Tooltip(
                  message:
                      '${bar.fullDayLabel}: ${DashboardAnalytics.formatReadableDuration(bar.minutes)}',
                  child: _buildMiniBar(
                    bar.dayLetter,
                    bar.fraction,
                    isHighlight: bar.isToday,
                    hasActivity: bar.minutes > 0,
                    isDark: isDark,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBar(
    String day,
    double heightFraction, {
    bool isHighlight = false,
    bool hasActivity = false,
    bool isDark = false,
  }) {
    final primaryCol = AsterTheme.primary(context);
    final barColor = isHighlight
        ? primaryCol
        : hasActivity
            ? primaryCol.withValues(alpha: 0.42)
            : AsterTheme.surfaceInset(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 16,
          height: 44 * heightFraction,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          day,
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
            color: isHighlight ? primaryCol : AsterTheme.textMuted(context),
          ),
        ),
      ],
    );
  }

  // ─── Widget: Distribuição por Disciplina (Real + Filtro de Período) ───
  Widget _buildDistributionCard(
    Map<String, int> subjectMinutes,
    int? daysWindow,
    bool isDark,
  ) {
    final colors = [
      AsterTheme.accent(context, 0),
      AsterTheme.accent(context, 1),
      AsterTheme.accent(context, 2),
      AsterTheme.accent(context, 3),
      AsterTheme.primary(context),
    ];

    return SoftClayCard.list(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Distribuição',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                    ),
                  ),
                  Text(
                    'por disciplina',
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildWindowToggleChip('7d', 7, daysWindow == 7, isDark),
                    _buildWindowToggleChip('30d', 30, daysWindow == 30, isDark),
                    _buildWindowToggleChip('Tudo', null, daysWindow == null, isDark),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          if (subjectMinutes.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
              ),
              child: Center(
                child: Text(
                  'Nenhum estudo registrado neste período ainda.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
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
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                            ),
                          ),
                          Text(
                            subjectMinutes.length == 1 ? 'área' : 'áreas',
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),

                Expanded(
                  child: Column(
                    children: subjectMinutes.entries.toList().asMap().entries.map((item) {
                      final color = colors[item.key % colors.length];
                      final durationStr =
                          DashboardAnalytics.formatCompactDuration(item.value.value);
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
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                ),
                              ),
                            ),
                            Text(
                              durationStr,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                              ),
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

  Widget _buildWindowToggleChip(String label, int? value, bool selected, bool isDark) {
    final primaryCol = AsterTheme.primary(context);
    final onPrimaryCol = AsterTheme.onPrimary(context);
    return GestureDetector(
      onTap: () => _distributionDaysWindow.value = value,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? primaryCol : Colors.transparent,
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: selected ? onPrimaryCol : AsterTheme.textMuted(context),
          ),
        ),
      ),
    );
  }

  // ─── Widget: Consistência · 182 dias (Heatmap Real & Interativo) ───
  Widget _buildHeatmapCard(DashboardConsistencyStats consistency, bool isDark) {
    final streakStr = '${consistency.currentStreakDays}d';
    final bestStr = consistency.bestDayMinutes > 0
        ? DashboardAnalytics.formatCompactDuration(consistency.bestDayMinutes)
        : '0m';

    return SoftClayCard.list(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Consistência · ${consistency.totalTrackedDays} dias',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                    ),
                  ),
                  ValueListenableBuilder<String?>(
                    valueListenable: _hoveredDayLabel,
                    builder: (context, hovered, _) {
                      return Text(
                        hovered ??
                            '${consistency.activeDaysCount} dia${consistency.activeDaysCount == 1 ? '' : 's'} ativo${consistency.activeDaysCount == 1 ? '' : 's'} · toque/passe o mouse nos pontos',
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: hovered != null
                              ? AsterConstants.menta
                              : (isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                        ),
                      );
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'Menos ',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                    ),
                  ),
                  _buildDot(0, isDark: isDark),
                  _buildDot(1, isDark: isDark),
                  _buildDot(2, isDark: isDark),
                  _buildDot(3, isDark: isDark),
                  _buildDot(4, isDark: isDark),
                  Text(
                    ' Mais',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  height: 110,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConsistencyHeatmap(
                      columns: consistency.levels.length,
                      rows: 7,
                      levels: consistency.levels,
                      datesGrid: consistency.datesGrid,
                      minutesGrid: consistency.minutesGrid,
                      onDayInspected: (label) {
                        _hoveredDayLabel.value = label;
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STREAK ATUAL',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    streakStr,
                    key: const Key('dashboard_streak_value'),
                    style: GoogleFonts.manrope(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'MELHOR DIA',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    bestStr,
                    key: const Key('dashboard_best_day_value'),
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int level, {bool isDark = false}) {
    return Container(
      width: 9,
      height: 9,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: ConsistencyHeatmap.colorForLevel(
          level,
          isDark: isDark,
          activeColor: AsterTheme.secondary(context),
          emptyColor: AsterTheme.surfaceInset(context),
        ),
        shape: BoxShape.circle,
      ),
    );
  }

  // ─── Widget: Sessões Recentes Reais com Atalho para Diário de Estudos ───
  Widget _buildRecentSessionsCard(
    List<Map<String, dynamic>> realSessions,
    List<String> suggestedSubjects,
    bool isDark,
  ) {
    final palette = [
      AsterTheme.accent(context, 0),
      AsterTheme.accent(context, 1),
      AsterTheme.accent(context, 2),
      AsterTheme.accent(context, 3),
    ];

    return SoftClayCard.list(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Sessões recentes',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => RootScreen.switchTab(7),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Abrir Diário',
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                onTap: () => _openAddSessionModal(suggestedSubjects: suggestedSubjects),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    '+ Nova Sessão',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AsterTheme.primary(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (realSessions.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.auto_stories_rounded,
                    size: 28,
                    color: AsterTheme.primary(context).withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Você ainda não registrou sessões de estudo.',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Use o cronômetro acima ou clique em + Nova Sessão para iniciar seu histórico.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                    ),
                  ),
                ],
              ),
            )
          else
            ...realSessions.take(4).toList().asMap().entries.map((entry) {
              final idx = entry.key;
              final s = entry.value;
              final sub = (s['subject'] ?? 'Estudo').toString();
              final top = (s['topic'] ?? '').toString();
              final mins = (s['duration_minutes'] as num?)?.toInt() ?? 0;
              final notes = (s['notes'] ?? '').toString();
              final studyDate = (s['study_date'] ?? '').toString();
              final duration = DashboardAnalytics.formatCompactDuration(mins);
              final color = palette[idx % palette.length];

              return _buildSessionRow(
                title: top.isNotEmpty ? '$sub — $top' : sub,
                tag: sub,
                subtitle: notes.isNotEmpty ? notes : studyDate,
                duration: duration,
                color: color,
                onDelete: () async {
                  await SupabaseService.deleteStudySession(s['id'].toString());
                  await _refreshEcosystemAndSubject();
                },
                isDark: isDark,
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
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
            width: 1,
          ),
        ),
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
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
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
                  color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
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

  // ─── Widget: Insight do Agente (Totalmente Funcional & Conectado ao Ecossistema) ───
  Widget _buildAgentInsightCard({
    required DashboardInsight insight,
    required DashboardEcosystemSnapshot ecosystem,
    required DashboardConsistencyStats consistency,
    required int weeklyGoalMinutes,
    required int currentWeekMinutes,
    required bool isDark,
  }) {
    final spots = insight.accuracySpots;
    final hasChart = spots.length >= 2;
    final accuracyLabel =
        insight.latestAccuracyPct != null ? '${insight.latestAccuracyPct}%' : 'Sem simulados';

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
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                ),
                child: Text(
                  'Noesis AI · ${insight.badgeLabel}',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AsterTheme.primary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight.message,
            key: const Key('dashboard_insight_message'),
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              height: 1.5,
              color: AsterTheme.text(context),
            ),
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SoftClayPillButton(
                text: _scheduledReviewThisSession ? 'Revisão agendada ✓' : 'Agendar revisão',
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: _scheduledReviewThisSession ? AsterTheme.secondary(context) : null,
                onPressed: _scheduledReviewThisSession
                    ? null
                    : () => _scheduleRecommendedReview(insight),
              ),
              SoftClayPillButton(
                text: 'Ver análise',
                isSecondary: true,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                onPressed: () => _openFullAnalysisModal(
                  insight: insight,
                  ecosystem: ecosystem,
                  consistency: consistency,
                  weeklyGoalMinutes: weeklyGoalMinutes,
                  currentWeekMinutes: currentWeekMinutes,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACURÁCIA NOS SIMULADOS',
                      style: GoogleFonts.manrope(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      accuracyLabel,
                      key: const Key('dashboard_accuracy_label'),
                      style: GoogleFonts.manrope(
                        fontSize: insight.latestAccuracyPct != null ? 20 : 14,
                        fontWeight: FontWeight.w900,
                        color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasChart)
                SizedBox(
                  width: 96,
                  height: 34,
                  child: RepaintBoundary(
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: (spots.length - 1).toDouble(),
                        minY: 0,
                        maxY: 100,
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: AsterTheme.secondary(context),
                            barWidth: 2.5,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                TextButton(
                  onPressed: () => RootScreen.switchTab(1),
                  child: Text(
                    'Fazer simulado →',
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AsterTheme.primary(context),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _scheduleRecommendedReview(DashboardInsight insight) async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 14, 0);
    final endTime = tomorrow.add(Duration(minutes: insight.recommendedDurationMinutes));

    await SupabaseService.addCalendarEvent(
      title: insight.recommendedReviewTitle,
      description: insight.recommendedReviewDescription,
      category: 'review',
      startTime: tomorrow,
      endTime: endTime,
    );

    if (!mounted) return;
    setState(() {
      _scheduledReviewThisSession = true;
    });
    await _refreshEcosystemAndSubject();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          persist: false,
          duration: const Duration(seconds: 4),
          backgroundColor: AsterConstants.menta,
          content: Text(
            '"${insight.recommendedReviewTitle}" agendada para amanhã às 14:00!',
          ),
          action: SnackBarAction(
            label: 'Ver Agenda',
            textColor: Colors.white,
            onPressed: () => RootScreen.switchTab(5),
          ),
        ),
      );
  }

  Future<void> _openFullAnalysisModal({
    required DashboardInsight insight,
    required DashboardEcosystemSnapshot ecosystem,
    required DashboardConsistencyStats consistency,
    required int weeklyGoalMinutes,
    required int currentWeekMinutes,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CognitiveAnalysisDialog(
        insight: insight,
        ecosystem: ecosystem,
        consistency: consistency,
        weeklyGoalMinutes: weeklyGoalMinutes,
        currentWeekMinutes: currentWeekMinutes,
      ),
    );
  }
}

class _EcosystemTileData {
  const _EcosystemTileData({
    required this.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final Key key;
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _CognitiveAnalysisDialog extends StatefulWidget {
  const _CognitiveAnalysisDialog({
    required this.insight,
    required this.ecosystem,
    required this.consistency,
    required this.weeklyGoalMinutes,
    required this.currentWeekMinutes,
  });

  final DashboardInsight insight;
  final DashboardEcosystemSnapshot ecosystem;
  final DashboardConsistencyStats consistency;
  final int weeklyGoalMinutes;
  final int currentWeekMinutes;

  @override
  State<_CognitiveAnalysisDialog> createState() => _CognitiveAnalysisDialogState();
}

class _CognitiveAnalysisDialogState extends State<_CognitiveAnalysisDialog> {
  String? _aiPlan;
  bool _isGeneratingAi = false;

  Future<void> _generateAiRecommendations() async {
    setState(() => _isGeneratingAi = true);
    try {
      final prompt = '''
Com base nos dados reais deste estudante no Noesis, gere um plano prático curto (3 tópicos objetivos em português):
- Meta semanal: ${SupabaseService.formatGoalDuration(widget.currentWeekMinutes)} / ${SupabaseService.formatGoalDuration(widget.weeklyGoalMinutes)}
- Streak atual: ${widget.consistency.currentStreakDays} dias | Melhor dia: ${DashboardAnalytics.formatReadableDuration(widget.consistency.bestDayMinutes)}
- Simulados feitos: ${widget.ecosystem.examsCount} | Média: ${widget.ecosystem.averageExamScore?.round() ?? 0}%
- Flashcards pendentes: ${widget.ecosystem.cardsNeedingReview} de ${widget.ecosystem.totalCards}
- Trilhas ativas: ${widget.ecosystem.roadmapsCount} (${widget.ecosystem.overallRoadmapProgressPct}% concluído)
- Principal alerta atual: ${widget.insight.message}
''';
      final response = await GeminiService.executeAgentChat(
        userMessage: prompt,
        history: [],
      );
      if (mounted) {
        setState(() {
          _aiPlan = response;
          _isGeneratingAi = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiPlan = 'Não foi possível gerar a análise com IA agora: $e';
          _isGeneratingAi = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avgExam = widget.ecosystem.averageExamScore;
    final nextStep = widget.ecosystem.nextRoadmapStep;

    return Dialog(
      backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AsterTheme.primary(context).withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.insights_rounded, size: 20, color: AsterTheme.primary(context)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Diagnóstico Completo de Estudos',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                          ),
                        ),
                        Text(
                          'Visão consolidada do seu desempenho no ecossistema Noesis',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              _buildMetricBlock(
                isDark: isDark,
                color: AsterConstants.menta,
                title: 'Ritmo Semanal & Consistência',
                body:
                    'Semana atual: ${SupabaseService.formatGoalDuration(widget.currentWeekMinutes)} / '
                    '${SupabaseService.formatGoalDuration(widget.weeklyGoalMinutes)} · '
                    'Streak: ${widget.consistency.currentStreakDays}d · '
                    'Melhor dia: ${DashboardAnalytics.formatReadableDuration(widget.consistency.bestDayMinutes)}',
              ),
              const SizedBox(height: 10),
              _buildMetricBlock(
                isDark: isDark,
                color: AsterTheme.primary(context),
                title: 'Simulados',
                body: widget.ecosystem.examsCount == 0
                    ? 'Nenhum simulado concluído ainda.'
                    : '${widget.ecosystem.examsCount} simulado${widget.ecosystem.examsCount == 1 ? '' : 's'} concluído${widget.ecosystem.examsCount == 1 ? '' : 's'} · '
                        'Média geral de ${avgExam?.round() ?? 0}%',
              ),
              const SizedBox(height: 10),
              _buildMetricBlock(
                isDark: isDark,
                color: AsterConstants.ambar,
                title: 'Flashcards & Cadernos',
                body:
                    '${widget.ecosystem.cardsNeedingReview} cards pendentes de ${widget.ecosystem.totalCards} totais · '
                    '${widget.ecosystem.notebooksCount} cadernos com ${widget.ecosystem.notesCount} anotações.',
              ),
              const SizedBox(height: 10),
              _buildMetricBlock(
                isDark: isDark,
                color: AsterConstants.coral,
                title: 'Trilhas (Roadmap)',
                body: nextStep == null
                    ? '${widget.ecosystem.roadmapsCount} trilha${widget.ecosystem.roadmapsCount == 1 ? '' : 's'} · ${widget.ecosystem.overallRoadmapProgressPct}% concluído.'
                    : '${widget.ecosystem.overallRoadmapProgressPct}% concluído · Próxima etapa: '
                        '"${nextStep.step.title}" (${nextStep.roadmap.title}).',
              ),

              if (_aiPlan != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AsterTheme.primary(context).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                    border: Border.all(color: AsterTheme.primary(context).withValues(alpha: 0.25)),
                  ),
                  child: MarkdownBody(
                    data: _aiPlan!,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: GoogleFonts.manrope(
                        fontSize: 12.5,
                        height: 1.55,
                        color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                      ),
                      strong: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AsterConstants.textDark,
                      ),
                      em: GoogleFonts.manrope(
                        fontStyle: FontStyle.italic,
                        color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                      ),
                      h1: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AsterConstants.textDark,
                      ),
                      h2: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AsterConstants.textDark,
                      ),
                      h3: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AsterConstants.textDark,
                      ),
                      listBullet: GoogleFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AsterTheme.primary(context),
                      ),
                      listIndent: 16,
                      blockSpacing: 8,
                      code: GoogleFonts.jetBrainsMono(
                        fontSize: 11.5,
                        backgroundColor: isDark
                            ? const Color(0xFF1E202E)
                            : AsterConstants.surfaceInset.withValues(alpha: 0.5),
                        color: AsterTheme.primary(context),
                      ),
                      blockquote: GoogleFonts.manrope(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: OutlinedButton.icon(
                      onPressed: _isGeneratingAi ? null : _generateAiRecommendations,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AsterTheme.primary(context),
                        side: BorderSide(
                          color: AsterTheme.primary(context).withValues(alpha: 0.45),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                        ),
                      ),
                      icon: _isGeneratingAi
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_rounded, size: 16),
                      label: Text(
                        _isGeneratingAi ? 'Analisando...' : 'Gerar plano com Noesis AI',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IntrinsicWidth(
                    child: SoftClayPillButton(
                      text: 'Ir para módulo',
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      onPressed: () {
                        Navigator.of(context).pop();
                        RootScreen.switchTab(widget.insight.targetTab);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBlock({
    required bool isDark,
    required Color color,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
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

/// Widget de Heatmap de Consistência Otimizado com CustomPainter e inspeção por toque/hover.
class ConsistencyHeatmap extends StatelessWidget {
  final int columns;
  final int rows;
  final List<List<int>>? levels;
  final List<List<DateTime>>? datesGrid;
  final List<List<int>>? minutesGrid;
  final ValueChanged<String?>? onDayInspected;

  const ConsistencyHeatmap({
    super.key,
    this.columns = 26,
    this.rows = 7,
    this.levels,
    this.datesGrid,
    this.minutesGrid,
    this.onDayInspected,
  });

  static Color colorForLevel(
    int level, {
    bool isDark = false,
    Color? activeColor,
    Color? emptyColor,
  }) {
    final base = activeColor ?? AsterConstants.menta;
    switch (level) {
      case 4:
        return base;
      case 3:
        return base.withValues(alpha: 0.7);
      case 2:
        return base.withValues(alpha: 0.45);
      case 1:
        return base.withValues(alpha: 0.22);
      default:
        return emptyColor ?? (isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset);
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

  void _inspectOffset(Offset localPos, Size size) {
    if (onDayInspected == null || datesGrid == null || minutesGrid == null) return;
    const double colStep = 17.0;
    const double dotDiameter = 9.0;
    final double rowStep = (size.height - dotDiameter) / (rows - 1);

    final col = (localPos.dx / colStep).floor();
    final row = ((localPos.dy - dotDiameter / 2) / rowStep).round();

    if (col >= 0 && col < columns && row >= 0 && row < rows) {
      final date = datesGrid![col][row];
      final mins = minutesGrid![col][row];
      final dateStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
      final durStr = mins > 0
          ? '${DashboardAnalytics.formatReadableDuration(mins)} estudados'
          : 'Sem registro';
      onDayInspected!('$dateStr: $durStr');
    }
  }

  @override
  Widget build(BuildContext context) {
    const double colWidth = 17.0;
    final size = Size(columns * colWidth, 110);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeCol = AsterTheme.secondary(context);
    final emptyCol = AsterTheme.surfaceInset(context);

    return RepaintBoundary(
      child: MouseRegion(
        onHover: (event) => _inspectOffset(event.localPosition, size),
        onExit: (_) => onDayInspected?.call(null),
        child: GestureDetector(
          onTapDown: (details) => _inspectOffset(details.localPosition, size),
          child: CustomPaint(
            size: size,
            painter: _HeatmapPainter(
              columns: columns,
              rows: rows,
              levels: levels,
              isDark: isDark,
              activeColor: activeCol,
              emptyColor: emptyCol,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final int columns;
  final int rows;
  final List<List<int>>? levels;
  final bool isDark;
  final Color activeColor;
  final Color emptyColor;

  _HeatmapPainter({
    required this.columns,
    required this.rows,
    this.levels,
    this.isDark = false,
    required this.activeColor,
    required this.emptyColor,
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

        paint.color = ConsistencyHeatmap.colorForLevel(
          level,
          isDark: isDark,
          activeColor: activeColor,
          emptyColor: emptyColor,
        );
        canvas.drawCircle(Offset(cx, cy), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) {
    return oldDelegate.columns != columns ||
        oldDelegate.rows != rows ||
        oldDelegate.levels != levels ||
        oldDelegate.isDark != isDark ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.emptyColor != emptyColor;
  }
}
