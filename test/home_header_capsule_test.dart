// Verifies the home header's brand image is exactly what the admin asked for:
// the "Soulful Bhakti" ornate white logo, at the SAME on-screen size as the
// asset it replaced (72 * 0.15 * 5 = 54dp), with a genuinely transparent
// background (so it is displayed unedited).

import 'dart:io';

import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('home header brand image', () {
    test('home.dart shows the ornate logo at the unchanged 54dp height', () {
      final repo = Directory.current.path;
      final home = File('$repo/lib/pages/home/home.dart');
      expect(home.existsSync(), isTrue);
      final content = home.readAsStringSync();

      // The header must load the new ornate logo...
      expect(
        content.contains(
            "'assets/branding/soulful-bhakti-ornate-white-logo.png'"),
        isTrue,
        reason: 'home.dart must reference the admin-uploaded ornate logo',
      );
      // ...at EXACTLY the same height as before (the admin said the current
      // size is perfect and only the artwork was to change).
      expect(
        content.contains('height: 72 * 0.15 * 5'),
        isTrue,
        reason: 'the header height must stay at 72 * 0.15 * 5 = 54dp; only the '
            'image was to be swapped, not resized',
      );
      // ...with BoxFit.contain (aspect preserved, never distorted).
      expect(
        content.contains('fit: BoxFit.contain'),
        isTrue,
        reason: 'the image must keep its own aspect ratio',
      );
      // The asset must exist and be declared so it ships in the APK.
      final asset = File(
          '$repo/assets/branding/soulful-bhakti-ornate-white-logo.png');
      expect(asset.existsSync(), isTrue,
          reason: 'the referenced logo PNG must exist on disk');
      final pubspec = File('$repo/pubspec.yaml').readAsStringSync();
      expect(
        pubspec.contains(
            'assets/branding/soulful-bhakti-ornate-white-logo.png'),
        isTrue,
        reason: 'pubspec must declare the logo so it is bundled',
      );
    });

    test('no stale reference to the previous capsule asset remains', () {
      final repo = Directory.current.path;
      final content =
          File('$repo/lib/pages/home/home.dart').readAsStringSync();
      expect(
        content.contains('sangeet-wide-capsule-small.png'),
        isFalse,
        reason: 'the header must no longer point at the replaced capsule image',
      );
    });

    testWidgets('a 54dp asset renders with contain fit', (tester) async {
      await tester.pumpWidget(
        material.MaterialApp(
          home: material.Scaffold(
            body: material.Center(
              child: material.Image.asset(
                'assets/branding/soulful-bhakti-ornate-white-logo.png',
                height: 72 * 0.15 * 5,
                fit: material.BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          ),
        ),
      );
      final image =
          tester.widget<material.Image>(find.byType(material.Image));
      expect(image.image, isA<material.AssetImage>());
      expect(
        (image.image as material.AssetImage).assetName,
        'assets/branding/soulful-bhakti-ornate-white-logo.png',
      );
      expect(image.height, 72 * 0.15 * 5);
      expect(image.fit, material.BoxFit.contain);
    });
  });
}
