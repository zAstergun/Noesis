import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/supabase_service.dart';
import '../../core/theme.dart';
import '../../widgets/weekly_goal_dialog.dart';

enum _StudyPeriodFilter { all, today, week, month }

/// Área dedicada ao **Diário de Estudos**: registra quanto tempo foi estudado
/// em cada dia, o que foi estudado e mostra evolução diária e por matéria.
class StudyLogScreen extends StatefulWidget {
  const StudyLogScreen({super.key});

  /// Extrai e ordena as matérias realmente estudadas na conta por frequência e tempo total.
  /// Nunca inventa ou injeta matérias que a pessoa não estuda.
  static List<String> resolvePersonalizedSubjects(
    List<Map<String, dynamic>> sessions, {
    int maxCount = 8,
  }) {
    final counts = <String, int>{};
    final minutes = <String, int>{};
    final canonical = <String, String>{};

    for (final s in sessions) {
      final raw = (s['subject'] ?? '').toString().trim();
      if (raw.isEmpty) continue;
      final key = raw.toLowerCase();
      canonical.putIfAbsent(key, () => raw);
      counts[key] = (counts[key] ?? 0) + 1;
      minutes[key] = (minutes[key] ?? 0) + ((s['duration_minutes'] as num?)?.toInt() ?? 0);
    }

    final sortedKeys = canonical.keys.toList()
      ..sort((a, b) {
        final scoreA = (counts[a] ?? 0) * 10000 + (minutes[a] ?? 0);
        final scoreB = (counts[b] ?? 0) * 10000 + (minutes[b] ?? 0);
        return scoreB.compareTo(scoreA);
      });

    return sortedKeys.take(maxCount).map((k) => canonical[k]!).toList();
  }

  /// Combina as durações mais frequentes registradas pela conta (ex.: 4h = 240m)
  /// com atalhos padrão equilibrados em ordem crescente.
  static List<int> resolvePersonalizedDurations(
    List<Map<String, dynamic>> sessions, {
    int maxCount = 7,
  }) {
    final freq = <int, int>{};
    for (final s in sessions) {
      final mins = (s['duration_minutes'] as num?)?.toInt() ?? 0;
      if (mins > 0) {
        freq[mins] = (freq[mins] ?? 0) + 1;
      }
    }

    final userRanked = freq.keys.toList()
      ..sort((a, b) {
        final cmp = (freq[b] ?? 0).compareTo(freq[a] ?? 0);
        return cmp != 0 ? cmp : b.compareTo(a);
      });

    final chosen = <int>{};
    for (final d in userRanked.take(4)) {
      chosen.add(d);
    }
    const defaults = [30, 45, 60, 90, 120, 15, 180];
    for (final d in defaults) {
      if (chosen.length >= maxCount) break;
      chosen.add(d);
    }

    final result = chosen.toList()..sort();
    return result;
  }

  /// Retorna a duração mais frequente da conta para pré-preencher novos registros.
  static int? resolvePreferredDuration(List<Map<String, dynamic>> sessions) {
    final freq = <int, int>{};
    for (final s in sessions) {
      final mins = (s['duration_minutes'] as num?)?.toInt() ?? 0;
      if (mins > 0) {
        freq[mins] = (freq[mins] ?? 0) + 1;
      }
    }
    if (freq.isEmpty) return null;
    final sorted = freq.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.compareTo(a.value);
        return cmp != 0 ? cmp : b.key.compareTo(a.key);
      });
    return sorted.first.key;
  }

  @override
  State<StudyLogScreen> createState() => _StudyLogScreenState();
}

class _StudyLogScreenState extends State<StudyLogScreen> {
  final _searchController = TextEditingController();
  final _subjectController = TextEditingController();
  final _topicController = TextEditingController();
  final _hoursController = TextEditingController(text: '0');
  final _minutesController = TextEditingController(text: '45');
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  _StudyPeriodFilter _periodFilter = _StudyPeriodFilter.all;
  String? _subjectFilter;
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _userEditedDuration = false;
  StreamSubscription<List<Map<String, dynamic>>>? _sessionsSub;

  @override
  void initState() {
    super.initState();
    SupabaseService.loadDailyGoalMinutes();
    _loadInitial();
    _sessionsSub = SupabaseService.studySessionsStream().listen((list) {
      if (mounted) {
        final sorted = _sortSessions(list);
        setState(() {
          _sessions = sorted;
          _isLoading = false;
          _applyPreferredDurationIfUntouched(sorted);
        });
      }
    });
  }

  void _applyPreferredDurationIfUntouched(List<Map<String, dynamic>> sessions) {
    if (_userEditedDuration) return;
    final pref = StudyLogScreen.resolvePreferredDuration(sessions);
    if (pref != null && pref > 0) {
      _hoursController.text = (pref ~/ 60).toString();
      _minutesController.text = (pref % 60).toString();
    }
  }

