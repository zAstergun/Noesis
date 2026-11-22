import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'supabase_service.dart';

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
  }
  throw const FormatException('Formato de JSON inesperado recebido.');
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

class GeminiService {
  static String? apiKey;
  static String provider = 'google';
  static String model = 'gemini-3.1-flash-lite';
  static String baseUrl = '';
  static double temperature = 0.4;

  static const List<AIProvider> providers = [
    AIProvider(
      id: 'google',
      label: 'Google',
      keyUrl: 'https://aistudio.google.com/app/apikey',
      models: [
        'gemini-3.1-flash-lite',
        'gemini-3.8-flash',
        'gemini-3.7-flash',
        'gemini-3.6-flash',
        'gemini-3.5-flash',
        'gemini-3.5-flash-lite',
        'gemini-3.1-pro-preview',
        'gemini-3-flash-preview',
        'gemini-2.0-flash',
        'gemini-1.5-flash',
      ],
      defaultModel: 'gemini-3.1-flash-lite',
    ),
    AIProvider(
      id: 'openai',
      label: 'OpenAI',
      keyUrl: 'https://platform.openai.com/api-keys',
      models: ['gpt-4o', 'gpt-4o-mini', 'o4-mini'],
      defaultModel: 'gpt-4o-mini',
    ),
    AIProvider(
      id: 'anthropic',
      label: 'Anthropic',
      keyUrl: 'https://console.anthropic.com/settings/keys',
      models: ['claude-sonnet-4', 'claude-haiku-4'],
      defaultModel: 'claude-sonnet-4',
    ),
    AIProvider(
      id: 'xai',
      label: 'xAI · Grok',
      keyUrl: 'https://console.x.ai/',
      models: ['grok-4.7'],
      defaultModel: 'grok-4.7',
    ),
    AIProvider(
      id: 'deepseek',
      label: 'DeepSeek',
      keyUrl: 'https://platform.deepseek.com/api_keys',
      models: ['deepseek-v4-pro', 'deepseek-v4-flash'],
      defaultModel: 'deepseek-v4-flash',
    ),
    AIProvider(
      id: 'openrouter',
      label: 'OpenRouter',
      keyUrl: 'https://openrouter.ai/settings/keys',
      models: ['auto', 'deepseek-v3'],
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
    model = modelName;
    apiKey = key;
    if (customBaseUrl != null) baseUrl = customBaseUrl;
  }

  static AIProvider get currentProvider =>
      providers.firstWhere((p) => p.id == provider, orElse: () => providers.first);

  // ---------------------------------------------------------------------------
  // TESTE DE CONEXÃO MULTI-PROVEDOR (STUDIO OS STYLE)
  // ---------------------------------------------------------------------------
  static Future<String> testConnection({
    required String providerId,
    required String modelName,
    required String apiKey,
    String? baseUrl,
  }) async {
    final key = apiKey.trim();
    final mod = modelName.trim();
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
    if (provider != 'custom' && key.isEmpty) {
      throw Exception('Chave de API da IA não configurada.');
    }

    final prompt = '''
Você é o examinador sênior do Aster. Sua missão é criar um simulado de alto nível técnico sobre "$subject - $topic".
Dificuldade: $difficulty.
Total de questões: $numberOfQuestions.

${referenceDocumentText != null ? 'DOCUMENTO DE REFERÊNCIA / PROVAS ANTERIORES PARA GUIAR O ESTILO E AS QUESTÕES:\n"""\n$referenceDocumentText\n"""' : 'Gere questões originais e rigorosas sobre o tema indicado.'}

RETORNE ESTRITAMENTE um JSON no seguinte formato (sem formatação markdown extra, apenas o array JSON válido):
[
  {
    "question": "Texto claro do enunciado da questão...",
    "options": [
      "Alternativa A",
      "Alternativa B",
      "Alternativa C",
      "Alternativa D"
    ],
    "correct_index": 0,
    "explanation": "Explicação detalhada e didática do motivo pelo qual a alternativa correta é a certa e o erro das demais."
  }
]
''';

    String text = '';

    if (provider == 'google') {
      try {
        final generModel = GenerativeModel(
          model: model.isNotEmpty ? model : 'gemini-1.5-flash',
          apiKey: key,
          generationConfig: GenerationConfig(
            temperature: 0.4,
            responseMimeType: 'application/json',
          ),
        );
        final response = await generModel.generateContent([Content.text(prompt)]);
        text = response.text ?? '';
      } catch (_) {
        // Fallback direto via REST
        final endpoint = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key',
        );
        final resp = await http.post(
          endpoint,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [{'text': prompt}]
              }
            ],
            'generationConfig': {'temperature': 0.4}
          }),
        );
        final data = jsonDecode(resp.body);
        text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
      }
    } else {
      // Provedores OpenAI-compatible / Anthropic
      text = await _executeRawPrompt(prompt: prompt, systemInstruction: 'Retorne estritamente um array JSON válido.');
    }

    if (text.isEmpty) throw Exception('Resposta vazia da IA.');

    try {
      return await compute(_parseJsonPayload, text);
    } catch (e) {
      debugPrint('Erro ao parsear JSON do simulado: $e \nTexto: $text');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // ASSISTENTE DE ESTUDOS COM TOOL CALLING OU MULTI-PROVEDOR
  // ---------------------------------------------------------------------------
  static Future<String> executeAgentChat({
    required String userMessage,
    required List<Content> history,
  }) async {
    final key = apiKey?.trim() ?? '';
    if (provider != 'custom' && key.isEmpty) {
      return 'Por favor, configure sua chave de API nas Configurações para ativar o assistente Noesis AI.';
    }

    if (provider == 'google') {
      try {
        final logStudyTool = Tool(functionDeclarations: [
          FunctionDeclaration(
            'log_study_session',
            'Registra uma sessão de estudo realizada pelo usuário no banco de dados.',
            Schema(
              SchemaType.object,
              properties: {
                'subject': Schema(SchemaType.string, description: 'Matéria ou disciplina estudada.'),
                'topic': Schema(SchemaType.string, description: 'Tópico específico estudado.'),
                'duration_minutes': Schema(SchemaType.integer, description: 'Tempo total estudado em minutos.'),
                'notes': Schema(SchemaType.string, description: 'Anotações do que foi estudado.'),
              },
              requiredProperties: ['subject', 'topic', 'duration_minutes'],
            ),
          ),
          FunctionDeclaration(
            'schedule_calendar_event',
            'Agenda um compromisso, prova ou bloco de estudos no calendário.',
            Schema(
              SchemaType.object,
              properties: {
                'title': Schema(SchemaType.string, description: 'Título do compromisso.'),
                'start_time_iso': Schema(SchemaType.string, description: 'Data e hora de início no formato ISO 8601.'),
                'duration_minutes': Schema(SchemaType.integer, description: 'Duração estimada em minutos.'),
                'category': Schema(SchemaType.string, description: 'Categoria: study, exam, work, personal.'),
              },
              requiredProperties: ['title', 'start_time_iso'],
            ),
          ),
        ]);

        final googleModel = GenerativeModel(
          model: model.isNotEmpty ? model : 'gemini-1.5-flash',
          apiKey: key,
          tools: [logStudyTool],
          systemInstruction: Content.system(
            'Você é o Noesis AI, o assistente pessoal de alta produtividade e estudos do Aster. '
            'Você ajuda o usuário a gerenciar sua rotina de estudos, registrar tempos estudados, agendar revisões no calendário e tirar dúvidas técnicas. '
            'Quando o usuário pedir para registrar um estudo ("estudei 2h de matemática hoje"), chame log_study_session. '
            'Quando pedir para agendar um evento ("marque uma prova dia tal"), chame schedule_calendar_event. '
            'Seja direto, motivador, conciso e use formatação Markdown elegante.'
          ),
        );

        final chat = googleModel.startChat(history: history);
        var response = await chat.sendMessage(Content.text(userMessage));

        while (response.functionCalls.isNotEmpty) {
          final functionCall = response.functionCalls.first;
          Map<String, Object?> functionResult = {};

          if (functionCall.name == 'log_study_session') {
            try {
              final args = functionCall.args;
              final subject = args['subject'] as String;
              final topic = args['topic'] as String;
              final duration = (args['duration_minutes'] as num).toInt();
              final notes = args['notes'] as String?;

              await SupabaseService.addStudySession(
                subject: subject,
                topic: topic,
                durationMinutes: duration,
                studyDate: DateTime.now(),
                notes: notes,
              );
              functionResult = {'status': 'success', 'message': 'Sessão registrada com sucesso!'};
            } catch (e) {
              functionResult = {'status': 'error', 'message': e.toString()};
            }
          } else if (functionCall.name == 'schedule_calendar_event') {
            try {
              final args = functionCall.args;
              final title = args['title'] as String;
              final startTime = DateTime.parse(args['start_time_iso'] as String);
              final duration = (args['duration_minutes'] as num?)?.toInt() ?? 60;
              final endTime = startTime.add(Duration(minutes: duration));
              final category = (args['category'] as String?) ?? 'study';

              await SupabaseService.addCalendarEvent(
                title: title,
                startTime: startTime,
                endTime: endTime,
                category: category,
              );
              functionResult = {'status': 'success', 'message': 'Evento agendado com sucesso!'};
            } catch (e) {
              functionResult = {'status': 'error', 'message': e.toString()};
            }
          }

          response = await chat.sendMessage(
            Content.functionResponse(functionCall.name, functionResult),
          );
        }

        return response.text ?? 'Ação processada com sucesso!';
      } catch (_) {
        // Fallback caso a SDK direta tenha limitação de modelo
        return await _executeRawPrompt(
          prompt: userMessage,
          systemInstruction:
              'Você é o Noesis AI, agente pessoal de estudos do Aster. Responda de forma clara, amigável e concisa em Markdown.',
        );
      }
    }

    // Para outros provedores (OpenAI, Anthropic, DeepSeek, Grok, etc.)
    return await _executeRawPrompt(
      prompt: userMessage,
      systemInstruction:
          'Você é o Noesis AI, assistente de estudos e alta produtividade do ecossistema Aster. Responda em Markdown conciso e motivador.',
    );
  }

  static Future<String> _executeRawPrompt({
    required String prompt,
    required String systemInstruction,
  }) async {
    final key = apiKey?.trim() ?? '';
    final mod = model.isNotEmpty ? model : 'gpt-4o-mini';

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
          'model': mod,
          'max_tokens': 2048,
          'system': systemInstruction,
          'messages': [
            {'role': 'user', 'content': prompt}
          ]
        }),
      );
      final data = jsonDecode(resp.body);
      return data['content']?[0]?['text'] ?? 'Sem resposta da Anthropic.';
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
        'model': mod,
        'messages': [
          {'role': 'system', 'content': systemInstruction},
          {'role': 'user', 'content': prompt}
        ],
        'temperature': temperature,
        'max_tokens': 2048,
      }),
    );

    final data = jsonDecode(resp.body);
    return data['choices']?[0]?['message']?['content'] ?? 'Sem resposta do provedor.';
  }
}
