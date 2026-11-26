import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/oauth_loopback_io.dart' as oauth_loopback;
import 'package:noesis/core/supabase_service.dart';
import 'package:noesis/main.dart';
import 'package:noesis/widgets/profile_settings_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../e2e/harness/test_app_harness.dart';

// 1x1 PNG transparente válido para teste de upload de avatar
final Uint8List _kSamplePngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  setUp(() async {
    ProfileSettingsDialog.avatarPickerOverrideForTesting = null;
    await SupabaseService.resetProfileForTesting();
  });

  tearDown(() async {
    ProfileSettingsDialog.avatarPickerOverrideForTesting = null;
    await SupabaseService.resetProfileForTesting();
  });

  test('StudioOS profile validation and error translation logic', () {
    expect(SupabaseService.sanitizeUsername('  @Luma_Dev! 99 '), 'luma_dev99');

    // Usuário autenticado sem e-mail confirmado não pode trocar um @ já existente
    final lockedMsg = SupabaseService.validateProfileUpdate(
      newUsername: 'novo_user',
      currentUsername: 'antigo_user',
      isEmailConfirmed: false,
      isAuthenticatedUser: true,
    );
    expect(lockedMsg, isNotNull);
    expect(lockedMsg, contains('verificar o seu e-mail'));

    // Usuário com e-mail confirmado pode trocar @ normalmente
    final confirmedOk = SupabaseService.validateProfileUpdate(
      newUsername: 'novo_user',
      currentUsername: 'antigo_user',
      isEmailConfirmed: true,
      isAuthenticatedUser: true,
    );
    expect(confirmedOk, isNull);

    // Usuário autenticado definindo @ pela primeira vez pode salvar mesmo sem confirmação
    final firstTimeOk = SupabaseService.validateProfileUpdate(
      newUsername: 'novo_user',
      currentUsername: '',
      isEmailConfirmed: false,
      isAuthenticatedUser: true,
    );
    expect(firstTimeOk, isNull);

    expect(
      SupabaseService.translateAuthError('23505 duplicate key profiles_channel_key'),
      contains('já está em uso'),
    );
    expect(
      SupabaseService.translateAuthError('User must keep at least 2 identities / only one identity'),
      contains('ao menos um método de login'),
    );
    expect(
      SupabaseService.translateAuthError('Manual linking is disabled'),
      contains('desativada no servidor'),
    );
  });

  testWidgets('Sidebar user section is clickable and opens StudioOS-style profile settings', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await TestAppHarness.pumpInHarness(tester, const NoesisApp());
    await tester.pumpAndSettle();

    final guestBtn = find.text('Entrar sem login · Modo de Teste');
    if (guestBtn.evaluate().isNotEmpty) {
      await tester.tap(guestBtn);
      await tester.pumpAndSettle();
    }

    // 1. Clica na área do usuário na barra lateral
    final profileBtn = find.byKey(const Key('sidebar_profile_button'));
    expect(profileBtn, findsOneWidget);
    await tester.tap(profileBtn);
    await tester.pumpAndSettle();

    // Verifica abas Geral e Segurança & Contas
    expect(find.byKey(const Key('profile_tab_general')), findsOneWidget);
    expect(find.byKey(const Key('profile_tab_security')), findsOneWidget);

    // 2. Edita nome, @usuario e bio na aba Geral
    await tester.enterText(find.byKey(const Key('profile_name_field')), 'Luma Silva');
    await tester.enterText(find.byKey(const Key('profile_username_field')), '@Luma.Dev');
    await tester.enterText(find.byKey(const Key('profile_bio_field')), 'Focada em Arquitetura Cloud');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('profile_save_button')));
    await tester.tap(find.byKey(const Key('profile_save_button')));
    await tester.pumpAndSettle();

    expect(find.text('Perfil Atualizado'), findsOneWidget);
    expect(find.text('@luma.dev'), findsOneWidget);

    // 3. Altera foto de perfil usando preview e salvamento local
    ProfileSettingsDialog.avatarPickerOverrideForTesting = () async => (
      bytes: _kSamplePngBytes,
      fileName: 'avatar_teste.png',
    );
    await tester.ensureVisible(find.byKey(const Key('profile_pick_avatar_button')));
    await tester.tap(find.byKey(const Key('profile_pick_avatar_button')));
    await tester.pumpAndSettle();

    expect(find.text('Prévia da nova foto'), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile_confirm_avatar_button')));
    await tester.pumpAndSettle();

    expect(find.text('Foto Atualizada'), findsOneWidget);
    expect(find.byKey(const Key('profile_remove_avatar_button')), findsOneWidget);

    // 4. Vai para aba Segurança & Contas -> testa E-mail, Senha e Contas Google/Discord
    await tester.tap(find.byKey(const Key('profile_tab_security')));
    await tester.pumpAndSettle();

    expect(find.text('E-mail Vinculado'), findsOneWidget);
    expect(find.text('Alterar Senha'), findsOneWidget);
    expect(find.text('Contas Vinculadas (SSO)'), findsOneWidget);
    expect(find.text('Google (Gmail)'), findsOneWidget);
    expect(find.text('Discord'), findsOneWidget);

    // Atualiza e-mail local
    await tester.enterText(find.byKey(const Key('profile_email_field')), 'luma@asterdev.me');
    await tester.ensureVisible(find.byKey(const Key('profile_update_email_button')));
    await tester.tap(find.byKey(const Key('profile_update_email_button')));
    await tester.pumpAndSettle();
    expect(find.text('E-mail Atualizado'), findsOneWidget);

    // Valida regra de senha curta (< 8 caracteres)
    await tester.enterText(find.byKey(const Key('profile_current_password_field')), '12345678');
    await tester.enterText(find.byKey(const Key('profile_new_password_field')), 'curta');
    await tester.enterText(find.byKey(const Key('profile_confirm_password_field')), 'curta');
    await tester.ensureVisible(find.byKey(const Key('profile_update_password_button')));
    await tester.tap(find.byKey(const Key('profile_update_password_button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('mínimo 8 caracteres'), findsOneWidget);

    // Fecha o modal e verifica que sidebar e saudação refletiram os novos dados
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();

    expect(find.text('Luma Silva'), findsOneWidget);
    expect(find.textContaining('@luma.dev'), findsOneWidget);
    expect(find.textContaining('Luma Silva.'), findsOneWidget);

    await TestAppHarness.drainAsync(tester);
  });

  testWidgets('Profile SSO cards enforce StudioOS single-identity unlink protection', (tester) async {
    SupabaseService.linkedIdentitiesOverrideForTesting = const [
      LinkedIdentity(
        id: 'id-google',
        identityId: 'ident-google',
        provider: 'google',
        accountLabel: 'luma@gmail.com',
      ),
      LinkedIdentity(
        id: 'id-discord',
        identityId: 'ident-discord',
        provider: 'discord',
        accountLabel: 'lumadev#0001',
      ),
    ];

    await TestAppHarness.pumpInHarness(
      tester,
      const Scaffold(
        body: ProfileSettingsDialog(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile_tab_security')));
    await tester.pumpAndSettle();

    expect(find.text('Conectado (luma@gmail.com)'), findsOneWidget);
    expect(find.text('Conectado (lumadev#0001)'), findsOneWidget);

    // Desvincula Discord (com 2 identidades ativas é permitido)
    await tester.ensureVisible(find.byKey(const Key('profile_unlink_discord_button')));
    await tester.tap(find.byKey(const Key('profile_unlink_discord_button')));
    await tester.pumpAndSettle();

    expect(find.text('Desvincular Discord?'), findsOneWidget);
    await tester.tap(find.text('Desvincular').last);
    await tester.pumpAndSettle();

    // Agora resta apenas Google -> botão Desvincular deve ficar desabilitado (onPressed == null)
    expect(find.text('Não conectado'), findsOneWidget);
    final googleUnlink = tester.widget<OutlinedButton>(
      find.byKey(const Key('profile_unlink_google_button')),
    );
    expect(googleUnlink.onPressed, isNull);

    await TestAppHarness.drainAsync(tester);
  });

  testWidgets('ProfileSettingsDialog header live-updates cover, frame and title when equipped',
      (tester) async {
    SupabaseService.setVipForTesting(true);
    addTearDown(() => SupabaseService.setVipForTesting(null));

    await TestAppHarness.pumpInHarness(
      tester,
      const Scaffold(
        body: ProfileSettingsDialog(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Seleciona uma capa VIP no seletor abaixo e valida atualização imediata no topo
    await tester.ensureVisible(find.byKey(const Key('profile_edit_item_banner_vip_imperial')));
    await tester.tap(find.byKey(const Key('profile_edit_item_banner_vip_imperial')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile_header_banner_banner_vip_imperial')), findsOneWidget);

    // 2. Alterna para Molduras, seleciona uma moldura VIP e valida atualização no topo
    await tester.tap(find.byKey(const Key('profile_edit_cosmetic_tab_frame')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('profile_edit_item_frame_vip_astral')));
    await tester.tap(find.byKey(const Key('profile_edit_item_frame_vip_astral')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile_header_frame_frame_vip_astral')), findsOneWidget);

    // 3. Alterna para Títulos, seleciona um título e valida o selo no cabeçalho
    await tester.tap(find.byKey(const Key('profile_edit_cosmetic_tab_title')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('profile_edit_item_title_vip_sovereign')));
    await tester.tap(find.byKey(const Key('profile_edit_item_title_vip_sovereign')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile_header_title_title_vip_sovereign')), findsOneWidget);

    await TestAppHarness.drainAsync(tester);
  });

  test('authRedirectUrl preserves web Noesis origin and uses deep link on native', () {
    expect(SupabaseService.authRedirectUrl(), equals('io.supabase.noesis://login-callback/'));
    expect(
      SupabaseService.authRedirectUrl(
        baseUriOverride: Uri.parse('https://noesis.asterdev.me/?code=123#state=abc'),
      ),
      equals('https://noesis.asterdev.me/'),
    );
    expect(
      SupabaseService.authRedirectUrl(
        baseUriOverride: Uri.parse('http://localhost:5173/'),
      ),
      equals('http://localhost:5173/'),
    );
    expect(
      SupabaseService.authRedirectUrl(
        baseUriOverride: Uri.parse('http://127.0.0.1:8080/?code=abc'),
      ),
      equals('http://127.0.0.1:8080/'),
    );
  });

  test('Desktop OAuth loopback binds 127.0.0.1 port and exchanges callback code', () async {
    String? capturedRedirectUrl;
    Uri? capturedCallbackUri;

    final ok = await oauth_loopback.runDesktopOAuthLoopback(
      client: SupabaseService.client,
      startAuthFlow: (redirectUrl) async {
        capturedRedirectUrl = redirectUrl;
        return OAuthResponse(
          provider: OAuthProvider.google,
          url: 'https://accounts.google.com/o/oauth2/v2/auth?redirect_to=${Uri.encodeComponent(redirectUrl)}',
        );
      },
      launchBrowserOverride: (authUri) async {
        final callbackBase = Uri.parse(capturedRedirectUrl!);
        final socket = await Socket.connect(InternetAddress.loopbackIPv4, callbackBase.port);
        socket.write('GET /?code=test-pkce-code HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n');
        await socket.flush();
        await utf8.decoder.bind(socket).join();
        await socket.close();
        return true;
      },
      sessionFromUrlOverride: (callbackUri) async {
        capturedCallbackUri = callbackUri;
      },
    );

    expect(ok, isTrue);
    expect(capturedRedirectUrl, startsWith('http://127.0.0.1:'));
    expect(capturedCallbackUri?.queryParameters['code'], equals('test-pkce-code'));
  });
}
