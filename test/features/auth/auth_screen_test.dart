import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/supabase_service.dart';
import 'package:noesis/features/auth/auth_screen.dart';
import 'package:noesis/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../e2e/harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  tearDown(() async {
    await SupabaseService.resetProfileForTesting();
  });

  group('AuthScreen account creation & test-account removal', () {
    testWidgets('does not expose any guest or test-account login bypass', (tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        AuthScreen(onAuthenticated: () {}),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Modo de Teste'), findsNothing);
      expect(find.textContaining('Entrar sem login'), findsNothing);
      expect(find.text('Entrar'), findsOneWidget);
      expect(find.text('Criar Conta'), findsOneWidget);
    });

    testWidgets('validates username, email format, and minimum password length on Sign Up',
        (tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        AuthScreen(onAuthenticated: () {}),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Criar Conta'));
      await tester.pumpAndSettle();

      expect(find.text('Criar Conta Aster'), findsOneWidget);

      // 1. Empty username
      await tester.tap(find.text('Criar Conta Aster'));
      await tester.pumpAndSettle();
      expect(find.text('Por favor, informe seu usuário.'), findsOneWidget);

      // 2. Invalid email format
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'NovoEstudante');
      await tester.enterText(fields.at(1), 'email-invalido');
      await tester.enterText(fields.at(2), '123456');
      await tester.tap(find.text('Criar Conta Aster'));
      await tester.pumpAndSettle();
      expect(find.text('Por favor, informe um e-mail válido.'), findsOneWidget);

      // 3. Password shorter than 6 characters
      await tester.enterText(fields.at(1), 'novo@aster.app');
      await tester.enterText(fields.at(2), '123');
      await tester.tap(find.text('Criar Conta Aster'));
      await tester.pumpAndSettle();
      expect(find.text('A senha precisa ter pelo menos 6 caracteres.'), findsOneWidget);
    });

    test('translateAuthError returns Portuguese messages for sign-up failures', () {
      expect(
        SupabaseService.translateAuthError('User already registered'),
        'Já existe uma conta com esse e-mail.',
      );
      expect(
        SupabaseService.translateAuthError('Password should be at least 6 characters'),
        'A senha precisa ter pelo menos 6 caracteres.',
      );
      expect(
        SupabaseService.translateAuthError('Unable to validate email address: invalid format'),
        'E-mail inválido.',
      );
      expect(
        SupabaseService.extractOAuthCallbackError(
          Uri.parse('http://127.0.0.1:54671/?error=access_denied&error_description=The+user+did+not+authorize+your+application'),
        ),
        'Autorização cancelada. Você pode tentar novamente quando quiser.',
      );
      expect(
        SupabaseService.extractOAuthCallbackError(
          Uri.parse('http://127.0.0.1:54671/?error=invalid_request&error_code=flow_state_already_used'),
        ),
        'Esta tentativa de login já foi usada ou expirou. Tente entrar novamente.',
      );
    });

    testWidgets('displays Portuguese message when returning with OAuth cancellation error',
        (tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        AuthScreen(
          onAuthenticated: () {},
          initialCallbackUri: Uri.parse('http://127.0.0.1:54671/?error=access_denied'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Autorização cancelada. Você pode tentar novamente quando quiser.'),
        findsOneWidget,
      );
    });

    test('AndroidManifest declares INTERNET permission and Noesis OAuth callback intent-filter', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android.permission.INTERNET'));
      expect(manifest, contains('android:scheme="io.supabase.noesis"'));
      expect(manifest, contains('android:host="login-callback"'));
    });

    testWidgets('AuthScreen renders cleanly on 360x780 mobile viewport without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await TestAppHarness.pumpInHarness(
        tester,
        AuthScreen(onAuthenticated: () {}),
        screenSize: const Size(360, 780),
      );
      await tester.pumpAndSettle();

      expect(find.text('Discord'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Entrar na Aster Account'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SignUp requires email confirmation screen and supports resend, and unconfirmed SignIn offers resend',
        (tester) async {
      final resentEmails = <String>[];
      SupabaseService.signUpOverrideForTesting = ({
        required String email,
        required String password,
        String? fullName,
      }) async {
        return AuthResponse(
          session: null,
          user: User(
            id: 'new-user-1',
            appMetadata: const {},
            userMetadata: {'full_name': fullName},
            aud: 'authenticated',
            createdAt: DateTime.now().toIso8601String(),
            email: email,
          ),
        );
      };
      SupabaseService.signInOverrideForTesting = ({
        required String email,
        required String password,
      }) async {
        throw const AuthException('Email not confirmed');
      };
      SupabaseService.resendSignupConfirmationOverrideForTesting = (email) async {
        resentEmails.add(email);
      };

      bool authenticated = false;
      await TestAppHarness.pumpInHarness(
        tester,
        AuthScreen(onAuthenticated: () => authenticated = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Criar Conta'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'NovoEstudante');
      await tester.enterText(fields.at(1), 'novo@aster.app');
      await tester.enterText(fields.at(2), 'segredo123');
      await tester.tap(find.text('Criar Conta Aster'));
      await tester.pumpAndSettle();

      expect(authenticated, isFalse);
      expect(find.byKey(const Key('auth_pending_confirmation_card')), findsOneWidget);
      expect(find.text('Confirme seu e-mail'), findsOneWidget);

      await tester.tap(find.byKey(const Key('auth_resend_confirmation_button')));
      await tester.pumpAndSettle();
      expect(resentEmails, ['novo@aster.app']);
      expect(find.textContaining('Novo link de confirmação enviado'), findsOneWidget);

      await tester.tap(find.byKey(const Key('auth_back_from_confirmation_button')));
      await tester.pumpAndSettle();

      // Tenta entrar antes de confirmar -> mostra erro + botão de reenvio
      final loginFields = find.byType(TextField);
      await tester.enterText(loginFields.at(0), 'novo@aster.app');
      await tester.enterText(loginFields.at(1), 'segredo123');
      await tester.tap(find.text('Entrar na Aster Account'));
      await tester.pumpAndSettle();

      expect(find.text('Confirme seu e-mail antes de entrar. Verifique a caixa de entrada.'), findsOneWidget);
      expect(find.byKey(const Key('auth_login_resend_confirmation_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('auth_login_resend_confirmation_button')));
      await tester.pumpAndSettle();
      expect(resentEmails, ['novo@aster.app', 'novo@aster.app']);
    });

    testWidgets('RootScreen displays email verification reminder banner when unconfirmed', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SupabaseService.isEmailConfirmedOverrideForTesting = false;
      await TestAppHarness.pumpInHarness(tester, const NoesisApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('email_verification_reminder_banner')), findsOneWidget);
      expect(find.byKey(const Key('email_verification_refresh_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('email_verification_dismiss_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('email_verification_reminder_banner')), findsNothing);
    });
  });
}
