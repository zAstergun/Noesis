import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../../core/shop_service.dart';
import '../../../core/supabase_service.dart';
import '../../flashcards/models/flashcard_model.dart';
import '../../notebooks/models/notebook_model.dart';
import '../../quizzes/data/saved_exams_repository.dart';
import '../../quizzes/data/saved_exams_store_stub.dart'
    if (dart.library.io) '../../quizzes/data/saved_exams_store_io.dart'
    if (dart.library.js_interop) '../../quizzes/data/saved_exams_store_web.dart' as local_store;
import '../../roadmaps/data/roadmaps_repository.dart';
import '../../roadmaps/models/roadmap_model.dart';
import '../models/study_group_model.dart';

class StudyGroupActionResult {
  const StudyGroupActionResult({
    required this.ok,
    this.message,
    this.error,
    this.group,
    this.earnedInsights = 0,
  });

  final bool ok;
  final String? message;
  final String? error;
  final StudyGroup? group;
  final int earnedInsights;
}

class AttachablePersonalContent {
  const AttachablePersonalContent({
    required this.ownerUserId,
    this.notebooks = const [],
    this.decks = const [],
    this.exams = const [],
    this.roadmaps = const [],
  });

  final String ownerUserId;
  final List<StudyNotebook> notebooks;
  final List<FlashcardDeck> decks;
  final List<SavedExamAttempt> exams;
  final List<StudyRoadmap> roadmaps;
}

/// Serviço central de **Grupos de Estudo** do Noesis.
///
/// Suporta criação, convites por `@usuario` ou link de convite, conteúdos compartilhados
/// (cadernos, diário de estudo por membro, flashcards, simulados e trilhas),
/// anexo estritamente isolado por conta, ranking interno de Insights e configurações do líder.
class StudyGroupsService {
  StudyGroupsService._();
  static final StudyGroupsService instance = StudyGroupsService._();

  static const String _storageKey = 'noesis_study_groups_v1';

  final ValueNotifier<List<StudyGroup>> groupsNotifier =
      ValueNotifier<List<StudyGroup>>(const []);

  final List<StudyGroup> _groups = [];
  bool _loaded = false;
  bool _listeningProfile = false;

  void _ensureProfileListener() {
    if (_listeningProfile) return;
    _listeningProfile = true;
    SupabaseService.userProfileNotifier.addListener(_onUserProfileChanged);
  }

  void _onUserProfileChanged() {
    if (!_loaded) return;
    _syncCurrentMemberMetrics();
    _publish();
  }

  /// Identificador do usuário ativo (Supabase ou local).
  static String get currentUserId =>
      SupabaseService.currentUser?.id ?? 'local_user';

  static String get currentUserHandle {
    final profile = SupabaseService.userProfileNotifier.value;
    final raw = (profile?['channel'] ?? '').toString();
    final clean = SupabaseService.sanitizeUsername(raw);
    return clean.isEmpty ? 'estudante' : clean;
  }

  static String get currentUserDisplayName {
    final profile = SupabaseService.userProfileNotifier.value;
    final full = (profile?['full_name'] ?? '').toString().trim();
    if (full.isNotEmpty) return full;
    final email = SupabaseService.currentUser?.email ?? '';
    if (email.contains('@')) return email.split('@').first;
    return 'Estudante';
  }

  Future<void> init({bool force = false}) async {
    _ensureProfileListener();
    if (_loaded && !force) return;
    _loaded = true;
    _groups.clear();

    try {
      final raw = await local_store.readSavedExamsRaw(_storageKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              _groups.add(StudyGroup.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
      }
    } catch (_) {}

    if (SupabaseService.isAuthenticated) {
      try {
        final rows = await SupabaseService.client
            .from('noesis_study_groups')
            .select()
            .order('updated_at', ascending: false);
        for (final row in rows) {
          final payloadRaw = row['payload'];
          if (payloadRaw is Map) {
            final parsed = StudyGroup.fromJson(Map<String, dynamic>.from(payloadRaw));
            final idx = _groups.indexWhere((g) => g.id == parsed.id);
            if (idx == -1) {
              _groups.add(parsed);
            } else if (parsed.updatedAt.isAfter(_groups[idx].updatedAt)) {
              _groups[idx] = parsed;
            }
          }
        }
      } catch (_) {}
    }

    _syncCurrentMemberMetrics();
    _publish();
  }

  void _syncCurrentMemberMetrics() {
    final uid = currentUserId;
    final myHandle = currentUserHandle;
    final myName = currentUserDisplayName;
    final isVip = SupabaseService.isCurrentUserVip;
    final profile = SupabaseService.userProfileNotifier.value;
    final myAvatar = profile?['avatar_url']?.toString();
    final myBio = profile?['bio']?.toString();

    for (int i = 0; i < _groups.length; i++) {
      final g = _groups[i];
      final idx = g.members.indexWhere((m) => m.userId == uid);
      if (idx != -1) {
        final updatedMembers = List<StudyGroupMember>.from(g.members);
        updatedMembers[idx] = updatedMembers[idx].copyWith(
          username: myHandle,
          displayName: myName,
          avatarUrl: myAvatar,
          bio: myBio,
          isVip: isVip,
        );
        _groups[i] = g.copyWith(members: updatedMembers);
      }
    }
  }

  void _publish() {
    final sorted = List<StudyGroup>.from(_groups)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    groupsNotifier.value = List<StudyGroup>.unmodifiable(sorted);
  }

  Future<void> _persist({StudyGroup? changedGroup}) async {
    try {
      await local_store.writeSavedExamsRaw(
        _storageKey,
        jsonEncode(_groups.map((g) => g.toJson()).toList()),
      );
    } catch (_) {}

    if (changedGroup != null && SupabaseService.currentUser != null) {
      try {
        await SupabaseService.client.from('noesis_study_groups').upsert({
          'id': changedGroup.id,
          'leader_id': changedGroup.leaderId,
          'invite_code': changedGroup.inviteCode,
          'payload': changedGroup.toJson(),
          'updated_at': changedGroup.updatedAt.toIso8601String(),
        });
      } catch (_) {}
    }
  }

  /// Extrai código limpo de um código direto (`NOE-ABC123`) ou link (`https://noesis.asterdev.me/grupos/NOE-ABC123`).
  static String parseInviteCode(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last.trim().toUpperCase();
    }
    return trimmed.replaceFirst(RegExp(r'^.*/'), '').trim().toUpperCase();
  }

