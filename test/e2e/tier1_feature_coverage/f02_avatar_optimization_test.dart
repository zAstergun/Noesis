import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/main.dart';
import 'package:noesis/core/constants.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Feature 02: Image & Avatar Optimization', () {
    testWidgets('1. ResizeImage wraps NetworkImage to constrain decode size to 72x72',
        (WidgetTester tester) async {
      const imageUrl = 'https://avatars.example.com/user123.png';
      const resizeImage = ResizeImage(
        NetworkImage(imageUrl),
        width: 72,
        height: 72,
      );

      expect(resizeImage.width, equals(72));
      expect(resizeImage.height, equals(72));
      expect(resizeImage.imageProvider, isA<NetworkImage>());
    });

    testWidgets('2. CircleAvatar accepts ResizeImage as backgroundImage',
        (WidgetTester tester) async {
      const resizeImage = ResizeImage(
        NetworkImage('https://avatars.example.com/hd_photo.jpg'),
        width: 72,
        height: 72,
      );

      await TestAppHarness.pumpInHarness(
        tester,
        const CircleAvatar(
          radius: 18,
          backgroundImage: resizeImage,
        ),
      );

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.backgroundImage, isA<ResizeImage>());
      final img = avatar.backgroundImage as ResizeImage;
      expect(img.width, equals(72));
      expect(img.height, equals(72));
    });

    testWidgets('3. CircleAvatar with null avatar_url displays user initials text child',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        const CircleAvatar(
          radius: 18,
          backgroundColor: Color(0x267C6CF0),
          child: Text('ES'),
        ),
      );

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.backgroundImage, isNull);
      expect(find.text('ES'), findsOneWidget);
    });

    testWidgets('4. Real TopBar CircleAvatar in RootScreen renders with 17 radius and lavanda alpha 0.15',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        const RootScreen(),
      );

      // Inspect the real TopBar avatar widget from lib/main.dart
      final avatarFinder = find.byType(CircleAvatar);
      expect(avatarFinder, findsOneWidget);

      final avatar = tester.widget<CircleAvatar>(avatarFinder);
      expect(avatar.radius, equals(17));
      expect(avatar.backgroundColor, equals(AsterConstants.lavanda.withValues(alpha: 0.15)));

      await TestAppHarness.drainAsync(tester);
    });

    testWidgets('5. Real TopBar CircleAvatar in RootScreen renders default initials ES in lavanda color',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        const RootScreen(),
      );

      // The real TopBar renders default initials 'ES' for Estudante
      expect(find.text('ES'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('ES'));
      expect(textWidget.style?.color, equals(AsterConstants.lavanda));

      await TestAppHarness.drainAsync(tester);
    });
  });
}
