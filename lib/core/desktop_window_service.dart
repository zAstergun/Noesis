import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Gerencia a janela nativa do app desktop Windows (barra de título integrada,
/// arrasto, minimizar, maximizar/restaurar, fechar e sincronização de tema escuro).
class DesktopWindowService {
  DesktopWindowService._();

  static const MethodChannel _channel = MethodChannel('noesis/window_controls');
  static final ValueNotifier<bool> isMaximizedNotifier = ValueNotifier<bool>(false);
  static bool _initialized = false;

  /// Verdadeiro quando rodando como aplicativo desktop Windows nativo.
  static bool get isCustomFrameSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static Future<void> ensureInitialized() async {
    if (_initialized || !isCustomFrameSupported) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onMaximizeChanged' && call.arguments is bool) {
        isMaximizedNotifier.value = call.arguments as bool;
      }
    });
    try {
      final isMax = await _channel.invokeMethod<bool>('isMaximized');
      if (isMax != null) {
        isMaximizedNotifier.value = isMax;
      }
    } catch (_) {}
  }

  static Future<void> startDrag() async {
    if (!isCustomFrameSupported) return;
    try {
      await _channel.invokeMethod('startDrag');
    } catch (_) {}
  }

  static Future<void> minimize() async {
    if (!isCustomFrameSupported) return;
    try {
      await _channel.invokeMethod('minimize');
    } catch (_) {}
  }

  static Future<void> toggleMaximize() async {
    if (!isCustomFrameSupported) return;
    try {
      final isMax = await _channel.invokeMethod<bool>('toggleMaximize');
      if (isMax != null) {
        isMaximizedNotifier.value = isMax;
      }
    } catch (_) {}
  }

  static Future<void> close() async {
    if (!isCustomFrameSupported) return;
    try {
      await _channel.invokeMethod('close');
    } catch (_) {}
  }

  static Future<void> setDarkMode(bool isDark) async {
    if (!isCustomFrameSupported) return;
    try {
      await _channel.invokeMethod('setDarkMode', isDark);
    } catch (_) {}
  }
}
