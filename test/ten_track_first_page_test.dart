// Pins the "ten tracks, then see more" rule everywhere it applies.
//
// Every shelf and screen that lists tracks reveals ten of them and then offers
// a way to see more, so no screen opens on an endless wall of cards:
//
//   * the home rows (Newest Arrivals, Top Trending, Recently Played, each
//     language's songs),
//   * the "see all" screens reached from those rows (Albums, Newest Arrivals,
//     Top Trending, a language's songs),
//   * the deity screens,
//   * the album screens (through the shared presentation list).
//
// The numbers live in one place per surface, and these assertions are what stop
// them drifting back to 25/100 (which is what they were) without anyone
// noticing that one surface had quietly stopped following the rule.
import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/components/track_presentation/presentation_list.dart';
import 'package:sangeet/modules/home/sections/recent_tracks.dart';
import 'package:sangeet/modules/home/sections/track_section.dart';
import 'package:sangeet/pages/home/featured_playlist_detail.dart';
import 'package:sangeet/pages/home/home_see_all.dart';

void main() {
  test('every track surface reveals ten tracks per page', () {
    expect(HomeTrackSection.pageSize, 10,
        reason: 'the home Newest Arrivals / Top Trending rows');
    expect(HomeRecentlyPlayedTracksSection.pageSize, 10,
        reason: 'the home Recently Played row');
    expect(HomeSeeAllPage.pageSize, 10,
        reason: 'the Albums / Newest Arrivals / Top Trending / language '
            'screens');
    expect(FeaturedPlaylistPage.pageSize, 10,
        reason: 'the deity screens');
    expect(kPresentationInitialVisibleTracks, 10,
        reason: 'the album screens (shared presentation list)');
  });

  test('the see-more thresholds are the same number as the page size', () {
    // A row only renders its "See More" card when it has more than one page, and
    // the presentation list only renders its expander above this threshold; if
    // either fell below the page size the control would appear while the first
    // page was still complete, or never appear at all.
    expect(kPresentationInitialVisibleTracks, HomeTrackSection.pageSize);
    expect(kPresentationInitialVisibleTracks, HomeSeeAllPage.pageSize);
  });
}
