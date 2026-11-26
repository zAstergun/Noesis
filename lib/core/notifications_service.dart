import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../features/flashcards/models/flashcard_model.dart';
import '../features/notebooks/models/notebook_model.dart';
import '../features/quizzes/data/saved_exams_repository.dart';
import '../features/quizzes/data/saved_exams_store_stub.dart'
    if (dart.library.io) '../features/quizzes/data/saved_exams_store_io.dart'
    if (dart.library.js_interop) '../features/quizzes/data/saved_exams_store_web.dart' as local_store;
import '../features/roadmaps/data/roadmaps_repository.dart';
import '../features/roadmaps/models/roadmap_model.dart';
import 'constants.dart';
import 'gemini_service.dart';
import 'insights_economy_config.dart';
import 'shop_service.dart';
import 'supabase_service.dart';
import 'theme.dart';

/// Paleta semântica resolvida dinamicamente conforme o tema ativo.
enum NotificationTone { primary, secondary, amber, coral }

/// Notificação real derivada do estado da conta do estudante.
class NoesisNotification {
  const NoesisNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timeLabel,
    required this.icon,
    required this.tone,
    required this.targetTab,
    required this.priority,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String message;
  final String timeLabel;
  final IconData icon;
  final NotificationTone tone;
  final int targetTab;
  final int priority;
  final bool isRead;

  Color resolveColor(BuildContext context) {
    switch (tone) {
      case NotificationTone.primary:
        return AsterTheme.primary(context);
      case NotificationTone.secondary:
        return AsterTheme.secondary(context);
      case NotificationTone.amber:
        return AsterConstants.ambar;
      case NotificationTone.coral:
        return AsterConstants.coral;
    }
  }

  NoesisNotification copyWith({bool? isRead}) {
    return NoesisNotification(
      id: id,
      title: title,
      message: message,
      timeLabel: timeLabel,
      icon: icon,
      tone: tone,
      targetTab: targetTab,
      priority: priority,
      isRead: isRead ?? this.isRead,
    );
  }
}

/// Serviço central de notificações reais e reativas do Noesis.
/// Consolida agenda, revisões pendentes (flashcards e cadernos), meta semanal,
/// streak real, simulados, trilhas e configuração de IA com persistência de leitura/descarte.
class NotificationsService {
  NotificationsService._();

  static final NotificationsService instance = NotificationsService._();
  static const String _stateStorageKey = 'noesis_notifications_state_v1';

  final ValueNotifier<List<NoesisNotification>> notificationsNotifier =
      ValueNotifier<List<NoesisNotification>>(const []);

  final Set<String> _readIds = {};
  final Set<String> _dismissedIds = {};
  bool _stateLoaded = false;
  bool _started = false;
  Future<void>? _inFlightRefresh;

  StreamSubscription<List<Map<String, dynamic>>>? _sessionsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _calendarSub;

  int get unreadCount => notificationsNotifier.value.where((n) => !n.isRead).length;

  /// Inicia observadores em tempo real nos dados do usuário.
  void start() {
    if (!_started) {
      _started = true;
      _sessionsSub = SupabaseService.studySessionsStream().listen((_) {
        refresh();
      });
      _calendarSub = SupabaseService.calendarEventsStream().listen((_) {
        refresh();
      });
      SupabaseService.weeklyGoalMinutesNotifier.addListener(_onGoalChanged);
    }
    refresh();
  }

  void _onGoalChanged() {
    refresh();
  }

  /// Libera inscrições ativas.
  void stop() {
    _sessionsSub?.cancel();
    _sessionsSub = null;
    _calendarSub?.cancel();
    _calendarSub = null;
    SupabaseService.weeklyGoalMinutesNotifier.removeListener(_onGoalChanged);
    _started = false;
  }

