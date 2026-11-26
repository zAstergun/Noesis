import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/supabase_service.dart';
import 'package:noesis/core/theme.dart';
import 'package:noesis/features/ai_agent/ai_assistant_screen.dart';
import 'package:noesis/features/ai_agent/data/ai_chat_history_repository.dart';
import 'package:noesis/features/settings/settings_screen.dart';
import 'package:noesis/main.dart';
import 'package:noesis/widgets/profile_settings_dialog.dart';
import 'package:noesis/widgets/vip_rgb_theme_editor.dart';
import '../e2e/harness/test_app_harness.dart';

// Cabeçalho GIF89a 1x1 mínimo para teste
final Uint8List _kSampleGifBytes = Uint8List.fromList([
  ...ascii.encode('GIF89a'),
  1, 0, 1, 0, 0x80, 0, 0, 0, 0, 0, 255, 255, 255,
  0x2C, 0, 0, 0, 0, 1, 0, 1, 0, 0, 2, 2, 0x44, 1, 0, 0x3B,
]);

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  setUp(() async {
    ProfileSettingsDialog.avatarPickerOverrideForTesting = null;
    await SupabaseService.resetProfileForTesting();
    await AsterTheme.resetCustomThemeForTesting();
    await AiChatHistoryRepository.clearAll();
  });

  tearDown(() async {
    ProfileSettingsDialog.avatarPickerOverrideForTesting = null;
    await SupabaseService.resetProfileForTesting();
    await AsterTheme.resetCustomThemeForTesting();
    await AiChatHistoryRepository.clearAll();
  });

  test('GIF avatar upload is restricted to VIP users', () async {
    SupabaseService.setVipForTesting(false);
    final blocked = await SupabaseService.uploadUserAvatar(
      bytes: _kSampleGifBytes,
      fileName: 'avatar.gif',
    );
    expect(blocked.ok, isFalse);
    expect(blocked.requiresVip, isTrue);
    expect(blocked.error, contains('Apenas membros VIP'));

    SupabaseService.setVipForTesting(true);
    final allowed = await SupabaseService.uploadUserAvatar(
      bytes: _kSampleGifBytes,
      fileName: 'avatar.gif',
    );
    expect(allowed.ok, isTrue);
    expect(allowed.profile?['avatar_url'], startsWith('data:image/gif;base64,'));
  });

  testWidgets('Profile shows GIF VIP notice, blocks non-VIP GIF, and highlights VIP avatar circle', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    SupabaseService.setVipForTesting(false);

    await TestAppHarness.pumpInHarness(tester, const NoesisApp());
    await tester.pumpAndSettle();

    final guestBtn = find.text('Entrar sem login · Modo de Teste');
    if (guestBtn.evaluate().isNotEmpty) {
      await tester.tap(guestBtn);
      await tester.pumpAndSettle();
    }

    // Não-VIP não exibe badge VIP no círculo do avatar e mostra botão Discord acima do perfil
    expect(find.byKey(const Key('vip_avatar_badge')), findsNothing);
    final discordFinder = find.byKey(const Key('sidebar_discord_button'));
    final profileFinder = find.byKey(const Key('sidebar_profile_button'));
    expect(discordFinder, findsOneWidget);
    expect(profileFinder, findsOneWidget);
    expect(tester.getTopLeft(discordFinder).dy, lessThan(tester.getTopLeft(profileFinder).dy));
    expect(find.text('Entrar no Discord'), findsOneWidget);

    // Torna VIP -> destaque dourado + badge VIP aparecem imediatamente na barra lateral
    SupabaseService.setVipForTesting(true);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vip_avatar_badge')), findsOneWidget);

    // Volta para não-VIP para testar bloqueio de GIF no diálogo de perfil
    SupabaseService.setVipForTesting(false);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sidebar_profile_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile_gif_vip_notice')), findsOneWidget);
    expect(find.textContaining('Apenas quem é VIP pode usar GIF na foto de perfil'), findsOneWidget);

    ProfileSettingsDialog.avatarPickerOverrideForTesting = () async => (
      bytes: _kSampleGifBytes,
      fileName: 'animado.gif',
    );
    await tester.ensureVisible(find.byKey(const Key('profile_pick_avatar_button')));
    await tester.tap(find.byKey(const Key('profile_pick_avatar_button')));
    await tester.pumpAndSettle();

    expect(find.text('GIF Exclusivo para VIP'), findsOneWidget);

    // Fecha o modal de perfil para encerrar sem pendências
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();
    await TestAppHarness.drainAsync(tester);
  });

  testWidgets('Custom 6-color RGB theme is last theme and strictly VIP-only', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    expect(AsterTheme.availableThemesWithCustom.last.id, AsterTheme.customThemeId);
    expect(AsterTheme.availableThemesWithCustom.last.name, 'Personalizado');

    SupabaseService.setVipForTesting(false);

    await TestAppHarness.pumpInHarness(
      tester,
      const Scaffold(body: SettingsScreen()),
    );
    await tester.pumpAndSettle();

    final customCard = find.byKey(const Key('theme_option_custom'));
    expect(customCard, findsOneWidget);
    expect(find.byKey(const Key('custom_theme_vip_lock_banner')), findsOneWidget);
    expect(find.byKey(const Key('vip_custom_theme_editor')), findsNothing);

    // Tocar como não-VIP abre o modal de privilégios VIP em vez de ativar o tema
    await tester.ensureVisible(customCard);
    await tester.tap(customCard);
    await tester.pumpAndSettle();
    expect(find.text('Privilégios VIP no Noesis'), findsOneWidget);
    expect(find.textContaining('todos os projetos do Aster'), findsAtLeastNWidgets(1));
    expect(find.text('Insights em Dobro (2×)'), findsOneWidget);
    expect(find.text('Ganho Diário Ilimitado'), findsOneWidget);
    expect(find.byKey(const Key('vip_discord_button')), findsOneWidget);
    expect(AsterTheme.activeThemeIdNotifier.value, isNot(AsterTheme.customThemeId));

    // Fecha modal VIP
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();

    // Ativa VIP -> desbloqueia o tema Personalizado e o editor de 6 cores RGB
    SupabaseService.setVipForTesting(true);
    await tester.pumpAndSettle();

    await tester.ensureVisible(customCard);
    await tester.tap(customCard);
    await tester.pumpAndSettle();

    expect(AsterTheme.activeThemeIdNotifier.value, AsterTheme.customThemeId);
    expect(find.byKey(const Key('vip_custom_theme_editor')), findsOneWidget);
    for (int i = 0; i < 6; i++) {
      expect(find.byKey(Key('custom_color_slot_$i')), findsOneWidget);
    }

    // Edita a cor Primária (slot 2) via HEX e valida painel retangular 2D + caixas R/G/B
    expect(find.byKey(const Key('vip_rgb_spectrum_canvas')), findsOneWidget);
    expect(find.byKey(const Key('vip_rgb_hue_bar')), findsOneWidget);
    expect(find.byKey(const Key('vip_rgb_r_field')), findsOneWidget);
    expect(find.byKey(const Key('vip_rgb_g_field')), findsOneWidget);
    expect(find.byKey(const Key('vip_rgb_b_field')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('vip_rgb_hex_field')));
    await tester.enterText(find.byKey(const Key('vip_rgb_hex_field')), '#11AAFF');
    await tester.pumpAndSettle();

    expect(AsterTheme.customThemeColorsNotifier.value.primary, const Color(0xFF11AAFF));
    await TestAppHarness.drainAsync(tester);
  });

  testWidgets('Noesis AI conversation history is accessible only for VIP users', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await AiChatHistoryRepository.upsertSession(
      AiChatSession(
        id: 'sess-vip-1',
        title: 'Revisão de Kubernetes',
        createdAt: DateTime(2026, 11, 24, 15, 0),
        updatedAt: DateTime(2026, 11, 24, 15, 5),
        messages: const [
          {'role': 'user', 'text': 'Me ajude a revisar Kubernetes'},
          {'role': 'ai', 'text': 'Claro! Vamos revisar Pods, Deployments e Services.'},
        ],
      ),
    );

    SupabaseService.setVipForTesting(false);
    await TestAppHarness.pumpInHarness(
      tester,
      const Scaffold(body: AiAssistantScreen()),
    );
    await tester.pumpAndSettle();

    // Não-VIP ao clicar em Histórico vê o modal de Privilégios VIP e não abre o histórico
    await tester.tap(find.byKey(const Key('ai_history_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai_history_dialog')), findsNothing);
    expect(find.text('Privilégios VIP no Noesis'), findsOneWidget);

    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();

    // VIP ao clicar em Histórico abre as conversas salvas e restaura ao tocar
    SupabaseService.setVipForTesting(true);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ai_history_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai_history_dialog')), findsOneWidget);
    expect(find.text('Revisão de Kubernetes'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ai_history_item_sess-vip-1')));
    await tester.pumpAndSettle();
    expect(find.text('Me ajude a revisar Kubernetes'), findsOneWidget);
    expect(find.textContaining('Pods, Deployments e Services'), findsOneWidget);

    await TestAppHarness.drainAsync(tester);
  });

  testWidgets('VipRgbColorTrigger gates RGB picker to VIP and opens StudioOS dialog when VIP', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Color selected = const Color(0xFF7C6CF0);
    SupabaseService.setVipForTesting(false);

    await TestAppHarness.pumpInHarness(
      tester,
      Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => Center(
            child: VipRgbColorTrigger(
              currentColor: selected,
              isCustomSelected: false,
              onColorSelected: (c) => setState(() => selected = c),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Não-VIP ao tocar no gatilho RGB vê a modal de Privilégios VIP
    await tester.tap(find.byKey(const Key('vip_rgb_picker_trigger')));
    await tester.pumpAndSettle();
    expect(find.text('Privilégios VIP no Noesis'), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();

    // VIP abre a modal retangular Seletor RGB VIP e aplica cor personalizada
    SupabaseService.setVipForTesting(true);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('vip_rgb_picker_trigger')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vip_rgb_picker_dialog')), findsOneWidget);
    expect(find.byKey(const Key('vip_rgb_spectrum_canvas')), findsOneWidget);
    expect(find.byKey(const Key('vip_rgb_hue_bar')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('vip_rgb_hex_field')), '#22DD88');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vip_rgb_picker_apply_button')));
    await tester.pumpAndSettle();

    expect(selected, const Color(0xFF22DD88));
  });
}
