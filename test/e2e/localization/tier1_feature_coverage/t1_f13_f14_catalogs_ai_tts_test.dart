import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/audio_service.dart';
import 'package:noesis/core/gemini_service.dart';
import 'package:noesis/core/localization/noesis_locale_service.dart';
import 'package:noesis/core/noesis_agent_tools.dart';
import 'package:noesis/core/tts/tts_helper.dart' as tts_helper;
import 'package:noesis/features/flashcards/models/flashcard_model.dart';
import 'package:noesis/features/flashcards/utils/deck_file_importer.dart';
import 'package:noesis/features/quizzes/data/exam_models_catalog.dart';
import 'package:noesis/features/roadmaps/models/roadmap_model.dart';

import '../../harness/mock_http_overrides.dart';
import '../helpers/localization_test_helpers.dart';

class _CapturingHttpOverrides extends HttpOverrides {
  _CapturingHttpOverrides(this.capturedBodies);

  final List<String> capturedBodies;
  final HttpOverrides _delegate = MockHttpOverrides();

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _CapturingHttpClient(
      _delegate.createHttpClient(context),
      capturedBodies,
    );
  }
}

class _CapturingHttpClient implements HttpClient {
  _CapturingHttpClient(this._inner, this.capturedBodies);

  final HttpClient _inner;
  final List<String> capturedBodies;

  @override
  bool get autoUncompress => _inner.autoUncompress;
  @override
  set autoUncompress(bool value) => _inner.autoUncompress = value;

  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;
  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;

  @override
  Duration get idleTimeout => _inner.idleTimeout;
  @override
  set idleTimeout(Duration value) => _inner.idleTimeout = value;

  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;
  @override
  set maxConnectionsPerHost(int? value) => _inner.maxConnectionsPerHost = value;

  @override
  String? get userAgent => _inner.userAgent;
  @override
  set userAgent(String? value) => _inner.userAgent = value;

  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials credentials) =>
      _inner.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(
    String host,
    int port,
    String realm,
    HttpClientCredentials credentials,
  ) =>
      _inner.addProxyCredentials(host, port, realm, credentials);

  @override
  set authenticate(
    Future<bool> Function(Uri url, String realm, String? account)? f,
  ) =>
      _inner.authenticate = f;

  @override
  set authenticateProxy(
    Future<bool> Function(String host, int port, String realm, String? account)?
        f,
  ) =>
      _inner.authenticateProxy = f;

  @override
  set badCertificateCallback(
    bool Function(X509Certificate cert, String host, int port)? callback,
  ) =>
      _inner.badCertificateCallback = callback;

  @override
  set findProxy(String Function(Uri url)? f) => _inner.findProxy = f;

  @override
  set connectionFactory(
    Future<ConnectionTask<Socket>> Function(Uri url, String? proxyHost, int? proxyPort)? f,
  ) =>
      _inner.connectionFactory = f;

  @override
  set keyLog(Function(String line)? callback) => _inner.keyLog = callback;

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  Future<HttpClientRequest> open(
    String method,
    String host,
    int port,
    String path,
  ) =>
      openUrl(method, Uri(scheme: 'http', host: host, port: port, path: path));

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final innerReq = await _inner.openUrl(method, url);
    return _CapturingHttpClientRequest(innerReq, capturedBodies);
  }

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      open('GET', host, port, path);
  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      open('POST', host, port, path);
  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);
  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      open('PUT', host, port, path);
  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);
  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      open('DELETE', host, port, path);
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);
  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      open('PATCH', host, port, path);
  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);
  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      open('HEAD', host, port, path);
  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);
}

class _CapturingHttpClientRequest implements HttpClientRequest {
  _CapturingHttpClientRequest(this._inner, this.capturedBodies);

  final HttpClientRequest _inner;
  final List<String> capturedBodies;
  final List<int> _buffer = [];
  bool _recorded = false;

  void _flushCapturedBody() {
    if (_recorded) return;
    _recorded = true;
    capturedBodies.add(utf8.decode(_buffer, allowMalformed: true));
  }

  @override
  bool get bufferOutput => _inner.bufferOutput;
  @override
  set bufferOutput(bool value) => _inner.bufferOutput = value;

  @override
  int get contentLength => _inner.contentLength;
  @override
  set contentLength(int value) => _inner.contentLength = value;

  @override
  Encoding get encoding => _inner.encoding;
  @override
  set encoding(Encoding value) => _inner.encoding = value;

  @override
  bool get followRedirects => _inner.followRedirects;
  @override
  set followRedirects(bool value) => _inner.followRedirects = value;

