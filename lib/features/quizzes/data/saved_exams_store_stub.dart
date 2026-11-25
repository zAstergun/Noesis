String? _memoryCache;

Future<String?> readSavedExamsRaw(String key) async => _memoryCache;

Future<void> writeSavedExamsRaw(String key, String value) async {
  _memoryCache = value;
}
