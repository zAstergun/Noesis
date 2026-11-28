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
import 'localization/noesis_l10n.dart';
import 'noesis_crm_service.dart';
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
  static const int _maxStoredDatedIds = 300;

  static String _storageKeyForUser(String? userId) {
    final clean = userId?.trim() ?? '';
    return clean.isEmpty ? '${_stateStorageKey}_guest' : '${_stateStorageKey}_$clean';
  }

  final ValueNotifier<List<NoesisNotification>> notificationsNotifier =
      ValueNotifier<List<NoesisNotification>>(const []);

  final Set<String> _readIds = {};
  final Set<String> _dismissedIds = {};
  DateTime? _stateUpdatedAt;
  bool _stateLoaded = false;
  String? _stateUserId;
  String? _streamUserId;
  bool _started = false;
  int _mutationEpoch = 0;
  int _restoredInEpoch = 0;
  Future<void>? _inFlightStateLoad;
  Future<void>? _pendingRemoteSync;
  Future<void>? _inFlightRefresh;
  bool _refreshNeedsRerun = false;
  DateTime? _pendingReferenceDate;

  StreamSubscription<List<Map<String, dynamic>>>? _sessionsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _calendarSub;

  int get unreadCount => notificationsNotifier.value.where((n) => !n.isRead).length;

  /// Notifica o serviço quando a conta autenticada muda (login, logout ou troca de conta).
  void handleAuthUserChanged(String? newUserId) {
    final normalized =
        (newUserId != null && newUserId.trim().isNotEmpty) ? newUserId.trim() : null;
    if (_stateUserId != normalized) {
      _readIds.clear();
      _dismissedIds.clear();
      _stateUpdatedAt = null;
      _stateLoaded = false;
      _stateUserId = normalized;
      _mutationEpoch++;
      _refreshNeedsRerun = true;
      notificationsNotifier.value = const [];
    }
    if (_started && _streamUserId != normalized) {
      stop();
      start();
    }
  }

  /// Inicia observadores em tempo real nos dados do usuário.
  void start() {
    final uid = SupabaseService.currentEffectiveUserId;
    if (_started && _streamUserId != uid) {
      stop();
    }
    if (!_started) {
      _started = true;
      _streamUserId = uid;
      _sessionsSub = SupabaseService.studySessionsStream().listen((_) {
        refresh();
      });
      _calendarSub = SupabaseService.calendarEventsStream().listen((_) {
        refresh();
      });
      SupabaseService.weeklyGoalMinutesNotifier.addListener(_onGoalChanged);
      SupabaseService.dailyGoalMinutesNotifier.addListener(_onGoalChanged);
      NoesisCrmService.instance.noticesNotifier.addListener(_onGoalChanged);
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
    SupabaseService.dailyGoalMinutesNotifier.removeListener(_onGoalChanged);
    NoesisCrmService.instance.noticesNotifier.removeListener(_onGoalChanged);
    _started = false;
    _streamUserId = null;
  }

  /// Aguarda sincronizações pendentes antes de encerrar a sessão (signOut).
  Future<void> flushPendingSync() async {
    final load = _inFlightStateLoad;
    if (load != null) {
      try {
        await load;
      } catch (_) {}
    }
    final sync = _pendingRemoteSync;
    if (sync != null) {
      try {
        await sync;
      } catch (_) {}
    }
  }

  static ({Set<String> readIds, Set<String> dismissedIds, DateTime? updatedAt})?
      _parseStateMap(dynamic decoded) {
    if (decoded is! Map) return null;
    final reads = <String>{};
    final dismissed = <String>{};
    final rawReads = decoded['read_ids'];
    final rawDismissed = decoded['dismissed_ids'];
    if (rawReads is List) {
      for (final e in rawReads) {
        final s = e.toString().trim();
        if (s.isNotEmpty) reads.add(s);
      }
    }
    if (rawDismissed is List) {
      for (final e in rawDismissed) {
        final s = e.toString().trim();
        if (s.isNotEmpty) dismissed.add(s);
      }
    }
    final rawTs = decoded['updated_at']?.toString();
    final updatedAt = rawTs != null ? DateTime.tryParse(rawTs)?.toUtc() : null;
    return (readIds: reads, dismissedIds: dismissed, updatedAt: updatedAt);
  }

  Future<void> _ensureStateLoaded() async {
    final targetUid = SupabaseService.currentEffectiveUserId;
    if (_stateUserId != targetUid) {
      _readIds.clear();
      _dismissedIds.clear();
      _stateUpdatedAt = null;
      _stateLoaded = false;
      _stateUserId = targetUid;
      _mutationEpoch++;
      notificationsNotifier.value = const [];
    }
    if (_stateLoaded) return;

    final existingLoad = _inFlightStateLoad;
    if (existingLoad != null) {
      await existingLoad;
      if (_stateLoaded && _stateUserId == SupabaseService.currentEffectiveUserId) {
        return;
      }
    }

    final future = _loadStateForUser(targetUid);
    _inFlightStateLoad = future;
    try {
      await future;
    } finally {
      if (identical(_inFlightStateLoad, future)) {
        _inFlightStateLoad = null;
      }
    }
  }

  Future<void> _loadStateForUser(String? targetUid) async {
    final loadEpoch = _mutationEpoch;

    ({Set<String> readIds, Set<String> dismissedIds, DateTime? updatedAt})? localState;
    try {
      String? raw = await local_store.readSavedExamsRaw(_storageKeyForUser(targetUid));
      if ((raw == null || raw.trim().isEmpty) && targetUid == null) {
        raw = await local_store.readSavedExamsRaw(_stateStorageKey);
      }
      if (raw != null && raw.trim().isNotEmpty) {
        localState = _parseStateMap(jsonDecode(raw));
      }
    } catch (_) {}

    ({Set<String> readIds, Set<String> dismissedIds, DateTime? updatedAt})? remoteState;
    if (targetUid != null) {
      try {
        final remoteMap = await SupabaseService.loadNotificationsState();
        remoteState = _parseStateMap(remoteMap);
      } catch (_) {}
    }

    // Se o usuário acabou de logar e não tem estado salvo ainda, herda o estado de visitante local
    if (targetUid != null && localState == null && remoteState == null) {
      try {
        final guestRaw = await local_store.readSavedExamsRaw(_storageKeyForUser(null));
        if (guestRaw != null && guestRaw.trim().isNotEmpty) {
          localState = _parseStateMap(jsonDecode(guestRaw));
        }
      } catch (_) {}
    }

    // Se a conta mudou durante o carregamento assíncrono, descarta este resultado.
    if (SupabaseService.currentEffectiveUserId != targetUid) {
      return;
    }

    ({Set<String> readIds, Set<String> dismissedIds, DateTime? updatedAt})? resolved;
    bool shouldWriteLocal = false;
    bool shouldWriteRemote = false;

    if (remoteState != null && localState == null) {
      resolved = remoteState;
      shouldWriteLocal = true;
    } else if (localState != null && remoteState == null) {
      resolved = localState;
      shouldWriteRemote = targetUid != null;
    } else if (localState != null && remoteState != null) {
      final mergedReads = <String>{...remoteState.readIds, ...localState.readIds};
      final localTs = localState.updatedAt;
      final remoteTs = remoteState.updatedAt;
      final localIsNewer = localTs != null &&
          (remoteTs == null || localTs.isAfter(remoteTs));
      final mergedDismissed = <String>{...remoteState.dismissedIds, ...localState.dismissedIds};
      resolved = (
        readIds: mergedReads,
        dismissedIds: mergedDismissed,
        updatedAt: localIsNewer ? localTs : remoteTs,
      );
      if (mergedReads.length != remoteState.readIds.length ||
          mergedDismissed.length != remoteState.dismissedIds.length ||
          localIsNewer) {
        shouldWriteRemote = targetUid != null;
      }
      if (mergedReads.length != localState.readIds.length ||
          mergedDismissed.length != localState.dismissedIds.length ||
          !localIsNewer) {
        shouldWriteLocal = true;
      }
    }

    if (resolved != null) {
      if (_mutationEpoch == loadEpoch) {
        _readIds
          ..clear()
          ..addAll(resolved.readIds);
        _dismissedIds
          ..clear()
          ..addAll(resolved.dismissedIds);
        _stateUpdatedAt = resolved.updatedAt;
      } else {
        _readIds.addAll(resolved.readIds);
        if (_restoredInEpoch != _mutationEpoch) {
          _dismissedIds.addAll(resolved.dismissedIds);
        }
        shouldWriteRemote = true;
        shouldWriteLocal = true;
      }
    }

    _stateUserId = targetUid;
    _stateLoaded = true;

    if (shouldWriteRemote) {
      await _persistState();
    } else if (shouldWriteLocal && resolved != null) {
      try {
        await local_store.writeSavedExamsRaw(
          _storageKeyForUser(targetUid),
          jsonEncode({
            'read_ids': _readIds.toList(),
            'dismissed_ids': _dismissedIds.toList(),
            if (_stateUpdatedAt != null)
              'updated_at': _stateUpdatedAt!.toIso8601String(),
          }),
        );
      } catch (_) {}
    }
  }

  static void _trimIdSet(Set<String> ids) {
    if (ids.length <= _maxStoredDatedIds + 50) return;
    final datedPattern = RegExp(r'\d{4}-\d{1,2}-\d{1,2}|_\d{1,2}_\d{1,2}$');
    final permanent = <String>[];
    final dated = <String>[];
    for (final id in ids) {
      if (datedPattern.hasMatch(id)) {
        dated.add(id);
      } else {
        permanent.add(id);
      }
    }
    if (dated.length > _maxStoredDatedIds) {
      dated.removeRange(0, dated.length - _maxStoredDatedIds);
    }
    ids
      ..clear()
      ..addAll(permanent)
      ..addAll(dated);
  }

  Future<void> _persistState() {
    final targetUid = SupabaseService.currentEffectiveUserId;
    _stateUserId = targetUid;
    _stateLoaded = true;
    _trimIdSet(_readIds);
    _trimIdSet(_dismissedIds);
    _stateUpdatedAt = DateTime.now().toUtc();
    final payload = <String, dynamic>{
      'read_ids': _readIds.toList(),
      'dismissed_ids': _dismissedIds.toList(),
      'updated_at': _stateUpdatedAt!.toIso8601String(),
    };
    final encoded = jsonEncode(payload);

    final previous = _pendingRemoteSync ?? Future<void>.value();
    final next = previous.catchError((_) {}).then((_) async {
      try {
        await local_store.writeSavedExamsRaw(
          _storageKeyForUser(targetUid),
          encoded,
        );
      } catch (_) {}
      if (targetUid != null &&
          SupabaseService.currentEffectiveUserId == targetUid) {
        await SupabaseService.saveNotificationsState(payload);
      }
    });
    late final Future<void> tracked;
    tracked = next.whenComplete(() {
      if (identical(_pendingRemoteSync, tracked)) {
        _pendingRemoteSync = null;
      }
    });
    _pendingRemoteSync = tracked;
    return tracked;
  }

  /// Recalcula todas as notificações a partir dos dados reais atuais.
  Future<void> refresh({DateTime? referenceDate}) {
    final existing = _inFlightRefresh;
    if (existing != null) {
      _refreshNeedsRerun = true;
      if (referenceDate != null) {
        _pendingReferenceDate = referenceDate;
      }
      return existing;
    }

    final future = _runRefreshLoop(referenceDate: referenceDate).whenComplete(() {
      _inFlightRefresh = null;
    });
    _inFlightRefresh = future;
    return future;
  }

  Future<void> _runRefreshLoop({DateTime? referenceDate}) async {
    DateTime? nextRef = referenceDate;
    do {
      _refreshNeedsRerun = false;
      await _runRefresh(referenceDate: nextRef);
      nextRef = _pendingReferenceDate;
      _pendingReferenceDate = null;
    } while (_refreshNeedsRerun);
  }

  Future<void> _runRefresh({DateTime? referenceDate}) async {
    final uidAtStart = SupabaseService.currentEffectiveUserId;
    if (_started && _streamUserId != uidAtStart) {
      stop();
      _started = true;
      _streamUserId = uidAtStart;
      _sessionsSub = SupabaseService.studySessionsStream().listen((_) {
        refresh();
      });
      _calendarSub = SupabaseService.calendarEventsStream().listen((_) {
        refresh();
      });
      SupabaseService.weeklyGoalMinutesNotifier.addListener(_onGoalChanged);
      SupabaseService.dailyGoalMinutesNotifier.addListener(_onGoalChanged);
    }

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

    if (SupabaseService.currentEffectiveUserId != uidAtStart) {
      _refreshNeedsRerun = true;
      return;
    }

    final events = results[0] as List<Map<String, dynamic>>;
    final sessions = results[1] as List<Map<String, dynamic>>;
    final decks = results[2] as List<FlashcardDeck>;
    final notebooks = results[3] as List<StudyNotebook>;
    final exams = results[4] as List<SavedExamAttempt>;
    final roadmaps = results[5] as List<StudyRoadmap>;

    final extraActiveDates = <DateTime>{
      ...SupabaseService.recordedConsistencyDates,
      ...ShopService.instance.studyActivityDates,
    };

    await ShopService.instance.reconcileStreakProtectors(
      sessions,
      referenceDate: now,
      extraActiveDates: extraActiveDates,
    );

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
      isEmailConfirmed: SupabaseService.isCurrentUserEmailConfirmed,
      protectedDates: ShopService.instance.protectedStreakDates,
      extraActiveDates: extraActiveDates,
    );

    final crmNotices = NoesisCrmService.instance.noticesNotifier.value.map((n) {
      final NotificationTone tone;
      final IconData icon;
      switch (n.tone) {
        case 'urgent':
          tone = NotificationTone.coral;
          icon = Icons.campaign_rounded;
        case 'warning':
          tone = NotificationTone.amber;
          icon = Icons.warning_amber_rounded;
        case 'promo':
          tone = NotificationTone.amber;
          icon = Icons.card_giftcard_rounded;
        default:
          tone = NotificationTone.primary;
          icon = Icons.notifications_active_rounded;
      }
      return NoesisNotification(
        id: 'crm_notice_${n.id}',
        title: n.title,
        message: n.message,
        timeLabel: NoesisL10n.tr('Equipe Aster'),
        icon: icon,
        tone: tone,
        targetTab: 0,
        priority: n.tone == 'urgent' ? -2 : 0,
      );
    }).toList();

    final visible = [...crmNotices, ...built]
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
    bool isEmailConfirmed = true,
    Set<DateTime> protectedDates = const {},
    Set<DateTime> extraActiveDates = const {},
  }) {
    final list = <NoesisNotification>[];
    final todayStart = DateTime(now.year, now.month, now.day);
    final windowEnd = now.add(const Duration(hours: 48));

    // -1. Confirmação de e-mail pendente
    if (!isEmailConfirmed) {
      list.add(
        NoesisNotification(
          id: 'email_verification_pending',
          title: NoesisL10n.tr('Confirme seu e-mail'),
          message: NoesisL10n.tr(
            'Verifique sua caixa de entrada e clique no link de validação para proteger sua conta Aster e liberar alterações de @usuário.',
          ),
          timeLabel: NoesisL10n.tr('Conta'),
          icon: Icons.mark_email_unread_rounded,
          tone: NotificationTone.coral,
          targetTab: 6,
          priority: 1,
        ),
      );
    }

    // 0. Bônus de boas-vindas ao entrar pela primeira vez no Noesis (+100 Insights)
    if (hasWelcomeBonus) {
      list.add(
        NoesisNotification(
          id: 'welcome_insights_bonus',
          title: NoesisL10n.tr(
            'Bônus de boas-vindas · +{amount} {currency}',
            {
              'amount': InsightsEconomyConfig.welcomeBonus,
              'currency': InsightsEconomyConfig.currencyName,
            },
          ),
          message: NoesisL10n.tr(
            'Você recebeu {amount} {currency} pelo seu primeiro acesso ao Noesis! Use na Loja para desbloquear novos temas.',
            {
              'amount': InsightsEconomyConfig.welcomeBonus,
              'currency': InsightsEconomyConfig.currencyName,
            },
          ),
          timeLabel: NoesisL10n.tr('Boas-vindas'),
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
      final rawStart = DateTime.tryParse((evt['start_time'] ?? '').toString());
      if (rawStart == null) continue;
      final start = rawStart.toLocal();
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
      final titleText = (evt['title'] ?? NoesisL10n.tr('Compromisso de estudo')).toString().trim();
      final category = (evt['category'] ?? 'study').toString();
      final isExam = category == 'exam';
      final dayKey = '${start.year}-${start.month}-${start.day}-${start.hour}';
      final id = 'cal_${evt['id'] ?? titleText}_$dayKey';

      list.add(
        NoesisNotification(
          id: id,
          title: isExam ? NoesisL10n.tr('Prova / Marco Próximo') : NoesisL10n.tr('Agenda Próxima'),
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
      final titleText = (first.event['title'] ?? NoesisL10n.tr('Bloco pendente')).toString().trim();
      list.add(
        NoesisNotification(
          id: 'cal_pending_${first.event['id'] ?? titleText}_${todayStart.toIso8601String().substring(0, 10)}',
          title: NoesisL10n.tr('Bloco Pendente Hoje'),
          message: NoesisL10n.tr(
            '"{title}" estava previsto para {time} e ainda não foi concluído.',
            {'title': titleText, 'time': _formatClock(first.start)},
          ),
          timeLabel: NoesisL10n.tr('Hoje'),
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
          title: totalCardsDue == 1
              ? NoesisL10n.tr('{count} card para revisar', {'count': totalCardsDue})
              : NoesisL10n.tr('{count} cards para revisar', {'count': totalCardsDue}),
          message: topDeckDue == 1
              ? NoesisL10n.tr(
                  'Priorize "{deck}" ({count} pendente) para consolidar a memória.',
                  {'deck': topDeck.title, 'count': topDeckDue},
                )
              : NoesisL10n.tr(
                  'Priorize "{deck}" ({count} pendentes) para consolidar a memória.',
                  {'deck': topDeck.title, 'count': topDeckDue},
                ),
          timeLabel: NoesisL10n.tr('Agora'),
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
          title: notesToReview == 1
              ? NoesisL10n.tr('{count} anotação para revisar', {'count': notesToReview})
              : NoesisL10n.tr('{count} anotações para revisar', {'count': notesToReview}),
          message: firstNotebookTitle != null
              ? NoesisL10n.tr(
                  'Resumo em "{notebook}" aguardando revisão espaçada.',
                  {'notebook': firstNotebookTitle},
                )
              : NoesisL10n.tr('Você tem resumos marcados para revisão nos Cadernos.'),
          timeLabel: NoesisL10n.tr('Cadernos'),
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
      extraActiveDates: extraActiveDates,
    );
    final monday = todayStart.subtract(Duration(days: todayStart.weekday - 1));
    final weekId = '${monday.year}-${monday.month}-${monday.day}';
    final dayId = '${todayStart.year}-${todayStart.month}-${todayStart.day}';

    if (dailyGoalMinutes != null && dailyGoalMinutes > 0) {
      if (todayMinutes >= dailyGoalMinutes) {
        list.add(
          NoesisNotification(
            id: 'daily_goal_reached_$dayId',
            title: NoesisL10n.tr('Meta Diária Atingida 🎯'),
            message: NoesisL10n.tr(
              'Você completou {completed} hoje (meta de {goal}).',
              {
                'completed': SupabaseService.formatGoalDuration(todayMinutes),
                'goal': SupabaseService.formatGoalDuration(dailyGoalMinutes),
              },
            ),
            timeLabel: NoesisL10n.tr('Hoje'),
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
            title: NoesisL10n.tr('Reta Final da Meta Diária'),
            message: NoesisL10n.tr(
              'Faltam apenas {remaining} para bater {goal} hoje.',
              {
                'remaining': SupabaseService.formatGoalDuration(remainingDaily),
                'goal': SupabaseService.formatGoalDuration(dailyGoalMinutes),
              },
            ),
            timeLabel: NoesisL10n.tr('Hoje'),
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
          title: NoesisL10n.tr('Meta Semanal Atingida 🎯'),
          message: NoesisL10n.tr(
            'Você completou {completed} nesta semana (meta de {goal}).',
            {
              'completed': SupabaseService.formatGoalDuration(weeklyMinutes),
              'goal': SupabaseService.formatGoalDuration(weeklyGoalMinutes),
            },
          ),
          timeLabel: NoesisL10n.tr('Esta semana'),
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
          title: NoesisL10n.tr('Reta Final da Meta Semanal'),
          message: NoesisL10n.tr(
            'Faltam apenas {remaining} para bater {goal} na semana.',
            {
              'remaining': SupabaseService.formatGoalDuration(remaining),
              'goal': SupabaseService.formatGoalDuration(weeklyGoalMinutes),
            },
          ),
          timeLabel: NoesisL10n.tr('Esta semana'),
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
          title: streakDays == 1
              ? NoesisL10n.tr('Sequência Ativa · {days} dia 🔥', {'days': streakDays})
              : NoesisL10n.tr('Sequência Ativa · {days} dias 🔥', {'days': streakDays}),
          message: NoesisL10n.tr('Você manteve consistência nos estudos. Continue registrando no Diário para ampliar sua sequência.'),
          timeLabel: NoesisL10n.tr('Hoje'),
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
          title: NoesisL10n.tr('Registre seu estudo de hoje'),
          message: NoesisL10n.tr('Nenhuma sessão registrada hoje ainda. Abra o Diário de Estudos para iniciar sua sequência.'),
          timeLabel: NoesisL10n.tr('Hoje'),
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
                ? NoesisL10n.tr('Revisão Recomendada em Simulado')
                : NoesisL10n.tr('Simulado Concluído ({pct}%)', {'pct': pct}),
            message: needsReinforcement
                ? NoesisL10n.tr(
                    'Em "{title}" você atingiu {pct}%. Revise seus erros para fixar os pontos fracos.',
                    {'title': latest.title, 'pct': pct},
                  )
                : NoesisL10n.tr(
                    'Último desempenho em "{title}": {pct}% de acertos ({correct}/{total}).',
                    {
                      'title': latest.title,
                      'pct': pct,
                      'correct': latest.correctCount,
                      'total': latest.loadedCount,
                    },
                  ),
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
            title: NoesisL10n.tr('Próxima Etapa · {title}', {'title': rm.title}),
            message: NoesisL10n.tr(
              'Continue sua trilha em "{step}" ({pct}% concluída).',
              {'step': nextStep.title, 'pct': (rm.progress * 100).round()},
            ),
            timeLabel: NoesisL10n.tr('Trilhas'),
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
        NoesisNotification(
          id: 'ai_key_missing',
          title: NoesisL10n.tr('Chave de IA não configurada'),
          message: NoesisL10n.tr('Adicione sua chave de API em Configurações para habilitar o Noesis AI e geradores inteligentes.'),
          timeLabel: NoesisL10n.tr('Configuração'),
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
      final dt = DateTime.tryParse(raw)?.toLocal();
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
    if (diffDays <= 0) return NoesisL10n.tr('Hoje · {time}', {'time': _formatClock(start)});
    if (diffDays == 1) return NoesisL10n.tr('Amanhã · {time}', {'time': _formatClock(start)});
    return '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')} · ${_formatClock(start)}';
  }

  static String _formatRelativeFuture(DateTime now, DateTime start) {
    final mins = start.difference(now).inMinutes;
    if (mins <= 0) return NoesisL10n.tr('começa agora ({time})', {'time': _formatClock(start)});
    if (mins < 60) return NoesisL10n.tr('em {mins} min ({time})', {'mins': mins, 'time': _formatClock(start)});
    final hours = start.difference(now).inHours;
    if (hours < 24 && start.day == now.day) {
      return NoesisL10n.tr('hoje às {time}', {'time': _formatClock(start)});
    }
    return _formatTimeBadge(now, start);
  }

  static String _formatPastAge(DateTime now, DateTime past) {
    final mins = now.difference(past).inMinutes;
    if (mins < 2) return NoesisL10n.tr('Agora');
    if (mins < 60) return NoesisL10n.tr('Há {mins} min', {'mins': mins});
    final hours = now.difference(past).inHours;
    if (hours < 24) return NoesisL10n.tr('Há {hours}h', {'hours': hours});
    final days = now.difference(past).inDays;
    if (days == 1) return NoesisL10n.tr('Ontem');
    return NoesisL10n.tr('Há {days} dias', {'days': days});
  }

  /// Marca uma notificação específica como lida e persiste.
  Future<void> markAsRead(String id) async {
    _mutationEpoch++;
    _readIds.add(id);
    notificationsNotifier.value = notificationsNotifier.value
        .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
    if (!_stateLoaded || _stateUserId != SupabaseService.currentEffectiveUserId) {
      await _ensureStateLoaded();
      _readIds.add(id);
    }
    await _persistState();
  }

  /// Marca todas as notificações atuais como lidas e persiste.
  Future<void> markAllAsRead() async {
    _mutationEpoch++;
    final currentIds = notificationsNotifier.value.map((n) => n.id).toList();
    _readIds.addAll(currentIds);
    notificationsNotifier.value = notificationsNotifier.value
        .map((n) => n.copyWith(isRead: true))
        .toList();
    if (!_stateLoaded || _stateUserId != SupabaseService.currentEffectiveUserId) {
      await _ensureStateLoaded();
      _readIds.addAll(currentIds);
    }
    await _persistState();
  }

  /// Oculta uma notificação específica e persiste o descarte.
  Future<void> dismiss(String id) async {
    _mutationEpoch++;
    _dismissedIds.add(id);
    notificationsNotifier.value =
        notificationsNotifier.value.where((n) => n.id != id).toList();
    if (!_stateLoaded || _stateUserId != SupabaseService.currentEffectiveUserId) {
      await _ensureStateLoaded();
      _dismissedIds.add(id);
    }
    await _persistState();
  }

  /// Oculta todas as notificações atualmente exibidas.
  Future<void> dismissAll() async {
    _mutationEpoch++;
    final currentIds = notificationsNotifier.value.map((n) => n.id).toList();
    _dismissedIds.addAll(currentIds);
    notificationsNotifier.value = const [];
    if (!_stateLoaded || _stateUserId != SupabaseService.currentEffectiveUserId) {
      await _ensureStateLoaded();
      _dismissedIds.addAll(currentIds);
    }
    await _persistState();
  }

  /// Restaura notificações descartadas e atualiza a lista a partir dos dados reais.
  Future<void> restoreAndRefresh() async {
    _mutationEpoch++;
    _restoredInEpoch = _mutationEpoch;
    if (!_stateLoaded || _stateUserId != SupabaseService.currentEffectiveUserId) {
      await _ensureStateLoaded();
    }
    _dismissedIds.clear();
    await _persistState();
    await refresh();
  }

  /// Limpa cache em memória entre testes automatizados.
  @visibleForTesting
  Future<void> resetForTesting() async {
    stop();
    final prevUid = _stateUserId;
    final currentUid = SupabaseService.currentEffectiveUserId;
    _readIds.clear();
    _dismissedIds.clear();
    _stateUpdatedAt = null;
    _stateLoaded = false;
    _stateUserId = null;
    _mutationEpoch++;
    _restoredInEpoch = 0;
    _refreshNeedsRerun = false;
    _pendingReferenceDate = null;
    _pendingRemoteSync = null;
    _inFlightStateLoad = null;
    notificationsNotifier.value = const [];
    const emptyPayload = '{"read_ids":[],"dismissed_ids":[]}';
    for (final key in {
      _stateStorageKey,
      _storageKeyForUser(null),
      if (prevUid != null) _storageKeyForUser(prevUid),
      if (currentUid != null) _storageKeyForUser(currentUid),
    }) {
      try {
        await local_store.writeSavedExamsRaw(key, emptyPayload);
      } catch (_) {}
    }
  }
}
