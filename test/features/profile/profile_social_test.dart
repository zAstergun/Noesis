import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/shop_service.dart';
import 'package:noesis/features/profile/data/social_connections_service.dart';
import 'package:noesis/features/profile/models/user_profile_model.dart';
import 'package:noesis/features/study_groups/data/study_groups_service.dart';
import 'package:noesis/features/tracker/dashboard_analytics.dart';
import 'package:noesis/main.dart';
import '../../e2e/harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  setUp(() async {
    await ShopService.instance.resetForTesting(initialBalance: 800);
    await SocialConnectionsService.instance.resetForTesting();
    await StudyGroupsService.instance.resetForTesting();
  });

  test('SocialConnectionsService searches by @, tracks mutual follows as internal friends, and prioritizes invite suggestions', () async {
    final social = SocialConnectionsService.instance;

    // @camila_sec já segue o usuário atual na semente comunitária; @lucas_dev não segue ainda
    social.registerDirectoryProfileForTesting(
      const PublicUserProfile(
        userId: 'u_bruno_teste',
        username: 'bruno_teste',
        displayName: 'Bruno Teste',
        bio: 'Estudando Cloud',
        eloIndex: 2,
        weeklyInsights: 150,
        followsCurrentUser: true,
      ),
    );
    social.registerDirectoryProfileForTesting(
      const PublicUserProfile(
        userId: 'u_diana_only',
        username: 'diana_only',
        displayName: 'Diana Só Seguida',
        bio: 'Estudando Direito',
        eloIndex: 2,
        weeklyInsights: 120,
        followsCurrentUser: false,
      ),
    );

    // Busca com e sem @
    final withAt = social.searchProfilesByHandle('@bruno_teste');
    final withoutAt = social.searchProfilesByHandle('bruno');
    expect(withAt.first.username, 'bruno_teste');
    expect(withoutAt.any((p) => p.username == 'bruno_teste'), isTrue);

    // Segue ambos: Bruno vira conexão mútua (mútua == "amigo" interno), Diana continua unilateral
    final bruno = withAt.first;
    final diana = social.searchProfilesByHandle('@diana_only').first;
    await social.toggleFollow(diana);
    await social.toggleFollow(bruno);

    expect(social.isFollowing(diana.userId, username: diana.username), isTrue);
    expect(social.isMutualConnection(diana.userId, username: diana.username), isFalse);

    expect(social.isFollowing(bruno.userId, username: bruno.username), isTrue);
    expect(social.isMutualConnection(bruno.userId, username: bruno.username), isTrue);
    expect(social.mutualConnections.any((p) => p.userId == bruno.userId), isTrue);

    // Sugestões para convite de grupo devem priorizar conexões mútuas no topo
    final suggestions = social.inviteSuggestionsForGroup();
    final brunoIdx = suggestions.indexWhere((p) => p.userId == bruno.userId);
    final dianaIdx = suggestions.indexWhere((p) => p.userId == diana.userId);
    expect(brunoIdx, isNot(-1));
    expect(dianaIdx, isNot(-1));
    expect(brunoIdx, lessThan(dianaIdx));
  });

  testWidgets('Perfil tab displays public profile preview, @ search, mutual follow without Amigo label, and quick group invite',
      (WidgetTester tester) async {
    final social = SocialConnectionsService.instance;
    social.registerDirectoryProfileForTesting(
      const PublicUserProfile(
        userId: 'u_clara_sec',
        username: 'clara_sec',
        displayName: 'Clara Martins',
        bio: 'Focada em Security+ e AWS.',
        isVip: true,
        eloIndex: 4,
        weeklyInsights: 380,
        weeklyMinutes: 210,
        streakDays: 12,
        followsCurrentUser: true,
      ),
    );

    await TestAppHarness.pumpInHarness(
      tester,
      const RootScreen(),
      screenSize: const Size(1440, 900),
    );
    final guestFinder = find.textContaining('Entrar sem login');
    if (guestFinder.evaluate().isNotEmpty) {
      await tester.ensureVisible(guestFinder.first);
      await tester.tap(guestFinder.first);
      await tester.pumpAndSettle();
    }

    // 1. Abre aba Perfil sob CONTA
    final perfilNav = find.text('Perfil');
    expect(perfilNav, findsOneWidget);
    await tester.ensureVisible(perfilNav);
    await tester.tap(perfilNav);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile_screen_root')), findsOneWidget);
    expect(find.byKey(const Key('profile_own_card')), findsOneWidget);
    expect(find.byKey(const Key('profile_elo_journey_card')), findsOneWidget);
    expect(find.byKey(const Key('profile_equipped_loadout_card')), findsOneWidget);
    expect(find.byKey(const Key('profile_milestones_card')), findsOneWidget);
    expect(find.byKey(const Key('profile_study_portfolio_card')), findsOneWidget);
    expect(find.byKey(const Key('profile_groups_card')), findsOneWidget);
    expect(find.byKey(const Key('profile_connections_card')), findsNothing);
    expect(find.byKey(const Key('profile_customization_card')), findsNothing);
    expect(find.text('Rede de Estudos'), findsNothing);
    expect(find.text('Perfil & Conexões'), findsNothing);

    // Verifica que a barra de pesquisa fica no canto superior direito do cabeçalho
    final searchWrapper = find.byKey(const Key('profile_top_right_search_wrapper'));
    expect(searchWrapper, findsOneWidget);
    final headerRect = tester.getRect(find.byKey(const Key('profile_own_card')));
    final searchRect = tester.getRect(searchWrapper);
    expect(searchRect.bottom, lessThanOrEqualTo(headerRect.top));
    expect(searchRect.right, greaterThan(headerRect.center.dx));

    // Compra Capa e Título na Loja (Identidade & Status) e depois troca em Perfil -> Editar
    final beforeBalance = ShopService.instance.balance;
    await tester.tap(find.text('Loja').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shop_section_identity')));
    await tester.pumpAndSettle();

    final buyBannerBtn = find.byKey(const Key('shop_identity_btn_banner_lavender_aurora'));
    await tester.ensureVisible(buyBannerBtn);
    await tester.tap(buyBannerBtn);
    await tester.pumpAndSettle();
    expect(ShopService.instance.balance, beforeBalance - 220);

    await tester.tap(find.byKey(const Key('shop_identity_tab_title')));
    await tester.pumpAndSettle();
    final buyTitleBtn = find.byKey(const Key('shop_identity_btn_title_curious'));
    await tester.ensureVisible(buyTitleBtn);
    await tester.tap(buyTitleBtn);
    await tester.pumpAndSettle();
    expect(ShopService.instance.balance, beforeBalance - 220 - 200);

    // Volta para Perfil -> Editar permite trocar Capa, Moldura e Título desbloqueados
    await tester.tap(find.text('Perfil').first);
    await tester.pumpAndSettle();

    // Clicar em Seguidores / Seguindo abre uma modal limpa (e não uma seção abaixo)
    await tester.tap(find.byKey(const Key('profile_stat_followers')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile_connections_modal')), findsOneWidget);
    expect(find.byKey(const Key('profile_modal_tab_following')), findsOneWidget);
    expect(find.byKey(const Key('profile_modal_tab_followers')), findsOneWidget);
    expect(find.byKey(const Key('profile_modal_tab_all')), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile_connections_modal')), findsNothing);

    // Abre Editar Perfil e equipa capa + título dentro da modal de edição
    await tester.tap(find.byKey(const Key('profile_edit_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile_edit_appearance_section')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('profile_edit_cosmetic_tab_title')));
    await tester.tap(find.byKey(const Key('profile_edit_cosmetic_tab_title')));
    await tester.pumpAndSettle();
    final editTitleChip = find.byKey(const Key('profile_edit_item_title_curious'));
    await tester.ensureVisible(editTitleChip);
    await tester.tap(editTitleChip);
    await tester.pumpAndSettle();
    expect(ShopService.instance.equippedTitleIdNotifier.value, 'title_curious');
    await tester.tap(find.byTooltip('Fechar').last);
    await tester.pumpAndSettle();

    // Resgata a conquista desbloqueada "Estilo Próprio" (+40 Insights) e garante idempotência
    final claimStyleBtn = find.byKey(const Key('achievement_claim_btn_custom_style'));
    expect(claimStyleBtn, findsOneWidget);
    final balBeforeClaim = ShopService.instance.balance;
    await tester.ensureVisible(claimStyleBtn);
    await tester.tap(claimStyleBtn);
    await tester.pumpAndSettle();
    expect(ShopService.instance.balance, balBeforeClaim + 40);
    expect(find.byKey(const Key('achievement_claim_btn_custom_style')), findsNothing);
    expect(
      ShopService.instance.claimAchievementReward(
        achievementId: 'custom_style',
        title: 'Estilo Próprio',
        amount: 40,
      ),
      0,
    );

    // 2. Pré-visualiza como outros usuários veem o próprio perfil (incluindo Título equipado)
    final previewBtn = find.byKey(const Key('profile_preview_public_button'));
    await tester.ensureVisible(previewBtn);
    await tester.tap(previewBtn);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('public_profile_modal')), findsOneWidget);
    expect(find.byKey(const Key('public_profile_journey_section')), findsOneWidget);
    expect(find.byKey(const Key('public_profile_milestones_section')), findsOneWidget);
    expect(find.text('Como outros usuários veem seu perfil'), findsOneWidget);
    expect(find.text('Mente Inquieta'), findsAtLeastNWidgets(1));
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();

    // 3. Pesquisa perfil pelo @ na barra de busca do canto superior direito e abre popover animado estilo anexo do chat
    final searchField = find.byKey(const Key('profile_search_field'));
    await tester.ensureVisible(searchField);
    await tester.tap(searchField);
    await tester.pumpAndSettle();
    final popoverFinder = find.byKey(const Key('profile_search_popover_menu'));
    expect(popoverFinder, findsOneWidget);
    // Popover flutua acima dos cards sobrepondo a página sem criar bloco inline
    expect(
      tester.getRect(popoverFinder).overlaps(
        tester.getRect(find.byKey(const Key('profile_own_card'))),
      ),
      isTrue,
    );

    await tester.enterText(searchField, '@clara_sec');
    await tester.pumpAndSettle();
    final claraCard = find.byKey(const Key('profile_search_result_u_clara_sec'));
    expect(claraCard, findsOneWidget);
    await tester.ensureVisible(claraCard);
    await tester.tap(claraCard);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile_search_popover_menu')), findsNothing);

    expect(find.byKey(const Key('public_profile_modal')), findsOneWidget);
    expect(find.byKey(const Key('public_profile_stats_grid')), findsOneWidget);
    expect(find.byKey(const Key('public_profile_stat_time')), findsOneWidget);
    expect(find.text('Clara Martins'), findsAtLeastNWidgets(1));
    expect(find.text('@clara_sec'), findsAtLeastNWidgets(1));
    final claraProfile = social.findByUserOrHandle(username: 'clara_sec');
    expect(claraProfile, isNotNull);
    expect(
      find.text(DashboardAnalytics.formatReadableDuration(claraProfile!.weeklyMinutes)),
      findsOneWidget,
    );

    // Segue Clara -> como Clara já seguia de volta, viram conexão mútua (sem mostrar texto "Amigo")
    await tester.tap(find.byKey(const Key('public_profile_follow_button')));
    await tester.pumpAndSettle();
    expect(find.text('Seguem-se mutuamente'), findsOneWidget);
    expect(find.textContaining('Amigo'), findsNothing);
    expect(social.isMutualConnection('u_clara_sec', username: 'clara_sec'), isTrue);

    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();

    // 4. Em Grupos -> Convidar @ mostra Clara nas sugestões rápidas e permite convidar em 1 clique
    await tester.ensureVisible(find.text('Grupos').first);
    await tester.tap(find.text('Grupos').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('groups_create_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('create_group_name_field')), 'Squad Conexões');
    await tester.tap(find.byKey(const Key('create_group_confirm_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('group_invite_member_button')));
    await tester.pumpAndSettle();
    expect(find.text('SUGESTÕES RÁPIDAS'), findsOneWidget);
    expect(find.byKey(const Key('invite_suggestion_row_u_clara_sec')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('invite_quick_u_clara_sec')));
    await tester.tap(find.byKey(const Key('invite_quick_u_clara_sec')));
    await tester.pumpAndSettle();

    final createdGroup = StudyGroupsService.instance.groupsNotifier.value.first;
    expect(createdGroup.members.any((m) => m.username == 'clara_sec'), isTrue);

    await TestAppHarness.drainAsync(tester);
  });
}
