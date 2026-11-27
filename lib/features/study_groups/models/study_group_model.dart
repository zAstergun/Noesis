import '../../../core/localization/noesis_l10n.dart';
import '../../flashcards/models/flashcard_model.dart';
import '../../notebooks/models/notebook_model.dart';
import '../../quizzes/data/saved_exams_repository.dart';
import '../../roadmaps/models/roadmap_model.dart';

class StudyGroupMember {
  const StudyGroupMember({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.isVip = false,
    this.isLeader = false,
    this.canInvite = false,
    this.canEdit = false,
    this.insightsScore = 0,
    this.weeklyMinutes = 0,
    required this.joinedAt,
  });

  final String userId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final bool isVip;
  final bool isLeader;
  final bool canInvite;
  final bool canEdit;
  final int insightsScore;
  final int weeklyMinutes;
  final DateTime joinedAt;

  StudyGroupMember copyWith({
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    bool? isVip,
    bool? isLeader,
    bool? canInvite,
    bool? canEdit,
    int? insightsScore,
    int? weeklyMinutes,
  }) {
    return StudyGroupMember(
      userId: userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      isVip: isVip ?? this.isVip,
      isLeader: isLeader ?? this.isLeader,
      canInvite: canInvite ?? this.canInvite,
      canEdit: canEdit ?? this.canEdit,
      insightsScore: insightsScore ?? this.insightsScore,
      weeklyMinutes: weeklyMinutes ?? this.weeklyMinutes,
      joinedAt: joinedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'username': username,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'bio': bio,
        'is_vip': isVip,
        'is_leader': isLeader,
        'can_invite': canInvite,
        'can_edit': canEdit,
        'group_insights': insightsScore,
        'weekly_minutes': weeklyMinutes,
        'joined_at': joinedAt.toIso8601String(),
      };

  factory StudyGroupMember.fromJson(Map<String, dynamic> json) {
    return StudyGroupMember(
      userId: (json['user_id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      displayName: (json['display_name'] ?? NoesisL10n.tr('Estudante')).toString(),
      avatarUrl: json['avatar_url']?.toString(),
      bio: json['bio']?.toString(),
      isVip: json['is_vip'] == true,
      isLeader: json['is_leader'] == true,
      canInvite: json['can_invite'] == true,
      canEdit: json['can_edit'] == true,
      insightsScore: (json['group_insights'] as num?)?.toInt() ?? 0,
      weeklyMinutes: (json['weekly_minutes'] as num?)?.toInt() ?? 0,
      joinedAt: DateTime.tryParse((json['joined_at'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

class StudyGroupChatMessage {
  const StudyGroupChatMessage({
    required this.id,
    required this.userId,
    required this.senderName,
    required this.senderUsername,
    this.senderAvatarUrl,
    this.isVip = false,
    this.isLeader = false,
    required this.text,
    required this.sentAt,
  });

  final String id;
  final String userId;
  final String senderName;
  final String senderUsername;
  final String? senderAvatarUrl;
  final bool isVip;
  final bool isLeader;
  final String text;
  final DateTime sentAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'sender_name': senderName,
        'sender_username': senderUsername,
        'sender_avatar_url': senderAvatarUrl,
        'is_vip': isVip,
        'is_leader': isLeader,
        'text': text,
        'sent_at': sentAt.toIso8601String(),
      };

  factory StudyGroupChatMessage.fromJson(Map<String, dynamic> json) {
    return StudyGroupChatMessage(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      senderName: (json['sender_name'] ?? NoesisL10n.tr('Estudante')).toString(),
      senderUsername: (json['sender_username'] ?? '').toString(),
      senderAvatarUrl: json['sender_avatar_url']?.toString(),
      isVip: json['is_vip'] == true,
      isLeader: json['is_leader'] == true,
      text: (json['text'] ?? '').toString(),
      sentAt: DateTime.tryParse((json['sent_at'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

class StudyGroupLogEntry {
  const StudyGroupLogEntry({
    required this.id,
    required this.userId,
    required this.memberName,
    required this.memberUsername,
    required this.subject,
    required this.topic,
    required this.durationMinutes,
    this.notes,
    required this.loggedAt,
  });

  final String id;
  final String userId;
  final String memberName;
  final String memberUsername;
  final String subject;
  final String topic;
  final int durationMinutes;
  final String? notes;
  final DateTime loggedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'member_name': memberName,
        'member_username': memberUsername,
        'subject': subject,
        'topic': topic,
        'duration_minutes': durationMinutes,
        'notes': notes,
        'logged_at': loggedAt.toIso8601String(),
      };

  factory StudyGroupLogEntry.fromJson(Map<String, dynamic> json) {
    return StudyGroupLogEntry(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      memberName: (json['member_name'] ?? NoesisL10n.tr('Estudante')).toString(),
      memberUsername: (json['member_username'] ?? '').toString(),
      subject: (json['subject'] ?? NoesisL10n.tr('Estudo')).toString(),
      topic: (json['topic'] ?? '').toString(),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
      notes: json['notes']?.toString(),
      loggedAt: DateTime.tryParse((json['logged_at'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

enum StudyGroupContentKind { notebook, deck, exam, roadmap }

class GroupCardProgress {
  const GroupCardProgress({
    this.difficulty = 'unreviewed',
    this.reviewCount = 0,
    this.lastReviewed,
  });

  final String difficulty;
  final int reviewCount;
  final DateTime? lastReviewed;

  Map<String, dynamic> toJson() => {
        'difficulty': difficulty,
        'review_count': reviewCount,
        if (lastReviewed != null) 'last_reviewed': lastReviewed!.toIso8601String(),
      };

  factory GroupCardProgress.fromJson(Map<String, dynamic> json) {
    return GroupCardProgress(
      difficulty: (json['difficulty'] ?? 'unreviewed').toString(),
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      lastReviewed: json['last_reviewed'] != null
          ? DateTime.tryParse(json['last_reviewed'].toString())
          : null,
    );
  }
}

class SharedGroupItem<T> {
  const SharedGroupItem({
    required this.shareId,
    required this.sourceId,
    required this.sharedByUserId,
    required this.sharedByName,
    required this.sharedByHandle,
    required this.sharedAt,
    required this.data,
  });

  final String shareId;
  final String sourceId;
  final String sharedByUserId;
  final String sharedByName;
  final String sharedByHandle;
  final DateTime sharedAt;
  final T data;
}

class StudyGroup {
  const StudyGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.subject,
    required this.leaderId,
    required this.inviteCode,
    this.allowMemberInvites = false,
    this.allowMemberEdit = false,
    this.rankingEnabled = true,
    this.members = const [],
    this.pendingUsernames = const [],
    this.sharedNotebooks = const [],
    this.sharedDecks = const [],
    this.sharedExams = const [],
    this.sharedRoadmaps = const [],
    this.studyLogs = const [],
    this.chatMessages = const [],
    this.flashcardProgress = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final String subject;
  final String leaderId;
  final String inviteCode;
  final bool allowMemberInvites;
  final bool allowMemberEdit;
  final bool rankingEnabled;
  final List<StudyGroupMember> members;
  final List<String> pendingUsernames;
  final List<SharedGroupItem<StudyNotebook>> sharedNotebooks;
  final List<SharedGroupItem<FlashcardDeck>> sharedDecks;
  final List<SharedGroupItem<SavedExamAttempt>> sharedExams;
  final List<SharedGroupItem<StudyRoadmap>> sharedRoadmaps;
  final List<StudyGroupLogEntry> studyLogs;
  final List<StudyGroupChatMessage> chatMessages;
  final Map<String, Map<String, GroupCardProgress>> flashcardProgress;
  final DateTime createdAt;
  final DateTime updatedAt;

  static String cardProgressKey(String deckId, String cardId) => '$deckId::$cardId';

  /// Resolve um baralho compartilhado aplicando exclusivamente o progresso do [userId] informado.
  FlashcardDeck resolvedDeckForUser(SharedGroupItem<FlashcardDeck> item, String userId) {
    final deck = item.data;
    final userProgress = flashcardProgress[userId] ?? const <String, GroupCardProgress>{};
    final resolvedCards = deck.cards.map((card) {
      final p = userProgress[cardProgressKey(deck.id, card.id)] ??
          userProgress[cardProgressKey(item.sourceId, card.id)];
      if (p == null) {
        return Flashcard(
          id: card.id,
          front: card.front,
          back: card.back,
          tags: card.tags,
          difficulty: 'unreviewed',
          reviewCount: 0,
          lastReviewed: null,
          audioUrl: card.audioUrl,
          frontAudioUrl: card.frontAudioUrl,
          backAudioUrl: card.backAudioUrl,
        );
      }
      return card.copyWith(
        difficulty: p.difficulty,
        reviewCount: p.reviewCount,
        lastReviewed: p.lastReviewed,
      );
    }).toList();
    return deck.copyWith(cards: resolvedCards);
  }

  String get inviteLink => 'https://noesis.asterdev.me/grupos/$inviteCode';

  bool isLeader(String userId) => leaderId == userId;

  StudyGroupMember? memberFor(String userId) {
    for (final m in members) {
      if (m.userId == userId) return m;
    }
    return null;
  }

  bool canUserInvite(String userId) {
    if (isLeader(userId)) return true;
    final m = memberFor(userId);
    if (m == null) return false;
    return allowMemberInvites || m.canInvite;
  }

  bool canUserEdit(String userId) {
    if (isLeader(userId)) return true;
    final m = memberFor(userId);
    if (m == null) return false;
    return allowMemberEdit || m.canEdit;
  }

  bool canUserManageSettings(String userId) => isLeader(userId);

  bool canUserRemoveContent(String userId) => isLeader(userId);

  List<StudyGroupMember> get rankedMembers {
    final sorted = List<StudyGroupMember>.from(members)
      ..sort((a, b) {
        final cmp = b.insightsScore.compareTo(a.insightsScore);
        if (cmp != 0) return cmp;
        return b.weeklyMinutes.compareTo(a.weeklyMinutes);
      });
    return sorted;
  }

  StudyGroup copyWith({
    String? name,
    String? description,
    String? subject,
    String? inviteCode,
    bool? allowMemberInvites,
    bool? allowMemberEdit,
    bool? rankingEnabled,
    List<StudyGroupMember>? members,
    List<String>? pendingUsernames,
    List<SharedGroupItem<StudyNotebook>>? sharedNotebooks,
    List<SharedGroupItem<FlashcardDeck>>? sharedDecks,
    List<SharedGroupItem<SavedExamAttempt>>? sharedExams,
    List<SharedGroupItem<StudyRoadmap>>? sharedRoadmaps,
    List<StudyGroupLogEntry>? studyLogs,
    List<StudyGroupChatMessage>? chatMessages,
    Map<String, Map<String, GroupCardProgress>>? flashcardProgress,
    DateTime? updatedAt,
  }) {
    return StudyGroup(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      subject: subject ?? this.subject,
      leaderId: leaderId,
      inviteCode: inviteCode ?? this.inviteCode,
      allowMemberInvites: allowMemberInvites ?? this.allowMemberInvites,
      allowMemberEdit: allowMemberEdit ?? this.allowMemberEdit,
      rankingEnabled: rankingEnabled ?? this.rankingEnabled,
      members: members ?? this.members,
      pendingUsernames: pendingUsernames ?? this.pendingUsernames,
      sharedNotebooks: sharedNotebooks ?? this.sharedNotebooks,
      sharedDecks: sharedDecks ?? this.sharedDecks,
      sharedExams: sharedExams ?? this.sharedExams,
      sharedRoadmaps: sharedRoadmaps ?? this.sharedRoadmaps,
      studyLogs: studyLogs ?? this.studyLogs,
      chatMessages: chatMessages ?? this.chatMessages,
      flashcardProgress: flashcardProgress ?? this.flashcardProgress,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'subject': subject,
      'leader_id': leaderId,
      'invite_code': inviteCode,
      'allow_member_invites': allowMemberInvites,
      'allow_member_edit': allowMemberEdit,
      'ranking_enabled': rankingEnabled,
      'members': members.map((m) => m.toJson()).toList(),
      'pending_usernames': pendingUsernames,
      'shared_notebooks': sharedNotebooks
          .map(
            (e) => {
              'share_id': e.shareId,
              'source_id': e.sourceId,
              'shared_by_user_id': e.sharedByUserId,
              'shared_by_name': e.sharedByName,
              'shared_by_handle': e.sharedByHandle,
              'shared_at': e.sharedAt.toIso8601String(),
              'data': e.data.toMap(),
            },
          )
          .toList(),
      'shared_decks': sharedDecks
          .map(
            (e) => {
              'share_id': e.shareId,
              'source_id': e.sourceId,
              'shared_by_user_id': e.sharedByUserId,
              'shared_by_name': e.sharedByName,
              'shared_by_handle': e.sharedByHandle,
              'shared_at': e.sharedAt.toIso8601String(),
              'data': e.data.toMap(),
            },
          )
          .toList(),
      'shared_exams': sharedExams
          .map(
            (e) => {
              'share_id': e.shareId,
              'source_id': e.sourceId,
              'shared_by_user_id': e.sharedByUserId,
              'shared_by_name': e.sharedByName,
              'shared_by_handle': e.sharedByHandle,
              'shared_at': e.sharedAt.toIso8601String(),
              'data': e.data.toJson(),
            },
          )
          .toList(),
      'shared_roadmaps': sharedRoadmaps
          .map(
            (e) => {
              'share_id': e.shareId,
              'source_id': e.sourceId,
              'shared_by_user_id': e.sharedByUserId,
              'shared_by_name': e.sharedByName,
              'shared_by_handle': e.sharedByHandle,
              'shared_at': e.sharedAt.toIso8601String(),
              'data': e.data.toJson(),
            },
          )
          .toList(),
      'study_logs': studyLogs.map((l) => l.toJson()).toList(),
      'chat_messages': chatMessages.map((m) => m.toJson()).toList(),
      'flashcard_progress': flashcardProgress.map(
        (uid, cardMap) => MapEntry(
          uid,
          cardMap.map((k, v) => MapEntry(k, v.toJson())),
        ),
      ),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory StudyGroup.fromJson(Map<String, dynamic> json) {
    T parseSharedMeta<T>(
      Map<String, dynamic> raw,
      T Function(Map<String, dynamic> payload) parser,
    ) {
      final dataMap = raw['data'] is Map
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : <String, dynamic>{};
      return parser(dataMap);
    }

    SharedGroupItem<T> parseWrapper<T>(
      Map<String, dynamic> raw,
      T Function(Map<String, dynamic> payload) parser,
    ) {
      return SharedGroupItem<T>(
        shareId: (raw['share_id'] ?? '').toString(),
        sourceId: (raw['source_id'] ?? '').toString(),
        sharedByUserId: (raw['shared_by_user_id'] ?? '').toString(),
        sharedByName: (raw['shared_by_name'] ?? NoesisL10n.tr('Estudante')).toString(),
        sharedByHandle: (raw['shared_by_handle'] ?? '').toString(),
        sharedAt: DateTime.tryParse((raw['shared_at'] ?? '').toString()) ?? DateTime.now(),
        data: parseSharedMeta(raw, parser),
      );
    }

    return StudyGroup(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? NoesisL10n.tr('Grupo de Estudos')).toString(),
      description: (json['description'] ?? '').toString(),
      subject: (json['subject'] ?? NoesisL10n.tr('Geral')).toString(),
      leaderId: (json['leader_id'] ?? '').toString(),
      inviteCode: (json['invite_code'] ?? '').toString(),
      allowMemberInvites: json['allow_member_invites'] == true,
      allowMemberEdit: json['allow_member_edit'] == true,
      rankingEnabled: json['ranking_enabled'] != false,
      members: ((json['members'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => StudyGroupMember.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      pendingUsernames: ((json['pending_usernames'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList(),
      sharedNotebooks: ((json['shared_notebooks'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (raw) => parseWrapper(
              Map<String, dynamic>.from(raw),
              (d) => StudyNotebook.fromMap(d),
            ),
          )
          .toList(),
      sharedDecks: ((json['shared_decks'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (raw) => parseWrapper(
              Map<String, dynamic>.from(raw),
              (d) => FlashcardDeck.fromMap(d),
            ),
          )
          .toList(),
      sharedExams: ((json['shared_exams'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (raw) => parseWrapper(
              Map<String, dynamic>.from(raw),
              (d) => SavedExamAttempt.fromJson(d),
            ),
          )
          .toList(),
      sharedRoadmaps: ((json['shared_roadmaps'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (raw) => parseWrapper(
              Map<String, dynamic>.from(raw),
              (d) => StudyRoadmap.fromJson(d),
            ),
          )
          .toList(),
      studyLogs: ((json['study_logs'] as List?) ?? const [])
          .whereType<Map>()
          .map((l) => StudyGroupLogEntry.fromJson(Map<String, dynamic>.from(l)))
          .toList(),
      chatMessages: ((json['chat_messages'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => StudyGroupChatMessage.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      flashcardProgress: _parseFlashcardProgress(json['flashcard_progress']),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ?? DateTime.now(),
    );
  }

  static Map<String, Map<String, GroupCardProgress>> _parseFlashcardProgress(dynamic raw) {
    if (raw is! Map) return const {};
    final parsed = <String, Map<String, GroupCardProgress>>{};
    raw.forEach((uidKey, cardsRaw) {
      if (cardsRaw is Map) {
        final perCard = <String, GroupCardProgress>{};
        cardsRaw.forEach((cardKey, val) {
          if (val is Map) {
            perCard[cardKey.toString()] =
                GroupCardProgress.fromJson(Map<String, dynamic>.from(val));
          }
        });
        parsed[uidKey.toString()] = perCard;
      }
    });
    return parsed;
  }
}
