import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:noesis/core/localization/noesis_locale_service.dart';
import 'package:noesis/features/ai_agent/ai_assistant_screen.dart';
import 'package:noesis/features/calendar/calendar_screen.dart';
import 'package:noesis/features/flashcards/flashcards_screen.dart';
import 'package:noesis/features/notebooks/notebooks_screen.dart';
import 'package:noesis/features/profile/models/profile_achievements.dart';
import 'package:noesis/features/profile/models/profile_cosmetics.dart';
import 'package:noesis/features/profile/models/user_profile_model.dart';
import 'package:noesis/features/profile/profile_screen.dart';
import 'package:noesis/features/quizzes/quiz_screen.dart';
import 'package:noesis/features/ranking/data/ranking_service.dart';
import 'package:noesis/features/ranking/models/ranking_league_model.dart';
import 'package:noesis/features/ranking/ranking_screen.dart';
import 'package:noesis/features/roadmaps/roadmaps_screen.dart';
import 'package:noesis/features/shop/shop_screen.dart';
import 'package:noesis/features/study_groups/data/study_groups_service.dart';
import 'package:noesis/features/study_groups/study_groups_screen.dart';
import 'package:noesis/features/study_log/study_log_screen.dart';
import 'package:noesis/features/tracker/tracker_screen.dart';

import '../../harness/test_app_harness.dart';
import '../helpers/localization_test_helpers.dart';

String _extractAllTextUnder(WidgetTester tester, Finder rootFinder) {
  final textFinder = find.descendant(
    of: rootFinder,
    matching: find.byType(Text),
  );
  final buffer = StringBuffer();
  for (final widget in tester.widgetList<Text>(textFinder)) {
    final text = widget.data ?? widget.textSpan?.toPlainText() ?? '';
    if (text.trim().isNotEmpty) {
      buffer.writeln(text);
    }
  }
  return buffer.toString();
}