  @override
  int get maxRedirects => _inner.maxRedirects;
  @override
  set maxRedirects(int value) => _inner.maxRedirects = value;

  @override
  bool get persistentConnection => _inner.persistentConnection;
  @override
  set persistentConnection(bool value) => _inner.persistentConnection = value;

  @override
  HttpHeaders get headers => _inner.headers;

  @override
  HttpConnectionInfo? get connectionInfo => _inner.connectionInfo;

  @override
  List<Cookie> get cookies => _inner.cookies;

  @override
  String get method => _inner.method;

  @override
  Uri get uri => _inner.uri;

  @override
  void add(List<int> data) {
    _buffer.addAll(data);
    _inner.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    final chunks = <int>[];
    await for (final chunk in stream) {
      chunks.addAll(chunk);
    }
    _buffer.addAll(chunks);
    await _inner.addStream(Stream.value(chunks));
  }

  @override
  Future<HttpClientResponse> close() {
    _flushCapturedBody();
    return _inner.close();
  }

  @override
  Future<HttpClientResponse> get done => _inner.done;

  @override
  Future<void> flush() => _inner.flush();

  @override
  void write(Object? obj) {
    _buffer.addAll(utf8.encode(obj.toString()));
    _inner.write(obj);
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    _buffer.addAll(utf8.encode(objects.join(separator)));
    _inner.writeAll(objects, separator);
  }

  @override
  void writeCharCode(int charCode) {
    _buffer.add(charCode);
    _inner.writeCharCode(charCode);
  }

  @override
  void writeln([Object? obj = '']) {
    _buffer.addAll(utf8.encode('$obj\n'));
    _inner.writeln(obj);
  }

  @override
  void abort([Object? exception, StackTrace? stackTrace]) =>
      _inner.abort(exception, stackTrace);
}

