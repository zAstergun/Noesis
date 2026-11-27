import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/shop_service.dart';
import 'package:noesis/core/supabase_service.dart';
import 'package:noesis/features/flashcards/models/flashcard_model.dart';
import 'package:noesis/features/notebooks/models/notebook_model.dart';
import 'package:noesis/features/quizzes/data/saved_exams_repository.dart';
import 'package:noesis/features/roadmaps/data/roadmaps_repository.dart';
import 'package:noesis/features/roadmaps/models/roadmap_model.dart';
import 'package:noesis/features/study_groups/data/study_groups_service.dart';
import 'package:noesis/features/study_groups/models/study_group_model.dart';
import 'package:noesis/main.dart';
import '../../e2e/harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  setUp(() async {
    await StudyGroupsService.instance.resetForTesting();
    await ShopService.instance.resetForTesting(initialBalance: 150);
  });

  tearDown(() async {
    await StudyGroupsService.instance.resetForTesting();
  });

  test('StudyGroupsService supports invites (@ and link), chat, private attach isolation, group-only ranking, and leader-only controls', () async {
    final svc = StudyGroupsService.instance;
    const leaderId = 'leader-1';
    const memberId = 'member-2';

    // Saldo global alto fora do grupo não deve contaminar o ranking interno do grupo
    await ShopService.instance.resetForTesting(initialBalance: 500);

    // 1. Líder cria o grupo e começa com 0 Insights no ranking interno do grupo
    final created = await svc.createGroup(
      name: 'Squad Security+',
      subject: 'Segurança',
      description: 'Estudo diário SY0-701',
      actorUserId: leaderId,
      actorUsername: 'ana_sec',
      actorDisplayName: 'Ana Líder',
    );
    expect(created.ok, isTrue);
    final group = created.group!;
    expect(group.isLeader(leaderId), isTrue);
    expect(group.inviteLink, contains(group.inviteCode));
    expect(group.memberFor(leaderId)!.insightsScore, 0);

    // Segundo grupo para garantir que pontos ganhos no grupo 1 não vazem para o grupo 2
    final otherGroupRes = await svc.createGroup(
      name: 'Grupo Paralelo',
      actorUserId: leaderId,
      actorUsername: 'ana_sec',
      actorDisplayName: 'Ana Líder',
    );
    final otherGroupId = otherGroupRes.group!.id;

    // 2. Convite por link coloca membro comum sem permissões elevadas e score 0 no grupo
    final joined = await svc.joinByInviteLinkOrCode(
      codeOrLink: group.inviteLink,
      actorUserId: memberId,
      actorUsername: 'bruno_dev',
      actorDisplayName: 'Bruno',
    );
    expect(joined.ok, isTrue);
    expect(joined.group!.members.length, 2);
    expect(joined.group!.memberFor(memberId)!.insightsScore, 0);
    expect(joined.group!.canUserInvite(memberId), isFalse);
    expect(joined.group!.canUserEdit(memberId), isFalse);
    expect(joined.group!.canUserRemoveContent(memberId), isFalse);

    // Membro comum não pode convidar ou alterar configurações antes do líder liberar
    final deniedInvite = await svc.inviteMemberByUsername(
      groupId: group.id,
      username: '@carlos',
      actorUserId: memberId,
    );
    expect(deniedInvite.ok, isFalse);

    final deniedSettings = await svc.updateGroupSettings(
      groupId: group.id,
      actorUserId: memberId,
      rankingEnabled: false,
    );
    expect(deniedSettings.ok, isFalse);

    // 3. Líder dá permissão individual para Bruno convidar e editar
    await svc.setMemberPermissions(
      groupId: group.id,
      targetUserId: memberId,
      actorUserId: leaderId,
      canInvite: true,
      canEdit: true,
    );

    final allowedInvite = await svc.inviteMemberByUsername(
      groupId: group.id,
      username: '@carlos_cloud',
      actorUserId: memberId,
      displayNameHint: 'Carlos',
    );
    expect(allowedInvite.ok, isTrue);
    expect(allowedInvite.group!.members.any((m) => m.username == 'carlos_cloud'), isTrue);

    // Chat interno do grupo
    final chatRes = await svc.sendChatMessage(
      groupId: group.id,
      text: 'Bora revisar IAM hoje!',
      actorUserId: memberId,
    );
    expect(chatRes.ok, isTrue);
    expect(chatRes.group!.chatMessages.length, 1);
    expect(chatRes.group!.chatMessages.first.text, 'Bora revisar IAM hoje!');

    // 4. Isolamento privado ao anexar: usuário externo não vê itens pessoais da conta ativa
    final nb = StudyNotebook(
      id: 'nb-priv-1',
      title: 'Notas Privadas Ana',
      subject: 'Segurança',
      notes: [
        StudyNote(id: 'n1', notebookId: 'nb-priv-1', title: 'IAM', content: '### Least privilege'),
      ],
    );
    await SupabaseService.saveNotebook(nb);
    final deck = FlashcardDeck(
      id: 'dk-priv-1',
      title: 'Baralho Pessoal Ana',
      subject: 'Segurança',
      description: 'Cards privados',
      cards: [Flashcard(id: 'c1', front: 'MFA?', back: 'Multi-factor authentication')],
      createdAt: DateTime(2026, 11, 25),
    );
    await SupabaseService.saveFlashcardDeck(deck);

    final ownAttachables = await svc.loadAttachablePersonalContent();
    expect(ownAttachables.notebooks.any((e) => e.id == 'nb-priv-1'), isTrue);
    expect(ownAttachables.decks.any((e) => e.id == 'dk-priv-1'), isTrue);

    final foreignAttachables = await svc.loadAttachablePersonalContent(actorUserId: memberId);
    expect(foreignAttachables.notebooks, isEmpty);
    expect(foreignAttachables.decks, isEmpty);
    expect(foreignAttachables.exams, isEmpty);
    expect(foreignAttachables.roadmaps, isEmpty);

    // 5. Anexa caderno, baralho, simulado, trilha e estuda DENTRO do grupo
    final exam = SavedExamAttempt(
      id: 'ex-grp-1',
      groupKey: 'sec',
      examModelId: null,
      examModelName: 'Security+',
      title: 'Simulado IAM & PKI',
      subject: 'Segurança',
      topic: 'PKI',
      difficulty: 'Difícil',
      createdAt: DateTime(2026, 11, 25),
      elapsedSeconds: 180,
      targetTotalCount: 1,
      questions: [
        {
          'question': 'O que assina certificados?',
          'options': ['DNS', 'CA', 'ARP', 'NTP'],
          'correct_index': 1,
        },
      ],
      userAnswers: const {0: 1},
      correctCount: 1,
      wrongCount: 0,
      blankCount: 0,
      scorePercentage: 100,
    );
    final rm = StudyRoadmap(
      id: 'rm-grp-1',
      title: 'Trilha Cripto',
      subject: 'Segurança',
      goal: 'Dominar PKI',
      level: 'Intermediário',
      steps: const [RoadmapStep(id: 's1', title: 'AES & RSA', status: RoadmapStepStatus.todo)],
      createdAt: DateTime(2026, 11, 25),
      updatedAt: DateTime(2026, 11, 25),
    );
    await RoadmapsRepository.saveRoadmap(rm, syncRemote: false);

    final attNb = await svc.attachNotebook(groupId: group.id, notebook: nb, actorUserId: memberId, actorHandle: 'bruno_dev');
    final attDk = await svc.attachDeck(groupId: group.id, deck: deck, actorUserId: leaderId, actorHandle: 'ana_sec');
    final attEx = await svc.attachExam(groupId: group.id, exam: exam, actorUserId: leaderId, actorHandle: 'ana_sec');
    final attRm = await svc.attachRoadmap(groupId: group.id, roadmap: rm, actorUserId: leaderId, actorHandle: 'ana_sec');
    expect(attNb.ok && attDk.ok && attEx.ok && attRm.ok, isTrue);

    // Ganho externo fora do grupo NÃO entra no ranking interno do grupo
    ShopService.instance.awardForQuizAnswer(isCorrect: true);

    // Ganho DENTRO do grupo (diário + flashcard + trilha) soma apenas neste grupo
    final logRes = await svc.addStudyLogEntry(
      groupId: group.id,
      subject: 'Criptografia',
      topic: 'TLS 1.3',
      durationMinutes: 45,
      actorUserId: memberId,
      actorName: 'Bruno',
      actorHandle: 'bruno_dev',
    );
    expect(logRes.earnedInsights, greaterThan(0));

    final fcRes = await svc.recordGroupFlashcardReview(
      groupId: group.id,
      shareId: attDk.group!.sharedDecks.first.shareId,
      cardId: 'c1',
      deckTitle: deck.title,
      quality: 'good',
      actorUserId: memberId,
    );
    expect(fcRes.earnedInsights, greaterThan(0));

    final current = svc.groupsNotifier.value.firstWhere((g) => g.id == group.id);
    final parallel = svc.groupsNotifier.value.firstWhere((g) => g.id == otherGroupId);
    expect(current.sharedNotebooks.length, 1);
    expect(current.sharedDecks.length, 1);
    expect(current.sharedExams.length, 1);
    expect(current.sharedRoadmaps.length, 1);
    expect(current.studyLogs.length, 1);
    expect(current.rankedMembers.first.userId, memberId);
    expect(
      current.memberFor(memberId)!.insightsScore,
      logRes.earnedInsights + fcRes.earnedInsights,
    );
    expect(current.memberFor(leaderId)!.insightsScore, 0);
    expect(parallel.memberFor(leaderId)!.insightsScore, 0);

    // 6. Apenas líder remove conteúdos anexados e pode desativar ranking
    final shareId = current.sharedNotebooks.first.shareId;
    final memberRemoveAttempt = await svc.removeSharedContent(
      groupId: group.id,
      kind: StudyGroupContentKind.notebook,
      shareId: shareId,
      actorUserId: memberId,
    );
    expect(memberRemoveAttempt.ok, isFalse);

    final leaderRemove = await svc.removeSharedContent(
      groupId: group.id,
      kind: StudyGroupContentKind.notebook,
      shareId: shareId,
      actorUserId: leaderId,
    );
    expect(leaderRemove.ok, isTrue);
    expect(leaderRemove.group!.sharedNotebooks, isEmpty);

    final toggleRank = await svc.updateGroupSettings(
      groupId: group.id,
      actorUserId: leaderId,
      rankingEnabled: false,
    );
    expect(toggleRank.group!.rankingEnabled, isFalse);
  });

  testWidgets('Grupos tab supports chat, rendered markdown notebook, in-group flashcards without leaving tab, and group-only ranking', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await SupabaseService.saveNotebook(
      StudyNotebook(
        id: 'nb-ui-share-1',
        title: 'Caderno Compartilhável',
        subject: 'Redes',
        notes: [
          StudyNote(
            id: 'n-ui-1',
            notebookId: 'nb-ui-share-1',
            title: 'TCP',
            content: '### Handshake\nConexão **3-way** no TCP.',
          ),
        ],
      ),
    );
    await SupabaseService.saveFlashcardDeck(
      FlashcardDeck(
        id: 'dk-ui-share-1',
        title: 'Baralho TCP',
        subject: 'Redes',
        description: 'Cartões de revisão',
        cards: [
          Flashcard(id: 'c-ui-1', front: 'SYN/ACK?', back: 'Confirmação do servidor'),
        ],
        createdAt: DateTime(2026, 11, 25),
      ),
    );

    await TestAppHarness.pumpInHarness(tester, const NoesisApp());
    await tester.pumpAndSettle();

    final guestBtn = find.text('Entrar sem login · Modo de Teste');
    if (guestBtn.evaluate().isNotEmpty) {
      await tester.tap(guestBtn);
      await tester.pumpAndSettle();
    }

    // Abre a aba Grupos na sidebar
    await tester.tap(find.text('Grupos').first);
    await tester.pumpAndSettle();
    expect(find.text('Grupos de Estudo'), findsOneWidget);

    // Cria um novo grupo
    await tester.tap(find.byKey(const Key('groups_create_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('create_group_name_field')), 'Grupo Cloud AWS');
    await tester.tap(find.byKey(const Key('create_group_confirm_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('group_workspace_view')), findsOneWidget);
    expect(find.text('Grupo Cloud AWS'), findsOneWidget);

    // Chat abre como primeira aba padrão ao entrar/criar um grupo e na ordem organizada
    expect(find.byKey(const Key('group_chat_view')), findsOneWidget);
    final orderedTabKeys = [
      const Key('group_tab_chat'),
      const Key('group_tab_exams'),
      const Key('group_tab_decks'),
      const Key('group_tab_notebooks'),
      const Key('group_tab_roadmaps'),
      const Key('group_tab_diary'),
      const Key('group_tab_ranking'),
      const Key('group_tab_settings'),
    ];
    for (int i = 0; i < orderedTabKeys.length - 1; i++) {
      final left = tester.getTopLeft(find.byKey(orderedTabKeys[i]));
      final right = tester.getTopLeft(find.byKey(orderedTabKeys[i + 1]));
      expect(
        right.dy > left.dy || (right.dy == left.dy && right.dx > left.dx),
        isTrue,
        reason: 'Tab ${orderedTabKeys[i]} should appear before ${orderedTabKeys[i + 1]}',
      );
    }

    // Convida colega pelo @usuario
    await tester.tap(find.byKey(const Key('group_invite_member_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('invite_username_field')), 'maria_aws');
    await tester.tap(find.byKey(const Key('invite_username_confirm_button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('@maria_aws'), findsAtLeastNWidgets(1));

    // Conversa na nova aba Chat do grupo, vê avatar e abre perfil do remetente
    await tester.tap(find.byKey(const Key('group_tab_chat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group_chat_view')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('group_chat_input')), 'Vamos revisar TCP hoje!');
    await tester.tap(find.byKey(const Key('group_chat_send_button')));
    await tester.pumpAndSettle();
    expect(find.text('Vamos revisar TCP hoje!'), findsOneWidget);

    final sentMsg = StudyGroupsService.instance.groupsNotifier.value.first.chatMessages.first;
    expect(find.byKey(Key('group_chat_avatar_${sentMsg.id}')), findsOneWidget);
    await tester.tap(find.byKey(Key('group_chat_avatar_${sentMsg.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group_member_profile_modal')), findsOneWidget);
    expect(find.text('Perfil do Membro'), findsOneWidget);
    await tester.tap(find.text('Fechar').last);
    await tester.pumpAndSettle();

    // Anexa e lê caderno dentro do grupo usando a tela real de Cadernos (com criação, IA e Markdown)
    await tester.tap(find.byKey(const Key('group_tab_notebooks')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group_create_notebook_button')), findsOneWidget);
    expect(find.byKey(const Key('group_attach_notebook_button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('group_attach_notebook_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group_attach_personal_dialog')), findsOneWidget);
    await tester.tap(find.text('Caderno Compartilhável'));
    await tester.pumpAndSettle();

    final openNotebookBtn = find.text('Abrir Caderno 📖').first;
    await tester.ensureVisible(openNotebookBtn);
    await tester.tap(openNotebookBtn);
    await tester.pumpAndSettle();
    expect(find.text('Handshake', findRichText: true), findsOneWidget);
    expect(find.text('### Handshake', findRichText: true), findsNothing);
    expect(find.byKey(const Key('group_workspace_view')), findsOneWidget);

    // Anexa baralho e estuda DENTRO do grupo usando a tela real de Flashcards (com IA e importação)
    await tester.tap(find.byKey(const Key('group_tab_decks')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group_create_deck_button')), findsOneWidget);
    expect(find.text('Gerar com IA ✨'), findsOneWidget);
    expect(find.text('Importar Arquivo'), findsOneWidget);
    await tester.tap(find.byKey(const Key('group_attach_deck_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Baralho TCP'));
    await tester.pumpAndSettle();

    final fcScrollable = find.descendant(
      of: find.byType(CustomScrollView).last,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Estudar Agora 🚀'),
      200,
      scrollable: fcScrollable.first,
    );
    await tester.ensureVisible(find.text('Estudar Agora 🚀').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estudar Agora 🚀').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ver Resposta (Virar Cartão) 👆'));
    await tester.tap(find.text('Ver Resposta (Virar Cartão) 👆'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bom 🟡'));
    await tester.tap(find.text('Bom 🟡'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Concluir'));
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group_workspace_view')), findsOneWidget);

    // Verifica que Simulados e Trilhas no grupo renderizam os fluxos reais com IA e botão de anexar
    await tester.tap(find.byKey(const Key('group_tab_exams')));
    await tester.pumpAndSettle();
    expect(find.text('SIMULADOS DO GRUPO COM IA'), findsOneWidget);
    expect(find.byKey(const Key('group_attach_exam_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('group_tab_roadmaps')));
    await tester.pumpAndSettle();
    expect(find.text('Nova Trilha Manual'), findsOneWidget);
    expect(find.text('Criar com IA'), findsOneWidget);
    expect(find.byKey(const Key('group_attach_roadmap_button')), findsOneWidget);

    // Verifica Ranking interno apenas com os Insights ganhos dentro do grupo (+1 pela revisão do card) e avatar dos membros
    await tester.tap(find.byKey(const Key('group_tab_ranking')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group_ranking_board')), findsOneWidget);
    final myUid = StudyGroupsService.currentUserId;
    final rankedGroup = StudyGroupsService.instance.groupsNotifier.value.firstWhere((g) => g.id != '');
    expect(rankedGroup.memberFor(myUid)?.insightsScore, 1);
    expect(find.text('1'), findsAtLeastNWidgets(1));
    expect(find.byKey(Key('group_ranking_avatar_$myUid')), findsOneWidget);

    // Verifica avatar nas Configurações (Permissões por membro) e abre perfil pelo membro
    await tester.tap(find.byKey(const Key('group_tab_settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('group_settings_avatar_$myUid')), findsOneWidget);
    await tester.tap(find.byKey(Key('group_settings_member_profile_$myUid')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group_member_profile_modal')), findsOneWidget);
    await tester.tap(find.text('Fechar').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('group_setting_ranking_enabled')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('group_tab_ranking')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group_ranking_disabled_notice')), findsOneWidget);

    await TestAppHarness.drainAsync(tester);
  });

  testWidgets('Group flashcards isolate progress per user and Realizados shows how each member performed',
      (WidgetTester tester) async {
    final svc = StudyGroupsService.instance;
    final created = await svc.createGroup(
      name: 'Turma Certificação',
      description: 'Progresso individual e comparativo',
      subject: 'Security+',
      actorUserId: StudyGroupsService.currentUserId,
      actorDisplayName: 'Visitante',
      actorUsername: 'estudante',
    );
    expect(created.ok, isTrue);
    final group = created.group!;

    final joinedB = await svc.joinByInviteLinkOrCode(
      codeOrLink: group.inviteCode,
      actorUserId: 'user_ana',
      actorDisplayName: 'Ana Silva',
      actorUsername: 'ana_sec',
    );
    expect(joinedB.ok, isTrue);

    // 1. Flashcard compartilhado mantém progressão separada por usuário
    final deck = FlashcardDeck(
      id: 'dk-multi-1',
      title: 'Protocolos Seguros',
      subject: 'Security+',
      description: 'TLS, SSH e IPSec',
      createdAt: DateTime(2026, 11, 25),
      cards: [
        Flashcard(id: 'c-multi-1', front: 'Porta padrão HTTPS?', back: '443'),
      ],
    );
    await svc.saveGroupDeck(group.id, deck);

    await svc.recordGroupFlashcardReviewByDeckId(
      groupId: group.id,
      deckId: deck.id,
      cardId: 'c-multi-1',
      deckTitle: deck.title,
      difficulty: 'easy',
      isDueForReview: true,
      wasPreviouslyHard: false,
      allowReviewBase: true,
      actorUserId: StudyGroupsService.currentUserId,
    );

    final deckForUserA = svc.groupDecks(group.id, userId: StudyGroupsService.currentUserId).first;
    final deckForUserB = svc.groupDecks(group.id, userId: 'user_ana').first;
    expect(deckForUserA.cards.first.difficulty, 'easy');
    expect(deckForUserA.cards.first.reviewCount, 1);
    expect(deckForUserA.masteredCount, 1);

    // Ana ainda não revisou -> cartão segue pendente/unreviewed para ela
    expect(deckForUserB.cards.first.difficulty, 'unreviewed');
    expect(deckForUserB.cards.first.reviewCount, 0);
    expect(deckForUserB.masteredCount, 0);

    await svc.recordGroupFlashcardReviewByDeckId(
      groupId: group.id,
      deckId: deck.id,
      cardId: 'c-multi-1',
      deckTitle: deck.title,
      difficulty: 'hard',
      isDueForReview: true,
      wasPreviouslyHard: false,
      allowReviewBase: true,
      actorUserId: 'user_ana',
    );
    expect(svc.groupDecks(group.id, userId: 'user_ana').first.cards.first.difficulty, 'hard');
    expect(
      svc.groupDecks(group.id, userId: StudyGroupsService.currentUserId).first.cards.first.difficulty,
      'easy',
    );

    // 2. Simulados realizados no grupo preservam as tentativas de cada membro e exibem o desempenho por participante
    final sampleQuestions = [
      {
        'question': 'Qual porta padrão do HTTPS?',
        'options': ['80', '443', '22', '53'],
        'correctIndex': 1,
        'explanation': 'HTTPS usa a porta TCP 443.',
      },
      {
        'question': 'Qual porta padrão do SSH?',
        'options': ['21', '22', '25', '110'],
        'correctIndex': 1,
        'explanation': 'SSH usa a porta TCP 22.',
      },
    ];

    final attemptA = SavedExamsRepository.buildAttempt(
      id: 'att-user-a',
      examModelId: 'comptia-sec',
      examModelName: 'CompTIA Security+',
      subject: 'Security+',
      topic: 'Portas e Protocolos',
      difficulty: 'Médio / Prático',
      questions: sampleQuestions,
      userAnswers: {0: 1, 1: 0}, // 50% (1/2)
      elapsedSeconds: 95,
      targetTotalCount: 2,
    );
    final attemptB = SavedExamsRepository.buildAttempt(
      id: 'att-user-b',
      examModelId: 'comptia-sec',
      examModelName: 'CompTIA Security+',
      subject: 'Security+',
      topic: 'Portas e Protocolos',
      difficulty: 'Médio / Prático',
      questions: sampleQuestions,
      userAnswers: {0: 1, 1: 1}, // 100% (2/2)
      elapsedSeconds: 80,
      targetTotalCount: 2,
    );

    await svc.saveGroupExamAttempt(
      group.id,
      attemptA,
      actorUserId: StudyGroupsService.currentUserId,
      actorName: 'Visitante',
      actorHandle: 'estudante',
    );
    await svc.saveGroupExamAttempt(
      group.id,
      attemptB,
      actorUserId: 'user_ana',
      actorName: 'Ana Silva',
      actorHandle: 'ana_sec',
    );

    await TestAppHarness.pumpInHarness(
      tester,
      const RootScreen(),
      screenSize: const Size(1280, 900),
    );
    final guestFinder = find.textContaining('Entrar sem login');
    if (guestFinder.evaluate().isNotEmpty) {
      await tester.ensureVisible(guestFinder.first);
      await tester.tap(guestFinder.first);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Grupos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('group_card_${group.id}')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('group_tab_exams')));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Realizados').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('group_exams_members_performance_card')), findsOneWidget);
    expect(find.byKey(const Key('group_exam_member_perf_user_ana')), findsOneWidget);
    expect(find.byKey(Key('group_exam_member_perf_${StudyGroupsService.currentUserId}')), findsOneWidget);
    expect(find.byKey(const Key('group_exam_attempt_att-user-a')), findsOneWidget);
    expect(find.byKey(const Key('group_exam_attempt_att-user-b')), findsOneWidget);
    expect(find.textContaining('Ana Silva (@ana_sec)'), findsAtLeastNWidgets(1));
    expect(find.text('Notas nesta prova:'), findsAtLeastNWidgets(1));

    // Filtrando pelo membro Ana exibe apenas as tentativas dela
    await tester.ensureVisible(find.byKey(const Key('group_exam_member_perf_user_ana')));
    await tester.tap(find.byKey(const Key('group_exam_member_perf_user_ana')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group_exam_attempt_att-user-b')), findsOneWidget);
    expect(find.byKey(const Key('group_exam_attempt_att-user-a')), findsNothing);

    await TestAppHarness.drainAsync(tester);
  });

  testWidgets('Registrar no Diário do Grupo modal selects hours and minutes separately and saves total minutes',
      (WidgetTester tester) async {
    final svc = StudyGroupsService.instance;
    final created = await svc.createGroup(
      name: 'Squad Horas & Minutos',
      description: 'Registro de tempo combinado',
      subject: 'Redes',
      actorUserId: StudyGroupsService.currentUserId,
      actorDisplayName: 'Visitante',
    );
    expect(created.ok, isTrue);
    final group = created.group!;

    await TestAppHarness.pumpInHarness(
      tester,
      const RootScreen(),
      screenSize: const Size(1280, 900),
    );
    final guestFinder = find.textContaining('Entrar sem login');
    if (guestFinder.evaluate().isNotEmpty) {
      await tester.ensureVisible(guestFinder.first);
      await tester.tap(guestFinder.first);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Grupos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('group_card_${group.id}')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('group_tab_diary')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('group_add_log_button')));
    await tester.pumpAndSettle();

    expect(find.text('Registrar no Diário do Grupo'), findsOneWidget);
    expect(find.byKey(const Key('group_log_hours_field')), findsOneWidget);
    expect(find.byKey(const Key('group_log_minutes_field')), findsOneWidget);

    // Chip de 2h preenche 2 horas e 0 minutos
    await tester.tap(find.byKey(const Key('group_log_duration_chip_120')));
    await tester.pumpAndSettle();
    expect(find.text('DURAÇÃO (2H)'), findsOneWidget);

    // Preenche manualmente 1h + 45min => 105 minutos (1h 45m)
    await tester.enterText(find.byKey(const Key('group_log_topic_field')), 'Roteamento BGP');
    await tester.enterText(find.byKey(const Key('group_log_hours_field')), '1');
    await tester.enterText(find.byKey(const Key('group_log_minutes_field')), '45');
    await tester.pumpAndSettle();
    expect(find.text('DURAÇÃO (1H 45M)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('group_log_save_button')));
    await tester.pumpAndSettle();

    final updated = svc.groupsNotifier.value.firstWhere((g) => g.id == group.id);
    expect(updated.studyLogs.length, 1);
    expect(updated.studyLogs.first.durationMinutes, 105);
    expect(find.text('1h 45m'), findsAtLeastNWidgets(1));

    await TestAppHarness.drainAsync(tester);
  });
}
