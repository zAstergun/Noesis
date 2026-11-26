import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

HttpServer? _activeLoopbackServer;

bool get isDesktopLoopbackPlatform =>
    !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

Future<bool> runDesktopOAuthLoopback({
  required SupabaseClient client,
  required Future<OAuthResponse> Function(String redirectUrl) startAuthFlow,
  Future<bool> Function(Uri url)? launchBrowserOverride,
  Future<void> Function(Uri callbackUri)? sessionFromUrlOverride,
  Duration timeout = const Duration(minutes: 3),
}) async {
  await _activeLoopbackServer?.close(force: true);
  _activeLoopbackServer = null;

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  _activeLoopbackServer = server;
  // Usa 127.0.0.1 explicitamente porque a allowlist de Redirect URLs do projeto Supabase aceita 127.0.0.1:* e rejeita localhost.
  final redirectUrl = 'http://127.0.0.1:${server.port}/';
  final completer = Completer<Uri>();

  late final StreamSubscription<HttpRequest> sub;
  sub = server.listen(
    (HttpRequest request) async {
      final path = request.uri.path;
      if (path == '/favicon.ico') {
        request.response
          ..statusCode = HttpStatus.notFound
          ..close();
        return;
      }

      final hasAuthParams = request.uri.queryParameters.containsKey('code') ||
          request.uri.queryParameters.containsKey('access_token') ||
          request.uri.queryParameters.containsKey('error') ||
          request.uri.queryParameters.containsKey('error_description');

      if (!hasAuthParams && path != '/callback-fragment') {
        // Caso o provedor retorne tokens no fragmento (#access_token=...), converte para query.
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..write('''<!DOCTYPE html>
<html lang="pt-BR">
<head><meta charset="utf-8"><title>Noesis · Conectando...</title></head>
<body style="font-family:system-ui,sans-serif;background:#11121C;color:#F4F5FB;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;">
  <div style="text-align:center;padding:32px;max-width:420px;background:#1B1C2A;border-radius:20px;">
    <h2 style="margin:0 0 8px;">Concluindo login no Noesis...</h2>
    <p id="msg" style="color:#989BB8;font-size:14px;">Aguarde um instante.</p>
  </div>
  <script>
    (function(){
      var h = window.location.hash ? window.location.hash.substring(1) : '';
      if (h) {
        window.location.replace('/callback-fragment?' + h);
      } else {
        document.getElementById('msg').textContent = 'Nenhum código de autenticação recebido. Você pode fechar esta aba e tentar novamente.';
      }
    })();
  </script>
</body>
</html>''');
        await request.response.close();
        return;
      }

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(_successHtml(hasError: request.uri.queryParameters.containsKey('error')));
      await request.response.close();

      if (!completer.isCompleted) {
        completer.complete(request.uri);
      }
    },
    onError: (Object err, StackTrace st) {
      if (!completer.isCompleted) {
        completer.completeError(err, st);
      }
    },
  );

  try {
    final res = await startAuthFlow(redirectUrl);
    final authUri = Uri.parse(res.url);
    final launched = launchBrowserOverride != null
        ? await launchBrowserOverride(authUri)
        : await launchUrl(authUri, mode: LaunchMode.externalApplication);

    if (!launched) {
      return false;
    }

    final callbackUri = await completer.future.timeout(timeout);
    if (sessionFromUrlOverride != null) {
      await sessionFromUrlOverride(callbackUri);
    } else {
      await client.auth.getSessionFromUrl(callbackUri);
    }
    return true;
  } finally {
    await sub.cancel();
    if (identical(_activeLoopbackServer, server)) {
      _activeLoopbackServer = null;
    }
    await server.close(force: true);
  }
}

String _successHtml({required bool hasError}) {
  final encodedTitle = htmlEscape.convert(
    hasError ? 'Não foi possível concluir o login' : 'Login concluído no Noesis!',
  );
  final encodedBody = htmlEscape.convert(
    hasError
        ? 'Feche esta aba e verifique a mensagem exibida no aplicativo Noesis.'
        : 'Sua Aster Account foi autenticada. Você já pode fechar esta aba e voltar para o aplicativo Noesis.',
  );
  return '''<!DOCTYPE html>
<html lang="pt-BR">
<head><meta charset="utf-8"><title>Noesis · Aster Account</title></head>
<body style="font-family:system-ui,sans-serif;background:#11121C;color:#F4F5FB;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;">
  <div style="text-align:center;padding:32px;max-width:440px;background:#1B1C2A;border-radius:20px;border:1px solid #2E3149;">
    <h2 style="margin:0 0 10px;color:${hasError ? '#FF7A90' : '#3CCF9A'};">$encodedTitle</h2>
    <p style="margin:0;color:#989BB8;font-size:14px;line-height:1.5;">$encodedBody</p>
  </div>
</body>
</html>''';
}
