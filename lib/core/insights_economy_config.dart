/// Configuração central da Economia de Insights (v1).
/// Mantém nome da moeda, tabela de recompensas, preços de temas e regras anti-abuso
/// em um único ponto para facilitar calibração futura.
enum ThemePriceTier {
  starter,
  essential,
  intermediate,
  advanced,
  legendary,
  vipCustom,
}

class InsightsEconomyConfig {
  InsightsEconomyConfig._();

  // Identidade da Moeda
  static const String currencyName = 'Insights';
  static const String currencySingular = 'Insight';
  static const String currencySymbol = '✦';

  static String formatBalance(int amount) => '$amount $currencySymbol $currencyName';
  static String formatCompact(int amount) => '$amount $currencySymbol';

  // Tabela v1 — Ganhos por esforço real
  static const int quizQuestionAnswered = 1;
  static const int quizQuestionCorrectBonus = 2; // +1 base +2 extra = 3 total
  static const int flashcardDueReview = 1; // somente quando está na hora de revisar
  static const int flashcardHardRedeemedBonus = 2; // card marcado como difícil e acertado depois
  static const int examCompleted = 20;
  static const double examHighScoreThresholdPct = 80.0;
  static const int examHighScoreBonus = 30;
  static const int dailyGoalHit = 15;
  static const int weeklyGoalHit = 150;
  static const int welcomeBonus = 100;

  static const Map<int, int> streakMilestones = {
    3: 20,
    7: 60,
    14: 120,
    30: 300,
  };

  // Regras anti-abuso (v1) e multiplicador VIP
  static const Duration minQuizQuestionDuration = Duration(seconds: 3);
  static const List<double> examRepeatMultipliers = [1.0, 0.5, 0.25];
  static const int dailySoftCap = 150;
  static const double softCapMultiplier = 0.5;
  static const int vipGainMultiplier = 2;

  // Itens do Arsenal de Estudo
  static const int streakProtectorPrice = 180;
  static const int maxStreakProtectors = 5;
  static const int vipMaxStreakProtectors = maxStreakProtectors * 2; // 10 para VIP
  static const int vipMonthlyFreeProtectors = 2;
  static const int questionsPerFreeStreakProtector = 100;
  static const int weeklyStudyMinutesPerFreeStreakProtector = 10 * 60; // 10h/semana

  static int maxStreakProtectorsForVip(bool isVip) =>
      isVip ? vipMaxStreakProtectors : maxStreakProtectors;

  // Tabela v1 — Faixas e preços de temas (soma dos 10 temas pagos = 6.300 Insights)
  static const Map<String, int> themePrices = {
    'soft_clay_nevoa': 0, // Padrão (grátis)
    'aurora': 300, // Essenciais
    'floresta': 300,
    'oceano': 300,
    'brasa': 600, // Intermediários
    'lagoa': 600,
    'sakura': 600,
    'nordico': 600,
    'grafite': 1000, // Avançados
    'esmeralda': 1000,
    'crepusculo': 1000,
  };

  static const Map<String, ThemePriceTier> themeTiers = {
    'soft_clay_nevoa': ThemePriceTier.starter,
    'aurora': ThemePriceTier.essential,
    'floresta': ThemePriceTier.essential,
    'oceano': ThemePriceTier.essential,
    'brasa': ThemePriceTier.intermediate,
    'lagoa': ThemePriceTier.intermediate,
    'sakura': ThemePriceTier.intermediate,
    'nordico': ThemePriceTier.intermediate,
    'grafite': ThemePriceTier.advanced,
    'esmeralda': ThemePriceTier.advanced,
    'crepusculo': ThemePriceTier.advanced,
    'custom': ThemePriceTier.vipCustom,
  };

  static String tierLabel(ThemePriceTier tier) {
    switch (tier) {
      case ThemePriceTier.starter:
        return 'Padrão';
      case ThemePriceTier.essential:
        return 'Essenciais';
      case ThemePriceTier.intermediate:
        return 'Intermediários';
      case ThemePriceTier.advanced:
        return 'Avançados';
      case ThemePriceTier.legendary:
        return 'Especiais';
      case ThemePriceTier.vipCustom:
        return 'Exclusivo VIP';
    }
  }

  static ThemePriceTier tierForTheme(String themeId) =>
      themeTiers[themeId] ?? ThemePriceTier.intermediate;

  static int priceForTheme(String themeId) => themePrices[themeId] ?? 600;
}
