import 'dart:io';

final Map<String, String> _testMemoryStore = {};

File _resolveFile(String key) {
  final baseDir = Platform.environment['APPDATA'] ??
      Platform.environment['HOME'] ??
      Directory.systemTemp.path;
  final dir = Directory('$baseDir${Platform.pathSeparator}noesis');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  final safeKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  return File('${dir.path}${Platform.pathSeparator}$safeKey.json');
}

Future<String?> readSavedExamsRaw(String key) async {
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    return _testMemoryStore[key];
  }
  try {
    final file = _resolveFile(key);
    if (!await file.exists()) return null;
    return await file.readAsString();
  } catch (_) {
    return _testMemoryStore[key];
  }
}

Future<void> writeSavedExamsRaw(String key, String value) async {
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    _testMemoryStore[key] = value;
    return;
  }
  try {
    final file = _resolveFile(key);
    await file.writeAsString(value, flush: true);
  } catch (_) {
    _testMemoryStore[key] = value;
  }
}
