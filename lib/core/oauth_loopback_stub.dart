import 'package:supabase_flutter/supabase_flutter.dart';

bool get isDesktopLoopbackPlatform => false;

Future<void> cancelActiveOAuthLoopback() async {}

Future<bool> runDesktopOAuthLoopback({
  required SupabaseClient client,
  required Future<OAuthResponse> Function(String redirectUrl) startAuthFlow,
  Future<bool> Function(Uri url)? launchBrowserOverride,
}) async {
  return false;
}
