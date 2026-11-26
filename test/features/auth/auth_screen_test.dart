import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/supabase_service.dart';
import 'package:noesis/features/auth/auth_screen.dart';
import '../../e2e/harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
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
  });
}
