/// Multilingual keyword tables for [NoesisAgentTools.parseNaturalDateTime]
/// and conversational intent matching.
///
/// Placed under `lib/core/localization/` to keep natural-language lexicons
/// grouped with localization assets.
class NaturalDateKeywords {
  NaturalDateKeywords._();

  static const List<String> dayAfterTomorrowTokens = [
    'depois de amanh',
    'day after tomorrow',
    'pasado mañana',
    'pasado manana',
    'après-demain',
    'apres-demain',
  ];

  static const List<String> tomorrowTokens = [
    'amanhã',
    'amanha',
    'tomorrow',
    'mañana',
    'manana',
    'demain',
    'morgen',
    'domani',
  ];

  static const List<String> todayTokens = [
    'hoje',
    'today',
    'hoy',
    'aujourd',
    'heute',
    'oggi',
  ];

  static const Map<int, List<String>> weekdayTokens = {
    DateTime.monday: ['segunda', 'monday', 'lunes', 'lundi', 'montag'],
    DateTime.tuesday: ['terça', 'terca', 'tuesday', 'martes', 'mardi', 'dienstag'],
    DateTime.wednesday: ['quarta', 'wednesday', 'miércoles', 'miercoles', 'mercredi', 'mittwoch'],
    DateTime.thursday: ['quinta', 'thursday', 'jueves', 'jeudi', 'donnerstag'],
    DateTime.friday: ['sexta', 'friday', 'viernes', 'vendredi', 'freitag'],
    DateTime.saturday: ['sábado', 'sabado', 'saturday', 'samedi', 'samstag'],
    DateTime.sunday: ['domingo', 'sunday', 'dimanche', 'sonntag'],
  };

  static const List<String> noonTokens = ['meio-dia', 'meio dia', 'noon', 'midday'];
  static const List<String> midnightTokens = ['meia-noite', 'meia noite', 'midnight'];
  static const List<String> afternoonNightTokens = [
    'da tarde',
    'da noite',
    'evening',
    'afternoon',
    'tonight',
    'de la tarde',
    'de la noche',
  ];

  static const List<String> replyClaimTokens = [
    'acabei de',
    'agendad',
    'registr',
    'criei',
    'adicionei',
    'excluí',
    'exclui',
    'atualizei',
    'scheduled',
    'created',
    'logged',
    'updated',
    'deleted',
  ];

  static const List<String> calendarNouns = ['calendario', 'calendário', 'agend', 'aviso', 'marqu', 'calendar', 'schedule'];
  static const List<String> calendarVerbs = ['cri', 'agend', 'adicion', 'marqu', 'coloc', 'schedule', 'add', 'create', 'book'];
  static const List<String> excludeVerbs = ['exclu', 'remov', 'delet'];
  static const List<String> examKeywords = ['prova', 'exam', 'test'];
  static const List<String> reviewKeywords = ['revis', 'review'];
  static const List<String> quizKeywords = ['simulado', 'quiz', 'mock'];
  static const List<String> sessionKeywords = ['registr', 'estudei', 'studied', 'log session'];
  static const List<String> weeklyGoalKeywords = ['meta semanal', 'weekly goal'];
  static const List<String> dailyGoalKeywords = ['meta diaria', 'meta diária', 'daily goal'];
}
