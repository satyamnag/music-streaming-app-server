// Verifies the home header's brand image is exactly what the admin asked for:
// the wide-capsule PNG, displayed UNEDITED as exported, at 85% smaller size
// (72dp * 0.15 = 10.8dp optical height), and that no reference to the deleted
// soulful-bhakti-wordmark.png remains anywhere in the app tree or pubspec.

import 'dart:io';

import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('home header brand image', () {
    test('home.dart shows the capsule at 10.8dp', () {
      final repo = Directory.current.path;
      final home = File('$repo/lib/pages/home/home.dart');
      expect(home.existsSync(), isTrue);
      final content = home.readAsStringSync();

      // The header must load the updated capsule PNG...
      expect(
        content.contains("'assets/branding/sangeet-wide-capsule-small.png'"),
        isTrue,
        reason: 'home.dart must reference the admin-updated capsule PNG',
      );
      // ...at 85% smaller than the previous 72dp (72 * 0.15 == 10.8dp)...
      expect(
        content.contains('height: 72 * 0.15'),
        isTrue,
        reason: 'the header must render at 85% smaller (15% of 72dp)',
      );
      // ...with BoxFit.contain (aspect preserved, never distorted).
      expect(
        content.contains('fit: BoxFit.contain'),
        isTrue,
        reason: 'the image must keep its own aspect ratio',
      );
      // The image asset file must exist and match what the header names.
      final asset = File('$repo/assets/branding/sangeet-wide-capsule-small.png');
      expect(asset.existsSync(), isTrue,
          reason: 'the referenced capsule PNG must exist on disk');
    });

    test('no reference to the deleted wordmark asset remains', () {
      final repo = Directory.current.path;
      final files = <File>[
        File('$repo/lib/pages/home/home.dart'),
        File('$repo/pubspec.yaml'),
      ];
      for (final f in files) {
        expect(f.existsSync(), isTrue, reason: '${f.path} should exist');
        final content = f.readAsStringSync();
        expect(content.contains('soulful-bhakti-wordmark'), isFalse,
            reason: '${f.path} must not reference the deleted wordmark');
      }
      // pubspec must declare the capsule so it is bundled.
      final pubspec = File('$repo/pubspec.yaml').readAsStringSync();
      expect(
        pubspec.contains('assets/branding/sangeet-wide-capsule-small.png'),
        isTrue,
        reason: 'pubspec must declare the capsule asset so it ships in the APK',
      );
    });

    testWidgets('the capsule widget config renders an asset at 10.8dp',
        (tester) async {
      await tester.pumpWidget(
        material.MaterialApp(
          home: material.Scaffold(
            body: material.Center(
              child: material.Image.asset(
                'assets/branding/sangeet-wide-capsule-small.png',
                height: 72 * 0.15,
                fit: material.BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          ),
        ),
      );
      final image = tester.widget<material.Image>(
        find.byType(material.Image),
      );
      expect(image.image, isA<material.AssetImage>(),
          reason: 'the header must load a bundled asset, not a network image');
      expect(
        (image.image as material.AssetImage).assetName,
        'assets/branding/sangeet-wide-capsule-small.png',
      );
      expect(image.height, 72 * 0.15);
      expect(image.fit, material.BoxFit.contain);
    });
  });
}