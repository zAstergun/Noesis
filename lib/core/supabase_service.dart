import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/flashcards/models/flashcard_model.dart';
import '../features/notebooks/models/notebook_model.dart';
import '../features/quizzes/data/saved_exams_store_stub.dart'
    if (dart.library.io) '../features/quizzes/data/saved_exams_store_io.dart'
    if (dart.library.js_interop) '../features/quizzes/data/saved_exams_store_web.dart' as local_store;
import 'oauth_loopback_stub.dart'
    if (dart.library.io) 'oauth_loopback_io.dart' as oauth_loopback;

class ProfileActionResult {
  final bool ok;
  final String? message;
  final String? error;
  final Map<String, dynamic>? profile;
  final bool requiresVip;

  const ProfileActionResult({
    required this.ok,
    this.message,
    this.error,
    this.profile,
    this.requiresVip = false,
  });
}

class LinkedIdentity {
  final String id;
  final String identityId;
  final String provider;
  final String? accountLabel;
  final UserIdentity? raw;

  const LinkedIdentity({
    required this.id,
    required this.identityId,
    required this.provider,
    this.accountLabel,
    this.raw,
  });
}

class SupabaseService {
  static final SupabaseClient client = Supabase.instance.client;

  // ----------------------------------------------------
  // AUTH & ASTER ACCOUNT
  // ----------------------------------------------------
  static User? get currentUser => client.auth.currentUser;
  static bool get isAuthenticated => currentUser != null;

  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static String authRedirectUrl({Uri? baseUriOverride}) {
    if (kIsWeb || baseUriOverride != null) {
      final base = baseUriOverride ?? Uri.base;
      final isDefaultPort = !base.hasPort ||
          (base.scheme == 'http' && base.port == 80) ||
          (base.scheme == 'https' && base.port == 443);
      return Uri(
        scheme: base.scheme,
        host: base.host,
        port: isDefaultPort ? null : base.port,
        path: base.path.isEmpty ? '/' : base.path,
      ).toString();
    }
    return 'io.supabase.noesis://login-callback/';
  }

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: fullName != null ? {'full_name': fullName} : null,
      emailRedirectTo: authRedirectUrl(),
    );
    return response;
  }

  static Future<bool> signInWithOAuth(OAuthProvider provider) async {
    final scopes = provider == OAuthProvider.discord ? 'identify email' : null;
    if (oauth_loopback.isDesktopLoopbackPlatform) {
      return await oauth_loopback.runDesktopOAuthLoopback(
        client: client,
        startAuthFlow: (redirectUrl) => client.auth.getOAuthSignInUrl(
          provider: provider,
          scopes: scopes,
          redirectTo: redirectUrl,
        ),
      );
    }
    return await client.auth.signInWithOAuth(
      provider,
      scopes: scopes,
      redirectTo: authRedirectUrl(),
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static const String _localProfileStorageKey = 'noesis_local_profile_v1';
  static final ValueNotifier<Map<String, dynamic>?> userProfileNotifier =
      ValueNotifier<Map<String, dynamic>?>(null);
  static final ValueNotifier<bool> isVipNotifier = ValueNotifier<bool>(false);

  @visibleForTesting
  static bool? isVipOverrideForTesting;

  static bool get isCurrentUserVip {
    if (isVipOverrideForTesting != null) {
      return isVipOverrideForTesting!;
    }
    final prof = userProfileNotifier.value;
    if (prof != null && prof['is_vip'] == true) {
      return true;
    }
    final user = currentUser;
    if (user == null) return false;
    return user.userMetadata?['is_vip'] == true || user.appMetadata['is_vip'] == true;
  }

  @visibleForTesting
  static void setVipForTesting(bool? vip) {
    isVipOverrideForTesting = vip;
    final current = userProfileNotifier.value;
    if (current != null && vip != null) {
      userProfileNotifier.value = Map<String, dynamic>.from(current)..['is_vip'] = vip;
    }
    isVipNotifier.value = isCurrentUserVip;
  }

  /// Gancho apenas para testes de widget validarem vinculação/desvinculação OAuth offline.
  @visibleForTesting
  static List<LinkedIdentity>? linkedIdentitiesOverrideForTesting;

  @visibleForTesting
  static Future<void> resetProfileForTesting() async {
    linkedIdentitiesOverrideForTesting = null;
    isVipOverrideForTesting = null;
    isVipNotifier.value = false;
    userProfileNotifier.value = null;
    await _writeLocalProfileCache(const {});
  }

  static Future<Map<String, dynamic>?> getProfile() async {
    return loadFullProfile();
  }

  static Future<Map<String, dynamic>?> _readLocalProfileCache() async {
    try {
      final raw = await local_store.readSavedExamsRaw(_localProfileStorageKey);
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  static Future<void> _writeLocalProfileCache(Map<String, dynamic> data) async {
    try {
      await local_store.writeSavedExamsRaw(
        _localProfileStorageKey,
        jsonEncode(data),
      );
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> loadFullProfile() async {
    final user = currentUser;
    final localCache = await _readLocalProfileCache();

    if (user == null) {
      if (localCache != null) {
        userProfileNotifier.value = localCache;
      }
      isVipNotifier.value = isCurrentUserVip;
      return localCache;
    }

    final meta = Map<String, dynamic>.from(user.userMetadata ?? const {});
    final customClaims = meta['custom_claims'] is Map
        ? Map<String, dynamic>.from(meta['custom_claims'] as Map)
        : const <String, dynamic>{};

    final merged = <String, dynamic>{
      'id': user.id,
      'email': user.email ?? '',
      'email_confirmed_at': user.emailConfirmedAt,
      'full_name': meta['full_name'] ??
          meta['name'] ??
          customClaims['global_name'] ??
          meta['user_name'] ??
          meta['preferred_username'] ??
          user.email?.split('@').first ??
          'Estudante',
      'channel': meta['channel'],
      'avatar_url': meta['avatar_url'] ?? meta['picture'],
      'bio': meta['bio'],
      'is_vip': meta['is_vip'] == true || user.appMetadata['is_vip'] == true,
    };

    try {
      final res = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (res != null) {
        if ((res['full_name'] ?? '').toString().trim().isNotEmpty) {
          merged['full_name'] = res['full_name'];
        }
        if ((res['channel'] ?? '').toString().trim().isNotEmpty) {
          merged['channel'] = res['channel'];
        }
        if ((res['avatar_url'] ?? '').toString().trim().isNotEmpty) {
          merged['avatar_url'] = res['avatar_url'];
        }
        if (res['bio'] != null) {
          merged['bio'] = res['bio'];
        }
        if (res['is_vip'] is bool) {
          merged['is_vip'] = res['is_vip'];
        }
        if (res['stats'] != null) {
          merged['stats'] = res['stats'];
        }
      }
    } catch (e) {
      debugPrint('Error loading Aster Profile: $e');
    }

    userProfileNotifier.value = merged;
    isVipNotifier.value = isCurrentUserVip;
    return merged;
  }

  /// Normaliza nome de usuário (@ único) no padrão do StudioOS.
  static String sanitizeUsername(String raw) {
    return raw
        .trim()
        .replaceFirst(RegExp(r'^@+'), '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_.-]'), '');
  }

  /// Traduz mensagens técnicas do Supabase Auth/Postgres para português (mesma lógica do StudioOS).
  static String translateAuthError(Object error) {
    final msg = error
        .toString()
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^AuthException:\s*'), '')
        .trim();
    final m = msg.toLowerCase();
    if (m.contains('invalid login credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    if (m.contains('email not confirmed')) {
      return 'Confirme seu e-mail antes de entrar. Verifique a caixa de entrada.';
    }
    if (m.contains('user already registered') || m.contains('already been registered')) {
      return 'Já existe uma conta com esse e-mail.';
    }
    if (m.contains('password should be at least')) {
      return 'A senha precisa ter pelo menos 6 caracteres.';
    }
    if (m.contains('new password should be different')) {
      return 'A nova senha deve ser diferente da senha atual.';
    }
    if (m.contains('rate limit') || m.contains('too many')) {
      return 'Muitas tentativas. Aguarde um minuto e tente de novo.';
    }
    if (m.contains('unable to validate email') || m.contains('invalid email')) {
      return 'E-mail inválido.';
    }
    if (m.contains('network') || m.contains('fetch') || m.contains('socketexception')) {
      return 'Falha de conexão. Verifique sua internet.';
    }
    if (m.contains('provider is not enabled')) {
      return 'Esse provedor de login não está habilitado no Supabase (Authentication → Providers).';
    }
    if (m.contains('manual linking is disabled')) {
      return 'A vinculação e desvinculação manual de contas está desativada no servidor.';
    }
    if (m.contains('only one identity') ||
        m.contains('cannot unlink') ||
        m.contains('at least 2') ||
        m.contains('last identity')) {
      return 'Você precisa manter ao menos um método de login ativo para não perder o acesso à sua conta.';
    }
    if (m.contains('identity not found')) {
      return 'Identidade externa não encontrada ou já desvinculada.';
    }
    if (m.contains('already linked') || m.contains('identity is already')) {
      return 'Essa conta externa já está vinculada a outro usuário.';
    }
    if (m.contains('access_denied') || m.contains('did not authorize')) {
      return 'Autorização cancelada. Você pode tentar novamente quando quiser.';
    }
    if (m.contains('flow_state_already_used') || m.contains('state has already been used')) {
      return 'Esta tentativa de login já foi usada ou expirou. Tente entrar novamente.';
    }
    if (m.contains('oauth')) {
      return 'Não foi possível iniciar o login externo. Tente de novo.';
    }
    if (m.contains('23505') || m.contains('duplicate key') || m.contains('profiles_channel_key') || m.contains('unique')) {
      return 'Este nome de usuário (@) já está em uso por outro usuário. Escolha outro.';
    }
    return msg;
  }

  /// Extrai e traduz erro retornado via query ou fragmento no callback OAuth.
  static String? extractOAuthCallbackError(Uri uri) {
    final params = <String, String>{...uri.queryParameters};
    if (uri.fragment.isNotEmpty) {
      try {
        params.addAll(Uri.splitQueryString(uri.fragment));
      } catch (_) {}
    }
    final err = params['error']?.trim() ?? '';
    final errCode = params['error_code']?.trim() ?? '';
    final errDesc = params['error_description']?.trim() ?? '';
    if (err.isEmpty && errCode.isEmpty && errDesc.isEmpty) {
      return null;
    }
    return translateAuthError('$err $errCode $errDesc'.trim());
  }

  /// Valida os parâmetros de atualização de perfil antes de persistir (regra idêntica ao StudioOS).
  static String? validateProfileUpdate({
    required String newUsername,
    required String? currentUsername,
    required bool isEmailConfirmed,
    required bool isAuthenticatedUser,
  }) {
    final cleanNew = newUsername.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();
    final cleanCurrent = (currentUsername ?? '').trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();

    if (isAuthenticatedUser && cleanCurrent.isNotEmpty && cleanNew != cleanCurrent && !isEmailConfirmed) {
      return 'Você só pode alterar seu nome de usuário (@) após verificar o seu e-mail. Verifique a caixa de entrada da sua conta para liberar a alteração.';
    }
    if (cleanNew.isNotEmpty && !RegExp(r'^[a-z0-9_.-]+$').hasMatch(cleanNew)) {
      return 'O nome de usuário (@) só pode conter letras minúsculas, números, sublinhados (_), hífens (-) e pontos (.).';
    }
    return null;
  }

  static Future<ProfileActionResult> updateUserProfile({
    required String fullName,
    required String username,
    String? bio,
  }) async {
    final trimmedName = fullName.trim().isEmpty ? 'Estudante' : fullName.trim();
    final cleanHandle = username.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();
    final trimmedBio = bio?.trim();
    final user = currentUser;
    final currentMap = userProfileNotifier.value ?? await _readLocalProfileCache() ?? <String, dynamic>{};
    final currentChannel = (currentMap['channel'] ?? user?.userMetadata?['channel'] ?? '').toString();

    final validationError = validateProfileUpdate(
      newUsername: cleanHandle,
      currentUsername: currentChannel,
      isEmailConfirmed: user?.emailConfirmedAt != null,
      isAuthenticatedUser: user != null,
    );
    if (validationError != null) {
      return ProfileActionResult(ok: false, error: validationError);
    }

    if (user == null) {
      final updated = Map<String, dynamic>.from(currentMap)
        ..['full_name'] = trimmedName
        ..['channel'] = cleanHandle.isEmpty ? null : cleanHandle
        ..['bio'] = trimmedBio
        ..['updated_at'] = DateTime.now().toIso8601String();
      await _writeLocalProfileCache(updated);
      userProfileNotifier.value = updated;
      return ProfileActionResult(
        ok: true,
        message: 'Perfil atualizado com sucesso.',
        profile: updated,
      );
    }

    try {
      final upsertData = <String, dynamic>{
        'id': user.id,
        'full_name': trimmedName,
        'channel': cleanHandle.isEmpty ? null : cleanHandle,
        if (currentMap['avatar_url'] != null) 'avatar_url': currentMap['avatar_url'],
        'bio': ?trimmedBio,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Atualiza primeiro no Postgres para validar restrição UNIQUE de @username
      try {
        await client.from('profiles').upsert(upsertData);
      } catch (dbErr) {
        final msg = dbErr.toString().toLowerCase();
        if (msg.contains('23505') || msg.contains('unique') || msg.contains('profiles_channel_key')) {
          return const ProfileActionResult(
            ok: false,
            error: 'Este nome de usuário (@) já está em uso por outro usuário. Escolha outro.',
          );
        }
        // Se a coluna bio ainda não existir em alguma tabela antiga, tenta sem bio
        if (msg.contains('bio') && msg.contains('column')) {
          upsertData.remove('bio');
          await client.from('profiles').upsert(upsertData);
        } else {
          return ProfileActionResult(ok: false, error: translateAuthError(dbErr));
        }
      }

      await client.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': trimmedName,
            'channel': cleanHandle.isEmpty ? null : cleanHandle,
            'bio': ?trimmedBio,
          },
        ),
      );

      final refreshed = Map<String, dynamic>.from(currentMap)
        ..['id'] = user.id
        ..['email'] = user.email ?? currentMap['email'] ?? ''
        ..['email_confirmed_at'] = user.emailConfirmedAt
        ..['full_name'] = trimmedName
        ..['channel'] = cleanHandle.isEmpty ? null : cleanHandle
        ..['bio'] = trimmedBio
        ..['updated_at'] = DateTime.now().toIso8601String();
      userProfileNotifier.value = refreshed;
      return ProfileActionResult(
        ok: true,
        message: 'Perfil atualizado com sucesso.',
        profile: refreshed,
      );
    } catch (e) {
      return ProfileActionResult(ok: false, error: translateAuthError(e));
    }
  }

  static Future<ProfileActionResult> updateUserEmail(String newEmail) async {
    final trimmed = newEmail.trim();
    if (trimmed.isEmpty) {
      return const ProfileActionResult(
        ok: false,
        error: 'Por favor, digite um endereço de e-mail válido.',
      );
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed)) {
      return const ProfileActionResult(ok: false, error: 'E-mail inválido.');
    }

    final user = currentUser;
    final currentMap = userProfileNotifier.value ?? await _readLocalProfileCache() ?? <String, dynamic>{};
    final currentEmail = (user?.email ?? currentMap['email'] ?? '').toString().trim();

    if (trimmed.toLowerCase() == currentEmail.toLowerCase()) {
      return const ProfileActionResult(
        ok: false,
        error: 'O endereço digitado já é o seu e-mail cadastrado atualmente.',
      );
    }

    if (user == null) {
      final updated = Map<String, dynamic>.from(currentMap)
        ..['email'] = trimmed
        ..['updated_at'] = DateTime.now().toIso8601String();
      await _writeLocalProfileCache(updated);
      userProfileNotifier.value = updated;
      return ProfileActionResult(
        ok: true,
        message: 'E-mail local atualizado para $trimmed.',
        profile: updated,
      );
    }

    try {
      await client.auth.updateUser(
        UserAttributes(email: trimmed),
        emailRedirectTo: authRedirectUrl(),
      );
      return const ProfileActionResult(
        ok: true,
        message:
            'Enviamos um link de confirmação para o novo e-mail. Verifique sua caixa de entrada para concluir a alteração.',
      );
    } catch (e) {
      return ProfileActionResult(ok: false, error: translateAuthError(e));
    }
  }

  static Future<ProfileActionResult> updateUserPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (currentPassword.isEmpty) {
      return const ProfileActionResult(
        ok: false,
        error: 'Por favor, digite sua senha atual para continuar.',
      );
    }
    if (newPassword.isEmpty || newPassword != confirmPassword) {
      return const ProfileActionResult(
        ok: false,
        error: 'As novas senhas digitadas não coincidem ou estão vazias.',
      );
    }
    if (newPassword.length < 8) {
      return const ProfileActionResult(
        ok: false,
        error: 'A nova senha deve ter no mínimo 8 caracteres para sua segurança.',
      );
    }

    final user = currentUser;
    if (user == null) {
      return const ProfileActionResult(
        ok: false,
        error: 'A alteração de senha requer uma conta Aster autenticada.',
      );
    }

    try {
      await client.auth.updateUser(
        UserAttributes(
          password: newPassword,
          currentPassword: currentPassword,
        ),
      );
      return const ProfileActionResult(
        ok: true,
        message: 'Sua senha foi alterada com sucesso!',
      );
    } catch (e) {
      return ProfileActionResult(ok: false, error: translateAuthError(e));
    }
  }

  static String _mimeTypeForExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }

  static bool isGifUpload({required Uint8List bytes, required String fileName}) {
    final lowerName = fileName.trim().toLowerCase();
    if (lowerName.endsWith('.gif')) return true;
    if (bytes.length >= 6) {
      final header = String.fromCharCodes(bytes.sublist(0, 6));
      if (header == 'GIF87a' || header == 'GIF89a') return true;
    }
    return false;
  }

  static Future<ProfileActionResult> uploadUserAvatar({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (bytes.isEmpty) {
      return const ProfileActionResult(ok: false, error: 'Arquivo de imagem vazio.');
    }
    if (bytes.length > 5 * 1024 * 1024) {
      return const ProfileActionResult(
        ok: false,
        error: 'A imagem deve ter no máximo 5 MB.',
      );
    }

    final isGif = isGifUpload(bytes: bytes, fileName: fileName);
    if (isGif && !isCurrentUserVip) {
      return const ProfileActionResult(
        ok: false,
        requiresVip: true,
        error:
            'Apenas membros VIP podem usar GIFs na foto de perfil. Torne-se VIP para desbloquear avatares animados!',
      );
    }

    final dotIdx = fileName.lastIndexOf('.');
    final rawExt = dotIdx >= 0 ? fileName.substring(dotIdx + 1).toLowerCase() : 'jpg';
    final ext = const {'png', 'jpg', 'jpeg', 'webp', 'gif'}.contains(rawExt) ? rawExt : 'jpg';
    final mime = _mimeTypeForExtension(ext);
    final currentMap = userProfileNotifier.value ?? await _readLocalProfileCache() ?? <String, dynamic>{};
    final user = currentUser;

    if (user == null) {
      final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';
      final updated = Map<String, dynamic>.from(currentMap)
        ..['avatar_url'] = dataUri
        ..['updated_at'] = DateTime.now().toIso8601String();
      await _writeLocalProfileCache(updated);
      userProfileNotifier.value = updated;
      return ProfileActionResult(
        ok: true,
        message: 'Foto de perfil atualizada!',
        profile: updated,
      );
    }

    try {
      final objectPath = '${user.id}-${DateTime.now().millisecondsSinceEpoch}.$ext';
      await client.storage.from('avatars').uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: mime),
          );
      final publicUrl = client.storage.from('avatars').getPublicUrl(objectPath);

      await client.auth.updateUser(UserAttributes(data: {'avatar_url': publicUrl}));
      await client.from('profiles').upsert({
        'id': user.id,
        'avatar_url': publicUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      final updated = Map<String, dynamic>.from(currentMap)
        ..['id'] = user.id
        ..['avatar_url'] = publicUrl
        ..['updated_at'] = DateTime.now().toIso8601String();
      userProfileNotifier.value = updated;
      return ProfileActionResult(
        ok: true,
        message: 'Foto de perfil atualizada!',
        profile: updated,
      );
    } catch (e) {
      return ProfileActionResult(ok: false, error: translateAuthError(e));
    }
  }

  static Future<ProfileActionResult> removeUserAvatar() async {
    final currentMap = userProfileNotifier.value ?? await _readLocalProfileCache() ?? <String, dynamic>{};
    final user = currentUser;

    if (user == null) {
      final updated = Map<String, dynamic>.from(currentMap)
        ..remove('avatar_url')
        ..['updated_at'] = DateTime.now().toIso8601String();
      await _writeLocalProfileCache(updated);
      userProfileNotifier.value = updated;
      return ProfileActionResult(
        ok: true,
        message: 'Foto de perfil removida.',
        profile: updated,
      );
    }

    try {
      await client.auth.updateUser(UserAttributes(data: {'avatar_url': null}));
      await client.from('profiles').upsert({
        'id': user.id,
        'avatar_url': null,
        'updated_at': DateTime.now().toIso8601String(),
      });
      final updated = Map<String, dynamic>.from(currentMap)
        ..remove('avatar_url')
        ..['updated_at'] = DateTime.now().toIso8601String();
      userProfileNotifier.value = updated;
      return ProfileActionResult(
        ok: true,
        message: 'Foto de perfil removida.',
        profile: updated,
      );
    } catch (e) {
      return ProfileActionResult(ok: false, error: translateAuthError(e));
    }
  }

  static String? _extractIdentityLabel(String provider, Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return null;
    if (provider == 'google') {
      final label = (data['email'] ?? data['name'] ?? '').toString().trim();
      return label.isEmpty ? null : label;
    }
    if (provider == 'discord') {
      final claims = data['custom_claims'] is Map
          ? Map<String, dynamic>.from(data['custom_claims'] as Map)
          : const <String, dynamic>{};
      final label = (claims['global_name'] ??
              data['preferred_username'] ??
              data['user_name'] ??
              data['name'] ??
              data['email'] ??
              '')
          .toString()
          .trim();
      return label.isEmpty ? null : label;
    }
    final fallback = (data['email'] ?? data['name'] ?? '').toString().trim();
    return fallback.isEmpty ? null : fallback;
  }

  static Future<List<LinkedIdentity>> getLinkedIdentities() async {
    if (linkedIdentitiesOverrideForTesting != null) {
      return List<LinkedIdentity>.from(linkedIdentitiesOverrideForTesting!);
    }
    final user = currentUser;
    if (user == null) return const [];

    List<UserIdentity> rawList = const [];
    try {
      rawList = await client.auth.getUserIdentities();
    } catch (_) {
      rawList = user.identities ?? const [];
    }

    return rawList
        .map(
          (i) => LinkedIdentity(
            id: i.id,
            identityId: i.identityId,
            provider: i.provider.toLowerCase(),
            accountLabel: _extractIdentityLabel(i.provider.toLowerCase(), i.identityData),
            raw: i,
          ),
        )
        .toList();
  }

  static Future<ProfileActionResult> linkOAuthIdentity(OAuthProvider provider) async {
    if (currentUser == null) {
      return const ProfileActionResult(
        ok: false,
        error: 'Entre com uma conta Aster para vincular Google ou Discord.',
      );
    }
    try {
      final scopes = provider == OAuthProvider.discord ? 'identify email' : null;
      final bool launched;
      if (oauth_loopback.isDesktopLoopbackPlatform) {
        launched = await oauth_loopback.runDesktopOAuthLoopback(
          client: client,
          startAuthFlow: (redirectUrl) => client.auth.getLinkIdentityUrl(
            provider,
            scopes: scopes,
            redirectTo: redirectUrl,
          ),
        );
      } else {
        launched = await client.auth.linkIdentity(
          provider,
          scopes: scopes,
          redirectTo: authRedirectUrl(),
        );
      }
      if (!launched) {
        return const ProfileActionResult(
          ok: false,
          error: 'Não foi possível abrir o navegador para concluir a vinculação.',
        );
      }
      final label = provider == OAuthProvider.google ? 'Google' : 'Discord';
      return ProfileActionResult(
        ok: true,
        message: 'Fluxo de vinculação com $label iniciado. Conclua no navegador e toque em atualizar.',
      );
    } catch (e) {
      return ProfileActionResult(ok: false, error: translateAuthError(e));
    }
  }

  static Future<ProfileActionResult> unlinkOAuthIdentity(
    LinkedIdentity identity, {
    required int totalIdentities,
  }) async {
    if (totalIdentities <= 1) {
      return const ProfileActionResult(
        ok: false,
        error: 'Você precisa manter ao menos um método de login ativo para não perder o acesso à sua conta.',
      );
    }
    if (linkedIdentitiesOverrideForTesting != null) {
      linkedIdentitiesOverrideForTesting = linkedIdentitiesOverrideForTesting!
          .where((item) => item.identityId != identity.identityId && item.id != identity.id)
          .toList();
      return const ProfileActionResult(
        ok: true,
        message: 'Conta desvinculada com sucesso.',
      );
    }
    if (currentUser == null || identity.raw == null) {
      return const ProfileActionResult(
        ok: false,
        error: 'Identidade externa não encontrada.',
      );
    }
    try {
      await client.auth.unlinkIdentity(identity.raw!);
      return const ProfileActionResult(
        ok: true,
        message: 'Conta desvinculada com sucesso.',
      );
    } catch (e) {
      return ProfileActionResult(ok: false, error: translateAuthError(e));
    }
  }

  // ----------------------------------------------------
  // WEEKLY & DAILY STUDY GOALS (local cache + profiles.stats)
  // ----------------------------------------------------
  static const int defaultWeeklyGoalMinutes = 25 * 60; // 25h padrão
  static const int minWeeklyGoalMinutes = 30; // 30m mínimo
  static const int maxWeeklyGoalMinutes = 168 * 60; // 168h máximo (semana inteira)
  static final ValueNotifier<int> weeklyGoalMinutesNotifier =
      ValueNotifier<int>(defaultWeeklyGoalMinutes);

  static const int defaultDailyGoalMinutes = 3 * 60; // 3h padrão por dia
  static const int minDailyGoalMinutes = 15; // 15m mínimo
  static const int maxDailyGoalMinutes = 24 * 60; // 24h máximo
  static final ValueNotifier<int> dailyGoalMinutesNotifier =
      ValueNotifier<int>(defaultDailyGoalMinutes);

  static String formatGoalDuration(int totalMinutes) {
    if (totalMinutes <= 0) return '0h';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (mins == 0) return '${hours}h';
    if (hours == 0) return '${mins}m';
    return '${hours}h ${mins}m';
  }

  static int computeTodayStudiedMinutes(
    List<Map<String, dynamic>> sessions, {
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int total = 0;
    for (final session in sessions) {
      final mins = (session['duration_minutes'] as num?)?.toInt() ?? 0;
      if (mins <= 0) continue;
      final rawDate = (session['study_date'] ?? session['created_at'] ?? '').toString().trim();
      if (rawDate.isEmpty) continue;
      final parsed = DateTime.tryParse(rawDate);
      if (parsed == null) continue;
      final day = DateTime(parsed.year, parsed.month, parsed.day);
      if (day == today) {
        total += mins;
      }
    }
    return total;
  }

  static int computeCurrentWeekStudiedMinutes(
    List<Map<String, dynamic>> sessions, {
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final sundayEnd = monday.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    int total = 0;
    for (final session in sessions) {
      final mins = (session['duration_minutes'] as num?)?.toInt() ?? 0;
      if (mins <= 0) continue;
      final rawDate = (session['study_date'] ?? session['created_at'] ?? '').toString().trim();
      if (rawDate.isEmpty) continue;
      final parsed = DateTime.tryParse(rawDate);
      if (parsed == null) continue;
      final day = DateTime(parsed.year, parsed.month, parsed.day);
      if (!day.isBefore(monday) && !day.isAfter(sundayEnd)) {
        total += mins;
      }
    }
    return total;
  }

  static int computeCurrentStreakDays(
    List<Map<String, dynamic>> sessions, {
    DateTime? referenceDate,
    Set<DateTime> protectedDates = const {},
  }) {
    final activeDays = <DateTime>{};
    for (final session in sessions) {
      final mins = (session['duration_minutes'] as num?)?.toInt() ?? 0;
      if (mins <= 0) continue;
      final rawDate = (session['study_date'] ?? session['created_at'] ?? '').toString().trim();
      if (rawDate.isEmpty) continue;
      final parsed = DateTime.tryParse(rawDate);
      if (parsed == null) continue;
      activeDays.add(DateTime(parsed.year, parsed.month, parsed.day));
    }
    if (activeDays.isEmpty) return 0;

    final normalizedProtected = {
      for (final d in protectedDates) DateTime(d.year, d.month, d.day),
    };
    final coveredDays = <DateTime>{...activeDays, ...normalizedProtected};

    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    DateTime cursor;
    if (coveredDays.contains(today)) {
      cursor = today;
    } else if (coveredDays.contains(yesterday)) {
      cursor = yesterday;
    } else {
      return 0;
    }

    // Dias protegidos preservam a ponte da sequência sem somar dias extras não estudados.
    int streak = 0;
    while (coveredDays.contains(cursor)) {
      if (activeDays.contains(cursor)) {
        streak++;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static Future<int> loadWeeklyGoalMinutes() async {
    int? resolved;
    try {
      final raw = await local_store.readSavedExamsRaw('noesis_weekly_goal_v1');
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map && decoded['weekly_goal_minutes'] is num) {
          final parsed = (decoded['weekly_goal_minutes'] as num).toInt();
          if (parsed == 0 ||
              (parsed >= minWeeklyGoalMinutes && parsed <= maxWeeklyGoalMinutes)) {
            resolved = parsed;
          }
        }
      }
    } catch (_) {}

    if (currentUser != null) {
      try {
        final profile = await getProfile();
        final stats = profile?['stats'];
        if (stats is Map && stats['noesis_weekly_goal_minutes'] is num) {
          final remote = (stats['noesis_weekly_goal_minutes'] as num).toInt();
          if (remote == 0 ||
              (remote >= minWeeklyGoalMinutes && remote <= maxWeeklyGoalMinutes)) {
            resolved = remote;
            unawaited(
              local_store.writeSavedExamsRaw(
                'noesis_weekly_goal_v1',
                jsonEncode({'weekly_goal_minutes': remote}),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Erro ao carregar meta semanal do Supabase: $e');
      }
    }

    final finalMinutes = resolved ?? defaultWeeklyGoalMinutes;
    weeklyGoalMinutesNotifier.value = finalMinutes;
    return finalMinutes;
  }

  static Future<void> saveWeeklyGoalMinutes(int minutes) async {
    final clamped = minutes <= 0
        ? 0
        : minutes.clamp(minWeeklyGoalMinutes, maxWeeklyGoalMinutes);
    weeklyGoalMinutesNotifier.value = clamped;

    try {
      await local_store.writeSavedExamsRaw(
        'noesis_weekly_goal_v1',
        jsonEncode({
          'weekly_goal_minutes': clamped,
          'updated_at': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {}

    if (currentUser != null) {
      try {
        final profile = await getProfile();
        final currentStats = profile?['stats'] is Map
            ? Map<String, dynamic>.from(profile!['stats'] as Map)
            : <String, dynamic>{};
        currentStats['noesis_weekly_goal_minutes'] = clamped;
        await client
            .from('profiles')
            .update({
              'stats': currentStats,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', currentUser!.id);
      } catch (e) {
        debugPrint('Erro ao salvar meta semanal no Supabase: $e');
      }
    }
  }

  static Future<int> loadDailyGoalMinutes() async {
    int? resolved;
    try {
      final raw = await local_store.readSavedExamsRaw('noesis_daily_goal_v1');
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map && decoded['daily_goal_minutes'] is num) {
          final parsed = (decoded['daily_goal_minutes'] as num).toInt();
          if (parsed == 0 ||
              (parsed >= minDailyGoalMinutes && parsed <= maxDailyGoalMinutes)) {
            resolved = parsed;
          }
        }
      }
    } catch (_) {}

    if (currentUser != null) {
      try {
        final profile = await getProfile();
        final stats = profile?['stats'];
        if (stats is Map && stats['noesis_daily_goal_minutes'] is num) {
          final remote = (stats['noesis_daily_goal_minutes'] as num).toInt();
          if (remote == 0 ||
              (remote >= minDailyGoalMinutes && remote <= maxDailyGoalMinutes)) {
            resolved = remote;
            unawaited(
              local_store.writeSavedExamsRaw(
                'noesis_daily_goal_v1',
                jsonEncode({'daily_goal_minutes': remote}),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Erro ao carregar meta diária do Supabase: $e');
      }
    }

    final finalMinutes = resolved ?? defaultDailyGoalMinutes;
    dailyGoalMinutesNotifier.value = finalMinutes;
    return finalMinutes;
  }

  static Future<void> saveDailyGoalMinutes(int minutes) async {
    final clamped = minutes <= 0
        ? 0
        : minutes.clamp(minDailyGoalMinutes, maxDailyGoalMinutes);
    dailyGoalMinutesNotifier.value = clamped;

    try {
      await local_store.writeSavedExamsRaw(
        'noesis_daily_goal_v1',
        jsonEncode({
          'daily_goal_minutes': clamped,
          'updated_at': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {}

    if (currentUser != null) {
      try {
        final profile = await getProfile();
        final currentStats = profile?['stats'] is Map
            ? Map<String, dynamic>.from(profile!['stats'] as Map)
            : <String, dynamic>{};
        currentStats['noesis_daily_goal_minutes'] = clamped;
        await client
            .from('profiles')
            .update({
              'stats': currentStats,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', currentUser!.id);
      } catch (e) {
        debugPrint('Erro ao salvar meta diária no Supabase: $e');
      }
    }
  }

  // ----------------------------------------------------
  // STUDY SESSIONS (noesis_sessions)
  // ----------------------------------------------------
  static final StreamController<List<Map<String, dynamic>>> _studySessionsStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  static List<Map<String, dynamic>> _inMemoryStudySessions = [];

  static Future<void> _hydrateLocalStudySessions() async {
    try {
      final raw = await local_store.readSavedExamsRaw('noesis_study_sessions_v1');
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _inMemoryStudySessions = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (_) {}
  }

  static Future<void> _persistLocalStudySessions() async {
    try {
      await local_store.writeSavedExamsRaw(
        'noesis_study_sessions_v1',
        jsonEncode(_inMemoryStudySessions),
      );
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> getStudySessions({int limit = 50}) async {
    if (currentUser == null) {
      await _hydrateLocalStudySessions();
      return List<Map<String, dynamic>>.from(_inMemoryStudySessions);
    }
    try {
      final res = await client
          .from('noesis_sessions')
          .select()
          .eq('user_id', currentUser!.id)
          .order('study_date', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);
      final list = List<Map<String, dynamic>>.from(res);
      _inMemoryStudySessions = list;
      unawaited(_persistLocalStudySessions());
      return list;
    } catch (_) {
      return List<Map<String, dynamic>>.from(_inMemoryStudySessions);
    }
  }

  static Stream<List<Map<String, dynamic>>> studySessionsStream() {
    if (currentUser == null) {
      return Stream<List<Map<String, dynamic>>>.multi((controller) {
        controller.add(List<Map<String, dynamic>>.from(_inMemoryStudySessions));
        _hydrateLocalStudySessions().then((_) {
          if (!controller.isClosed) {
            controller.add(List<Map<String, dynamic>>.from(_inMemoryStudySessions));
          }
        });
        final sub = _studySessionsStreamController.stream.listen((sessions) {
          controller.add(sessions);
        });
        controller.onCancel = () => sub.cancel();
      });
    }

    return client
        .from('noesis_sessions')
        .stream(primaryKey: ['id'])
        .eq('user_id', currentUser!.id)
        .order('study_date', ascending: false)
        .map((sessions) => List<Map<String, dynamic>>.from(sessions));
  }

  static Future<void> addStudySession({
    required String subject,
    required String topic,
    required int durationMinutes,
    required DateTime studyDate,
    String? notes,
  }) async {
    await _hydrateLocalStudySessions();
    final tempId = 'sess-${DateTime.now().millisecondsSinceEpoch}';
    final dateOnly = studyDate.toIso8601String().split('T').first;
    final newSession = {
      'id': tempId,
      'user_id': currentUser?.id,
      'subject': subject,
      'topic': topic,
      'duration_minutes': durationMinutes,
      'study_date': dateOnly,
      'notes': notes,
      'created_at': DateTime.now().toIso8601String(),
    };

    _inMemoryStudySessions.insert(0, newSession);
    _studySessionsStreamController.add(List<Map<String, dynamic>>.from(_inMemoryStudySessions));
    await _persistLocalStudySessions();

    if (currentUser != null) {
      try {
        final inserted = await client
            .from('noesis_sessions')
            .insert({
              'user_id': currentUser!.id,
              'subject': subject,
              'topic': topic,
              'duration_minutes': durationMinutes,
              'study_date': dateOnly,
              'notes': notes,
            })
            .select()
            .single();
        final idx = _inMemoryStudySessions.indexWhere((s) => s['id'] == tempId);
        if (idx != -1) {
          _inMemoryStudySessions[idx] = Map<String, dynamic>.from(inserted);
          _studySessionsStreamController.add(List<Map<String, dynamic>>.from(_inMemoryStudySessions));
          await _persistLocalStudySessions();
        }
      } catch (e) {
        debugPrint('Erro ao persistir sessão no Supabase: $e');
      }
    }
  }

  static Future<void> updateStudySession({
    required String id,
    required String subject,
    required String topic,
    required int durationMinutes,
    required DateTime studyDate,
    String? notes,
  }) async {
    await _hydrateLocalStudySessions();
    final dateOnly = studyDate.toIso8601String().split('T').first;
    final idx = _inMemoryStudySessions.indexWhere((s) => s['id'] == id);
    if (idx != -1) {
      _inMemoryStudySessions[idx] = {
        ..._inMemoryStudySessions[idx],
        'subject': subject,
        'topic': topic,
        'duration_minutes': durationMinutes,
        'study_date': dateOnly,
        'notes': notes,
      };
      _studySessionsStreamController.add(List<Map<String, dynamic>>.from(_inMemoryStudySessions));
      await _persistLocalStudySessions();
    }

    if (currentUser != null && RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)) {
      try {
        await client
            .from('noesis_sessions')
            .update({
              'subject': subject,
              'topic': topic,
              'duration_minutes': durationMinutes,
              'study_date': dateOnly,
              'notes': notes,
            })
            .eq('id', id)
            .eq('user_id', currentUser!.id);
      } catch (e) {
        debugPrint('Erro ao atualizar sessão no Supabase: $e');
      }
    }
  }

  static Future<void> deleteStudySession(String id) async {
    await _hydrateLocalStudySessions();
    _inMemoryStudySessions.removeWhere((s) => s['id'] == id);
    _studySessionsStreamController.add(List<Map<String, dynamic>>.from(_inMemoryStudySessions));
    await _persistLocalStudySessions();

    if (currentUser != null && RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)) {
      try {
        await client
            .from('noesis_sessions')
            .delete()
            .eq('id', id)
            .eq('user_id', currentUser!.id);
      } catch (e) {
        debugPrint('Erro ao deletar sessão no Supabase: $e');
      }
    }
  }

  // ----------------------------------------------------
  // CALENDAR EVENTS (noesis_calendar_events)
  // ----------------------------------------------------
  static final StreamController<List<Map<String, dynamic>>> _calendarStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  static final List<Map<String, dynamic>> _inMemoryCalendarEvents = [];

  static bool _isUuid(String id) =>
      RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(id);

  static List<Map<String, dynamic>> _sortedCalendarSnapshot({String? userId}) {
    final filtered = userId == null
        ? List<Map<String, dynamic>>.from(_inMemoryCalendarEvents)
        : _inMemoryCalendarEvents
            .where((e) => e['user_id'] == userId)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
    filtered.sort(
      (a, b) => (a['start_time'] ?? '').toString().compareTo((b['start_time'] ?? '').toString()),
    );
    return filtered;
  }

  static void _emitCalendarEvents() {
    _calendarStreamController.add(List<Map<String, dynamic>>.from(_inMemoryCalendarEvents));
  }

  static Future<List<Map<String, dynamic>>> getCalendarEvents({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (currentUser == null) {
      return _sortedCalendarSnapshot();
    }
    final uid = currentUser!.id;
    try {
      var query = client.from('noesis_calendar_events').select().eq('user_id', uid);

      if (startDate != null) {
        query = query.gte('start_time', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('end_time', endDate.toIso8601String());
      }

      final res = await query.order('start_time', ascending: true);
      final list = List<Map<String, dynamic>>.from(
        (res as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      if (startDate == null && endDate == null) {
        final pendingOptimistic = _inMemoryCalendarEvents
            .where((e) =>
                e['user_id'] == uid &&
                (e['id']?.toString().startsWith('evt-') ?? false))
            .toList();
        _inMemoryCalendarEvents
          ..removeWhere((e) => e['user_id'] == uid)
          ..addAll(list);
        for (final opt in pendingOptimistic) {
          final alreadyPresent = _inMemoryCalendarEvents.any((e) =>
              e['user_id'] == uid &&
              e['title'] == opt['title'] &&
              e['start_time'] == opt['start_time']);
          if (!alreadyPresent) {
            _inMemoryCalendarEvents.add(opt);
          }
        }
        _emitCalendarEvents();
      }
      return list;
    } catch (e) {
      debugPrint('Erro ao carregar eventos do calendário: $e');
      return _sortedCalendarSnapshot(userId: uid);
    }
  }

  static Stream<List<Map<String, dynamic>>> calendarEventsStream() {
    if (currentUser == null) {
      return Stream<List<Map<String, dynamic>>>.multi((controller) {
        controller.add(_sortedCalendarSnapshot());
        final sub = _calendarStreamController.stream.listen((_) {
          if (!controller.isClosed) {
            controller.add(_sortedCalendarSnapshot());
          }
        });
        controller.onCancel = () => sub.cancel();
      });
    }

    final uid = currentUser!.id;
    return Stream<List<Map<String, dynamic>>>.multi((controller) {
      void emitForUser() {
        if (!controller.isClosed) {
          controller.add(_sortedCalendarSnapshot(userId: uid));
        }
      }

      emitForUser();

      // Carrega snapshot imediato via REST mesmo se o Realtime atrasar ou oscilar
      getCalendarEvents().then((_) => emitForUser());

      final localSub = _calendarStreamController.stream.listen((_) {
        emitForUser();
      });

      final realtimeSub = client
          .from('noesis_calendar_events')
          .stream(primaryKey: ['id'])
          .eq('user_id', uid)
          .order('start_time', ascending: true)
          .listen(
        (events) {
          final pendingOptimistic = _inMemoryCalendarEvents
              .where((e) =>
                  e['user_id'] == uid &&
                  (e['id']?.toString().startsWith('evt-') ?? false))
              .toList();
          _inMemoryCalendarEvents
            ..removeWhere((e) => e['user_id'] == uid)
            ..addAll(events.map((e) => Map<String, dynamic>.from(e)));
          for (final opt in pendingOptimistic) {
            final alreadySynced = _inMemoryCalendarEvents.any((e) =>
                e['user_id'] == uid &&
                e['title'] == opt['title'] &&
                e['start_time'] == opt['start_time']);
            if (!alreadySynced) {
              _inMemoryCalendarEvents.add(opt);
            }
          }
          emitForUser();
        },
        onError: (Object error) {
          debugPrint('Realtime calendar stream error: $error');
        },
      );

      controller.onCancel = () async {
        await localSub.cancel();
        await realtimeSub.cancel();
      };
    });
  }

  static Future<Map<String, dynamic>> addCalendarEvent({
    required String title,
    String? description,
    String category = 'study',
    String? color,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final uid = currentUser?.id;
    final tempId = 'evt-${DateTime.now().microsecondsSinceEpoch}-${_inMemoryCalendarEvents.length}';
    final startUtcIso = startTime.toUtc().toIso8601String();
    final endUtcIso = endTime.toUtc().toIso8601String();

    final newEvent = <String, dynamic>{
      'id': tempId,
      'user_id': uid,
      'title': title,
      'description': description,
      'category': category,
      'color': ?color,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'is_completed': false,
      'created_at': DateTime.now().toIso8601String(),
    };

    _inMemoryCalendarEvents.add(newEvent);
    _emitCalendarEvents();

    if (uid != null) {
      try {
        final payload = <String, dynamic>{
          'user_id': uid,
          'title': title,
          'description': description,
          'category': category,
          'start_time': startUtcIso,
          'end_time': endUtcIso,
        };
        if (color != null) {
          payload['color'] = color;
        }
        final inserted = await client
            .from('noesis_calendar_events')
            .insert(payload)
            .select()
            .single();
        final authoritative = Map<String, dynamic>.from(inserted);
        final idx = _inMemoryCalendarEvents.indexWhere((e) => e['id'] == tempId);
        if (idx != -1) {
          _inMemoryCalendarEvents[idx] = authoritative;
        } else {
          _inMemoryCalendarEvents.add(authoritative);
        }
        _emitCalendarEvents();
        return authoritative;
      } catch (e) {
        _inMemoryCalendarEvents.removeWhere((e) => e['id'] == tempId);
        _emitCalendarEvents();
        debugPrint('Erro ao persistir evento no Supabase: $e');
        rethrow;
      }
    }
    return newEvent;
  }

  static Future<void> deleteCalendarEvent(String id) async {
    final uid = currentUser?.id;
    final backupIdx = _inMemoryCalendarEvents.indexWhere((e) => e['id']?.toString() == id);
    final backupEvent = backupIdx != -1 ? Map<String, dynamic>.from(_inMemoryCalendarEvents[backupIdx]) : null;
    _inMemoryCalendarEvents.removeWhere((e) => e['id']?.toString() == id);
    _emitCalendarEvents();

    if (uid != null && _isUuid(id)) {
      try {
        await client
            .from('noesis_calendar_events')
            .delete()
            .eq('id', id)
            .eq('user_id', uid);
      } catch (e) {
        if (backupEvent != null) {
          _inMemoryCalendarEvents.add(backupEvent);
          _emitCalendarEvents();
        }
        debugPrint('Erro ao deletar evento no Supabase: $e');
        rethrow;
      }
    }
  }

  static Future<void> toggleCalendarEventCompleted(String id, bool isCompleted) async {
    final uid = currentUser?.id;
    final idx = _inMemoryCalendarEvents.indexWhere((e) => e['id']?.toString() == id);
    final previousState = idx != -1 ? _inMemoryCalendarEvents[idx]['is_completed'] : null;
    if (idx != -1) {
      _inMemoryCalendarEvents[idx]['is_completed'] = isCompleted;
      _emitCalendarEvents();
    }

    if (uid != null && _isUuid(id)) {
      try {
        await client
            .from('noesis_calendar_events')
            .update({'is_completed': isCompleted})
            .eq('id', id)
            .eq('user_id', uid);
      } catch (e) {
        if (idx != -1) {
          _inMemoryCalendarEvents[idx]['is_completed'] = previousState;
          _emitCalendarEvents();
        }
        debugPrint('Erro ao atualizar status do evento no Supabase: $e');
        rethrow;
      }
    }
  }

  static Future<void> updateCalendarEvent({
    required String id,
    String? title,
    String? description,
    String? category,
    String? color,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final uid = currentUser?.id;
    final idx = _inMemoryCalendarEvents.indexWhere((e) => e['id']?.toString() == id);
    final backupEvent = idx != -1 ? Map<String, dynamic>.from(_inMemoryCalendarEvents[idx]) : null;
    if (idx != -1) {
      if (title != null) _inMemoryCalendarEvents[idx]['title'] = title;
      if (description != null) _inMemoryCalendarEvents[idx]['description'] = description;
      if (category != null) _inMemoryCalendarEvents[idx]['category'] = category;
      if (color != null) _inMemoryCalendarEvents[idx]['color'] = color;
      if (startTime != null) _inMemoryCalendarEvents[idx]['start_time'] = startTime.toIso8601String();
      if (endTime != null) _inMemoryCalendarEvents[idx]['end_time'] = endTime.toIso8601String();
      _emitCalendarEvents();
    }

    if (uid != null && _isUuid(id)) {
      try {
        final payload = <String, dynamic>{
          'title': ?title,
          'description': ?description,
          'category': ?category,
          'color': ?color,
          if (startTime != null) 'start_time': startTime.toUtc().toIso8601String(),
          if (endTime != null) 'end_time': endTime.toUtc().toIso8601String(),
        };
        final updated = await client
            .from('noesis_calendar_events')
            .update(payload)
            .eq('id', id)
            .eq('user_id', uid)
            .select()
            .single();
        final currentIdx = _inMemoryCalendarEvents.indexWhere((e) => e['id']?.toString() == id);
        if (currentIdx != -1) {
          _inMemoryCalendarEvents[currentIdx] = Map<String, dynamic>.from(updated);
          _emitCalendarEvents();
        }
      } catch (e) {
        if (backupEvent != null) {
          final currentIdx = _inMemoryCalendarEvents.indexWhere((e) => e['id']?.toString() == id);
          if (currentIdx != -1) {
            _inMemoryCalendarEvents[currentIdx] = backupEvent;
          }
          _emitCalendarEvents();
        }
        debugPrint('Erro ao atualizar evento no Supabase: $e');
        rethrow;
      }
    }
  }

  // ----------------------------------------------------
  // QUIZZES (noesis_quizzes)
  // ----------------------------------------------------
  static final List<Map<String, dynamic>> _inMemoryQuizzes = [];

  static Future<List<Map<String, dynamic>>> getQuizzes() async {
    if (currentUser == null) {
      return List<Map<String, dynamic>>.from(_inMemoryQuizzes);
    }
    try {
      final res = await client
          .from('noesis_quizzes')
          .select()
          .eq('user_id', currentUser!.id)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return List<Map<String, dynamic>>.from(_inMemoryQuizzes);
    }
  }

  static Future<Map<String, dynamic>> saveGeneratedQuiz({
    required String title,
    required String subject,
    required List<Map<String, dynamic>> questionsData,
    String? difficulty,
  }) async {
    final quizRecord = {
      'id': 'quiz-${DateTime.now().millisecondsSinceEpoch}',
      'user_id': currentUser?.id,
      'title': title,
      'subject': subject,
      'difficulty': difficulty ?? 'Médio / Prático',
      'questions_data': questionsData,
      'score_percentage': null,
      'time_spent_seconds': null,
      'completed_at': null,
      'created_at': DateTime.now().toIso8601String(),
    };
    _inMemoryQuizzes.insert(0, quizRecord);

    if (currentUser != null) {
      try {
        await client.from('noesis_quizzes').insert({
          'user_id': currentUser!.id,
          'title': title,
          'subject': subject,
          'questions_data': questionsData,
        });
      } catch (e) {
        debugPrint('Erro ao persistir simulado gerado no Supabase: $e');
      }
    }
    return quizRecord;
  }

  static Future<void> deleteQuiz(String quizId) async {
    _inMemoryQuizzes.removeWhere((q) => q['id']?.toString() == quizId);
    if (currentUser != null) {
      try {
        await client
            .from('noesis_quizzes')
            .delete()
            .eq('id', quizId)
            .eq('user_id', currentUser!.id);
      } catch (e) {
        debugPrint('Erro ao excluir simulado no Supabase: $e');
      }
    }
  }

  static Future<void> saveQuizResult({
    required String title,
    required String subject,
    required List<Map<String, dynamic>> questionsData,
    required double scorePercentage,
    required int timeSpentSeconds,
    String? documentId,
  }) async {
    final quizRecord = {
      'id': 'quiz-${DateTime.now().millisecondsSinceEpoch}',
      'user_id': currentUser?.id,
      'title': title,
      'subject': subject,
      'questions_data': questionsData,
      'score_percentage': scorePercentage,
      'time_spent_seconds': timeSpentSeconds,
      'completed_at': DateTime.now().toIso8601String(),
      'document_id': documentId,
    };
    _inMemoryQuizzes.insert(0, quizRecord);

    if (currentUser != null) {
      try {
        await client.from('noesis_quizzes').insert({
          'user_id': currentUser!.id,
          'title': title,
          'subject': subject,
          'questions_data': questionsData,
          'score_percentage': scorePercentage,
          'time_spent_seconds': timeSpentSeconds,
          'completed_at': DateTime.now().toIso8601String(),
          'document_id': documentId,
        });
      } catch (e) {
        debugPrint('Erro ao persistir resultado do simulado no Supabase: $e');
      }
    }
  }

  /// Salva ou atualiza um simulado completo na tabela `noesis_quizzes` (incluindo respostas e review da IA).
  static Future<void> upsertSavedExamAttempt(Map<String, dynamic> attemptJson) async {
    final attemptKey = (attemptJson['id'] ?? '').toString().trim();
    if (attemptKey.isEmpty) return;

    final existingMemIdx = _inMemoryQuizzes.indexWhere(
      (q) => q['attempt_key'] == attemptKey || q['id'] == attemptKey,
    );
    final memRecord = {
      'id': attemptKey,
      'attempt_key': attemptKey,
      'user_id': currentUser?.id,
      'group_key': attemptJson['groupKey'],
      'exam_model_id': attemptJson['examModelId'],
      'exam_model_name': attemptJson['examModelName'],
      'title': attemptJson['title'] ?? 'Simulado',
      'subject': attemptJson['subject'] ?? 'Geral',
      'topic': attemptJson['topic'] ?? '',
      'difficulty': attemptJson['difficulty'] ?? 'Médio / Prático',
      'target_total_count': attemptJson['targetTotalCount'],
      'questions_data': attemptJson['questions'] ?? const [],
      'user_answers': attemptJson['userAnswers'] ?? const <String, dynamic>{},
      'correct_count': attemptJson['correctCount'] ?? 0,
      'wrong_count': attemptJson['wrongCount'] ?? 0,
      'blank_count': attemptJson['blankCount'] ?? 0,
      'score_percentage': attemptJson['scorePercentage'] ?? 0.0,
      'time_spent_seconds': attemptJson['elapsedSeconds'] ?? 0,
      'time_expired': attemptJson['timeExpired'] == true,
      'ai_review_markdown': attemptJson['aiReviewMarkdown'],
      'completed_at': attemptJson['createdAt'] ?? DateTime.now().toIso8601String(),
    };
    if (existingMemIdx != -1) {
      _inMemoryQuizzes[existingMemIdx] = memRecord;
    } else {
      _inMemoryQuizzes.insert(0, memRecord);
    }

    if (currentUser == null) return;

    try {
      final uid = currentUser!.id;
      final existing = await client
          .from('noesis_quizzes')
          .select('id')
          .eq('user_id', uid)
          .eq('attempt_key', attemptKey)
          .maybeSingle();

      final payload = {
        'user_id': uid,
        'attempt_key': attemptKey,
        'group_key': attemptJson['groupKey'],
        'exam_model_id': attemptJson['examModelId'],
        'exam_model_name': attemptJson['examModelName'],
        'title': attemptJson['title'] ?? 'Simulado',
        'subject': attemptJson['subject'] ?? 'Geral',
        'topic': attemptJson['topic'] ?? '',
        'difficulty': attemptJson['difficulty'] ?? 'Médio / Prático',
        'target_total_count': attemptJson['targetTotalCount'],
        'questions_data': attemptJson['questions'] ?? const [],
        'user_answers': attemptJson['userAnswers'] ?? const <String, dynamic>{},
        'correct_count': attemptJson['correctCount'] ?? 0,
        'wrong_count': attemptJson['wrongCount'] ?? 0,
        'blank_count': attemptJson['blankCount'] ?? 0,
        'score_percentage': attemptJson['scorePercentage'] ?? 0.0,
        'time_spent_seconds': attemptJson['elapsedSeconds'] ?? 0,
        'time_expired': attemptJson['timeExpired'] == true,
        if (attemptJson['aiReviewMarkdown'] != null)
          'ai_review_markdown': attemptJson['aiReviewMarkdown'],
        'completed_at': attemptJson['createdAt'] ?? DateTime.now().toIso8601String(),
      };

      if (existing != null && existing['id'] != null) {
        await client
            .from('noesis_quizzes')
            .update(payload)
            .eq('id', existing['id'])
            .eq('user_id', uid);
      } else {
        await client.from('noesis_quizzes').insert(payload);
      }
    } catch (e) {
      debugPrint('Erro ao sincronizar simulado salvo no Supabase: $e');
    }
  }

  /// Atualiza o markdown da análise da IA para um simulado já salvo no Supabase.
  static Future<void> updateSavedExamAiReview(String attemptKey, String reviewMarkdown) async {
    final memIdx = _inMemoryQuizzes.indexWhere(
      (q) => q['attempt_key'] == attemptKey || q['id'] == attemptKey,
    );
    if (memIdx != -1) {
      _inMemoryQuizzes[memIdx]['ai_review_markdown'] = reviewMarkdown;
    }

    if (currentUser == null) return;
    try {
      final uid = currentUser!.id;
      await client
          .from('noesis_quizzes')
          .update({'ai_review_markdown': reviewMarkdown})
          .eq('user_id', uid)
          .eq('attempt_key', attemptKey);
    } catch (e) {
      debugPrint('Erro ao atualizar review IA do simulado no Supabase: $e');
    }
  }

  /// Remove um simulado salvo do Supabase.
  static Future<void> deleteSavedExamAttempt(String attemptKey) async {
    _inMemoryQuizzes.removeWhere(
      (q) => q['attempt_key'] == attemptKey || q['id'] == attemptKey,
    );

    if (currentUser == null) return;
    try {
      final uid = currentUser!.id;
      final deletedByKey = await client
          .from('noesis_quizzes')
          .delete()
          .eq('user_id', uid)
          .eq('attempt_key', attemptKey)
          .select('id');
      if ((deletedByKey as List).isEmpty &&
          RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(attemptKey)) {
        await client
            .from('noesis_quizzes')
            .delete()
            .eq('user_id', uid)
            .eq('id', attemptKey);
      }
    } catch (e) {
      debugPrint('Erro ao excluir simulado salvo no Supabase: $e');
    }
  }

  // ----------------------------------------------------
  // FLASHCARDS & REPETIÇÃO ESPAÇADA
  // ----------------------------------------------------
  static final List<FlashcardDeck> _inMemoryFlashcardDecks = [];

  static Future<List<FlashcardDeck>> getFlashcardDecks() async {
    if (currentUser == null) {
      return List<FlashcardDeck>.from(_inMemoryFlashcardDecks);
    }
    try {
      final res = await client
          .from('noesis_flashcard_decks')
          .select()
          .eq('user_id', currentUser!.id)
          .order('created_at', ascending: false);
      return (res as List)
          .map((row) => FlashcardDeck.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (_) {
      return List<FlashcardDeck>.from(_inMemoryFlashcardDecks);
    }
  }

  static Future<FlashcardDeck> saveFlashcardDeck(FlashcardDeck deck) async {
    final existingIndex = _inMemoryFlashcardDecks.indexWhere((d) => d.id == deck.id);
    if (existingIndex >= 0) {
      _inMemoryFlashcardDecks[existingIndex] = deck;
    } else {
      _inMemoryFlashcardDecks.insert(0, deck);
    }

    if (currentUser != null) {
      try {
        final payload = {
          'id': deck.id,
          'user_id': currentUser!.id,
          'title': deck.title,
          'subject': deck.subject,
          'description': deck.description,
          'cards': deck.cards.map((c) => c.toMap()).toList(),
          'color_hex': deck.colorHex,
          'icon_code': deck.iconCode,
          'updated_at': DateTime.now().toIso8601String(),
        };
        await client.from('noesis_flashcard_decks').upsert(payload);
      } catch (e) {
        debugPrint('Erro ao salvar baralho no Supabase: $e');
      }
    }
    return deck;
  }

  static Future<void> deleteFlashcardDeck(String deckId) async {
    _inMemoryFlashcardDecks.removeWhere((d) => d.id == deckId);
    if (currentUser != null) {
      try {
        await client.from('noesis_flashcard_decks').delete().eq('id', deckId);
      } catch (e) {
        debugPrint('Erro ao excluir baralho no Supabase: $e');
      }
    }
  }

  static Future<void> updateCardReview({
    required String deckId,
    required String cardId,
    required String difficulty,
  }) async {
    final deckIndex = _inMemoryFlashcardDecks.indexWhere((d) => d.id == deckId);
    if (deckIndex >= 0) {
      final deck = _inMemoryFlashcardDecks[deckIndex];
      final cardIndex = deck.cards.indexWhere((c) => c.id == cardId);
      if (cardIndex >= 0) {
        final card = deck.cards[cardIndex];
        card.difficulty = difficulty;
        card.reviewCount += 1;
        card.lastReviewed = DateTime.now();
      }
      if (currentUser != null) {
        saveFlashcardDeck(_inMemoryFlashcardDecks[deckIndex]);
      }
    }
  }

  // ----------------------------------------------------
  // CADERNOS DE ESTUDO & ANOTAÇÕES (NOTEBOOKS)
  // ----------------------------------------------------
  static final List<StudyNotebook> _inMemoryNotebooks = [];

  static Future<List<StudyNotebook>> getNotebooks() async {
    if (currentUser != null) {
      try {
        final res = await client
            .from('noesis_study_notebooks')
            .select()
            .eq('user_id', currentUser!.id)
            .order('created_at', ascending: false);
        return (res as List)
            .map((row) => StudyNotebook.fromMap(Map<String, dynamic>.from(row)))
            .toList();
      } catch (e) {
        debugPrint('Erro ao buscar cadernos no Supabase: $e');
      }
    }
    return List<StudyNotebook>.from(_inMemoryNotebooks);
  }

  static Future<StudyNotebook> saveNotebook(StudyNotebook notebook) async {
    final idx = _inMemoryNotebooks.indexWhere((n) => n.id == notebook.id);
    if (idx >= 0) {
      _inMemoryNotebooks[idx] = notebook;
    } else {
      _inMemoryNotebooks.insert(0, notebook);
    }

    if (currentUser != null) {
      try {
        final payload = {
          'id': notebook.id,
          'user_id': currentUser!.id,
          'title': notebook.title,
          'subject': notebook.subject,
          'description': notebook.description,
          'color_hex': notebook.colorHex,
          'icon_code': notebook.iconCode,
          'notes': notebook.notes.map((n) => n.toMap()).toList(),
          'created_at': notebook.createdAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
        await client.from('noesis_study_notebooks').upsert(payload);
      } catch (e) {
        debugPrint('Erro ao salvar caderno no Supabase: $e');
      }
    }

    return notebook;
  }

  static Future<void> deleteNotebook(String notebookId) async {
    _inMemoryNotebooks.removeWhere((n) => n.id == notebookId);
    if (currentUser != null) {
      try {
        await client.from('noesis_study_notebooks').delete().eq('id', notebookId);
      } catch (e) {
        debugPrint('Erro ao excluir caderno no Supabase: $e');
      }
    }
  }

  static Future<void> saveNote(String notebookId, StudyNote note) async {
    final nbIndex = _inMemoryNotebooks.indexWhere((n) => n.id == notebookId);
    if (nbIndex >= 0) {
      final nb = _inMemoryNotebooks[nbIndex];
      final noteList = List<StudyNote>.from(nb.notes);
      final nIndex = noteList.indexWhere((n) => n.id == note.id);
      if (nIndex >= 0) {
        noteList[nIndex] = note;
      } else {
        noteList.insert(0, note);
      }
      final updatedNb = nb.copyWith(notes: noteList, updatedAt: DateTime.now());
      _inMemoryNotebooks[nbIndex] = updatedNb;
      if (currentUser != null) {
        await saveNotebook(updatedNb);
      }
    }
  }

  static Future<void> deleteNote(String notebookId, String noteId) async {
    final nbIndex = _inMemoryNotebooks.indexWhere((n) => n.id == notebookId);
    if (nbIndex >= 0) {
      final nb = _inMemoryNotebooks[nbIndex];
      final noteList = List<StudyNote>.from(nb.notes)..removeWhere((n) => n.id == noteId);
      final updatedNb = nb.copyWith(notes: noteList, updatedAt: DateTime.now());
      _inMemoryNotebooks[nbIndex] = updatedNb;
      if (currentUser != null) {
        await saveNotebook(updatedNb);
      }
    }
  }

  // ----------------------------------------------------
  // TRILHAS DE ESTUDO / ROADMAPS (noesis_roadmaps)
  // ----------------------------------------------------
  static final List<Map<String, dynamic>> _inMemoryRoadmaps = [];

  static Future<List<Map<String, dynamic>>> getRoadmaps() async {
    if (currentUser == null) {
      return List<Map<String, dynamic>>.from(_inMemoryRoadmaps);
    }
    try {
      final res = await client
          .from('noesis_roadmaps')
          .select()
          .eq('user_id', currentUser!.id)
          .order('updated_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(res);
      _inMemoryRoadmaps
        ..clear()
        ..addAll(list);
      return list;
    } catch (e) {
      debugPrint('Erro ao buscar trilhas no Supabase: $e');
      return List<Map<String, dynamic>>.from(_inMemoryRoadmaps);
    }
  }

  static Future<void> upsertRoadmap(Map<String, dynamic> roadmapJson) async {
    final roadmapKey = (roadmapJson['id'] ?? '').toString().trim();
    if (roadmapKey.isEmpty) return;

    final idx = _inMemoryRoadmaps.indexWhere(
      (r) => r['roadmap_key'] == roadmapKey || r['id'] == roadmapKey,
    );
    final memRecord = {
      ...roadmapJson,
      'roadmap_key': roadmapKey,
      'user_id': currentUser?.id,
    };
    if (idx != -1) {
      _inMemoryRoadmaps[idx] = memRecord;
    } else {
      _inMemoryRoadmaps.insert(0, memRecord);
    }

    if (currentUser == null) return;
    try {
      final uid = currentUser!.id;
      final existing = await client
          .from('noesis_roadmaps')
          .select('id')
          .eq('user_id', uid)
          .eq('roadmap_key', roadmapKey)
          .maybeSingle();

      final payload = {
        'user_id': uid,
        'roadmap_key': roadmapKey,
        'title': roadmapJson['title'] ?? 'Trilha de Estudos',
        'goal': roadmapJson['goal'] ?? '',
        'subject': roadmapJson['subject'] ?? 'Geral',
        'level': roadmapJson['level'] ?? 'Intermediário',
        'estimated_weeks': roadmapJson['estimated_weeks'] ?? 4,
        'steps': roadmapJson['steps'] ?? const [],
        'updated_at': roadmapJson['updated_at'] ?? DateTime.now().toIso8601String(),
      };

      if (existing != null && existing['id'] != null) {
        await client
            .from('noesis_roadmaps')
            .update(payload)
            .eq('id', existing['id'])
            .eq('user_id', uid);
      } else {
        await client.from('noesis_roadmaps').insert({
          ...payload,
          'created_at': roadmapJson['created_at'] ?? DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Erro ao sincronizar trilha no Supabase: $e');
    }
  }

  static Future<void> deleteRoadmap(String roadmapKey) async {
    _inMemoryRoadmaps.removeWhere(
      (r) => r['roadmap_key'] == roadmapKey || r['id'] == roadmapKey,
    );
    if (currentUser == null) return;
    try {
      final uid = currentUser!.id;
      final deletedByKey = await client
          .from('noesis_roadmaps')
          .delete()
          .eq('user_id', uid)
          .eq('roadmap_key', roadmapKey)
          .select('id');
      if ((deletedByKey as List).isEmpty &&
          RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(roadmapKey)) {
        await client
            .from('noesis_roadmaps')
            .delete()
            .eq('user_id', uid)
            .eq('id', roadmapKey);
      }
    } catch (e) {
      debugPrint('Erro ao excluir trilha no Supabase: $e');
    }
  }
}
