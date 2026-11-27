import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'localization/agent_intent_keywords.dart';
import 'localization/noesis_l10n.dart';
import 'localization/noesis_locale_service.dart';
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

  throw FormatException(NoesisL10n.tr('Formato de JSON inesperado recebido.'));
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

  static String _validateCustomEndpoint(String rawBase) {
    final cleanBase = rawBase.trim().replaceAll(RegExp(r'/+$'), '');
    if (cleanBase.isEmpty) {
      throw Exception(NoesisL10n.tr('Informe a URL base do provedor personalizado.'));
    }
    final uri = Uri.tryParse(cleanBase);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw Exception(NoesisL10n.tr('URL base personalizada inválida.'));
    }
    final isLocalLoopback =
        uri.host == '127.0.0.1' || uri.host == 'localhost' || uri.host == '::1';
    if (uri.scheme != 'https' && !(uri.scheme == 'http' && isLocalLoopback)) {
      throw Exception(
        NoesisL10n.tr('Por segurança, provedores personalizados exigem HTTPS (ou HTTP apenas em localhost/127.0.0.1).'),
      );
    }
    return cleanBase.endsWith('/chat/completions')
        ? cleanBase
        : '$cleanBase/chat/completions';
  }

  /// Testa se um modelo individual responde com status 200 para a chave informada
  static Future<({bool isWorking, String? error})> probeModelOperational(String mod, String key) async {
    final cleanMod = normalizeModel('google', mod);
    try {
      final endpoint = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$cleanMod:generateContent',
      );
      final resp = await http.post(
        endpoint,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': key,
        },
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
        'https://generativelanguage.googleapis.com/v1beta/models',
      );
      final resp = await http
          .get(endpoint, headers: {'x-goog-api-key': apiKey})
          .timeout(const Duration(seconds: 10));
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
      lastError = results.firstWhere((r) => r.error != null, orElse: () => (model: '', isWorking: false, error: NoesisL10n.tr('Nenhum modelo respondeu.'))).error;
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
      throw Exception(NoesisL10n.tr('Informe a chave de API antes de testar.'));
    }
    if (mod.isEmpty && providerId != 'custom') {
      throw Exception(NoesisL10n.tr('Selecione ou informe o modelo.'));
    }

    if (providerId == 'google') {
      final endpoint = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$mod:generateContent',
      );
      final resp = await http.post(
        endpoint,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': key,
        },
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
          throw Exception(NoesisL10n.tr('Erro ao conectar com Google Gemini ({status}).', {'status': resp.statusCode}));
        }
      }
      return NoesisL10n.tr('Conexão OK com Google Gemini ({model})!', {'model': mod});
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
            {'role': 'user', 'content': 'Reply only OK.'}
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
          throw Exception(NoesisL10n.tr('Erro ao conectar com Anthropic ({status}).', {'status': resp.statusCode}));
        }
      }
      return NoesisL10n.tr('Conexão OK com Anthropic ({model})!', {'model': mod});
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
      apiUrl = _validateCustomEndpoint(urlBase);
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
          {'role': 'user', 'content': 'Reply only OK.'}
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
        throw Exception(
          NoesisL10n.tr(
            'Erro ao conectar com {provider} ({status}).',
            {'provider': providerId, 'status': resp.statusCode},
          ),
        );
      }
    }
    return NoesisL10n.tr('Conexão OK com {provider} ({model})!', {'provider': providerId, 'model': mod});
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
    throw Exception(NoesisL10n.tr('A IA retornou um lote vazio. Tente novamente em instantes.'));
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
          final userOpt = selectedIdx < options.length
              ? options[selectedIdx]
              : NoesisL10n.tr('Opção {index}', {'index': selectedIdx + 1});
          final rightOpt = correctIdx < options.length
              ? options[correctIdx]
              : NoesisL10n.tr('Opção {index}', {'index': correctIdx + 1});
          wrongDetails.add(
            NoesisL10n.tr(
              '- Q{num} [{topics}]: "{stem}"\n  Marcou: "{marked}" | Gabarito: "{correct}"',
              {
                'num': i + 1,
                'topics': sources.join(', '),
                'stem': shortStem,
                'marked': userOpt,
                'correct': rightOpt,
              },
            ),
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

    final aiLang = NoesisLocaleService.activeAiLanguageName;
    final prompt = NoesisL10n.tr(
      'Você é um mentor pedagógico especialista em exames do Aster Noesis.\n'
      'Analise o desempenho do estudante neste simulado e gere um feedback objetivo, estratégico e acionável no idioma **{aiLang}** (Markdown).\n'
      'IMPORTANTE: Todo o texto da análise, títulos e tópicos DEVE ser escrito em **{aiLang}**.\n\n'
      'DADOS DA SESSÃO:\n'
      '- Prova / Modelo: {exam} ({subject})\n'
      '- Questões avaliadas: {total} | Respondidas: {answered} | Acertos: {correct} ({accTotal}% do total, {accAnswered}% das respondidas) | Erros: {wrong} | Em branco: {blank}\n'
      '- Tempo decorrido: {mins}m {secs}s\n'
      '- Tópicos com acertos: {rightTopics}\n'
      '- Tópicos com erros/lacunas: {wrongTopics}\n\n'
      'QUESTÕES ERRADAS PELO ESTUDANTE:\n'
      '{wrongDetails}\n\n'
      'ESTRUTURA OBRIGATÓRIA DA RESPOSTA (seja direto, use bullets e negrito):\n'
      '### 1. Diagnóstico do Desempenho\n'
      '(Avalie precisão, ritmo de prova e impacto de erros ou itens em branco.)\n\n'
      '### 2. Pontos Fortes\n'
      '(O que o estudante já domina com base nos acertos.)\n\n'
      '### 3. Onde Você Mais Perdeu Pontos & Padrão de Erro\n'
      '(Explique objetivamente os conceitos/pegadinhas das questões erradas acima.)\n\n'
      '### 4. Plano Prático de Melhoria (Próximos Passos)\n'
      '(Liste 3 ações específicas de revisão e treino para elevar a nota no próximo simulado.)',
      {
        'aiLang': aiLang,
        'exam': examModelName ?? topic,
        'subject': subject,
        'total': total,
        'answered': answered,
        'correct': correct,
        'accTotal': accuracyTotal,
        'accAnswered': accuracyAnswered,
        'wrong': wrong,
        'blank': blank,
        'mins': elapsedSeconds ~/ 60,
        'secs': elapsedSeconds % 60,
        'rightTopics': rightTopics.isEmpty ? NoesisL10n.tr('Nenhum registrado') : rightTopics.take(8).join(', '),
        'wrongTopics': wrongTopics.isEmpty ? NoesisL10n.tr('Nenhum erro') : wrongTopics.take(8).join(', '),
        'wrongDetails': wrongDetails.isEmpty
            ? NoesisL10n.tr('Nenhum erro registrado nas questões respondidas!')
            : wrongDetails.join('\n'),
      },
    );

    try {
      final result = await _executeRawPrompt(
        prompt: prompt,
        systemInstruction: NoesisL10n.tr(
          'Você é um tutor especialista em preparação para provas e certificações. Responda apenas com a análise em Markdown limpo no idioma: {aiLang}.',
          {'aiLang': aiLang},
        ),
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
    buffer.writeln(NoesisL10n.tr('### 1. Diagnóstico Geral · {exam}', {'exam': examName}));
    buffer.writeln(NoesisL10n.tr('- **Aproveitamento global:** {correct}/{total} acertos (**{pct}%**).', {
      'correct': correct,
      'total': total,
      'pct': accuracyTotal,
    }));
    if (blank > 0) {
      buffer.writeln(NoesisL10n.tr('- **Precisão nas respondidas:** **{pct}%** ({answered} respondidas, {blank} em branco).', {
        'pct': accuracyAnswered,
        'answered': total - blank,
        'blank': blank,
      }));
    }
    buffer.writeln('');
    buffer.writeln(NoesisL10n.tr('### 2. Pontos Fortes'));
    if (rightTopics.isNotEmpty && correct > 0) {
      buffer.writeln(NoesisL10n.tr('- Bom domínio inicial em: **{topics}**.', {'topics': rightTopics.take(5).join(', ')}));
    } else {
      buffer.writeln(NoesisL10n.tr('- Ainda não há acertos suficientes para consolidar pontos fortes; revise os gabaritos comentados questão a questão.'));
    }
    buffer.writeln('');
    buffer.writeln(NoesisL10n.tr('### 3. Pontos de Melhoria'));
    if (wrong > 0 || blank > 0) {
      buffer.writeln(NoesisL10n.tr('- Priorize a revisão dos erros em: **{topics}**.', {'topics': wrongTopics.take(6).join(', ')}));
      buffer.writeln(NoesisL10n.tr('- Use o filtro **Erros** no comparativo acima e clique para inspecionar o raciocínio de cada distrator marcado.'));
    } else {
      buffer.writeln(NoesisL10n.tr('- Desempenho impecável neste bloco! Aumente o nível de profundidade ou avance para mais lotes.'));
    }
    return buffer.toString();
  }

  /// Gera uma revisão analítica longitudinal da IA sobre toda a utilização da conta
  /// no período filtrado (tempo, evolução em simulados, retenção em flashcards, trilhas e hábitos).
  static Future<({String headline, String markdown, bool generatedWithLlm})>
      generateAccountPerformanceReview({
    required String periodLabel,
    required int totalMinutes,
    required int previousPeriodMinutes,
    required int? minutesDeltaPct,
    required int sessionsCount,
    required int activeDaysCount,
    required int streakDays,
    required int examsCount,
    required int totalQuestions,
    required double? averageExamScore,
    required double? previousExamScore,
    required List<String> topSubjectsSummary,
    required int cardsReviewedInPeriod,
    required int retentionRatePct,
    required int cardsDueCount,
    required int notesUpdatedInPeriod,
    required int notesNeedingReview,
    required int roadmapProgressPct,
    required int insightsEarnedInPeriod,
    required String currentEloName,
  }) async {
    final hoursStr = (totalMinutes / 60.0).toStringAsFixed(1);
    final prevHoursStr = (previousPeriodMinutes / 60.0).toStringAsFixed(1);
    final avgScoreStr = averageExamScore != null ? '${averageExamScore.round()}%' : NoesisL10n.tr('sem simulados');
    final prevScoreStr = previousExamScore != null ? '${previousExamScore.round()}%' : NoesisL10n.tr('sem base anterior');
    final aiLang = NoesisLocaleService.activeAiLanguageName;

    final key = apiKey?.trim() ?? '';
    if (provider == 'custom' || key.isNotEmpty) {
      final prompt = NoesisL10n.tr(
        'Você é o mentor analítico do Noesis. Gere um review longitudinal claro e acionável em Markdown (estritamente no idioma: {aiLang}) avaliando o desempenho real deste estudante no período "{period}":\n\n'
        'MÉTRICAS CONSOLIDADAS DA CONTA:\n'
        '- Período analisado: {period}\n'
        '- Tempo total estudado: {mins}m ({hours}h) em {sessions} sessões · {activeDays} dias ativos · streak atual: {streak}d\n'
        '- Comparativo vs período anterior: {prevHours}h ({delta})\n'
        '- Simulados no período: {exams} provas · {questions} questões · acurácia média: {avg} (anterior: {prevAvg})\n'
        '- Matérias destacadas: {subjects}\n'
        '- Flashcards: {reviewed} revisados no período · retenção estimada {retention}% · {due} cartões pendentes\n'
        '- Cadernos: {notesUpdated} notas atualizadas no período · {notesReview} marcadas para revisão\n'
        '- Trilhas de estudo: {roadmapPct}% concluído\n'
        '- Economia & Liga: +{insights} Insights conquistados · Elo atual: {elo}\n\n'
        'Estruture exatamente em 4 seções curtas com `###`:\n'
        '### 1. Diagnóstico do Período\n'
        '### 2. Evolução ao Longo do Tempo\n'
        '### 3. Pontos de Atenção & Lacunas\n'
        '### 4. Plano Prático para os Próximos Dias\n'
        'Seja direto, cite os números reais e dê ações concretas.',
        {
          'aiLang': aiLang,
          'period': periodLabel,
          'mins': totalMinutes,
          'hours': hoursStr,
          'sessions': sessionsCount,
          'activeDays': activeDaysCount,
          'streak': streakDays,
          'prevHours': prevHoursStr,
          'delta': minutesDeltaPct != null
              ? '${minutesDeltaPct >= 0 ? '+' : ''}$minutesDeltaPct%'
              : NoesisL10n.tr('sem comparativo'),
          'exams': examsCount,
          'questions': totalQuestions,
          'avg': avgScoreStr,
          'prevAvg': prevScoreStr,
          'subjects': topSubjectsSummary.isEmpty
              ? NoesisL10n.tr('nenhuma registrada ainda')
              : topSubjectsSummary.join('; '),
          'reviewed': cardsReviewedInPeriod,
          'retention': retentionRatePct,
          'due': cardsDueCount,
          'notesUpdated': notesUpdatedInPeriod,
          'notesReview': notesNeedingReview,
          'roadmapPct': roadmapProgressPct,
          'insights': insightsEarnedInPeriod,
          'elo': currentEloName,
        },
      );
      try {
        final raw = await _executeRawPrompt(
          prompt: prompt,
          systemInstruction: NoesisL10n.tr(
            'Você é um analista pedagógico de alto desempenho do Noesis. Responda apenas em Markdown conciso e baseado nos dados fornecidos, estritamente no idioma: {aiLang}.',
            {'aiLang': aiLang},
          ),
          timeoutSeconds: 45,
        );
        if (raw.trim().isNotEmpty) {
          final headline = averageExamScore != null
              ? NoesisL10n.tr('{hours}h estudadas · Média {avg} em {period}', {
                  'hours': hoursStr,
                  'avg': avgScoreStr,
                  'period': periodLabel,
                })
              : NoesisL10n.tr('{hours}h estudadas em {sessions} sessões ({period})', {
                  'hours': hoursStr,
                  'sessions': sessionsCount,
                  'period': periodLabel,
                });
          return (headline: headline, markdown: raw.trim(), generatedWithLlm: true);
        }
      } catch (_) {}
    }

    // Fallback autônomo determinístico rico com os dados reais da conta
    final buffer = StringBuffer();
    buffer.writeln('### ${NoesisL10n.tr('1. Diagnóstico do Período')} ($periodLabel)');
    if (totalMinutes > 0) {
      final deltaText = minutesDeltaPct == null
          ? NoesisL10n.tr('primeiro recorte registrado')
          : (minutesDeltaPct >= 0
              ? NoesisL10n.tr('avanço de **+{pct}%** vs período anterior ({prev}h)', {'pct': minutesDeltaPct, 'prev': prevHoursStr})
              : NoesisL10n.tr('queda de **{pct}%** vs período anterior ({prev}h)', {'pct': minutesDeltaPct, 'prev': prevHoursStr}));
      buffer.writeln(
        NoesisL10n.tr(
          '- **Carga horária:** **{hours}h** ({mins} min) distribuídas em **{sessions} sessões** e **{days} dias ativos** ({delta}).',
          {
            'hours': hoursStr,
            'mins': totalMinutes,
            'sessions': sessionsCount,
            'days': activeDaysCount,
            'delta': deltaText,
          },
        ),
      );
    } else {
      buffer.writeln('- ${NoesisL10n.tr('Nenhuma sessão cronometrada ou registrada neste período ainda.')}');
    }
    if (examsCount > 0 && averageExamScore != null) {
      buffer.writeln(
        NoesisL10n.tr(
          '- **Simulados:** **{exams} simulado(s)** ({questions} questões) com média de **{avg}%**.',
          {'exams': examsCount, 'questions': totalQuestions, 'avg': averageExamScore.round()},
        ),
      );
    }
    buffer.writeln(
      NoesisL10n.tr(
        '- **Ritmo atual:** sequência de **{streak}d** e Elo **{elo}** (+{insights} Insights no período).',
        {'streak': streakDays, 'elo': currentEloName, 'insights': insightsEarnedInPeriod},
      ),
    );
    buffer.writeln('');

    buffer.writeln('### ${NoesisL10n.tr('2. Evolução ao Longo do Tempo')}');
    if (averageExamScore != null && previousExamScore != null) {
      final diffPts = (averageExamScore - previousExamScore).round();
      if (diffPts > 0) {
        buffer.writeln(
          NoesisL10n.tr(
            '- Sua precisão em simulados subiu **+{diff} p.p.** em comparação ao ciclo anterior (**{prev}% → {curr}%**).',
            {'diff': diffPts, 'prev': previousExamScore.round(), 'curr': averageExamScore.round()},
          ),
        );
      } else if (diffPts < 0) {
        buffer.writeln(
          NoesisL10n.tr(
            '- A média em simulados recuou **{diff} p.p.** (**{prev}% → {curr}%**); revise os erros recentes antes da próxima bateria.',
            {'diff': diffPts.abs(), 'prev': previousExamScore.round(), 'curr': averageExamScore.round()},
          ),
        );
      } else {
        buffer.writeln(
          NoesisL10n.tr('- Acurácia estável em **{avg}%** frente ao período anterior.', {'avg': averageExamScore.round()}),
        );
      }
    } else if (topSubjectsSummary.isNotEmpty) {
      buffer.writeln(
        NoesisL10n.tr('- Concentração principal de esforço: **{summary}**.', {'summary': topSubjectsSummary.take(3).join(' · ')}),
      );
    } else {
      buffer.writeln('- ${NoesisL10n.tr('Continue registrando sessões e simulados para formar sua série histórica de evolução.')}');
    }
    if (cardsReviewedInPeriod > 0 || roadmapProgressPct > 0) {
      buffer.writeln(
        NoesisL10n.tr(
          '- **Retenção ativa:** **{reviewed} flashcards** revisados (retenção de **{retention}%**) e **{pct}%** das trilhas concluídos.',
          {'reviewed': cardsReviewedInPeriod, 'retention': retentionRatePct, 'pct': roadmapProgressPct},
        ),
      );
    }
    buffer.writeln('');

    buffer.writeln('### ${NoesisL10n.tr('3. Pontos de Atenção & Lacunas')}');
    if (cardsDueCount > 0) {
      buffer.writeln(
        NoesisL10n.tr('- Existem **{count} flashcards pendentes/difíceis** aguardando revisão espaçada.', {'count': cardsDueCount}),
      );
    }
    if (notesNeedingReview > 0) {
      buffer.writeln(
        NoesisL10n.tr('- Você marcou **{count} anotações** em Cadernos para revisão.', {'count': notesNeedingReview}),
      );
    }
    if (minutesDeltaPct != null && minutesDeltaPct < -10) {
      buffer.writeln('- ${NoesisL10n.tr('O volume de horas caiu frente ao ciclo anterior; blocos menores de 25–45 min ajudam a retomar a constância.')}');
    }
    if (cardsDueCount == 0 && notesNeedingReview == 0 && examsCount == 0) {
      buffer.writeln('- ${NoesisL10n.tr('Inclua pelo menos 1 simulado diagnóstico para medir acurácia objetiva além do tempo de estudo.')}');
    }
    buffer.writeln('');

    buffer.writeln('### ${NoesisL10n.tr('4. Plano Prático para os Próximos Dias')}');
    if (cardsDueCount > 0) {
      buffer.writeln(
        NoesisL10n.tr('- **Prioridade 1:** Zerar ao menos **{count} flashcards** pendentes hoje.', {'count': cardsDueCount.clamp(5, 25)}),
      );
    }
    if (examsCount == 0 || (averageExamScore != null && averageExamScore < 75)) {
      buffer.writeln('- ${NoesisL10n.tr('**Prioridade 2:** Fazer um simulado de **15 a 30 questões** focado na disciplina de menor nota e ler o review questão a questão.')}');
    } else if (averageExamScore != null) {
      buffer.writeln(
        NoesisL10n.tr(
          '- **Prioridade 2:** Manter sua média acima de **{avg}%** avançando uma etapa nas Trilhas ({pct}% concluídos).',
          {'avg': averageExamScore.round(), 'pct': roadmapProgressPct},
        ),
      );
    }
    if (notesNeedingReview > 0) {
      buffer.writeln('- ${NoesisL10n.tr('**Prioridade 3:** Revisar **1 a 2 notas** sinalizadas nos Cadernos para fixar os conceitos-chave.')}');
    }

    final headline = examsCount > 0 && averageExamScore != null
        ? NoesisL10n.tr('{hours}h estudadas · Média {avg}% ({period})', {
            'hours': hoursStr,
            'avg': averageExamScore.round(),
            'period': periodLabel,
          })
        : NoesisL10n.tr('{hours}h em {sessions} sessões ({period})', {
            'hours': hoursStr,
            'sessions': sessionsCount,
            'period': periodLabel,
          });

    return (
      headline: headline,
      markdown: buffer.toString(),
      generatedWithLlm: false,
    );
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
        ? NoesisL10n.tr(
            'MODELO OFICIAL DE PROVA SELECIONADO: {exam}\n'
            'Siga rigorosamente os requisitos, estilo de enunciado, arquitetura de distratores, quantidade de alternativas e diretrizes do guia oficial abaixo:\n'
            '"""\n{blueprint}\n"""\n',
            {
              'exam': examModelName ?? topic,
              'blueprint': examBlueprintText.trim(),
            },
          )
        : '';

    final referenceSection = hasReference
        ? NoesisL10n.tr(
            'MATERIAIS DE ESTUDO ANEXADOS PELO USUÁRIO (FLASHCARDS, CADERNOS E/OU APOSTILAS — BASE PRIORITÁRIA):\n'
            'Utilize prioritariamente os conceitos, definições, anotações e exemplos dos materiais anexados abaixo para formular as questões, distratores plausíveis e explicações (mantendo o estilo/formato do modelo de prova escolhido):\n'
            '"""\n{reference}\n"""\n',
            {'reference': referenceDocumentText.trim()},
          )
        : '';

    final antiDupSection = avoidTopicsSummary != null
        ? NoesisL10n.tr(
            '\nNÃO REPITA cenários ou perguntas equivalentes às já criadas anteriormente neste simulado:\n[{topics}]\n',
            {'topics': avoidTopicsSummary},
          )
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

    final aiLang = NoesisLocaleService.activeAiLanguageName;
    final prompt = NoesisL10n.tr(
      'Você é o examinador sênior do Aster Noesis. Crie um lote de questões para um simulado de alto nível sobre "{subject} - {topic}".\n'
      'IDIOMA DE SAÍDA OBRIGATÓRIO: {aiLang} (com exceção de provas específicas de língua estrangeira abaixo).\n'
      'Dificuldade: {difficulty}.\n'
      'Lote {batchIndex} (questões {startNumber} a {endNumber} de um total de {totalTarget}).\n'
      'QUANTIDADE EXATA DESTE LOTE: {batchCount} questões.\n'
      '{extraSections}\n'
      'INSTRUÇÕES DE FORMATO E SEPARAÇÃO DE DISCIPLINAS:\n'
      '- Respeite a DIVISÃO SEQUENCIAL DE DISCIPLINAS acima (se definida): NUNCA misture matérias aleatoriamente nem alterne disciplinas fora da sequência oficial do caderno. Cada objeto do array DEVE preencher "discipline" exatamente com a disciplina correspondente àquela questão.\n'
      '- Se o modelo oficial especificar 3 alternativas (ex.: DELE, DELF, CFA), 4 alternativas (ex.: SAT, ACT, OAB, Unicamp, CompTIA, Azure, GCP, CCNA), 5 alternativas (ex.: ENEM, FUVEST, USMLE, ENARE, ENAM, GRE/LSAT) ou 2 alternativas (ex.: CEBRASPE Certo/Errado), respeite esse número exato no array "options" (padrão: 4 alternativas caso não haja especificação distinta).\n'
      '- Em provas de idiomas estrangeiros (DELE, DELF, Goethe, JLPT, HSK, IELTS, TOEFL, Cambridge, SAT, ACT, GRE, GMAT, LSAT, USMLE), redija o enunciado e opções no idioma autêntico da prova e forneça "explanation" didática detalhada no idioma do usuário ({aiLang}).\n'
      '- Separação limpa entre Texto de Apoio e Pergunta: sempre que a questão trouxer um excerto, caso clínico, situação-problema ou trecho literário/jornalístico antes da pergunta, coloque esse conteúdo em "supporting_text" (e a referência bibliográfica em "source_citation", ex.: "Fonte: ..."), deixando em "question" APENAS a pergunta/enunciado objetivo final. Caso a questão não possua texto de apoio separado, deixe "supporting_text" e "source_citation" como strings vazias ("").\n'
      '- NÃO escreva rótulos artificiais como "Texto-base:" ou "Comando:" no início das frases. NÃO use fórmulas LaTeX entre cifrões nem comandos com barra invertida — use texto simples e símbolos Unicode (10%, x², √2, ×, ÷, ≤, ≥, →). Não repita letras ("A) ", "B) ") dentro das strings de "options". Pode usar negrito Markdown (**termo**) para destacar palavras-chave.\n'
      '- "rag_sources": inclua de 1 a 3 tags curtas citando o modelo/banca ou normas de referência usadas.\n\n'
      'RETORNE ESTRITAMENTE um array JSON válido com exatamente {batchCount} objetos no seguinte formato (sem Markdown extra):\n'
      '[\n'
      '  {\n'
      '    "discipline": "{defaultDiscipline}",\n'
      '    "supporting_text": "Context passage or scenario (or empty string if none).",\n'
      '    "source_citation": "Source: short reference (or empty string).",\n'
      '    "question": "Final question stem...",\n'
      '    "code_snippet": "Optional code, log, CLI output or table (or empty string)",\n'
      '    "options": ["Option A", "Option B", "Option C", "Option D"],\n'
      '    "correct_index": 0,\n'
      '    "explanation": "Detailed explanation of the right answer and why each distractor is wrong.",\n'
      '    "rag_sources": ["{sourceTag}", "{defaultDiscipline}"]\n'
      '  }\n'
      ']',
      {
        'subject': subject,
        'topic': topic,
        'aiLang': aiLang,
        'difficulty': difficulty,
        'batchIndex': batchIndex,
        'startNumber': startNumber,
        'endNumber': startNumber + batchCount - 1,
        'totalTarget': totalTarget,
        'batchCount': batchCount,
        'extraSections': '$sectionDirective$blueprintSection$referenceSection$antiDupSection',
        'defaultDiscipline': defaultDiscipline,
        'sourceTag': examModelName ?? subject,
      },
    );

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

    final aiLang = NoesisLocaleService.activeAiLanguageName;
    final refBlock = contextNotes != null && contextNotes.isNotEmpty
        ? NoesisL10n.tr('Material de Referência / Anotações:\n"""\n{notes}\n"""', {'notes': contextNotes})
        : '';
    final prompt = NoesisL10n.tr(
      'Gere um conjunto de {count} FLASHCARDS DE ESTUDO COGNITIVO sobre o tema específico:\n'
      'Idioma de saída obrigatório (front, back e tags): {aiLang}\n'
      'Matéria: "{subject}"\n'
      'Tema Específico: "{topic}"\n'
      'Dificuldade: "{difficulty}"\n'
      '{ref}\n\n'
      'Diretrizes pedagógicas para os Flashcards:\n'
      '1. "front": Pergunta desafiadora, conceito-chave, problema arquitetural ou termo técnico que exija recuperação ativa de memória (Active Recall).\n'
      '2. "back": Explicação clara, didática, precisa e técnica, destacando o \'porquê\', analogias ou regras de ouro mnemônicas.\n'
      '3. "tags": Lista de 2 ou 3 palavras-chave sobre o conteúdo.\n\n'
      'RETORNE ESTRITAMENTE um array JSON no seguinte formato (sem Markdown extra, apenas o array JSON válido):\n'
      '[\n'
      '  {\n'
      '    "front": "Question or concept for the front of the card",\n'
      '    "back": "Clear didactic explanation for the back",\n'
      '    "tags": ["{subject}", "{topic}"]\n'
      '  }\n'
      ']',
      {
        'count': count,
        'aiLang': aiLang,
        'subject': subject,
        'topic': topic,
        'difficulty': difficulty,
        'ref': refBlock,
      },
    );

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
          title: baseTitle.isNotEmpty ? baseTitle : NoesisL10n.tr('Novo Baralho'),
          subject: baseSubject.isNotEmpty ? baseSubject : NoesisL10n.tr('Geral'),
          description: NoesisL10n.tr('Baralho com {count} cartões.', {'count': cards.length}),
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

    final aiLang = NoesisLocaleService.activeAiLanguageName;
    final resolvedSubject = baseSubject.isNotEmpty ? baseSubject : NoesisL10n.tr('Geral');
    final prompt = NoesisL10n.tr(
      'Você é um especialista em pedagogia e organização cognitiva de flashcards (idioma: {aiLang}).\n'
      'Temos um conjunto de {total} flashcards com o tema geral "{title}" ({subject}).\n'
      'O usuário quer dividir este conjunto em baralhos menores com aproximadamente {target} cartões cada (totalizando cerca de {decksCount} baralhos temáticos).\n'
      'Analise os tópicos e separe-os em {decksCount} baralhos temáticos específicos, coesos e bem estruturados.\n\n'
      'Para cada baralho:\n'
      '- "title": Título temático específico, claro e profissional (ex: "{title} - Part 1", "{title} - Part 2").\n'
      '- "subject": Matéria ou disciplina refinada.\n'
      '- "description": Breve descrição pedagógica do foco deste baralho.\n'
      '- "color_hex": Código hexadecimal de cor (ex: "7C6CF0", "4EBA88", "F5A623", "FF7A90", "4A6BF5", "38B6FF").\n'
      '- "card_indices": Array com os números dos índices inteiros (0 a {maxIdx}) dos cartões pertencentes a este baralho. Todos os índices devem ser atribuídos.\n\n'
      'Cards:\n[\n{summaries}\n]\n\n'
      'RETORNE ESTRITAMENTE um array JSON no formato:\n'
      '[\n'
      '  {\n'
      '    "title": "Deck title",\n'
      '    "subject": "Subject",\n'
      '    "description": "Short description...",\n'
      '    "color_hex": "7C6CF0",\n'
      '    "card_indices": [0, 1, 2]\n'
      '  }\n'
      ']',
      {
        'aiLang': aiLang,
        'total': cards.length,
        'title': baseTitle,
        'subject': resolvedSubject,
        'target': cleanTarget,
        'decksCount': targetDecks,
        'maxIdx': sampleCards.length - 1,
        'summaries': summaries,
      },
    );

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
        final description = (item['description'] as String?)?.trim() ?? NoesisL10n.tr('Sub-baralho temático organizado por IA.');
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
          final fallbackPartTitle = NoesisL10n.tr(
            '{title} · Parte {part}',
            {'title': baseTitle, 'part': '${i + 1}'},
          );
          resultDecks.add(FlashcardDeck(
            id: 'deck-ai-${DateTime.now().millisecondsSinceEpoch}-$i',
            title: title.isNotEmpty ? title : fallbackPartTitle,
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
          title: baseTitle.isNotEmpty ? baseTitle : NoesisL10n.tr('Novo Baralho'),
          subject: baseSubject.isNotEmpty ? baseSubject : NoesisL10n.tr('Geral'),
          description: NoesisL10n.tr(
            'Baralho com {count} cartões.',
            {'count': '${cards.length}'},
          ),
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
    final secKw = NoesisL10n.tr('segurança', null, 'br');
    final criptoKw = NoesisL10n.tr('criptografia', null, 'br');
    if (AgentIntentKeywords.languageSubjectMarkers.any((k) => lowerTitle.contains(k) || lowerSubject.contains(k))) {
      themeSuffixes = [
        NoesisL10n.tr('Fundamentos & Estruturas Básicas'),
        NoesisL10n.tr('Tempos Verbais & Construções'),
        NoesisL10n.tr('Expressões, Conectivos & Vocabulário'),
        NoesisL10n.tr('Prática Avançada & Nuances'),
        NoesisL10n.tr('Revisão Geral & Fixação'),
        NoesisL10n.tr('Verbos Modais & Fraseais'),
        NoesisL10n.tr('Leitura & Interpretação Contextual'),
        NoesisL10n.tr('Conversação & Situações Cotidianas'),
      ];
    } else if (lowerTitle.contains(secKw) || lowerTitle.contains('cripto') || lowerSubject.contains(secKw) || lowerSubject.contains(criptoKw)) {
      themeSuffixes = [
        NoesisL10n.tr('Criptografia & Algoritmos Essenciais'),
        NoesisL10n.tr('Segurança de Redes & Protocolos (TLS/IPsec)'),
        NoesisL10n.tr('Controle de Acesso, Autenticação & IAM'),
        NoesisL10n.tr('Ameaças, Vulnerabilidades & Resposta a Incidentes'),
        NoesisL10n.tr('Governança, Riscos & Conformidade'),
      ];
    } else if (lowerTitle.contains('rede') || lowerSubject.contains('redes')) {
      themeSuffixes = [
        NoesisL10n.tr('Modelo OSI & Camada de Rede'),
        NoesisL10n.tr('Protocolos de Transporte & Roteamento (TCP/UDP/BGP)'),
        NoesisL10n.tr('Serviços de Aplicação (DNS, HTTP, DHCP)'),
        NoesisL10n.tr('Infraestrutura & Resolução de Problemas'),
      ];
    } else if (lowerTitle.contains('devops') || lowerTitle.contains('cloud') || lowerTitle.contains('aws') || lowerSubject.contains('cloud')) {
      themeSuffixes = [
        NoesisL10n.tr('Arquitetura Cloud & Computação (EC2, Lambda)'),
        NoesisL10n.tr('Armazenamento, Bancos de Dados & S3'),
        NoesisL10n.tr('Redes Virtuais & Segurança (VPC, IAM)'),
        NoesisL10n.tr('CI/CD, Monitoramento & Infraestrutura como Código'),
      ];
    } else {
      themeSuffixes = [
        NoesisL10n.tr('Conceitos Fundamentais'),
        NoesisL10n.tr('Aplicações & Métodos Práticos'),
        NoesisL10n.tr('Tópicos Avançados & Casos Específicos'),
        NoesisL10n.tr('Aprofundamento & Cenários Complexos'),
        NoesisL10n.tr('Revisão & Fixação Cognitiva'),
      ];
    }

    for (int i = 0; i < numDecks; i++) {
      final start = i * chunkSize;
      if (start >= cards.length) break;
      final end = (start + chunkSize).clamp(0, cards.length);
      final subList = cards.sublist(start, end);
      if (subList.isEmpty) continue;

      final partNum = i + 1;
      final suffix = i < themeSuffixes.length
          ? themeSuffixes[i]
          : NoesisL10n.tr('Módulo {part}', {'part': '$partNum'});
      final title = numDecks <= 5
          ? '$baseTitle · $suffix'
          : NoesisL10n.tr(
              '{title} · Parte {part}: {suffix}',
              {'title': baseTitle, 'part': '$partNum', 'suffix': suffix},
            );

      decks.add(
        FlashcardDeck(
          id: 'deck-auto-${DateTime.now().millisecondsSinceEpoch}-$i',
          title: title,
          subject: baseSubject.isNotEmpty ? baseSubject : NoesisL10n.tr('Geral'),
          description: NoesisL10n.tr(
            'Módulo de estudo focado em {suffix} ({count} cartões).',
            {'suffix': suffix, 'count': '${subList.length}'},
          ),
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
        final systemInstruction = NoesisL10n.tr(
          'Você é um assistente especialista em pedagogia, revisão gramatical e formatação Markdown para o aplicativo Noesis.\n'
          'Sua missão é organizar, enriquecer a legibilidade e formatar com maestria as anotações de estudo do estudante mantendo 100% DO CONTEÚDO ORIGINAL.\n'
          'Preserve o idioma das anotações do usuário (idioma ativo do app: {aiLang}).\n'
          'DIRETRIZES CRÍTICAS E OBRIGATÓRIAS:\n'
          '1. NUNCA RESUMA, NUNCA CORTE, NUNCA ABREVIE E NUNCA APAGUE NENHUM PARÁGRAFO OU FRASE. É estritamente proibido omitir qualquer conteúdo fornecido pelo usuário. A totalidade absoluta do texto deve estar presente na resposta.\n'
          '2. Preserve e mantenha na íntegra todos os blocos de código (ex: ```bash, ```python, etc.), comandos, parâmetros e exemplos técnicos sem nenhuma modificação no código.\n'
          '3. PRESERVE estritamente quaisquer URLs, links de referência [texto](url) e imagens markdown ![legenda](url) que o usuário já tenha inserido.\n'
          '4. Corrija pontuação, concordância e erros gramaticais/ortográficos no texto explicativo.\n'
          '5. Estruture em seções lógicas com títulos e subtítulos (#, ##, ###), marcadores (- ou *) e negritos em termos essenciais (**conceito**).\n'
          '6. Retorne EXCLUSIVAMENTE o conteúdo formatado em Markdown, sem nenhuma introdução, saudação, comentário prévio ou notas de encerramento.',
          {'aiLang': NoesisLocaleService.activeAiLanguageName},
        );

        final prompt = NoesisL10n.tr(
          'Por favor, formate e estruture as seguintes anotações de estudo na íntegra, mantendo o idioma original (usuário: {aiLang}), sem resumir ou omitir nenhuma linha (Matéria/Contexto: {subject}):\n\n{text}',
          {
            'aiLang': NoesisLocaleService.activeAiLanguageName,
            'subject': topicOrSubject ?? NoesisL10n.tr('Geral'),
            'text': clean,
          },
        );

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
  static String get _internalSafetyDirective => NoesisL10n.tr(
        'REGRA OBRIGATÓRIA DE INTERFACE: NUNCA mencione, cite ou exiba nomes internos de ferramentas/funções '
        '(como inspect_account_data, log_study_session, update_study_session, delete_study_session, '
        'schedule_calendar_event, update_calendar_event, delete_calendar_event, set_weekly_goal, '
        'create_quiz, delete_quiz, create_flashcards, update_flashcard_deck, delete_flashcard_deck, '
        'create_notebook_or_note, update_notebook_or_note, delete_notebook_or_note, '
        'create_roadmap, update_roadmap, delete_roadmap), '
        'nomes de tabelas ou colunas do banco de dados (como noesis_sessions, noesis_quizzes, '
        'noesis_calendar_events, noesis_flashcard_decks, noesis_study_notebooks, noesis_roadmaps, '
        'profiles, user_id, supabase), comandos SQL, IDs internos ou tags JSON/XML para o usuário. '
        'Descreva sempre seus recursos em linguagem natural amigável no idioma ativo do usuário ({aiLang}) '
        '(ex.: "{studyLog}", "{calendar}", "{quizzes}", "{flashcards}", "{notebooks}", "{roadmaps}").\n'
        'REGRA DE INTEGRIDADE: SÓ afirme que criou, agendou, alterou ou excluiu algo DEPOIS de executar '
        'realmente a ferramenta correspondente e receber status de sucesso. Nunca invente confirmações sem chamar a ferramenta.',
        {
          'aiLang': NoesisLocaleService.activeAiLanguageName,
          'studyLog': NoesisL10n.tr('Diário de Estudos'),
          'calendar': NoesisL10n.tr('Calendário'),
          'quizzes': NoesisL10n.tr('Simulados'),
          'flashcards': NoesisL10n.tr('Flashcards'),
          'notebooks': NoesisL10n.tr('Cadernos'),
          'roadmaps': NoesisL10n.tr('Trilhas'),
        },
      );

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
      NoesisL10n.tr('dados do app'),
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'`?\b(?:public\.profiles|supabase|auth\.users)\b`?', caseSensitive: false),
      NoesisL10n.tr('sua conta'),
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
      return NoesisL10n.tr('Por favor, configure sua chave de API nas Configurações para ativar o assistente Noesis AI.');
    }

    final now = DateTime.now();
    final snapshot = await NoesisAgentTools.buildAccountSnapshotText();
    final cleanAttach = attachmentContext?.trim() ?? '';
    final fullUserPrompt = cleanAttach.isEmpty
        ? userMessage
        : NoesisL10n.tr('{msg}\n\n[CONTEÚDO ANEXADO PELO USUÁRIO PARA LEITURA/ANÁLISE]:\n{attach}', {
            'msg': userMessage,
            'attach': cleanAttach,
          });

    final nowIso = now.toIso8601String();
    final weekdays = [
      NoesisL10n.tr('Segunda'),
      NoesisL10n.tr('Terça'),
      NoesisL10n.tr('Quarta'),
      NoesisL10n.tr('Quinta'),
      NoesisL10n.tr('Sexta'),
      NoesisL10n.tr('Sábado'),
      NoesisL10n.tr('Domingo'),
    ];
    final wd = weekdays[(now.weekday - 1) % 7];
    final aiLang = NoesisLocaleService.activeAiLanguageName;

    final agentSystemPrompt = NoesisL10n.tr(
      'Você é o Noesis AI, o agente pessoal de estudos e alta produtividade do Aster.\n'
      'Data e hora atual do usuário: {wd}, {nowIso}.\n'
      'Idioma ativo do usuário no Noesis: {aiLang}. Responda sempre neste idioma (ou no idioma em que o usuário escrever).\n'
      'Você tem controle total sobre TODAS as páginas do Noesis (Calendário, Diário de Estudos, Meta Semanal, Simulados, Flashcards, Cadernos de Estudo e Trilhas/Roadmaps) e pode ler/revisar tudo da conta.\n'
      '- Sempre use as ferramentas disponíveis para consultar, criar, editar ou remover itens reais antes de responder.\n'
      '- Ao interpretar datas naturais como "today 11:00", "tomorrow 19:00" ou "Friday 14:00", converta para ISO-8601 usando a data atual ({nowIso}).\n'
      '- Se houver conteúdo anexado (arquivos ou itens do Noesis), leia-o com atenção e utilize-o na resposta ou na criação de simulados/flashcards/resumos.\n'
      '- Responda em Markdown elegante, direto e útil.\n\n'
      '{snapshot}\n\n'
      '{safety}',
      {
        'wd': wd,
        'nowIso': nowIso,
        'aiLang': aiLang,
        'snapshot': snapshot,
        'safety': _internalSafetyDirective,
      },
    );

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
        systemInstruction: '$agentSystemPrompt\n\n${NoesisL10n.tr(
          'Para executar ações reais no sistema, inclua ao final da resposta uma ou mais tags:\n'
          '<noesis_action>{"action": "<nome>", "data": {...}}</noesis_action>\n'
          'Ações suportadas: inspect_account_data, schedule_calendar_event, update_calendar_event, delete_calendar_event, '
          'log_study_session, update_study_session, delete_study_session, set_weekly_goal, create_quiz, delete_quiz, '
          'create_flashcards, update_flashcard_deck, delete_flashcard_deck, create_notebook_or_note, '
          'update_notebook_or_note, delete_notebook_or_note, create_roadmap, update_roadmap, delete_roadmap.',
        )}',
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
        'https://generativelanguage.googleapis.com/v1beta/models/$mod:generateContent',
      );
      final contents = List<Map<String, dynamic>>.from(baseContents);
      final executedTools = <ExecutedToolResult>[];
      var lastReply = '';

      try {
        for (int turn = 0; turn < 6; turn++) {
          final resp = await http
              .post(
                endpoint,
                headers: {
                  'Content-Type': 'application/json',
                  'x-goog-api-key': key,
                },
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
            lastError = Exception(NoesisL10n.tr('Erro Google REST ({model} / status {status})', {
              'model': mod,
              'status': resp.statusCode,
            }));
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
          lastError = Exception(NoesisL10n.tr('Erro Google REST ({model}): {err}', {
            'model': mod,
            'err': e,
          }));
        }
      }

      if (mIdx < candidateModels.length - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    }

    throw lastError ?? Exception(NoesisL10n.tr('Falha ao conectar ao Google Gemini.'));
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
      final reply = NoesisL10n.tr(
        'Analisei o material anexado para você! 📎\n\n### Síntese & Revisão do Conteúdo\n```text\n{snippet}\n```\n\nPosso **gerar flashcards**, **criar um simulado** com base exatamente nesse conteúdo, ou **salvar as conclusões em um Caderno de Estudos**. O que prefere fazer agora?',
        {'snippet': snippet},
      );
      return AgentChatResult(reply: reply);
    }

    // 0.5. Ler / Listar / Inspecionar dados reais da conta
    if (AgentIntentKeywords.inspectAccountQueries.any(lower.contains) &&
        !AgentIntentKeywords.createActionVerbs.any(lower.contains)) {
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

      final reply = NoesisL10n.tr(
        'Aqui está o panorama atualizado da sua conta **Noesis**:\n\n'
        '- 🎯 **Meta Semanal:** {studied} estudados de {goal}\n'
        '- 📅 **Calendário:** {cal} compromisso(s) ativo(s)\n'
        '- ⏱️ **Diário de Estudos:** {sess} sessão(ões) recente(s)\n'
        '- 📝 **Simulados:** {quizzes} simulado(s) salvo(s)\n'
        '- 🎴 **Flashcards:** {decks} baralho(s) ativo(s)\n'
        '- 📓 **Cadernos:** {notebooks} caderno(s)\n'
        '- 🗺️ **Trilhas:** {roadmaps} trilha(s)\n\n'
        'Se quiser detalhes ou editar/remover qualquer item específico, é só me dizer!',
        {
          'studied': goal?['studied_this_week_formatted'] ?? '0m',
          'goal': goal?['goal_formatted'] ?? '25h',
          'cal': cal.length,
          'sess': sess.length,
          'quizzes': quizzes.length,
          'decks': decks.length,
          'notebooks': notebooks.length,
          'roadmaps': roadmaps.length,
        },
      );
      return AgentChatResult(reply: reply);
    }

    // 0.6. Meta Semanal
    if (AgentIntentKeywords.weeklyGoalTriggers.any(lower.contains) ||
        (AgentIntentKeywords.goalTrigger.any(lower.contains) &&
            AgentIntentKeywords.hourTrigger.any(lower.contains))) {
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
        reply: NoesisL10n.tr('Pronto! ✅ **{summary}** atualizada com sucesso no seu Dashboard.', {'summary': exec.summary}),
        actions: actions,
      );
    }

    // 0.7. Remover / Excluir itens
    if (AgentIntentKeywords.deleteTriggers.any(lower.contains)) {
      String toolName = 'delete_calendar_event';
      if (AgentIntentKeywords.quizTokens.any(lower.contains)) {
        toolName = 'delete_quiz';
      } else if (AgentIntentKeywords.notebookTokens.any(lower.contains)) {
        toolName = 'delete_notebook_or_note';
      } else if (AgentIntentKeywords.flashcardTokens.any(lower.contains)) {
        toolName = 'delete_flashcard_deck';
      } else if (AgentIntentKeywords.roadmapTokens.any(lower.contains)) {
        toolName = 'delete_roadmap';
      } else if (AgentIntentKeywords.sessionTokens.any(lower.contains)) {
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
            ? NoesisL10n.tr('Feito! 🗑️ **{summary}**.', {'summary': exec.summary})
            : NoesisL10n.tr('Não encontrei um item correspondente para remover. Informe o título exato ou anexe o item que deseja excluir.'),
        actions: actions,
      );
    }

    // 0.8. Criar Caderno ou Anotação
    if (AgentIntentKeywords.notebookTokens.any(lower.contains) &&
        AgentIntentKeywords.createNotebookVerbs.any(lower.contains)) {
      final exec = await NoesisAgentTools.executeTool(
        name: 'create_notebook_or_note',
        args: {
          'notebook_title': NoesisL10n.tr('Anotações Noesis AI'),
          'subject': NoesisL10n.tr('Estudos'),
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
        reply: NoesisL10n.tr('Anotação salva! 📓 **{summary}** já disponível na aba **Cadernos**.', {'summary': exec.summary}),
        actions: actions,
      );
    }

    // 0.9. Criar Trilha / Roadmap
    if (AgentIntentKeywords.roadmapTokens.any(lower.contains) &&
        AgentIntentKeywords.createRoadmapVerbs.any(lower.contains)) {
      final exec = await NoesisAgentTools.executeTool(
        name: 'create_roadmap',
        args: {'subject': NoesisL10n.tr('Tecnologia & Segurança'), 'goal': message},
        userMessage: message,
        attachmentContext: attachmentContext,
        generateQuiz: _agentQuizCallback,
        generateFlashcards: _agentFlashcardsCallback,
        generateRoadmap: _agentRoadmapCallback,
      );
      actions.addAll(_toAgentActions([exec]));
      return AgentChatResult(
        reply: NoesisL10n.tr('Trilha criada! 🗺️ **{summary}** já está disponível na aba **Trilhas**.', {'summary': exec.summary}),
        actions: actions,
      );
    }

    // 1. Criar Simulado
    if (AgentIntentKeywords.quizTokens.any(lower.contains)) {
      String subject = NoesisL10n.tr('Cybersegurança & AppSec');
      String topic = 'OWASP Top 10';
      int count = 5;

      if (lower.contains('owasp')) {
        subject = NoesisL10n.tr('Segurança de Software');
        topic = NoesisL10n.tr('OWASP Top 10 · Vulnerabilidades e Mitigações');
      } else if (lower.contains('cripto') || lower.contains('crypto')) {
        subject = NoesisL10n.tr('Criptografia & PKI');
        topic = NoesisL10n.tr('Modos de Operação AES, Hashing e TLS');
      } else if (AgentIntentKeywords.networkTokens.any(lower.contains)) {
        subject = NoesisL10n.tr('Redes & Infraestrutura');
        topic = NoesisL10n.tr('Protocolos TCP/IP, DNS e Firewall');
      } else if (lower.contains('cloud') || lower.contains('aws')) {
        subject = NoesisL10n.tr('Cloud Computing');
        topic = NoesisL10n.tr('AWS Security & Arquitetura de Nuvem');
      }

      final matchCount = RegExp(r'(\d+)\s*(?:quest|question)').firstMatch(lower);
      if (matchCount != null) {
        count = int.tryParse(matchCount.group(1)!) ?? 5;
      }

      final difficultyVal = NoesisL10n.tr('Avançado / Nível Certificação');
      final questions = _generateAutonomousQuiz(subject, topic, count, difficultyVal);
      final quizRecord = await SupabaseService.saveGeneratedQuiz(
        title: topic,
        subject: subject,
        questionsData: questions,
        difficulty: difficultyVal,
      );

      final summary = NoesisL10n.tr(
        'Simulado criado · {count} questões · {title}',
        {'count': count, 'title': topic},
      );
      actions.add(AgentAction(
        name: 'create_quiz',
        parameters: {'subject': subject, 'topic': topic, 'count': count},
        status: 'completed',
        summary: summary,
        data: quizRecord,
      ));

      final reply = NoesisL10n.tr(
        'Criei o simulado com **{count} questões técnicas** sobre **{topic}** no Quiz Engine do Noesis!\n\n'
        '### Detalhes do Exame:\n'
        '- **Disciplina:** {subject}\n'
        '- **Tópico:** {topic}\n'
        '- **Nível:** {difficulty}\n'
        '- **Conteúdo:** Cenários reais com análise de código, mitigação de vulnerabilidades e gabarito fundamentado.\n\n'
        'Você pode **iniciar o simulado agora** pelo botão abaixo ou acessá-lo na aba **Simulados**. Boa prova! 🚀',
        {'count': count, 'topic': topic, 'subject': subject, 'difficulty': difficultyVal},
      );
      return AgentChatResult(reply: reply, actions: actions);
    }

    // 1.5. Criar Baralho de Flashcards Cognitivos
    if (AgentIntentKeywords.flashcardTokens.any(lower.contains)) {
      String subject = NoesisL10n.tr('Criptografia & Segurança');
      String topic = NoesisL10n.tr('Conceitos e Protocolos de Criptografia');
      int count = 5;

      if (AgentIntentKeywords.securityTokens.any(lower.contains)) {
        subject = NoesisL10n.tr('Segurança de Software');
        topic = NoesisL10n.tr('OWASP Top 10 e Mitigações');
      } else if (AgentIntentKeywords.networkTokens.any(lower.contains) || lower.contains('tcp') || lower.contains('tls')) {
        subject = NoesisL10n.tr('Redes & Protocolos');
        topic = NoesisL10n.tr('Transporte TCP/UDP e Handshake TLS');
      } else if (lower.contains('cloud') || lower.contains('aws')) {
        subject = NoesisL10n.tr('Cloud Computing');
        topic = NoesisL10n.tr('AWS VPC, IAM e Resiliência');
      } else if (AgentIntentKeywords.algoTokens.any(lower.contains)) {
        subject = NoesisL10n.tr('Ciência da Computação');
        topic = NoesisL10n.tr('Big-O, Hash Tables e Grafos');
      }

      final matchCount = RegExp(r'(\d+)\s*(?:cart|card)').firstMatch(lower);
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
          front: val['front']?.toString() ?? NoesisL10n.tr('Pergunta'),
          back: val['back']?.toString() ?? NoesisL10n.tr('Resposta'),
          tags: val['tags'] is List ? List<String>.from(val['tags']) : [subject, topic],
        );
      }).toList();

      final deckTitle = 'Flashcards: $topic';
      final deck = FlashcardDeck(
        id: 'deck-${DateTime.now().millisecondsSinceEpoch}',
        title: deckTitle,
        subject: subject,
        description: NoesisL10n.tr('Baralho de retenção ativa gerado pelo Noesis AI.'),
        cards: flashcards,
        createdAt: DateTime.now(),
      );

      await SupabaseService.saveFlashcardDeck(deck);

      actions.add(AgentAction(
        name: 'create_flashcards',
        parameters: {'title': deckTitle, 'subject': subject, 'topic': topic},
        status: 'completed',
        summary: NoesisL10n.tr('Baralho criado · {count} cartões · {title}', {
          'count': flashcards.length,
          'title': deckTitle,
        }),
        data: deck.toMap(),
      ));

      final reply = NoesisL10n.tr(
        'Baralho de Flashcards criado com sucesso! 🎴\n\n'
        'Gerei **{count} flashcards cognitivos** sobre **{topic}** ({subject}):\n\n'
        '- **Active Recall:** Perguntas conceituais focadas em retenção de longo prazo.\n'
        '- **Explicações Técnicas:** Respostas detalhadas com o porquê de cada mecanismo.\n'
        '- **Prática:** Acesse o baralho na aba **Flashcards** com animação 3D de virar cartão e avaliação de dificuldade!',
        {
          'count': flashcards.length,
          'topic': topic,
          'subject': subject,
        },
      );
      return AgentChatResult(reply: reply, actions: actions);
    }

    // 2. Agendar Evento no Calendário
    if (AgentIntentKeywords.scheduleTriggers.any(lower.contains)) {
      String title = NoesisL10n.tr('Revisão de Estudos');
      String category = 'review';

      if (lower.contains('cripto') || lower.contains('crypto')) {
        title = NoesisL10n.tr('Revisão · Criptografia & PKI');
      } else if (lower.contains('owasp')) {
        title = NoesisL10n.tr('Revisão · OWASP Top 10');
      } else if (AgentIntentKeywords.quizTokens.any(lower.contains)) {
        title = NoesisL10n.tr('Execução de Simulado');
        category = 'lab';
      } else if (AgentIntentKeywords.examWords.any(lower.contains)) {
        title = NoesisL10n.tr('Prova Oficial');
        category = 'exam';
      }

      final startTime = _parseRelativeTime(lower);
      final endTime = startTime.add(const Duration(minutes: 60));

      await SupabaseService.addCalendarEvent(
        title: title,
        startTime: startTime,
        endTime: endTime,
        category: category,
        description: NoesisL10n.tr('Agendado automaticamente pelo Noesis AI a pedido do usuário.'),
      );

      final timeStr = _formatTimeBrief(startTime);
      final summary = NoesisL10n.tr(
        'Evento agendado · {time} · {title}',
        {'time': timeStr, 'title': title},
      );
      actions.add(AgentAction(
        name: 'schedule_calendar_event',
        parameters: {'title': title, 'start_time': startTime.toIso8601String(), 'category': category},
        status: 'completed',
        summary: summary,
      ));

      final reply = NoesisL10n.tr(
        'Agendado com sucesso! 📅\n\n'
        'Adicionei **{title}** ao seu **Calendário** para **{time}**.\n\n'
        '- **Horário:** {start} às {end}\n'
        '- **Categoria:** {category}\n'
        '- **Lembrete:** Visível na sua grade semanal e diária da aba **Calendário**.\n\n'
        'Precisa que eu prepare um roteiro de tópicos para esse bloco ou quer agendar mais alguma revisão?',
        {
          'title': title,
          'time': timeStr,
          'start': _formatTimeFull(startTime),
          'end': _formatTimeFull(endTime),
          'category': category.toUpperCase(),
        },
      );
      return AgentChatResult(reply: reply, actions: actions);
    }

    // 3. Registrar Sessão de Estudo no Tracker
    if (AgentIntentKeywords.logStudyTriggers.any(lower.contains)) {
      String subject = NoesisL10n.tr('Criptografia');
      String topic = NoesisL10n.tr('AES-GCM & Modos de Operação');
      int minutes = 90;

      if (lower.contains('owasp')) {
        subject = NoesisL10n.tr('Segurança de Software');
        topic = NoesisL10n.tr('OWASP Top 10 · Mitigações de Injeção');
      } else if (AgentIntentKeywords.networkTokens.any(lower.contains)) {
        subject = NoesisL10n.tr('Redes');
        topic = NoesisL10n.tr('Protocolos de Roteamento e Handshake TLS');
      } else if (lower.contains('cloud') || lower.contains('aws')) {
        subject = NoesisL10n.tr('Cloud Computing');
        topic = NoesisL10n.tr('IAM Policies & VPC Security');
      }

      if (AgentIntentKeywords.durationHalfHour.any(lower.contains)) {
        minutes = 90;
      } else if (AgentIntentKeywords.durationTwoHours.any(lower.contains)) {
        minutes = 120;
      } else if (AgentIntentKeywords.durationOneHour.any(lower.contains)) {
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
        notes: NoesisL10n.tr('Sessão registrada via comando no Noesis AI.'),
      );

      final formattedDuration = _formatDuration(minutes);
      final summary = NoesisL10n.tr(
        'Sessão registrada · {duration} em {subject}',
        {'duration': formattedDuration, 'subject': subject},
      );
      actions.add(AgentAction(
        name: 'log_study_session',
        parameters: {'subject': subject, 'topic': topic, 'duration_minutes': minutes},
        status: 'completed',
        summary: summary,
      ));

      final reply = NoesisL10n.tr(
        'Feito! ✅ Sessão de **{duration}** salva com sucesso em **{subject}**.\n\n'
        '- **Tópico:** {topic}\n'
        '- **Métricas:** O tempo já foi somado à sua meta semanal e ao gráfico do **Dashboard**.\n'
        '- **Consistência:** Streak diário mantido e atualizado!\n\n'
        'Seus dados já estão refletidos nos gráficos de progresso. Deseja agendar uma revisão desse conteúdo ou testar seus conhecimentos em um simulado rápido?',
        {
          'duration': formattedDuration,
          'subject': subject,
          'topic': topic,
        },
      );
      return AgentChatResult(reply: reply, actions: actions);
    }

    // 4. Resumo de Criptografia / Conceitos
    if (AgentIntentKeywords.summaryTriggers.any(lower.contains)) {
      final reply = NoesisL10n.tr(
        'Aqui está um resumo de alto rendimento sobre os **Conceitos Fundamentais de Criptografia**:\n\n'
        '### 1. Criptografia Simétrica (Chave Secreta)\n'
        '- **Princípio:** A mesma chave é usada para cifrar e decifrar.\n'
        '- **Vantagem:** Extremamente rápida e eficiente para grandes volumes de dados (streaming e arquivos).\n'
        '- **Algoritmo Padrão:** **AES (Advanced Encryption Standard)** com chaves de 128, 192 ou 256 bits.\n'
        '- **Modos de Operação Críticos:**\n'
        '  - `AES-GCM` (Galois/Counter Mode): Cifra autenticada (AEAD) que garante confidencialidade e integridade. **Atenção:** Nunca reutilize o *nonce* sob a mesma chave.\n'
        '  - `AES-CBC`: Requer vetor de inicialização (IV) imprevisível e preenchimento (padding).\n\n'
        '### 2. Criptografia Assimétrica (Chave Pública/Privada)\n'
        '- **Princípio:** Chave pública cifra; chave privada correspondente decifra (e vice-versa para assinaturas).\n'
        '- **Vantagem:** Resolve a distribuição segura de chaves em canais abertos.\n'
        '- **Principais Algoritmos:**\n'
        '  - **RSA:** Baseado na fatoração de inteiros grandes (chaves de 2048 a 4096 bits).\n'
        '  - **ECC (Curvas Elípticas):** Chaves menores (ex: 256 bits) com segurança equivalente ao RSA-3072, consumindo menos CPU.\n'
        '  - **ECDH:** Troca de chaves para estabelecer segredos efêmeros.\n\n'
        '### 3. Funções de Hash Criptográfico & MAC\n'
        '- **Unidirecionais:** Não permitem reversão. Convertem dados arbitrários em digest de tamanho fixo.\n'
        '- **Propriedades:** Resistência a colisões e efeito avalanche (1 bit alterado muda todo o hash).\n'
        '- **Padrões:** `SHA-256`, `SHA-3`, `BLAKE2`.\n'
        '- **HMAC:** Hash combinado com chave secreta para verificação de integridade e autenticidade.\n\n'
        '### 4. Aplicações Práticas (TLS 1.3 & PKI)\n'
        '- **Handshake TLS:** Usa criptografia assimétrica (ECDHE) para negociar chaves efêmeras com **PFS (Perfect Forward Secrecy)** e depois cifra o tráfego com AES-GCM ou ChaCha20-Poly1305.\n'
        '- **Certificados Digitais (X.509):** Autoridades Certificadoras (CA) assinam chaves públicas para garantir a identidade do servidor.\n\n'
        '> 💡 **Dica de Estudo:** Foque em entender o funcionamento da **Cifra Autenticada (AEAD)** e o motivo do *nonce reuse* destruir a segurança do AES-GCM.\n\n'
        'Gostaria que eu gerasse um simulado de 5 questões sobre esse resumo ou prefere agendar uma revisão?',
      );
      return AgentChatResult(reply: reply);
    }

    // 5. O que posso fazer / Ajuda
    final reply = NoesisL10n.tr(
      'Sou o **Noesis AI**, seu agente cognitivo integrado ao ecossistema Noesis. Tenho capacidade de executar ações reais no seu sistema:\n\n'
      '### O que você pode fazer comigo:\n'
      '- 📝 **Criar Simulados Técnicos:** Diga *"Crie um simulado de 5 questões sobre OWASP"* ou *"Gere questões sobre Criptografia"*.\n'
      '- 🎴 **Gerar Flashcards Cognitivos:** Diga *"Gere flashcards sobre Criptografia"* ou crie baralhos sobre temas específicos.\n'
      '- ⏱️ **Registrar Sessões de Estudo:** Diga *"Registre 1h30 de estudo de Criptografia"* ou *"Estudei 45 min de redes"*.\n'
      '- 📅 **Agendar Revisões e Provas:** Diga *"Agende uma revisão para amanhã às 14h"* ou *"Marque minha prova oficial na sexta"*.\n'
      '- 🧠 **Resumos e Explicações Técnicas:** Peça resumos com exemplos de código, comparações de arquitetura e dicas para certificações.\n\n'
      'Como posso acelerar seus estudos agora?',
    );
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
        throw Exception(
          NoesisL10n.tr('Falha na API Anthropic ({status}): {body}', {'status': resp.statusCode, 'body': resp.body}),
        );
      }

      final data = jsonDecode(resp.body);
      final text = data['content']?[0]?['text'] as String?;
      if (text == null || text.trim().isEmpty) {
        throw Exception(NoesisL10n.tr('Anthropic retornou resposta vazia.'));
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
      apiUrl = _validateCustomEndpoint(baseUrl);
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
      throw Exception(
        NoesisL10n.tr(
          'Falha na API ({provider} / {status}): {body}',
          {'provider': provider, 'status': resp.statusCode, 'body': resp.body},
        ),
      );
    }

    final data = jsonDecode(resp.body);
    final content = data['choices']?[0]?['message']?['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw Exception(NoesisL10n.tr('Provedor retornou resposta vazia.'));
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
        'https://generativelanguage.googleapis.com/v1beta/models/$mod:generateContent',
      );

      try {
        final resp = await http.post(
          endpoint,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': key,
          },
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

        lastError = Exception(NoesisL10n.tr('Erro Google REST ({model} / {msg})', {
          'model': mod,
          'msg': apiMessage,
        }));

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
          lastError = Exception(NoesisL10n.tr('Erro Google REST ({model}): {err}', {
            'model': mod,
            'err': e,
          }));
        }
        if (i < candidateModels.length - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 450));
          continue;
        }
      }
    }

    throw lastError ?? Exception(NoesisL10n.tr('Erro Google REST: nenhum modelo Gemini disponível respondeu.'));
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
          'question': NoesisL10n.tr(
              'Um endpoint REST aceita o parâmetro ?redirect= para encaminhar o usuário após autenticação. Um invasor envia https://app.com/login?redirect=https://evil.com. Qual vulnerabilidade do OWASP Top 10 está caracterizada?'),
          'code_snippet': NoesisL10n.tr(
              '# auth_controller.py\nredirect_url = request.args.get("redirect")\nreturn redirect(redirect_url)  # Sem validação prévia'),
          'options': [
            'A01:2021 - Broken Access Control (Open Redirect)',
            'A03:2021 - Injection (SQL Injection)',
            'A07:2021 - Identification and Authentication Failures',
            'A09:2021 - Security Logging and Monitoring Failures',
          ],
          'correct_index': 0,
          'explanation': NoesisL10n.tr(
              'Redirecionamentos abertos não validados enquadram-se em Broken Access Control (A01). A mitigação correta é validar o destino contra uma allow-list estrita de domínios ou caminhos relativos internos.'),
          'rag_sources': ['OWASP Top 10:2021 · A01', 'CWE-601: Open Redirect'],
        },
        {
          'question': NoesisL10n.tr(
              'Durante uma auditoria, constatou-se que a aplicação concatena diretamente entradas de formulário em consultas SQL. Qual abordagem mitiga a falha de forma definitiva?'),
          'code_snippet':
              '# query_runner.py\nsql = f"SELECT * FROM users WHERE email = \'{user_email}\'"\ncursor.execute(sql)',
          'options': [
            NoesisL10n.tr('Utilizar consultas parametrizadas (Prepared Statements) em todas as camadas de acesso a dados.'),
            NoesisL10n.tr('Adicionar um filtro de caracteres especiais para remover aspas simples e hifens.'),
            NoesisL10n.tr('Aplicar criptografia AES-256 no banco de dados antes da execução da query.'),
            NoesisL10n.tr('Aumentar o tempo limite de conexão (timeout) do pool de conexões.'),
          ],
          'correct_index': 0,
          'explanation': NoesisL10n.tr(
              'Prepared Statements separam estritamente o código SQL dos dados de entrada, impedindo que comandos arbitrários sejam interpretados pelo motor do banco. Filtros por lista negra são frequentemente contornados.'),
          'rag_sources': ['OWASP Top 10:2021 · A03 Injection', 'NIST SP 800-64'],
        },
        {
          'question': NoesisL10n.tr(
              'Uma aplicação armazena senhas no banco de dados utilizando MD5 com salt simples. Diante das recomendações modernas da OWASP, qual é a conduta correta?'),
          'code_snippet':
              '# password_hasher.py\nhash = hashlib.md5((salt + password).encode()).hexdigest()',
          'options': [
            NoesisL10n.tr('Migrar para algoritmos com fator de trabalho ajustável, como Argon2id, bcrypt ou PBKDF2.'),
            NoesisL10n.tr('Dobrar o tamanho do salt mantendo o algoritmo MD5.'),
            NoesisL10n.tr('Substituir por SHA-1 com iterações em loop for de 1000 vezes.'),
            NoesisL10n.tr('Cifrar o hash MD5 com chave simétrica AES no servidor web.'),
          ],
          'correct_index': 0,
          'explanation': NoesisL10n.tr(
              'Funções rápidas como MD5 e SHA-1 são vulneráveis a ataques de força bruta massivos com GPUs e ASICs. A OWASP recomenda Argon2id ou bcrypt, que impõem custo deliberado de CPU e memória.'),
          'rag_sources': ['OWASP Password Storage Cheat Sheet', 'RFC 9106 Argon2'],
        },
        {
          'question': NoesisL10n.tr(
              'Qual medida é mais eficiente para impedir ataques de Cross-Site Scripting (XSS) em aplicações web modernas?'),
          'code_snippet':
              '// view.js\ndocument.getElementById("userBio").innerHTML = userData.bio;',
          'options': [
            NoesisL10n.tr('Utilizar Content Security Policy (CSP) robusta aliada a context-aware output encoding (ou frameworks que escapam por padrão).'),
            NoesisL10n.tr('Substituir todas as requisições GET por POST para mascarar os parâmetros na URL.'),
            NoesisL10n.tr('Habilitar o flag SameSite=None em todos os cookies de sessão.'),
            NoesisL10n.tr('Validar apenas o comprimento da string no front-end.'),
          ],
          'correct_index': 0,
          'explanation': NoesisL10n.tr(
              'Context-aware output encoding garante que dados inseridos no DOM não sejam executados como código. Um CSP restrito atua como defesa em profundidade, bloqueando scripts inline e fontes não autorizadas.'),
          'rag_sources': ['OWASP XSS Prevention Cheat Sheet', 'W3C CSP Level 3'],
        },
        {
          'question': NoesisL10n.tr(
              'Ao analisar o cabeçalho de resposta de um servidor, identificou-se a ausência de "Strict-Transport-Security" (HSTS). Qual é o risco direto dessa ausência?'),
          'code_snippet': NoesisL10n.tr(
              'HTTP/1.1 200 OK\nServer: nginx\n(Ausência do cabeçalho Strict-Transport-Security)'),
          'options': [
            NoesisL10n.tr('Ataques de SSL Stripping (downgrade para HTTP puro) por man-in-the-middle em conexões subsequentes.'),
            NoesisL10n.tr('Injeção de cabeçalhos HTTP no lado do cliente.'),
            NoesisL10n.tr('Execução remota de código no balanceador de carga.'),
            NoesisL10n.tr('Vazamento imediato da chave privada RSA do certificado.'),
          ],
          'correct_index': 0,
          'explanation': NoesisL10n.tr(
              'O HSTS instrui os navegadores a acessarem o site exclusivamente via HTTPS, impedindo ataques de downgrade como o SSLStrip em redes não confiáveis (como Wi-Fi público).'),
          'rag_sources': ['RFC 6797 HSTS', 'OWASP Top 10 · Security Misconfiguration'],
        },
      ];
      final safeCount = count.clamp(1, quizMaxQuestions);
      return List<Map<String, dynamic>>.generate(safeCount, (i) {
        final base = pool[i % pool.length];
        final disc = (disciplines != null && i < disciplines.length)
            ? disciplines[i]
            : (subject.trim().isNotEmpty ? subject.trim() : NoesisL10n.tr('Segurança de Aplicações'));
        return {
          ...base,
          'discipline': disc,
        };
      });
    }

    // Default: Criptografia & PKI
    final cryptoPool = [
      {
        'question': NoesisL10n.tr(
            'Em uma cifra de bloco operando em modo Galois/Counter Mode (AES-GCM), qual é a consequência fatal da reutilização do mesmo Initialization Vector (Nonce) sob uma mesma chave secreta?'),
        'code_snippet': NoesisL10n.tr(
            '# encryptor.py\nkey = load_fixed_key()\nnonce = b"123456789012"  # Fixo reutilizado para todas as mensagens!'),
        'options': [
          NoesisL10n.tr('Permite a recuperação da chave de autenticação (GHASH key) e quebra a confidencialidade das mensagens por XOR dos textos cifrados.'),
          NoesisL10n.tr('Causa estouro de pilha (buffer overflow) no acelerador de hardware.'),
          NoesisL10n.tr('Reduz o tamanho da chave de 256 bits para 64 bits automaticamente.'),
          NoesisL10n.tr('Faz a cifra reverter para o modo ECB (Electronic Codebook).'),
        ],
        'correct_index': 0,
        'explanation': NoesisL10n.tr(
            'No AES-GCM, o reúso de nonce com a mesma chave revela o keystream (permitindo decifrar mensagens via XOR) e viabiliza a recuperação da chave GHASH, destruindo a integridade e autenticidade.'),
        'rag_sources': ['NIST SP 800-38D (GCM)', 'RFC 5116 (AEAD)'],
      },
      {
        'question': NoesisL10n.tr(
            'Qual é a principal vantagem das curvas elípticas (ECC) em relação ao RSA tradicional na criptografia assimétrica moderna?'),
        'code_snippet': NoesisL10n.tr(
            '# Comparação de tamanhos:\n# RSA-3072 vs ECC P-256 (mesmo nível de segurança de 128 bits)'),
        'options': [
          NoesisL10n.tr('Chaves substancialmente menores para o mesmo nível de segurança criptográfica, reduzindo uso de memória e latência de rede.'),
          NoesisL10n.tr('A criptografia ECC é simétrica e não requer troca de chaves.'),
          NoesisL10n.tr('Imunidade comprovada contra computadores quânticos rodando o algoritmo de Shor.'),
          NoesisL10n.tr('Despensa a necessidade de números aleatórios de alta entropia.'),
        ],
        'correct_index': 0,
        'explanation': NoesisL10n.tr(
            'Uma chave ECC de 256 bits oferece segurança equivalente ao RSA de 3072 bits. Isso economiza banda, acelera handshakes TLS e reduz consumo de energia em dispositivos móveis e IoT.'),
        'rag_sources': ['NIST SP 800-57', 'RFC 6090'],
      },
      {
        'question': NoesisL10n.tr(
            'Durante a negociação do TLS 1.3, qual propriedade garante que mesmo se a chave privada do servidor vazar no futuro, sessões passadas não poderão ser decifradas?'),
        'code_snippet':
            'Cipher Suite: TLS_AES_256_GCM_SHA384\nKey Exchange: Ephemeral Elliptic Curve Diffie-Hellman (ECDHE)',
        'options': [
          'Perfect Forward Secrecy (PFS)',
          'Zero-Knowledge Proof (ZKP)',
          'Homomorphic Encryption',
          'Pre-Shared Key Derivation (PSK)',
        ],
        'correct_index': 0,
        'explanation': NoesisL10n.tr(
            'O Perfect Forward Secrecy (PFS) gera chaves efêmeras para cada sessão (ECDHE). Se a chave mestre do servidor for comprometida depois, as sessões passadas continuam indecifráveis.'),
        'rag_sources': ['RFC 8446 (The TLS Protocol Version 1.3)', 'NIST SP 800-52'],
      },
      {
        'question': NoesisL10n.tr(
            'Qual das seguintes opções descreve com precisão a diferença fundamental entre uma função de hash simples e um Message Authentication Code (MAC)?'),
        'code_snippet':
            '# Hash: SHA256(data)\n# MAC:  HMAC-SHA256(key, data)',
        'options': [
          NoesisL10n.tr('O MAC utiliza uma chave secreta compartilhada para assegurar integridade e autenticidade da origem, enquanto o hash verifica apenas a integridade.'),
          NoesisL10n.tr('O Hash é reversível e o MAC é unidirecional.'),
          NoesisL10n.tr('O MAC cifra a mensagem inteira e o Hash apenas o cabeçalho.'),
          NoesisL10n.tr('O Hash só funciona com arquivos de até 1 MB.'),
        ],
        'correct_index': 0,
        'explanation': NoesisL10n.tr(
            'Um atacante pode alterar os dados e recalcular um hash comum. Porém, sem a chave secreta compartilhada, ele não consegue calcular um MAC válido, provando que a mensagem veio de quem detém a chave.'),
        'rag_sources': ['RFC 2104 (HMAC)', 'FIPS PUB 198-1'],
      },
      {
        'question': NoesisL10n.tr(
            'Por que o modo ECB (Electronic Codebook) é expressamente proibido para cifragem de dados confidenciais com cifras de bloco?'),
        'code_snippet': NoesisL10n.tr(
            '# ECB Mode:\n# Bloco de Entrada A -> Cifra(A)\n# Bloco de Entrada A -> Cifra(A) [Mesma saída sempre!]'),
        'options': [
          NoesisL10n.tr('Blocos idênticos de texto claro produzem blocos idênticos de texto cifrado, preservando padrões visuais e estruturais dos dados.'),
          NoesisL10n.tr('Não suporta chaves de 256 bits.'),
          NoesisL10n.tr('Exige sincronização de relógio em tempo real entre cliente e servidor.'),
          NoesisL10n.tr('Gera mensagens com o triplo do tamanho original.'),
        ],
        'correct_index': 0,
        'explanation': NoesisL10n.tr(
            'O modo ECB não usa vetor de inicialização nem encadeamento. Blocos idênticos geram cifras idênticas, permitindo inferir estruturas internas (ex: a famosa imagem do pinguim Tux cifrado em ECB).'),
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
        'question': NoesisL10n.tr('[{exam} · Q{num}] {question}', {
          'exam': examModelName ?? topic,
          'num': startNumber + i,
          'question': base['question'],
        }),
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
          'front': NoesisL10n.tr('O que é Broken Access Control (A01:2021) e por que é a falha nº 1 do OWASP Top 10?'),
          'back': NoesisL10n.tr('Ocorre quando usuários conseguem acessar recursos ou executar ações fora de suas permissões pretendidas (ex: manipular IDs na URL `?user_id=123`). É a nº 1 porque é extremamente prevalente e comum em arquiteturas modernas de microsserviços.'),
          'tags': ['OWASP', 'A01:2021', 'Access Control'],
        },
        {
          'front': NoesisL10n.tr('Como Prepared Statements (Consultas Parametrizadas) eliminam SQL Injection?'),
          'back': NoesisL10n.tr('Prepared Statements enviam a estrutura da query SQL para compilação prévia no banco, tratando os parâmetros como valores literais puros. Mesmo que o parâmetro contenha aspas ou comandos (`OR 1=1`), ele nunca é interpretado como código SQL executável.'),
          'tags': ['AppSec', 'SQL Injection', NoesisL10n.tr('Mitigação')],
        },
        {
          'front': NoesisL10n.tr('Qual a diferença entre XSS Armazenado (Stored) e XSS Refletido (Reflected)?'),
          'back': NoesisL10n.tr('XSS Refletido ocorre quando o payload é enviado na requisição (ex: busca na URL) e refletido imediatamente na resposta. XSS Armazenado é persistido no banco de dados (ex: comentários de blog), atacando todos os usuários que visualizarem a página posteriormente.'),
          'tags': ['OWASP', 'XSS', 'Web Security'],
        },
        {
          'front': NoesisL10n.tr('Qual a função dos cabeçalhos CSP (Content Security Policy) e CORS na proteção de navegadores?'),
          'back': NoesisL10n.tr('CSP restringe as origens das quais scripts, imagens e conexões podem ser carregados, bloqueando execução de scripts inline em caso de XSS. CORS instrui o navegador a permitir ou proibir que páginas de outra origem leiam recursos via fetch/XHR.'),
          'tags': ['HTTP Headers', 'CSP', 'CORS'],
        },
        {
          'front': NoesisL10n.tr('Por que tokens CSRF são essenciais para requisições com mutação de estado?'),
          'back': NoesisL10n.tr('Navegadores anexam cookies de sessão automaticamente em requisições cross-site. Um token CSRF é um valor imprevisível e vinculado à sessão que não é enviado automaticamente, garantindo que a requisição partiu legitimamente da aplicação do usuário.'),
          'tags': ['CSRF', NoesisL10n.tr('Autenticação'), NoesisL10n.tr('Sessões')],
        },
      ];
      return pool.take(count).toList();
    }

    if (lower.contains('cloud') || lower.contains('aws') || lower.contains('devops') || lower.contains('kubernetes')) {
      final pool = [
        {
          'front': NoesisL10n.tr('Qual a diferença crucial entre um Internet Gateway (IGW) e um NAT Gateway na AWS?'),
          'back': NoesisL10n.tr('IGW realiza tradução de endereço 1:1 e permite conexões bidirecionais (inbound e outbound) em subnets públicas. NAT Gateway permite que instâncias em subnets privadas façam requisições para a Internet (outbound), mas impede que conexões externas iniciem contato (inbound).'),
          'tags': ['AWS', 'VPC', 'Networking'],
        },
        {
          'front': NoesisL10n.tr('Qual o conceito de Imutabilidade de Infraestrutura e como ele reduz Configuration Drift?'),
          'back': NoesisL10n.tr('Servidores e contêineres nunca são modificados ou atualizados in-place. Se uma alteração for necessária, uma nova imagem é construída, testada e implantada substituindo as instâncias antigas, garantindo paridade idêntica entre ambientes.'),
          'tags': ['DevOps', 'IaC', NoesisL10n.tr('Imutabilidade')],
        },
        {
          'front': NoesisL10n.tr('Qual a diferença entre Kubernetes Pod, Deployment e Service?'),
          'back': NoesisL10n.tr('Pod: Menor unidade de execução que encapsula um ou mais contêineres. Deployment: Gerencia o ciclo de vida, réplicas e rolling updates dos Pods. Service: Provê um IP estável e balanceador de carga DNS para que outros pods ou clientes alcancem o conjunto efêmero de Pods.'),
          'tags': ['Kubernetes', 'K8s', 'Containers'],
        },
        {
          'front': NoesisL10n.tr('O que é o Teorema CAP em sistemas distribuídos?'),
          'back': NoesisL10n.tr('Em uma rede com Partição (P), um sistema distribuído só pode garantir Consistência (C - todos os nós leem o mesmo dado mais recente) OU Disponibilidade (A - toda requisição recebe resposta sem garantia de ser a mais recente), nunca ambos simultaneamente.'),
          'tags': [NoesisL10n.tr('Sistemas Distribuídos'), 'CAP', NoesisL10n.tr('Bancos')],
        },
      ];
      return pool.take(count).toList();
    }

    // Default Crypto / Security / General High-Yield Pool
    final generalPool = [
      {
        'front': NoesisL10n.tr('Conceito Fundamental de {topic}: Qual é o seu objetivo primário?', {'topic': topic}),
        'back': NoesisL10n.tr(
            'No contexto de {subject}, {topic} é projetado para resolver problemas críticos de integridade, confiabilidade e desempenho através de abstrações bem definidas e contratos determinísticos.',
            {'subject': subject, 'topic': topic}),
        'tags': [subject, topic],
      },
      {
        'front': NoesisL10n.tr('{topic}: Qual a principal armadilha ou antipadrão a ser evitado?', {'topic': topic}),
        'back': NoesisL10n.tr(
            'A armadilha mais comum é assumir comportamentos implícitos sem validação de limites, o que pode introduzir vulnerabilidades de segurança, sobrecarga de recursos ou acoplamento excessivo.'),
        'tags': [subject, NoesisL10n.tr('Boas Práticas')],
      },
      {
        'front': NoesisL10n.tr('{topic}: Qual é o trade-off fundamental envolvido?', {'topic': topic}),
        'back': NoesisL10n.tr(
            'O trade-off envolve balancear complexidade de implementação vs resiliência e escala. Otimizações prematuras geralmente aumentam a dívida técnica sem ganhos mensuráveis.'),
        'tags': [subject, NoesisL10n.tr('Arquitetura')],
      },
      {
        'front': NoesisL10n.tr('{topic}: Como validar o funcionamento em ambientes de produção?', {'topic': topic}),
        'back': NoesisL10n.tr(
            'Através de telemetria observável (métricas, logs estruturados e tracing distribuído) combinada com testes automatizados de regressão e checagem de saúde (health checks).'),
        'tags': [subject, NoesisL10n.tr('Operações')],
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
    String level = NoesisL10n.defaultRoadmapLevel,
    int estimatedWeeks = 4,
    int hoursPerWeek = 8,
    String? extraNotes,
  }) async {
    final cleanGoal = goal.trim().isEmpty
        ? NoesisL10n.tr('Dominar {subject}', {'subject': subject})
        : goal.trim();
    final cleanSubject = subject.trim().isEmpty ? NoesisL10n.tr('Geral') : subject.trim();
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
        ? NoesisL10n.tr('\nObservações / Prioridades do estudante:\n"""\n{notes}\n"""\n', {'notes': extraNotes.trim()})
        : '';

    final aiLang = NoesisLocaleService.activeAiLanguageName;
    final prompt = NoesisL10n.tr(
      'Crie um Roadmap (Trilha de Estudos) completo, sequencial e prático no idioma **{aiLang}**.\n'
      'REGRA CRÍTICA: Todos os títulos, descrições, objetivos, tópicos e metas devem estar estritamente no idioma **{aiLang}**.\n'
      '- Objetivo final: "{goal}"\n'
      '- Matéria / Área principal: "{subject}"\n'
      '- Nível atual: "{level}"\n'
      '- Prazo total estimado: {weeks} semanas (~{hours} horas por semana)\n'
      '{extra}\n'
      'Gere de 5 a 8 etapas progressivas (da base até a consolidação/prática).\n'
      'Para CADA etapa, explique detalhadamente o que a pessoa vai aprender:\n'
      '- "description": 2 a 3 frases objetivas explicando o propósito da etapa, a progressão didática e como o conteúdo se conecta ao objetivo final.\n'
      '- "learning_objectives": lista de 3 a 4 objetivos claros começando com verbo no infinitivo detalhando o que o aluno dominará ao concluir a etapa.\n'
      '- "key_topics": lista de 4 a 6 conceitos/assuntos específicos essenciais daquela etapa.\n'
      '- "practical_milestone": 1 meta prática verificável para validar que aprendeu.\n'
      '- "subtopics": lista de 3 a 5 subtarefas acionáveis de checklist.\n'
      '- "resources": 1 a 3 sugestões de materiais ou exercícios práticos.\n\n'
      'RETORNE ESTRITAMENTE um array JSON com 1 objeto neste formato (sem Markdown extra):\n'
      '[\n'
      '  {\n'
      '    "title": "Concise roadmap title",\n'
      '    "steps": [\n'
      '      {\n'
      '        "title": "Step 1: Clear step name",\n'
      '        "description": "Detailed explanation of what will be learned and why this step comes here.",\n'
      '        "estimated_hours": 6,\n'
      '        "learning_objectives": ["Understand concept X...", "Apply method Y in practice..."],\n'
      '        "key_topics": ["Concept A", "Concept B", "Rule C", "Case Study D"],\n'
      '        "practical_milestone": "Solve 15 explained exercises achieving at least 80% accuracy.",\n'
      '        "subtopics": ["Subtopic 1", "Subtopic 2", "Subtopic 3"],\n'
      '        "resources": ["Suggested material or practice exercise"]\n'
      '      }\n'
      '    ]\n'
      '  }\n'
      ']',
      {
        'aiLang': aiLang,
        'goal': cleanGoal,
        'subject': cleanSubject,
        'level': level,
        'weeks': safeWeeks,
        'hours': safeHours,
        'extra': extraSection,
      },
    );

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
      title: goal.isNotEmpty
          ? goal
          : NoesisL10n.tr('Trilha de {subject}', {'subject': subject}),
      goal: goal,
      subject: subject,
      level: level,
      estimatedWeeks: estimatedWeeks,
      createdAt: now,
      updatedAt: now,
      steps: [
        RoadmapStep(
          id: 'step-1-${now.millisecondsSinceEpoch}',
          title: NoesisL10n.tr(
            '1. Diagnóstico e Fundamentos de {subject}',
            {'subject': subject},
          ),
          description: NoesisL10n.tr(
            'Nivelamento conceitual inicial para construir uma base sólida em {subject} ({level}) antes de avançar para tópicos densos.',
            {'subject': subject, 'level': NoesisL10n.tr(level)},
          ),
          estimatedHours: perStep,
          status: RoadmapStepStatus.doing,
          learningObjectives: [
            NoesisL10n.tr(
              'Dominar a terminologia fundamental e os princípios organizadores de {subject}',
              {'subject': subject},
            ),
            NoesisL10n.tr('Identificar suas principais lacunas iniciais por meio de questões diagnósticas'),
            NoesisL10n.tr('Estruturar um resumo-base para consultas rápidas nas etapas seguintes'),
          ],
          keyTopics: [
            NoesisL10n.tr('Conceitos basilares de {subject}', {'subject': subject}),
            NoesisL10n.tr('Vocabulário e convenções'),
            NoesisL10n.tr('Leitura e interpretação inicial'),
            NoesisL10n.tr('Mapa de incidência'),
          ],
          practicalMilestone: NoesisL10n.tr(
            'Concluir 10 questões diagnósticas e anotar os 5 conceitos-chave no Caderno.',
          ),
          subtopics: [
            RoadmapSubtopic(
              id: 'sub-1a',
              title: NoesisL10n.tr(
                'Mapeamento de conceitos-chave de {subject}',
                {'subject': subject},
              ),
            ),
            RoadmapSubtopic(
              id: 'sub-1b',
              title: NoesisL10n.tr('Resumo base e vocabulário essencial'),
            ),
            RoadmapSubtopic(
              id: 'sub-1c',
              title: NoesisL10n.tr('Lista inicial de exercícios diagnósticos'),
            ),
          ],
          resources: [
            NoesisL10n.tr('Caderno de resumo estruturado'),
            NoesisL10n.tr('10 questões diagnósticas'),
          ],
        ),
        RoadmapStep(
          id: 'step-2-${now.millisecondsSinceEpoch}',
          title: NoesisL10n.tr('2. Núcleo Teórico e Estruturas Principais'),
          description: NoesisL10n.tr(
            'Aprofundamento sistemático nos pilares centrais de {subject}, conectando regras, mecanismos e causas e consequências.',
            {'subject': subject},
          ),
          estimatedHours: perStep,
          learningObjectives: [
            NoesisL10n.tr(
              'Explicar com clareza os mecanismos e leis centrais de {subject}',
              {'subject': subject},
            ),
            NoesisL10n.tr('Relacionar diferentes frentes teóricas sem depender de memorização mecânica'),
            NoesisL10n.tr('Transformar definições-chave em flashcards para retenção espaçada'),
          ],
          keyTopics: [
            NoesisL10n.tr('Pilares de maior peso'),
            NoesisL10n.tr('Relações de causa e efeito'),
            NoesisL10n.tr('Modelagem conceitual'),
            NoesisL10n.tr('Síntese ativa'),
          ],
          practicalMilestone: NoesisL10n.tr(
            'Criar e revisar pelo menos 15 flashcards dos pilares teóricos principais.',
          ),
          subtopics: [
            RoadmapSubtopic(
              id: 'sub-2a',
              title: NoesisL10n.tr('Estudo guiado dos tópicos de maior peso'),
            ),
            RoadmapSubtopic(
              id: 'sub-2b',
              title: NoesisL10n.tr('Flashcards para fixação ativa (Active Recall)'),
            ),
          ],
          resources: [
            NoesisL10n.tr('Baralho de Flashcards no Noesis'),
            NoesisL10n.tr('Anotações por tópico'),
          ],
        ),
        RoadmapStep(
          id: 'step-3-${now.millisecondsSinceEpoch}',
          title: NoesisL10n.tr('3. Resolução Guiada e Aplicações Práticas'),
          description: NoesisL10n.tr(
            'Transição da teoria para a prática dirigida: treino progressivo em situações reais e análise detalhada dos distratores.',
          ),
          estimatedHours: perStep,
          learningObjectives: [
            NoesisL10n.tr('Interpretar enunciados contextualizados e identificar exatamente o comando da questão'),
            NoesisL10n.tr('Diagnosticar erros recorrentes e armadilhas típicas da área'),
            NoesisL10n.tr('Ganhar velocidade e segurança na resolução de problemas aplicados'),
          ],
          keyTopics: [
            NoesisL10n.tr('Resolução passo a passo'),
            NoesisL10n.tr('Análise de distratores'),
            NoesisL10n.tr('Caderno de erros'),
            NoesisL10n.tr('Aplicações cotidianas'),
          ],
          practicalMilestone: NoesisL10n.tr(
            'Completar um simulado temático atingindo pelo menos 75% de aproveitamento.',
          ),
          subtopics: [
            RoadmapSubtopic(
              id: 'sub-3a',
              title: NoesisL10n.tr('Bateria de exercícios por dificuldade crescente'),
            ),
            RoadmapSubtopic(
              id: 'sub-3b',
              title: NoesisL10n.tr('Caderno de erros e revisão das lacunas'),
            ),
          ],
          resources: [NoesisL10n.tr('Simulado temático no Noesis')],
        ),
        RoadmapStep(
          id: 'step-4-${now.millisecondsSinceEpoch}',
          title: NoesisL10n.tr('4. Tópicos Avançados e Interdisciplinaridade'),
          description: NoesisL10n.tr(
            'Integração entre conteúdos de alta complexidade em {subject}, lidando com cenários combinados e questões de alto rigor.',
            {'subject': subject},
          ),
          estimatedHours: perStep,
          learningObjectives: [
            NoesisL10n.tr('Combinar dois ou mais conceitos avançados na mesma resolução'),
            NoesisL10n.tr('Evitar extrapolações e erros sutis de modelagem em níveis altos'),
            NoesisL10n.tr('Consolidar tópicos críticos por revisão ativa antes da reta final'),
          ],
          keyTopics: [
            NoesisL10n.tr('Questões interdisciplinares'),
            NoesisL10n.tr('Casos de borda'),
            NoesisL10n.tr('Análise crítica comparativa'),
            NoesisL10n.tr('Gestão de tempo sob pressão'),
          ],
          practicalMilestone: NoesisL10n.tr(
            'Resolver uma bateria avançada cronometrada e revisar 100% das questões erradas.',
          ),
          subtopics: [
            RoadmapSubtopic(
              id: 'sub-4a',
              title: NoesisL10n.tr('Casos avançados e questões interdisciplinares'),
            ),
            RoadmapSubtopic(
              id: 'sub-4b',
              title: NoesisL10n.tr('Revisão espaçada dos pontos críticos'),
            ),
          ],
          resources: [NoesisL10n.tr('Simulado avançado cronometrado')],
        ),
        RoadmapStep(
          id: 'step-5-${now.millisecondsSinceEpoch}',
          title: NoesisL10n.tr('5. Consolidação Final e Simulado Completo'),
          description: NoesisL10n.tr(
            'Fechamento estratégico da trilha visando "{goal}", com simulado completo, revisão da IA e ajuste fino dos últimos pontos.',
            {'goal': goal},
          ),
          estimatedHours: perStep,
          learningObjectives: [
            NoesisL10n.tr('Sustentar foco e ritmo de prova durante uma bateria completa com cronômetro'),
            NoesisL10n.tr('Validar domínio global usando o comparativo e a Review da IA'),
            NoesisL10n.tr('Executar plano cirúrgico de revisão final sobre as poucas lacunas restantes'),
          ],
          keyTopics: [
            NoesisL10n.tr('Simulado completo'),
            NoesisL10n.tr('Review pedagógica da IA'),
            NoesisL10n.tr('Revisão de última milha'),
            NoesisL10n.tr('Calibragem de ritmo'),
          ],
          practicalMilestone: NoesisL10n.tr(
            'Finalizar simulado completo com tempo controlado e revisar o plano da IA.',
          ),
          subtopics: [
            RoadmapSubtopic(
              id: 'sub-5a',
              title: NoesisL10n.tr('Simulado completo com tempo controlado'),
            ),
            RoadmapSubtopic(
              id: 'sub-5b',
              title: NoesisL10n.tr('Revisão final da Review da IA'),
            ),
          ],
          resources: [NoesisL10n.tr('Simulado completo no Noesis')],
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
    final weekdays = [
      NoesisL10n.tr('Seg'),
      NoesisL10n.tr('Ter'),
      NoesisL10n.tr('Qua'),
      NoesisL10n.tr('Qui'),
      NoesisL10n.tr('Sex'),
      NoesisL10n.tr('Sáb'),
      NoesisL10n.tr('Dom'),
    ];
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