  Future<void> _loadInitial() async {
    final list = await SupabaseService.getStudySessions(limit: 200);
    if (mounted) {
      final sorted = _sortSessions(list);
      setState(() {
        _sessions = sorted;
        _isLoading = false;
        _applyPreferredDurationIfUntouched(sorted);
      });
    }
  }

  List<Map<String, dynamic>> _sortSessions(List<Map<String, dynamic>> raw) {
    final copy = raw.map((e) => Map<String, dynamic>.from(e)).toList();
    copy.sort((a, b) {
      final dateA = (a['study_date'] ?? '').toString();
      final dateB = (b['study_date'] ?? '').toString();
      final cmpDate = dateB.compareTo(dateA);
      if (cmpDate != 0) return cmpDate;
      final createdA = (a['created_at'] ?? '').toString();
      final createdB = (b['created_at'] ?? '').toString();
      return createdB.compareTo(createdA);
    });
    return copy;
  }

  @override
  void dispose() {
    _sessionsSub?.cancel();
    _searchController.dispose();
    _subjectController.dispose();
    _topicController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime _parseDateKey(String raw) {
    return DateTime.tryParse(raw.split('T').first) ?? DateTime.now();
  }

  String _formatDuration(int totalMinutes) {
    if (totalMinutes <= 0) return '0m';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  String _formatDayHeading(String dateKey) {
    final now = DateTime.now();
    final todayKey = _dateKey(now);
    final yesterdayKey = _dateKey(now.subtract(const Duration(days: 1)));
    final dt = _parseDateKey(dateKey);

    String formatted;
    try {
      formatted = DateFormat("EEEE, d 'de' MMM", 'pt_BR').format(dt);
      formatted = formatted[0].toUpperCase() + formatted.substring(1);
    } catch (_) {
      formatted = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }

    if (dateKey == todayKey) return 'Hoje · $formatted';
    if (dateKey == yesterdayKey) return 'Ontem · $formatted';
    return formatted;
  }

  int _totalMinutesForDate(String dateKey) {
    int sum = 0;
    for (final s in _sessions) {
      if ((s['study_date'] ?? '').toString().split('T').first == dateKey) {
        sum += (s['duration_minutes'] as num?)?.toInt() ?? 0;
      }
    }
    return sum;
  }

  int _totalMinutesSinceDays(int days) {
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    int sum = 0;
    for (final s in _sessions) {
      final dt = _parseDateKey((s['study_date'] ?? '').toString());
      final dayOnly = DateTime(dt.year, dt.month, dt.day);
      if (!dayOnly.isBefore(cutoff)) {
        sum += (s['duration_minutes'] as num?)?.toInt() ?? 0;
      }
    }
    return sum;
  }

  int _distinctActiveDaysCount() {
    return _sessions
        .map((s) => (s['study_date'] ?? '').toString().split('T').first)
        .where((d) => d.isNotEmpty)
        .toSet()
        .length;
  }

  List<String> get _personalizedSubjects => StudyLogScreen.resolvePersonalizedSubjects(_sessions);

  List<int> get _personalizedDurations => StudyLogScreen.resolvePersonalizedDurations(_sessions);

  void _setDurationPreset(int totalMinutes) {
    setState(() {
      _userEditedDuration = true;
      _hoursController.text = (totalMinutes ~/ 60).toString();
      _minutesController.text = (totalMinutes % 60).toString();
    });
  }

  int _readCurrentDurationMinutes() {
    final h = int.tryParse(_hoursController.text.trim()) ?? 0;
    final m = int.tryParse(_minutesController.text.trim()) ?? 0;
    return (h * 60) + m;
  }

  InputDecoration _softInputDecoration({
    required bool isDark,
    required String label,
    String? hint,
    IconData? prefixIcon,
    bool onAltSurface = true,
  }) {
    final fill = onAltSurface
        ? (isDark ? AsterConstants.surfaceCardDark : Colors.white)
        : (isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: fill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 17, color: AsterTheme.primary(context))
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AsterTheme.primary(context).withValues(alpha: 0.16)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AsterTheme.primary(context).withValues(alpha: 0.16)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AsterTheme.primary(context), width: 1.6),
      ),
    );
  }

  Future<void> _submitQuickEntry() async {
    final subject = _subjectController.text.trim();
    final topic = _topicController.text.trim();
    final duration = _readCurrentDurationMinutes();
    final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

    if (subject.isEmpty || topic.isEmpty || duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha a matéria, o que foi estudado e uma duração maior que 0 minutos.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await SupabaseService.addStudySession(
        subject: subject,
        topic: topic,
        durationMinutes: duration,
        studyDate: _selectedDate,
        notes: notes,
      );
      if (mounted) {
        _topicController.clear();
        _notesController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Estudo registrado: $subject (${_formatDuration(duration)})!'),
          ),
        );
      }
      await _loadInitial();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openSessionDialog({Map<String, dynamic>? editing}) async {
    final isEditing = editing != null;
    final initialDate = editing != null
        ? _parseDateKey((editing['study_date'] ?? '').toString())
        : _selectedDate;

    final preferredDuration = StudyLogScreen.resolvePreferredDuration(_sessions) ?? 60;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _StudySessionDialog(
        isEditing: isEditing,
        initialDate: initialDate,
        initialSubject: (editing?['subject'] ?? _subjectController.text).toString(),
        initialTopic: (editing?['topic'] ?? '').toString(),
        initialDurationMinutes: (editing?['duration_minutes'] as num?)?.toInt() ?? preferredDuration,
        initialNotes: (editing?['notes'] ?? '').toString(),
        subjectSuggestions: _personalizedSubjects,
        durationSuggestions: _personalizedDurations,
        formatDayHeading: (dt) => _formatDayHeading(_dateKey(dt)),
        formatDuration: _formatDuration,
      ),
    );

    if (result == null) return;
    final subject = result['subject'] as String;
    final topic = result['topic'] as String;
    final totalMinutes = result['durationMinutes'] as int;
    final pickedDate = result['studyDate'] as DateTime;
    final notes = result['notes'] as String?;

    if (isEditing) {
      await SupabaseService.updateStudySession(
        id: editing['id'].toString(),
        subject: subject,
        topic: topic,
        durationMinutes: totalMinutes,
        studyDate: pickedDate,
        notes: notes,
      );
    } else {
      await SupabaseService.addStudySession(
        subject: subject,
        topic: topic,
        durationMinutes: totalMinutes,
        studyDate: pickedDate,
        notes: notes,
      );
    }
    await _loadInitial();
  }

  Future<void> _confirmDeleteSession(Map<String, dynamic> item) async {
    final id = (item['id'] ?? '').toString();
    final subject = (item['subject'] ?? 'Estudo').toString();
    final topic = (item['topic'] ?? '').toString();
    final mins = (item['duration_minutes'] as num?)?.toInt() ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AsterConstants.coral.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: AsterConstants.coral, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Excluir registro de estudo?',
                          style: GoogleFonts.manrope(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                      borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$subject · ${_formatDuration(mins)}',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AsterTheme.primary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          topic,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SoftClayPillButton(
                        text: 'Cancelar',
                        isSecondary: true,
                        onPressed: () => Navigator.of(ctx).pop(false),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AsterConstants.coral,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                          ),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Excluir Registro'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      await SupabaseService.deleteStudySession(id);
      await _loadInitial();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final todayKey = _dateKey(DateTime.now());
    final yesterdayKey = _dateKey(DateTime.now().subtract(const Duration(days: 1)));
    final selectedKey = _dateKey(_selectedDate);
    final isCustomDate = selectedKey != todayKey && selectedKey != yesterdayKey;

    final todayMinutes = _totalMinutesForDate(todayKey);
    final weekMinutes = _totalMinutesSinceDays(7);
    final activeDays = _distinctActiveDaysCount();
    final currentDurationMins = _readCurrentDurationMinutes();

    // Cálculo por matéria
    final minutesBySubject = <String, int>{};
    for (final s in _sessions) {
      final subj = (s['subject'] ?? 'Geral').toString().trim();
      final mins = (s['duration_minutes'] as num?)?.toInt() ?? 0;
      minutesBySubject[subj] = (minutesBySubject[subj] ?? 0) + mins;
    }
    final sortedSubjects = minutesBySubject.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topSubject = sortedSubjects.isNotEmpty ? sortedSubjects.first.key : '—';
    final totalAllMinutes = minutesBySubject.values.fold<int>(0, (a, b) => a + b);

    // Filtros
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();
    final filtered = _sessions.where((s) {
      final subj = (s['subject'] ?? '').toString();
      final topic = (s['topic'] ?? '').toString();
      final notes = (s['notes'] ?? '').toString();
      final dateStr = (s['study_date'] ?? '').toString().split('T').first;

      if (_subjectFilter != null && subj != _subjectFilter) return false;
      if (query.isNotEmpty &&
          !subj.toLowerCase().contains(query) &&
          !topic.toLowerCase().contains(query) &&
          !notes.toLowerCase().contains(query)) {
        return false;
      }

      if (_periodFilter != _StudyPeriodFilter.all) {
        final dt = _parseDateKey(dateStr);
        final dayOnly = DateTime(dt.year, dt.month, dt.day);
        final todayOnly = DateTime(now.year, now.month, now.day);
        switch (_periodFilter) {
          case _StudyPeriodFilter.today:
            if (dayOnly != todayOnly) return false;
            break;
          case _StudyPeriodFilter.week:
            if (dayOnly.isBefore(todayOnly.subtract(const Duration(days: 6)))) return false;
            break;
          case _StudyPeriodFilter.month:
            if (dt.year != now.year || dt.month != now.month) return false;
            break;
          case _StudyPeriodFilter.all:
            break;
        }
      }
      return true;
    }).toList();

    // Agrupamento por dia
    final groupedByDay = <String, List<Map<String, dynamic>>>{};
    for (final s in filtered) {
      final key = (s['study_date'] ?? todayKey).toString().split('T').first;
      groupedByDay.putIfAbsent(key, () => []).add(s);
    }
    final orderedDays = groupedByDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28.0 : 16.0,
        vertical: 16.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Cabeçalho Superior (alinhado ao lado do menu recolhido) ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const NoesisCollapsedMenuSpacer(width: 82),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 560;
                    final titleBlock = Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AsterTheme.primary(context),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.auto_stories_rounded, color: AsterTheme.onPrimary(context), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DIÁRIO DE ESTUDOS',
                                style: GoogleFonts.manrope(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.2,
                                  color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Registre quanto tempo você estudou no dia e o conteúdo trabalhado',
                                style: GoogleFonts.manrope(
                                  fontSize: 12.5,
                                  color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );

                    final actionBtn = SoftClayPillButton(
                      text: 'Novo Registro Completo',
                      icon: Icons.add_rounded,
                      onPressed: () => _openSessionDialog(),
                    );

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          titleBlock,
                          const SizedBox(height: 14),
                          Align(alignment: Alignment.centerLeft, child: actionBtn),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: titleBlock),
                        const SizedBox(width: 16),
                        actionBtn,
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Card Superior: KPIs + Registro Rápido ──
          SoftClayCard(
            padding: EdgeInsets.all(isDesktop ? 28 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // 4 KPI Cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 680;
                    final cards = [
                      ValueListenableBuilder<int>(
                        valueListenable: SupabaseService.dailyGoalMinutesNotifier,
                        builder: (context, dailyGoalMinutes, _) {
                          final hasDailyGoal = dailyGoalMinutes > 0;
                          final safeDaily = hasDailyGoal ? dailyGoalMinutes : 1;
                          final todayProgress = (todayMinutes / safeDaily).clamp(0.0, 1.0);
                          return _kpiBox(
                            key: const Key('study_log_daily_goal_kpi'),
                            label: 'ESTUDADO HOJE',
                            value: _formatDuration(todayMinutes),
                            sub: hasDailyGoal
                                ? 'Meta: ${_formatDuration(dailyGoalMinutes)} (${(todayProgress * 100).round()}%) · editar'
                                : 'Sem meta fixa · definir',
                            color: AsterTheme.primary(context),
                            icon: Icons.today_rounded,
                            progress: hasDailyGoal ? todayProgress : null,
                            onTap: () => showDailyGoalEditorDialog(
                              context,
                              currentWeekStudiedMinutes:
                                  SupabaseService.computeCurrentWeekStudiedMinutes(_sessions),
                              currentDayStudiedMinutes: todayMinutes,
                            ),
                          );
                        },
                      ),
                      _kpiBox(
                        label: 'ÚLTIMOS 7 DIAS',
                        value: _formatDuration(weekMinutes),
                        sub: '${filtered.length} registros visíveis',
                        color: AsterConstants.menta,
                        icon: Icons.date_range_rounded,
                      ),
                      _kpiBox(
                        label: 'DIAS REGISTRADOS',
                        value: '$activeDays dias',
                        sub: 'Consistência no diário',
                        color: AsterConstants.ambar,
                        icon: Icons.local_fire_department_rounded,
                      ),
                      _kpiBox(
                        label: 'FOCO PRINCIPAL',
                        value: topSubject,
                        sub: sortedSubjects.isNotEmpty
                            ? _formatDuration(sortedSubjects.first.value)
                            : 'Sem registros',
                        color: AsterConstants.coral,
                        icon: Icons.school_outlined,
                      ),
                    ];
                    if (isWide) {
                      return Row(
                        children: cards.asMap().entries.map((entry) {
                          final isLast = entry.key == cards.length - 1;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: isLast ? 0 : 12),
                              child: entry.value,
                            ),
                          );
                        }).toList(),
                      );
                    }
                    return Column(
                      children: cards
                          .map((c) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: c,
                              ))
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 22),

                // Registro Rápido inline (Soft Clay)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                    borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
                    border: Border.all(
                      color: AsterTheme.primary(context).withValues(alpha: 0.14),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(Icons.flash_on_rounded, size: 15, color: AsterTheme.primary(context)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'REGISTRO RÁPIDO DO DIA',
                                style: GoogleFonts.manrope(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.9,
                                  color: AsterTheme.primary(context),
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _softPill(
                                  label: 'Hoje',
                                  selected: selectedKey == todayKey,
                                  color: AsterConstants.menta,
                                  onTap: () => setState(() => _selectedDate = DateTime.now()),
                                ),
                                _softPill(
                                  label: 'Ontem',
                                  selected: selectedKey == yesterdayKey,
                                  color: AsterConstants.menta,
                                  onTap: () => setState(
                                    () => _selectedDate = DateTime.now().subtract(const Duration(days: 1)),
                                  ),
                                ),
                                _softPill(
                                  label: isCustomDate
                                      ? DateFormat('dd/MM/yyyy').format(_selectedDate)
                                      : 'Outra data...',
                                  icon: Icons.calendar_today_rounded,
                                  selected: isCustomDate,
                                  color: AsterTheme.primary(context),
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _selectedDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now().add(const Duration(days: 1)),
                                    );
                                    if (picked != null && mounted) {
                                      setState(() => _selectedDate = picked);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        )
                      else ...[
                        Row(
                          children: [
                            Icon(Icons.flash_on_rounded, size: 15, color: AsterTheme.primary(context)),
                            const SizedBox(width: 6),
                            Text(
                              'REGISTRO RÁPIDO DO DIA',
                              style: GoogleFonts.manrope(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.9,
                                color: AsterTheme.primary(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _softPill(
                              label: 'Hoje',
                              selected: selectedKey == todayKey,
                              color: AsterConstants.menta,
                              onTap: () => setState(() => _selectedDate = DateTime.now()),
                            ),
                            _softPill(
                              label: 'Ontem',
                              selected: selectedKey == yesterdayKey,
                              color: AsterConstants.menta,
                              onTap: () => setState(
                                () => _selectedDate = DateTime.now().subtract(const Duration(days: 1)),
                              ),
                            ),
                            _softPill(
                              label: isCustomDate
                                  ? DateFormat('dd/MM/yyyy').format(_selectedDate)
                                  : 'Outra data...',
                              icon: Icons.calendar_today_rounded,
                              selected: isCustomDate,
                              color: AsterTheme.primary(context),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(const Duration(days: 1)),
                                );
                                if (picked != null && mounted) {
                                  setState(() => _selectedDate = picked);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Sugestões personalizadas com base nas matérias realmente estudadas na conta
                      if (_personalizedSubjects.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Suas matérias:',
                              style: GoogleFonts.manrope(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AsterConstants.textMuted,
                              ),
                            ),
                            ..._personalizedSubjects.map((subj) {
                              final active = _subjectController.text.trim() == subj;
                              return _softPill(
                                label: subj,
                                selected: active,
                                color: AsterTheme.primary(context),
                                onTap: () => setState(() => _subjectController.text = subj),
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],

                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _subjectController,
                                onChanged: (_) => setState(() {}),
                                decoration: _softInputDecoration(
                                  isDark: isDark,
                                  label: 'Matéria / Disciplina',
                                  hint: 'Ex.: Matemática',
                                  prefixIcon: Icons.book_outlined,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _topicController,
                                decoration: _softInputDecoration(
                                  isDark: isDark,
                                  label: 'O que você estudou?',
                                  hint: 'Ex.: Trigonometria, Lei de Ohm, Redação...',
                                  prefixIcon: Icons.edit_note_rounded,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 96,
                              child: TextField(
                                controller: _hoursController,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() => _userEditedDuration = true),
                                decoration: _softInputDecoration(
                                  isDark: isDark,
                                  label: 'Horas',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 96,
                              child: TextField(
                                controller: _minutesController,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() => _userEditedDuration = true),
                                decoration: _softInputDecoration(
                                  isDark: isDark,
                                  label: 'Min',
                                ),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        TextField(
                          controller: _subjectController,
                          onChanged: (_) => setState(() {}),
                          decoration: _softInputDecoration(
                            isDark: isDark,
                            label: 'Matéria / Disciplina',
                            hint: 'Ex.: Matemática',
                            prefixIcon: Icons.book_outlined,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _topicController,
                          decoration: _softInputDecoration(
                            isDark: isDark,
                            label: 'O que você estudou?',
                            hint: 'Ex.: Trigonometria + 20 questões',
                            prefixIcon: Icons.edit_note_rounded,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _hoursController,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() => _userEditedDuration = true),
                                decoration: _softInputDecoration(
                                  isDark: isDark,
                                  label: 'Horas',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _minutesController,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() => _userEditedDuration = true),
                                decoration: _softInputDecoration(
                                  isDark: isDark,
                                  label: 'Minutos',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Atalhos de duração Soft Clay adaptados à rotina da conta
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Duração rápida:',
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AsterConstants.textMuted,
                            ),
                          ),
                          ..._personalizedDurations.map((m) {
                            return _softPill(
                              key: ValueKey('quick_dur_$m'),
                              label: _formatDuration(m),
                              selected: currentDurationMins == m,
                              color: AsterConstants.ambar,
                              onTap: () => _setDurationPreset(m),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _notesController,
                              decoration: _softInputDecoration(
                                isDark: isDark,
                                label: 'Observações / Onde parou (opcional)',
                                hint: 'Ex.: Cap. 4 concluído; revisar regra de cadeia amanhã.',
                                prefixIcon: Icons.notes_rounded,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SoftClayPillButton(
                            text: _isSaving ? 'Salvando...' : 'Salvar Estudo',
                            icon: Icons.check_circle_outline_rounded,
                            onPressed: _isSaving ? () {} : _submitQuickEntry,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Distribuição por Matéria ──
          if (sortedSubjects.isNotEmpty) ...[
            SoftClayCard(
              padding: EdgeInsets.all(isDesktop ? 24 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'TEMPO DEDICADO POR MATÉRIA',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: AsterConstants.textMuted,
                          ),
                        ),
                      ),
                      if (_subjectFilter != null)
                        TextButton(
                          onPressed: () => setState(() => _subjectFilter = null),
                          child: const Text('Limpar filtro'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...sortedSubjects.take(6).map((entry) {
                    final pct = totalAllMinutes > 0 ? entry.value / totalAllMinutes : 0.0;
                    final isSelected = _subjectFilter == entry.key;
                    return InkWell(
                      onTap: () => setState(() {
                        _subjectFilter = isSelected ? null : entry.key;
                      }),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: GoogleFonts.manrope(
                                      fontSize: 12.5,
                                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                      color: isSelected
                                          ? AsterTheme.primary(context)
                                          : (isDark ? AsterConstants.textLight : AsterConstants.textDark),
                                    ),
                                  ),
                                ),
                                Text(
                                  '${_formatDuration(entry.value)} (${(pct * 100).round()}%)',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: AsterTheme.primary(context),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                              child: LinearProgressIndicator(
                                value: pct.clamp(0.03, 1.0),
                                minHeight: 7,
                                backgroundColor: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
                                valueColor: AlwaysStoppedAnimation(
                                  isSelected ? AsterConstants.menta : AsterTheme.primary(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Linha do Tempo por Dia ──
          SoftClayCard(
            padding: EdgeInsets.all(isDesktop ? 24 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'HISTÓRICO DIÁRIO (${filtered.length} REGISTROS)',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: AsterConstants.textMuted,
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _periodChip('Todos', _StudyPeriodFilter.all),
                        _periodChip('Hoje', _StudyPeriodFilter.today),
                        _periodChip('7 dias', _StudyPeriodFilter.week),
                        _periodChip('Mês', _StudyPeriodFilter.month),
                        SizedBox(
                          width: 230,
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: _softInputDecoration(
                              isDark: isDark,
                              label: 'Buscar matéria ou tema',
                              prefixIcon: Icons.search_rounded,
                              onAltSurface: false,
                            ).copyWith(
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 14),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (orderedDays.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                      borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.auto_stories_outlined,
                            size: 38, color: AsterTheme.primary(context).withValues(alpha: 0.6)),
                        const SizedBox(height: 10),
                        Text(
                          'Nenhum registro de estudo encontrado para esse filtro.',
                          style: GoogleFonts.manrope(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AsterConstants.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...orderedDays.map((dayKey) {
                    final dayItems = groupedByDay[dayKey]!;
                    final dayTotalMins = dayItems.fold<int>(
                      0,
                      (acc, s) => acc + ((s['duration_minutes'] as num?)?.toInt() ?? 0),
                    );
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 15, color: AsterTheme.primary(context)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _formatDayHeading(dayKey),
                                  style: GoogleFonts.manrope(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                  ),
                                ),
                              ),
                              SoftClayTag(
                                label: 'Total do dia: ${_formatDuration(dayTotalMins)}',
                                color: AsterConstants.menta,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...dayItems.map((item) {
                            final mins = (item['duration_minutes'] as num?)?.toInt() ?? 0;
                            final subj = (item['subject'] ?? 'Geral').toString();
                            final topic = (item['topic'] ?? '').toString();
                            final notes = (item['notes'] ?? '').toString().trim();

                            return Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
                                borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                                border: Border(
                                  left: BorderSide(color: AsterTheme.primary(context), width: 3.5),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            SoftClayTag(label: subj, color: AsterTheme.primary(context)),
                                            SoftClayTag(label: _formatDuration(mins), color: AsterConstants.ambar),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          topic,
                                          style: GoogleFonts.manrope(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                          ),
                                        ),
                                        if (notes.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            notes,
                                            style: GoogleFonts.manrope(
                                              fontSize: 12,
                                              height: 1.45,
                                              color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Editar registro',
                                    onPressed: () => _openSessionDialog(editing: item),
                                    icon: const Icon(Icons.edit_outlined, size: 17, color: AsterConstants.textMuted),
                                  ),
                                  IconButton(
                                    tooltip: 'Excluir registro',
                                    onPressed: () => _confirmDeleteSession(item),
                                    icon: const Icon(Icons.delete_outline_rounded, size: 17, color: AsterConstants.coral),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _kpiBox({
    Key? key,
    required String label,
    required String value,
    required String sub,
    required Color color,
    required IconData icon,
    double? progress,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
            borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
            border: Border.all(color: color.withValues(alpha: 0.14)),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 13, color: color),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: AsterConstants.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 18.5,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: AsterConstants.textMuted,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ],
      ),
        ),
      ),
    );
  }

  Widget _softPill({
    Key? key,
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? color
                : (isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard),
            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.22),
              width: 1.1,
            ),
            boxShadow: selected ? null : AsterConstants.claySubtleShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: selected
                      ? (ThemeData.estimateBrightnessForColor(color) == Brightness.light
                          ? const Color(0xFF111111)
                          : Colors.white)
                      : color,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? (ThemeData.estimateBrightnessForColor(color) == Brightness.light
                          ? const Color(0xFF111111)
                          : Colors.white)
                      : (isDark ? AsterConstants.textLight : AsterConstants.textDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _periodChip(String label, _StudyPeriodFilter target) {
    return _softPill(
      label: label,
      selected: _periodFilter == target,
      color: AsterTheme.primary(context),
      onTap: () => setState(() => _periodFilter = target),
    );
  }
}

class _StudySessionDialog extends StatefulWidget {
  const _StudySessionDialog({
    required this.isEditing,
    required this.initialDate,
    required this.initialSubject,
    required this.initialTopic,
    required this.initialDurationMinutes,
    required this.initialNotes,
    required this.subjectSuggestions,
    required this.durationSuggestions,
    required this.formatDayHeading,
    required this.formatDuration,
  });

  final bool isEditing;
  final DateTime initialDate;
  final String initialSubject;
  final String initialTopic;
  final int initialDurationMinutes;
  final String initialNotes;
  final List<String> subjectSuggestions;
  final List<int> durationSuggestions;
  final String Function(DateTime) formatDayHeading;
  final String Function(int) formatDuration;

  @override
  State<_StudySessionDialog> createState() => _StudySessionDialogState();
}

class _StudySessionDialogState extends State<_StudySessionDialog> {
  late final TextEditingController _subjCtrl;
  late final TextEditingController _topicCtrl;
  late final TextEditingController _hrsCtrl;
  late final TextEditingController _minsCtrl;
  late final TextEditingController _notesCtrl;
  late DateTime _pickedDate;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _subjCtrl = TextEditingController(text: widget.initialSubject);
    _topicCtrl = TextEditingController(text: widget.initialTopic);
    _hrsCtrl = TextEditingController(text: (widget.initialDurationMinutes ~/ 60).toString());
    _minsCtrl = TextEditingController(text: (widget.initialDurationMinutes % 60).toString());
    _notesCtrl = TextEditingController(text: widget.initialNotes);
    _pickedDate = widget.initialDate;
  }

  @override
  void dispose() {
    _subjCtrl.dispose();
    _topicCtrl.dispose();
    _hrsCtrl.dispose();
    _minsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _dayKey(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  int get _currentMinutes {
    final h = int.tryParse(_hrsCtrl.text.trim()) ?? 0;
    final m = int.tryParse(_minsCtrl.text.trim()) ?? 0;
    return (h * 60) + m;
  }

  InputDecoration _modalFieldDecoration({
    required bool isDark,
    required String label,
    String? hint,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 17, color: AsterTheme.primary(context)) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AsterTheme.primary(context).withValues(alpha: 0.16)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AsterTheme.primary(context).withValues(alpha: 0.16)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AsterTheme.primary(context), width: 1.6),
      ),
    );
  }

  Widget _modalPill({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? color
                : (isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt),
            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
            border: Border.all(color: selected ? color : color.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: selected
                      ? (ThemeData.estimateBrightnessForColor(color) == Brightness.light
                          ? const Color(0xFF111111)
                          : Colors.white)
                      : color,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? (ThemeData.estimateBrightnessForColor(color) == Brightness.light
                          ? const Color(0xFF111111)
                          : Colors.white)
                      : (isDark ? AsterConstants.textLight : AsterConstants.textDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final s = _subjCtrl.text.trim();
    final t = _topicCtrl.text.trim();
    final total = _currentMinutes;
    final n = _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();

    if (s.isEmpty) {
      setState(() => _validationError = 'Informe a matéria ou disciplina estudada.');
      return;
    }
    if (t.isEmpty) {
      setState(() => _validationError = 'Descreva o que foi estudado nessa sessão.');
      return;
    }
    if (total <= 0) {
      setState(() => _validationError = 'Defina uma duração maior que 0 minutos.');
      return;
    }

    Navigator.of(context).pop({
      'subject': s,
      'topic': t,
      'durationMinutes': total,
      'studyDate': _pickedDate,
      'notes': n,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final todayKey = _dayKey(DateTime.now());
    final yesterdayKey = _dayKey(DateTime.now().subtract(const Duration(days: 1)));
    final pickedKey = _dayKey(_pickedDate);
    final isCustomDate = pickedKey != todayKey && pickedKey != yesterdayKey;

    return Dialog(
      backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho Soft Clay
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AsterTheme.primary(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.auto_stories_rounded, color: AsterTheme.onPrimary(context), size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isEditing ? 'Editar Registro de Estudo' : 'Registrar Estudo do Dia',
                          style: GoogleFonts.manrope(
                            fontSize: 17.5,
                            fontWeight: FontWeight.w900,
                            color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                          ),
                        ),
                        Text(
                          'Defina o dia, a matéria, o tempo dedicado e o conteúdo trabalhado.',
                          style: GoogleFonts.manrope(fontSize: 12, color: AsterConstants.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: AsterConstants.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Data
                      Text(
                        'DATA DO ESTUDO',
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                          color: AsterConstants.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _modalPill(
                            label: 'Hoje',
                            selected: pickedKey == todayKey,
                            color: AsterConstants.menta,
                            onTap: () => setState(() => _pickedDate = DateTime.now()),
                          ),
                          _modalPill(
                            label: 'Ontem',
                            selected: pickedKey == yesterdayKey,
                            color: AsterConstants.menta,
                            onTap: () => setState(
                              () => _pickedDate = DateTime.now().subtract(const Duration(days: 1)),
                            ),
                          ),
                          _modalPill(
                            label: isCustomDate
                                ? widget.formatDayHeading(_pickedDate)
                                : 'Escolher no calendário',
                            icon: Icons.calendar_today_rounded,
                            selected: isCustomDate,
                            color: AsterTheme.primary(context),
                            onTap: () async {
                              final chosen = await showDatePicker(
                                context: context,
                                initialDate: _pickedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 1)),
                              );
                              if (chosen != null && mounted) {
                                setState(() => _pickedDate = chosen);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Sugestões de matéria (apenas matérias da conta)
                      if (widget.subjectSuggestions.isNotEmpty) ...[
                        Text(
                          'MATÉRIA / DISCIPLINA',
                          style: GoogleFonts.manrope(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
                            color: AsterConstants.textMuted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.subjectSuggestions.map((subj) {
                            return _modalPill(
                              label: subj,
                              selected: _subjCtrl.text.trim() == subj,
                              color: AsterTheme.primary(context),
                              onTap: () => setState(() {
                                _subjCtrl.text = subj;
                                _validationError = null;
                              }),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextField(
                        controller: _subjCtrl,
                        onChanged: (_) => setState(() => _validationError = null),
                        decoration: _modalFieldDecoration(
                          isDark: isDark,
                          label: 'Matéria / Disciplina',
                          hint: 'Ex.: Matemática, Biologia, Direito...',
                          prefixIcon: Icons.book_outlined,
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: _topicCtrl,
                        onChanged: (_) => setState(() => _validationError = null),
                        decoration: _modalFieldDecoration(
                          isDark: isDark,
                          label: 'O que foi estudado',
                          hint: 'Ex.: Funções exponenciais + 15 questões ENEM',
                          prefixIcon: Icons.edit_note_rounded,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'QUANTO TEMPO ESTUDOU (${widget.formatDuration(_currentMinutes)})',
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                          color: AsterConstants.textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.durationSuggestions.map((m) {
                          return _modalPill(
                            label: widget.formatDuration(m),
                            selected: _currentMinutes == m,
                            color: AsterConstants.ambar,
                            onTap: () {
                              setState(() {
                                _hrsCtrl.text = (m ~/ 60).toString();
                                _minsCtrl.text = (m % 60).toString();
                                _validationError = null;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _hrsCtrl,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() => _validationError = null),
                              decoration: _modalFieldDecoration(isDark: isDark, label: 'Horas'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _minsCtrl,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() => _validationError = null),
                              decoration: _modalFieldDecoration(isDark: isDark, label: 'Minutos'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: _notesCtrl,
                        maxLines: 3,
                        decoration: _modalFieldDecoration(
                          isDark: isDark,
                          label: 'Resumo / Onde parou / Dificuldades (opcional)',
                          hint: 'Anote pontos importantes para retomar amanhã...',
                          prefixIcon: Icons.notes_rounded,
                        ),
                      ),
                      if (_validationError != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _validationError!,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AsterConstants.coral,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Rodapé
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SoftClayPillButton(
                    text: 'Cancelar',
                    isSecondary: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  SoftClayPillButton(
                    text: widget.isEditing ? 'Salvar Alterações' : 'Registrar Estudo',
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
