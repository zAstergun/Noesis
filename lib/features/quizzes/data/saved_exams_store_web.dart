import 'package:web/web.dart' as web;

Future<String?> readSavedExamsRaw(String key) async {
  try {
    return web.window.localStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

Future<void> writeSavedExamsRaw(String key, String value) async {
  try {
    web.window.localStorage.setItem(key, value);
  } catch (_) {}
}
