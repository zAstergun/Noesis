import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'supabase_service.dart';
import '../features/flashcards/models/flashcard_model.dart';

List<Map<String, dynamic>> _parseJsonPayload(String rawJson) {
  String cleanJson = rawJson.trim();
  if (cleanJson.startsWith('```json')) {
    cleanJson = cleanJson.substring(7);
  } else if (cleanJson.startsWith('```')) {
    cleanJson = cleanJson.substring(3);
  }
  if (cleanJson.endsWith('```')) {
    cleanJson = cleanJson.substring(0, cleanJson.length - 3);
  }
  cleanJson = cleanJson.trim();

  final decoded = jsonDecode(cleanJson);
  if (decoded is List) {
    return List<Map<String, dynamic>>.from(decoded);
  } else if (decoded is Map && decoded.containsKey('questions')) {
    return List<Map<String, dynamic>>.from(decoded['questions']);
  } else if (decoded is Map && decoded.containsKey('decks')) {
    return List<Map<String, dynamic>>.from(decoded['decks']);
  }
  throw const FormatException('Formato de JSON inesperado recebido.');
}

class OperationalModelsResult {
  final List<String> models;
  final String? error;

  const OperationalModelsResult({
    required this.models,
    this.error,
  });
}

class AIProvider {
  final String id;
  final String label;
  final String keyUrl;
  final List<String> models;
  final String defaultModel;
  final String? defaultBaseUrl;

  const AIProvider({
    required this.id,
    required this.label,
    required this.keyUrl,
    required this.models,
    required this.defaultModel,
    this.defaultBaseUrl,
  });
}

class AgentAction {
  final String name;
  final Map<String, dynamic> parameters;
  final String status; // 'completed' | 'failed'
  final String summary;
  final Map<String, dynamic>? data;

  const AgentAction({
    required this.name,
    required this.parameters,
    required this.status,
    required this.summary,
    this.data,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'parameters': parameters,
        'status': status,
        'summary': summary,
        'data': data,
      };
}

class AgentChatResult {
  final String reply;
  final List<AgentAction> actions;

  const AgentChatResult({
    required this.reply,
    this.actions = const [],
  });
}

class GeminiService {
  static String? apiKey;
  static String provider = 'google';
  static String model = 'gemini-1.5-flash';
  static String baseUrl = '';
  static double temperature = 0.4;
  static List<AgentAction> lastExecutedActions = [];

  static const List<AIProvider> providers = [
    AIProvider(
      id: 'google',
      label: 'Google Gemini',
      keyUrl: 'https://aistudio.google.com/app/apikey',
      models: [
        'gemini-1.5-flash',
        'gemini-2.0-flash',
        'gemini-1.5-flash-8b',
        'gemini-1.5-pro',
        'gemini-2.5-flash',
        'gemini-2.5-pro',
      ],
      defaultModel: 'gemini-1.5-flash',
    ),
    AIProvider(
      id: 'openai',
      label: 'OpenAI',
      keyUrl: 'https://platform.openai.com/api-keys',
      models: ['gpt-4o', 'gpt-4o-mini', 'o3-mini', 'o1'],
      defaultModel: 'gpt-4o-mini',
    ),
    AIProvider(
      id: 'anthropic',
      label: 'Anthropic',
      keyUrl: 'https://console.anthropic.com/settings/keys',
      models: ['claude-3-7-sonnet', 'claude-3-5-haiku', 'claude-3-5-sonnet'],
      defaultModel: 'claude-3-7-sonnet',
    ),
    AIProvider(
      id: 'xai',
      label: 'xAI · Grok',
      keyUrl: 'https://console.x.ai/',
      models: ['grok-2-1212', 'grok-2-vision-1212', 'grok-beta'],
      defaultModel: 'grok-2-1212',
    ),
    AIProvider(
      id: 'deepseek',
      label: 'DeepSeek',
      keyUrl: 'https://platform.deepseek.com/api_keys',
      models: ['deepseek-chat', 'deepseek-reasoner'],
      defaultModel: 'deepseek-chat',
    ),
    AIProvider(
      id: 'openrouter',
      label: 'OpenRouter',
      keyUrl: 'https://openrouter.ai/settings/keys',
      models: ['auto', 'google/gemini-1.5-flash', 'deepseek/deepseek-chat', 'anthropic/claude-3.7-sonnet'],
      defaultModel: 'auto',
    ),
    AIProvider(
      id: 'custom',
      label: 'Personalizado',
      keyUrl: '',
      models: [],
      defaultModel: '',
      defaultBaseUrl: 'https://api.openai.com/v1',
    ),
  ];

  static void initialize(String key) {
    apiKey = key;
  }

  static void configure({
    required String providerId,
    required String modelName,
    required String key,
    String? customBaseUrl,
  }) {
    provider = providerId;
    model = normalizeModel(providerId, modelName);
    apiKey = key;
    if (customBaseUrl != null) baseUrl = customBaseUrl;
  }

  static String normalizeModel(String providerId, String mod) {
    var clean = mod.trim();
    if (clean.startsWith('models/')) {
      clean = clean.substring(7).trim();
    }
    if (clean.isNotEmpty) {
      return clean;
    }
    final prov = providers.firstWhere((p) => p.id == providerId, orElse: () => providers.first);
    return prov.defaultModel;
  }

  /// Valida se o modelo é elegível para uso no assistente Noesis (apenas modelos Gemini de chat/assistente)
  static bool isEligibleGeminiAssistantModel(String name) {
    final lower = name.toLowerCase().trim();
    final clean = lower.startsWith('models/') ? lower.substring(7) : lower;

    // Apenas modelos oficiais da família Gemini
    if (!clean.startsWith('gemini-')) return false;

    // Exclui modelos utilitários de API, embeddings, visão pura, código bruto ou experimentais não-chat
    const excludedKeywords = [
      'embedding',
      'imagen',
      'aqa',
      'learnlm',
      'bison',
      'gecko',
      'gemma',
      'whisper',
      'tts',
      'stt',
      'transcribe',
      'robotics',
      'computer-use',
      'deep-research',
      'medlm',
    ];
    for (final kw in excludedKeywords) {
      if (clean.contains(kw)) return false;
    }

    // Exclui apenas a versão legada 1.0 descontinuada pelo Google AI Studio
    if (clean.startsWith('gemini-1.0')) {
      return false;
    }

    return true;
  }