  Future<void> _ensureStateLoaded() async {
    if (_stateLoaded) return;
    _stateLoaded = true;
    try {
      final raw = await local_store.readSavedExamsRaw(_stateStorageKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final reads = decoded['read_ids'];
          final dismissed = decoded['dismissed_ids'];
          if (reads is List) {
            _readIds.addAll(reads.map((e) => e.toString()));
          }
          if (dismissed is List) {
            _dismissedIds.addAll(dismissed.map((e) => e.toString()));
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _persistState() async {
    try {
      await local_store.writeSavedExamsRaw(
        _stateStorageKey,
        jsonEncode({
          'read_ids': _readIds.toList(),
          'dismissed_ids': _dismissedIds.toList(),
        }),
      );
    } catch (_) {}
  }

  /// Recalcula todas as notificações a partir dos dados reais atuais.
  Future<void> refresh({DateTime? referenceDate}) {
    final existing = _inFlightRefresh;
    if (existing != null) return existing;

    final future = _runRefresh(referenceDate: referenceDate).whenComplete(() {
      _inFlightRefresh = null;
    });
    _inFlightRefresh = future;
    return future;
  }

  Future<void> _runRefresh({DateTime? referenceDate}) async {
    await _ensureStateLoaded();
    await ShopService.instance.init();
    final now = referenceDate ?? DateTime.now();

    final results = await Future.wait<dynamic>([
      SupabaseService.getCalendarEvents(),
      SupabaseService.getStudySessions(limit: 200),
      SupabaseService.getFlashcardDecks(),
      SupabaseService.getNotebooks(),
      SavedExamsRepository.loadAll(),
      RoadmapsRepository.loadAll(),
    ]);

    final events = results[0] as List<Map<String, dynamic>>;
    final sessions = results[1] as List<Map<String, dynamic>>;
    final decks = results[2] as List<FlashcardDeck>;
    final notebooks = results[3] as List<StudyNotebook>;
    final exams = results[4] as List<SavedExamAttempt>;
    final roadmaps = results[5] as List<StudyRoadmap>;

    await ShopService.instance.reconcileStreakProtectors(sessions, referenceDate: now);

    final built = buildNotificationsFromData(
      now: now,
      events: events,
      sessions: sessions,
      weeklyGoalMinutes: SupabaseService.weeklyGoalMinutesNotifier.value,
      dailyGoalMinutes: SupabaseService.dailyGoalMinutesNotifier.value,
      decks: decks,
      notebooks: notebooks,
      exams: exams,
      roadmaps: roadmaps,
      hasConfiguredAiKey:
          (GeminiService.apiKey?.trim().isNotEmpty ?? false) ||
          GeminiService.provider == 'custom',
      hasWelcomeBonus: ShopService.instance.hasWelcomeBonus,
      protectedDates: ShopService.instance.protectedStreakDates,
    );

    final visible = built
        .where((n) => !_dismissedIds.contains(n.id))
        .map((n) => n.copyWith(isRead: _readIds.contains(n.id)))
        .toList()
      ..sort((a, b) {
        if (a.isRead != b.isRead) return a.isRead ? 1 : -1;
        return a.priority.compareTo(b.priority);
      });

    notificationsNotifier.value = visible;
  }

  /// Gera notificações determinísticas puramente a partir do snapshot atual da conta.
  @visibleForTesting
  static List<NoesisNotification> buildNotificationsFromData({
    required DateTime now,
    required List<Map<String, dynamic>> events,
    required List<Map<String, dynamic>> sessions,
    required int weeklyGoalMinutes,
    int? dailyGoalMinutes,
    required List<FlashcardDeck> decks,
    required List<StudyNotebook> notebooks,
    required List<SavedExamAttempt> exams,
    required List<StudyRoadmap> roadmaps,
    required bool hasConfiguredAiKey,
    bool hasWelcomeBonus = false,
    Set<DateTime> protectedDates = const {},
  }) {
    final list = <NoesisNotification>[];
    final todayStart = DateTime(now.year, now.month, now.day);
    final windowEnd = now.add(const Duration(hours: 48));

    // 0. Bônus de boas-vindas ao entrar pela primeira vez no Noesis (+100 Insights)
    if (hasWelcomeBonus) {
      list.add(
        const NoesisNotification(
          id: 'welcome_insights_bonus',
          title: 'Bônus de boas-vindas · +${InsightsEconomyConfig.welcomeBonus} ${InsightsEconomyConfig.currencyName}',
          message:
              'Você recebeu ${InsightsEconomyConfig.welcomeBonus} ${InsightsEconomyConfig.currencyName} pelo seu primeiro acesso ao Noesis! Use na Loja para desbloquear novos temas.',
          timeLabel: 'Boas-vindas',
          icon: Icons.celebration_rounded,
          tone: NotificationTone.amber,
          targetTab: 9,
          priority: 2,
        ),
      );
    }

    // 1. Eventos próximos no Calendário (até 48h, não concluídos)
    final upcoming = <({Map<String, dynamic> event, DateTime start})>[];
    final overdueToday = <({Map<String, dynamic> event, DateTime start})>[];

    for (final evt in events) {
      if (evt['is_completed'] == true) continue;
      final start = DateTime.tryParse((evt['start_time'] ?? '').toString());
      if (start == null) continue;
      if (!start.isBefore(now.subtract(const Duration(minutes: 15))) &&
          !start.isAfter(windowEnd)) {
        upcoming.add((event: evt, start: start));
      } else if (!start.isBefore(todayStart) && start.isBefore(now)) {
        overdueToday.add((event: evt, start: start));
      }
    }
    upcoming.sort((a, b) => a.start.compareTo(b.start));

    for (final item in upcoming.take(2)) {
      final evt = item.event;
      final start = item.start;
      final titleText = (evt['title'] ?? 'Compromisso de estudo').toString().trim();
      final category = (evt['category'] ?? 'study').toString();
      final isExam = category == 'exam';
      final dayKey = '${start.year}-${start.month}-${start.day}-${start.hour}';
      final id = 'cal_${evt['id'] ?? titleText}_$dayKey';

      list.add(
        NoesisNotification(
          id: id,
          title: isExam ? 'Prova / Marco Próximo' : 'Agenda Próxima',
          message: '$titleText · ${_formatRelativeFuture(now, start)}.',
          timeLabel: _formatTimeBadge(now, start),
          icon: isExam ? Icons.event_available_rounded : Icons.schedule_rounded,
          tone: isExam ? NotificationTone.coral : NotificationTone.amber,
          targetTab: 5,
          priority: isExam ? 1 : 2,
        ),
      );
    }

    if (upcoming.isEmpty && overdueToday.isNotEmpty) {
      final first = overdueToday.first;
      final titleText = (first.event['title'] ?? 'Bloco pendente').toString().trim();
      list.add(
        NoesisNotification(
          id: 'cal_pending_${first.event['id'] ?? titleText}_${todayStart.toIso8601String().substring(0, 10)}',
          title: 'Bloco Pendente Hoje',
          message: '"$titleText" estava previsto para ${_formatClock(first.start)} e ainda não foi concluído.',
          timeLabel: 'Hoje',
          icon: Icons.event_note_rounded,
          tone: NotificationTone.amber,
          targetTab: 5,
          priority: 4,
        ),
      );
    }

    // 2. Flashcards pendentes de revisão
    int totalCardsDue = 0;
    FlashcardDeck? topDeck;
    int topDeckDue = 0;
    for (final deck in decks) {
      final due = deck.cardsToReview(referenceDate: now).length;
      totalCardsDue += due;
      if (due > topDeckDue) {
        topDeckDue = due;
        topDeck = deck;
      }
    }
    if (totalCardsDue > 0 && topDeck != null) {
      list.add(
        NoesisNotification(
          id: 'fc_due_${totalCardsDue}_${topDeck.id}',
          title: '$totalCardsDue ${totalCardsDue == 1 ? 'card' : 'cards'} para revisar',
          message: 'Priorize "${topDeck.title}" ($topDeckDue pendente${topDeckDue == 1 ? '' : 's'}) para consolidar a memória.',
          timeLabel: 'Agora',
          icon: Icons.style_rounded,
          tone: NotificationTone.primary,
          targetTab: 2,
          priority: 3,
        ),
      );
    }

    // 3. Cadernos / anotações que devem ser revisadas
    int notesToReview = 0;
    String? firstNotebookTitle;
    for (final nb in notebooks) {
      for (final note in nb.notes) {
        if (note.shouldReview(referenceDate: now)) {
          notesToReview++;
          firstNotebookTitle ??= nb.title;
        }
      }
    }
    if (notesToReview > 0) {
      list.add(
        NoesisNotification(
          id: 'nb_review_$notesToReview',
          title: '$notesToReview ${notesToReview == 1 ? 'anotação para revisar' : 'anotações para revisar'}',
          message: firstNotebookTitle != null
              ? 'Resumo em "$firstNotebookTitle" aguardando revisão espaçada.'
              : 'Você tem resumos marcados para revisão nos Cadernos.',
          timeLabel: 'Cadernos',
          icon: Icons.menu_book_rounded,
          tone: NotificationTone.secondary,
          targetTab: 3,
          priority: 5,
        ),
      );
    }

    // 4. Meta semanal, meta diária & Streak real
    final weeklyMinutes = SupabaseService.computeCurrentWeekStudiedMinutes(sessions, referenceDate: now);
    final todayMinutes = SupabaseService.computeTodayStudiedMinutes(sessions, referenceDate: now);
    final streakDays = SupabaseService.computeCurrentStreakDays(
      sessions,
      referenceDate: now,
      protectedDates: protectedDates,
    );
    final weekId = '${todayStart.year}-${todayStart.month}-${todayStart.day - (todayStart.weekday - 1)}';
    final dayId = '${todayStart.year}-${todayStart.month}-${todayStart.day}';

    if (dailyGoalMinutes != null && dailyGoalMinutes > 0) {
      if (todayMinutes >= dailyGoalMinutes) {
        list.add(
          NoesisNotification(
            id: 'daily_goal_reached_$dayId',
            title: 'Meta Diária Atingida 🎯',
            message:
                'Você completou ${SupabaseService.formatGoalDuration(todayMinutes)} hoje (meta de ${SupabaseService.formatGoalDuration(dailyGoalMinutes)}).',
            timeLabel: 'Hoje',
            icon: Icons.today_rounded,
            tone: NotificationTone.secondary,
            targetTab: 7,
            priority: 5,
          ),
        );
      } else if (todayMinutes > 0 && todayMinutes / dailyGoalMinutes >= 0.7) {
        final remainingDaily = dailyGoalMinutes - todayMinutes;
        list.add(
          NoesisNotification(
            id: 'daily_goal_almost_$dayId',
            title: 'Reta Final da Meta Diária',
            message:
                'Faltam apenas ${SupabaseService.formatGoalDuration(remainingDaily)} para bater ${SupabaseService.formatGoalDuration(dailyGoalMinutes)} hoje.',
            timeLabel: 'Hoje',
            icon: Icons.today_rounded,
            tone: NotificationTone.primary,
            targetTab: 7,
            priority: 6,
          ),
        );
      }
    }

    if (weeklyGoalMinutes > 0 && weeklyMinutes >= weeklyGoalMinutes) {
      list.add(
        NoesisNotification(
          id: 'goal_reached_$weekId',
          title: 'Meta Semanal Atingida 🎯',
          message:
              'Você completou ${SupabaseService.formatGoalDuration(weeklyMinutes)} nesta semana (meta de ${SupabaseService.formatGoalDuration(weeklyGoalMinutes)}).',
          timeLabel: 'Esta semana',
          icon: Icons.emoji_events_rounded,
          tone: NotificationTone.secondary,
          targetTab: 0,
          priority: 6,
        ),
      );
    } else if (weeklyGoalMinutes > 0 && weeklyMinutes > 0 && weeklyMinutes / weeklyGoalMinutes >= 0.7) {
      final remaining = weeklyGoalMinutes - weeklyMinutes;
      list.add(
        NoesisNotification(
          id: 'goal_almost_$weekId',
          title: 'Reta Final da Meta Semanal',
          message:
              'Faltam apenas ${SupabaseService.formatGoalDuration(remaining)} para bater ${SupabaseService.formatGoalDuration(weeklyGoalMinutes)} na semana.',
          timeLabel: 'Esta semana',
          icon: Icons.track_changes_rounded,
          tone: NotificationTone.primary,
          targetTab: 7,
          priority: 6,
        ),
      );
    }

    if (streakDays >= 1) {
      list.add(
        NoesisNotification(
          id: 'streak_${streakDays}_${todayStart.month}_${todayStart.day}',
          title: 'Sequência Ativa · $streakDays ${streakDays == 1 ? 'dia' : 'dias'} 🔥',
          message: 'Você manteve consistência nos estudos. Continue registrando no Diário para ampliar sua sequência.',
          timeLabel: 'Hoje',
          icon: Icons.local_fire_department_rounded,
          tone: NotificationTone.secondary,
          targetTab: 7,
          priority: 7,
        ),
      );
    } else if (sessions.isEmpty || !_hasSessionToday(sessions, todayStart)) {
      list.add(
        NoesisNotification(
          id: 'study_today_${todayStart.year}-${todayStart.month}-${todayStart.day}',
          title: 'Registre seu estudo de hoje',
          message: 'Nenhuma sessão registrada hoje ainda. Abra o Diário de Estudos para iniciar sua sequência.',
          timeLabel: 'Hoje',
          icon: Icons.auto_stories_rounded,
          tone: NotificationTone.primary,
          targetTab: 7,
          priority: 8,
        ),
      );
    }

    // 5. Último simulado realizado
    if (exams.isNotEmpty) {
      final latest = exams.first;
      final pct = latest.scorePercentage.round();
      final daysAgo = now.difference(latest.createdAt).inDays;
      if (daysAgo <= 7) {
        final needsReinforcement = pct < 65;
        list.add(
          NoesisNotification(
            id: 'exam_${latest.id}_$pct',
            title: needsReinforcement
                ? 'Revisão Recomendada em Simulado'
                : 'Simulado Concluído ($pct%)',
            message: needsReinforcement
                ? 'Em "${latest.title}" você atingiu $pct%. Revise seus erros para fixar os pontos fracos.'
                : 'Último desempenho em "${latest.title}": $pct% de acertos (${latest.correctCount}/${latest.loadedCount}).',
            timeLabel: _formatPastAge(now, latest.createdAt),
            icon: Icons.quiz_rounded,
            tone: needsReinforcement ? NotificationTone.coral : NotificationTone.secondary,
            targetTab: 1,
            priority: needsReinforcement ? 4 : 9,
          ),
        );
      }
    }

    // 6. Próxima etapa em Trilha (Roadmap)
    for (final rm in roadmaps) {
      RoadmapStep? nextStep;
      for (final step in rm.steps) {
        if (step.status == RoadmapStepStatus.doing) {
          nextStep = step;
          break;
        }
        if (nextStep == null && step.status == RoadmapStepStatus.todo) {
          nextStep = step;
        }
      }
      if (nextStep != null) {
        list.add(
          NoesisNotification(
            id: 'roadmap_${rm.id}_${nextStep.id}',
            title: 'Próxima Etapa · ${rm.title}',
            message: 'Continue sua trilha em "${nextStep.title}" (${(rm.progress * 100).round()}% concluída).',
            timeLabel: 'Trilhas',
            icon: Icons.route_rounded,
            tone: NotificationTone.primary,
            targetTab: 8,
            priority: 10,
          ),
        );
        break;
      }
    }

    // 7. Chave de IA ausente
    if (!hasConfiguredAiKey) {
      list.add(
        const NoesisNotification(
          id: 'ai_key_missing',
          title: 'Chave de IA não configurada',
          message: 'Adicione sua chave de API em Configurações para habilitar o Noesis AI e geradores inteligentes.',
          timeLabel: 'Configuração',
          icon: Icons.settings_suggest_rounded,
          tone: NotificationTone.amber,
          targetTab: 6,
          priority: 5,
        ),
      );
    }

    return list;
  }

  static bool _hasSessionToday(List<Map<String, dynamic>> sessions, DateTime todayStart) {
    for (final s in sessions) {
      final raw = (s['study_date'] ?? s['created_at'] ?? '').toString();
      final dt = DateTime.tryParse(raw);
      if (dt == null) continue;
      if (dt.year == todayStart.year && dt.month == todayStart.month && dt.day == todayStart.day) {
        return true;
      }
    }
    return false;
  }

  static String _formatClock(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  static String _formatTimeBadge(DateTime now, DateTime start) {
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(start.year, start.month, start.day);
    final diffDays = startDay.difference(today).inDays;
    if (diffDays <= 0) return 'Hoje · ${_formatClock(start)}';
    if (diffDays == 1) return 'Amanhã · ${_formatClock(start)}';
    return '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')} · ${_formatClock(start)}';
  }

  static String _formatRelativeFuture(DateTime now, DateTime start) {
    final mins = start.difference(now).inMinutes;
    if (mins <= 0) return 'começa agora (${_formatClock(start)})';
    if (mins < 60) return 'em $mins min (${_formatClock(start)})';
    final hours = start.difference(now).inHours;
    if (hours < 24 && start.day == now.day) {
      return 'hoje às ${_formatClock(start)}';
    }
    return _formatTimeBadge(now, start);
  }

  static String _formatPastAge(DateTime now, DateTime past) {
    final mins = now.difference(past).inMinutes;
    if (mins < 2) return 'Agora';
    if (mins < 60) return 'Há $mins min';
    final hours = now.difference(past).inHours;
    if (hours < 24) return 'Há ${hours}h';
    final days = now.difference(past).inDays;
    if (days == 1) return 'Ontem';
    return 'Há $days dias';
  }

  /// Marca uma notificação específica como lida e persiste.
  Future<void> markAsRead(String id) async {
    _readIds.add(id);
    notificationsNotifier.value = notificationsNotifier.value
        .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
    await _persistState();
  }

  /// Marca todas as notificações atuais como lidas e persiste.
  Future<void> markAllAsRead() async {
    for (final n in notificationsNotifier.value) {
      _readIds.add(n.id);
    }
    notificationsNotifier.value = notificationsNotifier.value
        .map((n) => n.copyWith(isRead: true))
        .toList();
    await _persistState();
  }

  /// Oculta uma notificação específica e persiste o descarte.
  Future<void> dismiss(String id) async {
    _dismissedIds.add(id);
    notificationsNotifier.value =
        notificationsNotifier.value.where((n) => n.id != id).toList();
    await _persistState();
  }

  /// Oculta todas as notificações atualmente exibidas.
  Future<void> dismissAll() async {
    for (final n in notificationsNotifier.value) {
      _dismissedIds.add(n.id);
    }
    notificationsNotifier.value = const [];
    await _persistState();
  }

  /// Restaura notificações descartadas e atualiza a lista a partir dos dados reais.
  Future<void> restoreAndRefresh() async {
    _dismissedIds.clear();
    await _persistState();
    await refresh();
  }

  /// Limpa cache em memória entre testes automatizados.
  @visibleForTesting
  Future<void> resetForTesting() async {
    stop();
    _readIds.clear();
    _dismissedIds.clear();
    _stateLoaded = false;
    notificationsNotifier.value = const [];
    await _persistState();
  }
}
