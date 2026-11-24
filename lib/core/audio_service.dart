import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'gemini_service.dart';
import 'tts/tts_helper.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal() {
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (!isTest) {
      _initPlayer();
    }
  }

  AudioPlayer? _player;
  final ValueNotifier<String?> currentlyPlayingUrl = ValueNotifier<String?>(null);
  final ValueNotifier<PlayerState> playerState = ValueNotifier<PlayerState>(PlayerState.stopped);

  void _initPlayer() {
    try {
      _player = AudioPlayer();
      _player!.onPlayerStateChanged.listen((state) {
        playerState.value = state;
        if (state == PlayerState.completed || state == PlayerState.stopped) {
          currentlyPlayingUrl.value = null;
        }
      });
    } catch (e) {
      debugPrint('AudioPlayer platform events not available in this environment: $e');
    }
  }

  /// Toca um áudio a partir de Data URI (base64), URL web, caminho de arquivo ou sintetizador de fala
  Future<void> playAudio(String audioSource) async {
    try {
      // Se já estiver tocando o mesmo áudio, pausa/para
      if (currentlyPlayingUrl.value == audioSource && playerState.value == PlayerState.playing) {
        await stopAudio();
        return;
      }

      await stopAudio();
      currentlyPlayingUrl.value = audioSource;
      playerState.value = PlayerState.playing;

      // Suporte para narração de voz / sintetizador nativo
      if (audioSource.startsWith('speech:')) {
        final firstColon = audioSource.indexOf(':');
        final secondColon = audioSource.indexOf(':', firstColon + 1);
        final String lang;
        final String text;
        if (secondColon != -1) {
          lang = audioSource.substring(firstColon + 1, secondColon);
          text = audioSource.substring(secondColon + 1);
        } else {
          lang = 'pt-BR';
          text = audioSource.substring(firstColon + 1);
        }

        if (kIsWeb) {
          speakWeb(text, lang, onDone: () {
            if (currentlyPlayingUrl.value == audioSource) {
              currentlyPlayingUrl.value = null;
              playerState.value = PlayerState.stopped;
            }
          });
          return;
        } else {
          // No Desktop/Mobile, converte o texto para MP3 via Google Neural TTS de alta fidelidade
          final ttsUrl = Uri.parse(
            'https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=$lang&q=${Uri.encodeComponent(text.length > 220 ? text.substring(0, 220).trim() : text)}',
          );
          try {
            final response = await http.get(
              ttsUrl,
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                'Referer': 'https://translate.google.com/',
              },
            ).timeout(const Duration(seconds: 10));

            if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
              await _player?.play(BytesSource(response.bodyBytes));
              return;
            }
          } catch (e) {
            debugPrint('Erro ao reproduzir speech no desktop: $e');
          }
        }
      }

      if (_player != null) {
        if (audioSource.startsWith('data:audio')) {
          // Extrai bytes base64 do Data URI
          final commaIdx = audioSource.indexOf(',');
          final base64Str = commaIdx != -1 ? audioSource.substring(commaIdx + 1) : audioSource;
          final bytes = base64Decode(base64Str);
          await _player!.play(BytesSource(Uint8List.fromList(bytes)));
        } else if (audioSource.startsWith('http://') || audioSource.startsWith('https://')) {
          await _player!.play(UrlSource(audioSource));
        } else {
          await _player!.play(DeviceFileSource(audioSource));
        }
      }
    } catch (e) {
      debugPrint('Erro ao reproduzir áudio: $e');
      currentlyPlayingUrl.value = null;
      playerState.value = PlayerState.stopped;
    }
  }

  Future<void> stopAudio() async {
    try {
      stopWeb();
      await _player?.stop();
      currentlyPlayingUrl.value = null;
      playerState.value = PlayerState.stopped;
    } catch (_) {}
  }

  /// Gera áudio narrado por IA usando OpenAI TTS (alta fidelidade) ou Google Neural / Web Speech (fallback zero-config)
  static Future<String?> generateAiSpeech({
    required String text,
    String? language,
    String voice = 'alloy',
  }) async {
    final cleanText = text.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleanText.isEmpty) return null;

    // Detectar idioma
    final lang = language ?? _detectLanguage(cleanText);

    // 1. Tentar OpenAI TTS se houver chave e provedor compatível
    final key = GeminiService.apiKey?.trim() ?? '';
    if (key.isNotEmpty && (GeminiService.provider == 'openai' || GeminiService.provider == 'custom' || key.startsWith('sk-'))) {
      try {
        final uri = Uri.parse(
          GeminiService.baseUrl.isNotEmpty ? '${GeminiService.baseUrl}/audio/speech' : 'https://api.openai.com/v1/audio/speech',
        );
        final response = await http.post(
          uri,
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'tts-1',
            'input': cleanText,
            'voice': voice,
            'response_format': 'mp3',
          }),
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          final b64 = base64Encode(response.bodyBytes);
          return 'data:audio/mp3;base64,$b64';
        }
      } catch (e) {
        debugPrint('Fallback de áudio da OpenAI falhou: $e. Usando neural TTS direto.');
      }
    }

    // 2. No Web, a API de Speech Synthesis do navegador é nativa, imediata e sem falhas de CORS
    if (kIsWeb) {
      return 'speech:$lang:$cleanText';
    }

    // 3. Provedor de TTS Neural Universal e Gratuito (Zero Chaves / Funciona Imediatamente em Alta Qualidade)
    final speakSnippet = cleanText.length > 220 ? cleanText.substring(0, 220).trim() : cleanText;
    final ttsUrl = Uri.parse(
      'https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=$lang&q=${Uri.encodeComponent(speakSnippet)}',
    );

    try {
      final response = await http.get(
        ttsUrl,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Referer': 'https://translate.google.com/',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final b64 = base64Encode(response.bodyBytes);
        return 'data:audio/mp3;base64,$b64';
      }
    } catch (e) {
      debugPrint('Erro ao obter bytes do TTS Universal: $e.');
    }

    return 'speech:$lang:$cleanText';
  }

  /// Detecta com precisão o idioma do texto (inglês, português, espanhol, etc.)
  static String detectLanguage(String text) {
    final lower = text.toLowerCase();

    // 1. Verificação de caracteres e acentos típicos
    final ptAccentMatches = RegExp(r'[ãõáéíóúâêôàç]').allMatches(lower).length;
    final esAccentMatches = RegExp(r'[ñ¿¡]').allMatches(lower).length;

    // 2. Extração de palavras e tokens limpos
    final words = lower.split(RegExp(r'[^a-z0-9áéíóúâêôãõàçñ]+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'pt-BR';

    int enScore = 0;
    int ptScore = ptAccentMatches * 3;
    int esScore = esAccentMatches * 4;

    // Vocabulário frequente em inglês
    const enVocab = {
      'the', 'be', 'to', 'of', 'and', 'a', 'in', 'that', 'have', 'i', 'it', 'for', 'not', 'on', 'with',
      'he', 'as', 'you', 'do', 'at', 'this', 'but', 'his', 'by', 'from', 'they', 'we', 'say', 'her',
      'she', 'or', 'an', 'will', 'my', 'one', 'all', 'would', 'there', 'their', 'what', 'so', 'up',
      'out', 'if', 'about', 'who', 'get', 'which', 'go', 'me', 'when', 'make', 'can', 'like', 'time',
      'no', 'just', 'him', 'know', 'take', 'people', 'into', 'year', 'your', 'good', 'some', 'could',
      'them', 'see', 'other', 'than', 'then', 'now', 'look', 'only', 'come', 'its', 'over', 'think',
      'also', 'back', 'after', 'use', 'two', 'how', 'our', 'work', 'first', 'well', 'way', 'even',
      'new', 'want', 'because', 'any', 'these', 'give', 'day', 'most', 'us', 'is', 'are', 'was',
      'were', 'been', 'has', 'had', 'did', 'does', 'speak', 'english', 'learn', 'grammar', 'read',
      'write', 'sentence', 'vocabulary', 'listen', 'hear', 'talk', 'tell', 'question', 'answer',
      'hello', 'bye', 'goodbye', 'morning', 'night', 'thank', 'thanks', 'please', 'welcome', 'sorry',
      'water', 'food', 'world', 'life', 'friend', 'house', 'car', 'city', 'country', 'study', 'why',
      'cloud', 'security', 'network', 'system', 'data', 'database', 'key', 'encryption', 'user', 'app'
    };

    // Expressões e contrações típicas em inglês
    if (RegExp(r"\b(i'm|don't|can't|won't|it's|you're|we're|they're|i've|i'll|doesn't|didn't|isn't|aren't)\b").hasMatch(lower)) {
      enScore += 5;
    }

    // Vocabulário frequente em português
    const ptVocab = {
      'o', 'a', 'os', 'as', 'um', 'uma', 'uns', 'umas', 'de', 'do', 'da', 'dos', 'das', 'em', 'no',
      'na', 'nos', 'nas', 'para', 'por', 'com', 'sem', 'sob', 'sobre', 'que', 'se', 'mas', 'ou',
      'como', 'quando', 'onde', 'porque', 'porquê', 'mais', 'menos', 'muito', 'pouco', 'já', 'ainda',
      'sempre', 'nunca', 'sim', 'não', 'ele', 'ela', 'eles', 'elas', 'eu', 'você', 'vocês', 'nós',
      'meu', 'minha', 'meus', 'minhas', 'seu', 'sua', 'seus', 'suas', 'nosso', 'nossa', 'nossos',
      'nossas', 'este', 'esta', 'estes', 'estas', 'esse', 'essa', 'esses', 'essas', 'isto', 'isso',
      'aquilo', 'ser', 'estar', 'ter', 'haver', 'fazer', 'ir', 'dizer', 'dar', 'ver', 'saber',
      'poder', 'querer', 'falar', 'português', 'estudo', 'resposta', 'pergunta', 'é', 'são', 'foi',
      'está', 'estão', 'tem', 'têm', 'chave', 'simétrica', 'assimétrica', 'sociedade', 'vazamento',
      'rede', 'segurança', 'banco', 'dados', 'servidor', 'troca', 'privada', 'pública', 'compartilhada'
    };

    // Vocabulário comum em espanhol
    const esVocab = {
      'el', 'los', 'las', 'del', 'al', 'con', 'sin', 'pero', 'por', 'para', 'como', 'cuando', 'donde',
      'porque', 'más', 'menos', 'muy', 'poco', 'ya', 'siempre', 'nunca', 'sí', 'no', 'yo', 'él', 'ella',
      'ellos', 'ellas', 'usted', 'ustedes', 'nosotros', 'mi', 'mis', 'tu', 'tus', 'su', 'sus', 'nuestro'
    };

    for (final word in words) {
      if (enVocab.contains(word)) enScore += 2;
      if (ptVocab.contains(word)) ptScore += 2;
      if (esVocab.contains(word)) esScore += 2;
    }

    if (esScore > enScore && esScore > ptScore) return 'es-ES';
    if (enScore > ptScore) return 'en-US';
    return 'pt-BR';
  }

  static String _detectLanguage(String text) => detectLanguage(text);
}
