import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

HttpServer? _activeLoopbackServer;
Completer<Uri>? _activeLoopbackCompleter;

bool get isDesktopLoopbackPlatform =>
    !kIsWeb &&
    (Platform.isWindows ||
        Platform.isMacOS ||
        Platform.isLinux ||
        Platform.isAndroid ||
        Platform.isIOS);

bool get _isMobilePlatform =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

Future<void> cancelActiveOAuthLoopback() async {
  final completer = _activeLoopbackCompleter;
  _activeLoopbackCompleter = null;
  if (completer != null && !completer.isCompleted) {
    completer.completeError(const _OAuthLoopbackCancelledException());
  }
  final server = _activeLoopbackServer;
  _activeLoopbackServer = null;
  await server?.close(force: true);
}

class _OAuthLoopbackCancelledException implements Exception {
  const _OAuthLoopbackCancelledException();
}

Future<bool> runDesktopOAuthLoopback({
  required SupabaseClient client,
  required Future<OAuthResponse> Function(String redirectUrl) startAuthFlow,
  Future<bool> Function(Uri url)? launchBrowserOverride,
  Future<void> Function(Uri callbackUri)? sessionFromUrlOverride,
  Duration timeout = const Duration(minutes: 3),
}) async {
  await cancelActiveOAuthLoopback();

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  _activeLoopbackServer = server;
  // Usa 127.0.0.1 explicitamente porque a allowlist de Redirect URLs do projeto Supabase aceita 127.0.0.1:* e rejeita localhost.
  final redirectUrl = 'http://127.0.0.1:${server.port}/';
  final completer = Completer<Uri>();
  _activeLoopbackCompleter = completer;

  var sessionExchangedInHandler = false;
  Object? handlerSessionError;
  StackTrace? handlerSessionStack;

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
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Noesis · Conectando...</title></head>
<body style="font-family:system-ui,sans-serif;background:#11121C;color:#F4F5FB;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;padding:16px;">
  <div style="text-align:center;padding:28px;max-width:420px;width:100%;background:#1B1C2A;border-radius:20px;">
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

      final hasError = request.uri.queryParameters.containsKey('error') ||
          request.uri.queryParameters.containsKey('error_description');

      // No mobile, conclui a troca da sessão antes de acionar o deep link de retorno ao app.
      if (_isMobilePlatform && !sessionExchangedInHandler) {
        sessionExchangedInHandler = true;
        try {
          if (sessionFromUrlOverride != null) {
            await sessionFromUrlOverride(request.uri);
          } else {
            await client.auth.getSessionFromUrl(request.uri);
          }
        } catch (err, st) {
          handlerSessionError = err;
          handlerSessionStack = st;
        }
      }

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(_successHtml(
          hasError: hasError || handlerSessionError != null,
          autoReturnToApp: _isMobilePlatform,
        ));
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
    if (handlerSessionError != null) {
      Error.throwWithStackTrace(
        handlerSessionError!,
        handlerSessionStack ?? StackTrace.current,
      );
    }
    if (!sessionExchangedInHandler) {
      if (sessionFromUrlOverride != null) {
        await sessionFromUrlOverride(callbackUri);
      } else {
        await client.auth.getSessionFromUrl(callbackUri);
      }
    }
    return true;
  } on _OAuthLoopbackCancelledException {
    return false;
  } finally {
    await sub.cancel();
    if (identical(_activeLoopbackCompleter, completer)) {
      _activeLoopbackCompleter = null;
    }
    if (identical(_activeLoopbackServer, server)) {
      _activeLoopbackServer = null;
    }
    await server.close(force: true);
  }
}

String _successHtml({
  required bool hasError,
  required bool autoReturnToApp,
}) {
  final encodedTitle = htmlEscape.convert(
    hasError ? 'Não foi possível concluir o login' : 'Login concluído no Noesis!',
  );
  final encodedBody = htmlEscape.convert(
    hasError
        ? 'Volte para o aplicativo Noesis para ver os detalhes.'
        : (autoReturnToApp
            ? 'Retornando automaticamente para o aplicativo Noesis...'
            : 'Sua Aster Account foi autenticada. Você já pode fechar esta aba e voltar para o aplicativo Noesis.'),
  );
  const appReturnUrl = 'io.supabase.noesis://login-callback/?returned=1';
  final mobileReturnHtml = autoReturnToApp
      ? '''
    <div style="margin-top:20px;">
      <a href="$appReturnUrl" style="display:inline-block;padding:12px 22px;background:#7C6CF0;color:#FFFFFF;text-decoration:none;border-radius:999px;font-weight:700;font-size:14px;">Voltar para o Noesis</a>
    </div>
    <script>
      setTimeout(function(){ window.location.replace('$appReturnUrl'); }, 120);
    </script>'''
      : '';
  return '''<!DOCTYPE html>
<html lang="pt-BR">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Noesis · Aster Account</title></head>
<body style="font-family:system-ui,sans-serif;background:#11121C;color:#F4F5FB;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;padding:16px;">
  <div style="text-align:center;padding:32px;max-width:440px;width:100%;background:#1B1C2A;border-radius:20px;border:1px solid #2E3149;">
    <h2 style="margin:0 0 10px;color:${hasError ? '#FF7A90' : '#3CCF9A'};">$encodedTitle</h2>
    <p style="margin:0;color:#989BB8;font-size:14px;line-height:1.5;">$encodedBody</p>$mobileReturnHtml
  </div>
</body>
</html>''';
}
