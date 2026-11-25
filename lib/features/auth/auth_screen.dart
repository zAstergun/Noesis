import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/supabase_service.dart';
import '../../widgets/noesis_logo.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  final VoidCallback? onContinueAsGuest;

  const AuthScreen({
    super.key,
    required this.onAuthenticated,
    this.onContinueAsGuest,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  String? _errorMessage;
  String? _successMessage;
  OAuthProvider? _oauthLoading;

  Future<void> _handleOAuth(OAuthProvider provider) async {
    setState(() {
      _oauthLoading = provider;
      _errorMessage = null;
    });

    try {
      await SupabaseService.signInWithOAuth(provider);
    } catch (e) {
      setState(() {
        _errorMessage = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('AuthException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _oauthLoading = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Por favor, informe seu e-mail.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Por favor, informe sua senha.');
      return;
    }
    if (_isSignUp && _fullNameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Por favor, informe seu usuário.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      if (_isSignUp) {
        await SupabaseService.signUp(
          email: email,
          password: password,
          fullName: _fullNameController.text.trim(),
        );
        setState(() {
          _successMessage = 'Conta Aster criada com sucesso! Acesse suas credenciais.';
          _isSignUp = false;
        });
      } else {
        await SupabaseService.signIn(
          email: email,
          password: password,
        );
        widget.onAuthenticated();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('AuthException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController =
        TextEditingController(text: _emailController.text.trim());
    bool isSending = false;
    String? resetError;
    String? resetSent;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AsterConstants.surfaceCard,
                    borderRadius:
                        BorderRadius.circular(AsterConstants.radiusLarge),
                    boxShadow: AsterConstants.clayShadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AsterTheme.primary(context).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.key_rounded,
                                size: 20, color: AsterTheme.primary(context)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Recuperar Senha',
                                  style: GoogleFonts.manrope(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AsterConstants.textDark,
                                  ),
                                ),
                                Text(
                                  'Instruções via e-mail',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    color: AsterConstants.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 20, color: AsterConstants.textMuted),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (resetSent != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AsterConstants.menta.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AsterConstants.radiusMedium),
                          ),
                          child: Text(
                            resetSent!,
                            style: GoogleFonts.manrope(
                              color: const Color(0xFF22996E),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ] else ...[
                        Text(
                          'Digite seu e-mail cadastrado para enviarmos o link seguro de redefinição de senha.',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: AsterConstants.textMuted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          label: 'E-MAIL',
                          controller: resetEmailController,
                          hint: 'seu-email@aster.app',
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        if (resetError != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            resetError!,
                            style: GoogleFonts.manrope(
                                color: AsterConstants.coral, fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: isSending
                              ? null
                              : () async {
                                  final mail = resetEmailController.text.trim();
                                  if (mail.isEmpty) {
                                    setDialogState(
                                        () => resetError = 'Digite seu e-mail.');
                                    return;
                                  }
                                  setDialogState(() {
                                    isSending = true;
                                    resetError = null;
                                  });
                                  try {
                                    await SupabaseService.client.auth
                                        .resetPasswordForEmail(mail);
                                    setDialogState(() {
                                      resetSent =
                                          'Link de redefinição enviado para $mail! Verifique sua caixa de entrada.';
                                    });
                                  } catch (e) {
                                    setDialogState(() {
                                      resetError = e
                                          .toString()
                                          .replaceAll('Exception: ', '');
                                    });
                                  } finally {
                                    setDialogState(() => isSending = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AsterTheme.primary(context),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AsterConstants.radiusPill),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  'Enviar Link de Recuperação',
                                  style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13),
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    void Function(String)? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AsterConstants.textMuted,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AsterConstants.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AsterConstants.surfaceInset.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            onSubmitted: onSubmitted,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AsterConstants.textDark,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    BorderSide(color: AsterTheme.primary(context), width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              prefixIcon: Icon(icon, size: 19, color: AsterConstants.textMuted),
              hintText: hint,
              hintStyle: GoogleFonts.manrope(
                fontSize: 13,
                color: AsterConstants.textFaint,
                fontWeight: FontWeight.w500,
              ),
              suffixIcon: suffixIcon,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeSwitcher() {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AsterConstants.surfaceAlt,
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / 2;

          return Stack(
            children: [
              // Indicador deslizante animado (Sliding Pill)
              AnimatedAlign(
                alignment: _isSignUp ? Alignment.centerRight : Alignment.centerLeft,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                child: Container(
                  width: tabWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: AsterConstants.surfaceCard,
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    boxShadow: AsterConstants.claySubtleShadow,
                  ),
                ),
              ),

              // Rótulos clicáveis com tipografia animada
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (_isSignUp) {
                          setState(() {
                            _isSignUp = false;
                            _errorMessage = null;
                            _successMessage = null;
                          });
                        }
                      },
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: !_isSignUp ? FontWeight.w800 : FontWeight.w600,
                            color: !_isSignUp ? AsterTheme.primary(context) : AsterConstants.textMuted,
                          ),
                          child: const Text('Entrar'),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (!_isSignUp) {
                          setState(() {
                            _isSignUp = true;
                            _errorMessage = null;
                            _successMessage = null;
                          });
                        }
                      },
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: _isSignUp ? FontWeight.w800 : FontWeight.w600,
                            color: _isSignUp ? AsterTheme.primary(context) : AsterConstants.textMuted,
                          ),
                          child: const Text('Criar Conta'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPrimaryButton() {
    final primaryCol = AsterTheme.primary(context);
    final lighter = Color.lerp(primaryCol, Colors.white, 0.12) ?? primaryCol;
    final darker = Color.lerp(primaryCol, Colors.black, 0.14) ?? primaryCol;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [lighter, primaryCol, darker],
        ),
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        boxShadow: AsterTheme.primaryShadow(context, primaryCol),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _submit,
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else ...[
                  const SizedBox(width: 32),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.2),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        _isSignUp
                            ? 'Criar Conta Aster'
                            : 'Entrar na Aster Account',
                        key: ValueKey<bool>(_isSignUp),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuestButton() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AsterConstants.surfaceAlt,
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        border: Border.all(
          color: AsterConstants.surfaceInset,
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onContinueAsGuest,
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: AsterTheme.primary(context),
                ),
                const SizedBox(width: 8),
                Text(
                  'Entrar sem login · Modo de Teste',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AsterConstants.textDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOAuthButton({
    required String label,
    required Widget icon,
    required VoidCallback onTap,
    bool isLoading = false,
    Color? borderColor,
    Color? backgroundColor,
    Color? textColor,
  }) {
    return Expanded(
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: backgroundColor ?? AsterConstants.surfaceAlt,
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          border: Border.all(
            color: borderColor ?? AsterConstants.surfaceInset,
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(60, 60, 120, 0.03),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isLoading || _oauthLoading != null ? null : onTap,
            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AsterTheme.primary(context)),
                      ),
                    )
                  else ...[
                    icon,
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor ?? AsterConstants.textDark,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AsterConstants.bgNevoa,
      body: SoftClayBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                // Doppelrand (Double-Bezel Architecture)
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.8),
                      width: 2,
                    ),
                    boxShadow: AsterConstants.clayShadow,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32.0, vertical: 36.0),
                    decoration: BoxDecoration(
                      color: AsterConstants.surfaceCard,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo Oficial Noesis
                        const Center(
                          child: NoesisLogo(size: 68, withShadow: true),
                        ),
                        const SizedBox(height: 16),

                        // Eyebrow Tag Semântica
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AsterTheme.primary(context).withValues(alpha: 0.10),
                              borderRadius:
                                  BorderRadius.circular(AsterConstants.radiusPill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: AsterTheme.primary(context),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'ASTER ACCOUNT · SSO',
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: AsterTheme.primary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        const NoesisWordmark(
                          fontSize: 28,
                          textAlign: TextAlign.center,
                          color: AsterConstants.textDark,
                        ),
                        const SizedBox(height: 4),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.0, 0.15),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            _isSignUp
                                ? 'Crie seu acesso unificado para o ecossistema Aster'
                                : 'Acesse seus estudos, cronogramas e inteligência cognitiva',
                            key: ValueKey<bool>(_isSignUp),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: AsterConstants.textMuted,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Seletor Entrar / Criar Conta
                        _buildModeSwitcher(),
                        const SizedBox(height: 22),

                        // Alertas de Erro / Sucesso
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AsterConstants.coral.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(
                                  AsterConstants.radiusMedium),
                              border: Border.all(
                                color: AsterConstants.coral.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    size: 18, color: AsterConstants.coral),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: GoogleFonts.manrope(
                                      color: AsterConstants.coral,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (_successMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AsterConstants.menta.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                  AsterConstants.radiusMedium),
                              border: Border.all(
                                color: AsterConstants.menta.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline_rounded,
                                    size: 18, color: Color(0xFF22996E)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _successMessage!,
                                    style: GoogleFonts.manrope(
                                      color: const Color(0xFF22996E),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Campos de Formulário com Transição Suave
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOutCubic,
                          alignment: Alignment.topCenter,
                          child: _isSignUp
                              ? Column(
                                  children: [
                                    _buildInputField(
                                      label: 'USUÁRIO',
                                      controller: _fullNameController,
                                      hint: 'Seu usuário',
                                      icon: Icons.person_outline_rounded,
                                      onSubmitted: (_) => _submit(),
                                    ),
                                    const SizedBox(height: 14),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),

                        _buildInputField(
                          label: 'E-MAIL',
                          controller: _emailController,
                          hint: 'exemplo@aster.app',
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 14),

                        _buildInputField(
                          label: 'SENHA',
                          controller: _passwordController,
                          hint: '••••••••••••',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          onSubmitted: (_) => _submit(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 18,
                              color: AsterConstants.textMuted,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Lembrar sessão & Esqueceu senha com Transição Suave
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOutCubic,
                          alignment: Alignment.topCenter,
                          child: !_isSignUp
                              ? Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            setState(() => _rememberMe = !_rememberMe);
                                          },
                                          borderRadius: BorderRadius.circular(6),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 4, horizontal: 2),
                                            child: Row(
                                              children: [
                                                AnimatedContainer(
                                                  duration: const Duration(milliseconds: 150),
                                                  width: 18,
                                                  height: 18,
                                                  decoration: BoxDecoration(
                                                    color: _rememberMe
                                                        ? AsterTheme.primary(context)
                                                        : AsterConstants.surfaceAlt,
                                                    borderRadius: BorderRadius.circular(5),
                                                    border: Border.all(
                                                      color: _rememberMe
                                                          ? AsterTheme.primary(context)
                                                          : AsterConstants.surfaceInset,
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  child: _rememberMe
                                                      ? const Icon(Icons.check_rounded,
                                                          size: 13, color: Colors.white)
                                                      : null,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Lembrar sessão',
                                                  style: GoogleFonts.manrope(
                                                    fontSize: 12,
                                                    color: AsterConstants.textMuted,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: _showForgotPasswordDialog,
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 4),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: Text(
                                            'Esqueceu a senha?',
                                            style: GoogleFonts.manrope(
                                              color: AsterTheme.primary(context),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                )
                              : const SizedBox(height: 8),
                        ),

                        // Botão Primário CTA
                        _buildPrimaryButton(),
                        const SizedBox(height: 18),

                        // Divisor Ou Continue Com (Estilo Studio OS)
                        Row(
                          children: [
                            const Expanded(
                              child: Divider(
                                color: AsterConstants.surfaceInset,
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                'OU CONTINUE COM',
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: AsterConstants.textMuted,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(
                                color: AsterConstants.surfaceInset,
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Grid OAuth: Google e Discord (Estilo Studio OS)
                        Row(
                          children: [
                            _buildOAuthButton(
                              label: 'Google',
                              icon: const GoogleLogoWidget(size: 18),
                              isLoading: _oauthLoading == OAuthProvider.google,
                              onTap: () => _handleOAuth(OAuthProvider.google),
                            ),
                            const SizedBox(width: 10),
                            _buildOAuthButton(
                              label: 'Discord',
                              icon: const DiscordLogoWidget(size: 18),
                              isLoading: _oauthLoading == OAuthProvider.discord,
                              onTap: () => _handleOAuth(OAuthProvider.discord),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Botão Entrar sem Login (Modo Teste / Convidado)
                        if (widget.onContinueAsGuest != null) ...[
                          _buildGuestButton(),
                          const SizedBox(height: 16),
                        ] else
                          const SizedBox(height: 20),

                        // Selo de Criptografia & Segurança
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              size: 14,
                              color: AsterConstants.textFaint,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Criptografia de 256 bits · Aster Auth SSO',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                color: AsterConstants.textFaint,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GoogleLogoWidget extends StatelessWidget {
  final double size;
  const GoogleLogoWidget({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: const _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24.0, size.height / 24.0);

    // Red
    final paintRed = Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.fill;
    final pathRed = Path();
    pathRed.moveTo(12.000, 10.200);
    pathRed.lineTo(12.000, 14.100);
    pathRed.lineTo(17.500, 14.100);
    pathRed.cubicTo(17.260, 15.500, 15.800, 18.200, 12.000, 18.200);
    pathRed.cubicTo(8.700, 18.200, 6.000, 15.500, 6.000, 12.100);
    pathRed.cubicTo(7.900, 12.100, 9.100, 12.900, 9.800, 13.600);
    pathRed.lineTo(12.400, 11.100);
    pathRed.cubicTo(16.800, 3.500, 14.600, 2.500, 12.000, 2.500);
    pathRed.cubicTo(6.800, 2.500, 2.600, 6.700, 2.600, 12.000);
    pathRed.cubicTo(8.000, 12.000, 11.600, 8.200, 11.600, 2.800);
    pathRed.cubicTo(11.600, 2.200, 11.500, 1.700, 11.400, 1.200);
    pathRed.lineTo(12.000, 1.200);
    pathRed.close();
    canvas.drawPath(pathRed, paintRed);

    // Blue
    final paintBlue = Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill;
    final pathBlue = Path();
    pathBlue.moveTo(21.000, 12.300);
    pathBlue.cubicTo(21.000, 11.700, 20.900, 11.200, 20.800, 10.700);
    pathBlue.lineTo(12.000, 10.700);
    pathBlue.lineTo(12.000, 14.600);
    pathBlue.lineTo(17.500, 14.600);
    pathBlue.cubicTo(17.200, 15.900, 16.400, 17.000, 15.200, 17.700);
    pathBlue.lineTo(18.300, 20.100);
    pathBlue.cubicTo(20.100, 18.400, 21.000, 15.900, 21.000, 12.300);
    pathBlue.close();
    canvas.drawPath(pathBlue, paintBlue);

    // Yellow
    final paintYellow = Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.fill;
    final pathYellow = Path();
    pathYellow.moveTo(6.400, 14.200);
    pathYellow.arcToPoint(const Offset(6.400, 9.800), radius: const Radius.elliptical(6.000, 6.000), rotation: 0, largeArc: false, clockwise: true);
    pathYellow.lineTo(3.200, 7.400);
    pathYellow.arcToPoint(const Offset(3.200, 16.600), radius: const Radius.elliptical(9.600, 9.600), rotation: 0, largeArc: false, clockwise: false);
    pathYellow.lineTo(6.400, 14.200);
    pathYellow.close();
    canvas.drawPath(pathYellow, paintYellow);

    // Green
    final paintGreen = Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.fill;
    final pathGreen = Path();
    pathGreen.moveTo(12.000, 21.500);
    pathGreen.cubicTo(14.600, 21.500, 16.800, 20.600, 18.300, 19.100);
    pathGreen.lineTo(15.200, 16.700);
    pathGreen.cubicTo(14.400, 17.300, 13.300, 17.700, 12.000, 17.700);
    pathGreen.cubicTo(9.500, 17.700, 7.500, 16.100, 6.700, 13.800);
    pathGreen.lineTo(3.500, 16.200);
    pathGreen.cubicTo(5.100, 19.300, 8.300, 21.500, 12.000, 21.500);
    pathGreen.close();
    canvas.drawPath(pathGreen, paintGreen);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DiscordLogoWidget extends StatelessWidget {
  final double size;
  const DiscordLogoWidget({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(
        painter: _DiscordLogoPainter(),
      ),
    );
  }
}

class _DiscordLogoPainter extends CustomPainter {
  const _DiscordLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Maintain 24x18 aspect ratio centered in the square box
    final scale = size.width / 24.0;
    final dy = (size.height - (18.0 * scale)) / 2.0;
    canvas.translate(0, dy);
    canvas.scale(scale, scale);

    final blurplePaint = Paint()
      ..color = const Color(0xFF5865F2)
      ..style = PaintingStyle.fill;

    final bodyPath = Path();
    bodyPath.moveTo(20.300, 1.600);
    bodyPath.arcToPoint(const Offset(15.400, 0.100), radius: const Radius.elliptical(19.800, 19.800), rotation: 0, largeArc: false, clockwise: false);
    bodyPath.arcToPoint(const Offset(14.770, 1.400), radius: const Radius.elliptical(14.000, 14.000), rotation: 0, largeArc: false, clockwise: false);
    bodyPath.arcToPoint(const Offset(9.280, 1.400), radius: const Radius.elliptical(18.300, 18.300), rotation: 0, largeArc: false, clockwise: false);
    bodyPath.arcToPoint(const Offset(8.640, 0.100), radius: const Radius.elliptical(13.900, 13.900), rotation: 0, largeArc: false, clockwise: false);
    bodyPath.arcToPoint(const Offset(3.740, 1.600), radius: const Radius.elliptical(19.700, 19.700), rotation: 0, largeArc: false, clockwise: false);
    bodyPath.cubicTo(0.630, 6.300, -0.210, 10.900, 0.210, 15.400);
    bodyPath.arcToPoint(const Offset(6.210, 18.450), radius: const Radius.elliptical(19.900, 19.900), rotation: 0, largeArc: false, clockwise: false);
    bodyPath.cubicTo(6.700, 17.790, 7.130, 17.080, 7.500, 16.350);
    bodyPath.arcToPoint(const Offset(5.470, 15.370), radius: const Radius.elliptical(13.000, 13.000), rotation: 0, largeArc: false, clockwise: true);
    bodyPath.cubicTo(5.640, 15.250, 5.810, 15.120, 5.970, 14.990);
    bodyPath.arcToPoint(const Offset(18.070, 14.990), radius: const Radius.elliptical(14.200, 14.200), rotation: 0, largeArc: false, clockwise: false);
    bodyPath.cubicTo(18.230, 15.130, 18.400, 15.250, 18.570, 15.370);
    bodyPath.cubicTo(17.920, 15.760, 17.240, 16.090, 16.530, 16.350);
    bodyPath.cubicTo(16.900, 17.080, 17.330, 17.780, 17.820, 18.450);
    bodyPath.arcToPoint(const Offset(23.830, 15.400), radius: const Radius.elliptical(19.800, 19.800), rotation: 0, largeArc: false, clockwise: false);
    bodyPath.cubicTo(24.330, 10.180, 22.980, 5.620, 20.300, 1.600);
    bodyPath.close();

    canvas.drawPath(bodyPath, blurplePaint);

    final whiteEyesPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final eyesPath = Path();
    eyesPath.moveTo(8.020, 12.630);
    eyesPath.cubicTo(6.840, 12.630, 5.860, 11.550, 5.860, 10.230);
    eyesPath.cubicTo(5.860, 8.900, 6.810, 7.820, 8.020, 7.820);
    eyesPath.cubicTo(9.240, 7.820, 10.210, 8.910, 10.190, 10.220);
    eyesPath.cubicTo(10.190, 11.550, 9.230, 12.630, 8.020, 12.630);
    eyesPath.close();

    eyesPath.moveTo(15.980, 12.630);
    eyesPath.cubicTo(14.800, 12.630, 13.830, 11.550, 13.830, 10.230);
    eyesPath.cubicTo(13.830, 8.900, 14.770, 7.820, 15.980, 7.820);
    eyesPath.cubicTo(17.200, 7.820, 18.170, 8.910, 18.150, 10.220);
    eyesPath.cubicTo(18.150, 11.550, 17.200, 12.630, 15.980, 12.630);
    eyesPath.close();

    canvas.drawPath(eyesPath, whiteEyesPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
