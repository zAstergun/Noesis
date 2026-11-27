import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/localization/noesis_l10n.dart';
import '../../../core/shop_service.dart';
import '../../../core/supabase_service.dart';
import '../../quizzes/data/saved_exams_store_stub.dart'
    if (dart.library.io) '../../quizzes/data/saved_exams_store_io.dart'
    if (dart.library.js_interop) '../../quizzes/data/saved_exams_store_web.dart' as local_store;
import '../../ranking/data/ranking_service.dart';
import '../../study_groups/data/study_groups_service.dart';
import '../models/user_profile_model.dart';

/// Gerencia perfis públicos, busca por `@usuario`, relacionamentos de seguir
/// e conexões mútuas (tratadas internamente como "amigos" para facilitar
/// sugestões e convites rápidos em grupos de estudo).
class SocialConnectionsService {
  SocialConnectionsService._();
  static final SocialConnectionsService instance = SocialConnectionsService._();

  static const String _storageKey = 'noesis_social_connections_v1';

  final ValueNotifier<SocialGraphState> stateNotifier = ValueNotifier<SocialGraphState>(
    SocialGraphState(
      currentUserProfile: PublicUserProfile(
        userId: 'local_user',
        username: NoesisL10n.tr('estudante'),
        displayName: NoesisL10n.tr('Estudante'),
        isCurrentUser: true,
      ),
      directory: const [],
      followingIds: const {},
      followingUsernames: const {},
      incomingFollowerIds: const {},
      incomingFollowerUsernames: const {},
      isLoading: true,
    ),
  );

  bool _loaded = false;
  bool _listeningUpstream = false;

  final Set<String> _followingIds = <String>{};
  final Set<String> _followingUsernames = <String>{};
  final Set<String> _incomingFollowerIds = <String>{};
  final Set<String> _incomingFollowerUsernames = <String>{};
  final List<PublicUserProfile> _customDirectoryEntries = <PublicUserProfile>[];
  List<PublicUserProfile> _remoteProfiles = const [];

  void _ensureListeners() {
    if (_listeningUpstream) return;
    _listeningUpstream = true;
    SupabaseService.userProfileNotifier.addListener(_onUpstreamChanged);
    SupabaseService.isVipNotifier.addListener(_onUpstreamChanged);
    RankingService.instance.boardNotifier.addListener(_onUpstreamChanged);
    StudyGroupsService.instance.groupsNotifier.addListener(_onUpstreamChanged);
    ShopService.instance.equippedBannerIdNotifier.addListener(_onUpstreamChanged);
    ShopService.instance.equippedFrameIdNotifier.addListener(_onUpstreamChanged);
    ShopService.instance.equippedTitleIdNotifier.addListener(_onUpstreamChanged);
  }

  void _onUpstreamChanged() {
    if (_loaded) {
      _publishState();
    }
  }

  Future<void> init({bool force = false}) async {
    _ensureListeners();
    if (_loaded && !force) return;
    _loaded = true;

    try {
      final raw = await local_store.readSavedExamsRaw(_storageKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _followingIds
            ..clear()
            ..addAll((decoded['following_ids'] as List? ?? const []).map((e) => e.toString()));
          _followingUsernames
            ..clear()
            ..addAll((decoded['following_usernames'] as List? ?? const [])
                .map((e) => SupabaseService.sanitizeUsername(e.toString()))
                .where((e) => e.isNotEmpty));
          _incomingFollowerIds
            ..clear()
            ..addAll((decoded['incoming_follower_ids'] as List? ?? const []).map((e) => e.toString()));
          _incomingFollowerUsernames
            ..clear()
            ..addAll((decoded['incoming_follower_usernames'] as List? ?? const [])
                .map((e) => SupabaseService.sanitizeUsername(e.toString()))
                .where((e) => e.isNotEmpty));
        }
      }
    } catch (_) {}

