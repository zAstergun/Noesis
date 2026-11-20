import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'supabase_service.dart';

class GeminiService {
  // O usuário pode definir sua chave ou podemos ler do ambiente
  static String? apiKey;

  static void initialize(String key) {
    apiKey = key;
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
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception('Chave da API do Google Gemini não configurada.');
    }

    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey!,
      generationConfig: GenerationConfig(
        temperature: 0.4,
        responseMimeType: 'application/json',
      ),
    );

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

    final response = await model.generateContent([Content.text(prompt)]);
    final text = response.text;
    if (text == null) throw Exception('Resposta vazia da IA.');

    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(decoded);
      } else if (decoded is Map && decoded.containsKey('questions')) {
        return List<Map<String, dynamic>>.from(decoded['questions']);
      }
      throw Exception('Formato de JSON inesperado recebido.');
    } catch (e) {
      debugPrint('Erro ao parsear JSON do simulado: $e \nTexto: $text');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // ASSISTENTE DE ESTUDOS COM TOOL CALLING
  // ---------------------------------------------------------------------------
  static Future<String> executeAgentChat({
    required String userMessage,
    required List<Content> history,
  }) async {
    if (apiKey == null || apiKey!.isEmpty) {
      return 'Por favor, insira a sua chave da API do Google Gemini nas configurações para ativar o assistente de IA.';
    }

    // Definição das Ferramentas (Tools / Function Calling)
    final logStudyTool = Tool(functionDeclarations: [
      FunctionDeclaration(
        'log_study_session',
        'Registra uma sessão de estudo realizada pelo usuário no banco de dados.',
        Schema(
          SchemaType.object,
          properties: {
            'subject': Schema(SchemaType.string, description: 'Matéria ou disciplina estudada (ex: Matemática, Cybersegurança, Flutter).'),
            'topic': Schema(SchemaType.string, description: 'Tópico específico estudado (ex: Álgebra Linear, Criptografia RSA).'),
            'duration_minutes': Schema(SchemaType.integer, description: 'Tempo total estudado em minutos.'),
            'notes': Schema(SchemaType.string, description: 'Anotações ou resumo do que foi estudado.'),
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
            'title': Schema(SchemaType.string, description: 'Título do compromisso ou evento.'),
            'start_time_iso': Schema(SchemaType.string, description: 'Data e hora de início no formato ISO 8601 (ex: 2026-11-25T14:00:00Z).'),
            'duration_minutes': Schema(SchemaType.integer, description: 'Duração estimada em minutos.'),
            'category': Schema(SchemaType.string, description: 'Categoria: study, exam, work, personal.'),
          },
          requiredProperties: ['title', 'start_time_iso'],
        ),
      ),
      FunctionDeclaration(
        'get_study_summary',
        'Consulta as últimas sessões de estudo do usuário para gerar métricas e resumos.',
        Schema(SchemaType.object, properties: {}),
      ),
    ]);

    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey!,
      tools: [logStudyTool],
      systemInstruction: Content.system(
        'Você é o Noesis AI, o agente pessoal de alta produtividade e estudos do Aster. '
        'Você ajuda o usuário a gerenciar sua rotina de estudos, registrar tempos estudados, agendar revisões no calendário e tirar dúvidas técnicas. '
        'Quando o usuário pedir para registrar um estudo ("estudei 2h de matemática hoje"), chame a ferramenta log_study_session. '
        'Quando pedir para agendar um evento ("marque uma prova dia tal"), chame schedule_calendar_event. '
        'Seja direto, motivador, conciso e use formatação Markdown elegante.'
      ),
    );

    final chat = model.startChat(history: history);
    var response = await chat.sendMessage(Content.text(userMessage));

    // Processar chamadas de ferramenta (Tool Calling)
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
          functionResult = {'status': 'success', 'message': 'Sessão de estudo registrada com sucesso no Noesis!'};
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
          functionResult = {'status': 'success', 'message': 'Evento agendado com sucesso no calendário!'};
        } catch (e) {
          functionResult = {'status': 'error', 'message': e.toString()};
        }
      } else if (functionCall.name == 'get_study_summary') {
        try {
          final sessions = await SupabaseService.getStudySessions(limit: 10);
          functionResult = {'sessions': sessions};
        } catch (e) {
          functionResult = {'error': e.toString()};
        }
      }

      // Envia a resposta da ferramenta de volta ao Gemini
      response = await chat.sendMessage(
        Content.functionResponse(functionCall.name, functionResult),
      );
    }

    return response.text ?? 'Ação processada com sucesso!';
  }
}
