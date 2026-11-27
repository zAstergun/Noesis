import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/insights_economy_config.dart';
import 'package:noesis/core/noesis_crm_service.dart';

void main() {
  tearDown(() {
    InsightsEconomyConfig.resetRemoteOverrides();
    NoesisCrmService.instance.configNotifier.value =
        const NoesisRemotePlatformConfig();
  });

  test('NoesisRemotePlatformConfig parses feature flags, maintenance and announcement', () {
    final cfg = NoesisRemotePlatformConfig.fromRow({
      'maintenance_mode': true,
      'maintenance_message': 'Manutenção rápida',
      'allow_guest_mode': false,
      'allow_registration': true,
      'feature_flags': {
        'ai_agent': false,
        'quizzes': true,
        'study_groups': false,
      },
      'announcement': {
        'enabled': true,
        'title': 'Nova Versão',
        'message': 'Confira as novidades.',
        'type': 'release',
        'cta_label': 'Ver',
        'cta_url': 'https://noesis.asterdev.me',
      },
      'economy_config': {
        'welcome_bonus': 200,
        'daily_soft_cap': 250,
        'vip_multiplier': 3,
        'daily_goal_hit': 25,
        'weekly_goal_hit': 300,
        'exam_completed': 40,
        'exam_high_score_bonus': 60,
      },
    });

    expect(cfg.maintenanceMode, isTrue);
    expect(cfg.maintenanceMessage, 'Manutenção rápida');
    expect(cfg.allowGuestMode, isFalse);
    expect(cfg.allowRegistration, isTrue);
    expect(cfg.isFeatureEnabled('ai_agent'), isFalse);
    expect(cfg.isFeatureEnabled('quizzes'), isTrue);
    expect(cfg.isFeatureEnabled('study_groups'), isFalse);
    expect(cfg.announcement.enabled, isTrue);
    expect(cfg.announcement.type, 'release');
    expect(cfg.announcement.title, 'Nova Versão');

    NoesisCrmService.instance.configNotifier.value = cfg;
    expect(NoesisCrmService.instance.isModuleEnabledForTab(4), isFalse); // Noesis AI
    expect(NoesisCrmService.instance.isModuleEnabledForTab(1), isTrue); // Simulados
    expect(NoesisCrmService.instance.isModuleEnabledForTab(10), isFalse); // Grupos
    expect(NoesisCrmService.instance.isModuleEnabledForTab(0), isTrue); // Dashboard

    InsightsEconomyConfig.applyRemoteOverrides(cfg.economyConfig);
    expect(InsightsEconomyConfig.effectiveWelcomeBonus, 200);
    expect(InsightsEconomyConfig.effectiveDailySoftCap, 250);
    expect(InsightsEconomyConfig.effectiveVipGainMultiplier, 3);
    expect(InsightsEconomyConfig.effectiveDailyGoalHit, 25);
    expect(InsightsEconomyConfig.effectiveWeeklyGoalHit, 300);
    expect(InsightsEconomyConfig.effectiveExamCompleted, 40);
    expect(InsightsEconomyConfig.effectiveExamHighScoreBonus, 60);
    expect(InsightsEconomyConfig.dailySoftCapForElo(1, isVip: true), (250 + 20) * 3);
  });
}
