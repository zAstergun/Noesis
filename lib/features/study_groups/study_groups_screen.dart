import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../core/shop_service.dart';
import '../../core/theme.dart';
import '../../widgets/insight_icon.dart';
import '../../widgets/vip_privileges.dart';
import '../flashcards/flashcards_screen.dart';
import '../notebooks/notebooks_screen.dart';
import '../quizzes/quiz_screen.dart';
import '../roadmaps/roadmaps_screen.dart';
import '../tracker/dashboard_analytics.dart';
import 'data/study_groups_service.dart';
import 'models/study_group_feature_scope.dart';
import 'models/study_group_model.dart';
import 'widgets/study_group_modals.dart';

enum _GroupDetailTab {
  chat,
  exams,
  decks,
  notebooks,
  roadmaps,
  diary,
  ranking,
  settings,
}

class StudyGroupsScreen extends StatefulWidget {
  const StudyGroupsScreen({super.key});

  @override
  State<StudyGroupsScreen> createState() => _StudyGroupsScreenState();
}

class _StudyGroupsScreenState extends State<StudyGroupsScreen> {
  String? _selectedGroupId;
  _GroupDetailTab _detailTab = _GroupDetailTab.chat;
  String? _diaryMemberFilterUserId;
  final TextEditingController _chatCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    StudyGroupsService.instance.init();
  }

  @override
  void dispose() {
    _chatCtrl.dispose();
    super.dispose();
  }

  void _showFeedback(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          persist: false,
          duration: const Duration(seconds: 3),
          backgroundColor: isError ? AsterConstants.coral : AsterTheme.primary(context),
          content: Text(
            msg,
            style: TextStyle(
              color: isError ? Colors.white : AsterTheme.onPrimary(context),
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final svc = StudyGroupsService.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([
        svc.groupsNotifier,
        ShopService.instance.balanceNotifier,
      ]),
      builder: (context, _) {
        final groups = svc.groupsNotifier.value;
        StudyGroup? activeGroup;
        if (_selectedGroupId != null) {
          for (final g in groups) {
            if (g.id == _selectedGroupId) {
              activeGroup = g;
              break;
            }
          }
        }

        final isEmbeddedPageTab = activeGroup != null &&
            (_detailTab == _GroupDetailTab.notebooks ||
                _detailTab == _GroupDetailTab.decks ||
                _detailTab == _GroupDetailTab.exams ||
                _detailTab == _GroupDetailTab.roadmaps);

        if (isEmbeddedPageTab) {
          return Column(
            key: const Key('group_workspace_view'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 28.0 : 16.0,
                  14.0,
                  isDesktop ? 28.0 : 16.0,
                  8.0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: _buildGroupHeaderAndTabs(
                      context,
                      group: activeGroup,
                      isDesktop: isDesktop,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _buildEmbeddedGroupFeature(context, group: activeGroup),
              ),
            ],
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 36.0 : 16.0,
            vertical: 18.0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: activeGroup == null
                  ? _buildGroupsDirectory(context, groups: groups, isDesktop: isDesktop)
                  : _buildGroupWorkspace(context, group: activeGroup, isDesktop: isDesktop),
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------
  // LISTA DE GRUPOS DO ESTUDANTE
  // ------------------------------------------------------------------
  Widget _buildGroupsDirectory(
    BuildContext context, {
    required List<StudyGroup> groups,
    required bool isDesktop,
  }) {
    final uid = StudyGroupsService.currentUserId;
    final primaryCol = AsterTheme.primary(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Builder(
          builder: (context) {
            final screenW = MediaQuery.sizeOf(context).width;
            final contentLeft =
                ((screenW - 1080).clamp(0.0, double.infinity) / 2) +
                    (isDesktop ? 36.0 : 16.0);
            final neededGap = (108.0 - contentLeft).clamp(0.0, 82.0);
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 560 : MediaQuery.sizeOf(context).width - 36,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NoesisCollapsedMenuSpacer(width: neededGap),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Grupos de Estudo',
                              style: GoogleFonts.manrope(
                                fontSize: isDesktop ? 24 : 21,
                                fontWeight: FontWeight.w900,
                                color: AsterTheme.text(context),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Compartilhe cadernos, flashcards, simulados, trilhas e acompanhe o diário e ranking juntos',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                color: AsterTheme.textMuted(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('groups_join_button'),
                      onPressed: _openJoinGroupDialog,
                      icon: const Icon(Icons.link_rounded, size: 17),
                      label: Text(
                        'Entrar por Link',
                        style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryCol,
                        side: BorderSide(color: primaryCol.withValues(alpha: 0.45)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      key: const Key('groups_create_button'),
                      onPressed: _openCreateGroupDialog,
                      icon: const Icon(Icons.group_add_rounded, size: 17),
                      label: Text(
                        'Criar Grupo',
                        style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryCol,
                        foregroundColor: AsterTheme.onPrimary(context),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),

        if (groups.isEmpty)
          SoftClayCard(
            key: const Key('groups_empty_state'),
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: primaryCol.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(Icons.groups_rounded, size: 30, color: primaryCol),
                ),
                const SizedBox(height: 14),
                Text(
                  'Nenhum grupo de estudo ainda',
                  style: GoogleFonts.manrope(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AsterTheme.text(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Crie um grupo e convide colegas pelo @usuario ou link de convite, ou entre em um grupo existente.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    color: AsterTheme.textMuted(context),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _openCreateGroupDialog,
                      icon: const Icon(Icons.add_rounded, size: 17),
                      label: const Text('Criar meu primeiro grupo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryCol,
                        foregroundColor: AsterTheme.onPrimary(context),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openJoinGroupDialog,
                      icon: const Icon(Icons.link_rounded, size: 17),
                      label: const Text('Tenho um link de convite'),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final cols = w >= 900 ? 3 : (w >= 560 ? 2 : 1);
              const gap = 14.0;
              final cardW = (w - (cols - 1) * gap) / cols;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: groups.map((group) {
                  final isLeader = group.isLeader(uid);
                  return SizedBox(
                    width: cardW,
                    child: SoftClayCard(
                      padding: EdgeInsets.zero,
                      child: InkWell(
                        key: Key('group_card_${group.id}'),
                        borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
                        onTap: () => setState(() {
                          _selectedGroupId = group.id;
                          _detailTab = _GroupDetailTab.chat;
                          _diaryMemberFilterUserId = null;
                        }),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: primaryCol.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.groups_rounded, size: 21, color: primaryCol),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          group.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.manrope(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: AsterTheme.text(context),
                                          ),
                                        ),
                                        Text(
                                          group.subject,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.manrope(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: primaryCol,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isLeader)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AsterVipColors.gold.withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                      ),
                                      child: Text(
                                        'Líder',
                                        style: GoogleFonts.manrope(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: AsterVipColors.goldDark,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (group.description.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  group.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: AsterTheme.textMuted(context),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _miniStatChip(context, Icons.people_alt_rounded, '${group.members.length} membros'),
                                  _miniStatChip(context, Icons.menu_book_rounded, '${group.sharedNotebooks.length} cadernos'),
                                  _miniStatChip(context, Icons.style_rounded, '${group.sharedDecks.length} decks'),
                                  _miniStatChip(context, Icons.assignment_rounded, '${group.sharedExams.length} simulados'),
                                  _miniStatChip(context, Icons.route_rounded, '${group.sharedRoadmaps.length} trilhas'),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AsterTheme.surfaceAlt(context),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      group.inviteCode,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: AsterTheme.textMuted(context),
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Abrir grupo →',
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: primaryCol,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _miniStatChip(BuildContext context, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AsterTheme.surfaceAlt(context),
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AsterTheme.textMuted(context)),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AsterTheme.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // ESPAÇO DE TRABALHO DO GRUPO SELECIONADO
  // ------------------------------------------------------------------
  Widget _buildGroupWorkspace(
    BuildContext context, {
    required StudyGroup group,
    required bool isDesktop,
  }) {
    final uid = StudyGroupsService.currentUserId;
    final isLeader = group.isLeader(uid);

    return Column(
      key: const Key('group_workspace_view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGroupHeaderAndTabs(context, group: group, isDesktop: isDesktop),
        const SizedBox(height: 18),

        // Conteúdo da aba selecionada
        if (_detailTab == _GroupDetailTab.diary)
          _buildGroupDiarySection(context, group: group)
        else if (_detailTab == _GroupDetailTab.chat)
          _buildGroupChatSection(context, group: group)
        else if (_detailTab == _GroupDetailTab.ranking)
          _buildRankingSection(context, group: group)
        else
          _buildGroupSettingsSection(context, group: group, isLeader: isLeader),
      ],
    );
  }

  Widget _buildEmbeddedGroupFeature(
    BuildContext context, {
    required StudyGroup group,
  }) {
    final uid = StudyGroupsService.currentUserId;
    final canEdit = group.canUserEdit(uid);
    final canRemove = group.canUserRemoveContent(uid);

    StudyGroupFeatureScope scopeFor(StudyGroupContentKind kind) =>
        StudyGroupFeatureScope(
          groupId: group.id,
          canEdit: canEdit,
          canRemove: canRemove,
          onAttachExisting: () => _openAttachDialog(group, kind),
          onFeedback: _showFeedback,
        );

    switch (_detailTab) {
      case _GroupDetailTab.notebooks:
        return NotebooksScreen(
          key: ValueKey('grp_notebooks_${group.id}'),
          groupScope: scopeFor(StudyGroupContentKind.notebook),
        );
      case _GroupDetailTab.decks:
        return FlashcardsScreen(
          key: ValueKey('grp_decks_${group.id}'),
          groupScope: scopeFor(StudyGroupContentKind.deck),
        );
      case _GroupDetailTab.exams:
        return QuizScreen(
          key: ValueKey('grp_exams_${group.id}'),
          groupScope: scopeFor(StudyGroupContentKind.exam),
        );
      case _GroupDetailTab.roadmaps:
        return RoadmapsScreen(
          key: ValueKey('grp_roadmaps_${group.id}'),
          groupScope: scopeFor(StudyGroupContentKind.roadmap),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildGroupHeaderAndTabs(
    BuildContext context, {
    required StudyGroup group,
    required bool isDesktop,
  }) {
    final uid = StudyGroupsService.currentUserId;
    final primaryCol = AsterTheme.primary(context);
    final isLeader = group.isLeader(uid);
    final canInvite = group.canUserInvite(uid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabeçalho do grupo ativo
        SoftClayCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 560 : MediaQuery.sizeOf(context).width - 72,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NoesisCollapsedMenuSpacer(width: isDesktop ? 56 : 0),
                        IconButton(
                          key: const Key('group_back_button'),
                          tooltip: 'Voltar para todos os grupos',
                          onPressed: () => setState(() => _selectedGroupId = null),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    group.name,
                                    style: GoogleFonts.manrope(
                                      fontSize: isDesktop ? 20 : 18,
                                      fontWeight: FontWeight.w900,
                                      color: AsterTheme.text(context),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: primaryCol.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                    ),
                                    child: Text(
                                      group.subject,
                                      style: GoogleFonts.manrope(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: primaryCol,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${group.members.length} ${group.members.length == 1 ? 'membro' : 'membros'} · Código ${group.inviteCode}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: AsterTheme.textMuted(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('group_copy_invite_link_button'),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: group.inviteLink));
                          _showFeedback('Link de convite copiado (${group.inviteCode})!');
                        },
                        icon: const Icon(Icons.link_rounded, size: 16),
                        label: Text(
                          'Copiar Link',
                          style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (canInvite)
                        ElevatedButton.icon(
                          key: const Key('group_invite_member_button'),
                          onPressed: () => _openInviteMemberDialog(group),
                          icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                          label: Text(
                            'Convidar @',
                            style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryCol,
                            foregroundColor: AsterTheme.onPrimary(context),
                            elevation: 0,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (group.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  group.description,
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    color: AsterTheme.textMuted(context),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Abas internas do grupo (Chat primeiro + estudo colaborativo + diário + ranking + configurações)
        Wrap(
          key: const Key('group_detail_tabs_bar'),
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildDetailTabChip(_GroupDetailTab.chat, const Key('group_tab_chat'), Icons.forum_rounded, 'Chat (${group.chatMessages.length})'),
            _buildDetailTabChip(_GroupDetailTab.exams, const Key('group_tab_exams'), Icons.assignment_rounded, 'Simulados (${group.sharedExams.length})'),
            _buildDetailTabChip(_GroupDetailTab.decks, const Key('group_tab_decks'), Icons.style_rounded, 'Flashcards (${group.sharedDecks.length})'),
            _buildDetailTabChip(_GroupDetailTab.notebooks, const Key('group_tab_notebooks'), Icons.menu_book_rounded, 'Cadernos (${group.sharedNotebooks.length})'),
            _buildDetailTabChip(_GroupDetailTab.roadmaps, const Key('group_tab_roadmaps'), Icons.route_rounded, 'Trilhas (${group.sharedRoadmaps.length})'),
            _buildDetailTabChip(_GroupDetailTab.diary, const Key('group_tab_diary'), Icons.auto_stories_rounded, 'Diário de Estudo'),
            _buildDetailTabChip(_GroupDetailTab.ranking, const Key('group_tab_ranking'), Icons.emoji_events_rounded, 'Ranking'),
            _buildDetailTabChip(
              _GroupDetailTab.settings,
              const Key('group_tab_settings'),
              Icons.tune_rounded,
              isLeader ? 'Configurações' : 'Regras & Membros',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailTabChip(
    _GroupDetailTab tab,
    Key key,
    IconData icon,
    String label,
  ) {
    final selected = _detailTab == tab;
    final primaryCol = AsterTheme.primary(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? primaryCol : AsterTheme.card(context),
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        border: Border.all(
          color: selected ? Colors.transparent : AsterTheme.surfaceInset(context),
          width: 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: primaryCol.withValues(alpha: isDark ? 0.32 : 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                  spreadRadius: -2,
                ),
              ]
            : (isDark ? AsterConstants.claySubtleDarkShadow : AsterConstants.claySubtleShadow),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: key,
          onTap: () => setState(() => _detailTab = tab),
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: selected ? AsterTheme.onPrimary(context) : AsterTheme.textMuted(context),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    color: selected ? AsterTheme.onPrimary(context) : AsterTheme.text(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // 1. DIÁRIO DE ESTUDO POR USUÁRIO
  // ------------------------------------------------------------------
  Widget _buildGroupDiarySection(BuildContext context, {required StudyGroup group}) {
    final primaryCol = AsterTheme.primary(context);
    final filteredLogs = _diaryMemberFilterUserId == null
        ? group.studyLogs
        : group.studyLogs.where((l) => l.userId == _diaryMemberFilterUserId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SoftClayCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Diário de Estudos por Participante',
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AsterTheme.text(context),
                        ),
                      ),
                      Text(
                        'Veja o que cada membro estudou e filtre por pessoa',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AsterTheme.textMuted(context),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    key: const Key('group_add_log_button'),
                    onPressed: () => _openAddStudyLogDialog(group),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                    label: Text(
                      'Registrar Estudo',
                      style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryCol,
                      foregroundColor: AsterTheme.onPrimary(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SoftClayChoiceChip(
                    key: const Key('group_diary_filter_all'),
                    label: 'Todos (${group.studyLogs.length})',
                    icon: Icons.groups_rounded,
                    selected: _diaryMemberFilterUserId == null,
                    compact: true,
                    onTap: () => setState(() => _diaryMemberFilterUserId = null),
                  ),
                  ...group.members.map((m) {
                    final count = group.studyLogs.where((l) => l.userId == m.userId).length;
                    return SoftClayChoiceChip(
                      key: Key('group_diary_filter_${m.userId}'),
                      label: '@${m.username} (${DashboardAnalytics.formatCompactDuration(m.weeklyMinutes)} · $count)',
                      selected: _diaryMemberFilterUserId == m.userId,
                      compact: true,
                      onTap: () => setState(() => _diaryMemberFilterUserId = m.userId),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (filteredLogs.isEmpty)
          SoftClayCard(
            padding: const EdgeInsets.all(22),
            child: Center(
              child: Text(
                'Nenhuma sessão registrada neste filtro ainda.',
                style: GoogleFonts.manrope(fontSize: 12.5, color: AsterTheme.textMuted(context)),
              ),
            ),
          )
        else
          ...filteredLogs.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftClayCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AsterConstants.menta.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.timer_outlined, size: 18, color: AsterConstants.menta),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${entry.memberName} (@${entry.memberUsername}) · ${entry.subject}',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AsterTheme.text(context),
                            ),
                          ),
                          if (entry.topic.isNotEmpty)
                            Text(
                              entry.topic,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: AsterTheme.textMuted(context),
                              ),
                            ),
                          if ((entry.notes ?? '').isNotEmpty)
                            Text(
                              entry.notes!,
                              style: GoogleFonts.manrope(
                                fontSize: 11.5,
                                color: AsterTheme.textMuted(context),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AsterTheme.surfaceAlt(context),
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      ),
                      child: Text(
                        DashboardAnalytics.formatReadableDuration(entry.durationMinutes),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: primaryCol,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // 1B. CHAT INTERNO DO GRUPO
  // ------------------------------------------------------------------
  Future<void> _sendChatMessage(StudyGroup group) async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    final res = await StudyGroupsService.instance.sendChatMessage(
      groupId: group.id,
      text: text,
    );
    if (!mounted) return;
    if (res.ok) {
      _chatCtrl.clear();
    } else {
      _showFeedback(res.error ?? 'Erro ao enviar mensagem.', isError: true);
    }
  }

  Widget _buildGroupChatSection(BuildContext context, {required StudyGroup group}) {
    final uid = StudyGroupsService.currentUserId;
    final isLeader = group.isLeader(uid);
    final primaryCol = AsterTheme.primary(context);

    return SoftClayCard(
      key: const Key('group_chat_view'),
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
                  color: primaryCol.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.forum_rounded, size: 18, color: primaryCol),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chat do Grupo',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AsterTheme.text(context),
                      ),
                    ),
                    Text(
                      'Converse, tire dúvidas e combine metas com os membros',
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
          Container(
            constraints: const BoxConstraints(minHeight: 240, maxHeight: 400),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AsterTheme.surfaceAlt(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AsterTheme.surfaceInset(context)),
            ),
            child: group.chatMessages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 42),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 30,
                            color: AsterTheme.textMuted(context),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Nenhuma mensagem ainda. Diga oi para o grupo!',
                            style: GoogleFonts.manrope(
                              fontSize: 12.5,
                              color: AsterTheme.textMuted(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    reverse: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: group.chatMessages.map((msg) {
                        final isMine = msg.userId == uid;
                        final canDelete = isMine || isLeader;
                        final hh = msg.sentAt.hour.toString().padLeft(2, '0');
                        final mm = msg.sentAt.minute.toString().padLeft(2, '0');
                        final liveMember = group.memberFor(msg.userId);
                        final avatarUrl = liveMember?.avatarUrl ?? msg.senderAvatarUrl;
                        final isVip = liveMember?.isVip ?? msg.isVip;
                        final senderName = liveMember?.displayName ?? msg.senderName;
                        final senderHandle = liveMember?.username ?? msg.senderUsername;

                        void openProfile() => showGroupMemberProfileModal(
                              context,
                              group: group,
                              member: liveMember,
                              userId: msg.userId,
                              fallbackName: senderName,
                              fallbackUsername: senderHandle,
                              fallbackAvatarUrl: avatarUrl,
                              fallbackIsVip: isVip,
                            );

                        final avatarWidget = GroupMemberAvatar(
                          avatarKey: Key('group_chat_avatar_${msg.id}'),
                          displayName: senderName,
                          avatarUrl: avatarUrl,
                          isVip: isVip,
                          radius: 17,
                          onTap: openProfile,
                        );

                        final bubble = Container(
                          constraints: const BoxConstraints(maxWidth: 480),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMine
                                ? primaryCol.withValues(alpha: 0.14)
                                : AsterTheme.card(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isMine
                                  ? primaryCol.withValues(alpha: 0.35)
                                  : AsterTheme.surfaceInset(context),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    key: Key('group_chat_sender_${msg.id}'),
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: openProfile,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          senderName,
                                          style: GoogleFonts.manrope(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: isMine ? primaryCol : AsterTheme.text(context),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          '@$senderHandle',
                                          style: GoogleFonts.manrope(
                                            fontSize: 10.5,
                                            color: AsterTheme.textMuted(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isVip) ...[
                                    const SizedBox(width: 5),
                                    const VipBadgePill(size: VipBadgeSize.xs, interactive: false),
                                  ],
                                  if (msg.isLeader) ...[
                                    const SizedBox(width: 5),
                                    Text(
                                      '· Líder',
                                      style: GoogleFonts.manrope(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AsterVipColors.goldDark,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 8),
                                  Text(
                                    '$hh:$mm',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10,
                                      color: AsterTheme.textMuted(context),
                                    ),
                                  ),
                                  if (canDelete) ...[
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () => StudyGroupsService.instance.deleteChatMessage(
                                        groupId: group.id,
                                        messageId: msg.id,
                                      ),
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 14,
                                        color: AsterTheme.textMuted(context),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                msg.text,
                                style: GoogleFonts.manrope(
                                  fontSize: 13.5,
                                  height: 1.45,
                                  color: AsterTheme.text(context),
                                ),
                              ),
                            ],
                          ),
                        );

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            mainAxisAlignment:
                                isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isMine) ...[
                                avatarWidget,
                                const SizedBox(width: 8),
                              ],
                              Flexible(child: bubble),
                              if (isMine) ...[
                                const SizedBox(width: 8),
                                avatarWidget,
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('group_chat_input'),
                  controller: _chatCtrl,
                  onSubmitted: (_) => _sendChatMessage(group),
                  decoration: noesisGroupInputDecoration(
                    context,
                    hintText: 'Enviar mensagem para o grupo...',
                    prefixIcon: Icons.chat_outlined,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                key: const Key('group_chat_send_button'),
                onPressed: () => _sendChatMessage(group),
                icon: const Icon(Icons.send_rounded, size: 16),
                label: Text(
                  'Enviar',
                  style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryCol,
                  foregroundColor: AsterTheme.onPrimary(context),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // 2. RANKING INTERNO DE INSIGHTS
  // ------------------------------------------------------------------
  Widget _buildRankingSection(BuildContext context, {required StudyGroup group}) {
    if (!group.rankingEnabled) {
      return SoftClayCard(
        key: const Key('group_ranking_disabled_notice'),
        padding: const EdgeInsets.all(26),
        child: Column(
          children: [
            Icon(Icons.leaderboard_outlined, size: 34, color: AsterTheme.textMuted(context)),
            const SizedBox(height: 10),
            Text(
              'Ranking interno desativado pelo líder',
              style: GoogleFonts.manrope(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: AsterTheme.text(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'O criador deste grupo optou por ocultar o ranking de Insights.',
              style: GoogleFonts.manrope(fontSize: 12, color: AsterTheme.textMuted(context)),
            ),
          ],
        ),
      );
    }

    final ranked = group.rankedMembers;
    return SoftClayCard(
      key: const Key('group_ranking_board'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const InsightCoinIcon(size: 20),
              const SizedBox(width: 8),
              Text(
                'Ranking Interno de Insights (Estudo no Grupo)',
                style: GoogleFonts.manrope(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: AsterTheme.text(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Soma apenas os Insights conquistados em atividades estudadas dentro deste grupo.',
            style: GoogleFonts.manrope(
              fontSize: 11.5,
              color: AsterTheme.textMuted(context),
            ),
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < ranked.length; i++) ...[
            if (i > 0) Divider(height: 16, color: AsterTheme.surfaceInset(context)),
            InkWell(
              key: Key('group_ranking_member_${ranked[i].userId}'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => showGroupMemberProfileModal(
                context,
                group: group,
                member: ranked[i],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '#${i + 1}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: i == 0 ? AsterVipColors.goldDark : AsterTheme.textMuted(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GroupMemberAvatar(
                      avatarKey: Key('group_ranking_avatar_${ranked[i].userId}'),
                      displayName: ranked[i].displayName,
                      avatarUrl: ranked[i].avatarUrl,
                      isVip: ranked[i].isVip,
                      radius: 17,
                      onTap: () => showGroupMemberProfileModal(
                        context,
                        group: group,
                        member: ranked[i],
                      ),
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
                                  ranked[i].displayName,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.manrope(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: AsterTheme.text(context),
                                  ),
                                ),
                              ),
                              if (ranked[i].isVip) ...[
                                const SizedBox(width: 6),
                                const VipBadgePill(size: VipBadgeSize.xs, interactive: false),
                              ],
                              if (ranked[i].isLeader) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '· Líder',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AsterTheme.primary(context),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            '@${ranked[i].username} · ${DashboardAnalytics.formatReadableDuration(ranked[i].weeklyMinutes)} no diário',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: AsterTheme.textMuted(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AsterTheme.surfaceAlt(context),
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const InsightCoinIcon(size: 13),
                          const SizedBox(width: 5),
                          Text(
                            '${ranked[i].insightsScore}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AsterTheme.text(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // 4. CONFIGURAÇÕES DO GRUPO (EXCLUSIVO PARA O LÍDER CRIADOR)
  // ------------------------------------------------------------------
  Widget _buildGroupSettingsSection(
    BuildContext context, {
    required StudyGroup group,
    required bool isLeader,
  }) {
    return SoftClayCard(
      key: const Key('group_settings_panel'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isLeader ? 'Configurações & Permissões do Líder' : 'Regras & Participantes do Grupo',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AsterTheme.text(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isLeader
                ? 'Defina o que os membros podem fazer, controle o ranking interno e remova anexos.'
                : 'Apenas o líder criador do grupo pode alterar permissões, ranking ou remover anexos.',
            style: GoogleFonts.manrope(fontSize: 12, color: AsterTheme.textMuted(context)),
          ),
          const SizedBox(height: 16),

          SwitchListTile.adaptive(
            key: const Key('group_setting_allow_invites'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Permitir que membros convidem outras pessoas'),
            value: group.allowMemberInvites,
            onChanged: isLeader
                ? (v) => StudyGroupsService.instance.updateGroupSettings(
                      groupId: group.id,
                      allowMemberInvites: v,
                    )
                : null,
          ),
          SwitchListTile.adaptive(
            key: const Key('group_setting_allow_edit'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Permitir que membros editem e anexem conteúdos ao grupo'),
            value: group.allowMemberEdit,
            onChanged: isLeader
                ? (v) => StudyGroupsService.instance.updateGroupSettings(
                      groupId: group.id,
                      allowMemberEdit: v,
                    )
                : null,
          ),
          SwitchListTile.adaptive(
            key: const Key('group_setting_ranking_enabled'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Ativar ranking interno de Insights'),
            value: group.rankingEnabled,
            onChanged: isLeader
                ? (v) => StudyGroupsService.instance.updateGroupSettings(
                      groupId: group.id,
                      rankingEnabled: v,
                    )
                : null,
          ),

          const SizedBox(height: 14),
          Divider(color: AsterTheme.surfaceInset(context)),
          const SizedBox(height: 12),
          Text(
            'PERMISSÕES POR MEMBRO (${group.members.length})',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: AsterTheme.textMuted(context),
            ),
          ),
          const SizedBox(height: 10),
          ...group.members.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AsterTheme.surfaceAlt(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    InkWell(
                      key: Key('group_settings_member_profile_${m.userId}'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => showGroupMemberProfileModal(
                        context,
                        group: group,
                        member: m,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GroupMemberAvatar(
                              avatarKey: Key('group_settings_avatar_${m.userId}'),
                              displayName: m.displayName,
                              avatarUrl: m.avatarUrl,
                              isVip: m.isVip,
                              radius: 17,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${m.displayName} (@${m.username})',
                                      style: GoogleFonts.manrope(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: AsterTheme.text(context),
                                      ),
                                    ),
                                    if (m.isVip) ...[
                                      const SizedBox(width: 6),
                                      const VipBadgePill(size: VipBadgeSize.xs, interactive: false),
                                    ],
                                  ],
                                ),
                                Text(
                                  m.isLeader ? 'Criador / Líder do grupo' : 'Membro · Toque para ver perfil',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    color: AsterTheme.textMuted(context),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!m.isLeader && isLeader)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SoftClayChoiceChip(
                            key: Key('member_perm_invite_${m.userId}'),
                            label: 'Convidar',
                            selected: m.canInvite,
                            showCheckmark: true,
                            compact: true,
                            onTap: () => StudyGroupsService.instance.setMemberPermissions(
                              groupId: group.id,
                              targetUserId: m.userId,
                              canInvite: !m.canInvite,
                            ),
                          ),
                          SoftClayChoiceChip(
                            key: Key('member_perm_edit_${m.userId}'),
                            label: 'Editar',
                            selected: m.canEdit,
                            showCheckmark: true,
                            compact: true,
                            onTap: () => StudyGroupsService.instance.setMemberPermissions(
                              groupId: group.id,
                              targetUserId: m.userId,
                              canEdit: !m.canEdit,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // DIÁLOGOS AUXILIARES
  // ------------------------------------------------------------------
  Future<void> _openCreateGroupDialog() => showCreateGroupModal(
        context,
        onCreated: (id) {
          if (mounted) {
            setState(() {
              _selectedGroupId = id;
              _detailTab = _GroupDetailTab.chat;
              _diaryMemberFilterUserId = null;
            });
          }
        },
        onFeedback: _showFeedback,
      );

  Future<void> _openJoinGroupDialog() => showJoinGroupModal(
        context,
        onJoined: (id) {
          if (mounted) {
            setState(() {
              _selectedGroupId = id;
              _detailTab = _GroupDetailTab.chat;
              _diaryMemberFilterUserId = null;
            });
          }
        },
        onFeedback: _showFeedback,
      );

  Future<void> _openInviteMemberDialog(StudyGroup group) => showInviteMemberModal(
        context,
        group: group,
        onFeedback: _showFeedback,
      );

  Future<void> _openAddStudyLogDialog(StudyGroup group) => showAddStudyLogModal(
        context,
        group: group,
        onFeedback: _showFeedback,
      );

  /// Mostra APENAS os conteúdos disponíveis na conta pessoal do usuário atual.
  Future<void> _openAttachDialog(
    StudyGroup group,
    StudyGroupContentKind kind,
  ) =>
      showAttachPersonalContentModal(
        context,
        group: group,
        kind: kind,
        onFeedback: _showFeedback,
      );
}
