import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'noesis_agent_tools.dart';
import 'supabase_service.dart';
import '../features/flashcards/models/flashcard_model.dart';
import '../features/quizzes/data/exam_models_catalog.dart';
import '../features/roadmaps/models/roadmap_model.dart';

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

  // Remove texto solto antes do primeiro '[' e após o ']' correspondente (sem cortar arrays internos caso o payload tenha sido truncado)
  final firstBracket = cleanJson.indexOf('[');
  final firstBrace = cleanJson.indexOf('{');
  if (firstBracket != -1 && (firstBrace == -1 || firstBracket < firstBrace)) {
    final matchingEnd = _findMatchingBracketEnd(cleanJson, firstBracket, '[', ']');
    cleanJson = matchingEnd != -1
        ? cleanJson.substring(firstBracket, matchingEnd + 1)
        : cleanJson.substring(firstBracket);
  }

  final sanitized = _stripTrailingJsonCommas(cleanJson);

  try {
    final decoded = jsonDecode(sanitized);
    if (decoded is List) {
      return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } else if (decoded is Map && decoded.containsKey('questions')) {
      final list = decoded['questions'];
      if (list is List) {
        return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } else if (decoded is Map && decoded.containsKey('decks')) {
      final list = decoded['decks'];
      if (list is List) {
        return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
  } catch (_) {
    // Fallback resiliente: recupera objetos JSON completos se o array foi truncado
    // ou se um único item veio com erro de sintaxe perto do limite de tokens.
    final salvaged = _salvageJsonObjects(sanitized);
    if (salvaged.isNotEmpty) {
      return salvaged;
    }
    rethrow;
  }

  throw const FormatException('Formato de JSON inesperado recebido.');
}

/// Encontra o índice de fechamento correspondente ao delimitador de abertura em `start`.
int _findMatchingBracketEnd(String input, int start, String openChar, String closeChar) {
  bool inString = false;
  bool escaped = false;
  int depth = 0;

  for (int i = start; i < input.length; i++) {
    final ch = input[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch == r'\') {
        escaped = true;
      } else if (ch == '"') {
        inString = false;
      }
      continue;
    }

    if (ch == '"') {
      inString = true;
      continue;
    }

    if (ch == openChar) {
      depth++;
    } else if (ch == closeChar) {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

/// Remove vírgulas finais inválidas antes de `}` ou `]` preservando strings.
String _stripTrailingJsonCommas(String input) {
  final sb = StringBuffer();
  bool inString = false;
  bool escaped = false;

  for (int i = 0; i < input.length; i++) {
    final ch = input[i];
    if (inString) {
      sb.write(ch);
      if (escaped) {
        escaped = false;
      } else if (ch == r'\') {
        escaped = true;
      } else if (ch == '"') {
        inString = false;
      }
      continue;
    }

    if (ch == '"') {
      inString = true;
      sb.write(ch);
      continue;
    }

    if (ch == ',') {
      int j = i + 1;
      while (j < input.length &&
          (input[j] == ' ' || input[j] == '\t' || input[j] == '\n' || input[j] == '\r')) {
        j++;
      }
      if (j < input.length && (input[j] == '}' || input[j] == ']')) {
        continue; // descarta trailing comma
      }
    }

    sb.write(ch);
  }
  return sb.toString();
}

/// Extrai individualmente cada objeto `{ ... }` bem-formado dentro de um JSON truncado.
List<Map<String, dynamic>> _salvageJsonObjects(String input) {
  final results = <Map<String, dynamic>>[];
  bool inString = false;
  bool escaped = false;
  int depth = 0;
  int? objStart;

  for (int i = 0; i < input.length; i++) {
    final ch = input[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch == r'\') {
        escaped = true;
      } else if (ch == '"') {
        inString = false;
      }
      continue;
    }

    if (ch == '"') {
      inString = true;
      continue;
    }

    if (ch == '{') {
      if (depth == 0) {
        objStart = i;
      }
      depth++;
    } else if (ch == '}' && depth > 0) {
      depth--;
      if (depth == 0 && objStart != null) {
        final slice = input.substring(objStart, i + 1);
        try {
          final parsed = jsonDecode(_stripTrailingJsonCommas(slice));
          if (parsed is Map) {
            results.add(Map<String, dynamic>.from(parsed));
          }
        } catch (_) {
          // Ignora objeto isolado malformado e continua salvando os válidos
        }
        objStart = null;
      }
    }
  }
  return results;
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
  static String model = 'gemini-flash-lite-latest';
  static String baseUrl = '';
  static double temperature = 0.4;
  static List<AgentAction> lastExecutedActions = [];
  static List<String> operationalGoogleModels = [];
  static String? _operationalKeyCache;

  static const List<AIProvider> providers = [
    AIProvider(
      id: 'google',
      label: 'Google Gemini',
      keyUrl: 'https://aistudio.google.com/app/apikey',
      models: [
        'gemini-flash-lite-latest',
        'gemini-3-flash-preview',
        'gemini-3.5-flash-lite',
        'gemini-2.5-flash',
        'gemini-2.0-flash',
      ],
      defaultModel: 'gemini-flash-lite-latest',
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

    // Se a listagem não trouxe candidatos, usa versões atuais da Google como candidatas
    if (candidates.isEmpty) {
      candidates.addAll([
        'gemini-flash-lite-latest',
        'gemini-3-flash-preview',
        'gemini-3.5-flash-lite',
        'gemini-2.5-flash',
        'gemini-2.0-flash',
      ]);
    } else {
      // Prioriza modelos flash mais atuais e disponíveis na conta
      candidates.sort((a, b) {
        int score(String m) {
          if (m == 'gemini-flash-lite-latest') return 0;
          if (m == 'gemini-3-flash-preview') return 1;
          if (m == 'gemini-3.5-flash-lite') return 2;
          if (m == 'gemini-2.5-flash') return 3;
          if (m == 'gemini-2.0-flash') return 4;
          if (m.contains('flash')) return 5;
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

    if (operational.isNotEmpty) {
      operationalGoogleModels = List<String>.from(operational);
      _operationalKeyCache = apiKey;
      if (provider == 'google' && !operational.contains(model)) {
        model = operational.first;
      }
    }

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
  // GERADOR DE SIMULADOS (QUIZ ENGINE — ATÉ 200 QUESTÕES EM LOTES)
  // ---------------------------------------------------------------------------
  static const int quizBatchSize = 8;
  static const int quizMaxQuestions = 200;

  @visibleForTesting
  static List<Map<String, dynamic>> parseJsonPayloadForTest(String rawJson) =>
      _parseJsonPayload(rawJson);

  /// Gera apenas 1 lote de questões (usado no carregamento progressivo sem perder a contagem total).
  static Future<List<Map<String, dynamic>>> generateQuizBatch({
    required String subject,
    required String topic,
    required int batchCount,
    required int totalTarget,
    required int startNumber,
    required int batchIndex,
    required String difficulty,
    String? referenceDocumentText,
    String? examModelName,
    String? examBlueprintText,
    List<String> recentStems = const [],
  }) async {
    final key = apiKey?.trim() ?? '';
    var cleanModel = normalizeModel(provider, model);
    final safeBatchCount = batchCount.clamp(1, quizBatchSize);

    if (provider != 'custom' && key.isEmpty) {
      return _generateAutonomousQuiz(
        subject,
        topic,
        safeBatchCount,
        difficulty,
        examModelName: examModelName,
        startNumber: startNumber,
      );
    }

    // Garante que usamos apenas modelos realmente operacionais na conta Google atual
    if (provider == 'google' &&
        (operationalGoogleModels.isEmpty || _operationalKeyCache != key)) {
      final synced = await fetchOperationalGoogleModels(key);
      if (synced.models.isNotEmpty) {
        cleanModel = synced.models.contains(cleanModel) ? cleanModel : synced.models.first;
        model = cleanModel;
      }
    } else if (provider == 'google' &&
        operationalGoogleModels.isNotEmpty &&
        !operationalGoogleModels.contains(cleanModel)) {
      cleanModel = operationalGoogleModels.first;
      model = cleanModel;
    }

    final examModel = ExamModelsCatalog.findByName(examModelName);
    final condensedBlueprint = examBlueprintText != null && examBlueprintText.trim().isNotEmpty
        ? _condenseBlueprintForBatch(examBlueprintText, batchIndex)
        : null;
    final expectedDisciplines = examModel?.disciplinesForBatch(
      totalTarget: totalTarget,
      startNumber: startNumber,
      batchCount: safeBatchCount,
    );

    Object? lastError;
    for (int attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        // Backoff progressivo para evitar 429 (Rate Limit) em múltiplas chamadas
        await Future<void>.delayed(Duration(seconds: attempt * 3));
      }
      try {
        final batch = await _generateQuizBatch(
          cleanModel: cleanModel,
          key: key,
          subject: subject,
          topic: topic,
          referenceDocumentText: referenceDocumentText,
          examModelName: examModelName,
          examBlueprintText: condensedBlueprint,
          examModel: examModel,
          batchCount: safeBatchCount,
          totalTarget: totalTarget,
          startNumber: startNumber,
          batchIndex: batchIndex,
          difficulty: difficulty,
          avoidTopicsSummary: recentStems.isEmpty ? null : recentStems.take(35).join(' | '),
        );
        if (batch.isNotEmpty) {
          final normalized = <Map<String, dynamic>>[];
          final limited = batch.take(safeBatchCount).toList();
          for (int i = 0; i < limited.length; i++) {
            final item = Map<String, dynamic>.from(limited[i]);
            final fallbackDisc = (expectedDisciplines != null && i < expectedDisciplines.length)
                ? expectedDisciplines[i]
                : (subject.trim().isNotEmpty ? subject.trim() : topic);
            final rawDisc = (item['discipline'] ?? item['subject'] ?? item['area'] ?? '')
                .toString()
                .trim();
            item['discipline'] = rawDisc.isNotEmpty ? rawDisc : fallbackDisc;
            if (item['supporting_text'] != null) {
              item['supporting_text'] = item['supporting_text'].toString().trim();
            }
            if (item['source_citation'] != null) {
              item['source_citation'] = item['source_citation'].toString().trim();
            }
            normalized.add(item);
          }
          return normalized;
        }
      } catch (e) {
        lastError = e;
        final errStr = e.toString().toLowerCase();
        // Não insiste em retry se for erro definitivo de chave/permissão
        if (errStr.contains('(401)') ||
            errStr.contains('(403)') ||
            errStr.contains('api key not valid') ||
            errStr.contains('api_key_invalid')) {
          rethrow;
        }
      }
    }

    if (lastError != null) throw lastError;
    throw Exception('A IA retornou um lote vazio. Tente novamente em instantes.');
  }

  static Future<List<Map<String, dynamic>>> generateQuiz({
    required String subject,
    required String topic,
    String? referenceDocumentText,
    String? examModelName,
    String? examBlueprintText,
    int numberOfQuestions = 5,
    String difficulty = 'médio/avançado',
    void Function(int generated, int total)? onProgress,
  }) async {
    final key = apiKey?.trim() ?? '';
    final safeTotal = numberOfQuestions.clamp(1, quizMaxQuestions);

    if (provider != 'custom' && key.isEmpty) {
      final local = _generateAutonomousQuiz(
        subject,
        topic,
        safeTotal,
        difficulty,
        examModelName: examModelName,
      );
      onProgress?.call(local.length, safeTotal);
      return local;
    }

    final List<Map<String, dynamic>> accumulated = [];
    final List<String> recentStems = [];

    int batchIndex = 0;
    while (accumulated.length < safeTotal) {
      batchIndex++;
      if (batchIndex > 1) {
        // Pacing suave para respeitar limites de RPM entre lotes consecutivos
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
      final remaining = safeTotal - accumulated.length;
      final currentBatchCount = remaining > quizBatchSize ? quizBatchSize : remaining;

      final batchQuestions = await generateQuizBatch(
        subject: subject,
        topic: topic,
        batchCount: currentBatchCount,
        totalTarget: safeTotal,
        startNumber: accumulated.length + 1,
        batchIndex: batchIndex,
        difficulty: difficulty,
        referenceDocumentText: referenceDocumentText,
        examModelName: examModelName,
        examBlueprintText: examBlueprintText,
        recentStems: recentStems,
      );

      for (final q in batchQuestions) {
        if (accumulated.length >= safeTotal) break;
        accumulated.add(q);
        final stem = (q['question'] as String? ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
        if (stem.isNotEmpty) {
          recentStems.add(stem.length > 65 ? stem.substring(0, 65) : stem);
        }
      }

      onProgress?.call(accumulated.length, safeTotal);
    }

    return accumulated;
  }

  static String _condenseBlueprintForBatch(String rawBlueprint, int batchIndex) {
    final trimmed = rawBlueprint.trim();
    final maxChars = batchIndex == 1 ? 5200 : 2800;
    if (trimmed.length <= maxChars) return trimmed;
    // Em lotes subsequentes, prioriza Requisitos, Lógica de Distratores e Diretrizes Obrigatórias
    final guidelinesIdx = trimmed.indexOf('## 4.');
    if (guidelinesIdx != -1 && batchIndex > 1) {
      final head = trimmed.substring(0, (trimmed.length).clamp(0, 1400));
      final tail = trimmed.substring(guidelinesIdx);
      final combined = '$head\n\n...\n\n$tail';
      return combined.length <= maxChars ? combined : combined.substring(0, maxChars);
    }
    return trimmed.substring(0, maxChars);
  }

  /// Gera uma análise pedagógica da IA comparando acertos, erros e recomendações de melhoria.
  static Future<String> generateQuizPerformanceReview({
    required String subject,
    required String topic,
    String? examModelName,
    required List<Map<String, dynamic>> questions,
    required Map<int, int> userAnswers,
    required int elapsedSeconds,
  }) async {
    final total = questions.length;
    int correct = 0;
    int wrong = 0;
    int blank = 0;
    final wrongDetails = <String>[];
    final rightTopics = <String>{};
    final wrongTopics = <String>{};

    for (int i = 0; i < total; i++) {
      final q = questions[i];
      final correctIdx = q['correct_index'] as int? ?? 0;
      final selectedIdx = userAnswers[i];
      final options = (q['options'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final disc = (q['discipline'] as String? ?? '').trim();
      final rawSources = (q['rag_sources'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final sources = <String>{
        if (disc.isNotEmpty) disc,
        ...rawSources,
        if (disc.isEmpty && rawSources.isEmpty) subject,
      }.toList();

      if (selectedIdx == null) {
        blank++;
        wrongTopics.addAll(sources);
      } else if (selectedIdx == correctIdx) {
        correct++;
        rightTopics.addAll(sources);
      } else {
        wrong++;
        wrongTopics.addAll(sources);
        if (wrongDetails.length < 18) {
          final qStem = (q['question'] as String? ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
          final shortStem = qStem.length > 140 ? '${qStem.substring(0, 140)}...' : qStem;
          final userOpt = selectedIdx < options.length ? options[selectedIdx] : 'Opção ${selectedIdx + 1}';
          final rightOpt = correctIdx < options.length ? options[correctIdx] : 'Opção ${correctIdx + 1}';
          wrongDetails.add(
            '- Q${i + 1} [${sources.join(", ")}]: "$shortStem"\n  Marcou: "$userOpt" | Gabarito: "$rightOpt"',
          );
        }
      }
    }

    final answered = correct + wrong;
    final accuracyAnswered = answered > 0 ? ((correct / answered) * 100).round() : 0;
    final accuracyTotal = total > 0 ? ((correct / total) * 100).round() : 0;

    final key = apiKey?.trim() ?? '';
    if (provider != 'custom' && key.isEmpty) {
      return _buildAutonomousReview(
        examName: examModelName ?? topic,
        total: total,
        correct: correct,
        wrong: wrong,
        blank: blank,
        accuracyTotal: accuracyTotal,
        accuracyAnswered: accuracyAnswered,
        rightTopics: rightTopics.toList(),
        wrongTopics: wrongTopics.toList(),
      );
    }

    final prompt = '''
Você é um mentor pedagógico especialista em exames do Aster Noesis.
Analise o desempenho do estudante neste simulado e gere um feedback objetivo, estratégico e acionável em Português (Markdown).

DADOS DA SESSÃO:
- Prova / Modelo: ${examModelName ?? topic} ($subject)
- Questões avaliadas: $total | Respondidas: $answered | Acertos: $correct ($accuracyTotal% do total, $accuracyAnswered% das respondidas) | Erros: $wrong | Em branco: $blank
- Tempo decorrido: ${(elapsedSeconds ~/ 60)}m ${(elapsedSeconds % 60)}s
- Tópicos com acertos: ${rightTopics.isEmpty ? 'Nenhum registrado' : rightTopics.take(8).join(', ')}
- Tópicos com erros/lacunas: ${wrongTopics.isEmpty ? 'Nenhum erro' : wrongTopics.take(8).join(', ')}

QUESTÕES ERRADAS PELO ESTUDANTE:
${wrongDetails.isEmpty ? 'Nenhum erro registrado nas questões respondidas!' : wrongDetails.join('\n')}

ESTRUTURA OBRIGATÓRIA DA RESPOSTA (seja direto, use bullets e negrito):
### 1. Diagnóstico do Desempenho
(Avalie precisão, ritmo de prova e impacto de erros ou itens em branco.)

### 2. Pontos Fortes
(O que o estudante já domina com base nos acertos.)

### 3. Onde Você Mais Perdeu Pontos & Padrão de Erro
(Explique objetivamente os conceitos/pegadinhas das questões erradas acima.)

### 4. Plano Prático de Melhoria (Próximos Passos)
(Liste 3 ações específicas de revisão e treino para elevar a nota no próximo simulado.)
''';

    try {
      final result = await _executeRawPrompt(
        prompt: prompt,
        systemInstruction: 'Você é um tutor especialista em preparação para provas e certificações. Responda apenas com a análise em Markdown limpo.',
        timeoutSeconds: 45,
      );
      if (result.trim().isNotEmpty) {
        return result.trim();
      }
    } catch (_) {
      // Fallback elegante caso a API oscile ao gerar review
    }

    return _buildAutonomousReview(
      examName: examModelName ?? topic,
      total: total,
      correct: correct,
      wrong: wrong,
      blank: blank,
      accuracyTotal: accuracyTotal,
      accuracyAnswered: accuracyAnswered,
      rightTopics: rightTopics.toList(),
      wrongTopics: wrongTopics.toList(),
    );
  }

  static String _buildAutonomousReview({
    required String examName,
    required int total,
    required int correct,
    required int wrong,
    required int blank,
    required int accuracyTotal,
    required int accuracyAnswered,
    required List<String> rightTopics,
    required List<String> wrongTopics,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('### 1. Diagnóstico Geral · $examName');
    buffer.writeln('- **Aproveitamento global:** $correct/$total acertos (**$accuracyTotal%**).');
    if (blank > 0) {
      buffer.writeln('- **Precisão nas respondidas:** **$accuracyAnswered%** (${total - blank} respondidas, $blank em branco).');
    }
    buffer.writeln('');
    buffer.writeln('### 2. Pontos Fortes');
    if (rightTopics.isNotEmpty && correct > 0) {
      buffer.writeln('- Bom domínio inicial em: **${rightTopics.take(5).join(', ')}**.');
    } else {
      buffer.writeln('- Ainda não há acertos suficientes para consolidar pontos fortes; revise os gabaritos comentados questão a questão.');
    }
    buffer.writeln('');
    buffer.writeln('### 3. Pontos de Melhoria');
    if (wrong > 0 || blank > 0) {
      buffer.writeln('- Priorize a revisão dos erros em: **${wrongTopics.take(6).join(', ')}**.');
      buffer.writeln('- Use o filtro **Erros** no comparativo acima e clique para inspecionar o raciocínio de cada distrator marcado.');
    } else {
      buffer.writeln('- Desempenho impecável neste bloco! Aumente o nível de profundidade ou avance para mais lotes.');
    }
    return buffer.toString();
  }

  static Future<List<Map<String, dynamic>>> _generateQuizBatch({
    required String cleanModel,
    required String key,
    required String subject,
    required String topic,
    required int batchCount,
    required int totalTarget,
    required int startNumber,
    required int batchIndex,
    required String difficulty,
    String? referenceDocumentText,
    String? examModelName,
    String? examBlueprintText,
    ExamModelTemplate? examModel,
    String? avoidTopicsSummary,
  }) async {
    final hasBlueprint = examBlueprintText != null && examBlueprintText.trim().isNotEmpty;
    final hasReference = referenceDocumentText != null && referenceDocumentText.trim().isNotEmpty;
    final sectionDirective = examModel != null
        ? '\n${examModel.formatBatchSectionDirective(totalTarget: totalTarget, startNumber: startNumber, batchCount: batchCount)}\n'
        : '';

    final blueprintSection = hasBlueprint
        ? '''
MODELO OFICIAL DE PROVA SELECIONADO: ${examModelName ?? topic}
Siga rigorosamente os requisitos, estilo de enunciado, arquitetura de distratores, quantidade de alternativas e diretrizes do guia oficial abaixo:
"""
${examBlueprintText.trim()}
"""
'''
        : '';

    final referenceSection = hasReference
        ? '''
MATERIAIS DE ESTUDO ANEXADOS PELO USUÁRIO (FLASHCARDS, CADERNOS E/OU APOSTILAS — BASE PRIORITÁRIA):
Utilize prioritariamente os conceitos, definições, anotações e exemplos dos materiais anexados abaixo para formular as questões, distratores plausíveis e explicações (mantendo o estilo/formato do modelo de prova escolhido):
"""
${referenceDocumentText.trim()}
"""
'''
        : '';

    final antiDupSection = avoidTopicsSummary != null
        ? '\nNÃO REPITA cenários ou perguntas equivalentes às já criadas anteriormente neste simulado:\n[$avoidTopicsSummary]\n'
        : '';

    final defaultDiscipline = examModel != null
        ? examModel
            .disciplinesForBatch(
              totalTarget: totalTarget,
              startNumber: startNumber,
              batchCount: batchCount,
            )
            .first
        : (subject.trim().isNotEmpty ? subject.trim() : topic);

    final prompt = '''
Você é o examinador sênior do Aster Noesis. Crie um lote de questões para um simulado de alto nível sobre "$subject - $topic".
Dificuldade: $difficulty.
Lote $batchIndex (questões $startNumber a ${startNumber + batchCount - 1} de um total de $totalTarget).
QUANTIDADE EXATA DESTE LOTE: $batchCount questões.
$sectionDirective$blueprintSection$referenceSection$antiDupSection
INSTRUÇÕES DE FORMATO E SEPARAÇÃO DE DISCIPLINAS:
- Respeite a DIVISÃO SEQUENCIAL DE DISCIPLINAS acima (se definida): NUNCA misture matérias aleatoriamente nem alterne disciplinas fora da sequência oficial do caderno. Cada objeto do array DEVE preencher "discipline" exatamente com a disciplina correspondente àquela questão.
- Se o modelo oficial especificar 3 alternativas (ex.: DELE, DELF, CFA), 4 alternativas (ex.: SAT, ACT, OAB, Unicamp, CompTIA, Azure, GCP, CCNA), 5 alternativas (ex.: ENEM, FUVEST, USMLE, ENARE, ENAM, GRE/LSAT) ou 2 alternativas (ex.: CEBRASPE Certo/Errado), respeite esse número exato no array "options" (padrão: 4 alternativas caso não haja especificação distinta).
- Em provas de idiomas estrangeiros (DELE, DELF, Goethe, JLPT, HSK, IELTS, TOEFL, Cambridge, SAT, ACT, GRE, GMAT, LSAT, USMLE), redija o enunciado e opções no idioma autêntico da prova e forneça "explanation" didática detalhada.
- Separação limpa entre Texto de Apoio e Pergunta: sempre que a questão trouxer um excerto, caso clínico, situação-problema ou trecho literário/jornalístico antes da pergunta, coloque esse conteúdo em "supporting_text" (e a referência bibliográfica em "source_citation", ex.: "Fonte: ..."), deixando em "question" APENAS a pergunta/enunciado objetivo final. Caso a questão não possua texto de apoio separado, deixe "supporting_text" e "source_citation" como strings vazias ("").
- NÃO escreva rótulos artificiais como "Texto-base:" ou "Comando:" no início das frases. NÃO use fórmulas LaTeX entre cifrões nem comandos com barra invertida — use texto simples e símbolos Unicode (10%, x², √2, ×, ÷, ≤, ≥, →). Não repita letras ("A) ", "B) ") dentro das strings de "options". Pode usar negrito Markdown (**termo**) para destacar palavras-chave.
- "rag_sources": inclua de 1 a 3 tags curtas citando o modelo/banca ou normas de referência usadas.

RETORNE ESTRITAMENTE um array JSON válido com exatamente $batchCount objetos no seguinte formato (sem Markdown extra):
[
  {
    "discipline": "$defaultDiscipline",
    "supporting_text": "Texto de apoio, citação ou situação contextualizada da questão (ou string vazia se não houver).",
    "source_citation": "Fonte: referência bibliográfica curta (ou string vazia).",
    "question": "Pergunta / enunciado completo final da questão...",
    "code_snippet": "Trecho de código, log, saída CLI ou tabela auxiliar opcional (ou string vazia)",
    "options": [
      "Alternativa A",
      "Alternativa B",
      "Alternativa C",
      "Alternativa D"
    ],
    "correct_index": 0,
    "explanation": "Explicação detalhada do gabarito e do erro de cada distrator.",
    "rag_sources": ["${examModelName ?? subject}", "$defaultDiscipline"]
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
            temperature: 0.35,
            maxOutputTokens: 8192,
            responseMimeType: 'application/json',
          ),
        );
        final response = await generModel
            .generateContent([Content.text(prompt)])
            .timeout(const Duration(seconds: 75));
        text = response.text ?? '';
      } catch (_) {
        text = '';
      }

      if (text.trim().isEmpty) {
        text = await _executeGoogleRest(
          prompt: prompt,
          systemInstruction: 'Retorne estritamente um array JSON válido.',
          timeoutSeconds: 75,
          jsonMode: true,
          allowModelFallback: true,
        );
      }
    } else {
      text = await _executeRawPrompt(
        prompt: prompt,
        systemInstruction: 'Retorne estritamente um array JSON válido.',
        timeoutSeconds: 75,
      );
    }

    if (text.trim().isEmpty) {
      return [];
    }

    try {
      return await compute(_parseJsonPayload, text);
    } catch (e) {
      debugPrint('Erro ao parsear JSON do lote $batchIndex do simulado: $e \nTexto: $text');
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
  static const String _internalSafetyDirective =
      'REGRA OBRIGATÓRIA DE INTERFACE: NUNCA mencione, cite ou exiba nomes internos de ferramentas/funções '
      '(como inspect_account_data, log_study_session, update_study_session, delete_study_session, '
      'schedule_calendar_event, update_calendar_event, delete_calendar_event, set_weekly_goal, '
      'create_quiz, delete_quiz, create_flashcards, update_flashcard_deck, delete_flashcard_deck, '
      'create_notebook_or_note, update_notebook_or_note, delete_notebook_or_note, '
      'create_roadmap, update_roadmap, delete_roadmap), '
      'nomes de tabelas ou colunas do banco de dados (como noesis_sessions, noesis_quizzes, '
      'noesis_calendar_events, noesis_flashcard_decks, noesis_study_notebooks, noesis_roadmaps, '
      'profiles, user_id, supabase), comandos SQL, IDs internos ou tags JSON/XML para o usuário. '
      'Descreva sempre seus recursos em linguagem natural amigável em português '
      '(ex.: "Registro de Estudos", "Calendário", "Simulados", "Flashcards", "Cadernos", "Trilhas").\n'
      'REGRA DE INTEGRIDADE: SÓ afirme que criou, agendou, alterou ou excluiu algo DEPOIS de executar '
      'realmente a ferramenta correspondente e receber status de sucesso. Nunca invente confirmações sem chamar a ferramenta.';

  /// Remove eventuais vazamentos de nomes internos de funções/ferramentas/tabelas do DB na resposta ao usuário.
  static String sanitizeUserFacingReply(String rawReply) {
    var cleaned = rawReply;
    // Remove blocos <noesis_action>...</noesis_action> residuais
    cleaned = cleaned.replaceAll(RegExp(r'<noesis_action>[\s\S]*?<\/noesis_action>'), '');

    // Remove citações entre parênteses ou isoladas de nomes internos de ferramentas
    const internalToolPattern =
        r'(?:inspect_account_data|log_study_session|update_study_session|delete_study_session|schedule_calendar_event|update_calendar_event|delete_calendar_event|set_weekly_goal|create_quiz|delete_quiz|create_flashcards|update_flashcard_deck|delete_flashcard_deck|create_notebook_or_note|update_notebook_or_note|delete_notebook_or_note|create_roadmap|update_roadmap|delete_roadmap|log_session|calendar\.create|quiz\.create|flashcards\.create)';
    cleaned = cleaned.replaceAll(
      RegExp('\\s*\\(\\s*`?$internalToolPattern(?:\\(\\))?`?\\s*\\)', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp('`?$internalToolPattern(?:\\(\\))?`?', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(
        r'`?\bnoesis_(?:sessions|calendar_events|documents|quizzes|flashcard_decks|study_notebooks|roadmaps|user_preferences)\b`?',
        caseSensitive: false,
      ),
      'dados do app',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'`?\b(?:public\.profiles|supabase|auth\.users)\b`?', caseSensitive: false),
      'sua conta',
    );

    // Limpa espaços duplicados e linhas em branco excessivas preservando quebras de Markdown
    cleaned = cleaned.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+([.,:;!?])'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return cleaned.trim();
  }

  static Future<List<Map<String, dynamic>>> _agentQuizCallback({
    required String subject,
    required String topic,
    required int numberOfQuestions,
    required String difficulty,
    String? referenceContext,
  }) =>
      generateQuiz(
        subject: subject,
        topic: topic,
        numberOfQuestions: numberOfQuestions,
        difficulty: difficulty,
        referenceDocumentText: referenceContext,
      );

  static Future<List<Map<String, dynamic>>> _agentFlashcardsCallback({
    required String subject,
    required String topic,
    required int count,
    String difficulty = 'Médio / Prático',
  }) =>
      generateFlashcards(
        subject: subject,
        topic: topic,
        count: count,
        difficulty: difficulty,
      );

  static Future<({String title, List<RoadmapStep> steps})> _agentRoadmapCallback({
    required String subject,
    required String goal,
    required String level,
    required int estimatedWeeks,
    String? focusNotes,
  }) async {
    final rm = await generateStudyRoadmap(
      subject: subject,
      goal: goal,
      level: level,
      estimatedWeeks: estimatedWeeks,
      extraNotes: focusNotes,
    );
    return (title: rm.title, steps: rm.steps);
  }

  static List<AgentAction> _toAgentActions(List<ExecutedToolResult> executed) {
    return executed
        .map(
          (e) => AgentAction(
            name: e.name,
            parameters: e.parameters,
            status: e.status,
            summary: e.summary,
            data: e.data,
          ),
        )
        .toList();
  }

  static Future<String> executeAgentChat({
    required String userMessage,
    required List<Content> history,
    String? attachmentContext,
  }) async {
    lastExecutedActions = [];
    final key = apiKey?.trim() ?? '';

    if (provider != 'custom' && key.isEmpty) {
      return 'Por favor, configure sua chave de API nas Configurações para ativar o assistente Noesis AI.';
    }

    final now = DateTime.now();
    final snapshot = await NoesisAgentTools.buildAccountSnapshotText();
    final cleanAttach = attachmentContext?.trim() ?? '';
    final fullUserPrompt = cleanAttach.isEmpty
        ? userMessage
        : '$userMessage\n\n[CONTEÚDO ANEXADO PELO USUÁRIO PARA LEITURA/ANÁLISE]:\n$cleanAttach';

    final nowIso = now.toIso8601String();
    final weekdays = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
    final wd = weekdays[(now.weekday - 1) % 7];

    final agentSystemPrompt =
        'Você é o Noesis AI, o agente pessoal de estudos e alta produtividade do Aster.\n'
        'Data e hora atual do usuário: $wd, $nowIso.\n'
        'Você tem controle total sobre TODAS as páginas do Noesis (Calendário, Diário de Estudos, Meta Semanal, Simulados, Flashcards, Cadernos de Estudo e Trilhas/Roadmaps) e pode ler/revisar tudo da conta.\n'
        '- Sempre use as ferramentas disponíveis para consultar, criar, editar ou remover itens reais antes de responder.\n'
        '- Ao interpretar datas naturais como "11 da manhã de hoje", "amanhã às 19h" ou "sexta às 14h", converta para ISO-8601 usando a data atual ($nowIso).\n'
        '- Se houver conteúdo anexado (arquivos ou itens do Noesis), leia-o com atenção e utilize-o na resposta ou na criação de simulados/flashcards/resumos.\n'
        '- Responda em Markdown elegante, direto e útil.\n\n'
        '$snapshot\n\n'
        '$_internalSafetyDirective';

    if (provider == 'google') {
      try {
        final restResult = await _executeGoogleRestAgentWithTools(
          userMessage: userMessage,
          promptWithAttachments: fullUserPrompt,
          attachmentContext: cleanAttach.isEmpty ? null : cleanAttach,
          history: history,
          systemInstruction: agentSystemPrompt,
        );
        lastExecutedActions = _toAgentActions(restResult.executedTools);
        return sanitizeUserFacingReply(restResult.reply);
      } catch (e) {
        debugPrint('Erro no executor Google REST com ferramentas: $e');
        final result = await _processAutonomousAgent(
          userMessage,
          attachmentContext: cleanAttach.isEmpty ? null : cleanAttach,
        );
        lastExecutedActions = result.actions;
        return sanitizeUserFacingReply(result.reply);
      }
    }

    try {
      final rawReply = await _executeRawPrompt(
        prompt: fullUserPrompt,
        systemInstruction: '$agentSystemPrompt\n\n'
            'Para executar ações reais no sistema, inclua ao final da resposta uma ou mais tags:\n'
            '<noesis_action>{"action": "<nome>", "data": {...}}</noesis_action>\n'
            'Ações suportadas: inspect_account_data, schedule_calendar_event, update_calendar_event, delete_calendar_event, '
            'log_study_session, update_study_session, delete_study_session, set_weekly_goal, create_quiz, delete_quiz, '
            'create_flashcards, update_flashcard_deck, delete_flashcard_deck, create_notebook_or_note, '
            'update_notebook_or_note, delete_notebook_or_note, create_roadmap, update_roadmap, delete_roadmap.',
      );

      final extracted = await _extractAndExecuteAction(
        rawReply,
        userMessage,
        attachmentContext: cleanAttach.isEmpty ? null : cleanAttach,
      );
      final actions = List<AgentAction>.from(extracted.actions);

      if (actions.isEmpty) {
        final recovered = await NoesisAgentTools.tryRecoverUnexecutedIntent(
          userMessage: userMessage,
          aiReply: extracted.reply,
          attachmentContext: cleanAttach.isEmpty ? null : cleanAttach,
          generateQuiz: _agentQuizCallback,
          generateFlashcards: _agentFlashcardsCallback,
          generateRoadmap: _agentRoadmapCallback,
        );
        if (recovered != null) {
          actions.addAll(_toAgentActions([recovered]));
        }
      }

      lastExecutedActions = actions;
      return sanitizeUserFacingReply(extracted.reply);
    } catch (_) {
      final result = await _processAutonomousAgent(
        userMessage,
        attachmentContext: cleanAttach.isEmpty ? null : cleanAttach,
      );
      lastExecutedActions = result.actions;
      return sanitizeUserFacingReply(result.reply);
    }
  }

  static Future<({String reply, List<ExecutedToolResult> executedTools})>
      _executeGoogleRestAgentWithTools({
    required String userMessage,
    required String promptWithAttachments,
    required String? attachmentContext,
    required List<Content> history,
    required String systemInstruction,
  }) async {
    final key = apiKey?.trim() ?? '';
    var primaryMod = normalizeModel('google', model);

    if (key.isNotEmpty &&
        (_operationalKeyCache != key ||
            operationalGoogleModels.isEmpty ||
            !operationalGoogleModels.contains(primaryMod))) {
      final synced = await fetchOperationalGoogleModels(key);
      if (synced.models.isNotEmpty && !synced.models.contains(primaryMod)) {
        primaryMod = synced.models.first;
        model = primaryMod;
      }
    }

    final candidateModels = <String>[];
    if (operationalGoogleModels.isNotEmpty && _operationalKeyCache == key) {
      if (operationalGoogleModels.contains(primaryMod)) {
        candidateModels.add(primaryMod);
      }
      for (final op in operationalGoogleModels) {
        if (!candidateModels.contains(op)) {
          candidateModels.add(op);
        }
      }
    }
    if (candidateModels.isEmpty) {
      candidateModels.add(primaryMod);
    }

    final baseContents = <Map<String, dynamic>>[];
    for (final item in history.take(16)) {
      final textParts = item.parts.whereType<TextPart>().map((p) => {'text': p.text}).toList();
      if (textParts.isEmpty) continue;
      baseContents.add({
        'role': item.role == 'model' ? 'model' : 'user',
        'parts': textParts,
      });
    }
    baseContents.add({
      'role': 'user',
      'parts': [
        {'text': promptWithAttachments}
      ],
    });

    Exception? lastError;

    for (int mIdx = 0; mIdx < candidateModels.length; mIdx++) {
      final mod = candidateModels[mIdx];
      final endpoint = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$mod:generateContent?key=$key',
      );
      final contents = List<Map<String, dynamic>>.from(baseContents);
      final executedTools = <ExecutedToolResult>[];
      var lastReply = '';

      try {
        for (int turn = 0; turn < 6; turn++) {
          final resp = await http
              .post(
                endpoint,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'systemInstruction': {
                    'parts': [
                      {'text': systemInstruction}
                    ]
                  },
                  'contents': contents,
                  'tools': [
                    {
                      'functionDeclarations': NoesisAgentTools.googleRestFunctionDeclarations,
                    }
                  ],
                  'generationConfig': {
                    'temperature': temperature,
                    'maxOutputTokens': 8192,
                  },
                }),
              )
              .timeout(const Duration(seconds: 45));

          if (resp.statusCode != 200) {
            lastError = Exception('Erro Google REST ($mod / status ${resp.statusCode})');
            if (resp.statusCode == 400 || resp.statusCode == 401 || resp.statusCode == 403) {
              throw lastError;
            }
            break;
          }

          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final candidate = (data['candidates'] as List?)?.firstOrNull as Map<String, dynamic>?;
          if (candidate == null) break;
          final content = candidate['content'] as Map<String, dynamic>?;
          final parts = (content?['parts'] as List?) ?? [];
          if (parts.isEmpty) break;

          final functionCalls = <Map<String, dynamic>>[];
          final textBuffer = StringBuffer();

          for (final rawPart in parts) {
            if (rawPart is! Map<String, dynamic>) continue;
            if (rawPart['thought'] == true) continue;
            if (rawPart['functionCall'] is Map<String, dynamic>) {
              functionCalls.add(rawPart['functionCall'] as Map<String, dynamic>);
            } else if (rawPart['text'] is String) {
              textBuffer.write(rawPart['text'] as String);
            }
          }

          final textChunk = textBuffer.toString().trim();
          if (textChunk.isNotEmpty) {
            lastReply = textChunk;
          }

          if (functionCalls.isEmpty) {
            // Checa eventuais tags <noesis_action> ou intenção não executada
            if (executedTools.isEmpty && lastReply.contains('<noesis_action>')) {
              final extracted = await _extractAndExecuteAction(
                lastReply,
                userMessage,
                attachmentContext: attachmentContext,
              );
              lastReply = extracted.reply;
              for (final a in extracted.actions) {
                executedTools.add(
                  ExecutedToolResult(
                    name: a.name,
                    parameters: a.parameters,
                    status: a.status,
                    summary: a.summary,
                    responsePayload: const {'status': 'success'},
                    data: a.data,
                  ),
                );
              }
            }

            if (executedTools.isEmpty) {
              final recovered = await NoesisAgentTools.tryRecoverUnexecutedIntent(
                userMessage: userMessage,
                aiReply: lastReply,
                attachmentContext: attachmentContext,
                generateQuiz: _agentQuizCallback,
                generateFlashcards: _agentFlashcardsCallback,
                generateRoadmap: _agentRoadmapCallback,
              );
              if (recovered != null) {
                executedTools.add(recovered);
              }
            }

            if (lastReply.isEmpty && executedTools.isNotEmpty) {
              lastReply = executedTools.map((e) => '- ✅ **${e.summary}**').join('\n');
            }
            if (lastReply.isNotEmpty) {
              return (reply: lastReply, executedTools: executedTools);
            }
            break;
          }

          contents.add({
            'role': 'model',
            'parts': parts,
          });

          final responseParts = <Map<String, dynamic>>[];
          for (final fc in functionCalls) {
            final name = fc['name']?.toString() ?? '';
            final rawArgs = fc['args'];
            final args = rawArgs is Map<String, dynamic>
                ? rawArgs
                : (rawArgs is Map ? Map<String, dynamic>.from(rawArgs) : <String, dynamic>{});

            final toolResult = await NoesisAgentTools.executeTool(
              name: name,
              args: args,
              userMessage: userMessage,
              attachmentContext: attachmentContext,
              generateQuiz: _agentQuizCallback,
              generateFlashcards: _agentFlashcardsCallback,
              generateRoadmap: _agentRoadmapCallback,
            );
            if (name != 'inspect_account_data' || toolResult.status == 'failed') {
              executedTools.add(toolResult);
            }
            responseParts.add({
              'functionResponse': {
                'name': name,
                'response': toolResult.responsePayload,
              }
            });
          }

          contents.add({
            'role': 'user',
            'parts': responseParts,
          });
        }
      } catch (e) {
        if (e is Exception) {
          lastError = e;
          final lower = e.toString().toLowerCase();
          if (lower.contains('status 400') ||
              lower.contains('status 401') ||
              lower.contains('status 403') ||
              lower.contains('api key not valid')) {
            rethrow;
          }
        } else {
          lastError = Exception('Erro Google REST ($mod): $e');
        }
      }

      if (mIdx < candidateModels.length - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    }

    throw lastError ?? Exception('Falha ao conectar ao Google Gemini.');
  }

  // ---------------------------------------------------------------------------
  // MOTOR COGNITIVO AUTÔNOMO (EXECUÇÃO LOCAL & FALLBACK INTELIGENTE)
  // ---------------------------------------------------------------------------
  static Future<AgentChatResult> _processAutonomousAgent(
    String message, {
    String? attachmentContext,
  }) async {
    final lower = message.toLowerCase().trim();
    final actions = <AgentAction>[];

    // 0. Revisar / Analisar Anexos ou Itens da Conta
    if (attachmentContext != null &&
        attachmentContext.trim().isNotEmpty &&
        (lower.contains('revis') ||
            lower.contains('analis') ||
            lower.contains('resum') ||
            lower.contains('o que') ||
            lower.contains('expli') ||
            lower.contains('corr'))) {
      final preview = attachmentContext.trim();
      final snippet = preview.length > 1400 ? '${preview.substring(0, 1400)}...' : preview;
      final reply = '''
Analisei o material anexado para você! 📎

### Síntese & Revisão do Conteúdo
```text
$snippet
```

Posso **gerar flashcards**, **criar um simulado** com base exatamente nesse conteúdo, ou **salvar as conclusões em um Caderno de Estudos**. O que prefere fazer agora?
''';
      return AgentChatResult(reply: reply);
    }

    // 0.5. Ler / Listar / Inspecionar dados reais da conta
    if ((lower.contains('quais') ||
            lower.contains('meus') ||
            lower.contains('minhas') ||
            lower.contains('o que tenho') ||
            lower.contains('listar') ||
            lower.contains('ver meus') ||
            lower.contains('revisar conta') ||
            lower.contains('resumo da conta')) &&
        !lower.contains('crie') &&
        !lower.contains('criar') &&
        !lower.contains('agend') &&
        !lower.contains('exclu') &&
        !lower.contains('remov')) {
      final inspected = await NoesisAgentTools.executeTool(
        name: 'inspect_account_data',
        args: const {'scope': 'all'},
        userMessage: message,
        attachmentContext: attachmentContext,
        generateQuiz: _agentQuizCallback,
        generateFlashcards: _agentFlashcardsCallback,
        generateRoadmap: _agentRoadmapCallback,
      );
      final data = inspected.responsePayload['data'] as Map<String, dynamic>? ?? {};
      final cal = (data['calendar'] as List?) ?? [];
      final sess = (data['sessions'] as List?) ?? [];
      final quizzes = (data['quizzes'] as List?) ?? [];
      final decks = (data['flashcards'] as List?) ?? [];
      final notebooks = (data['notebooks'] as List?) ?? [];
      final roadmaps = (data['roadmaps'] as List?) ?? [];
      final goal = data['weekly_goal'] as Map<String, dynamic>?;

      final reply = '''
Aqui está o panorama atualizado da sua conta **Noesis**:

- 🎯 **Meta Semanal:** ${goal?['studied_this_week_formatted'] ?? '0m'} estudados de ${goal?['goal_formatted'] ?? '25h'}
- 📅 **Calendário:** ${cal.length} compromisso(s) ativo(s)
- ⏱️ **Diário de Estudos:** ${sess.length} sessão(ões) recente(s)
- 📝 **Simulados:** ${quizzes.length} simulado(s) salvo(s)
- 🎴 **Flashcards:** ${decks.length} baralho(s) ativo(s)
- 📓 **Cadernos:** ${notebooks.length} caderno(s)
- 🗺️ **Trilhas:** ${roadmaps.length} trilha(s)

Se quiser detalhes ou editar/remover qualquer item específico, é só me dizer!
''';
      return AgentChatResult(reply: reply);
    }

    // 0.6. Meta Semanal
    if (lower.contains('meta semanal') || (lower.contains('meta') && lower.contains('hora'))) {
      final hourMatch = RegExp(r'(\d+)\s*h').firstMatch(lower);
      final h = hourMatch != null ? (int.tryParse(hourMatch.group(1)!) ?? 25) : 25;
      final exec = await NoesisAgentTools.executeTool(
        name: 'set_weekly_goal',
        args: {'hours': h},
        userMessage: message,
        attachmentContext: attachmentContext,
        generateQuiz: _agentQuizCallback,
        generateFlashcards: _agentFlashcardsCallback,
        generateRoadmap: _agentRoadmapCallback,
      );
      actions.addAll(_toAgentActions([exec]));
      return AgentChatResult(
        reply: 'Pronto! ✅ **${exec.summary}** atualizada com sucesso no seu Dashboard.',
        actions: actions,
      );
    }

    // 0.7. Remover / Excluir itens
    if (lower.contains('exclu') || lower.contains('remov') || lower.contains('apag') || lower.contains('cancel')) {
      String toolName = 'delete_calendar_event';
      if (lower.contains('simulado') || lower.contains('quiz')) {
        toolName = 'delete_quiz';
      } else if (lower.contains('caderno') || lower.contains('anota')) {
        toolName = 'delete_notebook_or_note';
      } else if (lower.contains('flashcard') || lower.contains('baralho')) {
        toolName = 'delete_flashcard_deck';
      } else if (lower.contains('trilha') || lower.contains('roadmap')) {
        toolName = 'delete_roadmap';
      } else if (lower.contains('sessão') || lower.contains('sessao') || lower.contains('diário') || lower.contains('diario')) {
        toolName = 'delete_study_session';
      }
      final exec = await NoesisAgentTools.executeTool(
        name: toolName,
        args: {'title_match': message, 'subject_match': message},
        userMessage: message,
        attachmentContext: attachmentContext,
        generateQuiz: _agentQuizCallback,
        generateFlashcards: _agentFlashcardsCallback,
        generateRoadmap: _agentRoadmapCallback,
      );
      actions.addAll(_toAgentActions([exec]));
      return AgentChatResult(
        reply: exec.status == 'completed'
            ? 'Feito! 🗑️ **${exec.summary}**.'
            : 'Não encontrei um item correspondente para remover. Informe o título exato ou anexe o item que deseja excluir.',
        actions: actions,
      );
    }

    // 0.8. Criar Caderno ou Anotação
    if ((lower.contains('caderno') || lower.contains('anotação') || lower.contains('anotacao') || lower.contains('nota')) &&
        (lower.contains('cri') || lower.contains('adicion') || lower.contains('salv') || lower.contains('ger'))) {
      final exec = await NoesisAgentTools.executeTool(
        name: 'create_notebook_or_note',
        args: {
          'notebook_title': 'Anotações Noesis AI',
          'subject': 'Estudos',
          'note_title': message.length > 60 ? '${message.substring(0, 60)}...' : message,
          'note_content': attachmentContext ?? message,
        },
        userMessage: message,
        attachmentContext: attachmentContext,
        generateQuiz: _agentQuizCallback,
        generateFlashcards: _agentFlashcardsCallback,
        generateRoadmap: _agentRoadmapCallback,
      );
      actions.addAll(_toAgentActions([exec]));
      return AgentChatResult(
        reply: 'Anotação salva! 📓 **${exec.summary}** já disponível na aba **Cadernos**.',
        actions: actions,
      );
    }

    // 0.9. Criar Trilha / Roadmap
    if ((lower.contains('trilha') || lower.contains('roadmap')) &&
        (lower.contains('cri') || lower.contains('ger') || lower.contains('mont'))) {
      final exec = await NoesisAgentTools.executeTool(
        name: 'create_roadmap',
        args: {'subject': 'Tecnologia & Segurança', 'goal': message},
        userMessage: message,
        attachmentContext: attachmentContext,
        generateQuiz: _agentQuizCallback,
        generateFlashcards: _agentFlashcardsCallback,
        generateRoadmap: _agentRoadmapCallback,
      );
      actions.addAll(_toAgentActions([exec]));
      return AgentChatResult(
        reply: 'Trilha criada! 🗺️ **${exec.summary}** já está disponível na aba **Trilhas**.',
        actions: actions,
      );
    }

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

      final summary = 'Simulado criado · $count questões · $topic';
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
        summary: 'Baralho criado · ${flashcards.length} cartões · $deckTitle',
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
      final summary = 'Evento agendado · $timeStr · $title';
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

      final summary = 'Sessão registrada · ${_formatDuration(minutes)} em $subject';
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
  static Future<AgentChatResult> _extractAndExecuteAction(
    String rawText,
    String userMessage, {
    String? attachmentContext,
  }) async {
    final actions = <AgentAction>[];
    String cleanReply = rawText;

    final regex = RegExp(r'<noesis_action>([\s\S]*?)<\/noesis_action>');
    final matches = regex.allMatches(rawText).toList();

    if (matches.isNotEmpty) {
      cleanReply = rawText.replaceAll(regex, '').trim();

      for (final match in matches) {
        final jsonBlock = match.group(1)?.trim() ?? '';
        try {
          final parsed = jsonDecode(jsonBlock) as Map<String, dynamic>;
          final actionName = parsed['action'] as String? ?? '';
          final rawData = parsed['data'];
          final data = rawData is Map<String, dynamic>
              ? rawData
              : (rawData is Map ? Map<String, dynamic>.from(rawData) : parsed);

          if (actionName.isEmpty) continue;
          final executed = await NoesisAgentTools.executeTool(
            name: actionName,
            args: data,
            userMessage: userMessage,
            attachmentContext: attachmentContext,
            generateQuiz: _agentQuizCallback,
            generateFlashcards: _agentFlashcardsCallback,
            generateRoadmap: _agentRoadmapCallback,
          );
          if (actionName != 'inspect_account_data' || executed.status == 'failed') {
            actions.add(
              AgentAction(
                name: executed.name,
                parameters: executed.parameters,
                status: executed.status,
                summary: executed.summary,
                data: executed.data,
              ),
            );
          }
        } catch (e) {
          debugPrint('Erro ao parsear ação do LLM: $e');
        }
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
    int timeoutSeconds = 45,
  }) async {
    final key = apiKey?.trim() ?? '';
    final cleanModel = normalizeModel(provider, model);

    if (provider == 'google') {
      return await _executeGoogleRest(
        prompt: prompt,
        systemInstruction: systemInstruction,
        timeoutSeconds: timeoutSeconds,
      );
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
      ).timeout(Duration(seconds: timeoutSeconds));

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
    ).timeout(Duration(seconds: timeoutSeconds));

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
    int timeoutSeconds = 45,
    bool jsonMode = false,
    bool allowModelFallback = true,
  }) async {
    final key = apiKey?.trim() ?? '';
    var primaryMod = normalizeModel('google', model);

    // Se o modelo selecionado ainda não está na lista operacional da conta, tenta sincronizar os disponíveis
    if (allowModelFallback &&
        key.isNotEmpty &&
        (_operationalKeyCache != key ||
            operationalGoogleModels.isEmpty ||
            !operationalGoogleModels.contains(primaryMod))) {
      final synced = await fetchOperationalGoogleModels(key);
      if (synced.models.isNotEmpty && !synced.models.contains(primaryMod)) {
        primaryMod = synced.models.first;
        model = primaryMod;
      }
    }

    final candidateModels = <String>[];
    if (operationalGoogleModels.isNotEmpty && _operationalKeyCache == key) {
      if (operationalGoogleModels.contains(primaryMod)) {
        candidateModels.add(primaryMod);
      }
      if (allowModelFallback) {
        for (final op in operationalGoogleModels) {
          if (!candidateModels.contains(op)) {
            candidateModels.add(op);
          }
        }
      }
    }
    if (candidateModels.isEmpty) {
      candidateModels.add(primaryMod);
    }

    final genConfig = <String, dynamic>{
      'temperature': temperature,
      'maxOutputTokens': 8192,
    };
    if (jsonMode) {
      genConfig['responseMimeType'] = 'application/json';
    }

    Exception? lastError;

    for (int i = 0; i < candidateModels.length; i++) {
      final mod = candidateModels[i];
      final endpoint = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$mod:generateContent?key=$key',
      );

      try {
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
            'generationConfig': genConfig,
          }),
        ).timeout(Duration(seconds: timeoutSeconds));

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final candidate = (data['candidates'] as List?)?.firstOrNull;
          if (candidate == null) continue;
          final parts = candidate['content']?['parts'] as List?;
          if (parts == null || parts.isEmpty) continue;
          final buffer = StringBuffer();
          for (final p in parts) {
            if (p is Map<String, dynamic>) {
              if (p['thought'] == true) continue;
              final txt = p['text'] as String?;
              if (txt != null) buffer.write(txt);
            }
          }
          final resultText = buffer.toString();
          if (resultText.trim().isNotEmpty) {
            if (mod != primaryMod) {
              debugPrint('Google REST fallback bem-sucedido usando $mod (primário $primaryMod indisponível).');
            }
            return resultText;
          }
          continue;
        }

        String apiMessage = 'status ${resp.statusCode}';
        try {
          final errJson = jsonDecode(resp.body);
          final parsedMsg = errJson['error']?['message'] as String?;
          if (parsedMsg != null && parsedMsg.trim().isNotEmpty) {
            apiMessage = 'status ${resp.statusCode}: $parsedMsg';
          }
        } catch (_) {}

        lastError = Exception('Erro Google REST ($mod / $apiMessage)');

        // Erros definitivos de autenticação/permissão não se beneficiam de trocar modelo
        if (resp.statusCode == 400 || resp.statusCode == 401 || resp.statusCode == 403) {
          throw lastError;
        }

        // Em 503 (sobrecarregado), 429 (rate limit), 404 (modelo legado) ou 5xx, tenta o próximo modelo
        if (i < candidateModels.length - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 450));
          continue;
        }
      } catch (e) {
        if (e is Exception) {
          lastError = e;
          final lower = e.toString().toLowerCase();
          if (lower.contains('status 400') ||
              lower.contains('status 401') ||
              lower.contains('status 403') ||
              lower.contains('api key not valid')) {
            rethrow;
          }
        } else {
          lastError = Exception('Erro Google REST ($mod): $e');
        }
        if (i < candidateModels.length - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 450));
          continue;
        }
      }
    }

    throw lastError ?? Exception('Erro Google REST: nenhum modelo Gemini disponível respondeu.');
  }

  // ---------------------------------------------------------------------------
  // BANCO DE QUESTÕES COGNITIVAS PARA MODO LOCAL
  // ---------------------------------------------------------------------------
  static List<Map<String, dynamic>> _generateAutonomousQuiz(
    String subject,
    String topic,
    int count,
    String difficulty, {
    String? examModelName,
    int startNumber = 1,
  }) {
    final lower = '$subject $topic'.toLowerCase();

    final examModel = ExamModelsCatalog.findByName(examModelName);
    final disciplines = examModel?.disciplinesForBatch(
      totalTarget: (startNumber - 1 + count).clamp(count, quizMaxQuestions),
      startNumber: startNumber,
      batchCount: count.clamp(1, quizMaxQuestions),
    );

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
      final safeCount = count.clamp(1, quizMaxQuestions);
      return List<Map<String, dynamic>>.generate(safeCount, (i) {
        final base = pool[i % pool.length];
        final disc = (disciplines != null && i < disciplines.length)
            ? disciplines[i]
            : (subject.trim().isNotEmpty ? subject.trim() : 'Segurança de Aplicações');
        return {
          ...base,
          'discipline': disc,
        };
      });
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

    return List<Map<String, dynamic>>.generate(count.clamp(1, quizMaxQuestions), (i) {
      final base = cryptoPool[(startNumber - 1 + i) % cryptoPool.length];
      final disc = (disciplines != null && i < disciplines.length)
          ? disciplines[i]
          : (subject.trim().isNotEmpty ? subject.trim() : topic);
      if (startNumber == 1 && i < cryptoPool.length) {
        return {
          ...base,
          'discipline': disc,
        };
      }
      return {
        ...base,
        'discipline': disc,
        'question': '[Simulado ${examModelName ?? topic} · Q${startNumber + i}] ${base['question']}',
      };
    });
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
  // GERADOR DE TRILHAS DE ESTUDO (ROADMAP) COM IA + FALLBACK LOCAL
  // ---------------------------------------------------------------------------
  static Future<StudyRoadmap> generateStudyRoadmap({
    required String goal,
    required String subject,
    String level = 'Intermediário',
    int estimatedWeeks = 4,
    int hoursPerWeek = 8,
    String? extraNotes,
  }) async {
    final cleanGoal = goal.trim().isEmpty ? 'Dominar $subject' : goal.trim();
    final cleanSubject = subject.trim().isEmpty ? 'Geral' : subject.trim();
    final safeWeeks = estimatedWeeks.clamp(1, 52);
    final safeHours = hoursPerWeek.clamp(1, 80);
    final key = apiKey?.trim() ?? '';
    var cleanModel = normalizeModel(provider, model);

    if (provider != 'custom' && key.isEmpty) {
      return _buildAutonomousRoadmap(
        goal: cleanGoal,
        subject: cleanSubject,
        level: level,
        estimatedWeeks: safeWeeks,
        hoursPerWeek: safeHours,
      );
    }

    if (provider == 'google' &&
        (operationalGoogleModels.isEmpty || _operationalKeyCache != key)) {
      final synced = await fetchOperationalGoogleModels(key);
      if (synced.models.isNotEmpty) {
        cleanModel = synced.models.contains(cleanModel) ? cleanModel : synced.models.first;
        model = cleanModel;
      }
    }

    final extraSection = (extraNotes != null && extraNotes.trim().isNotEmpty)
        ? '\nObservações / Prioridades do estudante:\n"""\n${extraNotes.trim()}\n"""\n'
        : '';

    final prompt = '''
Crie um Roadmap (Trilha de Estudos) completo, sequencial e prático em Português.
- Objetivo final: "$cleanGoal"
- Matéria / Área principal: "$cleanSubject"
- Nível atual: "$level"
- Prazo total estimado: $safeWeeks semanas (~$safeHours horas por semana)
$extraSection
Gere de 5 a 8 etapas progressivas (da base até a consolidação/prática).
Para CADA etapa, explique detalhadamente o que a pessoa vai aprender:
- "description": 2 a 3 frases objetivas explicando o propósito da etapa, a progressão didática e como o conteúdo se conecta ao objetivo final.
- "learning_objectives": lista de 3 a 4 objetivos claros começando com verbo no infinitivo (ex.: "Compreender...", "Aplicar...", "Diferenciar...") detalhando o que o aluno dominará ao concluir a etapa.
- "key_topics": lista de 4 a 6 conceitos/assuntos específicos essenciais daquela etapa.
- "practical_milestone": 1 meta prática verificável para validar que aprendeu (ex.: "Resolver 20 questões com 80% de acerto" ou "Produzir resumo comparativo...").
- "subtopics": lista de 3 a 5 subtarefas acionáveis de checklist.
- "resources": 1 a 3 sugestões de materiais ou exercícios práticos.

RETORNE ESTRITAMENTE um array JSON com 1 objeto neste formato (sem Markdown extra):
[
  {
    "title": "Título conciso da trilha",
    "steps": [
      {
        "title": "Etapa 1: Nome claro da etapa",
        "description": "Explicação detalhada do que será aprendido e por que essa etapa vem neste momento.",
        "estimated_hours": 6,
        "learning_objectives": ["Compreender o conceito X...", "Aplicar o método Y na prática..."],
        "key_topics": ["Conceito A", "Conceito B", "Fórmula/Regra C", "Estudo de Caso D"],
        "practical_milestone": "Resolver 15 exercícios comentados atingindo pelo menos 80% de acertos.",
        "subtopics": ["Subtópico 1", "Subtópico 2", "Subtópico 3"],
        "resources": ["Tipo de material ou exercício sugerido"]
      }
    ]
  }
]
''';

    String raw = '';
    if (provider == 'google') {
      try {
        final generModel = GenerativeModel(
          model: cleanModel,
          apiKey: key,
          generationConfig: GenerationConfig(
            temperature: 0.35,
            maxOutputTokens: 8192,
            responseMimeType: 'application/json',
          ),
        );
        final response = await generModel
            .generateContent([Content.text(prompt)])
            .timeout(const Duration(seconds: 60));
        raw = response.text ?? '';
      } catch (_) {
        raw = '';
      }
      if (raw.trim().isEmpty) {
        raw = await _executeGoogleRest(
          prompt: prompt,
          systemInstruction: 'Retorne estritamente um array JSON válido contendo 1 objeto com title e steps.',
          timeoutSeconds: 60,
          jsonMode: true,
          allowModelFallback: true,
        );
      }
    } else {
      raw = await _executeRawPrompt(
        prompt: prompt,
        systemInstruction: 'Retorne estritamente um array JSON válido contendo 1 objeto com title e steps.',
        timeoutSeconds: 60,
      );
    }

    if (raw.trim().isNotEmpty) {
      try {
        final parsedList = await compute(_parseJsonPayload, raw);
        if (parsedList.isNotEmpty) {
          final first = parsedList.first;
          final rawSteps = (first['steps'] is List) ? first['steps'] as List : parsedList;
          final steps = <RoadmapStep>[];
          for (int i = 0; i < rawSteps.length; i++) {
            final item = rawSteps[i];
            if (item is Map) {
              steps.add(RoadmapStep.fromJson(Map<String, dynamic>.from(item), fallbackIndex: i));
            }
          }
          if (steps.isNotEmpty) {
            final now = DateTime.now();
            return StudyRoadmap(
              id: 'roadmap-${now.millisecondsSinceEpoch}',
              title: (first['title'] ?? cleanGoal).toString().trim(),
              goal: cleanGoal,
              subject: cleanSubject,
              level: level,
              estimatedWeeks: safeWeeks,
              steps: steps,
              createdAt: now,
              updatedAt: now,
            );
          }
        }
      } catch (e) {
        debugPrint('Erro ao parsear roadmap da IA: $e');
      }
    }

    return _buildAutonomousRoadmap(
      goal: cleanGoal,
      subject: cleanSubject,
      level: level,
      estimatedWeeks: safeWeeks,
      hoursPerWeek: safeHours,
    );
  }

  static StudyRoadmap _buildAutonomousRoadmap({
    required String goal,
    required String subject,
    required String level,
    required int estimatedWeeks,
    required int hoursPerWeek,
  }) {
    final now = DateTime.now();
    final totalHours = (estimatedWeeks * hoursPerWeek).clamp(8, 500);
    final perStep = (totalHours / 5).round().clamp(2, 60);

    return StudyRoadmap(
      id: 'roadmap-${now.millisecondsSinceEpoch}',
      title: goal.isNotEmpty ? goal : 'Trilha de $subject',
      goal: goal,
      subject: subject,
      level: level,
      estimatedWeeks: estimatedWeeks,
      createdAt: now,
      updatedAt: now,
      steps: [
        RoadmapStep(
          id: 'step-1-${now.millisecondsSinceEpoch}',
          title: '1. Diagnóstico e Fundamentos de $subject',
          description:
              'Nivelamento conceitual inicial para construir uma base sólida em $subject ($level) antes de avançar para tópicos densos.',
          estimatedHours: perStep,
          status: RoadmapStepStatus.doing,
          learningObjectives: [
            'Dominar a terminologia fundamental e os princípios organizadores de $subject',
            'Identificar suas principais lacunas iniciais por meio de questões diagnósticas',
            'Estruturar um resumo-base para consultas rápidas nas etapas seguintes',
          ],
          keyTopics: [
            'Conceitos basilares de $subject',
            'Vocabulário e convenções',
            'Leitura e interpretação inicial',
            'Mapa de incidência',
          ],
          practicalMilestone: 'Concluir 10 questões diagnósticas e anotar os 5 conceitos-chave no Caderno.',
          subtopics: [
            RoadmapSubtopic(id: 'sub-1a', title: 'Mapeamento de conceitos-chave de $subject'),
            const RoadmapSubtopic(id: 'sub-1b', title: 'Resumo base e vocabulário essencial'),
            const RoadmapSubtopic(id: 'sub-1c', title: 'Lista inicial de exercícios diagnósticos'),
          ],
          resources: const ['Caderno de resumo estruturado', '10 questões diagnósticas'],
        ),
        RoadmapStep(
          id: 'step-2-${now.millisecondsSinceEpoch}',
          title: '2. Núcleo Teórico e Estruturas Principais',
          description:
              'Aprofundamento sistemático nos pilares centrais de $subject, conectando regras, mecanismos e causas e consequências.',
          estimatedHours: perStep,
          learningObjectives: [
            'Explicar com clareza os mecanismos e leis centrais de $subject',
            'Relacionar diferentes frentes teóricas sem depender de memorização mecânica',
            'Transformar definições-chave em flashcards para retenção espaçada',
          ],
          keyTopics: [
            'Pilares de maior peso',
            'Relações de causa e efeito',
            'Modelagem conceitual',
            'Síntese ativa',
          ],
          practicalMilestone: 'Criar e revisar pelo menos 15 flashcards dos pilares teóricos principais.',
          subtopics: [
            const RoadmapSubtopic(id: 'sub-2a', title: 'Estudo guiado dos tópicos de maior peso'),
            const RoadmapSubtopic(id: 'sub-2b', title: 'Flashcards para fixação ativa (Active Recall)'),
          ],
          resources: const ['Baralho de Flashcards no Noesis', 'Anotações por tópico'],
        ),
        RoadmapStep(
          id: 'step-3-${now.millisecondsSinceEpoch}',
          title: '3. Resolução Guiada e Aplicações Práticas',
          description:
              'Transição da teoria para a prática dirigida: treino progressivo em situações reais e análise detalhada dos distratores.',
          estimatedHours: perStep,
          learningObjectives: [
            'Interpretar enunciados contextualizados e identificar exatamente o comando da questão',
            'Diagnosticar erros recorrentes e armadilhas típicas da área',
            'Ganhar velocidade e segurança na resolução de problemas aplicados',
          ],
          keyTopics: [
            'Resolução passo a passo',
            'Análise de distratores',
            'Caderno de erros',
            'Aplicações cotidianas',
          ],
          practicalMilestone: 'Completar um simulado temático atingindo pelo menos 75% de aproveitamento.',
          subtopics: [
            const RoadmapSubtopic(id: 'sub-3a', title: 'Bateria de exercícios por dificuldade crescente'),
            const RoadmapSubtopic(id: 'sub-3b', title: 'Caderno de erros e revisão das lacunas'),
          ],
          resources: const ['Simulado temático no Noesis'],
        ),
        RoadmapStep(
          id: 'step-4-${now.millisecondsSinceEpoch}',
          title: '4. Tópicos Avançados e Interdisciplinaridade',
          description:
              'Integração entre conteúdos de alta complexidade em $subject, lidando com cenários combinados e questões de alto rigor.',
          estimatedHours: perStep,
          learningObjectives: [
            'Combinar dois ou mais conceitos avançados na mesma resolução',
            'Evitar extrapolações e erros sutis de modelagem em níveis altos',
            'Consolidar tópicos críticos por revisão ativa antes da reta final',
          ],
          keyTopics: [
            'Questões interdisciplinares',
            'Casos de borda',
            'Análise crítica comparativa',
            'Gestão de tempo sob pressão',
          ],
          practicalMilestone: 'Resolver uma bateria avançada cronometrada e revisar 100% das questões erradas.',
          subtopics: [
            const RoadmapSubtopic(id: 'sub-4a', title: 'Casos avançados e questões interdisciplinares'),
            const RoadmapSubtopic(id: 'sub-4b', title: 'Revisão espaçada dos pontos críticos'),
          ],
          resources: const ['Simulado avançado cronometrado'],
        ),
        RoadmapStep(
          id: 'step-5-${now.millisecondsSinceEpoch}',
          title: '5. Consolidação Final e Simulado Completo',
          description:
              'Fechamento estratégico da trilha visando "$goal", com simulado completo, revisão da IA e ajuste fino dos últimos pontos.',
          estimatedHours: perStep,
          learningObjectives: [
            'Sustentar foco e ritmo de prova durante uma bateria completa com cronômetro',
            'Validar domínio global usando o comparativo e a Review da IA',
            'Executar plano cirúrgico de revisão final sobre as poucas lacunas restantes',
          ],
          keyTopics: [
            'Simulado completo',
            'Review pedagógica da IA',
            'Revisão de última milha',
            'Calibragem de ritmo',
          ],
          practicalMilestone: 'Finalizar simulado completo com tempo controlado e revisar o plano da IA.',
          subtopics: [
            const RoadmapSubtopic(id: 'sub-5a', title: 'Simulado completo com tempo controlado'),
            const RoadmapSubtopic(id: 'sub-5b', title: 'Revisão final da Review da IA'),
          ],
          resources: const ['Simulado completo no Noesis'],
        ),
      ],
    );
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
    return NoesisAgentTools.parseNaturalDateTime(text);
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