void main() {
  setUpAll(() => LocalizationTestHelpers.setUpSuite());

  setUp(() => LocalizationTestHelpers.resetState());

  tearDown(() => LocalizationTestHelpers.resetState());

  group('F13 — Static Catalogs, Offline Templates & TTS', () {
    test(
      'F13-T1: ExamModelsCatalog exposes 8 categories and 39 models with valid blueprint assets & localized labels',
      () async {
        await NoesisLocaleService.setLanguage('en');

        expect(ExamCategory.values.length, equals(8));
        expect(ExamModelsCatalog.models.length, equals(39));

        for (final category in ExamCategory.values) {
          expect(
            LocalizationTestHelpers.containsPortugueseLeakage(category.label),
            isFalse,
            reason: 'ExamCategory.${category.name} leaked Portuguese: ${category.label}',
          );
        }
        expect(ExamCategory.all.label, isNot('Todos'));

        final firstModel = ExamModelsCatalog.models.first;
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(firstModel.summary),
          isFalse,
          reason: 'Exam model ${firstModel.id} summary leaked Portuguese: ${firstModel.summary}',
        );

        final blueprint = await ExamModelsCatalog.loadBlueprint(firstModel);
        expect(blueprint, isNotNull);
        expect(blueprint!.trim(), isNotEmpty);
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(blueprint),
          isFalse,
          reason: 'Loaded blueprint for ${firstModel.id} leaked Portuguese',
        );
      },
    );

    test(
      'F13-T2: ExamModelTemplate.formatBatchSectionDirective localizes section directives in English/Japanese',
      () async {
        final model = ExamModelsCatalog.models.first;

        for (final code in ['en', 'jp']) {
          await NoesisLocaleService.setLanguage(code);
          final directive = model.formatBatchSectionDirective(
            totalTarget: 10,
            startNumber: 1,
            batchCount: 4,
          );
          expect(directive.trim(), isNotEmpty);
          expect(directive, isNot(contains('ORDEM SEQUENCIAL OBRIGATÓRIA')));
          expect(directive, isNot(contains('obrigatoriamente da disciplina')));
          expect(
            LocalizationTestHelpers.containsPortugueseLeakage(directive),
            isFalse,
            reason: 'Section directive leaked Portuguese for locale $code',
          );
        }
      },
    );

    test(
      'F13-T3: RoadmapModel, FlashcardModel, and DeckFileImporter default/fallback labels localize across locales',
      () async {
        await NoesisLocaleService.setLanguage('en');

        final emptyRoadmap = StudyRoadmap.fromJson({});
        final emptyStep = RoadmapStep.fromJson({}, fallbackIndex: 0);
        final emptyDeck = FlashcardDeck.fromMap({});
        final hardCard = Flashcard(
          id: 'c1',
          front: 'What is TLS 1.3?',
          back: 'Transport Layer Security 1.3',
          difficulty: 'hard',
        );
        final parsedDeck = DeckFileImporter.parse(
          'untitled.txt',
          utf8.encode('front\tback\nf2\tb2'),
        );

        expect(emptyRoadmap.title, isNot('Trilha de Estudos'));
        expect(emptyStep.title, isNot('Etapa 1'));
        expect(emptyDeck.title, isNot('Novo Baralho'));
        expect(hardCard.reviewReason(), isNot('Difícil · reforçar'));
        expect(RoadmapStepStatus.todo.label, isNot('A fazer'));

        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(
            '${emptyRoadmap.title} ${emptyStep.title} ${emptyDeck.title} '
            '${hardCard.reviewReason()} ${RoadmapStepStatus.todo.label} '
            '${parsedDeck.suggestedSubject}',
          ),
          isFalse,
        );
      },
    );

    test(
      'F13-T4: AudioService.detectLanguage identifies multilingual samples across scripts and European languages',
      () {
        expect(AudioService.detectLanguage('日本語の勉強をしています'), startsWith('ja'));
        expect(AudioService.detectLanguage('学习人工智能和数据结构'), startsWith('zh'));
        expect(AudioService.detectLanguage('한국어 공부를 시작합니다'), startsWith('ko'));
        expect(AudioService.detectLanguage('مرحبا بكم في التعليم'), startsWith('ar'));
        expect(AudioService.detectLanguage('Привет мир обучение'), startsWith('ru'));
        expect(
          AudioService.detectLanguage('The network security system uses encryption'),
          startsWith('en'),
        );
        expect(
          AudioService.detectLanguage('El sistema de seguridad usa cifrado'),
          startsWith('es'),
        );
        expect(
          AudioService.detectLanguage('A segurança de rede utiliza criptografia'),
          startsWith('pt'),
        );
        expect(
          AudioService.detectLanguage('Bonjour, comment allez-vous aujourd hui'),
          startsWith('fr'),
        );
        expect(
          AudioService.detectLanguage('Guten Morgen, das ist ein Studium'),
          startsWith('de'),
        );
      },
    );

    test(
      'F13-T5: AudioService.generateAiSpeech returns TTS audio URI hermetically under MockHttpOverrides and VM stub is safe',
      () async {
        final prevProvider = GeminiService.provider;
        final prevKey = GeminiService.apiKey;
        addTearDown(() {
          GeminiService.provider = prevProvider;
          GeminiService.apiKey = prevKey;
        });

        GeminiService.provider = 'google';
        GeminiService.apiKey = null;

        MockHttpOverrides.customResponseBody = '';
        final speechFallback = await AudioService.generateAiSpeech(
          text: 'Bonjour monde',
          language: 'fr-FR',
        );
        expect(speechFallback, equals('speech:fr-FR:Bonjour monde'));

        MockHttpOverrides.customResponseBody = 'FAKE_MP3_BYTES';
        final dataUri = await AudioService.generateAiSpeech(
          text: 'Bonjour monde',
          language: 'fr-FR',
        );
        expect(dataUri, startsWith('data:audio/mp3;base64,'));

        // VM conditional stub must remain safe to invoke.
        tts_helper.speakWeb('Hello', 'en-GB');
        tts_helper.stopWeb();
      },
    );

    test(
      'F13-T6: tts_web.dart source maps all 15 supported language prefixes and distinguishes pt-BR vs pt-PT (static verification)',
      () {
        final ttsWebSource = LocalizationTestHelpers.readProjectFile(
          'lib/core/tts/tts_web.dart',
        );
        final speakFnStart = ttsWebSource.indexOf('void platformSpeakWeb');
        expect(speakFnStart, greaterThanOrEqualTo(0));
        final speakFnSource = ttsWebSource.substring(speakFnStart);

        // Explicitly verify pt-PT and pt-BR are mapped distinctly and pt-PT is matched before generic pt -> pt-BR.
        final ptPtInputMatch = RegExp(
          r'''startsWith\(\s*['"]pt[-_]pt['"]\s*\)''',
          caseSensitive: false,
        ).firstMatch(speakFnSource);
        final ptPtTargetMatch = RegExp(r'''['"]pt-PT['"]''').firstMatch(speakFnSource);
        final ptBrTargetMatch = RegExp(r'''['"]pt-BR['"]''').firstMatch(speakFnSource);
        expect(
          ptPtInputMatch,
          isNotNull,
          reason: 'lib/core/tts/tts_web.dart must explicitly handle pt-PT / pt_pt',
        );
        expect(
          ptPtTargetMatch,
          isNotNull,
          reason: 'lib/core/tts/tts_web.dart must emit pt-PT for European Portuguese',
        );
        expect(
          ptBrTargetMatch,
          isNotNull,
          reason: 'lib/core/tts/tts_web.dart must emit pt-BR for Brazilian Portuguese',
        );
        expect(
          ptPtInputMatch!.start,
          lessThan(ptBrTargetMatch!.start),
          reason: 'pt-PT check must precede pt-BR fallback so pt-PT is not collapsed into pt-BR',
        );
        expect(
          ptPtTargetMatch!.start,
          lessThan(ptBrTargetMatch.start),
          reason: 'pt-PT target must precede pt-BR fallback branch',
        );

        final other13Prefixes = <String>[
          'en',
          'es',
          'ja',
          'zh',
          'ko',
          'vi',
          'id',
          'fr',
          'de',
          'it',
          'nl',
          'ru',
          'ar',
        ];
        for (final prefix in other13Prefixes) {
          final hasMapping = RegExp(
            "['\"]$prefix(?:[-_][a-zA-Z]+)?['\"]",
          ).hasMatch(speakFnSource);
          expect(
            hasMapping,
            isTrue,
            reason: 'lib/core/tts/tts_web.dart is missing mapping for "$prefix"',
          );
        }
      },
    );
  });

  group('F14 — AI Prompts & Agent Tools', () {
    test(
      'F14-T1: GeminiService injects active locale into outbound chat and note-formatting payloads',
      () async {
        final prevProvider = GeminiService.provider;
        final prevKey = GeminiService.apiKey;
        final prevModel = GeminiService.model;
        final capturedBodies = <String>[];
        HttpOverrides.global = _CapturingHttpOverrides(capturedBodies);
        addTearDown(() {
          GeminiService.provider = prevProvider;
          GeminiService.apiKey = prevKey;
          GeminiService.model = prevModel;
          MockHttpOverrides.install();
        });

        GeminiService.provider = 'openai';
        GeminiService.apiKey = 'test-openai-key';
        GeminiService.model = 'gpt-4o-mini';
        MockHttpOverrides.customResponseBody = jsonEncode({
          'choices': [
            {
              'message': {'content': '# Formatted Study Note\n\n- Key concept'},
            },
          ],
        });

        for (final entry in {'en': 'English', 'jp': 'Japanese'}.entries) {
          await NoesisLocaleService.setLanguage(entry.key);

          capturedBodies.clear();
          await GeminiService.executeAgentChat(
            userMessage: 'Hello tutor',
            history: const [],
          );
          final chatBodies = List<String>.from(capturedBodies);
          expect(
            chatBodies,
            isNotEmpty,
            reason:
                'executeAgentChat must issue an outbound HTTP request for ${entry.key}',
          );
          for (var i = 0; i < chatBodies.length; i++) {
            final body = chatBodies[i];
            expect(
              body,
              contains(entry.value),
              reason:
                  'executeAgentChat request #$i missing active language ${entry.value}',
            );
            expect(
              body.toLowerCase(),
              isNot(contains('português')),
              reason:
                  'executeAgentChat request #$i contained "português" for ${entry.key}',
            );
            expect(
              LocalizationTestHelpers.containsPortugueseLeakage(body),
              isFalse,
              reason:
                  'executeAgentChat request #$i leaked Portuguese for ${entry.key}: $body',
            );
          }

          capturedBodies.clear();
          await GeminiService.formatStudyNote(
            rawText: 'TCP three-way handshake uses SYN, SYN-ACK, and ACK.',
          );
          final noteBodies = List<String>.from(capturedBodies);
          expect(
            noteBodies,
            isNotEmpty,
            reason:
                'formatStudyNote must issue an outbound HTTP request for ${entry.key}',
          );
          for (var i = 0; i < noteBodies.length; i++) {
            final body = noteBodies[i];
            expect(
              body,
              contains(entry.value),
              reason:
                  'formatStudyNote request #$i missing active language ${entry.value}',
            );
            expect(
              body.toLowerCase(),
              isNot(contains('português')),
              reason:
                  'formatStudyNote request #$i contained "português" for ${entry.key}',
            );
            expect(
              LocalizationTestHelpers.containsPortugueseLeakage(body),
              isFalse,
              reason:
                  'formatStudyNote request #$i leaked Portuguese for ${entry.key}: $body',
            );
          }
        }
      },
    );

    test(
      'F14-T2: GeminiService autonomous offline fallbacks localize output when API key is empty',
      () async {
        final prevProvider = GeminiService.provider;
        final prevKey = GeminiService.apiKey;
        addTearDown(() {
          GeminiService.provider = prevProvider;
          GeminiService.apiKey = prevKey;
        });

        GeminiService.provider = 'google';
        GeminiService.apiKey = null;
        await NoesisLocaleService.setLanguage('en');

        final chatReply = await GeminiService.executeAgentChat(
          userMessage: 'Help me study',
          history: const [],
        );
        expect(chatReply, isNot(contains('configure sua chave de API')));
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(chatReply),
          isFalse,
        );

        final quiz = await GeminiService.generateQuizBatch(
          subject: 'Mathematics',
          topic: 'Linear Algebra',
          batchCount: 2,
          totalTarget: 2,
          startNumber: 1,
          batchIndex: 0,
          difficulty: 'Medium',
        );
        expect(quiz, isNotEmpty);
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(jsonEncode(quiz)),
          isFalse,
        );

        final flashcards = await GeminiService.generateFlashcards(
          subject: 'Mathematics',
          topic: 'Linear Algebra',
          count: 2,
        );
        expect(flashcards, isNotEmpty);
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(
            jsonEncode(flashcards),
          ),
          isFalse,
        );

        final roadmap = await GeminiService.generateStudyRoadmap(
          goal: 'Master Linear Algebra',
          subject: 'Mathematics',
        );
        expect(roadmap.steps, isNotEmpty);
        final roadmapText =
            '${roadmap.title} ${roadmap.steps.map((s) => '${s.title} ${s.description}').join(' ')}';
        expect(roadmapText, isNot(contains('Etapa 1')));
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(roadmapText),
          isFalse,
        );
      },
    );

    test(
      'F14-T3: NoesisAgentTools.googleRestFunctionDeclarations preserves 20 tools with localized descriptions',
      () async {
        await NoesisLocaleService.setLanguage('en');

        final declarations = NoesisAgentTools.googleRestFunctionDeclarations;
        expect(declarations.length, equals(20));

        final serialized = jsonEncode(declarations);
        expect(
          serialized,
          isNot(contains('Lê e revisa itens reais da conta')),
        );
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(serialized),
          isFalse,
        );
      },
    );

    test(
      'F14-T4: NoesisAgentTools contextual quick suggestions and calendar recommendations localize in English',
      () async {
        await NoesisLocaleService.setLanguage('en');

        final suggestions =
            await NoesisAgentTools.buildContextualQuickSuggestions();
        expect(suggestions, isNotEmpty);
        for (final s in suggestions) {
          expect(s.label, isNot(contains('Plano de estudo de hoje')));
          expect(
            LocalizationTestHelpers.containsPortugueseLeakage(
              '${s.label} ${s.prompt} ${s.tooltip ?? ''}',
            ),
            isFalse,
            reason: 'Quick suggestion ${s.id} leaked Portuguese: ${s.label}',
          );
        }

        final recommendations =
            await NoesisAgentTools.buildCalendarRecommendations(
          calendarEvents: const [],
          now: DateTime(2026, 11, 27, 9),
        );
        expect(recommendations, isNotEmpty);
        for (final r in recommendations) {
          expect(r.message, isNot(contains('Hoje')));
          expect(r.message, isNot(contains('Amanhã')));
          expect(
            LocalizationTestHelpers.containsPortugueseLeakage(
              '${r.message} ${r.eventTitle} ${r.eventDescription}',
            ),
            isFalse,
            reason: 'Calendar recommendation ${r.id} leaked Portuguese: ${r.message}',
          );
        }
      },
    );

    test(
      'F14-T5: NoesisAgentTools.parseNaturalDateTime and NoesisAttachment.iconLabel support localized inputs and labels',
      () async {
        await NoesisLocaleService.setLanguage('en');

        const attachment = NoesisAttachment(
          id: 'att-1',
          kind: 'notebook',
          title: 'Notes',
          subtitle: 'Algebra',
          content: 'Matrix multiplication',
        );
        expect(attachment.iconLabel, isNot('Caderno'));
        expect(
          LocalizationTestHelpers.containsPortugueseLeakage(
            attachment.iconLabel,
          ),
          isFalse,
        );

        final parsed = NoesisAgentTools.parseNaturalDateTime(
          'tomorrow at 3pm',
          now: DateTime(2026, 11, 27, 9),
        );
        expect(parsed.year, equals(2026));
        expect(parsed.month, equals(11));
        expect(parsed.day, equals(28));
        expect(parsed.hour, equals(15));
        expect(parsed.minute, equals(0));
      },
    );
  });
}