  static String _generateInviteCode(int seedOffset) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = math.Random(DateTime.now().microsecondsSinceEpoch ^ seedOffset);
    final code = List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
    return 'NOE-$code';
  }

  Future<StudyGroupActionResult> createGroup({
    required String name,
    String description = '',
    String subject = 'Geral',
    String? actorUserId,
    String? actorUsername,
    String? actorDisplayName,
  }) async {
    await init();
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      return const StudyGroupActionResult(
        ok: false,
        error: 'Informe um nome para o grupo de estudos.',
      );
    }

    final now = DateTime.now();
    final uid = actorUserId ?? currentUserId;
    final leader = StudyGroupMember(
      userId: uid,
      username: SupabaseService.sanitizeUsername(actorUsername ?? currentUserHandle),
      displayName: (actorDisplayName ?? currentUserDisplayName).trim(),
      avatarUrl: SupabaseService.userProfileNotifier.value?['avatar_url']?.toString(),
      bio: SupabaseService.userProfileNotifier.value?['bio']?.toString(),
      isVip: SupabaseService.isCurrentUserVip,
      isLeader: true,
      canInvite: true,
      canEdit: true,
      insightsScore: 0,
      weeklyMinutes: 0,
      joinedAt: now,
    );

    final group = StudyGroup(
      id: 'grp-${now.microsecondsSinceEpoch}-${_groups.length}',
      name: cleanName,
      description: description.trim(),
      subject: subject.trim().isEmpty ? 'Geral' : subject.trim(),
      leaderId: uid,
      inviteCode: _generateInviteCode(_groups.length),
      members: [leader],
      createdAt: now,
      updatedAt: now,
    );

    _groups.insert(0, group);
    _publish();
    await _persist(changedGroup: group);
    return StudyGroupActionResult(
      ok: true,
      message: 'Grupo "${group.name}" criado!',
      group: group,
    );
  }

  /// Atualiza configurações e permissões do grupo — exclusivo para o líder criador.
  Future<StudyGroupActionResult> updateGroupSettings({
    required String groupId,
    String? actorUserId,
    bool? allowMemberInvites,
    bool? allowMemberEdit,
    bool? rankingEnabled,
    String? name,
    String? description,
  }) async {
    await init();
    final uid = actorUserId ?? currentUserId;
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx == -1) {
      return const StudyGroupActionResult(ok: false, error: 'Grupo não encontrado.');
    }
    final group = _groups[idx];
    if (!group.canUserManageSettings(uid)) {
      return const StudyGroupActionResult(
        ok: false,
        error: 'Apenas o criador/líder do grupo pode alterar estas configurações.',
      );
    }

    final updated = group.copyWith(
      name: (name != null && name.trim().isNotEmpty) ? name.trim() : group.name,
      description: description?.trim() ?? group.description,
      allowMemberInvites: allowMemberInvites ?? group.allowMemberInvites,
      allowMemberEdit: allowMemberEdit ?? group.allowMemberEdit,
      rankingEnabled: rankingEnabled ?? group.rankingEnabled,
      updatedAt: DateTime.now(),
    );
    _groups[idx] = updated;
    _publish();
    await _persist(changedGroup: updated);
    return StudyGroupActionResult(
      ok: true,
      message: 'Configurações do grupo atualizadas.',
      group: updated,
    );
  }

  /// Concede ou revoga permissões individuais de convite/edição a um membro — exclusivo do líder.
  Future<StudyGroupActionResult> setMemberPermissions({
    required String groupId,
    required String targetUserId,
    String? actorUserId,
    bool? canInvite,
    bool? canEdit,
  }) async {
    await init();
    final uid = actorUserId ?? currentUserId;
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx == -1) {
      return const StudyGroupActionResult(ok: false, error: 'Grupo não encontrado.');
    }
    final group = _groups[idx];
    if (!group.canUserManageSettings(uid)) {
      return const StudyGroupActionResult(
        ok: false,
        error: 'Apenas o líder pode alterar permissões de membros.',
      );
    }
    final mIdx = group.members.indexWhere((m) => m.userId == targetUserId);
    if (mIdx == -1) {
      return const StudyGroupActionResult(ok: false, error: 'Membro não encontrado.');
    }
    final updatedMembers = List<StudyGroupMember>.from(group.members);
    updatedMembers[mIdx] = updatedMembers[mIdx].copyWith(
      canInvite: canInvite,
      canEdit: canEdit,
    );
    final updated = group.copyWith(
      members: updatedMembers,
      updatedAt: DateTime.now(),
    );
    _groups[idx] = updated;
    _publish();
    await _persist(changedGroup: updated);
    return StudyGroupActionResult(ok: true, group: updated);
  }

  /// Convida alguém pelo `@usuario`. Valida permissão de convite do ator.
  Future<StudyGroupActionResult> inviteMemberByUsername({
    required String groupId,
    required String username,
    String? actorUserId,
    String? displayNameHint,
    int? initialInsightsScore,
  }) async {
    await init();
    final uid = actorUserId ?? currentUserId;
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx == -1) {
      return const StudyGroupActionResult(ok: false, error: 'Grupo não encontrado.');
    }
    final group = _groups[idx];
    if (!group.canUserInvite(uid)) {
      return const StudyGroupActionResult(
        ok: false,
        error: 'Você não tem permissão para convidar neste grupo.',
      );
    }

    final cleanHandle = SupabaseService.sanitizeUsername(username);
    if (cleanHandle.length < 2) {
      return const StudyGroupActionResult(
        ok: false,
        error: 'Informe um @usuario válido (mínimo 2 caracteres).',
      );
    }

    if (group.members.any((m) => m.username.toLowerCase() == cleanHandle)) {
      return StudyGroupActionResult(
        ok: false,
        error: '@$cleanHandle já participa deste grupo.',
      );
    }

    String resolvedId = 'invited_$cleanHandle';
    String resolvedName = (displayNameHint ?? '').trim().isNotEmpty
        ? displayNameHint!.trim()
        : '@$cleanHandle';
    String? avatarUrl;
    String? bio;
    bool isVip = false;

    if (SupabaseService.isAuthenticated) {
      try {
        final found = await SupabaseService.client
            .from('profiles')
            .select('id, full_name, channel, avatar_url, bio, is_vip')
            .eq('channel', cleanHandle)
            .maybeSingle();
        if (found != null) {
          resolvedId = (found['id'] ?? resolvedId).toString();
          final full = (found['full_name'] ?? '').toString().trim();
          if (full.isNotEmpty) resolvedName = full;
          avatarUrl = found['avatar_url']?.toString();
          bio = found['bio']?.toString();
          isVip = found['is_vip'] == true;
        }
      } catch (_) {}
    }

    final newMember = StudyGroupMember(
      userId: resolvedId,
      username: cleanHandle,
      displayName: resolvedName,
      avatarUrl: avatarUrl,
      bio: bio,
      isVip: isVip,
      insightsScore: initialInsightsScore ?? 0,
      joinedAt: DateTime.now(),
    );

    final updated = group.copyWith(
      members: [...group.members, newMember],
      pendingUsernames: [
        ...group.pendingUsernames.where((u) => u != cleanHandle),
        cleanHandle,
      ],
      updatedAt: DateTime.now(),
    );
    _groups[idx] = updated;
    _publish();
    await _persist(changedGroup: updated);
    return StudyGroupActionResult(
      ok: true,
      message: '@$cleanHandle adicionado ao grupo!',
      group: updated,
    );
  }

  /// Entra em um grupo usando link de convite (`https://noesis.asterdev.me/grupos/NOE-XXXXXX`) ou código.
  Future<StudyGroupActionResult> joinByInviteLinkOrCode({
    required String codeOrLink,
    String? actorUserId,
    String? actorUsername,
    String? actorDisplayName,
    int? actorInsightsScore,
  }) async {
    await init();
    final code = parseInviteCode(codeOrLink);
    if (code.isEmpty) {
      return const StudyGroupActionResult(
        ok: false,
        error: 'Cole um código ou link de convite válido.',
      );
    }

    int idx = _groups.indexWhere((g) => g.inviteCode.toUpperCase() == code);
    if (idx == -1 && SupabaseService.isAuthenticated) {
      try {
        final row = await SupabaseService.client
            .from('noesis_study_groups')
            .select()
            .eq('invite_code', code)
            .maybeSingle();
        if (row != null && row['payload'] is Map) {
          final parsed = StudyGroup.fromJson(Map<String, dynamic>.from(row['payload'] as Map));
          _groups.insert(0, parsed);
          idx = 0;
        }
      } catch (_) {}
    }

    if (idx == -1) {
      return const StudyGroupActionResult(
        ok: false,
        error: 'Nenhum grupo encontrado para este código de convite.',
      );
    }

    final uid = actorUserId ?? currentUserId;
    final group = _groups[idx];
    if (group.members.any((m) => m.userId == uid)) {
      return StudyGroupActionResult(
        ok: true,
        message: 'Você já faz parte de "${group.name}".',
        group: group,
      );
    }

    final handle = SupabaseService.sanitizeUsername(actorUsername ?? currentUserHandle);
    final profileAvatar = SupabaseService.userProfileNotifier.value?['avatar_url']?.toString();
    final profileBio = SupabaseService.userProfileNotifier.value?['bio']?.toString();
    final member = StudyGroupMember(
      userId: uid,
      username: handle,
      displayName: (actorDisplayName ?? currentUserDisplayName).trim(),
      avatarUrl: actorUserId == null ? profileAvatar : null,
      bio: actorUserId == null ? profileBio : null,
      isVip: actorUserId == null ? SupabaseService.isCurrentUserVip : false,
      insightsScore: actorInsightsScore ?? 0,
      joinedAt: DateTime.now(),
    );

    final updated = group.copyWith(
      members: [...group.members, member],
      updatedAt: DateTime.now(),
    );
    _groups[idx] = updated;
    _publish();
    await _persist(changedGroup: updated);
    return StudyGroupActionResult(
      ok: true,
      message: 'Você entrou no grupo "${updated.name}"!',
      group: updated,
    );
  }

  /// Lista APENAS os conteúdos pessoais disponíveis na conta do usuário logado/ativo atual.
  /// Outros membros nunca têm acesso aos itens não anexados desta conta.
  Future<AttachablePersonalContent> loadAttachablePersonalContent({
    String? actorUserId,
  }) async {
    final uid = actorUserId ?? currentUserId;
    // Garante estrito isolamento por conta ativa: se consultado para um usuário externo
    // diferente da sessão local atual, retorna vazio.
    if (uid != currentUserId) {
      return AttachablePersonalContent(ownerUserId: uid);
    }

    final results = await Future.wait<dynamic>([
      SupabaseService.getNotebooks(),
      SupabaseService.getFlashcardDecks(),
      SavedExamsRepository.loadAll(),
      RoadmapsRepository.loadAll(),
    ]);

    return AttachablePersonalContent(
      ownerUserId: uid,
      notebooks: List<StudyNotebook>.from(results[0] as List<StudyNotebook>),
      decks: List<FlashcardDeck>.from(results[1] as List<FlashcardDeck>),
      exams: List<SavedExamAttempt>.from(results[2] as List<SavedExamAttempt>),
      roadmaps: List<StudyRoadmap>.from(results[3] as List<StudyRoadmap>),
    );
  }

  Future<StudyGroupActionResult> attachNotebook({
    required String groupId,
    required StudyNotebook notebook,
    String? actorUserId,
    String? actorName,
    String? actorHandle,
  }) async {
    return _updateContent(
      groupId: groupId,
      actorUserId: actorUserId,
      mutate: (g, uid, now) {
        if (g.sharedNotebooks.any((e) => e.sourceId == notebook.id)) {
          return null;
        }
        return g.copyWith(
          sharedNotebooks: [
            SharedGroupItem<StudyNotebook>(
              shareId: 'sh_nb_${now.microsecondsSinceEpoch}',
              sourceId: notebook.id,
              sharedByUserId: uid,
              sharedByName: actorName ?? currentUserDisplayName,
              sharedByHandle: actorHandle ?? currentUserHandle,
              sharedAt: now,
              data: notebook,
            ),
            ...g.sharedNotebooks,
          ],
          updatedAt: now,
        );
      },
      successMessage: 'Caderno "${notebook.title}" anexado ao grupo!',
      duplicateError: 'Este caderno já está anexado ao grupo.',
    );
  }

  Future<StudyGroupActionResult> attachDeck({
    required String groupId,
    required FlashcardDeck deck,
    String? actorUserId,
    String? actorName,
    String? actorHandle,
  }) async {
    return _updateContent(
      groupId: groupId,
      actorUserId: actorUserId,
      mutate: (g, uid, now) {
        if (g.sharedDecks.any((e) => e.sourceId == deck.id)) {
          return null;
        }
        return g.copyWith(
          sharedDecks: [
            SharedGroupItem<FlashcardDeck>(
              shareId: 'sh_dk_${now.microsecondsSinceEpoch}',
              sourceId: deck.id,
              sharedByUserId: uid,
              sharedByName: actorName ?? currentUserDisplayName,
              sharedByHandle: actorHandle ?? currentUserHandle,
              sharedAt: now,
              data: deck,
            ),
            ...g.sharedDecks,
          ],
          updatedAt: now,
        );
      },
      successMessage: 'Baralho "${deck.title}" anexado ao grupo!',
      duplicateError: 'Este baralho já está anexado ao grupo.',
    );
  }

  Future<StudyGroupActionResult> attachExam({
    required String groupId,
    required SavedExamAttempt exam,
    String? actorUserId,
    String? actorName,
    String? actorHandle,
  }) async {
    return _updateContent(
      groupId: groupId,
      actorUserId: actorUserId,
      mutate: (g, uid, now) {
        if (g.sharedExams.any((e) => e.sourceId == exam.id)) {
          return null;
        }
        return g.copyWith(
          sharedExams: [
            SharedGroupItem<SavedExamAttempt>(
              shareId: 'sh_ex_${now.microsecondsSinceEpoch}',
              sourceId: exam.id,
              sharedByUserId: uid,
              sharedByName: actorName ?? currentUserDisplayName,
              sharedByHandle: actorHandle ?? currentUserHandle,
              sharedAt: now,
              data: exam,
            ),
            ...g.sharedExams,
          ],
          updatedAt: now,
        );
      },
      successMessage: 'Simulado "${exam.title}" anexado ao grupo!',
      duplicateError: 'Este simulado já está anexado ao grupo.',
    );
  }

  Future<StudyGroupActionResult> attachRoadmap({
    required String groupId,
    required StudyRoadmap roadmap,
    String? actorUserId,
    String? actorName,
    String? actorHandle,
  }) async {
    return _updateContent(
      groupId: groupId,
      actorUserId: actorUserId,
      mutate: (g, uid, now) {
        if (g.sharedRoadmaps.any((e) => e.sourceId == roadmap.id)) {
          return null;
        }
        return g.copyWith(
          sharedRoadmaps: [
            SharedGroupItem<StudyRoadmap>(
              shareId: 'sh_rm_${now.microsecondsSinceEpoch}',
              sourceId: roadmap.id,
              sharedByUserId: uid,
              sharedByName: actorName ?? currentUserDisplayName,
              sharedByHandle: actorHandle ?? currentUserHandle,
              sharedAt: now,
              data: roadmap,
            ),
            ...g.sharedRoadmaps,
          ],
          updatedAt: now,
        );
      },
      successMessage: 'Trilha "${roadmap.title}" anexada ao grupo!',
      duplicateError: 'Esta trilha já está anexada ao grupo.',
    );
  }

  Future<StudyGroupActionResult> _updateContent({
    required String groupId,
    required String? actorUserId,
    required StudyGroup? Function(StudyGroup group, String uid, DateTime now) mutate,
    required String successMessage,
    required String duplicateError,
  }) async {
    await init();
    final uid = actorUserId ?? currentUserId;
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx == -1) {
      return const StudyGroupActionResult(ok: false, error: 'Grupo não encontrado.');
    }
    final group = _groups[idx];
    if (!group.canUserEdit(uid)) {
      return const StudyGroupActionResult(
        ok: false,
        error: 'Apenas o líder ou membros com permissão de edição podem anexar conteúdos.',
      );
    }

    final updated = mutate(group, uid, DateTime.now());
    if (updated == null) {
      return StudyGroupActionResult(ok: false, error: duplicateError);
    }
    _groups[idx] = updated;
    _publish();
    await _persist(changedGroup: updated);
    return StudyGroupActionResult(ok: true, message: successMessage, group: updated);
  }

  /// Remove conteúdo compartilhado — exclusivo do líder do grupo.
  Future<StudyGroupActionResult> removeSharedContent({
    required String groupId,
    required StudyGroupContentKind kind,
    required String shareId,
    String? actorUserId,
  }) async {
    await init();
    final uid = actorUserId ?? currentUserId;
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx == -1) {
      return const StudyGroupActionResult(ok: false, error: 'Grupo não encontrado.');
    }
    final group = _groups[idx];
    if (!group.canUserRemoveContent(uid)) {
      return const StudyGroupActionResult(
        ok: false,
        error: 'Apenas o líder do grupo pode remover conteúdos anexados.',
      );
    }

    StudyGroup updated;
    final now = DateTime.now();
    switch (kind) {
      case StudyGroupContentKind.notebook:
        updated = group.copyWith(
          sharedNotebooks: group.sharedNotebooks.where((e) => e.shareId != shareId).toList(),
          updatedAt: now,
        );
      case StudyGroupContentKind.deck:
        updated = group.copyWith(
          sharedDecks: group.sharedDecks.where((e) => e.shareId != shareId).toList(),
          updatedAt: now,
        );
      case StudyGroupContentKind.exam:
        updated = group.copyWith(
          sharedExams: group.sharedExams.where((e) => e.shareId != shareId).toList(),
          updatedAt: now,
        );
      case StudyGroupContentKind.roadmap:
        updated = group.copyWith(
          sharedRoadmaps: group.sharedRoadmaps.where((e) => e.shareId != shareId).toList(),
          updatedAt: now,
        );
    }

    _groups[idx] = updated;
    _publish();
    await _persist(changedGroup: updated);
    return StudyGroupActionResult(
      ok: true,
      message: 'Conteúdo removido do grupo.',
      group: updated,
    );
  }

  /// Registra uma sessão de estudo no Diário do grupo por usuário e soma Insights no ranking do grupo.
  Future<StudyGroupActionResult> addStudyLogEntry({
    required String groupId,
    required String subject,
    required String topic,
    required int durationMinutes,
    String? notes,
    String? actorUserId,
    String? actorName,
    String? actorHandle,
  }) async {
    await init();
    final uid = actorUserId ?? currentUserId;
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx == -1) {
      return const StudyGroupActionResult(ok: false, error: 'Grupo não encontrado.');
    }
    final group = _groups[idx];
    if (group.memberFor(uid) == null) {
      return const StudyGroupActionResult(
        ok: false,
        error: 'Entre no grupo para registrar sessões no diário compartilhado.',
      );
    }
    if (durationMinutes <= 0) {
      return const StudyGroupActionResult(
        ok: false,
        error: 'Informe uma duração maior que zero minutos.',
      );
    }

    final now = DateTime.now();
    final cleanSubj = subject.trim().isEmpty ? 'Estudo' : subject.trim();
    final entry = StudyGroupLogEntry(
      id: 'glog_${now.microsecondsSinceEpoch}',
      userId: uid,
      memberName: (actorName ?? currentUserDisplayName).trim(),
      memberUsername: SupabaseService.sanitizeUsername(actorHandle ?? currentUserHandle),
      subject: cleanSubj,
      topic: topic.trim(),
      durationMinutes: durationMinutes,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      loggedAt: now,
    );

    final baseInsights = ((durationMinutes.clamp(1, 180)) / 10).ceil().clamp(1, 18);
    final earned = ShopService.instance.awardGroupStudyReward(
      groupId: groupId,
      source: 'group_diary',
      rawAmount: baseInsights,
      description: 'Diário no grupo "${group.name}" · $cleanSubj',
      idempotentId: 'grp_log:${entry.id}',
    );

    final updatedMembers = _addMemberStats(
      group.members,
      userId: uid,
      insightsDelta: earned,
      minutesDelta: durationMinutes,
    );

    final updated = group.copyWith(
      members: updatedMembers,
      studyLogs: [entry, ...group.studyLogs],
      updatedAt: now,
    );
    _groups[idx] = updated;
    _publish();
    await _persist(changedGroup: updated);
    return StudyGroupActionResult(
      ok: true,
      message: earned > 0
          ? 'Sessão registrada! +$earned Insights no ranking do grupo.'
          : 'Sessão registrada no diário do grupo!',
      group: updated,
      earnedInsights: earned,
    );
  }

  List<StudyGroupMember> _addMemberStats(
    List<StudyGroupMember> members, {
    required String userId,
    int insightsDelta = 0,
    int minutesDelta = 0,
  }) {
    return members.map((m) {
      if (m.userId != userId) return m;
      return m.copyWith(
        insightsScore: m.insightsScore + insightsDelta,
        weeklyMinutes: m.weeklyMinutes + minutesDelta,
      );
    }).toList();
  }

  // ------------------------------------------------------------------
  // CHAT INTERNO DO GRUPO
  // ------------------------------------------------------------------
  Future<StudyGroupActionResult> sendChatMessage({
    required String groupId,
    required String text,
    String? actorUserId,
    String? actorName,
    String? actorHandle,
  }) async {
    await init();
    final uid = actorUserId ?? currentUserId;
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx == -1) {
      return const StudyGroupActionResult(ok: false, error: 'Grupo não encontrado.');
    }
    final group = _groups[idx];
    final member = group.memberFor(uid);
    if (member == null) {
      return const StudyGroupActionResult(
        ok: false,
        error: 'Apenas membros podem conversar no chat do grupo.',
      );
    }
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      return const StudyGroupActionResult(ok: false, error: 'Digite uma mensagem.');
    }

    final now = DateTime.now();
    final msg = StudyGroupChatMessage(
      id: 'gmsg_${now.microsecondsSinceEpoch}-${group.chatMessages.length}',
      userId: uid,
      senderName: (actorName ?? member.displayName).trim(),
      senderUsername: SupabaseService.sanitizeUsername(actorHandle ?? member.username),
      senderAvatarUrl: member.avatarUrl,
      isVip: member.isVip,
      isLeader: member.isLeader,
      text: cleanText,
      sentAt: now,
    );

    final updated = group.copyWith(
      chatMessages: [...group.chatMessages, msg],
      updatedAt: now,
    );
    _groups[idx] = updated;
    _publish();
    await _persist(changedGroup: updated);
    return StudyGroupActionResult(ok: true, group: updated);
  }

  Future<StudyGroupActionResult> deleteChatMessage({
    required String groupId,
    required String messageId,
    String? actorUserId,
  }) async {
    await init();
    final uid = actorUserId ?? currentUserId;
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx == -1) {
      return const StudyGroupActionResult(ok: false, error: 'Grupo não encontrado.');
    }
    final group = _groups[idx];
    final msgIdx = group.chatMessages.indexWhere((m) => m.id == messageId);
    if (msgIdx == -1) {
      return const StudyGroupActionResult(ok: false, error: 'Mensagem não encontrada.');
    }
    final target = group.chatMessages[msgIdx];
    if (target.userId != uid && !group.isLeader(uid)) {
      return const StudyGroupActionResult(
        ok: false,
        error: 'Você só pode apagar suas próprias mensagens.',
      );
    }
    final updated = group.copyWith(
      chatMessages: group.chatMessages.where((m) => m.id != messageId).toList(),
      updatedAt: DateTime.now(),
    );
    _groups[idx] = updated;
    _publish();
    await _persist(changedGroup: updated);
    return StudyGroupActionResult(ok: true, group: updated);
  }

  // ------------------------------------------------------------------
  // CRIAÇÃO DE CONTEÚDO DIRETO NO GRUPO
  // ------------------------------------------------------------------
  Future<StudyGroupActionResult> createGroupNotebook({
    required String groupId,
    required String title,
    required String subject,
    required String noteTitle,
    required String noteContent,
    String? actorUserId,
    String? actorName,
    String? actorHandle,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      return const StudyGroupActionResult(ok: false, error: 'Informe um título para o caderno.');
    }
    final now = DateTime.now();
    final nbId = 'gnb_${now.microsecondsSinceEpoch}';
    final notes = noteContent.trim().isNotEmpty || noteTitle.trim().isNotEmpty
        ? [
            StudyNote(
              id: 'gnote_${now.microsecondsSinceEpoch}',
              notebookId: nbId,
              title: noteTitle.trim().isEmpty ? 'Anotação Inicial' : noteTitle.trim(),
              content: noteContent.trim(),
            ),
          ]
        : const <StudyNote>[];

    final nb = StudyNotebook(
      id: nbId,
      title: cleanTitle,
      subject: subject.trim().isEmpty ? 'Geral' : subject.trim(),
      notes: notes,
    );
    return attachNotebook(
      groupId: groupId,
      notebook: nb,
      actorUserId: actorUserId,
      actorName: actorName,
      actorHandle: actorHandle,
    );
  }

  Future<StudyGroupActionResult> addNoteToGroupNotebook({
    required String groupId,
    required String shareId,
    required String noteTitle,
    required String noteContent,
    String? actorUserId,
  }) async {
    if (noteTitle.trim().isEmpty || noteContent.trim().isEmpty) {
      return const StudyGroupActionResult(
        ok: false,
        error: 'Preencha o título e o conteúdo da anotação.',
      );
    }
    return _updateContent(
      groupId: groupId,
      actorUserId: actorUserId,
      mutate: (g, uid, now) {
        final nextNotebooks = g.sharedNotebooks.map((item) {
          if (item.shareId != shareId) return item;
          final nb = item.data;
          final updatedNb = nb.copyWith(
            notes: [
              ...nb.notes,
              StudyNote(
                id: 'gnote_${now.microsecondsSinceEpoch}',
                notebookId: nb.id,
                title: noteTitle.trim(),
                content: noteContent.trim(),
              ),
            ],
          );
          return SharedGroupItem<StudyNotebook>(
            shareId: item.shareId,
            sourceId: item.sourceId,
            sharedByUserId: item.sharedByUserId,
            sharedByName: item.sharedByName,
            sharedByHandle: item.sharedByHandle,
            sharedAt: item.sharedAt,
            data: updatedNb,
          );
        }).toList();
        return g.copyWith(sharedNotebooks: nextNotebooks, updatedAt: now);
      },
      successMessage: 'Anotação adicionada ao caderno do grupo!',
      duplicateError: 'Não foi possível adicionar a anotação.',
    );
  }

  Future<StudyGroupActionResult> createGroupDeck({
    required String groupId,
    required String title,
    required String subject,
    required List<Flashcard> cards,
    String description = '',
    String? actorUserId,
    String? actorName,
    String? actorHandle,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty || cards.isEmpty) {
      return const StudyGroupActionResult(
        ok: false,
        error: 'Informe o título e ao menos 1 flashcard.',
      );
    }
    final now = DateTime.now();
    final deck = FlashcardDeck(
      id: 'gdk_${now.microsecondsSinceEpoch}',
      title: cleanTitle,
      subject: subject.trim().isEmpty ? 'Geral' : subject.trim(),
      description: description.trim(),
      cards: cards,
      createdAt: now,
    );
    return attachDeck(
      groupId: groupId,
      deck: deck,
      actorUserId: actorUserId,
      actorName: actorName,
      actorHandle: actorHandle,
    );
  }

  Future<StudyGroupActionResult> createGroupExam({
    required String groupId,
    required String title,
    required String subject,
    required List<Map<String, dynamic>> questions,
    String difficulty = 'Médio',
    String? actorUserId,
    String? actorName,
    String? actorHandle,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty || questions.isEmpty) {
      return const StudyGroupActionResult(
        ok: false,
        error: 'Informe o título e ao menos 1 questão para o simulado.',
      );
    }
    final now = DateTime.now();
    final cleanSubj = subject.trim().isEmpty ? 'Geral' : subject.trim();
    final exam = SavedExamAttempt(
      id: 'gex_${now.microsecondsSinceEpoch}',
      groupKey: 'group_${groupId}_${now.millisecondsSinceEpoch}',
      examModelId: null,
      examModelName: 'Grupo · $cleanSubj',
      title: cleanTitle,
      subject: cleanSubj,
      topic: cleanSubj,
      difficulty: difficulty,
      createdAt: now,
      elapsedSeconds: 0,
      targetTotalCount: questions.length,
      questions: questions,
      userAnswers: const {},
      correctCount: 0,
      wrongCount: 0,
      blankCount: questions.length,
      scorePercentage: 0,
    );
    return attachExam(
      groupId: groupId,
      exam: exam,
      actorUserId: actorUserId,
      actorName: actorName,
      actorHandle: actorHandle,
    );
  }

  Future<StudyGroupActionResult> createGroupRoadmap({
    required String groupId,
    required String title,
    required String subject,
    required String goal,
    required List<RoadmapStep> steps,
    String? actorUserId,
    String? actorName,
    String? actorHandle,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty || steps.isEmpty) {
      return const StudyGroupActionResult(
        ok: false,
        error: 'Informe o título e ao menos 1 etapa da trilha.',
      );
    }
    final now = DateTime.now();
    final rm = StudyRoadmap(
      id: 'grm_${now.microsecondsSinceEpoch}',
      title: cleanTitle,
      subject: subject.trim().isEmpty ? 'Geral' : subject.trim(),
      goal: goal.trim().isEmpty ? 'Estudar em grupo' : goal.trim(),
      level: 'Colaborativa',
      steps: steps,
      createdAt: now,
      updatedAt: now,
    );
    return attachRoadmap(
      groupId: groupId,
      roadmap: rm,
      actorUserId: actorUserId,
      actorName: actorName,
      actorHandle: actorHandle,
    );
  }

  // ------------------------------------------------------------------
  // INTERAÇÃO E INSIGHTS EXCLUSIVOS DENTRO DO GRUPO
  // ------------------------------------------------------------------
  Future<StudyGroupActionResult> recordGroupNotebookStudy({
    required String groupId,
    required String shareId,
    required String noteId,
    required String notebookTitle,
    String? actorUserId,
  }) async {
    await init();
    final uid = actorUserId ?? currentUserId;
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx == -1) {
      return const StudyGroupActionResult(ok: false, error: 'Grupo não encontrado.');
    }
    final group = _groups[idx];
    if (group.memberFor(uid) == null) {
      return const StudyGroupActionResult(ok: false, error: 'Apenas membros podem estudar neste grupo.');
    }

    final earned = ShopService.instance.awardGroupStudyReward(
      groupId: groupId,
      source: 'group_notebook',
      rawAmount: 3,
      description: 'Leitura no grupo "${group.name}" · $notebookTitle',
      idempotentId: 'grp_nb:$groupId:$uid:$shareId:$noteId',
    );
    if (earned <= 0) {
      return StudyGroupActionResult(
        ok: true,
        message: 'Leitura já contabilizada para esta anotação neste grupo.',
        group: group,
        earnedInsights: 0,
      );
    }

    final updated = group.copyWith(
      members: _addMemberStats(group.members, userId: uid, insightsDelta: earned),
      updatedAt: DateTime.now(),
    );
    _groups[idx] = updated;
    _publish();
    await _persist(changedGroup: updated);
    return StudyGroupActionResult(
      ok: true,
      message: '+$earned Insights no ranking do grupo!',
      group: updated,
      earnedInsights: earned,
    );
  }

  Future<StudyGroupActionResult> recordGroupFlashcardReview({
    required String groupId,
    required String shareId,
    required String cardId,
    required String deckTitle,
    required String quality, // again | hard | good | easy
    String? actorUserId,
  }) async {
    await init();
    final uid = actorUserId ?? currentUserId;
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx == -1) {
      return const StudyGroupActionResult(ok: false, error: 'Grupo não encontrado.');
    }
    final group = _groups[idx];
    if (group.memberFor(uid) == null) {
      return const StudyGroupActionResult(ok: false, error: 'Entre no grupo para estudar os flashcards.');
    }

    int earned = 0;
    if (quality != 'again') {
      final now = ShopService.currentNow();
      final dayIso = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      earned = ShopService.instance.awardGroupStudyReward(
        groupId: groupId,
        source: 'group_flashcard',
        rawAmount: quality == 'hard' ? 1 : 2,
        description: 'Flashcard no grupo "${group.name}" · $deckTitle',
        idempotentId: 'grp_fc:$groupId:$uid:$shareId:$cardId:$dayIso',
      );
    }

    if (earned <= 0) {
      return StudyGroupActionResult(ok: true, group: group, earnedInsights: 0);
    }

    final updated = group.copyWith(
      members: _addMemberStats(group.members, userId: uid, insightsDelta: earned),
      updatedAt: DateTime.now(),
    );
    _groups[idx] = updated;
    _publish();
    await _persist(changedGroup: updated);
    return StudyGroupActionResult(
      ok: true,
      message: '+$earned Insights no grupo',
      group: updated,
      earnedInsights: earned,
    );
  }

  Future<StudyGroupActionResult> recordGroupExamQuestionAnswer({
    required String groupId,
    required String shareId,
    required String examTitle,
    required int questionIndex,
    required bool isCorrect,
    Duration? elapsedSinceShown,
    String? actorUserId,
  }) async {
    await init();
    final uid = actorUserId ?? currentUserId;
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx == -1) {
      return const StudyGroupActionResult(ok: false, error: 'Grupo não encontrado.');
    }
    final group = _groups[idx];
    if (group.memberFor(uid) == null) {
      return const StudyGroupActionResult(ok: false, error: 'Entre no grupo para resolver o simulado.');
    }

    final earned = ShopService.instance.awardForQuizAnswer(
      isCorrect: isCorrect,
      elapsedSinceShown: elapsedSinceShown,
      subject: '${group.name} · $examTitle',
      reference: 'group:$groupId:$shareId:q$questionIndex',
    );
    if (earned <= 0) {
      return StudyGroupActionResult(ok: true, group: group, earnedInsights: 0);
    }

    final updated = group.copyWith(
      members: _addMemberStats(group.members, userId: uid, insightsDelta: earned),
      updatedAt: DateTime.now(),
    );
    _groups[idx] = updated;
    _publish();
    await _persist(changedGroup: updated);
    return StudyGroupActionResult(ok: true, group: updated, earnedInsights: earned);
  }

  Future<StudyGroupActionResult> recordGroupExamCompletion({
    required String groupId,
    required String shareId,
    required String examTitle,
    required double scorePercentage,
    String? actorUserId,
  }) async {
    await init();
    final uid = actorUserId ?? currentUserId;
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx == -1) {
      return const StudyGroupActionResult(ok: false, error: 'Grupo não encontrado.');
    }
    final group = _groups[idx];
    if (group.memberFor(uid) == null) {
      return const StudyGroupActionResult(ok: false, error: 'Entre no grupo para concluir o simulado.');
    }

    final attemptId = 'grp_${groupId}_${shareId}_${uid}_${DateTime.now().microsecondsSinceEpoch}';
    final earned = ShopService.instance.awardForExamCompletion(
      attemptId: attemptId,
      groupKey: 'grp_${groupId}_$shareId',
      scorePercentage: scorePercentage,
      subject: '${group.name} · $examTitle',
    );
    if (earned <= 0) {
      return StudyGroupActionResult(ok: true, group: group, earnedInsights: 0);
    }

    final updated = group.copyWith(
      members: _addMemberStats(group.members, userId: uid, insightsDelta: earned),
      updatedAt: DateTime.now(),
    );
    _groups[idx] = updated;
    _publish();
    await _persist(changedGroup: updated);
    return StudyGroupActionResult(
      ok: true,
      message: 'Simulado concluído no grupo! +$earned Insights no ranking.',
      group: updated,
      earnedInsights: earned,
    );
  }

  Future<StudyGroupActionResult> toggleGroupRoadmapStep({
    required String groupId,
    required String shareId,
    required String stepId,
    required RoadmapStepStatus nextStatus,
    String? actorUserId,
  }) async {
    await init();
    final uid = actorUserId ?? currentUserId;
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx == -1) {
      return const StudyGroupActionResult(ok: false, error: 'Grupo não encontrado.');
    }
    final group = _groups[idx];
    if (group.memberFor(uid) == null) {
      return const StudyGroupActionResult(ok: false, error: 'Entre no grupo para interagir com a trilha.');
    }

    String stepTitle = '';
    final now = DateTime.now();
    final nextRoadmaps = group.sharedRoadmaps.map((item) {
      if (item.shareId != shareId) return item;
      final rm = item.data;
      final nextSteps = rm.steps.map((s) {
        if (s.id != stepId) return s;
        stepTitle = s.title;
        return s.copyWith(status: nextStatus);
      }).toList();
      return SharedGroupItem<StudyRoadmap>(
        shareId: item.shareId,
        sourceId: item.sourceId,
        sharedByUserId: item.sharedByUserId,
        sharedByName: item.sharedByName,
        sharedByHandle: item.sharedByHandle,
        sharedAt: item.sharedAt,
        data: rm.copyWith(steps: nextSteps, updatedAt: now),
      );
    }).toList();

    int earned = 0;
    if (nextStatus == RoadmapStepStatus.done && stepTitle.isNotEmpty) {
      earned = ShopService.instance.awardGroupStudyReward(
        groupId: groupId,
        source: 'group_roadmap',
        rawAmount: 5,
        description: 'Etapa concluída no grupo "${group.name}" · $stepTitle',
        idempotentId: 'grp_rm:$groupId:$uid:$shareId:$stepId',
      );
    }

    final updated = group.copyWith(
      sharedRoadmaps: nextRoadmaps,
      members: earned > 0
          ? _addMemberStats(group.members, userId: uid, insightsDelta: earned)
          : group.members,
      updatedAt: now,
    );
    _groups[idx] = updated;
    _publish();
    await _persist(changedGroup: updated);
    return StudyGroupActionResult(
      ok: true,
      message: earned > 0
          ? 'Etapa concluída! +$earned Insights no ranking do grupo.'
          : 'Etapa atualizada!',
      group: updated,
      earnedInsights: earned,
    );
  }

  // ------------------------------------------------------------------
  // PARIDADE COMPLETA COM AS PÁGINAS (CADERNOS, FLASHCARDS, SIMULADOS, TRILHAS)
  // ------------------------------------------------------------------
  StudyGroup? groupById(String groupId) {
    for (final g in _groups) {
      if (g.id == groupId) return g;
    }
    return null;
  }

  List<StudyNotebook> groupNotebooks(String groupId) =>
      (groupById(groupId)?.sharedNotebooks ?? const []).map((e) => e.data).toList();

  List<FlashcardDeck> groupDecks(String groupId, {String? userId}) {
    final g = groupById(groupId);
    if (g == null) return const [];
    final uid = userId ?? currentUserId;
    return g.sharedDecks.map((item) => g.resolvedDeckForUser(item, uid)).toList();
  }

  List<SavedExamAttempt> groupExams(String groupId) =>
      (groupById(groupId)?.sharedExams ?? const []).map((e) => e.data).toList();

  List<SharedGroupItem<SavedExamAttempt>> groupExamItems(String groupId) =>
      groupById(groupId)?.sharedExams ?? const [];

  List<StudyRoadmap> groupRoadmaps(String groupId) =>
      (groupById(groupId)?.sharedRoadmaps ?? const []).map((e) => e.data).toList();

  Future<StudyGroupActionResult> _creditMemberInGroup({
    required String groupId,
    required String userId,
    required int earned,
    String? message,
  }) async {
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx == -1) return const StudyGroupActionResult(ok: false, error: 'Grupo não encontrado.');
    final group = _groups[idx];
    if (earned <= 0) {
      return StudyGroupActionResult(ok: true, group: group, earnedInsights: 0);
    }
    final updated = group.copyWith(
      members: _addMemberStats(group.members, userId: userId, insightsDelta: earned),
      updatedAt: DateTime.now(),
    );
    _groups[idx] = updated;
    _publish();
    await _persist(changedGroup: updated);
    return StudyGroupActionResult(
      ok: true,
      message: message,
      group: updated,
      earnedInsights: earned,
    );
  }

  Future<StudyGroupActionResult> saveGroupNotebook(String groupId, StudyNotebook notebook) {
    return _updateContent(
      groupId: groupId,
      actorUserId: null,
      mutate: (g, uid, now) {
        final existingIdx = g.sharedNotebooks.indexWhere(
          (e) => e.sourceId == notebook.id || e.data.id == notebook.id,
        );
        final list = List<SharedGroupItem<StudyNotebook>>.from(g.sharedNotebooks);
        if (existingIdx != -1) {
          final prev = list[existingIdx];
          list[existingIdx] = SharedGroupItem<StudyNotebook>(
            shareId: prev.shareId,
            sourceId: prev.sourceId,
            sharedByUserId: prev.sharedByUserId,
            sharedByName: prev.sharedByName,
            sharedByHandle: prev.sharedByHandle,
            sharedAt: prev.sharedAt,
            data: notebook,
          );
        } else {
          list.insert(
            0,
            SharedGroupItem<StudyNotebook>(
              shareId: 'sh_nb_${now.microsecondsSinceEpoch}',
              sourceId: notebook.id,
              sharedByUserId: uid,
              sharedByName: currentUserDisplayName,
              sharedByHandle: currentUserHandle,
              sharedAt: now,
              data: notebook,
            ),
          );
        }
        return g.copyWith(sharedNotebooks: list, updatedAt: now);
      },
      successMessage: 'Caderno "${notebook.title}" salvo no grupo!',
      duplicateError: 'Erro ao salvar caderno.',
    );
  }

  Future<StudyGroupActionResult> deleteGroupNotebook(String groupId, String notebookId) async {
    await init();
    final group = groupById(groupId);
    if (group == null) return const StudyGroupActionResult(ok: false, error: 'Grupo não encontrado.');
    final item = group.sharedNotebooks.where((e) => e.sourceId == notebookId || e.data.id == notebookId).firstOrNull;
    if (item == null) return const StudyGroupActionResult(ok: false, error: 'Caderno não encontrado.');
    return removeSharedContent(groupId: groupId, kind: StudyGroupContentKind.notebook, shareId: item.shareId);
  }

  Future<StudyGroupActionResult> saveGroupNote(String groupId, String notebookId, StudyNote note) {
    return _updateContent(
      groupId: groupId,
      actorUserId: null,
      mutate: (g, uid, now) {
        final list = g.sharedNotebooks.map((item) {
          if (item.sourceId != notebookId && item.data.id != notebookId) return item;
          final notes = List<StudyNote>.from(item.data.notes);
          final nIdx = notes.indexWhere((n) => n.id == note.id);
          if (nIdx != -1) {
            notes[nIdx] = note;
          } else {
            notes.add(note);
          }
          return SharedGroupItem<StudyNotebook>(
            shareId: item.shareId,
            sourceId: item.sourceId,
            sharedByUserId: item.sharedByUserId,
            sharedByName: item.sharedByName,
            sharedByHandle: item.sharedByHandle,
            sharedAt: item.sharedAt,
            data: item.data.copyWith(notes: notes, updatedAt: now),
          );
        }).toList();
        return g.copyWith(sharedNotebooks: list, updatedAt: now);
      },
      successMessage: 'Anotação "${note.title}" salva no caderno do grupo!',
      duplicateError: 'Erro ao salvar anotação.',
    );
  }

  Future<StudyGroupActionResult> deleteGroupNote(String groupId, String notebookId, String noteId) {
    return _updateContent(
      groupId: groupId,
      actorUserId: null,
      mutate: (g, uid, now) {
        final list = g.sharedNotebooks.map((item) {
          if (item.sourceId != notebookId && item.data.id != notebookId) return item;
          final notes = item.data.notes.where((n) => n.id != noteId).toList();
          return SharedGroupItem<StudyNotebook>(
            shareId: item.shareId,
            sourceId: item.sourceId,
            sharedByUserId: item.sharedByUserId,
            sharedByName: item.sharedByName,
            sharedByHandle: item.sharedByHandle,
            sharedAt: item.sharedAt,
            data: item.data.copyWith(notes: notes, updatedAt: now),
          );
        }).toList();
        return g.copyWith(sharedNotebooks: list, updatedAt: now);
      },
      successMessage: 'Anotação excluída do grupo.',
      duplicateError: 'Erro ao excluir anotação.',
    );
  }

  Future<StudyGroupActionResult> recordGroupNotebookReviewById(
    String groupId,
    String notebookId,
    String noteId,
    String notebookTitle,
  ) async {
    await init();
    final group = groupById(groupId);
    if (group == null) return const StudyGroupActionResult(ok: false, error: 'Grupo não encontrado.');
    final item = group.sharedNotebooks.where((e) => e.sourceId == notebookId || e.data.id == notebookId).firstOrNull;
    return recordGroupNotebookStudy(
      groupId: groupId,
      shareId: item?.shareId ?? notebookId,
      noteId: noteId,
      notebookTitle: notebookTitle,
    );
  }

  Future<StudyGroupActionResult> saveGroupDeck(String groupId, FlashcardDeck deck) {
    return _updateContent(
      groupId: groupId,
      actorUserId: null,
      mutate: (g, uid, now) {
        final existingIdx = g.sharedDecks.indexWhere(
          (e) => e.sourceId == deck.id || e.data.id == deck.id,
        );
        final list = List<SharedGroupItem<FlashcardDeck>>.from(g.sharedDecks);
        if (existingIdx != -1) {
          final prev = list[existingIdx];
          list[existingIdx] = SharedGroupItem<FlashcardDeck>(
            shareId: prev.shareId,
            sourceId: prev.sourceId,
            sharedByUserId: prev.sharedByUserId,
            sharedByName: prev.sharedByName,
            sharedByHandle: prev.sharedByHandle,
            sharedAt: prev.sharedAt,
            data: deck,
          );
        } else {
          list.insert(
            0,
            SharedGroupItem<FlashcardDeck>(
              shareId: 'sh_dk_${now.microsecondsSinceEpoch}',
              sourceId: deck.id,
              sharedByUserId: uid,
              sharedByName: currentUserDisplayName,
              sharedByHandle: currentUserHandle,
              sharedAt: now,
              data: deck,
            ),
          );
        }
        return g.copyWith(sharedDecks: list, updatedAt: now);
      },
      successMessage: 'Baralho "${deck.title}" salvo no grupo!',
      duplicateError: 'Erro ao salvar baralho.',
    );
  }

  Future<StudyGroupActionResult> deleteGroupDeck(String groupId, String deckId) async {
    await init();
    final group = groupById(groupId);
    if (group == null) return const StudyGroupActionResult(ok: false, error: 'Grupo não encontrado.');
    final item = group.sharedDecks.where((e) => e.sourceId == deckId || e.data.id == deckId).firstOrNull;
    if (item == null) return const StudyGroupActionResult(ok: false, error: 'Baralho não encontrado.');
    return removeSharedContent(groupId: groupId, kind: StudyGroupContentKind.deck, shareId: item.shareId);
  }

  Future<StudyGroupActionResult> recordGroupFlashcardReviewByDeckId({
    required String groupId,
    required String deckId,
    required String cardId,
    required String deckTitle,
    required String difficulty,
    required bool isDueForReview,
    required bool wasPreviouslyHard,
    required bool allowReviewBase,
    String? actorUserId,
  }) async {
    await init();
    final uid = actorUserId ?? currentUserId;
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx == -1) return const StudyGroupActionResult(ok: false, error: 'Grupo não encontrado.');
    final group = _groups[idx];
    if (group.memberFor(uid) == null) {
      return const StudyGroupActionResult(ok: false, error: 'Entre no grupo para estudar.');
    }

    final earned = ShopService.instance.awardForFlashcardReview(
      cardId: 'grp_${groupId}_$cardId',
      difficulty: difficulty,
      isDueForReview: isDueForReview,
      wasPreviouslyHard: wasPreviouslyHard,
      deckTitle: 'Grupo ${group.name} · $deckTitle',
      allowReviewBase: allowReviewBase,
    );

    final now = DateTime.now();
    final matchedItem = group.sharedDecks
        .where((e) => e.sourceId == deckId || e.data.id == deckId)
        .firstOrNull;
    final resolvedDeckId = matchedItem?.data.id ?? deckId;
    final progressKey = StudyGroup.cardProgressKey(resolvedDeckId, cardId);

    final nextProgress = Map<String, Map<String, GroupCardProgress>>.fromEntries(
      group.flashcardProgress.entries.map(
        (e) => MapEntry(e.key, Map<String, GroupCardProgress>.from(e.value)),
      ),
    );
    final userProgress = Map<String, GroupCardProgress>.from(nextProgress[uid] ?? const {});
    final prev = userProgress[progressKey];
    userProgress[progressKey] = GroupCardProgress(
      difficulty: difficulty,
      reviewCount: (prev?.reviewCount ?? 0) + 1,
      lastReviewed: now,
    );
    nextProgress[uid] = userProgress;

    final updated = group.copyWith(
      flashcardProgress: nextProgress,
      members: earned > 0
          ? _addMemberStats(group.members, userId: uid, insightsDelta: earned)
          : group.members,
      updatedAt: now,
    );
    _groups[idx] = updated;
    _publish();
    await _persist(changedGroup: updated);
    return StudyGroupActionResult(ok: true, group: updated, earnedInsights: earned);
  }

  Future<StudyGroupActionResult> saveGroupExamAttempt(
    String groupId,
    SavedExamAttempt attempt, {
    String? actorUserId,
    String? actorName,
    String? actorHandle,
  }) async {
    await init();
    final uid = actorUserId ?? currentUserId;
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx == -1) return const StudyGroupActionResult(ok: false, error: 'Grupo não encontrado.');
    final group = _groups[idx];
    final member = group.memberFor(uid);
    if (member == null) {
      return const StudyGroupActionResult(ok: false, error: 'Entre no grupo para salvar simulados.');
    }

    final now = DateTime.now();
    final list = List<SharedGroupItem<SavedExamAttempt>>.from(group.sharedExams);
    final exIdx = list.indexWhere(
      (e) => (e.sourceId == attempt.id || e.data.id == attempt.id) && e.sharedByUserId == uid,
    );
    if (exIdx != -1) {
      final prev = list[exIdx];
      list[exIdx] = SharedGroupItem<SavedExamAttempt>(
        shareId: prev.shareId,
        sourceId: prev.sourceId,
        sharedByUserId: prev.sharedByUserId,
        sharedByName: prev.sharedByName,
        sharedByHandle: prev.sharedByHandle,
        sharedAt: prev.sharedAt,
        data: attempt,
      );
    } else {
      list.insert(
        0,
        SharedGroupItem<SavedExamAttempt>(
          shareId: 'sh_ex_${now.microsecondsSinceEpoch}',
          sourceId: attempt.id,
          sharedByUserId: uid,
          sharedByName: actorName ?? member.displayName,
          sharedByHandle: actorHandle ?? member.username,
          sharedAt: now,
          data: attempt,
        ),
      );
    }
    final updated = group.copyWith(sharedExams: list, updatedAt: now);
    _groups[idx] = updated;
    _publish();
    await _persist(changedGroup: updated);
    return StudyGroupActionResult(ok: true, group: updated);
  }

  Future<StudyGroupActionResult> deleteGroupExam(String groupId, String attemptId) async {
    await init();
    final group = groupById(groupId);
    if (group == null) return const StudyGroupActionResult(ok: false, error: 'Grupo não encontrado.');
    final item = group.sharedExams.where((e) => e.sourceId == attemptId || e.data.id == attemptId).firstOrNull;
    if (item == null) return const StudyGroupActionResult(ok: false, error: 'Simulado não encontrado.');
    return removeSharedContent(groupId: groupId, kind: StudyGroupContentKind.exam, shareId: item.shareId);
  }

  Future<StudyGroupActionResult> updateGroupExamAiReview(
    String groupId,
    String attemptId,
    String markdown,
  ) async {
    await init();
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx == -1) return const StudyGroupActionResult(ok: false, error: 'Grupo não encontrado.');
    final group = _groups[idx];
    final next = group.sharedExams.map((item) {
      if (item.sourceId != attemptId && item.data.id != attemptId) return item;
      return SharedGroupItem<SavedExamAttempt>(
        shareId: item.shareId,
        sourceId: item.sourceId,
        sharedByUserId: item.sharedByUserId,
        sharedByName: item.sharedByName,
        sharedByHandle: item.sharedByHandle,
        sharedAt: item.sharedAt,
        data: item.data.copyWith(aiReviewMarkdown: markdown),
      );
    }).toList();
    final updated = group.copyWith(sharedExams: next, updatedAt: DateTime.now());
    _groups[idx] = updated;
    _publish();
    await _persist(changedGroup: updated);
    return StudyGroupActionResult(ok: true, group: updated);
  }

  Future<StudyGroupActionResult> recordGroupExamAnswerRaw({
    required String groupId,
    required bool isCorrect,
    required Duration elapsedSinceShown,
    required String subject,
    required String reference,
  }) async {
    await init();
    final uid = currentUserId;
    final earned = ShopService.instance.awardForQuizAnswer(
      isCorrect: isCorrect,
      elapsedSinceShown: elapsedSinceShown,
      subject: subject,
      reference: reference,
    );
    return _creditMemberInGroup(groupId: groupId, userId: uid, earned: earned);
  }

  Future<StudyGroupActionResult> recordGroupExamCompletionRaw({
    required String groupId,
    required String attemptId,
    required String groupKey,
    required double scorePercentage,
    required String subject,
  }) async {
    await init();
    final uid = currentUserId;
    final earned = ShopService.instance.awardForExamCompletion(
      attemptId: 'grp_${groupId}_$attemptId',
      groupKey: 'grp_${groupId}_$groupKey',
      scorePercentage: scorePercentage,
      subject: subject,
    );
    return _creditMemberInGroup(
      groupId: groupId,
      userId: uid,
      earned: earned,
      message: earned > 0 ? 'Simulado concluído! +$earned Insights no ranking do grupo.' : null,
    );
  }

  Future<StudyGroupActionResult> saveGroupRoadmap(String groupId, StudyRoadmap roadmap) async {
    await init();
    final uid = currentUserId;
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx == -1) return const StudyGroupActionResult(ok: false, error: 'Grupo não encontrado.');
    final group = _groups[idx];
    final existingIdx = group.sharedRoadmaps.indexWhere(
      (e) => e.sourceId == roadmap.id || e.data.id == roadmap.id,
    );
    if (existingIdx == -1 && !group.canUserEdit(uid)) {
      return const StudyGroupActionResult(
        ok: false,
        error: 'Apenas o líder ou membros com permissão de edição podem criar trilhas no grupo.',
      );
    }
    if (group.memberFor(uid) == null) {
      return const StudyGroupActionResult(ok: false, error: 'Entre no grupo para interagir.');
    }

    final now = DateTime.now();
    final list = List<SharedGroupItem<StudyRoadmap>>.from(group.sharedRoadmaps);
    if (existingIdx != -1) {
      final prev = list[existingIdx];
      list[existingIdx] = SharedGroupItem<StudyRoadmap>(
        shareId: prev.shareId,
        sourceId: prev.sourceId,
        sharedByUserId: prev.sharedByUserId,
        sharedByName: prev.sharedByName,
        sharedByHandle: prev.sharedByHandle,
        sharedAt: prev.sharedAt,
        data: roadmap,
      );
    } else {
      list.insert(
        0,
        SharedGroupItem<StudyRoadmap>(
          shareId: 'sh_rm_${now.microsecondsSinceEpoch}',
          sourceId: roadmap.id,
          sharedByUserId: uid,
          sharedByName: currentUserDisplayName,
          sharedByHandle: currentUserHandle,
          sharedAt: now,
          data: roadmap,
        ),
      );
    }
    final updated = group.copyWith(sharedRoadmaps: list, updatedAt: now);
    _groups[idx] = updated;
    _publish();
    await _persist(changedGroup: updated);
    return StudyGroupActionResult(ok: true, group: updated);
  }

  Future<StudyGroupActionResult> deleteGroupRoadmap(String groupId, String roadmapId) async {
    await init();
    final group = groupById(groupId);
    if (group == null) return const StudyGroupActionResult(ok: false, error: 'Grupo não encontrado.');
    final item = group.sharedRoadmaps.where((e) => e.sourceId == roadmapId || e.data.id == roadmapId).firstOrNull;
    if (item == null) return const StudyGroupActionResult(ok: false, error: 'Trilha não encontrada.');
    return removeSharedContent(groupId: groupId, kind: StudyGroupContentKind.roadmap, shareId: item.shareId);
  }

  Future<StudyGroupActionResult> recordGroupRoadmapStepDone(
    String groupId,
    String roadmapId,
    String stepId,
    String stepTitle,
  ) async {
    await init();
    final uid = currentUserId;
    final group = groupById(groupId);
    if (group == null || group.memberFor(uid) == null) {
      return const StudyGroupActionResult(ok: false, error: 'Entre no grupo para pontuar.');
    }
    final earned = ShopService.instance.awardGroupStudyReward(
      groupId: groupId,
      source: 'group_roadmap',
      rawAmount: 5,
      description: 'Etapa concluída no grupo "${group.name}" · $stepTitle',
      idempotentId: 'grp_rm:$groupId:$uid:$roadmapId:$stepId',
    );
    return _creditMemberInGroup(
      groupId: groupId,
      userId: uid,
      earned: earned,
      message: earned > 0 ? 'Etapa concluída! +$earned Insights no ranking do grupo.' : null,
    );
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    _loaded = true;
    _groups.clear();
    _publish();
    await _persist();
  }
}