  /// Testa se um modelo individual responde com status 200 para a chave informada
  static Future<({bool isWorking, String? error})> probeModelOperational(String mod, String key) async {
    final cleanMod = normalizeModel('google', mod);
    try {
      final endpoint = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$cleanMod:generateContent?key=$key',
      );
      final resp = await http.post(
        endpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [{'text': 'OK'}]
            }
          ],
          'generationConfig': {
            'maxOutputTokens': 5,
            'temperature': 0.1,
          }
        }),
      ).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        return (isWorking: true, error: null);
      }
      try {
        final err = jsonDecode(resp.body);
        final msg = err['error']?['message'] as String? ?? 'Status ${resp.statusCode}';
        return (isWorking: false, error: msg);
      } catch (_) {
        return (isWorking: false, error: 'Status ${resp.statusCode}');
      }
    } catch (e) {
      return (isWorking: false, error: e.toString());
    }
  }

  /// Consulta dinamicamente a API do Google AI Studio, filtra modelos de chat e testa em tempo real quais estão 100% operacionais agora
  static Future<OperationalModelsResult> fetchOperationalGoogleModels(String key) async {
    final apiKey = key.trim();
    if (apiKey.isEmpty) return const OperationalModelsResult(models: []);

    final candidates = <String>[];
    String? apiError;

    try {
      final endpoint = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey',
      );
      final resp = await http.get(endpoint).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final list = (data['models'] as List<dynamic>?) ?? [];
        for (final item in list) {
          final methods = (item['supportedGenerationMethods'] as List<dynamic>?) ?? [];
          if (methods.contains('generateContent')) {
            String name = (item['name'] as String? ?? '');
            if (name.startsWith('models/')) name = name.substring(7);
            if (isEligibleGeminiAssistantModel(name) && !candidates.contains(name)) {
              candidates.add(name);
            }
          }
        }
      } else {
        try {
          final err = jsonDecode(resp.body);
          apiError = err['error']?['message'] as String?;
        } catch (_) {}
      }
    } catch (e) {
      apiError = e.toString();
    }

    // Se a listagem não trouxe candidatos, usa as versões oficiais gratuitas da Google como candidatas
    if (candidates.isEmpty) {
      candidates.addAll([
        'gemini-1.5-flash',
        'gemini-2.0-flash',
        'gemini-1.5-flash-8b',
        'gemini-1.5-pro',
        'gemini-2.5-flash',
      ]);
    } else {
      // Prioriza modelos flash (mais rápidos, alta taxa de resposta e 100% disponíveis na cota gratuita)
      candidates.sort((a, b) {
        int score(String m) {
          if (m == 'gemini-1.5-flash') return 0;
          if (m == 'gemini-2.0-flash') return 1;
          if (m == 'gemini-2.5-flash') return 2;
          if (m == 'gemini-1.5-flash-8b') return 3;
          if (m.contains('flash')) return 4;
          if (m == 'gemini-1.5-pro') return 5;
          if (m.contains('pro')) return 6;
          return 7;
        }
        return score(a).compareTo(score(b));
      });
    }

    // Probe paralelo em todos os candidatos (tempo total = tempo de 1 requisição)
    final probeFutures = candidates.map((mod) async {
      final res = await probeModelOperational(mod, apiKey);
      return (model: mod, isWorking: res.isWorking, error: res.error);
    });

    final results = await Future.wait(probeFutures);
    final operational = results.where((r) => r.isWorking).map((r) => r.model).toList();

    String? lastError = apiError;
    if (operational.isEmpty && results.isNotEmpty) {
      lastError = results.firstWhere((r) => r.error != null, orElse: () => (model: '', isWorking: false, error: 'Nenhum modelo respondeu.')).error;
    }

    return OperationalModelsResult(
      models: operational,
      error: lastError,
    );
  }

  /// Consulta dinamicamente a API oficial do Google AI Studio para listar modelos disponíveis para generateContent
  static Future<List<String>> fetchGoogleModels(String key) async {
    final result = await fetchOperationalGoogleModels(key);
    return result.models;
  }

  static AIProvider get currentProvider =>
      providers.firstWhere((p) => p.id == provider, orElse: () => providers.first);

  // ---------------------------------------------------------------------------
  // TESTE DE CONEXÃO MULTI-PROVEDOR
  // ---------------------------------------------------------------------------
  static Future<String> testConnection({
    required String providerId,
    required String modelName,
    required String apiKey,
    String? baseUrl,
  }) async {
    final key = apiKey.trim();
    final mod = normalizeModel(providerId, modelName);
    final urlBase = (baseUrl ?? '').trim();

    if (providerId != 'custom' && key.isEmpty) {
      throw Exception('Informe a chave de API antes de testar.');
    }
    if (mod.isEmpty && providerId != 'custom') {
      throw Exception('Selecione ou informe o modelo.');
    }

    if (providerId == 'google') {
      final endpoint = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$mod:generateContent?key=$key',
      );
      final resp = await http.post(
        endpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': 'Responda apenas OK.'}
              ]
            }
          ],
          'generationConfig': {
            'maxOutputTokens': 5,
            'temperature': 0.1,
          }
        }),
      ).timeout(const Duration(seconds: 25));

      if (resp.statusCode != 200) {
        try {
          final err = jsonDecode(resp.body);
          final msg = err['error']?['message'] ?? 'Status ${resp.statusCode}';
          throw Exception(msg);
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception('Erro ao conectar com Google Gemini (${resp.statusCode}).');
        }
      }
      return 'Conexão OK com Google Gemini ($mod)!';
    }

    if (providerId == 'anthropic') {
      final endpoint = Uri.parse('https://api.anthropic.com/v1/messages');
      final resp = await http.post(
        endpoint,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': key,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': mod,
          'max_tokens': 10,
          'messages': [
            {'role': 'user', 'content': 'Responda apenas OK.'}
          ]
        }),
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) {
        try {
          final err = jsonDecode(resp.body);
          final msg = err['error']?['message'] ?? 'Status ${resp.statusCode}';
          throw Exception(msg);
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception('Erro ao conectar com Anthropic (${resp.statusCode}).');
        }
      }
      return 'Conexão OK com Anthropic ($mod)!';
    }

    // OpenAI, xAI, DeepSeek, OpenRouter, Custom
    String apiUrl = '';
    final endpoints = {
      'openai': 'https://api.openai.com/v1/chat/completions',
      'xai': 'https://api.x.ai/v1/chat/completions',
      'deepseek': 'https://api.deepseek.com/chat/completions',
      'openrouter': 'https://openrouter.ai/api/v1/chat/completions',
    };

    if (providerId == 'custom') {
      if (urlBase.isEmpty) throw Exception('Informe a URL base do provedor personalizado.');
      apiUrl = urlBase.endsWith('/chat/completions') ? urlBase : '$urlBase/chat/completions';
    } else {
      apiUrl = endpoints[providerId] ?? '';
    }

    final headers = {'Content-Type': 'application/json'};
    if (key.isNotEmpty) headers['Authorization'] = 'Bearer $key';

    final resp = await http.post(
      Uri.parse(apiUrl),
      headers: headers,
      body: jsonEncode({
        'model': mod.isEmpty ? 'default' : mod,
        'messages': [
          {'role': 'user', 'content': 'Responda apenas OK.'}
        ],
        'max_tokens': 10,
      }),
    ).timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      try {
        final err = jsonDecode(resp.body);
        final msg = err['error']?['message'] ?? 'Status ${resp.statusCode}';
        throw Exception(msg);
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('Erro ao conectar com $providerId (${resp.statusCode}).');
      }
    }
    return 'Conexão OK com $providerId ($mod)!';
  }

  // ---------------------------------------------------------------------------
  // GERADOR DE SIMULADOS (QUIZ ENGINE)
  // ---------------------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> generateQuiz({
    required String subject,
    required String topic,
    String? referenceDocumentText,
    int numberOfQuestions = 5,
    String difficulty = 'médio/avançado',
  }) async {
    final key = apiKey?.trim() ?? '';
    final cleanModel = normalizeModel(provider, model);

    final prompt = '''
Você é o examinador sênior do Aster Noesis. Crie um simulado de alto nível técnico sobre "$subject - $topic".
Dificuldade: $difficulty.
Total de questões: $numberOfQuestions.

${referenceDocumentText != null ? 'DOCUMENTO DE REFERÊNCIA / PROVAS ANTERIORES:\n"""\n$referenceDocumentText\n"""' : 'Gere questões originais e rigorosas com cenários técnicos reais.'}

RETORNE ESTRITAMENTE um array JSON no seguinte formato (sem Markdown extra, apenas o array JSON válido):
[
  {
    "question": "Enunciado técnico contextualizado...",
    "code_snippet": "Linhas de código opcionais (ou string vazia)",
    "options": [
      "Alternativa A",
      "Alternativa B",
      "Alternativa C",
      "Alternativa D"
    ],
    "correct_index": 0,
    "explanation": "Explicação detalhada e didática do motivo pelo qual a alternativa correta é a certa e o erro das demais.",
    "rag_sources": ["$subject", "$topic"]
  }
]
''';

    if (provider != 'custom' && key.isEmpty) {
      return _generateAutonomousQuiz(subject, topic, numberOfQuestions, difficulty);
    }

    String text = '';

    if (provider == 'google') {
      try {
        final generModel = GenerativeModel(
          model: cleanModel,
          apiKey: key,
          generationConfig: GenerationConfig(
            temperature: 0.3,
            responseMimeType: 'application/json',
          ),
        );
        final response = await generModel.generateContent([Content.text(prompt)]);
        text = response.text ?? '';
      } catch (_) {
        text = await _executeGoogleRest(prompt: prompt, systemInstruction: 'Retorne estritamente um array JSON válido.');
      }
    } else {
      text = await _executeRawPrompt(prompt: prompt, systemInstruction: 'Retorne estritamente um array JSON válido.');
    }

    if (text.isEmpty) {
      return _generateAutonomousQuiz(subject, topic, numberOfQuestions, difficulty);
    }

    try {
      return await compute(_parseJsonPayload, text);
    } catch (e) {
      debugPrint('Erro ao parsear JSON do simulado: $e \nTexto: $text');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // GERADOR DE FLASHCARDS COM MULTI-PROVEDOR E MODO AUTÔNOMO
  // ---------------------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> generateFlashcards({
    required String subject,
    required String topic,
    int count = 6,
    String difficulty = 'Médio / Prático',
    String? contextNotes,
  }) async {
    final key = apiKey?.trim() ?? '';
    final cleanModel = normalizeModel(provider, model);

    final prompt = '''
Gere um conjunto de $count FLASHCARDS DE ESTUDO COGNITIVO sobre o tema específico:
Matéria: "$subject"
Tema Específico: "$topic"
Dificuldade: "$difficulty"
${contextNotes != null && contextNotes.isNotEmpty ? 'Material de Referência / Anotações:\n"""\n$contextNotes\n"""' : ''}

Diretrizes pedagógicas para os Flashcards:
1. "front": Pergunta desafiadora, conceito-chave, problema arquitetural ou termo técnico que exija recuperação ativa de memória (Active Recall).
2. "back": Explicação clara, didática, precisa e técnica, destacando o 'porquê', analogias ou regras de ouro mnemônicas.
3. "tags": Lista de 2 ou 3 palavras-chave sobre o conteúdo.

RETORNE ESTRITAMENTE um array JSON no seguinte formato (sem Markdown extra, apenas o array JSON válido):
[
  {
    "front": "Pergunta ou conceito para a frente do cartão",
    "back": "Explicação completa e didática para o verso",
    "tags": ["$subject", "$topic"]
  }
]
''';

    if (provider != 'custom' && key.isEmpty) {
      return _generateAutonomousFlashcards(subject, topic, count, difficulty);
    }

    String text = '';

    if (provider == 'google') {
      try {
        final generModel = GenerativeModel(
          model: cleanModel,
          apiKey: key,
          generationConfig: GenerationConfig(
            temperature: 0.3,
            responseMimeType: 'application/json',
          ),
        );
        final response = await generModel.generateContent([Content.text(prompt)]);
        text = response.text ?? '';
      } catch (_) {
        text = await _executeGoogleRest(prompt: prompt, systemInstruction: 'Retorne estritamente um array JSON válido.');
      }
    } else {
      text = await _executeRawPrompt(prompt: prompt, systemInstruction: 'Retorne estritamente um array JSON válido.');
    }

    if (text.isEmpty) {
      return _generateAutonomousFlashcards(subject, topic, count, difficulty);
    }

    try {
      return await compute(_parseJsonPayload, text);
    } catch (e) {
      debugPrint('Erro ao parsear JSON dos flashcards: $e \nTexto: $text');
      return _generateAutonomousFlashcards(subject, topic, count, difficulty);
    }
  }

  // ---------------------------------------------------------------------------
  // SEPARADOR DE FLASHCARDS VOLUMOSOS (> 20) EM BARALHOS TEMÁTICOS COM IA
  // ---------------------------------------------------------------------------
  static Future<List<FlashcardDeck>> splitFlashcardsIntoDecks({
    required List<Flashcard> cards,
    required String baseTitle,
    required String baseSubject,
    int targetCardsPerDeck = 30,
  }) async {
    final cleanTarget = targetCardsPerDeck.clamp(10, 200);

    if (cards.length <= 20) {
      return [
        FlashcardDeck(
          id: 'deck-${DateTime.now().millisecondsSinceEpoch}',
          title: baseTitle.isNotEmpty ? baseTitle : 'Novo Baralho',
          subject: baseSubject.isNotEmpty ? baseSubject : 'Geral',
          description: 'Baralho com ${cards.length} cartões.',
          cards: List.from(cards),
          createdAt: DateTime.now(),
        ),
      ];
    }

    final key = apiKey?.trim() ?? '';
    final cleanModel = normalizeModel(provider, model);

    if (provider != 'custom' && key.isEmpty) {
      return _autonomousSplitFlashcards(cards, baseTitle, baseSubject, cleanTarget);
    }

    final targetDecks = (cards.length / cleanTarget).ceil().clamp(2, 50);
    final sampleCards = cards.take(120).toList();
    final summaries = sampleCards.asMap().entries.map((e) {
      final i = e.key;
      final c = e.value;
      final front = c.front.replaceAll(RegExp(r'\s+'), ' ').trim();
      final frontSnippet = front.length > 70 ? '${front.substring(0, 70)}...' : front;
      final back = c.back.replaceAll(RegExp(r'\s+'), ' ').trim();
      final backSnippet = back.length > 70 ? '${back.substring(0, 70)}...' : back;
      final tags = c.tags.isNotEmpty ? ' [tags: ${c.tags.join(",")}]' : '';
      return '{"i": $i, "q": "$frontSnippet", "a": "$backSnippet"$tags}';
    }).join(',\n');

    final prompt = '''
Você é um especialista em pedagogia e organização cognitiva de flashcards.
Temos um conjunto de ${cards.length} flashcards com o tema geral "$baseTitle" (${baseSubject.isNotEmpty ? baseSubject : 'Geral'}).
O usuário quer dividir este conjunto em baralhos menores com aproximadamente $cleanTarget cartões cada (totalizando cerca de $targetDecks baralhos temáticos).
Analise os tópicos e separe-os em $targetDecks baralhos temáticos específicos, coesos e bem estruturados.

Para cada baralho:
- "title": Título temático específico, claro e profissional (ex: "$baseTitle - Módulo 1: Fundamentos", "$baseTitle - Módulo 2: ...").
- "subject": Matéria ou disciplina refinada.
- "description": Breve descrição pedagógica do foco deste baralho.
- "color_hex": Código hexadecimal de cor (ex: "7C6CF0", "4EBA88", "F5A623", "FF7A90", "4A6BF5", "38B6FF").
- "card_indices": Array com os números dos índices inteiros (0 a ${sampleCards.length - 1}) dos cartões pertencentes a este baralho. Todos os índices devem ser atribuídos.

Cartões:
[
$summaries
]

RETORNE ESTRITAMENTE um array JSON no formato:
[
  {
    "title": "Nome do Baralho",
    "subject": "Matéria",
    "description": "Breve descrição...",
    "color_hex": "7C6CF0",
    "card_indices": [0, 1, 2]
  }
]
''';

    String text = '';
    if (provider == 'google') {
      try {
        final generModel = GenerativeModel(
          model: cleanModel,
          apiKey: key,
          generationConfig: GenerationConfig(
            temperature: 0.2,
            responseMimeType: 'application/json',
          ),
        );
        final response = await generModel.generateContent([Content.text(prompt)]);
        text = response.text ?? '';
      } catch (_) {
        text = await _executeGoogleRest(prompt: prompt, systemInstruction: 'Retorne estritamente um array JSON válido.');
      }
    } else {
      text = await _executeRawPrompt(prompt: prompt, systemInstruction: 'Retorne estritamente um array JSON válido.');
    }

    if (text.isEmpty) {
      return _autonomousSplitFlashcards(cards, baseTitle, baseSubject, cleanTarget);
    }

    try {
      final parsed = await compute(_parseJsonPayload, text);
      if (parsed.isEmpty) {
        return _autonomousSplitFlashcards(cards, baseTitle, baseSubject, cleanTarget);
      }

      final assignedCardIndices = <int>{};
      final List<FlashcardDeck> resultDecks = [];
      const colors = ['7C6CF0', '4EBA88', 'F5A623', 'FF7A90', '4A6BF5', '38B6FF'];

      for (int i = 0; i < parsed.length; i++) {
        final item = parsed[i];
        final title = (item['title'] as String?)?.trim() ?? '$baseTitle · Parte ${i + 1}';
        final subject = (item['subject'] as String?)?.trim() ?? baseSubject;
        final description = (item['description'] as String?)?.trim() ?? 'Sub-baralho temático organizado por IA.';
        final colorHex = (item['color_hex'] as String?)?.replaceAll('#', '').trim() ?? colors[i % colors.length];

        final List<Flashcard> deckCards = [];
        final rawIndices = item['card_indices'];
        if (rawIndices is List) {
          for (final idxObj in rawIndices) {
            final idx = (idxObj as num?)?.toInt();
            if (idx != null && idx >= 0 && idx < cards.length) {
              if (!assignedCardIndices.contains(idx)) {
                assignedCardIndices.add(idx);
                deckCards.add(cards[idx]);
              }
            }
          }
        }

        if (deckCards.isNotEmpty || i == 0) {
          resultDecks.add(FlashcardDeck(
            id: 'deck-ai-${DateTime.now().millisecondsSinceEpoch}-$i',
            title: title.isNotEmpty ? title : '$baseTitle · Parte ${i + 1}',
            subject: subject.isNotEmpty ? subject : baseSubject,
            description: description,
            cards: deckCards,
            createdAt: DateTime.now(),
            colorHex: colorHex,
          ));
        }
      }

      // Preserve all unassigned cards by distributing them across the generated decks
      final unassignedCards = <Flashcard>[];
      for (int i = 0; i < cards.length; i++) {
        if (!assignedCardIndices.contains(i)) {
          unassignedCards.add(cards[i]);
        }
      }

      if (unassignedCards.isNotEmpty) {
        if (resultDecks.isEmpty) {
          return _autonomousSplitFlashcards(cards, baseTitle, baseSubject, cleanTarget);
        }
        int deckIdx = 0;
        for (final unassigned in unassignedCards) {
          resultDecks[deckIdx % resultDecks.length].cards.add(unassigned);
          deckIdx++;
        }
      }

      resultDecks.removeWhere((d) => d.cards.isEmpty);
      if (resultDecks.isEmpty) {
        return _autonomousSplitFlashcards(cards, baseTitle, baseSubject, cleanTarget);
      }

      return resultDecks;
    } catch (e) {
      debugPrint('Erro ao parsear divisão de flashcards com IA: $e');
      return _autonomousSplitFlashcards(cards, baseTitle, baseSubject, cleanTarget);
    }
  }

  // ALGORITMO AUTÔNOMO DE CLUSTERIZAÇÃO TEMÁTICA DE FLASHCARDS (OFFLINE / ZERO-LATENCY)
  static List<FlashcardDeck> _autonomousSplitFlashcards(
    List<Flashcard> cards,
    String baseTitle,
    String baseSubject, [
    int targetCardsPerDeck = 30,
  ]) {
    final cleanTarget = targetCardsPerDeck.clamp(10, 200);
    if (cards.length <= 20) {
      return [
        FlashcardDeck(
          id: 'deck-${DateTime.now().millisecondsSinceEpoch}',
          title: baseTitle.isNotEmpty ? baseTitle : 'Novo Baralho',
          subject: baseSubject.isNotEmpty ? baseSubject : 'Geral',
          description: 'Baralho com ${cards.length} cartões.',
          cards: List.from(cards),
          createdAt: DateTime.now(),
        ),
      ];
    }

    const colors = ['7C6CF0', '4EBA88', 'F5A623', 'FF7A90', '4A6BF5', '38B6FF'];

    // 1. Clusterização com base no tema e quantidade desejada
    final lowerTitle = baseTitle.toLowerCase();
    final lowerSubject = baseSubject.toLowerCase();

    final numDecks = (cards.length / cleanTarget).ceil().clamp(2, 60);
    final chunkSize = (cards.length / numDecks).ceil();
    final List<FlashcardDeck> decks = [];

    List<String> themeSuffixes;
    if (lowerTitle.contains('grammar') || lowerSubject.contains('idioma') || lowerTitle.contains('inglês') || lowerTitle.contains('ingles')) {
      themeSuffixes = [
        'Fundamentos & Estruturas Básicas',
        'Tempos Verbais & Construções',
        'Expressões, Conectivos & Vocabulário',
        'Prática Avançada & Nuances',
        'Revisão Geral & Fixação',
        'Verbos Modais & Fraseais',
        'Leitura & Interpretação Contextual',
        'Conversação & Situações Cotidianas',
      ];
    } else if (lowerTitle.contains('segurança') || lowerTitle.contains('cripto') || lowerSubject.contains('segurança') || lowerSubject.contains('criptografia')) {
      themeSuffixes = [
        'Criptografia & Algoritmos Essenciais',
        'Segurança de Redes & Protocolos (TLS/IPsec)',
        'Controle de Acesso, Autenticação & IAM',
        'Ameaças, Vulnerabilidades & Resposta a Incidentes',
        'Governança, Riscos & Conformidade',
      ];
    } else if (lowerTitle.contains('rede') || lowerSubject.contains('redes')) {
      themeSuffixes = [
        'Modelo OSI & Camada de Rede',
        'Protocolos de Transporte & Roteamento (TCP/UDP/BGP)',
        'Serviços de Aplicação (DNS, HTTP, DHCP)',
        'Infraestrutura & Resolução de Problemas',
      ];
    } else if (lowerTitle.contains('devops') || lowerTitle.contains('cloud') || lowerTitle.contains('aws') || lowerSubject.contains('cloud')) {
      themeSuffixes = [
        'Arquitetura Cloud & Computação (EC2, Lambda)',
        'Armazenamento, Bancos de Dados & S3',
        'Redes Virtuais & Segurança (VPC, IAM)',
        'CI/CD, Monitoramento & Infraestrutura como Código',
      ];
    } else {
      themeSuffixes = [
        'Conceitos Fundamentais',
        'Aplicações & Métodos Práticos',
        'Tópicos Avançados & Casos Específicos',
        'Aprofundamento & Cenários Complexos',
        'Revisão & Fixação Cognitiva',
      ];
    }

    for (int i = 0; i < numDecks; i++) {
      final start = i * chunkSize;
      if (start >= cards.length) break;
      final end = (start + chunkSize).clamp(0, cards.length);
      final subList = cards.sublist(start, end);
      if (subList.isEmpty) continue;

      final partNum = i + 1;
      final suffix = i < themeSuffixes.length ? themeSuffixes[i] : 'Módulo $partNum';
      final title = numDecks <= 5 ? '$baseTitle · $suffix' : '$baseTitle · Parte $partNum: $suffix';

      decks.add(
        FlashcardDeck(
          id: 'deck-auto-${DateTime.now().millisecondsSinceEpoch}-$i',
          title: title,
          subject: baseSubject.isNotEmpty ? baseSubject : 'Geral',
          description: 'Módulo de estudo focado em $suffix (${subList.length} cartões).',
          cards: subList,
          createdAt: DateTime.now().add(Duration(seconds: i)),
          colorHex: colors[i % colors.length],
        ),
      );
    }

    return decks;
  }

  // ---------------------------------------------------------------------------
  // FORMATAÇÃO E ESTRUTURAÇÃO DE ANOTAÇÕES DE ESTUDO COM IA
  // ---------------------------------------------------------------------------
  /// Formata e aprimora uma anotação de estudos em Markdown estruturado, elegante e pedagógico
  static Future<String> formatStudyNote({
    required String rawText,
    String? topicOrSubject,
  }) async {
    final clean = rawText.trim();
    if (clean.isEmpty) return rawText;

    final key = apiKey?.trim() ?? '';
    final hasActiveAi = (provider == 'custom' || key.isNotEmpty);

    if (hasActiveAi) {
      try {
        const systemInstruction =
            'Você é um assistente especialista em pedagogia, revisão gramatical e formatação Markdown para o aplicativo Noesis.\n'
            'Sua missão é organizar, enriquecer a legibilidade e formatar com maestria as anotações de estudo do estudante mantendo 100% DO CONTEÚDO ORIGINAL.\n'
            'DIRETRIZES CRÍTICAS E OBRIGATÓRIAS:\n'
            '1. NUNCA RESUMA, NUNCA CORTE, NUNCA ABREVIE E NUNCA APAGUE NENHUM PARÁGRAFO OU FRASE. É estritamente proibido omitir qualquer conteúdo fornecido pelo usuário. A totalidade absoluta do texto deve estar presente na resposta.\n'
            '2. Preserve e mantenha na íntegra todos os blocos de código (ex: ```bash, ```python, etc.), comandos, parâmetros e exemplos técnicos sem nenhuma modificação no código.\n'
            '3. PRESERVE estritamente quaisquer URLs, links de referência [texto](url) e imagens markdown ![legenda](url) que o usuário já tenha inserido.\n'
            '4. Corrija pontuação, concordância e erros gramaticais/ortográficos no texto explicativo.\n'
            '5. Estruture em seções lógicas com títulos e subtítulos (#, ##, ###), marcadores (- ou *) e negritos em termos essenciais (**conceito**).\n'
            '6. Retorne EXCLUSIVAMENTE o conteúdo formatado em Markdown, sem nenhuma introdução, saudação, comentário prévio ou notas de encerramento.';

        final prompt = 'Por favor, formate e estruture as seguintes anotações de estudo na íntegra, sem resumir ou omitir nenhuma linha (Matéria/Contexto: ${topicOrSubject ?? "Geral"}):\n\n$clean';

        final result = await _executeRawPrompt(
          prompt: prompt,
          systemInstruction: systemInstruction,
        );

        if (result.trim().isNotEmpty) {
          var formatted = result.trim();
          if (formatted.startsWith('```markdown') && formatted.endsWith('```')) {
            formatted = formatted.substring(11, formatted.length - 3).trim();
          } else if (formatted.startsWith('```') && formatted.endsWith('```')) {
            formatted = formatted.substring(3, formatted.length - 3).trim();
          }

          // Proteção anti-truncamento / anti-apagamento de conteúdo
          final hasCodeBlockInOriginal = clean.contains('```');
          final hasCodeBlockInFormatted = formatted.contains('```');
          final isSevereTruncation = clean.length > 150 && formatted.length < (clean.length * 0.55);
          final lostCodeBlock = hasCodeBlockInOriginal && !hasCodeBlockInFormatted;

          if (isSevereTruncation || lostCodeBlock) {
            debugPrint('Aviso: IA retornou texto truncado ou com partes faltantes. Usando formatação autônoma segura para preservar 100% do conteúdo.');
            return _autonomousFormatStudyNote(clean, topicOrSubject);
          }

          return formatted;
        }
      } catch (e) {
        debugPrint('Erro ao chamar IA para formatação de nota: $e. Usando formatação autônoma.');
      }
    }

    return _autonomousFormatStudyNote(clean, topicOrSubject);
  }

  static String _autonomousFormatStudyNote(String rawText, String? topicOrSubject) {
    final lines = rawText.split('\n');
    final formattedLines = <String>[];
    bool inCodeBlock = false;

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (line.isEmpty) {
        formattedLines.add('');
        continue;
      }

      if (line.startsWith('```')) {
        inCodeBlock = !inCodeBlock;
        formattedLines.add(line);
        continue;
      }

      if (inCodeBlock) {
        formattedLines.add(lines[i]);
        continue;
      }

      // Se já possui marcação markdown
      if (RegExp(r'^(#{1,6}\s|[-*+]\s|\d+\.\s|>\s|!\[|\[)').hasMatch(line)) {
        formattedLines.add(line);
        continue;
      }

      // Título inicial
      if (i == 0 && line.length < 70 && !line.endsWith('.')) {
        formattedLines.add('## $line\n');
        continue;
      }

      // Subtítulo
      if (line.length < 45 && !line.endsWith('.') && !line.endsWith(':') && i + 1 < lines.length && lines[i + 1].trim().isNotEmpty) {
        formattedLines.add('\n### $line');
        continue;
      }

      // Destaque de conceito
      if (line.contains(':') && !line.startsWith('http')) {
        final colonIdx = line.indexOf(':');
        final prefix = line.substring(0, colonIdx).trim();
        final suffix = line.substring(colonIdx + 1).trim();
        if (prefix.length < 35 && !prefix.contains('**') && suffix.isNotEmpty) {
          line = '**$prefix:** $suffix';
        }
      }

      // Marcadores comuns
      if (line.startsWith('•') || line.startsWith('–') || line.startsWith('—')) {
        line = '- ${line.substring(1).trim()}';
      }

      formattedLines.add(line);
    }

    return formattedLines.join('\n');
  }

  // ---------------------------------------------------------------------------
  // ASSISTENTE DE ESTUDOS COM TOOL CALLING COMPLETO E AÇÕES REAIS
  // ---------------------------------------------------------------------------
  static Future<String> executeAgentChat({
    required String userMessage,
    required List<Content> history,
  }) async {
    lastExecutedActions = [];
    final key = apiKey?.trim() ?? '';
    final cleanModel = normalizeModel(provider, model);

    if (provider != 'custom' && key.isEmpty) {
      return 'Por favor, configure sua chave de API nas Configurações para ativar o assistente Noesis AI.';
    }

    if (provider == 'google') {
      try {
        final logStudyTool = Tool(functionDeclarations: [
          FunctionDeclaration(
            'log_study_session',
            'Registra uma sessão de estudo realizada pelo usuário no banco de dados do Noesis.',
            Schema(
              SchemaType.object,
              properties: {
                'subject': Schema(SchemaType.string, description: 'Matéria estudada (ex: Criptografia, Redes, Cloud).'),
                'topic': Schema(SchemaType.string, description: 'Tópico específico (ex: AES-GCM, OWASP Top 10).'),
                'duration_minutes': Schema(SchemaType.integer, description: 'Duração total estudada em minutos.'),
                'notes': Schema(SchemaType.string, description: 'Notas ou tópicos revistos.'),
              },
              requiredProperties: ['subject', 'topic', 'duration_minutes'],
            ),
          ),
          FunctionDeclaration(
            'schedule_calendar_event',
            'Agenda um compromisso, prova ou bloco de estudos no calendário do Noesis.',
            Schema(
              SchemaType.object,
              properties: {
                'title': Schema(SchemaType.string, description: 'Título do compromisso.'),
                'start_time_iso': Schema(SchemaType.string, description: 'Data e hora de início no formato ISO 8601.'),
                'duration_minutes': Schema(SchemaType.integer, description: 'Duração estimada em minutos (padrão 60).'),
                'category': Schema(SchemaType.string, description: 'Categoria: study, review, lab, exam, personal.'),
                'description': Schema(SchemaType.string, description: 'Descrição adicional.'),
              },
              requiredProperties: ['title', 'start_time_iso'],
            ),
          ),
          FunctionDeclaration(
            'create_quiz',
            'Cria um simulado técnico com questões de múltipla escolha e salva no Noesis.',
            Schema(
              SchemaType.object,
              properties: {
                'title': Schema(SchemaType.string, description: 'Título do simulado.'),
                'subject': Schema(SchemaType.string, description: 'Matéria do simulado.'),
                'num_questions': Schema(SchemaType.integer, description: 'Quantidade de questões (ex: 5).'),
                'difficulty': Schema(SchemaType.string, description: 'Dificuldade: Iniciante, Prático ou Certificação.'),
              },
              requiredProperties: ['title', 'subject'],
            ),
          ),
          FunctionDeclaration(
            'create_flashcards',
            'Cria um novo baralho de flashcards cognitivos para estudo com repetição espaçada e active recall.',
            Schema(
              SchemaType.object,
              properties: {
                'title': Schema(SchemaType.string, description: 'Título do baralho de flashcards.'),
                'subject': Schema(SchemaType.string, description: 'Matéria ou disciplina.'),
                'topic': Schema(SchemaType.string, description: 'Tema específico para os cartões.'),
                'num_cards': Schema(SchemaType.integer, description: 'Quantidade de cartões (ex: 5).'),
              },
              requiredProperties: ['title', 'subject'],
            ),
          ),
        ]);

        final googleModel = GenerativeModel(
          model: cleanModel,
          apiKey: key,
          tools: [logStudyTool],
          systemInstruction: Content.system(
            'Você é o Noesis AI, o assistente pessoal de estudos e alta produtividade do Aster. '
            'Quando o usuário pedir para registrar um estudo, chame log_study_session. '
            'Quando pedir para agendar um evento ou revisão, chame schedule_calendar_event. '
            'Quando pedir para criar um simulado, chame create_quiz. '
            'Quando pedir para criar flashcards ou baralhos de estudo, chame create_flashcards. '
            'Seja direto, técnico, motivador e use Markdown elegante com negrito e tópicos.',
          ),
        );

        final chat = googleModel.startChat(history: history);
        var response = await chat.sendMessage(Content.text(userMessage));

        while (response.functionCalls.isNotEmpty) {
          final call = response.functionCalls.first;
          Map<String, Object?> functionResult = {};

          if (call.name == 'log_study_session') {
            final args = call.args;
            final subject = args['subject'] as String? ?? 'Estudos';
            final topic = args['topic'] as String? ?? 'Geral';
            final duration = (args['duration_minutes'] as num?)?.toInt() ?? 60;
            final notes = args['notes'] as String?;

            await SupabaseService.addStudySession(
              subject: subject,
              topic: topic,
              durationMinutes: duration,
              studyDate: DateTime.now(),
              notes: notes,
            );

            lastExecutedActions.add(AgentAction(
              name: 'log_study_session',
              parameters: args,
              status: 'completed',
              summary: 'log_session() · ${_formatDuration(duration)} em $subject',
            ));
            functionResult = {'status': 'success', 'message': 'Sessão registrada com sucesso!'};
          } else if (call.name == 'schedule_calendar_event') {
            final args = call.args;
            final title = args['title'] as String? ?? 'Bloco de Estudo';
            DateTime startTime;
            try {
              startTime = DateTime.parse(args['start_time_iso'] as String);
            } catch (_) {
              startTime = _parseRelativeTime(userMessage);
            }
            final duration = (args['duration_minutes'] as num?)?.toInt() ?? 60;
            final endTime = startTime.add(Duration(minutes: duration));
            final category = (args['category'] as String?) ?? 'study';

            await SupabaseService.addCalendarEvent(
              title: title,
              startTime: startTime,
              endTime: endTime,
              category: category,
            );

            lastExecutedActions.add(AgentAction(
              name: 'schedule_calendar_event',
              parameters: args,
              status: 'completed',
              summary: 'calendar.create() · ${_formatTimeBrief(startTime)} · $title',
            ));
            functionResult = {'status': 'success', 'message': 'Evento agendado com sucesso!'};
          } else if (call.name == 'create_quiz') {
            final args = call.args;
            final title = args['title'] as String? ?? 'Simulado Noesis';
            final subject = args['subject'] as String? ?? 'Tecnologia';
            final count = (args['num_questions'] as num?)?.toInt() ?? 5;
            final diff = (args['difficulty'] as String?) ?? 'Médio / Prático';

            final questions = await generateQuiz(
              subject: subject,
              topic: title,
              numberOfQuestions: count,
              difficulty: diff,
            );

            final savedRecord = await SupabaseService.saveGeneratedQuiz(
              title: title,
              subject: subject,
              questionsData: questions,
              difficulty: diff,
            );

            lastExecutedActions.add(AgentAction(
              name: 'create_quiz',
              parameters: args,
              status: 'completed',
              summary: 'quiz.create() · ${questions.length} questões · $title',
              data: savedRecord,
            ));
            functionResult = {'status': 'success', 'message': 'Simulado criado com sucesso!'};
          } else if (call.name == 'create_flashcards') {
            final args = call.args;
            final title = args['title'] as String? ?? 'Novo Baralho de Flashcards';
            final subject = args['subject'] as String? ?? 'Geral';
            final topic = args['topic'] as String? ?? title;
            final count = (args['num_cards'] as num?)?.toInt() ?? 5;

            final cardsData = await generateFlashcards(
              subject: subject,
              topic: topic,
              count: count,
            );

            final flashcards = cardsData.asMap().entries.map((e) {
              final val = e.value;
              return Flashcard(
                id: 'fc-${DateTime.now().millisecondsSinceEpoch}-${e.key}',
                front: val['front']?.toString() ?? 'Pergunta',
                back: val['back']?.toString() ?? 'Resposta',
                tags: val['tags'] is List ? List<String>.from(val['tags']) : [subject, topic],
              );
            }).toList();

            final deck = FlashcardDeck(
              id: 'deck-${DateTime.now().millisecondsSinceEpoch}',
              title: title,
              subject: subject,
              description: 'Baralho gerado pelo Noesis AI sobre $topic',
              cards: flashcards,
              createdAt: DateTime.now(),
            );

            await SupabaseService.saveFlashcardDeck(deck);

            lastExecutedActions.add(AgentAction(
              name: 'create_flashcards',
              parameters: args,
              status: 'completed',
              summary: 'flashcards.create() · ${flashcards.length} cartões · $title',
              data: deck.toMap(),
            ));
            functionResult = {'status': 'success', 'message': 'Baralho de flashcards criado com sucesso!'};
          }

          response = await chat.sendMessage(
            Content.functionResponse(call.name, functionResult),
          );
        }

        return response.text ?? 'Ação processada com sucesso no Noesis!';
      } catch (e) {
        // Fallback REST direto para o Google Gemini
        try {
          final restText = await _executeGoogleRest(
            prompt: userMessage,
            systemInstruction:
                'Você é o Noesis AI, agente pessoal de estudos do Aster. Responda em Markdown elegante e direto.',
          );
          if (restText.isNotEmpty) {
            final result = await _extractAndExecuteAction(restText, userMessage);
            lastExecutedActions = result.actions;
            return result.reply;
          }
        } catch (_) {}

        final result = await _processAutonomousAgent(userMessage);
        lastExecutedActions = result.actions;
        return result.reply;
      }
    }

    try {
      final rawReply = await _executeRawPrompt(
        prompt: userMessage,
        systemInstruction:
            'Você é o Noesis AI, agente pessoal de estudos e alta produtividade do ecossistema Aster.\n'
            'Se o usuário pedir para registrar estudo, agendar no calendário ou criar um simulado, execute a ação retornando no final da mensagem uma tag com JSON no formato:\n'
            '<noesis_action>{"action": "log_study_session"|"schedule_calendar_event"|"create_quiz", "data": {...}}</noesis_action>\n'
            'Responda em Markdown elegante, direto e com tópicos bem formatados.',
      );

      final extracted = await _extractAndExecuteAction(rawReply, userMessage);
      lastExecutedActions = extracted.actions;
      return extracted.reply;
    } catch (_) {
      final result = await _processAutonomousAgent(userMessage);
      lastExecutedActions = result.actions;
      return result.reply;
    }
  }

  // ---------------------------------------------------------------------------
  // MOTOR COGNITIVO AUTÔNOMO (EXECUÇÃO LOCAL & FALLBACK INTELIGENTE)
  // ---------------------------------------------------------------------------
  static Future<AgentChatResult> _processAutonomousAgent(String message) async {
    final lower = message.toLowerCase().trim();
    final actions = <AgentAction>[];

    // 1. Criar Simulado
    if (lower.contains('simulado') || lower.contains('questões') || lower.contains('questoes') || lower.contains('quiz')) {
      String subject = 'Cybersegurança & AppSec';
      String topic = 'OWASP Top 10';
      int count = 5;

      if (lower.contains('owasp')) {
        subject = 'Segurança de Software';
        topic = 'OWASP Top 10 · Vulnerabilidades e Mitigações';
      } else if (lower.contains('cripto')) {
        subject = 'Criptografia & PKI';
        topic = 'Modos de Operação AES, Hashing e TLS';
      } else if (lower.contains('redes') || lower.contains('network')) {
        subject = 'Redes & Infraestrutura';
        topic = 'Protocolos TCP/IP, DNS e Firewall';
      } else if (lower.contains('cloud') || lower.contains('aws')) {
        subject = 'Cloud Computing';
        topic = 'AWS Security & Arquitetura de Nuvem';
      }

      final matchCount = RegExp(r'(\d+)\s*quest').firstMatch(lower);
      if (matchCount != null) {
        count = int.tryParse(matchCount.group(1)!) ?? 5;
      }

      final questions = _generateAutonomousQuiz(subject, topic, count, 'Avançado / Nível Certificação');
      final quizRecord = await SupabaseService.saveGeneratedQuiz(
        title: topic,
        subject: subject,
        questionsData: questions,
        difficulty: 'Avançado / Nível Certificação',
      );

      final summary = 'quiz.create() · $count questões · $topic';
      actions.add(AgentAction(
        name: 'create_quiz',
        parameters: {'subject': subject, 'topic': topic, 'count': count},
        status: 'completed',
        summary: summary,
        data: quizRecord,
      ));

      final reply = '''
Criei o simulado com **$count questões técnicas** sobre **$topic** no Quiz Engine do Noesis!

### Detalhes do Exame:
- **Disciplina:** $subject
- **Tópico:** $topic
- **Nível:** Avançado / Nível Certificação
- **Conteúdo:** Cenários reais com análise de código, mitigação de vulnerabilidades e gabarito fundamentado.

Você pode **iniciar o simulado agora** pelo botão abaixo ou acessá-lo na aba **Simulados**. Boa prova! 🚀
''';
      return AgentChatResult(reply: reply, actions: actions);
    }

    // 1.5. Criar Baralho de Flashcards Cognitivos
    if (lower.contains('flashcard') || lower.contains('baralho') || lower.contains('cartões') || lower.contains('cartoes')) {
      String subject = 'Criptografia & Segurança';
      String topic = 'Conceitos e Protocolos de Criptografia';
      int count = 5;

      if (lower.contains('owasp') || lower.contains('appsec') || lower.contains('segurança')) {
        subject = 'Segurança de Software';
        topic = 'OWASP Top 10 e Mitigações';
      } else if (lower.contains('redes') || lower.contains('tcp') || lower.contains('tls')) {
        subject = 'Redes & Protocolos';
        topic = 'Transporte TCP/UDP e Handshake TLS';
      } else if (lower.contains('cloud') || lower.contains('aws')) {
        subject = 'Cloud Computing';
        topic = 'AWS VPC, IAM e Resiliência';
      } else if (lower.contains('algoritmo') || lower.contains('dados') || lower.contains('big-o')) {
        subject = 'Ciência da Computação';
        topic = 'Big-O, Hash Tables e Grafos';
      }

      final matchCount = RegExp(r'(\d+)\s*cart').firstMatch(lower);
      if (matchCount != null) {
        count = int.tryParse(matchCount.group(1)!) ?? 5;
      }

      final cardsData = await generateFlashcards(
        subject: subject,
        topic: topic,
        count: count,
      );

      final flashcards = cardsData.asMap().entries.map((e) {
        final val = e.value;
        return Flashcard(
          id: 'fc-${DateTime.now().millisecondsSinceEpoch}-${e.key}',
          front: val['front']?.toString() ?? 'Pergunta',
          back: val['back']?.toString() ?? 'Resposta',
          tags: val['tags'] is List ? List<String>.from(val['tags']) : [subject, topic],
        );
      }).toList();

      final deckTitle = 'Flashcards: $topic';
      final deck = FlashcardDeck(
        id: 'deck-${DateTime.now().millisecondsSinceEpoch}',
        title: deckTitle,
        subject: subject,
        description: 'Baralho de retenção ativa gerado pelo Noesis AI.',
        cards: flashcards,
        createdAt: DateTime.now(),
      );

      await SupabaseService.saveFlashcardDeck(deck);

      actions.add(AgentAction(
        name: 'create_flashcards',
        parameters: {'title': deckTitle, 'subject': subject, 'topic': topic},
        status: 'completed',
        summary: 'flashcards.create() · ${flashcards.length} cartões · $deckTitle',
        data: deck.toMap(),
      ));

      final reply = '''
Baralho de Flashcards criado com sucesso! 🎴

Gerei **${flashcards.length} flashcards cognitivos** sobre **$topic** ($subject):

- **Active Recall:** Perguntas conceituais focadas em retenção de longo prazo.
- **Explicações Técnicas:** Respostas detalhadas com o porquê de cada mecanismo.
- **Prática:** Acesse o baralho na aba **Flashcards** com animação 3D de virar cartão e avaliação de dificuldade!
''';
      return AgentChatResult(reply: reply, actions: actions);
    }

    // 2. Agendar Evento no Calendário
    if (lower.contains('agend') || lower.contains('marqu') || lower.contains('revisão') || lower.contains('revisao') || lower.contains('calendario') || lower.contains('calendário')) {
      String title = 'Revisão de Estudos';
      String category = 'review';

      if (lower.contains('cripto')) {
        title = 'Revisão · Criptografia & PKI';
      } else if (lower.contains('owasp')) {
        title = 'Revisão · OWASP Top 10';
      } else if (lower.contains('simulado')) {
        title = 'Execução de Simulado';
        category = 'lab';
      } else if (lower.contains('prova')) {
        title = 'Prova Oficial';
        category = 'exam';
      }

      final startTime = _parseRelativeTime(lower);
      final endTime = startTime.add(const Duration(minutes: 60));

      await SupabaseService.addCalendarEvent(
        title: title,
        startTime: startTime,
        endTime: endTime,
        category: category,
        description: 'Agendado automaticamente pelo Noesis AI a pedido do usuário.',
      );

      final timeStr = _formatTimeBrief(startTime);
      final summary = 'calendar.create() · $timeStr · $title';
      actions.add(AgentAction(
        name: 'schedule_calendar_event',
        parameters: {'title': title, 'start_time': startTime.toIso8601String(), 'category': category},
        status: 'completed',
        summary: summary,
      ));

      final reply = '''
Agendado com sucesso! 📅

Adicionei **$title** ao seu **Calendário** para **$timeStr**.

- **Horário:** ${_formatTimeFull(startTime)} às ${_formatTimeFull(endTime)}
- **Categoria:** ${category.toUpperCase()}
- **Lembrete:** Visível na sua grade semanal e diária da aba **Calendário**.

Precisa que eu prepare um roteiro de tópicos para esse bloco ou quer agendar mais alguma revisão?
''';
      return AgentChatResult(reply: reply, actions: actions);
    }

    // 3. Registrar Sessão de Estudo no Tracker
    if (lower.contains('registr') || lower.contains('estudei') || (lower.contains('salv') && lower.contains('estudo'))) {
      String subject = 'Criptografia';
      String topic = 'AES-GCM & Modos de Operação';
      int minutes = 90;

      if (lower.contains('owasp')) {
        subject = 'Segurança de Software';
        topic = 'OWASP Top 10 · Mitigações de Injeção';
      } else if (lower.contains('redes')) {
        subject = 'Redes';
        topic = 'Protocolos de Roteamento e Handshake TLS';
      } else if (lower.contains('cloud') || lower.contains('aws')) {
        subject = 'Cloud Computing';
        topic = 'IAM Policies & VPC Security';
      }

      if (lower.contains('1h30') || lower.contains('1:30') || lower.contains('1 hora e meia')) {
        minutes = 90;
      } else if (lower.contains('2h') || lower.contains('2 horas')) {
        minutes = 120;
      } else if (lower.contains('1h') || lower.contains('1 hora')) {
        minutes = 60;
      } else if (lower.contains('45 min')) {
        minutes = 45;
      } else if (lower.contains('30 min')) {
        minutes = 30;
      }

      await SupabaseService.addStudySession(
        subject: subject,
        topic: topic,
        durationMinutes: minutes,
        studyDate: DateTime.now(),
        notes: 'Sessão registrada via comando no Noesis AI.',
      );

      final summary = 'log_session() · ${_formatDuration(minutes)} registrada em $subject';
      actions.add(AgentAction(
        name: 'log_study_session',
        parameters: {'subject': subject, 'topic': topic, 'duration_minutes': minutes},
        status: 'completed',
        summary: summary,
      ));

      final reply = '''
Feito! ✅ Sessão de **${_formatDuration(minutes)}** salva com sucesso em **$subject**.

- **Tópico:** $topic
- **Métricas:** O tempo já foi somado à sua meta semanal e ao gráfico do **Dashboard**.
- **Consistência:** Streak diário mantido e atualizado!

Seus dados já estão refletidos nos gráficos de progresso. Deseja agendar uma revisão desse conteúdo ou testar seus conhecimentos em um simulado rápido?
''';
      return AgentChatResult(reply: reply, actions: actions);
    }

    // 4. Resumo de Criptografia / Conceitos
    if (lower.contains('resumo') || lower.contains('cripto') || lower.contains('conceitos')) {
      final reply = '''
Aqui está um resumo de alto rendimento sobre os **Conceitos Fundamentais de Criptografia**:

### 1. Criptografia Simétrica (Chave Secreta)
- **Princípio:** A mesma chave é usada para cifrar e decifrar.
- **Vantagem:** Extremamente rápida e eficiente para grandes volumes de dados (streaming e arquivos).
- **Algoritmo Padrão:** **AES (Advanced Encryption Standard)** com chaves de 128, 192 ou 256 bits.
- **Modos de Operação Críticos:**
  - `AES-GCM` (Galois/Counter Mode): Cifra autenticada (AEAD) que garante confidencialidade e integridade. **Atenção:** Nunca reutilize o *nonce* sob a mesma chave.
  - `AES-CBC`: Requer vetor de inicialização (IV) imprevisível e preenchimento (padding).

### 2. Criptografia Assimétrica (Chave Pública/Privada)
- **Princípio:** Chave pública cifra; chave privada correspondente decifra (e vice-versa para assinaturas).
- **Vantagem:** Resolve a distribuição segura de chaves em canais abertos.
- **Principais Algoritmos:**
  - **RSA:** Baseado na fatoração de inteiros grandes (chaves de 2048 a 4096 bits).
  - **ECC (Curvas Elípticas):** Chaves menores (ex: 256 bits) com segurança equivalente ao RSA-3072, consumindo menos CPU.
  - **ECDH:** Troca de chaves para estabelecer segredos efêmeros.

### 3. Funções de Hash Criptográfico & MAC
- **Unidirecionais:** Não permitem reversão. Convertem dados arbitrários em digest de tamanho fixo.
- **Propriedades:** Resistência a colisões e efeito avalanche (1 bit alterado muda todo o hash).
- **Padrões:** `SHA-256`, `SHA-3`, `BLAKE2`.
- **HMAC:** Hash combinado com chave secreta para verificação de integridade e autenticidade.

### 4. Aplicações Práticas (TLS 1.3 & PKI)
- **Handshake TLS:** Usa criptografia assimétrica (ECDHE) para negociar chaves efêmeras com **PFS (Perfect Forward Secrecy)** e depois cifra o tráfego com AES-GCM ou ChaCha20-Poly1305.
- **Certificados Digitais (X.509):** Autoridades Certificadoras (CA) assinam chaves públicas para garantir a identidade do servidor.

> 💡 **Dica de Estudo:** Foque em entender o funcionamento da **Cifra Autenticada (AEAD)** e o motivo do *nonce reuse* destruir a segurança do AES-GCM.

Gostaria que eu gerasse um simulado de 5 questões sobre esse resumo ou prefere agendar uma revisão?
''';
      return AgentChatResult(reply: reply);
    }

    // 5. O que posso fazer / Ajuda
    final reply = '''
Sou o **Noesis AI**, seu agente cognitivo integrado ao ecossistema Noesis. Tenho capacidade de executar ações reais no seu sistema:

### O que você pode fazer comigo:
- 📝 **Criar Simulados Técnicos:** Diga *"Crie um simulado de 5 questões sobre OWASP"* ou *"Gere questões sobre Criptografia"*.
- 🎴 **Gerar Flashcards Cognitivos:** Diga *"Gere flashcards sobre Criptografia"* ou crie baralhos sobre temas específicos.
- ⏱️ **Registrar Sessões de Estudo:** Diga *"Registre 1h30 de estudo de Criptografia"* ou *"Estudei 45 min de redes"*.
- 📅 **Agendar Revisões e Provas:** Diga *"Agende uma revisão para amanhã às 14h"* ou *"Marque minha prova oficial na sexta"*.
- 🧠 **Resumos e Explicações Técnicas:** Peça resumos com exemplos de código, comparações de arquitetura e dicas para certificações.

Como posso acelerar seus estudos agora?
''';
    return AgentChatResult(reply: reply);
  }

  // ---------------------------------------------------------------------------
  // EXTRATOR DE AÇÕES PARA MODELOS REST
  // ---------------------------------------------------------------------------
  static Future<AgentChatResult> _extractAndExecuteAction(String rawText, String userMessage) async {
    final actions = <AgentAction>[];
    String cleanReply = rawText;

    final regex = RegExp(r'<noesis_action>([\s\S]*?)<\/noesis_action>');
    final match = regex.firstMatch(rawText);

    if (match != null) {
      final jsonBlock = match.group(1)?.trim() ?? '';
      cleanReply = rawText.replaceAll(regex, '').trim();

      try {
        final parsed = jsonDecode(jsonBlock) as Map<String, dynamic>;
        final actionName = parsed['action'] as String? ?? '';
        final data = (parsed['data'] as Map<String, dynamic>?) ?? {};

        if (actionName == 'log_study_session') {
          final subject = data['subject'] as String? ?? 'Estudos';
          final topic = data['topic'] as String? ?? 'Geral';
          final duration = (data['duration_minutes'] as num?)?.toInt() ?? 60;
          await SupabaseService.addStudySession(
            subject: subject,
            topic: topic,
            durationMinutes: duration,
            studyDate: DateTime.now(),
            notes: data['notes'] as String?,
          );
          actions.add(AgentAction(
            name: 'log_study_session',
            parameters: data,
            status: 'completed',
            summary: 'log_session() · ${_formatDuration(duration)} em $subject',
          ));
        } else if (actionName == 'schedule_calendar_event') {
          final title = data['title'] as String? ?? 'Bloco de Estudo';
          DateTime startTime;
          try {
            startTime = DateTime.parse(data['start_time_iso'] as String);
          } catch (_) {
            startTime = _parseRelativeTime(userMessage);
          }
          final duration = (data['duration_minutes'] as num?)?.toInt() ?? 60;
          final endTime = startTime.add(Duration(minutes: duration));
          final category = (data['category'] as String?) ?? 'study';

          await SupabaseService.addCalendarEvent(
            title: title,
            startTime: startTime,
            endTime: endTime,
            category: category,
          );
          actions.add(AgentAction(
            name: 'schedule_calendar_event',
            parameters: data,
            status: 'completed',
            summary: 'calendar.create() · ${_formatTimeBrief(startTime)} · $title',
          ));
        } else if (actionName == 'create_quiz') {
          final title = data['title'] as String? ?? 'Simulado Noesis';
          final subject = data['subject'] as String? ?? 'Tecnologia';
          final count = (data['num_questions'] as num?)?.toInt() ?? 5;
          final questions = _generateAutonomousQuiz(subject, title, count, 'Médio / Prático');
          final record = await SupabaseService.saveGeneratedQuiz(
            title: title,
            subject: subject,
            questionsData: questions,
          );
          actions.add(AgentAction(
            name: 'create_quiz',
            parameters: data,
            status: 'completed',
            summary: 'quiz.create() · ${questions.length} questões · $title',
            data: record,
          ));
        }
      } catch (e) {
        debugPrint('Erro ao parsear ação do LLM: $e');
      }
    }

    return AgentChatResult(reply: cleanReply, actions: actions);
  }

  // ---------------------------------------------------------------------------
  // EXECUTOR REST GENÉRICO
  // ---------------------------------------------------------------------------
  static Future<String> _executeRawPrompt({
    required String prompt,
    required String systemInstruction,
  }) async {
    final key = apiKey?.trim() ?? '';
    final cleanModel = normalizeModel(provider, model);

    if (provider == 'google') {
      return await _executeGoogleRest(prompt: prompt, systemInstruction: systemInstruction);
    }

    if (provider == 'anthropic') {
      final endpoint = Uri.parse('https://api.anthropic.com/v1/messages');
      final resp = await http.post(
        endpoint,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': key,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': cleanModel,
          'max_tokens': 8192,
          'system': systemInstruction,
          'messages': [
            {'role': 'user', 'content': prompt}
          ]
        }),
      ).timeout(const Duration(seconds: 25));

      if (resp.statusCode != 200) {
        throw Exception('Falha na API Anthropic (${resp.statusCode}): ${resp.body}');
      }

      final data = jsonDecode(resp.body);
      final text = data['content']?[0]?['text'] as String?;
      if (text == null || text.trim().isEmpty) {
        throw Exception('Anthropic retornou resposta vazia.');
      }
      return text;
    }

    String apiUrl = '';
    final endpoints = {
      'openai': 'https://api.openai.com/v1/chat/completions',
      'xai': 'https://api.x.ai/v1/chat/completions',
      'deepseek': 'https://api.deepseek.com/chat/completions',
      'openrouter': 'https://openrouter.ai/api/v1/chat/completions',
    };

    if (provider == 'custom') {
      final cleanBase = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
      apiUrl = cleanBase.endsWith('/chat/completions') ? cleanBase : '$cleanBase/chat/completions';
    } else {
      apiUrl = endpoints[provider] ?? 'https://api.openai.com/v1/chat/completions';
    }

    final headers = {'Content-Type': 'application/json'};
    if (key.isNotEmpty) headers['Authorization'] = 'Bearer $key';

    final resp = await http.post(
      Uri.parse(apiUrl),
      headers: headers,
      body: jsonEncode({
        'model': cleanModel,
        'messages': [
          {'role': 'system', 'content': systemInstruction},
          {'role': 'user', 'content': prompt}
        ],
        'temperature': temperature,
        'max_tokens': 8192,
      }),
    ).timeout(const Duration(seconds: 25));

    if (resp.statusCode != 200) {
      throw Exception('Falha na API ($provider / ${resp.statusCode}): ${resp.body}');
    }

    final data = jsonDecode(resp.body);
    final content = data['choices']?[0]?['message']?['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw Exception('Provedor retornou resposta vazia.');
    }
    return content;
  }

  static Future<String> _executeGoogleRest({
    required String prompt,
    required String systemInstruction,
  }) async {
    final key = apiKey?.trim() ?? '';
    final mod = normalizeModel('google', model);

    final endpoint = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$mod:generateContent?key=$key',
    );

    final resp = await http.post(
      endpoint,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': '$systemInstruction\n\n$prompt'}
            ]
          }
        ],
        'generationConfig': {
          'temperature': temperature,
          'maxOutputTokens': 8192,
        }
      }),
    ).timeout(const Duration(seconds: 25));

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final candidate = (data['candidates'] as List?)?.firstOrNull;
      if (candidate == null) return '';
      final parts = candidate['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) return '';
      final buffer = StringBuffer();
      for (final p in parts) {
        if (p is Map<String, dynamic>) {
          if (p['thought'] == true) continue;
          final txt = p['text'] as String?;
          if (txt != null) buffer.write(txt);
        }
      }
      return buffer.toString();
    } else {
      throw Exception('Erro Google REST: status ${resp.statusCode}');
    }
  }

  // ---------------------------------------------------------------------------
  // BANCO DE QUESTÕES COGNITIVAS PARA MODO LOCAL
  // ---------------------------------------------------------------------------
  static List<Map<String, dynamic>> _generateAutonomousQuiz(
    String subject,
    String topic,
    int count,
    String difficulty,
  ) {
    final lower = '$subject $topic'.toLowerCase();

    if (lower.contains('owasp') || lower.contains('appsec') || lower.contains('software')) {
      final pool = [
        {
          'question':
              'Um endpoint REST aceita o parâmetro ?redirect= para encaminhar o usuário após autenticação. Um invasor envia https://app.com/login?redirect=https://evil.com. Qual vulnerabilidade do OWASP Top 10 está caracterizada?',
          'code_snippet':
              '# auth_controller.py\nredirect_url = request.args.get("redirect")\nreturn redirect(redirect_url)  # Sem validação prévia',
          'options': [
            'A01:2021 - Broken Access Control (Open Redirect)',
            'A03:2021 - Injection (SQL Injection)',
            'A07:2021 - Identification and Authentication Failures',
            'A09:2021 - Security Logging and Monitoring Failures',
          ],
          'correct_index': 0,
          'explanation':
              'Redirecionamentos abertos não validados enquadram-se em Broken Access Control (A01). A mitigação correta é validar o destino contra uma allow-list estrita de domínios ou caminhos relativos internos.',
          'rag_sources': ['OWASP Top 10:2021 · A01', 'CWE-601: Open Redirect'],
        },
        {
          'question':
              'Durante uma auditoria, constatou-se que a aplicação concatena diretamente entradas de formulário em consultas SQL. Qual abordagem mitiga a falha de forma definitiva?',
          'code_snippet':
              '# query_runner.py\nsql = f"SELECT * FROM users WHERE email = \'{user_email}\'"\ncursor.execute(sql)',
          'options': [
            'Utilizar consultas parametrizadas (Prepared Statements) em todas as camadas de acesso a dados.',
            'Adicionar um filtro de caracteres especiais para remover aspas simples e hifens.',
            'Aplicar criptografia AES-256 no banco de dados antes da execução da query.',
            'Aumentar o tempo limite de conexão (timeout) do pool de conexões.',
          ],
          'correct_index': 0,
          'explanation':
              'Prepared Statements separam estritamente o código SQL dos dados de entrada, impedindo que comandos arbitrários sejam interpretados pelo motor do banco. Filtros por lista negra são frequentemente contornados.',
          'rag_sources': ['OWASP Top 10:2021 · A03 Injection', 'NIST SP 800-64'],
        },
        {
          'question':
              'Uma aplicação armazena senhas no banco de dados utilizando MD5 com salt simples. Diante das recomendações modernas da OWASP, qual é a conduta correta?',
          'code_snippet':
              '# password_hasher.py\nhash = hashlib.md5((salt + password).encode()).hexdigest()',
          'options': [
            'Migrar para algoritmos com fator de trabalho ajustável, como Argon2id, bcrypt ou PBKDF2.',
            'Dobrar o tamanho do salt mantendo o algoritmo MD5.',
            'Substituir por SHA-1 com iterações em loop for de 1000 vezes.',
            'Cifrar o hash MD5 com chave simétrica AES no servidor web.',
          ],
          'correct_index': 0,
          'explanation':
              'Funções rápidas como MD5 e SHA-1 são vulneráveis a ataques de força bruta massivos com GPUs e ASICs. A OWASP recomenda Argon2id ou bcrypt, que impõem custo deliberado de CPU e memória.',
          'rag_sources': ['OWASP Password Storage Cheat Sheet', 'RFC 9106 Argon2'],
        },
        {
          'question':
              'Qual medida é mais eficiente para impedir ataques de Cross-Site Scripting (XSS) em aplicações web modernas?',
          'code_snippet':
              '// view.js\ndocument.getElementById("userBio").innerHTML = userData.bio;',
          'options': [
            'Utilizar Content Security Policy (CSP) robusta aliada a context-aware output encoding (ou frameworks que escapam por padrão).',
            'Substituir todas as requisições GET por POST para mascarar os parâmetros na URL.',
            'Habilitar o flag SameSite=None em todos os cookies de sessão.',
            'Validar apenas o comprimento da string no front-end.',
          ],
          'correct_index': 0,
          'explanation':
              'Context-aware output encoding garante que dados inseridos no DOM não sejam executados como código. Um CSP restrito atua como defesa em profundidade, bloqueando scripts inline e fontes não autorizadas.',
          'rag_sources': ['OWASP XSS Prevention Cheat Sheet', 'W3C CSP Level 3'],
        },
        {
          'question':
              'Ao analisar o cabeçalho de resposta de um servidor, identificou-se a ausência de "Strict-Transport-Security" (HSTS). Qual é o risco direto dessa ausência?',
          'code_snippet':
              'HTTP/1.1 200 OK\nServer: nginx\n(Ausência do cabeçalho Strict-Transport-Security)',
          'options': [
            'Ataques de SSL Stripping (downgrade para HTTP puro) por man-in-the-middle em conexões subsequentes.',
            'Injeção de cabeçalhos HTTP no lado do cliente.',
            'Execução remota de código no balanceador de carga.',
            'Vazamento imediato da chave privada RSA do certificado.',
          ],
          'correct_index': 0,
          'explanation':
              'O HSTS instrui os navegadores a acessarem o site exclusivamente via HTTPS, impedindo ataques de downgrade como o SSLStrip em redes não confiáveis (como Wi-Fi público).',
          'rag_sources': ['RFC 6797 HSTS', 'OWASP Top 10 · Security Misconfiguration'],
        },
      ];
      return pool.take(count).toList();
    }

    // Default: Criptografia & PKI
    final cryptoPool = [
      {
        'question':
            'Em uma cifra de bloco operando em modo Galois/Counter Mode (AES-GCM), qual é a consequência fatal da reutilização do mesmo Initialization Vector (Nonce) sob uma mesma chave secreta?',
        'code_snippet':
            '# encryptor.py\nkey = load_fixed_key()\nnonce = b"123456789012"  # Fixo reutilizado para todas as mensagens!',
        'options': [
          'Permite a recuperação da chave de autenticação (GHASH key) e quebra a confidencialidade das mensagens por XOR dos textos cifrados.',
          'Causa estouro de pilha (buffer overflow) no acelerador de hardware.',
          'Reduz o tamanho da chave de 256 bits para 64 bits automaticamente.',
          'Faz a cifra reverter para o modo ECB (Electronic Codebook).',
        ],
        'correct_index': 0,
        'explanation':
            'No AES-GCM, o reúso de nonce com a mesma chave revela o keystream (permitindo decifrar mensagens via XOR) e viabiliza a recuperação da chave GHASH, destruindo a integridade e autenticidade.',
        'rag_sources': ['NIST SP 800-38D (GCM)', 'RFC 5116 (AEAD)'],
      },
      {
        'question':
            'Qual é a principal vantagem das curvas elípticas (ECC) em relação ao RSA tradicional na criptografia assimétrica moderna?',
        'code_snippet':
            '# Comparação de tamanhos:\n# RSA-3072 vs ECC P-256 (mesmo nível de segurança de 128 bits)',
        'options': [
          'Chaves substancialmente menores para o mesmo nível de segurança criptográfica, reduzindo uso de memória e latência de rede.',
          'A criptografia ECC é simétrica e não requer troca de chaves.',
          'Imunidade comprovada contra computadores quânticos rodando o algoritmo de Shor.',
          'Despensa a necessidade de números aleatórios de alta entropia.',
        ],
        'correct_index': 0,
        'explanation':
            'Uma chave ECC de 256 bits oferece segurança equivalente ao RSA de 3072 bits. Isso economiza banda, acelera handshakes TLS e reduz consumo de energia em dispositivos móveis e IoT.',
        'rag_sources': ['NIST SP 800-57', 'RFC 6090'],
      },
      {
        'question':
            'Durante a negociação do TLS 1.3, qual propriedade garante que mesmo se a chave privada do servidor vazar no futuro, sessões passadas não poderão ser decifradas?',
        'code_snippet':
            'Cipher Suite: TLS_AES_256_GCM_SHA384\nKey Exchange: Ephemeral Elliptic Curve Diffie-Hellman (ECDHE)',
        'options': [
          'Perfect Forward Secrecy (PFS)',
          'Zero-Knowledge Proof (ZKP)',
          'Homomorphic Encryption',
          'Pre-Shared Key Derivation (PSK)',
        ],
        'correct_index': 0,
        'explanation':
            'O Perfect Forward Secrecy (PFS) gera chaves efêmeras para cada sessão (ECDHE). Se a chave mestre do servidor for comprometida depois, as sessões passadas continuam indecifráveis.',
        'rag_sources': ['RFC 8446 (The TLS Protocol Version 1.3)', 'NIST SP 800-52'],
      },
      {
        'question':
            'Qual das seguintes opções descreve com precisão a diferença fundamental entre uma função de hash simples e um Message Authentication Code (MAC)?',
        'code_snippet':
            '# Hash: SHA256(data)\n# MAC:  HMAC-SHA256(key, data)',
        'options': [
          'O MAC utiliza uma chave secreta compartilhada para assegurar integridade e autenticidade da origem, enquanto o hash verifica apenas a integridade.',
          'O Hash é reversível e o MAC é unidirecional.',
          'O MAC cifra a mensagem inteira e o Hash apenas o cabeçalho.',
          'O Hash só funciona com arquivos de até 1 MB.',
        ],
        'correct_index': 0,
        'explanation':
            'Um atacante pode alterar os dados e recalcular um hash comum. Porém, sem a chave secreta compartilhada, ele não consegue calcular um MAC válido, provando que a mensagem veio de quem detém a chave.',
        'rag_sources': ['RFC 2104 (HMAC)', 'FIPS PUB 198-1'],
      },
      {
        'question':
            'Por que o modo ECB (Electronic Codebook) é expressamente proibido para cifragem de dados confidenciais com cifras de bloco?',
        'code_snippet':
            '# ECB Mode:\n# Bloco de Entrada A -> Cifra(A)\n# Bloco de Entrada A -> Cifra(A) [Mesma saída sempre!]',
        'options': [
          'Blocos idênticos de texto claro produzem blocos idênticos de texto cifrado, preservando padrões visuais e estruturais dos dados.',
          'Não suporta chaves de 256 bits.',
          'Exige sincronização de relógio em tempo real entre cliente e servidor.',
          'Gera mensagens com o triplo do tamanho original.',
        ],
        'correct_index': 0,
        'explanation':
            'O modo ECB não usa vetor de inicialização nem encadeamento. Blocos idênticos geram cifras idênticas, permitindo inferir estruturas internas (ex: a famosa imagem do pinguim Tux cifrado em ECB).',
        'rag_sources': ['NIST SP 800-38A', 'CompTIA Security+ SY0-701'],
      },
    ];

    return cryptoPool.take(count).toList();
  }

  // ---------------------------------------------------------------------------
  // BANCO DE FLASHCARDS AUTÔNOMO PARA MODO LOCAL / OFFLINE
  // ---------------------------------------------------------------------------
  static List<Map<String, dynamic>> _generateAutonomousFlashcards(
    String subject,
    String topic,
    int count,
    String difficulty,
  ) {
    final lower = '$subject $topic'.toLowerCase();

    if (lower.contains('owasp') || lower.contains('appsec') || lower.contains('software')) {
      final pool = [
        {
          'front': 'O que é Broken Access Control (A01:2021) e por que é a falha nº 1 do OWASP Top 10?',
          'back': 'Ocorre quando usuários conseguem acessar recursos ou executar ações fora de suas permissões pretendidas (ex: manipular IDs na URL `?user_id=123`). É a nº 1 porque é extremamente prevalente e comum em arquiteturas modernas de microsserviços.',
          'tags': ['OWASP', 'A01:2021', 'Access Control'],
        },
        {
          'front': 'Como Prepared Statements (Consultas Parametrizadas) eliminam SQL Injection?',
          'back': 'Prepared Statements enviam a estrutura da query SQL para compilação prévia no banco, tratando os parâmetros como valores literais puros. Mesmo que o parâmetro contenha aspas ou comandos (`OR 1=1`), ele nunca é interpretado como código SQL executável.',
          'tags': ['AppSec', 'SQL Injection', 'Mitigação'],
        },
        {
          'front': 'Qual a diferença entre XSS Armazenado (Stored) e XSS Refletido (Reflected)?',
          'back': 'XSS Refletido ocorre quando o payload é enviado na requisição (ex: busca na URL) e refletido imediatamente na resposta. XSS Armazenado é persistido no banco de dados (ex: comentários de blog), atacando todos os usuários que visualizarem a página posteriormente.',
          'tags': ['OWASP', 'XSS', 'Web Security'],
        },
        {
          'front': 'Qual a função dos cabeçalhos CSP (Content Security Policy) e CORS na proteção de navegadores?',
          'back': 'CSP restringe as origens das quais scripts, imagens e conexões podem ser carregados, bloqueando execução de scripts inline em caso de XSS. CORS instrui o navegador a permitir ou proibir que páginas de outra origem leiam recursos via fetch/XHR.',
          'tags': ['HTTP Headers', 'CSP', 'CORS'],
        },
        {
          'front': 'Por que tokens CSRF são essenciais para requisições com mutação de estado?',
          'back': 'Navegadores anexam cookies de sessão automaticamente em requisições cross-site. Um token CSRF é um valor imprevisível e vinculado à sessão que não é enviado automaticamente, garantindo que a requisição partiu legitimamente da aplicação do usuário.',
          'tags': ['CSRF', 'Autenticação', 'Sessões'],
        },
      ];
      return pool.take(count).toList();
    }

    if (lower.contains('cloud') || lower.contains('aws') || lower.contains('devops') || lower.contains('kubernetes')) {
      final pool = [
        {
          'front': 'Qual a diferença crucial entre um Internet Gateway (IGW) e um NAT Gateway na AWS?',
          'back': 'IGW realiza tradução de endereço 1:1 e permite conexões bidirecionais (inbound e outbound) em subnets públicas. NAT Gateway permite que instâncias em subnets privadas façam requisições para a Internet (outbound), mas impede que conexões externas iniciem contato (inbound).',
          'tags': ['AWS', 'VPC', 'Networking'],
        },
        {
          'front': 'Qual o conceito de Imutabilidade de Infraestrutura e como ele reduz Configuration Drift?',
          'back': 'Servidores e contêineres nunca são modificados ou atualizados in-place. Se uma alteração for necessária, uma nova imagem é construída, testada e implantada substituindo as instâncias antigas, garantindo paridade idêntica entre ambientes.',
          'tags': ['DevOps', 'IaC', 'Imutabilidade'],
        },
        {
          'front': 'Qual a diferença entre Kubernetes Pod, Deployment e Service?',
          'back': 'Pod: Menor unidade de execução que encapsula um ou mais contêineres. Deployment: Gerencia o ciclo de vida, réplicas e rolling updates dos Pods. Service: Provê um IP estável e balanceador de carga DNS para que outros pods ou clientes alcancem o conjunto efêmero de Pods.',
          'tags': ['Kubernetes', 'K8s', 'Containers'],
        },
        {
          'front': 'O que é o Teorema CAP em sistemas distribuídos?',
          'back': 'Em uma rede com Partição (P), um sistema distribuído só pode garantir Consistência (C - todos os nós leem o mesmo dado mais recente) OU Disponibilidade (A - toda requisição recebe resposta sem garantia de ser a mais recente), nunca ambos simultaneamente.',
          'tags': ['Sistemas Distribuídos', 'CAP', 'Bancos'],
        },
      ];
      return pool.take(count).toList();
    }

    // Default Crypto / Security / General High-Yield Pool
    final generalPool = [
      {
        'front': 'Conceito Fundamental de $topic: Qual é o seu objetivo primário?',
        'back': 'No contexto de $subject, $topic é projetado para resolver problemas críticos de integridade, confiabilidade e desempenho através de abstrações bem definidas e contratos determinísticos.',
        'tags': [subject, topic],
      },
      {
        'front': '$topic: Qual a principal armadilha ou antipadrão a ser evitado?',
        'back': 'A armadilha mais comum é assumir comportamentos implícitos sem validação de limites, o que pode introduzir vulnerabilidades de segurança, sobrecarga de recursos ou acoplamento excessivo.',
        'tags': [subject, 'Boas Práticas'],
      },
      {
        'front': '$topic: Qual é o trade-off fundamental envolvido?',
        'back': 'O trade-off envolve balancear complexidade de implementação vs resiliência e escala. Otimizações prematuras geralmente aumentam a dívida técnica sem ganhos mensuráveis.',
        'tags': [subject, 'Arquitetura'],
      },
      {
        'front': '$topic: Como validar o funcionamento em ambientes de produção?',
        'back': 'Através de telemetria observável (métricas, logs estruturados e tracing distribuído) combinada com testes automatizados de regressão e checagem de saúde (health checks).',
        'tags': [subject, 'Operações'],
      },
    ];

    return generalPool.take(count).toList();
  }

  // ---------------------------------------------------------------------------
  // HELPERS DE FORMATAÇÃO E PARSE
  // ---------------------------------------------------------------------------
  static String _formatDuration(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m > 0 ? '${h}h${m.toString().padLeft(2, '0')}' : '${h}h';
    }
    return '${minutes}m';
  }

  static DateTime _parseRelativeTime(String text) {
    final now = DateTime.now();
    final lower = text.toLowerCase();

    int targetWeekday = now.weekday;
    if (lower.contains('sexta')) targetWeekday = DateTime.friday;
    if (lower.contains('segunda')) targetWeekday = DateTime.monday;
    if (lower.contains('terça') || lower.contains('terca')) targetWeekday = DateTime.tuesday;
    if (lower.contains('quarta')) targetWeekday = DateTime.wednesday;
    if (lower.contains('quinta')) targetWeekday = DateTime.thursday;
    if (lower.contains('sábado') || lower.contains('sabado')) targetWeekday = DateTime.saturday;
    if (lower.contains('domingo')) targetWeekday = DateTime.sunday;

    DateTime targetDay = now;
    if (lower.contains('amanhã') || lower.contains('amanha')) {
      targetDay = now.add(const Duration(days: 1));
    } else if (lower.contains('sexta') || lower.contains('segunda') || lower.contains('terça') || lower.contains('quarta') || lower.contains('quinta') || lower.contains('sábado') || lower.contains('domingo')) {
      int daysToAdd = (targetWeekday - now.weekday + 7) % 7;
      if (daysToAdd == 0) daysToAdd = 7;
      targetDay = now.add(Duration(days: daysToAdd));
    }

    int hour = 14;
    int minute = 0;
    final hourMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(lower);
    final hourSimpleMatch = RegExp(r'(\d{1,2})h').firstMatch(lower);

    if (hourMatch != null) {
      hour = int.tryParse(hourMatch.group(1)!) ?? 14;
      minute = int.tryParse(hourMatch.group(2)!) ?? 0;
    } else if (hourSimpleMatch != null) {
      hour = int.tryParse(hourSimpleMatch.group(1)!) ?? 14;
    }

    return DateTime(targetDay.year, targetDay.month, targetDay.day, hour, minute);
  }

  static String _formatTimeBrief(DateTime dt) {
    final weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    final wd = weekdays[(dt.weekday - 1) % 7];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$wd $h:$m';
  }

  static String _formatTimeFull(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