void main() {
  setUpAll(() => LocalizationTestHelpers.setUpSuite());

  setUp(() => LocalizationTestHelpers.resetState());

  tearDown(() => LocalizationTestHelpers.resetState());

  group('F11 — Community, Ranking, Profile & Shop', () {
    testWidgets(
      'F11-T1: ProfileScreen renders localized sections, stats, and achievements card in English',
      (tester) async {
        await LocalizationTestHelpers.pumpScreen(
          tester,
          const ProfileScreen(),
          locale: const Locale('en', 'GB'),
        );
        await TestAppHarness.drainAsync(tester);

        expect(find.byKey(const Key('profile_screen_root')), findsOneWidget);
        expect(find.byKey(const Key('profile_milestones_card')), findsOneWidget);
        expect(find.byKey(const Key('profile_edit_button')), findsOneWidget);

        final editBtnText = _extractAllTextUnder(
          tester,
          find.byKey(const Key('profile_edit_button')),
        );
        final milestonesText = _extractAllTextUnder(
          tester,
          find.byKey(const Key('profile_milestones_card')),
        );

        expect(editBtnText, isNot(contains('Editar Perfil')));
        expect(milestonesText, isNot(contains('Conquistas')));
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(
            '$editBtnText $milestonesText',
          ),
          isFalse,
        );
      },
    );

    test(
      'F11-T2: ProfileAchievementsCatalog (12) and ProfileCosmeticsCatalog (29) localize in English',
      () async {
        await NoesisLocaleService.setLanguage('en');

        const sampleProfile = PublicUserProfile(
          userId: 'u-test-1',
          username: 'tester',
          displayName: 'Test Learner',
          weeklyMinutes: 120,
          streakDays: 3,
          eloIndex: 1,
        );

        final achievements = ProfileAchievementsCatalog.evaluateForAccount(
          me: sampleProfile,
          totalQuizQuestionsAnswered: 15,
          totalBestEloIndex: 1,
          top3Finishes: 0,
          joinedGroupsCount: 1,
          mutualConnectionsCount: 0,
          equippedBannerId: ProfileCosmeticsCatalog.defaultBannerId,
          equippedFrameId: ProfileCosmeticsCatalog.defaultFrameId,
          equippedTitleId: ProfileCosmeticsCatalog.defaultTitleId,
          report: null,
          primaryCol: const Color(0xFF7C6CF0),
        );

        expect(achievements.length, equals(12));
        for (final a in achievements) {
          expect(
            a.title.trim(),
            isNotEmpty,
            reason: 'Achievement ${a.id} title must be non-empty',
          );
          expect(
            a.description.trim(),
            isNotEmpty,
            reason: 'Achievement ${a.id} description must be non-empty',
          );
          expect(
            a.statusLabel.trim(),
            isNotEmpty,
            reason: 'Achievement ${a.id} statusLabel must be non-empty',
          );
          expect(a.title, isNot('Primeiro Passo'));
          expect(a.statusLabel, isNot('Concluído'));
          expect(
            LocalizationTestHelpers.containsPortugueseLeakage(
              '${a.title} ${a.description} ${a.statusLabel}',
            ),
            isFalse,
            reason: 'Achievement ${a.id} leaked Portuguese: ${a.title}',
          );
        }

        final cosmetics = ProfileCosmeticsCatalog.all;
        expect(cosmetics.length, equals(29));
        for (final item in cosmetics) {
          expect(
            item.name.trim(),
            isNotEmpty,
            reason: 'Cosmetic ${item.id} name must be non-empty',
          );
          expect(
            item.subtitle.trim(),
            isNotEmpty,
            reason: 'Cosmetic ${item.id} subtitle must be non-empty',
          );
          expect(item.name, isNot('Névoa do Elo'));
          expect(
            LocalizationTestHelpers.containsPortugueseLeakage(
              '${item.name} ${item.subtitle}',
            ),
            isFalse,
            reason: 'Cosmetic ${item.id} leaked Portuguese: ${item.name}',
          );
        }
      },
    );

    testWidgets(
      'F11-T3: RankingScreen and RankingEloCatalog (8 Elos) localize league names and countdown in English',
      (tester) async {
        RankingService.allowSyntheticPeersForTesting = true;
        await RankingService.instance.resetForTesting();

        await LocalizationTestHelpers.pumpScreen(
          tester,
          const RankingScreen(),
          locale: const Locale('en', 'GB'),
        );
        await TestAppHarness.drainAsync(tester);

        expect(find.byKey(const Key('ranking_screen_root')), findsOneWidget);
        expect(find.byKey(const Key('ranking_elo_track_card')), findsOneWidget);

        expect(RankingEloCatalog.tiers.length, equals(8));
        for (final tier in RankingEloCatalog.tiers) {
          expect(tier.name, isNot('Faísca'));
          expect(
            LocalizationTestHelpers.containsPortugueseLeakage(
              '${tier.name} ${tier.subtitle} ${tier.milestoneDescription}',
            ),
            isFalse,
            reason: 'Elo tier ${tier.id} leaked Portuguese: ${tier.name}',
          );
        }

        final rankingText = _extractAllTextUnder(
          tester,
          find.byKey(const Key('ranking_screen_root')),
        );
        expect(rankingText, isNot(contains('restantes')));
        expect(rankingText, isNot(contains('Faísca')));
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(rankingText),
          isFalse,
        );
      },
    );

    testWidgets(
      'F11-T4: StudyGroupsScreen localizes workspace header and create/join buttons in English',
      (tester) async {
        await StudyGroupsService.instance.resetForTesting();

        await LocalizationTestHelpers.pumpScreen(
          tester,
          const StudyGroupsScreen(),
          locale: const Locale('en', 'GB'),
        );
        await TestAppHarness.drainAsync(tester);

        expect(find.byKey(const Key('groups_join_button')), findsOneWidget);
        expect(find.byKey(const Key('groups_create_button')), findsOneWidget);

        final joinText = _extractAllTextUnder(
          tester,
          find.byKey(const Key('groups_join_button')),
        );
        final createText = _extractAllTextUnder(
          tester,
          find.byKey(const Key('groups_create_button')),
        );

        expect(joinText, isNot(contains('Entrar com Código')));
        expect(createText, isNot(contains('Criar Grupo')));
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage('$joinText $createText'),
          isFalse,
        );
      },
    );

    testWidgets(
      'F11-T5: ShopScreen localizes section tabs, balance card, and economy copy in English',
      (tester) async {
        await LocalizationTestHelpers.pumpScreen(
          tester,
          const ShopScreen(),
          locale: const Locale('en', 'GB'),
        );
        await TestAppHarness.drainAsync(tester);

        expect(find.byKey(const Key('shop_section_all')), findsOneWidget);
        expect(find.byKey(const Key('shop_section_themes')), findsOneWidget);
        expect(find.byKey(const Key('shop_section_arsenal')), findsOneWidget);
        expect(find.byKey(const Key('shop_section_identity')), findsOneWidget);

        final allText = _extractAllTextUnder(
          tester,
          find.byKey(const Key('shop_section_all')),
        );
        final themesText = _extractAllTextUnder(
          tester,
          find.byKey(const Key('shop_section_themes')),
        );
        final identityText = _extractAllTextUnder(
          tester,
          find.byKey(const Key('shop_section_identity')),
        );

        expect(allText, isNot(contains('Todos')));
        expect(themesText, isNot(contains('Temas')));
        expect(identityText, isNot(contains('Identidade')));
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(
            '$allText $themesText $identityText',
          ),
          isFalse,
        );
      },
    );
  });

  group('F12 — Study Modules UI & Dynamic Dates', () {
    testWidgets(
      'F12-T1: TrackerScreen and StudyLogScreen localize KPIs and date header in French (fr)',
      (tester) async {
        await LocalizationTestHelpers.pumpScreen(
          tester,
          const TrackerScreen(),
          locale: const Locale('fr', 'FR'),
        );
        await TestAppHarness.drainAsync(tester);

        expect(find.byKey(const Key('dashboard_kpi_weekly_goal')), findsOneWidget);
        final weeklyKpiText = _extractAllTextUnder(
          tester,
          find.byKey(const Key('dashboard_kpi_weekly_goal')),
        );
        expect(weeklyKpiText, isNot(contains('Meta Semanal')));
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(weeklyKpiText),
          isFalse,
        );

        await LocalizationTestHelpers.pumpScreen(
          tester,
          const StudyLogScreen(),
          locale: const Locale('fr', 'FR'),
        );
        await TestAppHarness.drainAsync(tester);

        expect(find.byKey(const Key('study_log_daily_goal_kpi')), findsOneWidget);
        final studyLogText = _extractAllTextUnder(
          tester,
          find.byType(StudyLogScreen),
        );
        expect(studyLogText, isNot(contains('Diário de Estudos')));
        expect(
          RegExp(r'\d+\s+de\s+[a-zç]+').hasMatch(studyLogText.toLowerCase()),
          isFalse,
          reason: 'StudyLogScreen date should use French format, not Portuguese "de"',
        );
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(studyLogText),
          isFalse,
        );
      },
    );

    testWidgets(
      'F12-T2: CalendarScreen renders dynamically in Japanese (ja) without LocaleDataException',
      (tester) async {
        await LocalizationTestHelpers.pumpScreen(
          tester,
          const CalendarScreen(),
          locale: const Locale('ja', 'JP'),
        );
        await TestAppHarness.drainAsync(tester);

        expect(find.byType(CalendarScreen), findsOneWidget);
        final calText = _extractAllTextUnder(
          tester,
          find.byType(CalendarScreen),
        );

        expect(calText, isNot(contains('Calendário')));
        expect(calText, isNot(contains('Hoje')));
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(calText),
          isFalse,
        );

        // Expect Japanese month symbol formatting (e.g., 11月) rather than Portuguese month names.
        final expectedJaMonth = DateFormat.MMMM('ja_JP').format(DateTime.now());
        expect(calText, contains(expectedJaMonth));
      },
    );

    testWidgets(
      'F12-T3: NotebooksScreen and RoadmapsScreen localize filters and headers in German (de)',
      (tester) async {
        await LocalizationTestHelpers.pumpScreen(
          tester,
          const NotebooksScreen(),
          locale: const Locale('de', 'DE'),
        );
        await TestAppHarness.drainAsync(tester);

        expect(find.byKey(const Key('notebooks_filter_all')), findsOneWidget);
        expect(find.byKey(const Key('notebooks_filter_to_review')), findsOneWidget);
        expect(find.byKey(const Key('notebooks_filter_up_to_date')), findsOneWidget);

        final nbFiltersText = _extractAllTextUnder(
          tester,
          find.byKey(const Key('notebooks_filter_all')),
        );
        final nbReviewText = _extractAllTextUnder(
          tester,
          find.byKey(const Key('notebooks_filter_to_review')),
        );
        expect(nbFiltersText, isNot(contains('Todos')));
        expect(nbReviewText, isNot(contains('Para Revisar')));
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(
            '$nbFiltersText $nbReviewText',
          ),
          isFalse,
        );

        await LocalizationTestHelpers.pumpScreen(
          tester,
          const RoadmapsScreen(),
          locale: const Locale('de', 'DE'),
        );
        await TestAppHarness.drainAsync(tester);

        final roadmapText = _extractAllTextUnder(
          tester,
          find.byType(RoadmapsScreen),
        );
        expect(roadmapText, isNot(contains('Trilhas')));
        expect(roadmapText, isNot(contains('A fazer')));
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(roadmapText),
          isFalse,
        );
      },
    );

    testWidgets(
      'F12-T4: FlashcardsScreen localizes filter pills and review labels in Spanish (es)',
      (tester) async {
        await LocalizationTestHelpers.pumpScreen(
          tester,
          const FlashcardsScreen(),
          locale: const Locale('es', 'ES'),
        );
        await TestAppHarness.drainAsync(tester);

        expect(find.byKey(const Key('filter_status_all')), findsOneWidget);
        expect(find.byKey(const Key('filter_status_to_review')), findsOneWidget);
        expect(find.byKey(const Key('filter_status_completed')), findsOneWidget);

        final allText = _extractAllTextUnder(
          tester,
          find.byKey(const Key('filter_status_all')),
        );
        final toReviewText = _extractAllTextUnder(
          tester,
          find.byKey(const Key('filter_status_to_review')),
        );
        final completedText = _extractAllTextUnder(
          tester,
          find.byKey(const Key('filter_status_completed')),
        );

        expect(toReviewText, isNot(contains('Para Revisar')));
        expect(completedText, isNot(contains('Concluídos')));
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(
            '$allText $toReviewText $completedText',
          ),
          isFalse,
        );
      },
    );

    testWidgets(
      'F12-T5: QuizScreen localizes official/free mode cards and labels in English (en)',
      (tester) async {
        await LocalizationTestHelpers.pumpScreen(
          tester,
          const QuizScreen(),
          locale: const Locale('en', 'GB'),
        );
        await TestAppHarness.drainAsync(tester);

        expect(
          find.byKey(const Key('quiz_official_model_mode_card')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('quiz_free_mode_card')), findsOneWidget);

        final officialText = _extractAllTextUnder(
          tester,
          find.byKey(const Key('quiz_official_model_mode_card')),
        );
        final freeText = _extractAllTextUnder(
          tester,
          find.byKey(const Key('quiz_free_mode_card')),
        );

        expect(officialText, isNot(contains('Simulado Oficial')));
        expect(freeText, isNot(contains('Modo Livre')));
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(
            '$officialText $freeText',
          ),
          isFalse,
        );
      },
    );

    testWidgets(
      'F12-T6: AiAssistantScreen localizes onboarding capabilities and missing-key notice in English (en)',
      (tester) async {
        await LocalizationTestHelpers.pumpScreen(
          tester,
          const AiAssistantScreen(),
          locale: const Locale('en', 'GB'),
        );
        await TestAppHarness.drainAsync(tester);

        expect(find.byKey(const Key('ai_capabilities_overview')), findsOneWidget);
        expect(find.byKey(const Key('ai_missing_key_notice')), findsOneWidget);

        final aiText = _extractAllTextUnder(
          tester,
          find.byType(AiAssistantScreen),
        );
        expect(aiText, isNot(contains('Plano de estudo de hoje')));
        expect(aiText, isNot(contains('Configure uma chave de IA')));
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(aiText),
          isFalse,
        );
      },
    );
  });
}
