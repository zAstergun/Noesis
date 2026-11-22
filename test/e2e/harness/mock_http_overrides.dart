import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Hermetic HttpOverrides that intercepts all network requests.
/// Prevents socket leaks and can mock Gemini or Supabase HTTP responses.
class MockHttpOverrides extends HttpOverrides {
  static final List<Uri> recordedRequests = [];
  static String? customResponseBody;
  static int customStatusCode = 200;

  static void install() {
    HttpOverrides.global = MockHttpOverrides();
  }

  static void reset() {
    recordedRequests.clear();
    customResponseBody = null;
    customStatusCode = 200;
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
}

class _MockHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials credentials) {}

  @override
  void addProxyCredentials(String host, int port, String realm, HttpClientCredentials credentials) {}

  @override
  set authenticate(Future<bool> Function(Uri url, String realm, String? account)? f) {}

  @override
  set authenticateProxy(Future<bool> Function(String host, int port, String realm, String? account)? f) {}

  @override
  set badCertificateCallback(bool Function(X509Certificate cert, String host, int port)? callback) {}

  @override
  set findProxy(String Function(Uri url)? f) {}

  @override
  set connectionFactory(void Function(Uri url, String? proxyHost, int? proxyPort)? f) {}

  @override
  set keyLog(Function(String line)? callback) {}

  @override
  void close({bool force = false}) {}

  @override
  Future<HttpClientRequest> open(String method, String host, int port, String path) {
    return openUrl(method, Uri(scheme: 'http', host: host, port: port, path: path));
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    MockHttpOverrides.recordedRequests.add(url);
    return _MockHttpClientRequest(method, url);
  }

  @override
  Future<HttpClientRequest> get(String host, int port, String path) => open('GET', host, port, path);
  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
  @override
  Future<HttpClientRequest> post(String host, int port, String path) => open('POST', host, port, path);
  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);
  @override
  Future<HttpClientRequest> put(String host, int port, String path) => open('PUT', host, port, path);
  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);
  @override
  Future<HttpClientRequest> delete(String host, int port, String path) => open('DELETE', host, port, path);
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);
  @override
  Future<HttpClientRequest> patch(String host, int port, String path) => open('PATCH', host, port, path);
  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);
  @override
  Future<HttpClientRequest> head(String host, int port, String path) => open('HEAD', host, port, path);
  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);
}

class _MockHttpClientRequest implements HttpClientRequest {
  @override
  final String method;
  @override
  final Uri uri;

  final List<int> _bodyBuffer = [];

  _MockHttpClientRequest(this.method, this.uri);

  @override
  bool bufferOutput = true;
  @override
  int contentLength = -1;
  @override
  Encoding encoding = utf8;
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = true;

  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  final HttpConnectionInfo? connectionInfo = null;

  @override
  final List<Cookie> cookies = [];

  @override
  void add(List<int> data) {
    _bodyBuffer.addAll(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _bodyBuffer.addAll(chunk);
    }
  }

  @override
  Future<HttpClientResponse> close() async {
    final responsePayload = MockHttpOverrides.customResponseBody ??
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Mock response from hermetic test harness'}
                ]
              }
            }
          ]
        });
    return _MockHttpClientResponse(
      statusCode: MockHttpOverrides.customStatusCode,
      body: responsePayload,
    );
  }

  @override
  Future<HttpClientResponse> get done => close();

  @override
  Future<void> flush() async {}

  @override
  void write(Object? obj) {
    final str = obj.toString();
    _bodyBuffer.addAll(utf8.encode(str));
  }

  @override
  void writeAll(Iterable objects, [String separator = ""]) {
    write(objects.join(separator));
  }

  @override
  void writeCharCode(int charCode) {
    _bodyBuffer.add(charCode);
  }

  @override
  void writeln([Object? obj = ""]) {
    write('$obj\n');
  }

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}
}

class _MockHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  final int statusCode;
  final String body;

  _MockHttpClientResponse({required this.statusCode, required this.body});

  @override
  int get contentLength => utf8.encode(body).length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  final List<Cookie> cookies = [];

  @override
  final String reasonPhrase = 'OK';

  @override
  final X509Certificate? certificate = null;

  @override
  final HttpConnectionInfo? connectionInfo = null;

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  final List<RedirectInfo> redirects = const [];

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final stream = Stream.value(utf8.encode(body));
    return stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Future<HttpClientResponse> redirect([String? method, Uri? url, bool? followLoops]) async {
    return this;
  }

  @override
  Future<Socket> detachSocket() {
    throw UnsupportedError('detachSocket not supported in mock');
  }
}

class _MockHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _headers = {
    'content-type': ['application/json; charset=utf-8'],
  };

  @override
  List<String>? operator [](String name) => _headers[name.toLowerCase()];

  @override
  void add(String name, Object value, {bool? preserveHeaderCase}) {
    _headers.putIfAbsent(name.toLowerCase(), () => []).add(value.toString());
  }

  @override
  void set(String name, Object value, {bool? preserveHeaderCase}) {
    _headers[name.toLowerCase()] = [value.toString()];
  }

  @override
  void remove(String name, Object value) {
    _headers[name.toLowerCase()]?.remove(value.toString());
  }

  @override
  void removeAll(String name) {
    _headers.remove(name.toLowerCase());
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _headers.forEach(action);
  }

  @override
  void noFolding(String name) {}

  @override
  String? value(String name) => _headers[name.toLowerCase()]?.first;

  @override
  bool chunkedTransferEncoding = false;
  @override
  int contentLength = -1;
  @override
  ContentType? contentType = ContentType.json;
  @override
  DateTime? date;
  @override
  DateTime? expires;
  @override
  String? host = 'localhost';
  @override
  DateTime? ifModifiedSince;
  @override
  bool persistentConnection = true;
  @override
  int? port;

  @override
  void clear() {
    _headers.clear();
  }
}
