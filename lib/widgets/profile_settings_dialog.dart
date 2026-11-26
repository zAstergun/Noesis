import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../core/shop_service.dart';
import '../core/supabase_service.dart';
import '../core/theme.dart';
import '../features/auth/auth_screen.dart';
import '../features/profile/models/profile_cosmetics.dart';
import '../features/profile/widgets/profile_cosmetic_widgets.dart';
import '../features/ranking/models/ranking_league_model.dart';
import 'insight_icon.dart';
import 'vip_privileges.dart';

/// Resolve um [ImageProvider] seguro para URLs remotas ou `data:image/...;base64,...`.
ImageProvider<Object>? buildAvatarImageProvider(String? avatarUrl) {
  final raw = avatarUrl?.trim() ?? '';
  if (raw.isEmpty) return null;
  if (raw.startsWith('data:image/')) {
    final commaIdx = raw.indexOf(',');
    if (commaIdx <= 0 || commaIdx >= raw.length - 1) return null;
    try {
      final bytes = base64Decode(raw.substring(commaIdx + 1));
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }
  return NetworkImage(raw);
}

Future<void> showProfileSettingsDialog(
  BuildContext context, {
  int streakDays = 0,
  VoidCallback? onRequestSignIn,
  VoidCallback? onOpenShop,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => ProfileSettingsDialog(
      streakDays: streakDays,
      onRequestSignIn: onRequestSignIn,
      onOpenShop: onOpenShop,
    ),
  );
}

enum _ProfileNoticeTone { info, success, warning, error }

class ProfileSettingsDialog extends StatefulWidget {
  final int streakDays;
  final VoidCallback? onRequestSignIn;
  final VoidCallback? onOpenShop;

  /// Gancho para testes selecionarem imagem sem depender do seletor nativo.
  @visibleForTesting
  static Future<({Uint8List bytes, String fileName})?> Function()? avatarPickerOverrideForTesting;

  const ProfileSettingsDialog({
    super.key,
    this.streakDays = 0,
    this.onRequestSignIn,
    this.onOpenShop,
  });

  @override
  State<ProfileSettingsDialog> createState() => _ProfileSettingsDialogState();
}

class _ProfileSettingsDialogState extends State<ProfileSettingsDialog> {
  int _activeTab = 0; // 0 = Geral, 1 = Segurança & Contas
  ProfileCosmeticCategory _cosmeticCategory = ProfileCosmeticCategory.banner;

  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPass = true;
  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;

  bool _savingProfile = false;
  bool _savingEmail = false;
  bool _savingPassword = false;
  bool _uploadingAvatar = false;
  bool _loadingIdentities = false;
  bool _linkingOAuth = false;

  String? _avatarUrl;
  String? _currentSavedChannel;
  String? _pendingAvatarFileName;
  Uint8List? _pendingAvatarBytes;
  List<LinkedIdentity> _identities = const [];

  StreamSubscription<AuthState>? _authSub;

  String? _noticeTitle;
  String? _noticeMessage;
  _ProfileNoticeTone _noticeTone = _ProfileNoticeTone.info;

  @override
  void initState() {
    super.initState();
    ShopService.instance.init();
    _hydrateFromCurrentProfile();
    _loadIdentities();
    _authSub = SupabaseService.authStateChanges.listen((_) {
      if (mounted) {
        _loadIdentities();
        SupabaseService.loadFullProfile().then((_) {
          if (mounted) _hydrateFromCurrentProfile();
        });
      }
    });
  }

  void _hydrateFromCurrentProfile() {
    final user = SupabaseService.currentUser;
    final profile = SupabaseService.userProfileNotifier.value ?? const <String, dynamic>{};

    final displayName = (profile['full_name'] ??
            user?.userMetadata?['full_name'] ??
            user?.userMetadata?['name'] ??
            'Estudante')
        .toString();

    final rawChannel = (profile['channel'] ?? user?.userMetadata?['channel'] ?? '').toString();
    final cleanChannel = SupabaseService.sanitizeUsername(rawChannel);
    final bio = (profile['bio'] ?? user?.userMetadata?['bio'] ?? '').toString();
    final email = (user?.email ?? profile['email'] ?? '').toString();
    final avatar = (profile['avatar_url'] ?? user?.userMetadata?['avatar_url'])?.toString();

    setState(() {
      _nameController.text = displayName;
      _usernameController.text = cleanChannel;
      _bioController.text = bio;
      _emailController.text = email;
      _avatarUrl = (avatar != null && avatar.trim().isNotEmpty) ? avatar.trim() : null;
      _currentSavedChannel = cleanChannel;
    });
  }

  Future<void> _loadIdentities() async {
    setState(() => _loadingIdentities = true);
    final list = await SupabaseService.getLinkedIdentities();
    if (mounted) {
      setState(() {
        _identities = list;
        _loadingIdentities = false;
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showNotice(String title, String message, _ProfileNoticeTone tone) {
    setState(() {
      _noticeTitle = title;
      _noticeMessage = message;
      _noticeTone = tone;
    });
  }

  void _clearNotice() {
    if (_noticeMessage != null) {
      setState(() {
        _noticeTitle = null;
        _noticeMessage = null;
      });
    }
  }

  Future<void> _pickAvatar() async {
    _clearNotice();
    try {
      if (ProfileSettingsDialog.avatarPickerOverrideForTesting != null) {
        final picked = await ProfileSettingsDialog.avatarPickerOverrideForTesting!();
        if (picked != null && mounted) {
          if (SupabaseService.isGifUpload(bytes: picked.bytes, fileName: picked.fileName) &&
              !SupabaseService.isCurrentUserVip) {
            _showNotice(
              'GIF Exclusivo para VIP',
              'Apenas membros VIP podem usar GIFs na foto de perfil. Torne-se VIP para desbloquear avatares animados!',
              _ProfileNoticeTone.warning,
            );
            return;
          }
          setState(() {
            _pendingAvatarBytes = picked.bytes;
            _pendingAvatarFileName = picked.fileName;
          });
        }
        return;
      }

      final files = await FilePicker.pickFiles(
        dialogTitle: 'Selecionar foto de perfil',
        type: FileType.image,
      );
      if (files.isEmpty || !mounted) return;
      final file = files.first;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 5 * 1024 * 1024) {
        _showNotice('Arquivo Muito Grande', 'A foto de perfil deve ter no máximo 5 MB.', _ProfileNoticeTone.warning);
        return;
      }
      if (SupabaseService.isGifUpload(bytes: bytes, fileName: file.name) &&
          !SupabaseService.isCurrentUserVip) {
        _showNotice(
          'GIF Exclusivo para VIP',
          'Apenas membros VIP podem usar GIFs na foto de perfil. Torne-se VIP para desbloquear avatares animados!',
          _ProfileNoticeTone.warning,
        );
        return;
      }
      setState(() {
        _pendingAvatarBytes = bytes;
        _pendingAvatarFileName = file.name;
      });
    } catch (e) {
      if (mounted) {
        _showNotice('Erro ao Selecionar Imagem', SupabaseService.translateAuthError(e), _ProfileNoticeTone.error);
      }
    }
  }

  Future<void> _confirmAvatarUpload() async {
    final bytes = _pendingAvatarBytes;
    final fileName = _pendingAvatarFileName;
    if (bytes == null || fileName == null) return;

    setState(() => _uploadingAvatar = true);
    final res = await SupabaseService.uploadUserAvatar(
      bytes: bytes,
      fileName: fileName,
    );
    if (!mounted) return;

    setState(() {
      _uploadingAvatar = false;
      if (res.ok) {
        _pendingAvatarBytes = null;
        _pendingAvatarFileName = null;
        _avatarUrl = res.profile?['avatar_url']?.toString();
      }
    });

    if (res.ok) {
      _showNotice('Foto Atualizada', res.message ?? 'Foto de perfil salva com sucesso!', _ProfileNoticeTone.success);
    } else {
      _showNotice(
        res.requiresVip ? 'GIF Exclusivo para VIP' : 'Erro no Avatar',
        res.error ?? 'Não foi possível enviar a imagem.',
        res.requiresVip ? _ProfileNoticeTone.warning : _ProfileNoticeTone.error,
      );
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => _uploadingAvatar = true);
    final res = await SupabaseService.removeUserAvatar();
    if (!mounted) return;
    setState(() {
      _uploadingAvatar = false;
      if (res.ok) {
        _avatarUrl = null;
        _pendingAvatarBytes = null;
        _pendingAvatarFileName = null;
      }
    });
    if (res.ok) {
      _showNotice('Foto Removida', res.message ?? 'Foto de perfil removida.', _ProfileNoticeTone.info);
    } else {
      _showNotice('Erro', res.error ?? 'Não foi possível remover a foto.', _ProfileNoticeTone.error);
    }
  }

  Future<void> _saveProfile() async {
    _clearNotice();
    setState(() => _savingProfile = true);
    final res = await SupabaseService.updateUserProfile(
      fullName: _nameController.text,
      username: _usernameController.text,
      bio: _bioController.text,
    );
    if (!mounted) return;
    setState(() => _savingProfile = false);

    if (res.ok) {
      final clean = SupabaseService.sanitizeUsername(_usernameController.text);
      setState(() {
        _currentSavedChannel = clean;
        _usernameController.text = clean;
      });
      _showNotice('Perfil Atualizado', res.message ?? 'Suas informações foram salvas.', _ProfileNoticeTone.success);
    } else {
      _showNotice('Erro ao Salvar Perfil', res.error ?? 'Não foi possível atualizar o perfil.', _ProfileNoticeTone.error);
    }
  }

  Future<void> _saveEmail() async {
    _clearNotice();
    setState(() => _savingEmail = true);
    final res = await SupabaseService.updateUserEmail(_emailController.text);
    if (!mounted) return;
    setState(() => _savingEmail = false);

    if (res.ok) {
      final isSignedOut = SupabaseService.currentUser == null;
      _showNotice(
        isSignedOut ? 'E-mail Atualizado' : 'Link de Confirmação Enviado',
        res.message ?? 'E-mail atualizado.',
        isSignedOut ? _ProfileNoticeTone.success : _ProfileNoticeTone.info,
      );
    } else {
      _showNotice('Erro no E-mail', res.error ?? 'Não foi possível atualizar o e-mail.', _ProfileNoticeTone.warning);
    }
  }

  Future<void> _savePassword() async {
    _clearNotice();
    setState(() => _savingPassword = true);
    final res = await SupabaseService.updateUserPassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
      confirmPassword: _confirmPasswordController.text,
    );
    if (!mounted) return;
    setState(() => _savingPassword = false);

    if (res.ok) {
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _showNotice('Senha Atualizada', res.message ?? 'Sua senha foi alterada com sucesso!', _ProfileNoticeTone.success);
    } else {
      _showNotice('Erro ao Alterar Senha', res.error ?? 'Não foi possível alterar a senha.', _ProfileNoticeTone.warning);
    }
  }

  Future<void> _handleLinkProvider(OAuthProvider provider) async {
    _clearNotice();
    setState(() => _linkingOAuth = true);
    final res = await SupabaseService.linkOAuthIdentity(provider);
    if (!mounted) return;
    setState(() => _linkingOAuth = false);

    final label = provider == OAuthProvider.google ? 'Google' : 'Discord';
    if (res.ok) {
      _showNotice('Vincular $label', res.message ?? 'Fluxo iniciado.', _ProfileNoticeTone.info);
      await _loadIdentities();
    } else {
      _showNotice('Erro ao Vincular $label', res.error ?? 'Falha ao vincular conta.', _ProfileNoticeTone.error);
    }
  }

  Future<void> _handleUnlinkIdentity(LinkedIdentity identity, String providerLabel) async {
    _clearNotice();
    if (_identities.length <= 1) {
      _showNotice(
        'Ação Bloqueada',
        'Você precisa manter ao menos um método de login ativo para não perder o acesso à sua conta.',
        _ProfileNoticeTone.warning,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AsterTheme.card(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
        title: Text(
          'Desvincular $providerLabel?',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AsterTheme.text(ctx)),
        ),
        content: Text(
          'Tem certeza de que deseja desvincular sua conta $providerLabel? Você poderá reconectá-la a qualquer momento.',
          style: GoogleFonts.manrope(fontSize: 13, color: AsterTheme.textMuted(ctx)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: GoogleFonts.manrope(color: AsterTheme.textMuted(ctx), fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Desvincular', style: GoogleFonts.manrope(color: AsterConstants.coral, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final res = await SupabaseService.unlinkOAuthIdentity(
      identity,
      totalIdentities: _identities.length,
    );
    if (!mounted) return;

    if (res.ok) {
      _showNotice('Conta Desvinculada', res.message ?? 'Conta $providerLabel desvinculada com sucesso.', _ProfileNoticeTone.success);
      await _loadIdentities();
    } else {
      _showNotice('Erro ao Desvincular', res.error ?? 'Não foi possível desvincular.', _ProfileNoticeTone.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final isAuthenticated = user != null;
    final isEmailConfirmed = user?.emailConfirmedAt != null;
    final isUsernameLockedByVerification =
        isAuthenticated && (_currentSavedChannel?.isNotEmpty ?? false) && !isEmailConfirmed;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryCol = AsterTheme.primary(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 680;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 28,
        vertical: isCompact ? 16 : 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 740),
        child: Container(
          decoration: BoxDecoration(
            color: AsterTheme.card(context),
            borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
            border: Border.all(
              color: AsterTheme.surfaceInset(context).withValues(alpha: 0.7),
            ),
            boxShadow: isDark ? AsterConstants.clayDarkShadow : AsterConstants.clayShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeroHeader(context, isAuthenticated, isEmailConfirmed, primaryCol),
                if (_noticeMessage != null) _buildNoticeBanner(context),
                _buildTabSwitcher(context, primaryCol),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
                    child: _activeTab == 0
                        ? _buildGeneralTab(context, isUsernameLockedByVerification, primaryCol)
                        : _buildSecurityTab(context, isAuthenticated, primaryCol),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader(
    BuildContext context,
    bool isAuthenticated,
    bool isEmailConfirmed,
    Color primaryCol,
  ) {
    final shop = ShopService.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([
        shop.equippedBannerIdNotifier,
        shop.equippedFrameIdNotifier,
        shop.equippedTitleIdNotifier,
        shop.unlockedProfileItemsNotifier,
        SupabaseService.isVipNotifier,
      ]),
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final displayName = _nameController.text.trim().isEmpty
            ? 'Estudante'
            : _nameController.text.trim();
        final cleanChannel = SupabaseService.sanitizeUsername(_usernameController.text);
        final handleLabel = cleanChannel.isEmpty ? '@usuario' : '@$cleanChannel';
        final initials = displayName.substring(0, displayName.length >= 2 ? 2 : 1).toUpperCase();

        final ImageProvider<Object>? avatarProvider = _pendingAvatarBytes != null
            ? MemoryImage(_pendingAvatarBytes!)
            : buildAvatarImageProvider(_avatarUrl);
        final isVip = SupabaseService.isCurrentUserVip;

        final bannerId = shop.equippedBannerIdNotifier.value;
        final equippedBanner = ProfileCosmeticsCatalog.equippedBannerFor(bannerId);
        final hasCustomBanner =
            equippedBanner != null && equippedBanner.gradientColors.isNotEmpty;

        final frameId = shop.equippedFrameIdNotifier.value;
        final equippedFrame = ProfileCosmeticsCatalog.equippedFrameFor(frameId);
        final hasCustomFrame = equippedFrame != null;

        final titleId = shop.equippedTitleIdNotifier.value;
        final equippedTitle = ProfileCosmeticsCatalog.equippedTitleFor(titleId);

        final bannerDecoration = hasCustomBanner
            ? buildProfileBannerDecoration(
                bannerId: bannerId,
                elo: RankingEloCatalog.tierAt(0),
                fallbackPrimary: primaryCol,
                isDark: isDark,
              )
            : null;

        final chipBackFill = hasCustomBanner
            ? AsterTheme.card(context).withValues(alpha: isDark ? 0.72 : 0.86)
            : null;

        return AnimatedContainer(
          key: ValueKey('profile_header_banner_${bannerId ?? 'default'}'),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: AsterTheme.surfaceAlt(context),
            border: Border(
              bottom: BorderSide(color: AsterTheme.surfaceInset(context)),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 18, 16, 18),
            decoration: bannerDecoration,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    VipAvatarCircle(
                      key: ValueKey('profile_header_frame_${frameId ?? 'default'}'),
                      isVip: isVip,
                      badgeSize: VipBadgeSize.sm,
                      interactiveBadge: true,
                      fallbackBorderColor: primaryCol,
                      borderWidth: hasCustomFrame ? 3.2 : 2.5,
                      customGradientColors: hasCustomFrame
                          ? (equippedFrame.gradientColors.length >= 2
                              ? equippedFrame.gradientColors
                              : [
                                  equippedFrame.accentColor,
                                  equippedFrame.accentColor.withValues(alpha: 0.65),
                                ])
                          : null,
                      customGlowColor: hasCustomFrame ? equippedFrame.accentColor : null,
                      child: Container(
                        padding: hasCustomFrame ? const EdgeInsets.all(2.2) : EdgeInsets.zero,
                        decoration: hasCustomFrame
                            ? BoxDecoration(
                                color: AsterTheme.card(context),
                                shape: BoxShape.circle,
                              )
                            : null,
                        child: CircleAvatar(
                          radius: 34,
                          backgroundColor: primaryCol.withValues(alpha: 0.14),
                          backgroundImage: avatarProvider,
                          onBackgroundImageError: avatarProvider != null ? (_, _) {} : null,
                          child: avatarProvider == null
                              ? Text(
                                  initials,
                                  style: GoogleFonts.manrope(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: primaryCol,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Material(
                        color: isVip ? AsterVipColors.gold : primaryCol,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          key: const Key('profile_avatar_edit_button'),
                          customBorder: const CircleBorder(),
                          onTap: _uploadingAvatar ? null : _pickAvatar,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              Icons.photo_camera_rounded,
                              size: 14,
                              color: isVip ? AsterVipColors.inkBase : AsterTheme.onPrimary(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AsterTheme.text(context),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          if (equippedTitle != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              key: Key('profile_header_title_${equippedTitle.id}'),
                              decoration: chipBackFill != null
                                  ? BoxDecoration(
                                      color: chipBackFill,
                                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                    )
                                  : null,
                              child: ProfileTitleBadge(titleId: titleId),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: chipBackFill ?? primaryCol.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: primaryCol.withValues(alpha: 0.32)),
                            ),
                            child: Text(
                              cleanChannel.isEmpty ? '$handleLabel · padrão' : handleLabel,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: primaryCol,
                              ),
                            ),
                          ),
                          _buildStatusChip(
                            context,
                            label: isAuthenticated ? 'Conta Aster' : 'Conta Local',
                            color: isAuthenticated ? AsterConstants.menta : AsterConstants.ambar,
                            backingColor: chipBackFill,
                          ),
                          if (isVip)
                            const VipBadgePill(
                              key: Key('profile_vip_status_badge'),
                              size: VipBadgeSize.md,
                              interactive: true,
                            )
                          else
                            InkWell(
                              key: const Key('profile_vip_cta_button'),
                              onTap: () => showVipPrivilegesModal(context),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: chipBackFill ?? AsterVipColors.gold.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AsterVipColors.gold.withValues(alpha: 0.35)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const VipCrownIcon(size: 11),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Ver Privilégios VIP',
                                      style: GoogleFonts.manrope(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: AsterVipColors.goldDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (isAuthenticated)
                            _buildStatusChip(
                              context,
                              label: isEmailConfirmed ? 'E-mail verificado' : 'E-mail não verificado',
                              color: isEmailConfirmed ? AsterConstants.menta : AsterConstants.ambar,
                              backingColor: chipBackFill,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.of(context).pop(),
                  style: chipBackFill != null
                      ? IconButton.styleFrom(backgroundColor: chipBackFill)
                      : null,
                  icon: Icon(Icons.close_rounded, color: AsterTheme.text(context)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(
    BuildContext context, {
    required String label,
    required Color color,
    Color? backingColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backingColor ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: backingColor != null ? Border.all(color: color.withValues(alpha: 0.35)) : null,
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildNoticeBanner(BuildContext context) {
    final Color color;
    final IconData icon;
    switch (_noticeTone) {
      case _ProfileNoticeTone.success:
        color = AsterConstants.menta;
        icon = Icons.check_circle_rounded;
      case _ProfileNoticeTone.warning:
        color = AsterConstants.ambar;
        icon = Icons.warning_amber_rounded;
      case _ProfileNoticeTone.error:
        color = AsterConstants.coral;
        icon = Icons.error_outline_rounded;
      case _ProfileNoticeTone.info:
        color = AsterTheme.primary(context);
        icon = Icons.info_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(22, 12, 22, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_noticeTitle != null)
                  Text(
                    _noticeTitle!,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                Text(
                  _noticeMessage ?? '',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AsterTheme.text(context),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: _clearNotice,
            child: Icon(Icons.close_rounded, size: 16, color: AsterTheme.textMuted(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher(BuildContext context, Color primaryCol) {
    return Container(
      margin: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AsterTheme.surfaceAlt(context),
        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
        border: Border.all(color: AsterTheme.surfaceInset(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              context,
              key: const Key('profile_tab_general'),
              index: 0,
              icon: Icons.person_outline_rounded,
              label: 'Geral',
              primaryCol: primaryCol,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTabButton(
              context,
              key: const Key('profile_tab_security'),
              index: 1,
              icon: Icons.shield_outlined,
              label: 'Segurança & Contas',
              primaryCol: primaryCol,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    BuildContext context, {
    required Key key,
    required int index,
    required IconData icon,
    required String label,
    required Color primaryCol,
  }) {
    final selected = _activeTab == index;
    return Material(
      color: selected ? primaryCol : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _activeTab = index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? AsterTheme.onPrimary(context) : AsterTheme.textMuted(context),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: selected ? AsterTheme.onPrimary(context) : AsterTheme.text(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralTab(
    BuildContext context,
    bool isUsernameLockedByVerification,
    Color primaryCol,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Foto de Perfil
        _buildSectionCard(
          context,
          title: 'Foto de Perfil',
          accentColor: primaryCol,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    key: const Key('profile_pick_avatar_button'),
                    onPressed: _uploadingAvatar ? null : _pickAvatar,
                    icon: const Icon(Icons.upload_rounded, size: 16),
                    label: Text(
                      'Alterar Foto',
                      style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryCol,
                      side: BorderSide(color: primaryCol.withValues(alpha: 0.6)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  if (_avatarUrl != null && _pendingAvatarBytes == null)
                    TextButton.icon(
                      key: const Key('profile_remove_avatar_button'),
                      onPressed: _uploadingAvatar ? null : _removeAvatar,
                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AsterConstants.coral),
                      label: Text(
                        'Remover Foto',
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AsterConstants.coral,
                        ),
                      ),
                    ),
                  Text(
                    SupabaseService.isCurrentUserVip
                        ? 'PNG, JPG, WEBP ou GIF animado até 5 MB'
                        : 'PNG, JPG ou WEBP até 5 MB',
                    style: GoogleFonts.manrope(fontSize: 11.5, color: AsterTheme.textMuted(context)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              InkWell(
                key: const Key('profile_gif_vip_notice'),
                onTap: () => showVipPrivilegesModal(context),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  decoration: BoxDecoration(
                    color: AsterVipColors.gold.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AsterVipColors.gold.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const VipCrownIcon(size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          SupabaseService.isCurrentUserVip
                              ? 'Seu passe VIP libera GIFs animados na foto de perfil.'
                              : 'Apenas quem é VIP pode usar GIF na foto de perfil. Toque para ver os privilégios VIP.',
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AsterTheme.text(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const VipBadgePill(size: VipBadgeSize.xs, interactive: false),
                    ],
                  ),
                ),
              ),
              if (_pendingAvatarBytes != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AsterTheme.surfaceAlt(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryCol.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundImage: MemoryImage(_pendingAvatarBytes!),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Prévia da nova foto',
                              style: GoogleFonts.manrope(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AsterTheme.text(context),
                              ),
                            ),
                            Text(
                              _pendingAvatarFileName ?? 'avatar.png',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                color: AsterTheme.textMuted(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _uploadingAvatar
                            ? null
                            : () => setState(() {
                                  _pendingAvatarBytes = null;
                                  _pendingAvatarFileName = null;
                                }),
                        child: Text(
                          'Cancelar',
                          style: GoogleFonts.manrope(fontSize: 12, color: AsterTheme.textMuted(context)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        key: const Key('profile_confirm_avatar_button'),
                        onPressed: _uploadingAvatar ? null : _confirmAvatarUpload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryCol,
                          foregroundColor: AsterTheme.onPrimary(context),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          _uploadingAvatar ? 'Salvando...' : 'Salvar Foto',
                          style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Identidade (@usuario e Nome de Exibição — lógica StudioOS)
        _buildSectionCard(
          context,
          title: 'Identidade & Nome de Usuário',
          accentColor: AsterConstants.lavanda,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFieldLabel(context, 'NOME DE EXIBIÇÃO'),
              const SizedBox(height: 6),
              TextField(
                key: const Key('profile_name_field'),
                controller: _nameController,
                maxLength: 50,
                onChanged: (_) => setState(() {}),
                decoration: _inputDecoration(
                  context,
                  hint: 'Seu nome de exibição',
                  icon: Icons.badge_outlined,
                ),
                style: GoogleFonts.manrope(fontSize: 13.5, color: AsterTheme.text(context)),
              ),
              const SizedBox(height: 10),
              _buildFieldLabel(context, 'NOME DE USUÁRIO (@ ÚNICO)'),
              const SizedBox(height: 6),
              TextField(
                key: const Key('profile_username_field'),
                controller: _usernameController,
                readOnly: isUsernameLockedByVerification,
                maxLength: 30,
                onChanged: (val) {
                  final clean = SupabaseService.sanitizeUsername(val);
                  if (clean != val) {
                    _usernameController.value = TextEditingValue(
                      text: clean,
                      selection: TextSelection.collapsed(offset: clean.length),
                    );
                  }
                  setState(() {});
                },
                decoration: _inputDecoration(
                  context,
                  hint: 'usuario',
                  prefixText: '@',
                  icon: Icons.alternate_email_rounded,
                  enabled: !isUsernameLockedByVerification,
                ),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: primaryCol,
                ),
              ),
              if (isUsernameLockedByVerification) ...[
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AsterConstants.ambar.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AsterConstants.ambar.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 15, color: AsterConstants.ambar),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Confirme seu e-mail na caixa de entrada para poder alterar seu @usuario.',
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AsterConstants.ambar,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Apenas letras minúsculas, números, ".", "_" e "-".',
                    style: GoogleFonts.manrope(fontSize: 11, color: AsterTheme.textMuted(context)),
                  ),
                ),
              const SizedBox(height: 14),
              _buildFieldLabel(context, 'BIO'),
              const SizedBox(height: 6),
              TextField(
                key: const Key('profile_bio_field'),
                controller: _bioController,
                maxLines: 3,
                maxLength: 280,
                decoration: _inputDecoration(
                  context,
                  hint: 'Conte brevemente sobre seus objetivos de estudo...',
                ),
                style: GoogleFonts.manrope(fontSize: 13, color: AsterTheme.text(context)),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: SoftClayPillButton(
                  key: const Key('profile_save_button'),
                  text: _savingProfile ? 'Salvando...' : 'Salvar Perfil',
                  onPressed: _savingProfile ? () {} : _saveProfile,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Personalização do Perfil (Capa, Moldura e Título desbloqueados na Loja / VIP)
        _buildProfileAppearanceCard(context, primaryCol),
      ],
    );
  }

  Widget _buildProfileAppearanceCard(BuildContext context, Color primaryCol) {
    final shop = ShopService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _buildSectionCard(
      context,
      title: 'Capa, Moldura & Título',
      accentColor: primaryCol,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          shop.unlockedProfileItemsNotifier,
          shop.equippedBannerIdNotifier,
          shop.equippedFrameIdNotifier,
          shop.equippedTitleIdNotifier,
          SupabaseService.isVipNotifier,
        ]),
        builder: (ctx, _) {
          final isVip = SupabaseService.isCurrentUserVip;
          final allInCat = ProfileCosmeticsCatalog.byCategory(_cosmeticCategory);
          final unlockedItems =
              allInCat.where((item) => shop.isProfileItemUnlocked(item.id)).toList();
          final lockedItems =
              allInCat.where((item) => !shop.isProfileItemUnlocked(item.id)).toList();

          return Column(
            key: const Key('profile_edit_appearance_section'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Selecione os itens já desbloqueados para personalizar seu perfil público.',
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  color: AsterTheme.textMuted(ctx),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SoftClayChoiceChip(
                    key: const Key('profile_edit_cosmetic_tab_banner'),
                    label: 'Capas',
                    icon: Icons.gradient_rounded,
                    selected: _cosmeticCategory == ProfileCosmeticCategory.banner,
                    compact: true,
                    onTap: () => setState(() => _cosmeticCategory = ProfileCosmeticCategory.banner),
                  ),
                  SoftClayChoiceChip(
                    key: const Key('profile_edit_cosmetic_tab_frame'),
                    label: 'Molduras',
                    icon: Icons.blur_circular_rounded,
                    selected: _cosmeticCategory == ProfileCosmeticCategory.frame,
                    compact: true,
                    onTap: () => setState(() => _cosmeticCategory = ProfileCosmeticCategory.frame),
                  ),
                  SoftClayChoiceChip(
                    key: const Key('profile_edit_cosmetic_tab_title'),
                    label: 'Títulos',
                    icon: Icons.workspace_premium_rounded,
                    selected: _cosmeticCategory == ProfileCosmeticCategory.title,
                    compact: true,
                    onTap: () => setState(() => _cosmeticCategory = ProfileCosmeticCategory.title),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...unlockedItems.map((item) {
                    final equipped = shop.isProfileItemEquipped(item);
                    return InkWell(
                      key: Key('profile_edit_item_${item.id}'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        await shop.equipProfileItem(item.category, item.id);
                        if (!mounted) return;
                        _showNotice(
                          'Visual Atualizado',
                          '${item.name} equipado no seu perfil.',
                          _ProfileNoticeTone.success,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                        decoration: BoxDecoration(
                          color: equipped
                              ? AsterConstants.menta.withValues(alpha: isDark ? 0.18 : 0.13)
                              : AsterTheme.surfaceAlt(ctx),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: equipped
                                ? AsterConstants.menta
                                : item.accentColor.withValues(alpha: 0.30),
                            width: equipped ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (item.category == ProfileCosmeticCategory.banner &&
                                item.gradientColors.isNotEmpty)
                              Container(
                                width: 18,
                                height: 14,
                                margin: const EdgeInsets.only(right: 7),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  gradient: LinearGradient(colors: item.gradientColors),
                                ),
                              )
                            else ...[
                              Icon(item.icon, size: 15, color: item.accentColor),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              item.name,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: equipped ? AsterConstants.menta : AsterTheme.text(ctx),
                              ),
                            ),
                            if (item.isVipOnly) ...[
                              const SizedBox(width: 5),
                              const VipCrownIcon(size: 12),
                            ],
                            if (equipped) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: AsterConstants.menta,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
              if (lockedItems.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AsterTheme.surfaceAlt(ctx),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AsterTheme.surfaceInset(ctx)),
                  ),
                  child: Row(
                    children: [
                      const InsightCoinIcon(size: 15),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isVip
                              ? '${lockedItems.length} itens adicionais disponíveis na Loja com Insights.'
                              : '${lockedItems.length} itens (incluindo exclusivos VIP) disponíveis na Loja.',
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AsterTheme.textMuted(ctx),
                          ),
                        ),
                      ),
                      if (widget.onOpenShop != null) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          key: const Key('profile_edit_open_shop_button'),
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onOpenShop!();
                          },
                          icon: const Icon(Icons.storefront_rounded, size: 15),
                          label: Text(
                            'Abrir Loja',
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSecurityTab(
    BuildContext context,
    bool isAuthenticated,
    Color primaryCol,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. E-mail Vinculado
        _buildSectionCard(
          context,
          title: 'E-mail Vinculado',
          accentColor: AsterConstants.menta,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pode ser alterado. Em contas Aster, exige confirmação na caixa de entrada.',
                style: GoogleFonts.manrope(fontSize: 11.5, color: AsterTheme.textMuted(context)),
              ),
              const SizedBox(height: 10),
              _buildFieldLabel(context, 'ENDEREÇO DE E-MAIL'),
              const SizedBox(height: 6),
              TextField(
                key: const Key('profile_email_field'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration(
                  context,
                  hint: 'seu-email@aster.app',
                  icon: Icons.mail_outline_rounded,
                ),
                style: GoogleFonts.manrope(fontSize: 13.5, color: AsterTheme.text(context)),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  key: const Key('profile_update_email_button'),
                  onPressed: _savingEmail ? null : _saveEmail,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryCol,
                    side: BorderSide(color: primaryCol.withValues(alpha: 0.7)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _savingEmail ? 'Salvando...' : 'Atualizar E-mail',
                    style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Alterar Senha
        _buildSectionCard(
          context,
          title: 'Alterar Senha',
          accentColor: AsterConstants.ambar,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFieldLabel(context, 'SENHA ATUAL'),
              const SizedBox(height: 6),
              TextField(
                key: const Key('profile_current_password_field'),
                controller: _currentPasswordController,
                obscureText: _obscureCurrentPass,
                decoration: _inputDecoration(
                  context,
                  hint: '••••••••',
                  icon: Icons.lock_outline_rounded,
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscureCurrentPass = !_obscureCurrentPass),
                    icon: Icon(
                      _obscureCurrentPass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 18,
                      color: AsterTheme.textMuted(context),
                    ),
                  ),
                ),
                style: GoogleFonts.manrope(fontSize: 13.5, color: AsterTheme.text(context)),
              ),
              const SizedBox(height: 12),
              _buildFieldLabel(context, 'NOVA SENHA (MÍN. 8 CARACTERES)'),
              const SizedBox(height: 6),
              TextField(
                key: const Key('profile_new_password_field'),
                controller: _newPasswordController,
                obscureText: _obscureNewPass,
                decoration: _inputDecoration(
                  context,
                  hint: '••••••••',
                  icon: Icons.vpn_key_outlined,
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscureNewPass = !_obscureNewPass),
                    icon: Icon(
                      _obscureNewPass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 18,
                      color: AsterTheme.textMuted(context),
                    ),
                  ),
                ),
                style: GoogleFonts.manrope(fontSize: 13.5, color: AsterTheme.text(context)),
              ),
              const SizedBox(height: 12),
              _buildFieldLabel(context, 'CONFIRMAR NOVA SENHA'),
              const SizedBox(height: 6),
              TextField(
                key: const Key('profile_confirm_password_field'),
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPass,
                decoration: _inputDecoration(
                  context,
                  hint: '••••••••',
                  icon: Icons.verified_user_outlined,
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                    icon: Icon(
                      _obscureConfirmPass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 18,
                      color: AsterTheme.textMuted(context),
                    ),
                  ),
                ),
                style: GoogleFonts.manrope(fontSize: 13.5, color: AsterTheme.text(context)),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  key: const Key('profile_update_password_button'),
                  onPressed: _savingPassword ? null : _savePassword,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryCol,
                    side: BorderSide(color: primaryCol.withValues(alpha: 0.7)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _savingPassword ? 'Atualizando...' : 'Atualizar Senha',
                    style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Autenticação SSO / Contas Vinculadas (Google / Gmail & Discord)
        _buildSectionCard(
          context,
          title: 'Contas Vinculadas (SSO)',
          accentColor: primaryCol,
          trailing: IconButton(
            key: const Key('profile_refresh_identities_button'),
            tooltip: 'Atualizar conexões',
            onPressed: _loadingIdentities ? null : _loadIdentities,
            icon: Icon(Icons.refresh_rounded, size: 18, color: AsterTheme.textMuted(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isAuthenticated && widget.onRequestSignIn != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: primaryCol.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: primaryCol),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Entre com uma conta Aster para vincular seu Gmail ou Discord.',
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AsterTheme.text(context),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onRequestSignIn?.call();
                        },
                        child: Text(
                          'Fazer Login',
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: primaryCol,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              _buildSsoRow(
                context,
                provider: OAuthProvider.google,
                title: 'Google (Gmail)',
                icon: const GoogleLogoWidget(size: 20),
                linkKey: const Key('profile_link_google_button'),
                unlinkKey: const Key('profile_unlink_google_button'),
              ),
              const SizedBox(height: 10),
              _buildSsoRow(
                context,
                provider: OAuthProvider.discord,
                title: 'Discord',
                icon: const DiscordLogoWidget(size: 20),
                linkKey: const Key('profile_link_discord_button'),
                unlinkKey: const Key('profile_unlink_discord_button'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSsoRow(
    BuildContext context, {
    required OAuthProvider provider,
    required String title,
    required Widget icon,
    required Key linkKey,
    required Key unlinkKey,
  }) {
    final providerKey = provider == OAuthProvider.google ? 'google' : 'discord';
    final connected = _identities.where((i) => i.provider == providerKey).firstOrNull;
    final canUnlink = _identities.length > 1;
    final primaryCol = AsterTheme.primary(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AsterTheme.surfaceAlt(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: connected != null
              ? AsterConstants.menta.withValues(alpha: 0.4)
              : AsterTheme.surfaceInset(context),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AsterTheme.card(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AsterTheme.text(context),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: connected != null ? AsterConstants.menta : AsterTheme.textMuted(context).withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        connected != null
                            ? (connected.accountLabel != null
                                ? 'Conectado (${connected.accountLabel})'
                                : 'Conectado')
                            : 'Não conectado',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: connected != null ? AsterConstants.menta : AsterTheme.textMuted(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (connected != null)
            Tooltip(
              message: canUnlink
                  ? 'Desvincular conta $title'
                  : 'Mantenha ao menos uma forma de login vinculada à sua conta.',
              child: OutlinedButton(
                key: unlinkKey,
                onPressed: canUnlink ? () => _handleUnlinkIdentity(connected, title) : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AsterConstants.coral,
                  side: BorderSide(
                    color: canUnlink
                        ? AsterConstants.coral.withValues(alpha: 0.5)
                        : AsterTheme.surfaceInset(context),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  'Desvincular',
                  style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            )
          else
            OutlinedButton(
              key: linkKey,
              onPressed: _linkingOAuth ? null : () => _handleLinkProvider(provider),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryCol,
                side: BorderSide(color: primaryCol.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Vincular',
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required Color accentColor,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AsterTheme.card(context),
        borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
        border: Border.all(color: AsterTheme.surfaceInset(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AsterTheme.surfaceAlt(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AsterConstants.radiusLarge),
              ),
              border: Border(
                bottom: BorderSide(color: AsterTheme.surfaceInset(context)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AsterTheme.text(context),
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(BuildContext context, String text) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.7,
        color: AsterTheme.textMuted(context),
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String hint,
    IconData? icon,
    String? prefixText,
    Widget? suffixIcon,
    bool enabled = true,
  }) {
    final inset = AsterTheme.surfaceInset(context);
    final primaryCol = AsterTheme.primary(context);

    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.manrope(
        fontSize: 13,
        color: AsterTheme.textMuted(context).withValues(alpha: 0.65),
      ),
      prefixText: prefixText,
      prefixStyle: GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: primaryCol,
      ),
      prefixIcon: icon != null
          ? Icon(icon, size: 18, color: enabled ? AsterTheme.textMuted(context) : AsterConstants.ambar)
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: enabled
          ? AsterTheme.surfaceAlt(context)
          : AsterTheme.surfaceAlt(context).withValues(alpha: 0.6),
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: inset),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: inset),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryCol, width: 1.5),
      ),
    );
  }
}
