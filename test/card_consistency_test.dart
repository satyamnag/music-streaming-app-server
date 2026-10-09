// Guards that every album and track surface in the app renders the SAME card.
//
// Item 7 of the UI work: "wherever albums and tracks are there in any screen of
// the android app the ui must be exactly same as it is on the home screen".
//
// The guarantee is structural rather than visual: there is exactly ONE card
// implementation (`TrackCard`), reached through two thin data wrappers
// (`HomeAlbumCard`, `HomeTrackCard`). No screen builds its own card, so no screen
// can drift from the home screen - and this test fails if one starts to.
//
// A second card implementation is the failure mode being guarded, because that
// is what "the same as home" quietly stops being true.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Every `.dart` file under `lib/`, excluding generated code.
  List<File> libSources() {
    return Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.contains('.g.dart'))
        .where((f) => !f.path.contains('.freezed.dart'))
        .where((f) => !f.path.contains('generated'))
        .where((f) => !f.path.contains('l10n'))
        .toList();
  }

  test('there is exactly ONE card widget, and it lives in track_card', () {
    // A class that builds a card from scratch (its own cover + text block)
    // instead of delegating to TrackCard would be a second implementation.
    final declarers = <String>[];

    for (final file in libSources()) {
      final source = file.readAsStringSync();
      // Only the shared card owns these; a wrapper passes data through.
      if (source.contains('class TrackCard') ||
          source.contains('class HomeAlbumCard') ||
          source.contains('class HomeTrackCard')) {
        declarers.add(file.path.replaceAll(r'\', '/'));
      }
    }

    expect(
      declarers.where((p) => p.contains('track_card/track_card.dart')).length,
      1,
      reason: 'TrackCard must exist exactly once',
    );
    expect(
      declarers.length,
      3,
      reason: 'only TrackCard plus its two wrappers may declare a card class; '
          'a fourth means a screen grew its own card and can drift from home',
    );
  });

  test('both wrappers delegate to TrackCard', () {
    // The wrappers must stay pure data → card. If either painted its own
    // chrome, albums and tracks would no longer match the home screen.
    for (final path in [
      'lib/components/track_card/home_album_card.dart',
      'lib/components/track_card/home_track_card.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source.contains('return TrackCard('),
        isTrue,
        reason: '$path must render the shared TrackCard',
      );
      // No independent fill/stroke decisions.
      expect(
        source.contains('BoxDecoration('),
        isFalse,
        reason: '$path must not paint its own background; the card owns that',
      );
      expect(
        source.contains('BorderRadius.circular'),
        isFalse,
        reason: '$path must not choose its own corner radius; the card owns that',
      );
    }
  });

  test('every screen that shows a track album uses the shared wrappers', () {
    // Direct `TrackCard(` calls are allowed only for a loading skeleton or a
    // playlist card - never a per-screen album/track rendering.
    final offenders = <String>[];

    for (final file in libSources()) {
      final path = file.path.replaceAll(r'\', '/');
      if (path.contains('components/track_card/')) continue;

      final source = file.readAsStringSync();
      if (!source.contains('TrackCard(')) continue;

      // A screen reaching for the raw card must not also be styling it.
      final directUses = RegExp(r'TrackCard\(').allMatches(source).length;
      final wrapperUses = RegExp(r'Home(Track|Album)Card\(')
          .allMatches(source)
          .length;

      if (directUses > 0 && wrapperUses == 0) {
        // Allowed only when it passes no width (skeleton) or uses the shared
        // cardWidth constant (playlist card). A bespoke width would make the
        // grid differ from every other screen.
        final bespokeWidth = RegExp(r'width:\s*\d+(\.\d+)?\s*\*')
            .allMatches(source)
            .isNotEmpty;
        if (bespokeWidth) offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'these files build the raw card with a bespoke width, so their '
          'grid will not match the home screen: $offenders',
    );
  });

  test('the card width is taken from the shared layout constant', () {
    // The single source of the tile width, so every grid agrees.
    final layout =
        File('lib/modules/home/sections/home_section_layout.dart')
            .readAsStringSync();
    expect(
      layout.contains('cardWidth'),
      isTrue,
      reason: 'HomeSectionLayout owns the card width every screen must use',
    );
  });
}