    await refreshRemoteProfiles();
    _publishState();
  }

  Future<void> refreshRemoteProfiles() async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      _remoteProfiles = const [];
      return;
    }

    try {
      final rows = await SupabaseService.client
          .from('profiles')
          .select('id, full_name, channel, avatar_url, bio, is_vip, stats')
          .limit(100);
      final parsed = _parseRemoteProfileRows(rows as List, user.id);
      _remoteProfiles = parsed;
    } catch (_) {
      _remoteProfiles = const [];
    }
  }

  List<PublicUserProfile> _parseRemoteProfileRows(List<dynamic> rows, String currentUid) {
    final currentHandle = SupabaseService.sanitizeUsername(
      (SupabaseService.userProfileNotifier.value?['channel'] ?? '').toString(),
    );
    final parsed = <PublicUserProfile>[];
    for (final raw in rows) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final id = (map['id'] ?? '').toString().trim();
      final handle = SupabaseService.sanitizeUsername((map['channel'] ?? '').toString());
      if (id.isEmpty) continue;

      final stats = map['stats'] is Map
          ? Map<String, dynamic>.from(map['stats'] as Map)
          : const <String, dynamic>{};
      final remoteFollowing = (stats['noesis_following_ids'] as List? ?? const [])
          .map((e) => e.toString())
          .toSet();
      final remoteFollowingHandles = (stats['noesis_following_usernames'] as List? ?? const [])
          .map((e) => SupabaseService.sanitizeUsername(e.toString()))
          .toSet();

      final followsMe = remoteFollowing.contains(currentUid) ||
          (currentHandle.isNotEmpty && remoteFollowingHandles.contains(currentHandle));
      if (followsMe) {
        _incomingFollowerIds.add(id);
        if (handle.isNotEmpty) _incomingFollowerUsernames.add(handle);
      }

      parsed.add(
        PublicUserProfile(
          userId: id,
          username: handle.isEmpty ? NoesisL10n.tr('estudante') : handle,
          displayName: (map['full_name'] ?? NoesisL10n.tr('Estudante')).toString().trim(),
          avatarUrl: map['avatar_url']?.toString(),
          bio: map['bio']?.toString(),
          isVip: map['is_vip'] == true,
          isCurrentUser: id == currentUid,
          eloIndex: (stats['noesis_ranking_elo_index'] as num?)?.toInt() ?? 0,
          weeklyInsights: (stats['noesis_ranking_weekly_insights'] as num?)?.toInt() ?? 0,
          weeklyMinutes: (stats['noesis_ranking_weekly_minutes'] as num?)?.toInt() ?? 0,
          streakDays: (stats['noesis_ranking_streak_days'] as num?)?.toInt() ?? 0,
          followersCount: (stats['noesis_followers_count'] as num?)?.toInt() ?? 0,
          followingCount: remoteFollowing.length,
          followsCurrentUser: followsMe,
        ),
      );
    }
    return parsed;
  }

  /// Pesquisa estudantes remotamente no Supabase sob demanda caso esteja autenticado.
  Future<void> searchRemoteProfilesOnDemand(String query) async {
    final user = SupabaseService.currentUser;
    if (user == null) return;
    final cleanQ = query.trim().replaceFirst(RegExp(r'^@+'), '');
    if (cleanQ.length < 2) return;

    try {
      final safe = cleanQ
          .replaceAll(RegExp(r'[^a-zA-Z0-9_\-\sÀ-ÿ]'), '')
          .trim();
      if (safe.length < 2) return;
      final rows = await SupabaseService.client
          .from('profiles')
          .select('id, full_name, channel, avatar_url, bio, is_vip, stats')
          .or('channel.ilike.%$safe%,full_name.ilike.%$safe%')
          .limit(20);
      final found = _parseRemoteProfileRows(rows as List, user.id);
      if (found.isEmpty) return;

      final mergedById = <String, PublicUserProfile>{
        for (final p in _remoteProfiles) p.userId: p,
      };
      for (final p in found) {
        mergedById[p.userId] = p;
      }
      _remoteProfiles = mergedById.values.toList();
      _publishState();
    } catch (_) {}
  }

  PublicUserProfile buildCurrentUserProfile() {
    final raw = SupabaseService.userProfileNotifier.value;
    final uid = SupabaseService.currentUser?.id ?? 'local_user';
    final rawName = (raw?['full_name'] ?? '').toString().trim();
    final handle = SupabaseService.sanitizeUsername((raw?['channel'] ?? '').toString());
    final board = RankingService.instance.boardNotifier.value;
    final currentCompetitor = board.standings.where((c) => c.isCurrentUser).firstOrNull;

    final shop = ShopService.instance;

    final bannerId = shop.equippedBannerIdNotifier.value;
    final frameId = shop.equippedFrameIdNotifier.value;
    final titleId = shop.equippedTitleIdNotifier.value;
    final groupSubjects = StudyGroupsService.instance.groupsNotifier.value
        .map((g) => g.subject.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .take(3)
        .toList();

    return PublicUserProfile(
      userId: uid,
      username: handle.isEmpty ? NoesisL10n.tr('estudante') : handle,
      displayName: rawName.isEmpty ? NoesisL10n.tr('Estudante') : rawName,
      avatarUrl: raw?['avatar_url']?.toString(),
      bio: raw?['bio']?.toString(),
      isVip: SupabaseService.isCurrentUserVip,
      isCurrentUser: true,
      eloIndex: board.currentEloIndex,
      bestEloIndex: board.bestEloIndex,
      rankingRank: board.currentUserRank,
      accumulatedScore: board.accumulatedRankingScore,
      top3Finishes: board.top3Finishes,
      weeklyInsights: board.currentUserWeeklyInsights,
      weeklyMinutes: currentCompetitor?.weeklyMinutes ?? 0,
      streakDays: currentCompetitor?.streakDays ?? 0,
      followersCount: _incomingFollowerIds.length,
      followingCount: _followingIds.length,
      followsCurrentUser: false,
      equippedBannerId: bannerId != null && shop.isProfileItemUnlocked(bannerId) ? bannerId : null,
      equippedFrameId: frameId != null && shop.isProfileItemUnlocked(frameId) ? frameId : null,
      equippedTitleId: titleId != null && shop.isProfileItemUnlocked(titleId) ? titleId : null,
      focusSubjects: groupSubjects,
    );
  }

  List<PublicUserProfile> _buildMergedDirectory(PublicUserProfile currentUser) {
    final byHandle = <String, PublicUserProfile>{};
    final byId = <String, PublicUserProfile>{};

    void mergeProfile(PublicUserProfile candidate) {
      if (candidate.userId == currentUser.userId || candidate.isCurrentUser) return;
      final cleanHandle = SupabaseService.sanitizeUsername(candidate.username);
      final followsMe = candidate.followsCurrentUser ||
          _incomingFollowerIds.contains(candidate.userId) ||
          (cleanHandle.isNotEmpty && _incomingFollowerUsernames.contains(cleanHandle));
      final existing = byId[candidate.userId] ?? (cleanHandle.isNotEmpty ? byHandle[cleanHandle] : null);

      final enriched = (existing == null)
          ? candidate.copyWith(followsCurrentUser: followsMe)
          : existing.copyWith(
              displayName: candidate.displayName.isNotEmpty ? candidate.displayName : existing.displayName,
              avatarUrl: candidate.avatarUrl ?? existing.avatarUrl,
              bio: (candidate.bio ?? '').isNotEmpty ? candidate.bio : existing.bio,
              isVip: existing.isVip || candidate.isVip,
              eloIndex: candidate.eloIndex > existing.eloIndex ? candidate.eloIndex : existing.eloIndex,
              weeklyInsights: candidate.weeklyInsights > existing.weeklyInsights
                  ? candidate.weeklyInsights
                  : existing.weeklyInsights,
              weeklyMinutes: candidate.weeklyMinutes > existing.weeklyMinutes
                  ? candidate.weeklyMinutes
                  : existing.weeklyMinutes,
              streakDays: candidate.streakDays > existing.streakDays
                  ? candidate.streakDays
                  : existing.streakDays,
              followsCurrentUser: existing.followsCurrentUser || followsMe,
            );

      byId[enriched.userId] = enriched;
      if (cleanHandle.isNotEmpty) {
        byHandle[cleanHandle] = enriched;
      }
    }

    // 1. Competidores do Ranking
    for (final c in RankingService.instance.boardNotifier.value.standings) {
      if (c.isCurrentUser) continue;
      mergeProfile(
        PublicUserProfile(
          userId: c.userId,
          username: SupabaseService.sanitizeUsername(c.username),
          displayName: c.displayName,
          avatarUrl: c.avatarUrl,
          bio: c.bio,
          isVip: c.isVip,
          eloIndex: c.eloIndex,
          weeklyInsights: c.weeklyInsights,
          weeklyMinutes: c.weeklyMinutes,
          streakDays: c.streakDays,
          followersCount: 18 + (c.eloIndex * 7),
          followingCount: 14 + (c.eloIndex * 4),
        ),
      );
    }

    // 3. Membros dos Grupos de Estudo
    for (final g in StudyGroupsService.instance.groupsNotifier.value) {
      for (final m in g.members) {
        if (m.userId == currentUser.userId) continue;
        mergeProfile(
          PublicUserProfile(
            userId: m.userId,
            username: SupabaseService.sanitizeUsername(m.username),
            displayName: m.displayName,
            avatarUrl: m.avatarUrl,
            bio: m.bio,
            isVip: m.isVip,
            weeklyInsights: m.insightsScore,
            weeklyMinutes: m.weeklyMinutes,
            followersCount: 12,
            followingCount: 10,
          ),
        );
      }
    }

    // 4. Perfis remotos do Supabase
    for (final r in _remoteProfiles) {
      mergeProfile(r);
    }

    // 5. Perfis adicionados localmente / em testes
    for (final c in _customDirectoryEntries) {
      mergeProfile(c);
    }

    return byId.values.toList();
  }

  void _publishState() {
    final currentUser = buildCurrentUserProfile();
    final directory = _buildMergedDirectory(currentUser);
    stateNotifier.value = SocialGraphState(
      currentUserProfile: currentUser,
      directory: directory,
      followingIds: Set<String>.unmodifiable(_followingIds),
      followingUsernames: Set<String>.unmodifiable(_followingUsernames),
      incomingFollowerIds: Set<String>.unmodifiable(_incomingFollowerIds),
      incomingFollowerUsernames: Set<String>.unmodifiable(_incomingFollowerUsernames),
      isLoading: false,
    );
  }

  bool isFollowing(String userId, {String? username}) {
    if (_followingIds.contains(userId)) return true;
    if (username != null) {
      final clean = SupabaseService.sanitizeUsername(username);
      if (clean.isNotEmpty && _followingUsernames.contains(clean)) return true;
    }
    return false;
  }

  bool followsCurrentUser(String userId, {String? username}) {
    if (_incomingFollowerIds.contains(userId)) return true;
    if (username != null) {
      final clean = SupabaseService.sanitizeUsername(username);
      if (clean.isNotEmpty && _incomingFollowerUsernames.contains(clean)) return true;
    }
    return false;
  }

  /// Retorna `true` quando ambos os usuários se seguem mutuamente.
  /// Internamente o sistema considera conexões mútuas como "amigos".
  bool isMutualConnection(String userId, {String? username}) {
    return isFollowing(userId, username: username) &&
        followsCurrentUser(userId, username: username);
  }

  /// Lista de conexões mútuas ("amigos" internos do sistema).
  List<PublicUserProfile> get mutualConnections {
    return stateNotifier.value.directory
        .where((p) => isMutualConnection(p.userId, username: p.username))
        .toList();
  }

  /// Sugestões ordenadas para convite rápido de grupo:
  /// conexões mútuas ("amigos" internos) primeiro, depois seguidos, depois seguidores.
  List<PublicUserProfile> inviteSuggestionsForGroup({
    Set<String> excludeUserIds = const {},
    Set<String> excludeUsernames = const {},
    String query = '',
  }) {
    final q = SupabaseService.sanitizeUsername(query);
    final rawQ = query.trim().toLowerCase();

    final candidates = stateNotifier.value.directory.where((p) {
      if (excludeUserIds.contains(p.userId)) return false;
      final clean = SupabaseService.sanitizeUsername(p.username);
      if (excludeUsernames.contains(clean)) return false;

      if (q.isEmpty && rawQ.isEmpty) {
        return isFollowing(p.userId, username: clean) ||
            followsCurrentUser(p.userId, username: clean);
      }
      return clean.contains(q) ||
          (rawQ.isNotEmpty && p.displayName.toLowerCase().contains(rawQ));
    }).toList();

    candidates.sort((a, b) {
      final aMutual = isMutualConnection(a.userId, username: a.username) ? 0 : 1;
      final bMutual = isMutualConnection(b.userId, username: b.username) ? 0 : 1;
      if (aMutual != bMutual) return aMutual.compareTo(bMutual);

      final aFollows = isFollowing(a.userId, username: a.username) ? 0 : 1;
      final bFollows = isFollowing(b.userId, username: b.username) ? 0 : 1;
      if (aFollows != bFollows) return aFollows.compareTo(bFollows);

      return a.displayName.compareTo(b.displayName);
    });
    return candidates;
  }

  /// Busca perfis públicos pelo `@usuario` (ou nome), priorizando correspondência exata de `@`.
  List<PublicUserProfile> searchProfilesByHandle(String query) {
    final cleanQ = SupabaseService.sanitizeUsername(query);
    final rawQ = query.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();
    final dir = stateNotifier.value.directory;

    if (cleanQ.isEmpty && rawQ.isEmpty) {
      final sorted = List<PublicUserProfile>.from(dir);
      sorted.sort((a, b) {
        final aMutual = isMutualConnection(a.userId, username: a.username) ? 0 : 1;
        final bMutual = isMutualConnection(b.userId, username: b.username) ? 0 : 1;
        if (aMutual != bMutual) return aMutual.compareTo(bMutual);
        final aFollow = isFollowing(a.userId, username: a.username) ? 0 : 1;
        final bFollow = isFollowing(b.userId, username: b.username) ? 0 : 1;
        if (aFollow != bFollow) return aFollow.compareTo(bFollow);
        return b.weeklyInsights.compareTo(a.weeklyInsights);
      });
      return sorted;
    }

    final matches = dir.where((p) {
      final handle = SupabaseService.sanitizeUsername(p.username);
      final name = p.displayName.toLowerCase();
      return (cleanQ.isNotEmpty && handle.contains(cleanQ)) ||
          (rawQ.isNotEmpty && (handle.contains(rawQ) || name.contains(rawQ)));
    }).toList();

    matches.sort((a, b) {
      final aHandle = SupabaseService.sanitizeUsername(a.username);
      final bHandle = SupabaseService.sanitizeUsername(b.username);
      final aExact = aHandle == cleanQ ? 0 : (aHandle.startsWith(cleanQ) ? 1 : 2);
      final bExact = bHandle == cleanQ ? 0 : (bHandle.startsWith(cleanQ) ? 1 : 2);
      if (aExact != bExact) return aExact.compareTo(bExact);
      return b.weeklyInsights.compareTo(a.weeklyInsights);
    });
    return matches;
  }

  PublicUserProfile? findByUserOrHandle({String? userId, String? username}) {
    final cleanHandle = username != null ? SupabaseService.sanitizeUsername(username) : '';
    final state = stateNotifier.value;
    if (userId == state.currentUserProfile.userId ||
        (cleanHandle.isNotEmpty && cleanHandle == state.currentUserProfile.username)) {
      return state.currentUserProfile;
    }
    for (final p in state.directory) {
      if (userId != null && userId.isNotEmpty && p.userId == userId) return p;
      if (cleanHandle.isNotEmpty && SupabaseService.sanitizeUsername(p.username) == cleanHandle) {
        return p;
      }
    }
    return null;
  }

  Future<void> toggleFollow(PublicUserProfile target) async {
    await init();
    if (target.isCurrentUser || target.userId == stateNotifier.value.currentUserProfile.userId) {
      return;
    }
    final clean = SupabaseService.sanitizeUsername(target.username);
    final currentlyFollowing = isFollowing(target.userId, username: clean);
    if (currentlyFollowing) {
      _followingIds.remove(target.userId);
      if (clean.isNotEmpty) _followingUsernames.remove(clean);
    } else {
      _followingIds.add(target.userId);
      if (clean.isNotEmpty) _followingUsernames.add(clean);
    }
    _publishState();
    await _persist();
  }

  Future<void> _persist() async {
    final payload = {
      'following_ids': _followingIds.toList(),
      'following_usernames': _followingUsernames.toList(),
      'incoming_follower_ids': _incomingFollowerIds.toList(),
      'incoming_follower_usernames': _incomingFollowerUsernames.toList(),
    };
    try {
      await local_store.writeSavedExamsRaw(_storageKey, jsonEncode(payload));
    } catch (_) {}

    final user = SupabaseService.currentUser;
    if (user != null) {
      try {
        final existing = await SupabaseService.client
            .from('profiles')
            .select('stats')
            .eq('id', user.id)
            .maybeSingle();
        final mergedStats = existing?['stats'] is Map
            ? Map<String, dynamic>.from(existing!['stats'] as Map)
            : <String, dynamic>{};
        mergedStats['noesis_following_ids'] = _followingIds.toList();
        mergedStats['noesis_following_usernames'] = _followingUsernames.toList();
        mergedStats['noesis_followers_count'] = _incomingFollowerIds.length;
        await SupabaseService.client.from('profiles').upsert({
          'id': user.id,
          'stats': mergedStats,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }
  }

  @visibleForTesting
  void registerDirectoryProfileForTesting(PublicUserProfile profile) {
    _customDirectoryEntries.removeWhere(
      (e) => e.userId == profile.userId || e.username == profile.username,
    );
    _customDirectoryEntries.add(profile);
    if (profile.followsCurrentUser) {
      _incomingFollowerIds.add(profile.userId);
      final clean = SupabaseService.sanitizeUsername(profile.username);
      if (clean.isNotEmpty) _incomingFollowerUsernames.add(clean);
    }
    _publishState();
  }

  @visibleForTesting
  void setIncomingFollowerForTesting(
    String userId, {
    String? username,
    required bool followsMe,
  }) {
    final clean = username != null ? SupabaseService.sanitizeUsername(username) : '';
    if (followsMe) {
      _incomingFollowerIds.add(userId);
      if (clean.isNotEmpty) _incomingFollowerUsernames.add(clean);
    } else {
      _incomingFollowerIds.remove(userId);
      if (clean.isNotEmpty) _incomingFollowerUsernames.remove(clean);
    }
    _publishState();
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    _ensureListeners();
    _loaded = true;
    _followingIds.clear();
    _followingUsernames.clear();
    _incomingFollowerIds.clear();
    _incomingFollowerUsernames.clear();
    _customDirectoryEntries.clear();
    _remoteProfiles = const [];
    try {
      await local_store.writeSavedExamsRaw(_storageKey, '');
    } catch (_) {}
    _publishState();
  }
}
