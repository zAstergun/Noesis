import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../core/shop_service.dart';
import '../../core/supabase_service.dart';
import '../../core/theme.dart';
import '../../main.dart';
import '../../widgets/insight_icon.dart';
import '../../widgets/profile_settings_dialog.dart';
import '../../widgets/vip_privileges.dart';
import '../performance/data/performance_analytics_service.dart';
import '../performance/models/performance_report_model.dart';
import '../ranking/data/ranking_service.dart';
import '../ranking/models/ranking_league_model.dart';
import '../ranking/widgets/noesis_elo_badge.dart';
import '../study_groups/data/study_groups_service.dart';
import '../study_groups/models/study_group_model.dart';
import '../study_groups/widgets/study_group_modals.dart';
import '../tracker/dashboard_analytics.dart';
import 'data/social_connections_service.dart';
import 'models/profile_achievements.dart';
import 'models/profile_cosmetics.dart';
import 'models/user_profile_model.dart';
import 'widgets/profile_cosmetic_widgets.dart';
import 'widgets/public_profile_modal.dart';

enum _ProfileDirectoryFilter { all, following, followers }

/// Página **Perfil** sob a seção Conta:
/// - Barra de busca no canto superior direito com popover animado estilo anexo do chat
/// - Cartão do próprio perfil com visualização pública e customizações compráveis com Insights
/// - Área minimalista de Seguidores / Seguindo para abrir o perfil das pessoas
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final LayerLink _searchLayerLink = LayerLink();
  final Object _searchTapGroupId = Object();

  late final AnimationController _searchPopoverCtrl;
  OverlayEntry? _searchOverlayEntry;
  bool _popoverVisible = false;
  bool _isSearchingRemote = false;
  Timer? _remoteSearchDebounce;
  AccountPerformanceReport? _accountReport;

  @override
  void initState() {
    super.initState();
    _searchPopoverCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 210),
    );
    _searchPopoverCtrl.addStatusListener(_onPopoverAnimStatus);
    _searchFocusNode.addListener(_onSearchFocusChanged);

    SocialConnectionsService.instance.init();
    RankingService.instance.init();
    StudyGroupsService.instance.init();
    ShopService.instance.init();
    _loadAccountSummary();
  }

  Future<void> _loadAccountSummary() async {
    try {
      final report = await PerformanceAnalyticsService.instance.loadReport(
        period: PerformancePeriod.allTime,
      );
      if (!mounted) return;
      setState(() => _accountReport = report);
    } catch (_) {}
  }

  @override
  void dispose() {
    _remoteSearchDebounce?.cancel();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _searchCtrl.dispose();
    _searchPopoverCtrl.removeStatusListener(_onPopoverAnimStatus);
    _searchPopoverCtrl.dispose();
    _removeOverlayEntryImmediately();
    super.dispose();
  }

  void _removeOverlayEntryImmediately() {
    _searchOverlayEntry?.remove();
    _searchOverlayEntry = null;
    _popoverVisible = false;
  }

  void _onPopoverAnimStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && !_popoverVisible) {
      _removeOverlayEntryImmediately();
    }
  }

  void _onSearchFocusChanged() {
    if (!mounted) return;
    if (_searchFocusNode.hasFocus) {
      _openSearchPopover();
    } else if (_searchCtrl.text.trim().isEmpty) {
      _closeSearchPopover();
    }
  }

  void _onSearchQueryChanged(String value) {
    if (!mounted) return;
    setState(() {});
    if (!_popoverVisible && (_searchFocusNode.hasFocus || value.trim().isNotEmpty)) {
      _openSearchPopover();
    } else {
      _searchOverlayEntry?.markNeedsBuild();
    }

    _remoteSearchDebounce?.cancel();
    final clean = value.trim().replaceFirst(RegExp(r'^@+'), '');
    if (SupabaseService.currentUser != null && clean.length >= 2) {
      _remoteSearchDebounce = Timer(const Duration(milliseconds: 260), () async {
        if (!mounted) return;
        setState(() => _isSearchingRemote = true);
        _searchOverlayEntry?.markNeedsBuild();
        await SocialConnectionsService.instance.searchRemoteProfilesOnDemand(value);
        if (!mounted) return;
        setState(() => _isSearchingRemote = false);
        _searchOverlayEntry?.markNeedsBuild();
      });
    }
  }

  void _openSearchPopover() {
    if (!mounted) return;
    if (_searchOverlayEntry == null) {
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) return;
      _searchOverlayEntry = OverlayEntry(
        builder: (overlayCtx) => _buildFloatingSearchPopover(overlayCtx),
      );
      overlay.insert(_searchOverlayEntry!);
    }
    _popoverVisible = true;
    _searchPopoverCtrl.forward();
    _searchOverlayEntry?.markNeedsBuild();
    setState(() {});
  }

  void _closeSearchPopover({bool clearFocus = false}) {
    _popoverVisible = false;
    if (clearFocus && _searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }
    if (_searchPopoverCtrl.status == AnimationStatus.dismissed) {
      _removeOverlayEntryImmediately();
    } else {
      _searchPopoverCtrl.reverse();
    }
    if (mounted) setState(() {});
  }

  void _openEditProfile(PublicUserProfile current) {
    showProfileSettingsDialog(
      context,
      streakDays: current.streakDays,
      onOpenShop: () => RootScreen.switchTab(9),
    );
  }

  Future<void> _openConnectionsModal(_ProfileDirectoryFilter initialFilter) async {
    _closeSearchPopover(clearFocus: true);
    var activeFilter = initialFilter;
    final social = SocialConnectionsService.instance;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        final primaryCol = AsterTheme.primary(dialogCtx);
        final cardCol = isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard;

        return Dialog(
          key: const Key('profile_connections_modal'),
          backgroundColor: cardCol,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
            side: BorderSide(
              color: (isDark ? Colors.white : primaryCol).withValues(alpha: isDark ? 0.08 : 0.14),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
            child: StatefulBuilder(
              builder: (ctx, setModalState) {
                return ValueListenableBuilder<SocialGraphState>(
                  valueListenable: social.stateNotifier,
                  builder: (ctx, state, _) {
                    final directory = social.searchProfilesByHandle('');
                    final list = directory.where((p) {
                      switch (activeFilter) {
                        case _ProfileDirectoryFilter.all:
                          return true;
                        case _ProfileDirectoryFilter.following:
                          return social.isFollowing(p.userId, username: p.username);
                        case _ProfileDirectoryFilter.followers:
                          return social.followsCurrentUser(p.userId, username: p.username);
                      }
                    }).toList();

                    final title = activeFilter == _ProfileDirectoryFilter.following
                        ? 'Seguindo'
                        : activeFilter == _ProfileDirectoryFilter.followers
                            ? 'Seguidores'
                            : 'Explorar Estudantes';

                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: primaryCol.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.people_alt_rounded,
                                  size: 18,
                                  color: primaryCol,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  title,
                                  style: GoogleFonts.manrope(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w900,
                                    color: AsterTheme.text(ctx),
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Fechar',
                                onPressed: () => Navigator.of(ctx).pop(),
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 20,
                                  color: AsterTheme.textMuted(ctx),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              SoftClayChoiceChip(
                                key: const Key('profile_modal_tab_following'),
                                label: 'Seguindo (${state.followingIds.length})',
                                selected: activeFilter == _ProfileDirectoryFilter.following,
                                compact: true,
                                onTap: () => setModalState(
                                  () => activeFilter = _ProfileDirectoryFilter.following,
                                ),
                              ),
                              SoftClayChoiceChip(
                                key: const Key('profile_modal_tab_followers'),
                                label: 'Seguidores (${state.incomingFollowerIds.length})',
                                selected: activeFilter == _ProfileDirectoryFilter.followers,
                                compact: true,
                                onTap: () => setModalState(
                                  () => activeFilter = _ProfileDirectoryFilter.followers,
                                ),
                              ),
                              SoftClayChoiceChip(
                                key: const Key('profile_modal_tab_all'),
                                label: 'Explorar (${state.directory.length})',
                                selected: activeFilter == _ProfileDirectoryFilter.all,
                                compact: true,
                                onTap: () => setModalState(
                                  () => activeFilter = _ProfileDirectoryFilter.all,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Flexible(
                            child: list.isEmpty
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 28,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AsterTheme.surfaceAlt(ctx),
                                      borderRadius: BorderRadius.circular(
                                        AsterConstants.radiusMedium,
                                      ),
                                    ),
                                    child: Text(
                                      activeFilter == _ProfileDirectoryFilter.following
                                          ? 'Você ainda não segue ninguém. Use a barra de pesquisa no canto superior direito ou toque em Explorar.'
                                          : 'Nenhum perfil nesta lista ainda.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.manrope(
                                        fontSize: 12.5,
                                        color: AsterTheme.textMuted(ctx),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: list.length,
                                    itemBuilder: (_, idx) => _buildMinimalPersonRow(
                                      ctx,
                                      profile: list[idx],
                                      social: social,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                ),
                                side: BorderSide(
                                  color: (isDark ? Colors.white : primaryCol).withValues(alpha: 0.18),
                                ),
                              ),
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: Text(
                                'Fechar',
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w800,
                                  color: primaryCol,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingSearchPopover(BuildContext overlayCtx) {
    final screenW = MediaQuery.sizeOf(overlayCtx).width;
    final popoverWidth = (screenW - 24).clamp(260.0, 384.0);
    final isDark = Theme.of(overlayCtx).brightness == Brightness.dark;
    final bg = isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard;
    final primaryCol = AsterTheme.primary(overlayCtx);
    final borderCol = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : primaryCol.withValues(alpha: 0.14);

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_popoverVisible,
        child: CompositedTransformFollower(
          link: _searchLayerLink,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 8),
          showWhenUnlinked: false,
          child: Align(
            alignment: Alignment.topRight,
            child: TapRegion(
              groupId: _searchTapGroupId,
              onTapOutside: (_) => _closeSearchPopover(clearFocus: true),
              child: AnimatedBuilder(
                animation: _searchPopoverCtrl,
                builder: (animCtx, child) {
                  final isClosing = _searchPopoverCtrl.status == AnimationStatus.reverse;
                  final curved = CurvedAnimation(
                    parent: _searchPopoverCtrl,
                    curve: isClosing ? Curves.easeInCubic : Curves.easeOutBack,
                  );
                  final fade = CurvedAnimation(
                    parent: _searchPopoverCtrl,
                    curve: Curves.easeOutCubic,
                  );
                  return FadeTransition(
                    opacity: fade,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.04),
                        end: Offset.zero,
                      ).animate(fade),
                      child: ScaleTransition(
                        alignment: Alignment.topRight,
                        scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
                        child: child,
                      ),
                    ),
                  );
                },
                child: Material(
                  key: const Key('profile_search_popover_menu'),
                  color: Colors.transparent,
                  child: ListenableBuilder(
                    listenable: SocialConnectionsService.instance.stateNotifier,
                    builder: (listCtx, _) {
                      final social = SocialConnectionsService.instance;
                      final query = _searchCtrl.text.trim();
                      final hasQuery = query.isNotEmpty;
                      final matches = social.searchProfilesByHandle(_searchCtrl.text);
                      final visible = hasQuery ? matches : matches.take(5).toList();

                      return Container(
                        width: popoverWidth,
                        constraints: const BoxConstraints(maxHeight: 370),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
                          border: Border.all(color: borderCol),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.14),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 2, 4, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      hasQuery
                                          ? 'RESULTADOS (${matches.length})'
                                          : 'SUGESTÕES DE PERFIS',
                                      style: GoogleFonts.manrope(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                        color: AsterTheme.textMuted(listCtx),
                                      ),
                                    ),
                                  ),
                                  if (_isSearchingRemote)
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 1.8),
                                    )
                                  else if (hasQuery)
                                    InkWell(
                                      onTap: () {
                                        _searchCtrl.clear();
                                        _closeSearchPopover(clearFocus: true);
                                      },
                                      borderRadius: BorderRadius.circular(10),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        child: Text(
                                          'Limpar',
                                          style: GoogleFonts.manrope(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: primaryCol,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (visible.isEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.person_search_rounded,
                                      size: 26,
                                      color: AsterTheme.textMuted(listCtx).withValues(alpha: 0.7),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Nenhum perfil encontrado para "@${query.replaceFirst(RegExp(r'^@+'), '')}"',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AsterTheme.textMuted(listCtx),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Flexible(
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: visible.map((p) {
                                      return _buildPopoverProfileItem(
                                        listCtx,
                                        profile: p,
                                        social: social,
                                        isDark: isDark,
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopoverProfileItem(
    BuildContext ctx, {
    required PublicUserProfile profile,
    required SocialConnectionsService social,
    required bool isDark,
  }) {
    final isFollowing = social.isFollowing(profile.userId, username: profile.username);
    final isMutual = social.isMutualConnection(profile.userId, username: profile.username);
    final followsMe = social.followsCurrentUser(profile.userId, username: profile.username);
    final elo = profile.elo;
    final primaryCol = AsterTheme.primary(ctx);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        key: Key('profile_search_result_${profile.userId}'),
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          _closeSearchPopover(clearFocus: true);
          showPublicUserProfileModal(context, profile: profile);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : AsterTheme.surfaceAlt(ctx).withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              GroupMemberAvatar(
                displayName: profile.displayName,
                avatarUrl: profile.avatarUrl,
                isVip: profile.isVip,
                radius: 17,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AsterTheme.text(ctx),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        NoesisEloBadge(tier: elo, size: 14),
                        if (isMutual) ...[
                          const SizedBox(width: 5),
                          const SoftClayTag(
                            label: 'Mútuo',
                            color: AsterConstants.menta,
                          ),
                        ] else if (followsMe) ...[
                          const SizedBox(width: 5),
                          SoftClayTag(
                            label: 'Segue você',
                            color: primaryCol,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '@${profile.username} · Elo ${elo.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AsterTheme.textMuted(ctx),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SoftClayChoiceChip(
                label: isFollowing ? 'Seguindo' : 'Seguir',
                selected: isFollowing,
                compact: true,
                onTap: () => social.toggleFollow(profile),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final social = SocialConnectionsService.instance;
    final shop = ShopService.instance;
    final ranking = RankingService.instance;
    final groupsSvc = StudyGroupsService.instance;
    final primaryCol = AsterTheme.primary(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: Listenable.merge([
        social.stateNotifier,
        ranking.boardNotifier,
        groupsSvc.groupsNotifier,
        shop.balanceNotifier,
        shop.streakProtectorsNotifier,
        shop.unlockedThemesNotifier,
        shop.unlockedProfileItemsNotifier,
        shop.equippedBannerIdNotifier,
        shop.equippedFrameIdNotifier,
        shop.equippedTitleIdNotifier,
        shop.claimedAchievementsNotifier,
        SupabaseService.isVipNotifier,
      ]),
      builder: (context, _) {
        final state = social.stateNotifier.value;
        final board = ranking.boardNotifier.value;
        final groups = groupsSvc.groupsNotifier.value;
        final me = state.currentUserProfile;
        final elo = me.elo;

        final hasActiveSearch = _searchCtrl.text.trim().isNotEmpty;

        return SingleChildScrollView(
          key: const Key('profile_screen_root'),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 36.0 : 16.0,
            vertical: 18.0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── Cabeçalho: "Perfil" à esquerda + Barra de busca ancorada no canto superior direito ───
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const NoesisCollapsedMenuSpacer(width: 82),
                      Expanded(
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: primaryCol.withValues(alpha: 0.13),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.person_rounded,
                                    size: 21,
                                    color: primaryCol,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Perfil',
                                      style: GoogleFonts.manrope(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: AsterTheme.text(context),
                                      ),
                                    ),
                                    Text(
                                      '@${me.username}',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: AsterTheme.textMuted(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TapRegion(
                                  groupId: _searchTapGroupId,
                                  child: CompositedTransformTarget(
                                    link: _searchLayerLink,
                                    child: AnimatedContainer(
                                      key: const Key('profile_top_right_search_wrapper'),
                                      duration: const Duration(milliseconds: 180),
                                      curve: Curves.easeOutCubic,
                                      width: _popoverVisible
                                          ? (isDesktop ? 320 : 230)
                                          : (isDesktop ? 270 : 200),
                                      child: TextField(
                                        key: const Key('profile_search_field'),
                                        controller: _searchCtrl,
                                        focusNode: _searchFocusNode,
                                        onTap: _openSearchPopover,
                                        onChanged: _onSearchQueryChanged,
                                        style: GoogleFonts.manrope(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AsterTheme.text(context),
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          hintText: 'Buscar perfil (@...)',
                                          hintStyle: GoogleFonts.manrope(
                                            fontSize: 12.5,
                                            color: AsterTheme.textMuted(context),
                                          ),
                                          prefixIcon: AnimatedRotation(
                                            duration: const Duration(milliseconds: 210),
                                            curve: Curves.easeOutCubic,
                                            turns: _popoverVisible ? 0.04 : 0.0,
                                            child: Icon(
                                              Icons.search_rounded,
                                              size: 18,
                                              color: _popoverVisible
                                                  ? primaryCol
                                                  : AsterTheme.textMuted(context),
                                            ),
                                          ),
                                          prefixIconConstraints: const BoxConstraints(
                                            minWidth: 38,
                                            minHeight: 38,
                                          ),
                                          suffixIcon: (hasActiveSearch || _popoverVisible)
                                              ? IconButton(
                                                  tooltip: 'Fechar busca',
                                                  icon: const Icon(Icons.close_rounded, size: 17),
                                                  onPressed: () {
                                                    _searchCtrl.clear();
                                                    _closeSearchPopover(clearFocus: true);
                                                  },
                                                )
                                              : null,
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          filled: true,
                                          fillColor: AsterTheme.card(context),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                            borderSide: BorderSide(
                                              color: primaryCol.withValues(alpha: 0.16),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                            borderSide: BorderSide(
                                              color: _popoverVisible
                                                  ? primaryCol.withValues(alpha: 0.55)
                                                  : (isDark ? Colors.white : primaryCol)
                                                      .withValues(alpha: isDark ? 0.10 : 0.16),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                            borderSide: BorderSide(color: primaryCol, width: 1.6),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  tooltip: 'Atualizar perfis',
                                  onPressed: () {
                                    social.init(force: true);
                                    _loadAccountSummary();
                                  },
                                  icon: const Icon(Icons.refresh_rounded, size: 19),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ─── Card Principal do Próprio Perfil (com Capa, Moldura e Título equipados) ───
                  SoftClayCard(
                    key: const Key('profile_own_card'),
                    padding: EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                height: 84,
                                width: double.infinity,
                                decoration: buildProfileBannerDecoration(
                                  bannerId: me.equippedBannerId,
                                  elo: elo,
                                  fallbackPrimary: primaryCol,
                                  isDark: isDark,
                                ),
                              ),
                              Positioned(
                                right: 16,
                                top: 14,
                                child: Wrap(
                                  spacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      key: const Key('profile_preview_public_button'),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor:
                                            AsterTheme.card(context).withValues(alpha: 0.90),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        side: BorderSide(
                                          color: primaryCol.withValues(alpha: 0.22),
                                        ),
                                      ),
                                      onPressed: () => showPublicUserProfileModal(
                                        context,
                                        profile: me,
                                        previewNotice: 'Como outros usuários veem seu perfil',
                                        onEditOwnProfile: () => _openEditProfile(me),
                                      ),
                                      icon: const Icon(Icons.visibility_rounded, size: 15),
                                      label: Text(
                                        'Ver Perfil Público',
                                        style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    SoftClayPillButton(
                                      key: const Key('profile_edit_button'),
                                      text: 'Editar',
                                      icon: Icons.edit_rounded,
                                      onPressed: () => _openEditProfile(me),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                            child: Transform.translate(
                              offset: const Offset(0, -28),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          ProfileFramedAvatar(
                                            displayName: me.displayName,
                                            avatarUrl: me.avatarUrl,
                                            isVip: me.isVip,
                                            elo: elo,
                                            frameId: me.equippedFrameId,
                                            radius: 36,
                                          ),
                                          Positioned(
                                            right: -2,
                                            bottom: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(2.5),
                                              decoration: BoxDecoration(
                                                color: AsterTheme.card(context),
                                                shape: BoxShape.circle,
                                              ),
                                              child: NoesisEloBadge(
                                                tier: elo,
                                                size: 24,
                                                highlighted: true,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 32),
                                          child: Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Text(
                                                me.displayName,
                                                style: GoogleFonts.manrope(
                                                  fontSize: 19,
                                                  fontWeight: FontWeight.w900,
                                                  color: AsterTheme.text(context),
                                                ),
                                              ),
                                              if (me.isVip)
                                                const VipBadgePill(
                                                  size: VipBadgeSize.xs,
                                                  interactive: false,
                                                ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 9,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: elo.badgeColor.withValues(alpha: 0.14),
                                                  borderRadius: BorderRadius.circular(
                                                    AsterConstants.radiusPill,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    NoesisEloBadge(tier: elo, size: 15),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Elo ${elo.name}',
                                                      style: GoogleFonts.manrope(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w800,
                                                        color: elo.accentColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if ((me.equippedTitleId ?? '').isNotEmpty)
                                                ProfileTitleBadge(titleId: me.equippedTitleId),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    (me.bio ?? '').trim().isNotEmpty
                                        ? me.bio!.trim()
                                        : 'Adicione uma bio em Editar para mostrar o que você está estudando.',
                                    style: GoogleFonts.manrope(
                                      fontSize: 12.5,
                                      color: AsterTheme.textMuted(context),
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _minimalStatPill(
                                        context,
                                        key: const Key('profile_stat_following'),
                                        count: '${state.followingIds.length}',
                                        label: 'Seguindo',
                                        accent: primaryCol,
                                        onTap: () => _openConnectionsModal(
                                          _ProfileDirectoryFilter.following,
                                        ),
                                      ),
                                      _minimalStatPill(
                                        context,
                                        key: const Key('profile_stat_followers'),
                                        count: '${state.incomingFollowerIds.length}',
                                        label: 'Seguidores',
                                        accent: AsterConstants.menta,
                                        onTap: () => _openConnectionsModal(
                                          _ProfileDirectoryFilter.followers,
                                        ),
                                      ),
                                      _minimalStatPill(
                                        context,
                                        count: '+${me.weeklyInsights}',
                                        label: 'Insights/sem',
                                        accent: AsterConstants.menta,
                                        trailing: const InsightCoinIcon(size: 13),
                                      ),
                                      _minimalStatPill(
                                        context,
                                        count: DashboardAnalytics.formatReadableDuration(
                                          me.weeklyMinutes,
                                        ),
                                        label: '${me.streakDays}d streak',
                                        accent: elo.accentColor,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── Trajetória Noética & Identidade Equipada ───
                  LayoutBuilder(
                    builder: (ctx, box) {
                      final twoCols = box.maxWidth >= 760;
                      final journeyCard = _buildEloJourneyCard(
                        ctx,
                        board: board,
                        elo: elo,
                        primaryCol: primaryCol,
                      );
                      final loadoutCard = _buildEquippedLoadoutCard(
                        ctx,
                        shop: shop,
                        me: me,
                        primaryCol: primaryCol,
                        isDark: isDark,
                      );
                      if (!twoCols) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            journeyCard,
                            const SizedBox(height: 16),
                            loadoutCard,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: journeyCard),
                          const SizedBox(width: 16),
                          Expanded(child: loadoutCard),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // ─── Marcos & Insígnias da Conta ───
                  _buildMilestonesCard(
                    context,
                    me: me,
                    shop: shop,
                    board: board,
                    joinedGroupsCount: groups.length,
                    mutualConnectionsCount: social.mutualConnections.length,
                    report: _accountReport,
                    primaryCol: primaryCol,
                  ),
                  const SizedBox(height: 16),

                  // ─── Acervo de Estudos & Meus Grupos ───
                  LayoutBuilder(
                    key: const Key('profile_portfolio_row'),
                    builder: (ctx, box) {
                      final twoCols = box.maxWidth >= 760;
                      final portfolioCard = _buildStudyPortfolioCard(
                        ctx,
                        me: me,
                        report: _accountReport,
                        primaryCol: primaryCol,
                      );
                      final groupsCard = _buildProfileGroupsCard(
                        ctx,
                        groups: groups,
                        primaryCol: primaryCol,
                      );
                      if (!twoCols) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            portfolioCard,
                            const SizedBox(height: 16),
                            groupsCard,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: portfolioCard),
                          const SizedBox(width: 16),
                          Expanded(child: groupsCard),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEloJourneyCard(
    BuildContext context, {
    required RankingBoardState board,
    required RankingEloTier elo,
    required Color primaryCol,
  }) {
    final bestElo = board.bestElo;
    final nextTierIndex = (elo.index + 1).clamp(0, RankingEloCatalog.tiers.length - 1);
    final nextTier = RankingEloCatalog.tierAt(nextTierIndex);
    final isMaxTier = elo.index >= RankingEloCatalog.tiers.length - 1;

    return SoftClayCard(
      key: const Key('profile_elo_journey_card'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              NoesisEloBadge(tier: elo, size: 42, highlighted: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Carreira Noética',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AsterTheme.text(context),
                      ),
                    ),
                    Text(
                      'Elo ${elo.name} · ${elo.subtitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: elo.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => RootScreen.switchTab(11),
                child: Text(
                  'Ranking',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: primaryCol,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _compactJourneyCell(
                  context,
                  label: 'Posição atual',
                  value: '#${board.currentUserRank}',
                  color: primaryCol,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _compactJourneyCell(
                  context,
                  label: 'Melhor Elo',
                  value: bestElo.name,
                  color: bestElo.accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _compactJourneyCell(
                  context,
                  label: 'Pontuação acumulada',
                  value: '${board.accumulatedRankingScore} pts',
                  color: AsterConstants.menta,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _compactJourneyCell(
                  context,
                  label: 'Pódios · Permanência',
                  value: '${board.top3Finishes} · ${board.retentionStreakWeeks} sem.',
                  color: AsterTheme.text(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AsterTheme.surfaceAlt(context),
              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
            ),
            child: Row(
              children: [
                Icon(
                  isMaxTier ? Icons.auto_awesome_rounded : Icons.trending_up_rounded,
                  size: 16,
                  color: elo.accentColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isMaxTier
                        ? 'Você atingiu o topo da Escala Noética!'
                        : 'Próximo patamar: Elo ${nextTier.name} (Top ${elo.promotionSlots} da semana)',
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AsterTheme.textMuted(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactJourneyCell(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: AsterTheme.surfaceAlt(context),
        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AsterTheme.textMuted(context),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquippedLoadoutCard(
    BuildContext context, {
    required ShopService shop,
    required PublicUserProfile me,
    required Color primaryCol,
    required bool isDark,
  }) {
    final banner = ProfileCosmeticsCatalog.findById(me.equippedBannerId) ??
        ProfileCosmeticsCatalog.banners.first;
    final frame = ProfileCosmeticsCatalog.findById(me.equippedFrameId) ??
        ProfileCosmeticsCatalog.frames.first;
    final title = ProfileCosmeticsCatalog.findById(me.equippedTitleId) ??
        ProfileCosmeticsCatalog.titles.first;
    final unlockedCosmeticsCount = ProfileCosmeticsCatalog.all
        .where((i) => !i.isFree && shop.isProfileItemUnlocked(i.id))
        .length;
    final totalPaidCosmetics = ProfileCosmeticsCatalog.all.where((i) => !i.isFree).length;

    return SoftClayCard(
      key: const Key('profile_equipped_loadout_card'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primaryCol.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.style_rounded, size: 18, color: primaryCol),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Identidade & Acervo',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AsterTheme.text(context),
                      ),
                    ),
                    Text(
                      '$unlockedCosmeticsCount/$totalPaidCosmetics itens personalizados · ${shop.unlockedThemes.length}/${AsterTheme.availableThemes.length} temas',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        color: AsterTheme.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _equippedSlotRow(
            context,
            slotLabel: 'Capa',
            item: banner,
            isDark: isDark,
          ),
          const SizedBox(height: 6),
          _equippedSlotRow(
            context,
            slotLabel: 'Moldura',
            item: frame,
            isDark: isDark,
          ),
          const SizedBox(height: 6),
          _equippedSlotRow(
            context,
            slotLabel: 'Título',
            item: title,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AsterTheme.surfaceAlt(context),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                  ),
                  child: Row(
                    children: [
                      const InsightCoinIcon(size: 14),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${shop.balance} Insights · ${shop.streakProtectors}/${shop.maxStreakProtectors} selos',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AsterTheme.text(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _openEditProfile(me),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  ),
                ),
                child: Text(
                  'Trocar',
                  style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: () => RootScreen.switchTab(9),
                child: Text(
                  'Loja',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: primaryCol,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _equippedSlotRow(
    BuildContext context, {
    required String slotLabel,
    required ProfileCosmeticItem item,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AsterTheme.surfaceAlt(context),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          if (item.category == ProfileCosmeticCategory.banner &&
              item.gradientColors.isNotEmpty)
            Container(
              width: 24,
              height: 16,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                gradient: LinearGradient(colors: item.gradientColors),
              ),
            )
          else
            Icon(item.icon, size: 16, color: item.accentColor),
          const SizedBox(width: 10),
          Text(
            slotLabel,
            style: GoogleFonts.manrope(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AsterTheme.textMuted(context),
            ),
          ),
          const Spacer(),
          Text(
            item.name,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AsterTheme.text(context),
            ),
          ),
          if (item.isVipOnly) ...[
            const SizedBox(width: 5),
            const VipCrownIcon(size: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildMilestonesCard(
    BuildContext context, {
    required PublicUserProfile me,
    required ShopService shop,
    required RankingBoardState board,
    required int joinedGroupsCount,
    required int mutualConnectionsCount,
    required AccountPerformanceReport? report,
    required Color primaryCol,
  }) {
    final achievements = ProfileAchievementsCatalog.evaluateForAccount(
      me: me,
      totalQuizQuestionsAnswered: shop.totalQuizQuestionsAnswered,
      totalBestEloIndex: board.bestEloIndex,
      top3Finishes: board.top3Finishes,
      joinedGroupsCount: joinedGroupsCount,
      mutualConnectionsCount: mutualConnectionsCount,
      equippedBannerId: shop.equippedBannerIdNotifier.value,
      equippedFrameId: shop.equippedFrameIdNotifier.value,
      equippedTitleId: shop.equippedTitleIdNotifier.value,
      report: report,
      primaryCol: primaryCol,
    );

    final unlockedCount = achievements.where((m) => m.unlocked).length;
    final claimable =
        achievements.where((m) => m.unlocked && !shop.isAchievementClaimed(m.id)).toList();
    final claimableTotal = claimable.fold<int>(0, (sum, m) => sum + m.rewardInsights);

    return SoftClayCard(
      key: const Key('profile_milestones_card'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.military_tech_rounded, size: 19, color: primaryCol),
                  const SizedBox(width: 8),
                  Text(
                    'Marcos & Conquistas da Conta',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AsterTheme.text(context),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (claimable.isNotEmpty)
                    SoftClayPillButton(
                      key: const Key('achievements_claim_all_btn'),
                      text: 'Resgatar Tudo (+$claimableTotal)',
                      icon: Icons.redeem_rounded,
                      onPressed: () {
                        for (final ach in claimable) {
                          shop.claimAchievementReward(
                            achievementId: ach.id,
                            title: ach.title,
                            amount: ach.rewardInsights,
                          );
                        }
                      },
                    ),
                  SoftClayTag(
                    label: '$unlockedCount/${achievements.length} concluídos',
                    color: unlockedCount > 0 ? AsterConstants.menta : primaryCol,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (ctx, box) {
              final cols = box.maxWidth >= 780 ? 3 : (box.maxWidth >= 460 ? 2 : 1);
              const gap = 10.0;
              final itemW = (box.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: achievements.map((m) {
                  final done = m.unlocked;
                  final claimed = shop.isAchievementClaimed(m.id);
                  final canClaim = done && !claimed;

                  return SizedBox(
                    width: itemW,
                    child: Container(
                      key: Key('profile_achievement_${m.id}'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AsterTheme.surfaceAlt(ctx),
                        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                        border: Border.all(
                          color: (canClaim || claimed ? AsterConstants.menta : m.color).withValues(
                            alpha: canClaim ? 0.65 : (claimed ? 0.36 : 0.14),
                          ),
                          width: canClaim ? 1.4 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(m.icon, size: 16, color: done ? AsterConstants.menta : m.color),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  m.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.manrope(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: AsterTheme.text(ctx),
                                  ),
                                ),
                              ),
                              Text(
                                m.statusLabel,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: done ? AsterConstants.menta : m.color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            m.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: AsterTheme.textMuted(ctx),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: m.progress,
                              minHeight: 5,
                              backgroundColor: m.color.withValues(alpha: 0.14),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                done ? AsterConstants.menta : m.color,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const InsightCoinIcon(size: 13),
                              const SizedBox(width: 4),
                              Text(
                                '+${m.rewardInsights} Insights',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: done ? AsterConstants.menta : AsterTheme.textMuted(ctx),
                                ),
                              ),
                              const Spacer(),
                              if (canClaim)
                                InkWell(
                                  key: Key('achievement_claim_btn_${m.id}'),
                                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                  onTap: () => shop.claimAchievementReward(
                                    achievementId: m.id,
                                    title: m.title,
                                    amount: m.rewardInsights,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AsterConstants.menta,
                                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                    ),
                                    child: Text(
                                      'Resgatar',
                                      style: GoogleFonts.manrope(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                              else if (claimed)
                                Text(
                                  'Resgatado ✓',
                                  style: GoogleFonts.manrope(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: AsterConstants.menta,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStudyPortfolioCard(
    BuildContext context, {
    required PublicUserProfile me,
    required AccountPerformanceReport? report,
    required Color primaryCol,
  }) {
    final examsCount = report?.examsCount ?? 0;
    final cardsCount = report?.totalCards ?? 0;
    final notesCount = report?.totalNotes ?? 0;
    final roadmapsCount = report?.totalRoadmaps ?? 0;
    final totalStudiedLabel = DashboardAnalytics.formatReadableDuration(
      report?.periodMinutes ?? me.weeklyMinutes,
    );
    final subjects = (report?.subjectBreakdowns ?? const <SubjectBreakdownItem>[]).take(3).toList();

    return SoftClayCard(
      key: const Key('profile_study_portfolio_card'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.library_books_rounded, size: 18, color: primaryCol),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Acervo & Matérias em Foco',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AsterTheme.text(context),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => RootScreen.switchTab(13),
                child: Text(
                  'Desempenho',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: primaryCol,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _compactPortfolioBadge(context, '$examsCount Simulados', primaryCol),
              _compactPortfolioBadge(context, '$cardsCount Flashcards', AsterConstants.menta),
              _compactPortfolioBadge(context, '$notesCount Notas', const Color(0xFF0EA5E9)),
              _compactPortfolioBadge(context, '$roadmapsCount Trilhas', const Color(0xFFF59E0B)),
              _compactPortfolioBadge(context, 'Total: $totalStudiedLabel', AsterTheme.text(context)),
            ],
          ),
          const SizedBox(height: 14),
          if (subjects.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                color: AsterTheme.surfaceAlt(context),
                borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Registre sessões no Diário para destacar suas matérias principais no perfil.',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AsterTheme.textMuted(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () => RootScreen.switchTab(7),
                    child: const Text('Diário'),
                  ),
                ],
              ),
            )
          else
            ...subjects.map((s) {
              final pct = (s.shareFraction * 100).round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AsterTheme.text(context),
                            ),
                          ),
                        ),
                        Text(
                          '${DashboardAnalytics.formatReadableDuration(s.minutes)} ($pct%)',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: primaryCol,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: s.shareFraction.clamp(0.05, 1.0),
                        minHeight: 5,
                        backgroundColor: primaryCol.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(primaryCol),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _compactPortfolioBadge(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AsterTheme.surfaceAlt(context),
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildProfileGroupsCard(
    BuildContext context, {
    required List<StudyGroup> groups,
    required Color primaryCol,
  }) {
    final currentUid = StudyGroupsService.currentUserId;
    return SoftClayCard(
      key: const Key('profile_groups_card'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded, size: 19, color: AsterConstants.menta),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Meus Grupos de Estudos',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AsterTheme.text(context),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => RootScreen.switchTab(10),
                child: Text(
                  'Ver Grupos',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: primaryCol,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (groups.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                color: AsterTheme.surfaceAlt(context),
                borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Você ainda não participa de nenhum grupo. Crie ou entre em um grupo para estudar em equipe.',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AsterTheme.textMuted(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () => RootScreen.switchTab(10),
                    child: const Text('Grupos'),
                  ),
                ],
              ),
            )
          else
            ...groups.take(4).map((g) {
              final isLeader = g.leaderId == currentUid;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                  onTap: () => RootScreen.switchTab(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AsterTheme.surfaceAlt(context),
                      borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                    ),
                    child: Row(
                      children: [
                        GroupMemberAvatar(
                          displayName: g.name,
                          isVip: isLeader,
                          radius: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                g.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AsterTheme.text(context),
                                ),
                              ),
                              Text(
                                '${g.subject} · ${g.members.length} ${g.members.length == 1 ? 'membro' : 'membros'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  color: AsterTheme.textMuted(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SoftClayTag(
                          label: isLeader ? 'Líder' : 'Membro',
                          color: isLeader ? primaryCol : AsterConstants.menta,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _minimalStatPill(
    BuildContext context, {
    Key? key,
    required String count,
    required String label,
    required Color accent,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final pill = Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: AsterTheme.surfaceAlt(context),
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AsterTheme.textMuted(context),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 5),
            trailing,
          ],
        ],
      ),
    );

    if (onTap == null) return pill;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
      child: pill,
    );
  }

  Widget _buildMinimalPersonRow(
    BuildContext context, {
    required PublicUserProfile profile,
    required SocialConnectionsService social,
  }) {
    final isFollowing = social.isFollowing(profile.userId, username: profile.username);
    final followsMe = social.followsCurrentUser(profile.userId, username: profile.username);
    final isMutual = social.isMutualConnection(profile.userId, username: profile.username);
    final elo = profile.elo;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AsterTheme.surfaceAlt(context),
        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
        border: Border.all(
          color: isMutual
              ? AsterConstants.menta.withValues(alpha: 0.36)
              : AsterTheme.surfaceInset(context),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('profile_dir_item_${profile.userId}'),
          borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
          onTap: () => showPublicUserProfileModal(context, profile: profile),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                GroupMemberAvatar(
                  displayName: profile.displayName,
                  avatarUrl: profile.avatarUrl,
                  isVip: profile.isVip,
                  radius: 17,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            profile.displayName,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AsterTheme.text(context),
                            ),
                          ),
                          if (profile.isVip)
                            const VipBadgePill(size: VipBadgeSize.xs, interactive: false),
                          NoesisEloBadge(tier: elo, size: 15),
                          if (isMutual)
                            const SoftClayTag(
                              label: 'Mútuo',
                              color: AsterConstants.menta,
                            )
                          else if (followsMe)
                            SoftClayTag(
                              label: 'Segue você',
                              color: AsterTheme.primary(context),
                            ),
                        ],
                      ),
                      Text(
                        '@${profile.username} · Elo ${elo.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AsterTheme.textMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: () => showPublicUserProfileModal(context, profile: profile),
                  child: Text(
                    'Ver',
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AsterTheme.textMuted(context),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                SoftClayChoiceChip(
                  key: Key('profile_follow_btn_${profile.userId}'),
                  label: isFollowing ? 'Seguindo' : 'Seguir',
                  selected: isFollowing,
                  compact: true,
                  onTap: () => social.toggleFollow(profile),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
