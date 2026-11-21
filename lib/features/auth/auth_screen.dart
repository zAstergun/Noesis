import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/supabase_service.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isSignUp) {
        await SupabaseService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          fullName: _fullNameController.text.trim(),
        );
      } else {
        await SupabaseService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
      widget.onAuthenticated();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AsterConstants.bgNevoa,
      body: SoftClayBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SoftClayCard(
                padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 40.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Branding Soft Clay
                    Center(
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: const BoxDecoration(
                          color: AsterConstants.lavanda,
                          shape: BoxShape.circle,
                          boxShadow: AsterConstants.primaryButtonShadow,
                        ),
                        child: const Center(
                          child: Text(
                            'N',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Noesis',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: AsterConstants.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Acesse com a sua Aster Account',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: AsterConstants.textMuted,
                      ),
                    ),
                    const SizedBox(height: 32),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AsterConstants.coral.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 18, color: AsterConstants.coral),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.manrope(color: AsterConstants.coral, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    if (_isSignUp) ...[
                      TextField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome Completo',
                          prefixIcon: Icon(Icons.person_outline_rounded, color: AsterConstants.textMuted),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail Aster',
                        prefixIcon: Icon(Icons.email_outlined, color: AsterConstants.textMuted),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: Icon(Icons.lock_outline_rounded, color: AsterConstants.textMuted),
                      ),
                    ),
                    const SizedBox(height: 26),

                    SoftClayPillButton(
                      text: _isSignUp ? 'Criar Conta Aster' : 'Entrar na Aster Account',
                      onPressed: _isLoading ? null : _submit,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      icon: _isLoading ? null : Icons.arrow_forward_rounded,
                    ),
                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isSignUp = !_isSignUp;
                          _errorMessage = null;
                        });
                      },
                      child: Text(
                        _isSignUp
                            ? 'Já tem uma Aster Account? Entre aqui'
                            : 'Não tem uma conta? Cadastre-se no Aster',
                        style: GoogleFonts.manrope(
                          color: AsterConstants.lavanda,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
