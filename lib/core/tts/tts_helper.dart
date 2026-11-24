import 'tts_stub.dart' if (dart.library.js_interop) 'tts_web.dart';

void speakWeb(String text, String lang, {void Function()? onDone}) => platformSpeakWeb(text, lang, onDone: onDone);
void stopWeb() => platformStopWeb();
