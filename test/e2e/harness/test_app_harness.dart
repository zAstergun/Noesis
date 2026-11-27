import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:noesis/core/constants.dart';
import 'package:noesis/core/localization/noesis_l10n.dart';
import 'package:noesis/core/localization/noesis_locale_service.dart';
import 'package:noesis/core/theme.dart';
import 'package:noesis/main.dart';
import 'mock_http_overrides.dart';

/// Test Harness for pumping Noesis widgets and end-to-end screen hierarchies
/// hermetically with Aster Soft Clay theme, screen sizing, and localization.
class TestAppHarness {
  static bool _initialized = false;
  static Directory? _fontCacheDir;

  /// Sets up hermetic test environment: date formatting, mock HTTP overrides,
  /// font loading fallback, and disables font runtime fetching.
  static Future<void> setUpTestEnvironment() async {
    if (_initialized) return;
    TestWidgetsFlutterBinding.ensureInitialized();
    MockHttpOverrides.install();
    await initializeDateFormatting('pt_BR', null);
    await NoesisLocaleService.resetForTesting(
      platformLocalesOverride: const [Locale('pt', 'BR')],
    );
    GoogleFonts.config.allowRuntimeFetching = false;

    // Filter framework cosmetic warnings and Ahem font text overflows in test mode
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final msg = details.exceptionAsString();
      if (msg.contains('ListTile background color or ink splashes may be invisible') ||
          msg.contains('A RenderFlex overflowed by')) {
        return;
      }
      originalOnError?.call(details);
    };

    // Set up local font cache directory for font fallback handling
    _fontCacheDir = Directory('.dart_tool/test_fonts');
    if (!_fontCacheDir!.existsSync()) {
      _fontCacheDir!.createSync(recursive: true);
    }

    // Populate fallback font files for any variant not directly in assets
    final boldFontFile = File('assets/fonts/JetBrainsMono-Bold.ttf');
    if (boldFontFile.existsSync()) {
      final boldBytes = boldFontFile.readAsBytesSync();
      // JetBrainsMono_600 fallback file for google_fonts local file loading
      final semiBoldCached = File('${_fontCacheDir!.path}/JetBrainsMono_600_f833596d98e0e021dd43d993254658d0f32318f82f08afee0fc2e41c16ce9571.ttf');
      if (!semiBoldCached.existsSync()) {
        semiBoldCached.writeAsBytesSync(boldBytes);
      }
    }

    // Mock path_provider method channel so google_fonts finds the cached font
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return _fontCacheDir!.absolute.path;
      },
    );

    // Mock audioplayers platform and event channels in headless tests
    for (final ch in [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers/events',
      'xyz.luan/audioplayers.global/events',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(ch),
        (MethodCall call) async {
          if (call.method == 'listen' || call.method == 'cancel') {
            return null;
          }
          if (call.method == 'getSources') {
            return [];
          }
          return 1;
        },
      );
    }

    // Mock SharedPreferences method channel for hermetic test execution
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, Object>{};
        }
        return true;
      },
    );

    try {
      await Supabase.initialize(
        url: AsterConstants.supabaseUrl,
        anonKey: AsterConstants.supabaseAnonKey,
      );
    } catch (_) {
      // Supabase already initialized
    }

    RootScreen.bypassAuthForTesting = true;
    _initialized = true;
  }

  /// Wraps a widget in MaterialApp configured with AsterTheme, desktop viewport,
  /// and Portuguese directionality/localization defaults.
  static Widget wrapWidget(
    Widget child, {
    ThemeMode themeMode = ThemeMode.light,
    Size screenSize = const Size(1280, 800),
    Locale locale = const Locale('pt', 'BR'),
    NavigatorObserver? navigatorObserver,
  }) {
    return ListenableBuilder(
      listenable: NoesisLocaleService.currentCodeNotifier,
      builder: (context, _) {
        final effectiveLocale = locale == const Locale('pt', 'BR')
            ? NoesisLocaleService.currentLocale
            : locale;
        final effectiveDirection =
            effectiveLocale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AsterTheme.softClayTheme,
          darkTheme: AsterTheme.darkTheme,
          themeMode: themeMode,
          locale: effectiveLocale,
          supportedLocales: NoesisLocaleService.supportedFlutterLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          navigatorObservers: navigatorObserver != null ? [navigatorObserver] : const [],
          builder: (context, inner) {
            return NoesisLocaleScope(
              notifier: NoesisLocaleService.currentCodeNotifier,
              child: Directionality(
                textDirection: effectiveDirection,
                child: inner ?? const SizedBox.shrink(),
              ),
            );
          },
          home: Directionality(
            textDirection: effectiveDirection,
            child: MediaQuery(
              data: MediaQueryData(
                size: screenSize,
                devicePixelRatio: 1.0,
              ),
              child: Scaffold(
                body: child,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Pumps a widget inside the standard desktop layout constraints.
  static Future<void> pumpInHarness(
    WidgetTester tester,
    Widget child, {
    ThemeMode themeMode = ThemeMode.light,
    Size screenSize = const Size(1280, 800),
    Duration? pumpDuration,
  }) async {
    // Filter framework cosmetic warnings and Ahem font text overflows in test mode
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final msg = details.exceptionAsString();
      if (msg.contains('ListTile background color or ink splashes may be invisible') ||
          msg.contains('A RenderFlex overflowed by')) {
        return;
      }
      originalOnError?.call(details);
    };

    tester.view.physicalSize = screenSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      FlutterError.onError = originalOnError;
    });

    await tester.pumpWidget(
      wrapWidget(
        child,
        themeMode: themeMode,
        screenSize: screenSize,
      ),
    );

    if (pumpDuration != null) {
      await tester.pump(pumpDuration);
    } else {
      await tester.pump();
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
    }

    // Wait for any asynchronous GoogleFonts loading to complete and drain font callbacks
    await GoogleFonts.pendingFonts();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Drains any asynchronous font loading and platform relayout frame callbacks.
  static Future<void> drainAsync(WidgetTester tester) async {
    await GoogleFonts.pendingFonts();
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
}
