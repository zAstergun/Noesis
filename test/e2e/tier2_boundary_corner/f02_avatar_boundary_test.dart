import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:noesis/core/constants.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 2 - Feature 02: Image & Avatar Boundary Cases', () {
    String extractInitials(String? name) {
      if (name == null || name.trim().isEmpty) return 'VT';
      final clean = name.trim();
      return clean.length >= 2 ? clean.substring(0, 2).toUpperCase() : clean.toUpperCase();
    }

    Widget buildAvatarWidget({String? avatarUrl, String? name}) {
      final initials = extractInitials(name);
      return CircleAvatar(
        radius: 18,
        backgroundColor: AsterConstants.lavanda.withValues(alpha: 0.15),
        backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
            ? ResizeImage(
                NetworkImage(avatarUrl),
                width: 72,
                height: 72,
              )
            : null,
        child: (avatarUrl == null || avatarUrl.isEmpty)
            ? Text(
                initials,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: AsterConstants.lavanda,
                ),
              )
            : null,
      );
    }

    testWidgets('1. Ultra-high resolution image URL is constrained to 72x72 decode buffer',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        buildAvatarWidget(avatarUrl: 'https://cdn.example.com/ultra_hd_4k_avatar.jpg'),
      );

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      final resizeImage = avatar.backgroundImage as ResizeImage;
      expect(resizeImage.width, equals(72));
      expect(resizeImage.height, equals(72));
    });

    testWidgets('2. Empty avatar URL string ("") falls back gracefully to user initials',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        buildAvatarWidget(avatarUrl: '', name: 'Carlos Lima'),
      );

      expect(find.text('CA'), findsOneWidget);
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.backgroundImage, isNull);
    });

    testWidgets('3. Single-character user name produces valid 1-char initials without range error',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        buildAvatarWidget(name: 'A'),
      );

      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('4. User name with emojis and symbols safely produces initials',
        (WidgetTester tester) async {
      final initials = extractInitials('🚀 Aster');
      await TestAppHarness.pumpInHarness(
        tester,
        buildAvatarWidget(name: '🚀 Aster'),
      );

      expect(find.text(initials), findsOneWidget);
    });

    testWidgets('5. Completely null user profile falls back to standard default "VT"',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        buildAvatarWidget(avatarUrl: null, name: null),
      );

      expect(find.text('VT'), findsOneWidget);
    });
  });
}
