/// Multilingual intent-matching keyword tables used by offline agent
/// routing inside [GeminiService._processAutonomousAgent].
///
/// Stored under `lib/core/localization/` so language-specific intent lexicons
/// live alongside localization resources.
class AgentIntentKeywords {
  AgentIntentKeywords._();

  static const List<String> inspectAccountQueries = [
    'quais',
    'meus',
    'minhas',
    'o que tenho',
    'listar',
    'ver meus',
    'revisar conta',
    'resumo da conta',
    'my account',
    'list my',
    'what do i have',
    'account summary',
  ];

  static const List<String> createActionVerbs = [
    'crie',
    'criar',
    'agend',
    'exclu',
    'remov',
    'create',
    'schedule',
    'delete',
    'remove',
  ];

  static const List<String> weeklyGoalTriggers = ['meta semanal', 'weekly goal'];
  static const List<String> goalTrigger = ['meta', 'goal'];
  static const List<String> hourTrigger = ['hora', 'hour'];

  static const List<String> deleteTriggers = ['exclu', 'remov', 'apag', 'cancel', 'delet'];
  static const List<String> quizTokens = ['simulado', 'questões', 'questoes', 'quiz', 'mock exam', 'test'];
  static const List<String> notebookTokens = ['caderno', 'anotação', 'anotacao', 'nota', 'notebook', 'note'];
  static const List<String> flashcardTokens = ['flashcard', 'baralho', 'cartões', 'cartoes', 'deck', 'card'];
  static const List<String> roadmapTokens = ['trilha', 'roadmap', 'study path'];
  static const List<String> sessionTokens = ['sessão', 'sessao', 'diário', 'diario', 'study log', 'session'];

  static const List<String> createNotebookVerbs = ['cri', 'adicion', 'salv', 'ger', 'creat', 'add', 'sav', 'generat'];
  static const List<String> createRoadmapVerbs = ['cri', 'ger', 'mont', 'creat', 'generat', 'build'];

  static const List<String> networkTokens = ['redes', 'network'];
  static const List<String> securityTokens = ['segurança', 'seguranca', 'security', 'owasp', 'appsec'];
  static const List<String> algoTokens = ['algoritmo', 'dados', 'big-o', 'algorithm', 'data structure'];

  static const List<String> scheduleTriggers = ['agend', 'marqu', 'revisão', 'revisao', 'calendario', 'calendário', 'schedul', 'calendar', 'review'];
  static const List<String> examWords = ['prova', 'exam'];
  static const List<String> logStudyTriggers = ['registr', 'estudei', 'studied', 'log session'];
  static const List<String> summaryTriggers = ['resumo', 'cripto', 'conceitos', 'summary', 'crypto', 'concepts'];
  static const List<String> durationHalfHour = ['1h30', '1:30', '1 hora e meia', '1.5h'];
  static const List<String> durationTwoHours = ['2h', '2 horas', '2 hours'];
  static const List<String> durationOneHour = ['1h', '1 hora', '1 hour'];

  static const List<String> languageSubjectMarkers = [
    'grammar',
    'lesson',
    'inglês',
    'ingles',
    'english',
    'idioma',
    'vocab',
    'français',
    'espanhol',
    'alemão',
    'languages',
  ];

  static const List<String> lawSubjectMarkers = [
    'constitucional',
    'administrativo',
    'direito',
    'artigo',
    'lei',
  ];

  static const List<String> groupTxMarkers = [
    'no grupo',
    'in group',
    'in the group',
    'en el grupo',
  ];
}
