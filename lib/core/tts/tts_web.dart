import 'dart:js_interop';
import 'package:web/web.dart' as web;

web.SpeechSynthesisVoice? _findBestVoice(web.SpeechSynthesis synth, String targetLang) {
  try {
    final rawVoices = synth.getVoices();
    final voices = rawVoices.toDart;
    if (voices.isEmpty) return null;

    final langPrefix = targetLang.toLowerCase().split(RegExp(r'[-_]')).first;
    web.SpeechSynthesisVoice? fallback;
    web.SpeechSynthesisVoice? naturalFallback;

    for (var i = 0; i < voices.length; i++) {
      final v = voices[i];
      final vLang = v.lang.toLowerCase();
      final vName = v.name.toLowerCase();

      if (vLang.startsWith(langPrefix)) {
        fallback ??= v;

        // Prioriza fortemente vozes neurais / online / Google / Microsoft
        final isNatural = vName.contains('natural') ||
            vName.contains('online') ||
            vName.contains('neural') ||
            vName.contains('google');

        if (isNatural) {
          naturalFallback = v;
          if (vLang.contains(targetLang.toLowerCase())) {
            return v;
          }
        }
      }
    }
    return naturalFallback ?? fallback;
  } catch (_) {
    return null;
  }
}

void platformSpeakWeb(String text, String lang, {void Function()? onDone}) {
  try {
    final synth = web.window.speechSynthesis;
    synth.cancel();
    final utterance = web.SpeechSynthesisUtterance(text);

    final normLang = lang.startsWith('en')
        ? 'en-US'
        : (lang.startsWith('es')
            ? 'es-ES'
            : (lang.startsWith('fr')
                ? 'fr-FR'
                : (lang.startsWith('de')
                    ? 'de-DE'
                    : (lang.startsWith('it') ? 'it-IT' : 'pt-BR'))));

    utterance.lang = normLang;
    utterance.rate = 0.95;
    utterance.pitch = 1.0;

    final bestVoice = _findBestVoice(synth, normLang);
    if (bestVoice != null) {
      utterance.voice = bestVoice;
      utterance.lang = bestVoice.lang;
    }

    if (onDone != null) {
      utterance.onend = ((web.Event _) {
        onDone();
      }).toJS;
      utterance.onerror = ((web.Event _) {
        onDone();
      }).toJS;
    }

    // Se as vozes ainda estiverem sendo inicializadas pelo navegador
    if (bestVoice == null && synth.getVoices().toDart.isEmpty) {
      synth.onvoiceschanged = ((web.Event _) {
        final reloaded = _findBestVoice(synth, normLang);
        if (reloaded != null) {
          utterance.voice = reloaded;
          utterance.lang = reloaded.lang;
        }
        synth.speak(utterance);
      }).toJS;
      return;
    }

    synth.speak(utterance);
  } catch (e) {
    onDone?.call();
  }
}

void platformStopWeb() {
  try {
    web.window.speechSynthesis.cancel();
  } catch (_) {}
}
