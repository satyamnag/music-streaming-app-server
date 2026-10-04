// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get guest => 'ã‚²ã‚¹ãƒˆ';

  @override
  String get browse => 'é–²è¦§';

  @override
  String get search => 'æ¤œç´¢';

  @override
  String get library => 'ãƒ©ã‚¤ãƒ–ãƒ©ãƒª';

  @override
  String get lyrics => 'æ­Œè©ž';

  @override
  String get settings => 'è¨­å®š';

  @override
  String get settings_subtitle =>
      'Soulful Bhakti ã‚’ãŠå¥½ã¿ã«åˆã‚ã›ã¦ã‚«ã‚¹ã‚¿ãƒžã‚¤ã‚º';

  @override
  String get genre_categories_filter =>
      'ã‚«ãƒ†ã‚´ãƒªãƒ¼ã‚„ã‚¸ãƒ£ãƒ³ãƒ«ã‚’çµžã‚Šè¾¼ã¿...';

  @override
  String get genre => 'ã‚¸ãƒ£ãƒ³ãƒ«';

  @override
  String get personalized => 'ã‚ãªãŸã«ãŠã™ã™ã‚';

  @override
  String get featured => 'æ³¨ç›®';

  @override
  String get new_releases => 'æ–°ç€';

  @override
  String get songs => 'æ›²';

  @override
  String get newest_arrivals => 'æœ€æ–°ã®è¿½åŠ ';

  @override
  String get top_trending => 'æ€¥ä¸Šæ˜‡';

  @override
  String get see_more => 'ã‚‚ã£ã¨è¦‹ã‚‹';

  @override
  String playing_track(Object track) {
    return '$track ã‚’å†ç”Ÿ';
  }

  @override
  String queue_clear_alert(Object track_length) {
    return 'ç¾åœ¨ã®ã‚­ãƒ¥ãƒ¼ã‚’æ¶ˆåŽ»ã—ã¾ã™ã€‚$track_length æ›²ã‚’æ¶ˆåŽ»ã—ã¾ã™ã€‚\nç¶šè¡Œã—ã¾ã™ã‹ï¼Ÿ';
  }

  @override
  String get load_more => 'ã‚‚ã£ã¨èª­ã¿è¾¼ã‚€';

  @override
  String get playlists => 'å†ç”Ÿãƒªã‚¹ãƒˆ';

  @override
  String get artists => 'ã‚¢ãƒ¼ãƒ†ã‚£ã‚¹ãƒˆ';

  @override
  String get albums => 'ã‚¢ãƒ«ãƒãƒ ';

  @override
  String get tracks => 'æ›²';

  @override
  String get downloads => 'ãƒ€ã‚¦ãƒ³ãƒ­ãƒ¼ãƒ‰';

  @override
  String get filter_playlists =>
      'ã‚ãªãŸã®å†ç”Ÿãƒªã‚¹ãƒˆã‚’çµžã‚Šè¾¼ã¿...';

  @override
  String get liked_tracks => 'ã„ã„ã­ã—ãŸæ›²';

  @override
  String get liked_tracks_description => 'ã„ã„ã­ã—ãŸã™ã¹ã¦ã®æ›²';

  @override
  String get playlist => 'å†ç”Ÿãƒªã‚¹ãƒˆ';

  @override
  String get create_a_playlist => 'å†ç”Ÿãƒªã‚¹ãƒˆã®ä½œæˆ';

  @override
  String get new_playlist => 'æ–°ã—ã„ãƒ—ãƒ¬ã‚¤ãƒªã‚¹ãƒˆ';

  @override
  String get playlist_name => 'å†ç”Ÿãƒªã‚¹ãƒˆå';

  @override
  String get no_playlists_yet =>
      'ã¾ã ãƒ—ãƒ¬ã‚¤ãƒªã‚¹ãƒˆãŒã‚ã‚Šã¾ã›ã‚“ã€‚é¸æŠžã—ãŸæ›²ã‹ã‚‰ä½œæˆã—ã¦ãã ã•ã„ã€‚';

  @override
  String get update_playlist => 'å†ç”Ÿãƒªã‚¹ãƒˆã‚’æ›´æ–°';

  @override
  String get create => 'ä½œæˆ';

  @override
  String get cancel => 'ã‚­ãƒ£ãƒ³ã‚»ãƒ«';

  @override
  String get update => 'æ›´æ–°';

  @override
  String get name_of_playlist => 'å†ç”Ÿãƒªã‚¹ãƒˆã®åå‰';

  @override
  String get description => 'èª¬æ˜Ž';

  @override
  String get public => 'å…¬é–‹';

  @override
  String get collaborative => 'ã‚³ãƒ©ãƒœ';

  @override
  String get search_local_tracks => 'ç«¯æœ«å†…ã®æ›²ã‚’æ¤œç´¢...';

  @override
  String get play => 'å†ç”Ÿ';

  @override
  String get delete => 'å‰Šé™¤';

  @override
  String get none => 'ãªã—';

  @override
  String get sort_a_z => 'A-Z é †ã«ä¸¦ã³æ›¿ãˆ';

  @override
  String get sort_z_a => 'Z-A é †ã«ä¸¦ã³æ›¿ãˆ';

  @override
  String get sort_artist => 'ã‚¢ãƒ¼ãƒ†ã‚£ã‚¹ãƒˆé †ã«ä¸¦ã³æ›¿ãˆ';

  @override
  String get sort_album => 'ã‚¢ãƒ«ãƒãƒ é †ã«ä¸¦ã³æ›¿ãˆ';

  @override
  String get sort_duration => 'é•·ã•é †ã«ä¸¦ã¹æ›¿ãˆ';

  @override
  String get sort_tracks => 'æ›²ã®ä¸¦ã³æ›¿ãˆ';

  @override
  String currently_downloading(Object tracks_length) {
    return 'ãƒ€ã‚¦ãƒ³ãƒ­ãƒ¼ãƒ‰ä¸­ ($tracks_length) æ›²';
  }

  @override
  String get cancel_all => 'ã™ã¹ã¦ã‚­ãƒ£ãƒ³ã‚»ãƒ«';

  @override
  String get filter_artist => 'ã‚¢ãƒ¼ãƒ†ã‚£ã‚¹ãƒˆã‚’çµžã‚Šè¾¼ã¿...';

  @override
  String followers(Object followers) {
    return '$followers ãƒ•ã‚©ãƒ­ãƒ¯ãƒ¼';
  }

  @override
  String get add_artist_to_blacklist =>
      'ã“ã®ã‚¢ãƒ¼ãƒ†ã‚£ã‚¹ãƒˆã‚’ãƒ–ãƒ©ãƒƒã‚¯ãƒªã‚¹ãƒˆã«è¿½åŠ ';

  @override
  String get top_tracks => 'äººæ°—ã®æ›²';

  @override
  String get fans_also_like => 'ãƒ•ã‚¡ãƒ³ã®é–“ã§äººæ°—';

  @override
  String get loading => 'èª­ã¿è¾¼ã¿ä¸­...';

  @override
  String get artist => 'ã‚¢ãƒ¼ãƒ†ã‚£ã‚¹ãƒˆ';

  @override
  String get blacklisted => 'ãƒ–ãƒ©ãƒƒã‚¯ãƒªã‚¹ãƒˆ';

  @override
  String get following => 'ãƒ•ã‚©ãƒ­ãƒ¼ä¸­';

  @override
  String get follow => 'ãƒ•ã‚©ãƒ­ãƒ¼ã™ã‚‹';

  @override
  String get artist_url_copied =>
      'ã‚¢ãƒ¼ãƒ†ã‚£ã‚¹ãƒˆã® URL ã‚’ã‚¯ãƒªãƒƒãƒ—ãƒœãƒ¼ãƒ‰ã«ã‚³ãƒ”ãƒ¼ã—ã¾ã—ãŸ';

  @override
  String added_to_queue(Object tracks) {
    return '$tracks ã‚’ã‚­ãƒ¥ãƒ¼ã«è¿½åŠ ã—ã¾ã—ãŸ';
  }

  @override
  String get filter_albums => 'ã‚¢ãƒ«ãƒãƒ ã‚’çµžã‚Šè¾¼ã¿...';

  @override
  String get synced => 'åŒæœŸã™ã‚‹';

  @override
  String get plain => 'ãã®ã¾ã¾';

  @override
  String get shuffle => 'ã‚·ãƒ£ãƒƒãƒ•ãƒ«';

  @override
  String get search_tracks => 'æ›²ã‚’æ¤œç´¢...';

  @override
  String get released => 'ãƒªãƒªãƒ¼ã‚¹æ—¥';

  @override
  String error(Object error) {
    return 'ã‚¨ãƒ©ãƒ¼ $error';
  }

  @override
  String get title => 'ã‚¿ã‚¤ãƒˆãƒ«';

  @override
  String get time => 'é•·ã•';

  @override
  String get more_actions => 'ã»ã‹ã®æ“ä½œ';

  @override
  String add_count_to_playlist(Object count) {
    return 'å†ç”Ÿãƒªã‚¹ãƒˆã« ($count) æ›²ã‚’è¿½åŠ ';
  }

  @override
  String add_count_to_queue(Object count) {
    return 'ã‚­ãƒ¥ãƒ¼ã« ($count) æ›²ã‚’è¿½åŠ ';
  }

  @override
  String play_count_next(Object count) {
    return 'æ¬¡ã« ($count) æ›²ã‚’å†ç”Ÿ';
  }

  @override
  String get album => 'ã‚¢ãƒ«ãƒãƒ ';

  @override
  String copied_to_clipboard(Object data) {
    return '$data ã‚’ã‚¯ãƒªãƒƒãƒ—ãƒœãƒ¼ãƒ‰ã«ã‚³ãƒ”ãƒ¼ã—ã¾ã—ãŸ';
  }

  @override
  String add_to_following_playlists(Object track) {
    return '$track ã‚’ã“ã®å†ç”Ÿãƒªã‚¹ãƒˆã«è¿½åŠ ';
  }

  @override
  String get add => 'è¿½åŠ ';

  @override
  String added_track_to_queue(Object track) {
    return 'ã‚­ãƒ¥ãƒ¼ã« $track ã‚’è¿½åŠ ã—ã¾ã—ãŸ';
  }

  @override
  String get add_to_queue => 'ã‚­ãƒ¥ãƒ¼ã«è¿½åŠ ';

  @override
  String track_will_play_next(Object track) {
    return '$track ã‚’æ¬¡ã«å†ç”Ÿ';
  }

  @override
  String get play_next => 'æ¬¡ã«å†ç”Ÿ';

  @override
  String removed_track_from_queue(Object track) {
    return 'ã‚­ãƒ¥ãƒ¼ã‹ã‚‰ $track ã‚’é™¤åŽ»ã—ã¾ã—ãŸ';
  }

  @override
  String get remove_from_queue => 'ã‚­ãƒ¥ãƒ¼ã‹ã‚‰é™¤åŽ»';

  @override
  String get remove_from_favorites => 'ãŠæ°—ã«å…¥ã‚Šã‹ã‚‰é™¤åŽ»';

  @override
  String get save_as_favorite => 'ãŠæ°—ã«å…¥ã‚Šã«ä¿å­˜';

  @override
  String get add_to_playlist => 'å†ç”Ÿãƒªã‚¹ãƒˆã«è¿½åŠ ';

  @override
  String get remove_from_playlist => 'å†ç”Ÿãƒªã‚¹ãƒˆã‹ã‚‰é™¤åŽ»';

  @override
  String get add_to_blacklist => 'ãƒ–ãƒ©ãƒƒã‚¯ãƒªã‚¹ãƒˆã«è¿½åŠ ';

  @override
  String get remove_from_blacklist => 'ãƒ–ãƒ©ãƒƒã‚¯ãƒªã‚¹ãƒˆã‹ã‚‰é™¤åŽ»';

  @override
  String get share => 'å…±æœ‰';

  @override
  String get mini_player => 'ãƒŸãƒ‹ãƒ—ãƒ¬ã‚¤ãƒ¤ãƒ¼';

  @override
  String get slide_to_seek => 'å‰å¾Œã«ã‚¹ãƒ©ã‚¤ãƒ‰ã—ã¦ã‚·ãƒ¼ã‚¯';

  @override
  String get shuffle_playlist => 'å†ç”Ÿãƒªã‚¹ãƒˆã‚’ã‚·ãƒ£ãƒƒãƒ•ãƒ«';

  @override
  String get unshuffle_playlist => 'å†ç”Ÿãƒªã‚¹ãƒˆã®ã‚·ãƒ£ãƒƒãƒ•ãƒ«è§£é™¤';

  @override
  String get previous_track => 'å‰ã®æ›²';

  @override
  String get next_track => 'æ¬¡ã®æ›²';

  @override
  String get pause_playback => 'å†ç”Ÿã‚’åœæ­¢';

  @override
  String get resume_playback => 'å†ç”Ÿã‚’å†é–‹';

  @override
  String get loop_track => 'æ›²ã‚’ãƒ«ãƒ¼ãƒ—';

  @override
  String get no_loop => 'ãƒ«ãƒ¼ãƒ—ãªã—';

  @override
  String get repeat_playlist => 'å†ç”Ÿãƒªã‚¹ãƒˆã‚’ãƒªãƒ”ãƒ¼ãƒˆ';

  @override
  String get queue => 'å†ç”Ÿã‚­ãƒ¥ãƒ¼';

  @override
  String get alternative_track_sources => 'ã“ã®æ›²ã®åˆ¥ã®éŸ³æºã‚’é¸ã¶';

  @override
  String tracks_in_queue(Object tracks) {
    return '$tracksæ›²ã®å†ç”Ÿã‚­ãƒ¥ãƒ¼';
  }

  @override
  String get clear_all => 'ã™ã¹ã¦æ¶ˆåŽ»l';

  @override
  String get show_hide_ui_on_hover => 'ãƒžã‚¦ã‚¹ã‚’ä¹—ã›ã¦UIã‚’è¡¨ç¤º/éš ã™';

  @override
  String get always_on_top => 'å¸¸ã«æ‰‹å‰ã«è¡¨ç¤º';

  @override
  String get exit_mini_player => 'ãƒŸãƒ‹ãƒ—ãƒ¬ã‚¤ãƒ¤ãƒ¼ã‚’çµ‚äº†';

  @override
  String get local_library => 'ç«¯æœ«å†…ãƒ©ã‚¤ãƒ–ãƒ©ãƒª';

  @override
  String get add_library_location => 'ãƒ©ã‚¤ãƒ–ãƒ©ãƒªã«è¿½åŠ ';

  @override
  String get remove_library_location => 'ãƒ©ã‚¤ãƒ–ãƒ©ãƒªã‹ã‚‰å‰Šé™¤';

  @override
  String get account => 'ã‚¢ã‚«ã‚¦ãƒ³ãƒˆ';

  @override
  String get logout => 'ãƒ­ã‚°ã‚¢ã‚¦ãƒˆ';

  @override
  String get logout_of_this_account =>
      'ã“ã®ã‚¢ã‚«ã‚¦ãƒ³ãƒˆã‹ã‚‰ãƒ­ã‚°ã‚¢ã‚¦ãƒˆ';

  @override
  String get language_region => 'è¨€èªž & åœ°åŸŸ';

  @override
  String get language => 'è¨€èªž';

  @override
  String get system_default => 'ã‚·ã‚¹ãƒ†ãƒ ã®æ—¢å®šå€¤';

  @override
  String get market_place_region => 'éŸ³æ¥½å¸‚å ´ã®åœ°åŸŸ';

  @override
  String get recommendation_country => 'ãŠã™ã™ã‚ã®å›½';

  @override
  String get appearance => 'å¤–è¦³';

  @override
  String get layout_mode => 'ãƒ¬ã‚¤ã‚¢ã‚¦ãƒˆã®ç¨®é¡ž';

  @override
  String get override_layout_settings =>
      'ãƒ¬ã‚¹ãƒãƒ³ã‚·ãƒ–ãªãƒ¬ã‚¤ã‚¢ã‚¦ãƒˆã®ç¨®é¡žã®è¨­å®šã‚’ä¸Šæ›¸ãã™ã‚‹';

  @override
  String get adaptive => 'é©å¿œçš„';

  @override
  String get compact => 'ã‚³ãƒ³ãƒ‘ã‚¯ãƒˆ';

  @override
  String get extended => 'å¹…åºƒ';

  @override
  String get theme => 'ãƒ†ãƒ¼ãƒž';

  @override
  String get dark => 'ãƒ€ãƒ¼ã‚¯';

  @override
  String get light => 'ãƒ©ã‚¤ãƒˆ';

  @override
  String get system => 'ã‚·ã‚¹ãƒ†ãƒ ã«å¾“ã†';

  @override
  String get accent_color => 'ã‚¢ã‚¯ã‚»ãƒ³ãƒˆã‚«ãƒ©ãƒ¼';

  @override
  String get sync_album_color => 'ã‚¢ãƒ«ãƒãƒ ã®è‰²ã«åˆã‚ã›ã‚‹';

  @override
  String get sync_album_color_description =>
      'ã‚¢ãƒ«ãƒãƒ ã‚¢ãƒ¼ãƒˆã®ä¸»å¼µè‰²ã‚’ã‚¢ã‚¯ã‚»ãƒ³ãƒˆã‚«ãƒ©ãƒ¼ã¨ã—ã¦ä½¿ç”¨';

  @override
  String get playback => 'å†ç”Ÿ';

  @override
  String get audio_quality => 'éŸ³å£°å“è³ª';

  @override
  String get high => 'é«˜';

  @override
  String get low => 'ä½Ž';

  @override
  String get pre_download_play => 'äº‹å‰ãƒ€ã‚¦ãƒ³ãƒ­ãƒ¼ãƒ‰ã¨å†ç”Ÿ';

  @override
  String get pre_download_play_description =>
      'éŸ³å£°ã‚’ã‚¹ãƒˆãƒªãƒ¼ãƒŸãƒ³ã‚°ã™ã‚‹ä»£ã‚ã‚Šã«ã€ãƒ‡ãƒ¼ã‚¿ã‚’ãƒã‚¤ãƒˆå˜ä½ã§ãƒ€ã‚¦ãƒ³ãƒ­ãƒ¼ãƒ‰ã—ã¦å†ç”Ÿ (å›žç·šé€Ÿåº¦ãŒæ—©ã„ãƒ¦ãƒ¼ã‚¶ãƒ¼ã«ãŠã™ã™ã‚)';

  @override
  String get skip_non_music =>
      'éŸ³æ¥½ã§ãªã„éƒ¨åˆ†ã‚’ã‚¹ã‚­ãƒƒãƒ— (SponsorBlock)';

  @override
  String get blacklist_description =>
      'æ›²ã¨ã‚¢ãƒ¼ãƒ†ã‚£ã‚¹ãƒˆã®ãƒ–ãƒ©ãƒƒã‚¯ãƒªã‚¹ãƒˆ';

  @override
  String get wait_for_download_to_finish =>
      'ç¾åœ¨ã®ãƒ€ã‚¦ãƒ³ãƒ­ãƒ¼ãƒ‰ãŒå®Œäº†ã™ã‚‹ã¾ã§ãŠå¾…ã¡ãã ã•ã„';

  @override
  String get desktop => 'ãƒ‡ã‚¹ã‚¯ãƒˆãƒƒãƒ—';

  @override
  String get close_behavior => 'é–‰ã˜ãŸæ™‚ã®å‹•ä½œ';

  @override
  String get close => 'é–‰ã˜ã‚‹';

  @override
  String get minimize_to_tray => 'ãƒˆãƒ¬ã‚¤ã«æœ€å°åŒ–';

  @override
  String get show_tray_icon => 'ã‚·ã‚¹ãƒ†ãƒ ãƒˆãƒ¬ã‚¤ã«ã‚¢ã‚¤ã‚³ãƒ³ã‚’è¡¨ç¤º';

  @override
  String get about => 'ã“ã®ã‚¢ãƒ—ãƒªã«ã¤ã„ã¦';

  @override
  String get u_love_spotube =>
      'Soulful Bhakti ãŒå¥½ãã ã¨çŸ¥ã£ã¦ã„ã¾ã™ã‚ˆ';

  @override
  String get check_for_updates => 'ã‚¢ãƒƒãƒ—ãƒ‡ãƒ¼ãƒˆã®ç¢ºèª';

  @override
  String get about_spotube => 'Soulful Bhakti ã«ã¤ã„ã¦';

  @override
  String get blacklist => 'ãƒ–ãƒ©ãƒƒã‚¯ãƒªã‚¹ãƒˆ';

  @override
  String get please_sponsor => 'å‡ºè³‡/å¯„ä»˜ã‚‚ãŠå¾…ã¡ã—ã¾ã™';

  @override
  String get spotube_description =>
      'Soulful Bhakti ã¯ã€è»½é‡ã§ã‚¯ãƒ­ã‚¹ãƒ—ãƒ©ãƒƒãƒˆãƒ•ã‚©ãƒ¼ãƒ ãªã€ã™ã¹ã¦ç„¡æ–™ã® spotify ã‚¯ãƒ©ã‚¤ã‚¢ãƒ³ãƒˆ';

  @override
  String get version => 'ãƒãƒ¼ã‚¸ãƒ§ãƒ³';

  @override
  String get build_number => 'ãƒ“ãƒ«ãƒ‰ç•ªå·';

  @override
  String get founder => 'å‰µå§‹è€…';

  @override
  String get repository => 'ãƒªãƒã‚¸ãƒˆãƒª';

  @override
  String get bug_issues => 'ãƒã‚°ã‚„å•é¡Œ';

  @override
  String get made_with =>
      'â¤ï¸ ã‚’è¾¼ã‚ã¦ãƒãƒ³ã‚°ãƒ©ãƒ‡ã‚£ã‚·ãƒ¥ðŸ‡§ðŸ‡©ã§é–‹ç™º';

  @override
  String get kingkor_roy_tirtho => 'Kingkor Roy Tirtho';

  @override
  String copyright(Object current_year) {
    return 'Â© 2021-$current_year Kingkor Roy Tirtho';
  }

  @override
  String get license => 'ãƒ©ã‚¤ã‚»ãƒ³ã‚¹';

  @override
  String get credentials_will_not_be_shared_disclaimer =>
      'å¿ƒé…ã‚ã‚Šã¾ã›ã‚“ã€‚å€‹äººæƒ…å ±ã‚’åŽé›†ã—ãŸã‚Šã€å…±æœ‰ã•ã‚Œã‚‹ã“ã¨ã¯ã‚ã‚Šã¾ã›ã‚“';

  @override
  String get know_how_to_login => 'ã‚„ã‚Šæ–¹ãŒåˆ†ã‹ã‚‰ãªã„ã§ã™ã‹ï¼Ÿ';

  @override
  String get follow_step_by_step_guide => 'ã‚„ã‚Šæ–¹ã®èª¬æ˜Žã‚’è¦‹ã‚‹';

  @override
  String cookie_name_cookie(Object name) {
    return '$name Cookies';
  }

  @override
  String get fill_in_all_fields => 'ã™ã¹ã¦ã®æ¬„ã«å…¥åŠ›ã—ã¦ãã ã•ã„';

  @override
  String get submit => 'é€ä¿¡';

  @override
  String get exit => 'çµ‚äº†';

  @override
  String get previous => 'å‰ã¸';

  @override
  String get next => 'æ¬¡ã¸';

  @override
  String get done => 'å®Œäº†';

  @override
  String get step_1 => 'ã‚¹ãƒ†ãƒƒãƒ— 1';

  @override
  String get first_go_to => 'æœ€åˆã«ã“ã“ã‚’é–‹ã';

  @override
  String get something_went_wrong => 'ä½•ã‹èª¤ã‚ŠãŒã‚ã‚Šã¾ã™';

  @override
  String get piped_instance => 'Piped ã‚µãƒ¼ãƒãƒ¼ã®ã‚¤ãƒ³ã‚¹ã‚¿ãƒ³ã‚¹';

  @override
  String get piped_description =>
      'æ›²ã®ä¸€è‡´ã«ä½¿ã† Piped ã‚µãƒ¼ãƒãƒ¼ã®ã‚¤ãƒ³ã‚¹ã‚¿ãƒ³ã‚¹';

  @override
  String get piped_warning =>
      'ãã‚Œã‚‰ã®ä¸€éƒ¨ã§ã¯ã†ã¾ãå‹•ä½œã—ãªã„ã“ã¨ã‚‚ã‚ã‚Šã¾ã™ã€‚è‡ªå·±è²¬ä»»ã§ä½¿ç”¨ã—ã¦ãã ã•ã„';

  @override
  String get invidious_instance => 'Invidiousã‚µãƒ¼ãƒãƒ¼ã‚¤ãƒ³ã‚¹ã‚¿ãƒ³ã‚¹';

  @override
  String get invidious_description =>
      'æ›²ã®ä¸€è‡´ã«ä½¿ç”¨ã™ã‚‹Invidiousã‚µãƒ¼ãƒãƒ¼ã‚¤ãƒ³ã‚¹ã‚¿ãƒ³ã‚¹';

  @override
  String get invidious_warning =>
      'ä¸€éƒ¨ã¯ã†ã¾ãæ©Ÿèƒ½ã—ãªã„å¯èƒ½æ€§ãŒã‚ã‚Šã¾ã™ã€‚è‡ªå·±è²¬ä»»ã§ä½¿ç”¨ã—ã¦ãã ã•ã„';

  @override
  String get generate => 'ç”Ÿæˆ';

  @override
  String track_exists(Object track) {
    return 'æ›² $track ã¯æ—¢ã«å­˜åœ¨ã—ã¾ã™';
  }

  @override
  String get replace => 'ç½®æ›ã™ã‚‹';

  @override
  String get skip => 'ã‚¹ã‚­ãƒƒãƒ—';

  @override
  String select_up_to_count_type(Object count, Object type) {
    return '$typeã‚’æœ€å¤§$count å€‹ã¾ã§é¸æŠž';
  }

  @override
  String get select_genres => 'ã‚¸ãƒ£ãƒ³ãƒ«ã‚’é¸æŠž';

  @override
  String get add_genres => 'ã‚¸ãƒ£ãƒ³ãƒ«ã‚’è¿½åŠ ';

  @override
  String get country => 'å›½';

  @override
  String get number_of_tracks_generate => 'ç”Ÿæˆã™ã‚‹æ›²æ•°';

  @override
  String get acousticness => 'ã‚¢ã‚³ãƒ¼ã‚¹ãƒ†ã‚£ãƒƒã‚¯æ„Ÿ';

  @override
  String get danceability => 'ãƒ€ãƒ³ã‚¹æ„Ÿ';

  @override
  String get energy => 'ã‚¨ãƒãƒ«ã‚®ãƒ¼';

  @override
  String get instrumentalness => 'ã‚¤ãƒ³ã‚¹ãƒˆã‚¥ãƒ«ãƒ¡ãƒ³ã‚¿ãƒ«';

  @override
  String get liveness => 'ãƒ©ã‚¤ãƒ–æ„Ÿ';

  @override
  String get loudness => 'ãƒ©ã‚¦ãƒ‰ãƒã‚¹';

  @override
  String get speechiness => 'ä¼šè©±æ„Ÿ';

  @override
  String get valence => 'å¤šå¹¸æ€§';

  @override
  String get popularity => 'äººæ°—åº¦';

  @override
  String get key => 'ã‚­ãƒ¼';

  @override
  String get duration => 'é•·ã• (ç§’)';

  @override
  String get tempo => 'ãƒ†ãƒ³ãƒ (BPM)';

  @override
  String get mode => 'é•·èª¿';

  @override
  String get time_signature => 'æ‹å­è¨˜å·';

  @override
  String get short => 'çŸ­';

  @override
  String get medium => 'ä¸­';

  @override
  String get long => 'é•·';

  @override
  String get min => 'æœ€å°';

  @override
  String get max => 'æœ€å¤§';

  @override
  String get target => 'ç›®æ¨™';

  @override
  String get moderate => 'ä¸­';

  @override
  String get deselect_all => 'ã™ã¹ã¦é¸æŠžè§£é™¤';

  @override
  String get select_all => 'ã™ã¹ã¦é¸æŠž';

  @override
  String get are_you_sure => 'ã‚ˆã‚ã—ã„ã§ã™ã‹ï¼Ÿ';

  @override
  String get generating_playlist =>
      'ã‚«ã‚¹ã‚¿ãƒ ã®å†ç”Ÿãƒªã‚¹ãƒˆã‚’ç”Ÿæˆä¸­...';

  @override
  String selected_count_tracks(Object count) {
    return '$count æ›²ãŒé¸ã°ã‚Œã¾ã—ãŸ';
  }

  @override
  String get download_warning =>
      'å…¨æ›²ã®ä¸€æ‹¬ãƒ€ã‚¦ãƒ³ãƒ­ãƒ¼ãƒ‰ã¯æ˜Žã‚‰ã‹ã«éŸ³æ¥½ã¸ã®æµ·è³Šè¡Œç‚ºã§ã‚ã‚Šã€éŸ³æ¥½ã‚’ç”Ÿã¿å‡ºã™å…±åŒä½“ã«æå®³ã‚’ä¸Žãˆã‚‹ã§ã—ã‚‡ã†ã€‚æ°—ã¥ã„ã¦ã»ã—ã„ã€‚ã‚¢ãƒ¼ãƒ†ã‚£ã‚¹ãƒˆã®å¤šå¤§ãªåŠªåŠ›ã«æ•¬æ„ã‚’æ‰•ã„ã€æ”¯æ´ã™ã‚‹ã‚ˆã†ã«ã—ã¦ãã ã•ã„';

  @override
  String get download_ip_ban_warning =>
      'ã¾ãŸã€é€šå¸¸ã‚ˆã‚Šã‚‚éŽå‰°ãªãƒ€ã‚¦ãƒ³ãƒ­ãƒ¼ãƒ‰è¦æ±‚ãŒã‚ã‚Œã°ã€YouTubeã¯ã‚ãªãŸã®IPã‚’ãƒ–ãƒ­ãƒƒã‚¯ã—ã¾ã™ã€‚ã¤ã¾ã‚Šãã®IPã®ç«¯æœ«ã‹ã‚‰ã¯ã€å°‘ãªãã¨ã‚‚2-3ã‹æœˆã®é–“ã€ï¼ˆãƒ­ã‚°ã‚¤ãƒ³ã—ã¦ã‚‚ï¼‰YouTubeã‚’åˆ©ç”¨ã§ããªããªã‚Šã™ã€‚ãã†ãªã£ã¦ã‚‚ Soulful Bhakti ã¯ä¸€åˆ‡ã®è²¬ä»»ã‚’è² ã„ã¾ã›ã‚“';

  @override
  String get by_clicking_accept_terms =>
      'ã€ŒåŒæ„ã™ã‚‹ã€ã®ã‚¯ãƒªãƒƒã‚¯ã«ã‚ˆã‚Šã€ä»¥ä¸‹ã¸ã®åŒæ„ã¨ãªã‚Šã¾ã™:';

  @override
  String get download_agreement_1 =>
      'ãˆãˆã€éŸ³æ¥½ã¸ã®æµ·è³Šè¡Œç‚ºã ã€‚ç§ã¯ã‚ˆããªã„';

  @override
  String get download_agreement_2 =>
      'èŠ¸è¡“ä½œå“ã‚’è²·ã†ãŠé‡‘ãŒãªã„ã®ã§ãã†ã™ã‚‹ã—ã‹ãªã„ãŒã€ã‚¢ãƒ¼ãƒ†ã‚£ã‚¹ãƒˆã‚’ã§ãã‚‹é™ã‚Šæ”¯æ´ã™ã‚‹';

  @override
  String get download_agreement_3 =>
      'ç§ã®IPãŒYouTubeã«ãƒ–ãƒ­ãƒƒã‚¯ã•ã‚Œã‚‹ã“ã¨ãŒã‚ã‚‹ã¨å®Œå…¨ã«æŠŠæ¡ã—ãŸã€‚ç§ã®ã“ã®è¡Œå‹•ã«ã‚ˆã‚Šèµ·ããŸã©ã‚“ãªäº‹æ•…ã‚‚ã€Soulful Bhakti ã‚„ãã®æ‰€æœ‰è€…/è²¢çŒ®è€…ã«è²¬ä»»ã¯ã‚ã‚Šã¾ã›ã‚“ã€‚';

  @override
  String get decline => 'åŒæ„ã—ãªã„';

  @override
  String get accept => 'åŒæ„ã™ã‚‹';

  @override
  String get details => 'è©³ç´°';

  @override
  String get youtube => 'YouTube';

  @override
  String get channel => 'ãƒãƒ£ãƒ³ãƒãƒ«';

  @override
  String get likes => 'é«˜è©•ä¾¡';

  @override
  String get dislikes => 'ä½Žè©•ä¾¡';

  @override
  String get views => 'è¦–è´å›žæ•°';

  @override
  String get streamUrl => 'å‹•ç”»ã® URL';

  @override
  String get stop => 'ä¸­æ­¢';

  @override
  String get sort_newest => 'è¿½åŠ æ—¥ã®æ–°ã—ã„é †ã«ä¸¦ã³æ›¿ãˆ';

  @override
  String get sort_oldest => 'è¿½åŠ æ—¥ã®å¤ã„é †ã«ä¸¦ã³æ›¿ãˆ';

  @override
  String get sleep_timer => 'ã‚¹ãƒªãƒ¼ãƒ—ã‚¿ã‚¤ãƒžãƒ¼';

  @override
  String mins(Object minutes) {
    return '$minutes åˆ†';
  }

  @override
  String hours(Object hours) {
    return '$hours æ™‚é–“';
  }

  @override
  String hour(Object hours) {
    return '$hours æ™‚é–“';
  }

  @override
  String get custom_hours => 'æ™‚é–“ã‚’æŒ‡å®š';

  @override
  String get logs => 'ãƒ­ã‚°';

  @override
  String get developers => 'é–‹ç™º';

  @override
  String get not_logged_in => 'ãƒ­ã‚°ã‚¤ãƒ³ã—ã¦ã„ã¾ã›ã‚“';

  @override
  String get search_mode => 'æ¤œç´¢ãƒ¢ãƒ¼ãƒ‰';

  @override
  String get audio_source => 'éŸ³å£°ã®æä¾›å…ƒ';

  @override
  String get ok => 'OK';

  @override
  String get failed_to_encrypt => 'æš—å·åŒ–ã«å¤±æ•—ã—ã¾ã—ãŸ';

  @override
  String get encryption_failed_warning =>
      'SpoTubeã¯ãƒ‡ãƒ¼ã‚¿ã‚’å®‰å…¨ã«ä¿å­˜ã™ã‚‹ãŸã‚ã«æš—å·åŒ–ã‚’ç”¨ã„ã¾ã™ãŒã€æš—å·åŒ–ã«å¤±æ•—ã—ã¾ã—ãŸã€‚ã“ã®ãŸã‚ã€å®‰å…¨ã§ãªã„ä¿å­˜é ˜åŸŸã¸ã®ä¿å­˜ã«åˆ‡ã‚Šæ›¿ãˆã¾ã™\nOSãŒLinuxãªã‚‰ã€gnome-keyringã€kde-walletã€keepassxcãªã©ã®ç®¡ç†ãƒ„ãƒ¼ãƒ«ãŒã‚¤ãƒ³ã‚¹ãƒˆãƒ¼ãƒ«ã•ã‚Œã¦ã„ã‚‹ã“ã¨ã‚’ç¢ºèªã—ã¦ãã ã•ã„';

  @override
  String get querying_info => 'æƒ…å ±ã‚’å–å¾—ä¸­...';

  @override
  String get piped_api_down => 'Piped APIãŒãƒ€ã‚¦ãƒ³ã—ã¦ã„ã¾ã™';

  @override
  String piped_down_error_instructions(Object pipedInstance) {
    return 'Pipedã‚¤ãƒ³ã‚¹ã‚¿ãƒ³ã‚¹ $pipedInstance ã¯ç¾åœ¨ãƒ€ã‚¦ãƒ³ã—ã¦ã„ã¾ã™\n\nã‚¤ãƒ³ã‚¹ã‚¿ãƒ³ã‚¹ã‚’å¤‰æ›´ã™ã‚‹ã‹ã€ã€ŒAPIã®ç¨®é¡žã€ã‚’å…¬å¼ã®YouTube APIã«å¤‰æ›´ã—ã¦ãã ã•ã„\n\nå¤‰æ›´å¾Œã«ã‚¢ãƒ—ãƒªã‚’å†èµ·å‹•ã—ã¦ãã ã•ã„';
  }

  @override
  String get you_are_offline => 'ç¾åœ¨ã€ã‚ªãƒ•ãƒ©ã‚¤ãƒ³ã§ã™';

  @override
  String get connection_restored =>
      'ã‚¤ãƒ³ã‚¿ãƒ¼ãƒãƒƒãƒˆæŽ¥ç¶šãŒå¾©æ—§ã—ã¾ã—ãŸ';

  @override
  String get use_system_title_bar =>
      'ã‚·ã‚¹ãƒ†ãƒ ã®ã‚¿ã‚¤ãƒˆãƒ«ãƒãƒ¼ã‚’ä½¿ã†';

  @override
  String get crunching_results => 'çµæžœã‚’å‡¦ç†ä¸­...';

  @override
  String get search_to_get_results => 'çµæžœã‚’å–å¾—ã™ã‚‹ãŸã‚ã«æ¤œç´¢';

  @override
  String get use_amoled_mode => 'AMOLEDãƒ¢ãƒ¼ãƒ‰ã‚’ä½¿ç”¨';

  @override
  String get pitch_dark_theme => 'ãƒ”ãƒƒãƒãƒ–ãƒ©ãƒƒã‚¯ ãƒ€ãƒ¼ã‚¯ãƒ†ãƒ¼ãƒž';

  @override
  String get normalize_audio => 'éŸ³å£°ã‚’æ­£è¦åŒ–';

  @override
  String get change_cover => 'ã‚«ãƒãƒ¼ã‚’å¤‰æ›´';

  @override
  String get add_cover => 'ã‚«ãƒãƒ¼ã‚’è¿½åŠ ';

  @override
  String get restore_defaults => 'è¨­å®šã‚’åˆæœŸåŒ–';

  @override
  String get restore_defaults_confirmation =>
      'ã™ã¹ã¦ã®è¨­å®šãŒãƒ‡ãƒ•ã‚©ãƒ«ãƒˆå€¤ã«ãƒªã‚»ãƒƒãƒˆã•ã‚Œã¾ã™ã€‚ã“ã®æ“ä½œã¯å…ƒã«æˆ»ã›ã¾ã›ã‚“ã€‚';

  @override
  String get streaming_music_format => 'éŸ³æ¥½ã‚¹ãƒˆãƒªãƒ¼ãƒŸãƒ³ã‚°å½¢å¼';

  @override
  String get streaming_music_quality => 'éŸ³æ¥½ã‚¹ãƒˆãƒªãƒ¼ãƒŸãƒ³ã‚°å“è³ª';

  @override
  String get connect => 'æŽ¥ç¶š';

  @override
  String get disconnect => 'åˆ‡æ–­';

  @override
  String get username => 'ãƒ¦ãƒ¼ã‚¶ãƒ¼å';

  @override
  String get password => 'ãƒ‘ã‚¹ãƒ¯ãƒ¼ãƒ‰';

  @override
  String get login => 'ãƒ­ã‚°ã‚¤ãƒ³';

  @override
  String get sign_in => 'ãƒ­ã‚°ã‚¤ãƒ³';

  @override
  String get sign_up => 'ã‚µã‚¤ãƒ³ã‚¢ãƒƒãƒ—';

  @override
  String get sign_out => 'ãƒ­ã‚°ã‚¢ã‚¦ãƒˆ';

  @override
  String get verify => 'ç¢ºèª';

  @override
  String get create_account => 'ã‚¢ã‚«ã‚¦ãƒ³ãƒˆã‚’ä½œæˆ';

  @override
  String get already_have_account =>
      'ã™ã§ã«ã‚¢ã‚«ã‚¦ãƒ³ãƒˆã‚’ãŠæŒã¡ã§ã™ã‹ï¼Ÿãƒ­ã‚°ã‚¤ãƒ³';

  @override
  String get dont_have_account =>
      'ã‚¢ã‚«ã‚¦ãƒ³ãƒˆã‚’ãŠæŒã¡ã§ãªã„ã§ã™ã‹ï¼Ÿã‚µã‚¤ãƒ³ã‚¢ãƒƒãƒ—';

  @override
  String signed_in_as(Object userId) {
    return '$userId ã¨ã—ã¦ãƒ­ã‚°ã‚¤ãƒ³ä¸­';
  }

  @override
  String get verification_code => 'ç¢ºèªã‚³ãƒ¼ãƒ‰';

  @override
  String get verification_code_hint =>
      'ãƒ¡ãƒ¼ãƒ«ã«é€ä¿¡ã•ã‚ŒãŸã‚³ãƒ¼ãƒ‰ã‚’å…¥åŠ›ã—ã¦ãã ã•ã„';

  @override
  String get verify_email_code =>
      'ç¢ºèªã‚³ãƒ¼ãƒ‰ã‚’ãƒ¡ãƒ¼ãƒ«ã«é€ä¿¡ã—ã¾ã—ãŸ';

  @override
  String get go_to_album => 'ã‚¢ãƒ«ãƒãƒ ã«ç§»å‹•';

  @override
  String get discord_rich_presence => 'Discord ãƒªãƒƒãƒãƒ—ãƒ¬ã‚¼ãƒ³ã‚¹';

  @override
  String get browse_all => 'ã™ã¹ã¦ã‚’é–²è¦§';

  @override
  String get genres => 'ã‚¸ãƒ£ãƒ³ãƒ«';

  @override
  String get explore_genres => 'ã‚¸ãƒ£ãƒ³ãƒ«ã‚’æŽ¢ç´¢';

  @override
  String get friends => 'å‹é”';

  @override
  String get no_lyrics_available =>
      'ã™ã¿ã¾ã›ã‚“ã€ã“ã®æ›²ã®æ­Œè©žãŒè¦‹ã¤ã‹ã‚Šã¾ã›ã‚“';

  @override
  String get start_a_radio => 'ãƒ©ã‚¸ã‚ªã‚’é–‹å§‹';

  @override
  String get how_to_start_radio =>
      'ãƒ©ã‚¸ã‚ªã‚’ã©ã®ã‚ˆã†ã«é–‹å§‹ã—ã¾ã™ã‹ï¼Ÿ';

  @override
  String get replace_queue_question =>
      'ç¾åœ¨ã®ã‚­ãƒ¥ãƒ¼ã‚’ç½®ãæ›ãˆã‚‹ã‹ã€è¿½åŠ ã—ã¾ã™ã‹ï¼Ÿ';

  @override
  String get endless_playback => 'ã‚¨ãƒ³ãƒ‰ãƒ¬ã‚¹å†ç”Ÿ';

  @override
  String get delete_playlist => 'å†ç”Ÿãƒªã‚¹ãƒˆã‚’å‰Šé™¤';

  @override
  String get delete_playlist_confirmation =>
      'ã“ã®å†ç”Ÿãƒªã‚¹ãƒˆã‚’å‰Šé™¤ã—ã¾ã™ã‹ï¼Ÿ';

  @override
  String get local_tracks => 'ç«¯æœ«å†…ã®æ›²';

  @override
  String get local_tab => 'ç«¯æœ«å†…';

  @override
  String get song_link => 'æ›²ã®ãƒªãƒ³ã‚¯';

  @override
  String get skip_this_nonsense => 'ã“ã‚“ãªã“ã¨ã¯ã‚¹ã‚­ãƒƒãƒ—';

  @override
  String get freedom_of_music => 'â€œéŸ³æ¥½ã®è‡ªç”±â€';

  @override
  String get freedom_of_music_palm =>
      'â€œéŸ³æ¥½ã®è‡ªç”±ã‚’æ€ã„ã®ã¾ã¾ã«â€';

  @override
  String get get_started => 'ã•ã‚å§‹ã‚ã¾ã—ã‚‡ã†';

  @override
  String get youtube_source_description =>
      'æŽ¨å¥¨ã•ã‚Œã€æœ€é©ã«æ©Ÿèƒ½ã—ã¾ã™ã€‚';

  @override
  String get piped_source_description =>
      'è‡ªç”±ã‚’æ„Ÿã˜ã‚‹ï¼ŸYouTubeã¨åŒã˜ã ã‘ã©ã€ã¯ã‚‹ã‹ã«è‡ªç”±ã§ã™ã€‚';

  @override
  String get jiosaavn_source_description =>
      'å—ã‚¢ã‚¸ã‚¢åœ°åŸŸã§ã¯æœ€é©ã§ã™ã€‚';

  @override
  String get invidious_source_description =>
      'Pipedã«ä¼¼ã¦ã„ã¾ã™ãŒã€ã‚ˆã‚Šåˆ©ç”¨æ€§ãŒã‚ã‚Šã¾ã™ã€‚';

  @override
  String highest_quality(Object quality) {
    return 'æœ€é«˜å“è³ªï¼š$quality';
  }

  @override
  String get select_audio_source => 'éŸ³å£°ã®æä¾›å…ƒã‚’é¸æŠž';

  @override
  String get endless_playback_description =>
      'ã‚­ãƒ¥ãƒ¼ã®æœ€å¾Œã«æ–°ã—ã„æ›²ã‚’è‡ªå‹•ã§è¿½åŠ ';

  @override
  String get choose_your_region => 'åœ°åŸŸã‚’é¸æŠž';

  @override
  String get choose_your_region_description =>
      'Soulful BhaktiãŒã‚ãªãŸã®åœ°åŸŸã«é©ã—ãŸã‚³ãƒ³ãƒ†ãƒ³ãƒ„ã‚’è¡¨ç¤ºã—ã¾ã™ã€‚';

  @override
  String get choose_your_language => 'è¨€èªžã‚’é¸æŠžã—ã¦ãã ã•ã„';

  @override
  String get help_project_grow => 'ãƒ—ãƒ­ã‚¸ã‚§ã‚¯ãƒˆã®æˆé•·ã‚’æ”¯æ´ã™ã‚‹';

  @override
  String get help_project_grow_description =>
      'SpoTubeã¯ã‚ªãƒ¼ãƒ—ãƒ³ã‚½ãƒ¼ã‚¹ãƒ—ãƒ­ã‚¸ã‚§ã‚¯ãƒˆã§ã™ã€‚è²¢çŒ®ã—ãŸã‚Šã€ãƒã‚°å ±å‘Šã—ãŸã‚Šã€æ–°æ©Ÿèƒ½ã‚’ææ¡ˆã™ã‚‹ã“ã¨ã§ã€ãƒ—ãƒ­ã‚¸ã‚§ã‚¯ãƒˆã®æˆé•·ã«è²¢çŒ®ã§ãã¾ã™ã€‚';

  @override
  String get contribute_on_github => 'GitHubã§è²¢çŒ®';

  @override
  String get donate_on_open_collective => 'Open Collectiveã§å¯„ä»˜';

  @override
  String get browse_anonymously => 'åŒ¿åã§é–²è¦§ã™ã‚‹';

  @override
  String get enable_connect => 'æŽ¥ç¶šã™ã‚‹';

  @override
  String get enable_connect_description =>
      'ä»–ã®ç«¯æœ«ã‹ã‚‰Soulful Bhaktiã‚’åˆ¶å¾¡ã™ã‚‹';

  @override
  String get devices => 'æ©Ÿå™¨';

  @override
  String get select => 'é¸æŠž';

  @override
  String connect_client_alert(Object client) {
    return '$client ã‹ã‚‰æ“ä½œã•ã‚Œã¦ã„ã¾ã™';
  }

  @override
  String get this_device => 'ã“ã®ç«¯æœ«';

  @override
  String get remote => 'ãƒªãƒ¢ãƒ¼ãƒˆ';

  @override
  String get stats => 'çµ±è¨ˆ';

  @override
  String and_n_more(Object count) {
    return 'ã•ã‚‰ã« $count é …ç›®';
  }

  @override
  String get recently_played => 'æœ€è¿‘è´ã„ãŸæ›²';

  @override
  String get browse_more => 'ã‚‚ã£ã¨è¡¨ç¤º';

  @override
  String get no_title => 'ã‚¿ã‚¤ãƒˆãƒ«ãªã—';

  @override
  String get not_playing => 'å†ç”Ÿãªã—';

  @override
  String get epic_failure => 'å£®å¤§ãªã‚¨ãƒ©ãƒ¼ï¼';

  @override
  String added_num_tracks_to_queue(Object tracks_length) {
    return '$tracks_length æ›²ã‚’ã‚­ãƒ¥ãƒ¼ã«è¿½åŠ ã—ã¾ã—ãŸ';
  }

  @override
  String get spotube_has_an_update => 'Soulful Bhakti ã®æœ€æ–°ç‰ˆã‚ã‚Š';

  @override
  String get download_now => 'ä»Šã™ããƒ€ã‚¦ãƒ³ãƒ­ãƒ¼ãƒ‰';

  @override
  String nightly_version(Object nightlyBuildNum) {
    return 'Soulful Bhakti Nightly $nightlyBuildNum ãŒãƒªãƒªãƒ¼ã‚¹ã•ã‚Œã¾ã—ãŸ';
  }

  @override
  String release_version(Object version) {
    return 'Soulful Bhakti v$version ãŒãƒªãƒªãƒ¼ã‚¹ã•ã‚Œã¾ã—ãŸ';
  }

  @override
  String get read_the_latest => 'æœ€æ–°ã® ';

  @override
  String get release_notes => 'æ›´æ–°æƒ…å ±ã‚’èª­ã‚€';

  @override
  String get pick_color_scheme => 'ã‚«ãƒ©ãƒ¼ãƒ†ãƒ¼ãƒžã‚’é¸æŠž';

  @override
  String get save => 'ä¿å­˜';

  @override
  String get choose_the_device => 'ç«¯æœ«ã‚’é¸æŠžï¼š';

  @override
  String get multiple_device_connected =>
      'è¤‡æ•°ã®ç«¯æœ«ãŒæŽ¥ç¶šã•ã‚Œã¦ã„ã¾ã™ã€‚\nã“ã®æ“ä½œã‚’å®Ÿè¡Œã™ã‚‹ç«¯æœ«ã‚’é¸æŠž';

  @override
  String get nothing_found => 'ä½•ã‚‚è¦‹ã¤ã‹ã‚Šã¾ã›ã‚“ã§ã—ãŸ';

  @override
  String get the_box_is_empty => 'ãƒœãƒƒã‚¯ã‚¹ã¯ç©ºã§ã™';

  @override
  String get top_artists => 'ãƒˆãƒƒãƒ—ã‚¢ãƒ¼ãƒ†ã‚£ã‚¹ãƒˆ';

  @override
  String get top_albums => 'ãƒˆãƒƒãƒ—ã‚¢ãƒ«ãƒãƒ ';

  @override
  String get this_week => 'ä»Šé€±';

  @override
  String get this_month => 'ä»Šæœˆ';

  @override
  String get last_6_months => 'éŽåŽ»6ã‹æœˆ';

  @override
  String get this_year => 'ä»Šå¹´';

  @override
  String get last_2_years => 'éŽåŽ»2å¹´é–“';

  @override
  String get all_time => 'å…¨æœŸé–“';

  @override
  String powered_by_provider(Object providerName) {
    return '$providerName æä¾›';
  }

  @override
  String get email => 'ãƒ¡ãƒ¼ãƒ«';

  @override
  String get send_code => 'ã‚³ãƒ¼ãƒ‰ã‚’é€ä¿¡';

  @override
  String get change_identifier => 'åˆ¥ã®ãƒ¡ãƒ¼ãƒ«ã‚¢ãƒ‰ãƒ¬ã‚¹ã‚’ä½¿ç”¨';

  @override
  String get sign_in_with_otp => 'ãƒ¯ãƒ³ã‚¿ã‚¤ãƒ ã‚³ãƒ¼ãƒ‰ã§ãƒ­ã‚°ã‚¤ãƒ³';

  @override
  String get enter_otp_sent =>
      'ãŠé€ã‚Šã—ãŸã‚³ãƒ¼ãƒ‰ã‚’å…¥åŠ›ã—ã¦ãã ã•ã„';

  @override
  String get verify_email_reminder =>
      'ã‚¢ã‚«ã‚¦ãƒ³ãƒˆã‚’ä¿è­·ã™ã‚‹ãŸã‚ã€ãƒ¡ãƒ¼ãƒ«ã‚¢ãƒ‰ãƒ¬ã‚¹ã‚’ç¢ºèªã—ã¦ãã ã•ã„';

  @override
  String get verify_now => 'ä»Šã™ãç¢ºèª';

  @override
  String get enter_email_to_verify =>
      'ç¢ºèªã‚³ãƒ¼ãƒ‰ã‚’å—ã‘å–ã‚‹ã«ã¯ãƒ¡ãƒ¼ãƒ«ã‚¢ãƒ‰ãƒ¬ã‚¹ã‚’å…¥åŠ›ã—ã¦ãã ã•ã„';

  @override
  String get profile_followers => 'ãƒ•ã‚©ãƒ­ãƒ¯ãƒ¼';

  @override
  String get birthday => 'èª•ç”Ÿæ—¥';

  @override
  String get subscription => 'ç™»éŒ²';

  @override
  String get not_born => 'æœªå‡ºç”Ÿ';

  @override
  String get hacker => 'ãƒãƒƒã‚«ãƒ¼';

  @override
  String get profile => 'ãƒ—ãƒ­ãƒ•ã‚£ãƒ¼ãƒ«';

  @override
  String get no_name => 'åå‰ãªã—';

  @override
  String get edit => 'ç·¨é›†';

  @override
  String get user_profile => 'ãƒ¦ãƒ¼ã‚¶ãƒ¼ãƒ—ãƒ­ãƒ•ã‚£ãƒ¼ãƒ«';

  @override
  String count_plays(Object count) {
    return '$count å›žå†ç”Ÿ';
  }

  @override
  String get streaming_fees_hypothetical =>
      'ã‚¹ãƒˆãƒªãƒ¼ãƒŸãƒ³ã‚°æ–™é‡‘ (æ¦‚ç®—)';

  @override
  String get minutes_listened => 'è¦–è´æ™‚é–“';

  @override
  String get streamed_songs => 'ã‚¹ãƒˆãƒªãƒ¼ãƒŸãƒ³ã‚°ã•ã‚ŒãŸæ›²';

  @override
  String count_streams(Object count) {
    return '$count å›žã®ã‚¹ãƒˆãƒªãƒ¼ãƒ ';
  }

  @override
  String get owned_by_you => 'ã‚ãªãŸãŒæ‰€æœ‰';

  @override
  String copied_shareurl_to_clipboard(Object shareUrl) {
    return '$shareUrl ã‚’ã‚¯ãƒªãƒƒãƒ—ãƒœãƒ¼ãƒ‰ã«ã‚³ãƒ”ãƒ¼ã—ã¾ã—ãŸ';
  }

  @override
  String get hipotetical_calculation =>
      '*ã“ã‚Œã¯ã€ã‚ªãƒ³ãƒ©ã‚¤ãƒ³éŸ³æ¥½ã‚¹ãƒˆãƒªãƒ¼ãƒŸãƒ³ã‚°ãƒ—ãƒ©ãƒƒãƒˆãƒ•ã‚©ãƒ¼ãƒ ã®1ã‚¹ãƒˆãƒªãƒ¼ãƒ ã‚ãŸã‚Šã®å¹³å‡æ”¯æ‰•ã„é¡ã§ã‚ã‚‹\$0.003ã€œ\$0.005ã«åŸºã¥ã„ã¦è¨ˆç®—ã•ã‚Œã¦ã„ã¾ã™ã€‚ã“ã‚Œã¯ã€ãƒ¦ãƒ¼ã‚¶ãƒ¼ãŒç•°ãªã‚‹éŸ³æ¥½ã‚¹ãƒˆãƒªãƒ¼ãƒŸãƒ³ã‚°ãƒ—ãƒ©ãƒƒãƒˆãƒ•ã‚©ãƒ¼ãƒ ã§æ›²ã‚’è´ã„ãŸå ´åˆã«ã€ã‚¢ãƒ¼ãƒ†ã‚£ã‚¹ãƒˆã«ã©ã‚Œã ã‘æ”¯æ‰•ã£ãŸã‹ã‚’æŠŠæ¡ã™ã‚‹ãŸã‚ã®ä»®èª¬çš„ãªè¨ˆç®—ã§ã™ã€‚';

  @override
  String count_mins(Object minutes) {
    return '$minutes åˆ†';
  }

  @override
  String get summary_minutes => 'åˆ†';

  @override
  String get summary_listened_to_music => 'éŸ³æ¥½ã‚’è´ã„ãŸ';

  @override
  String get summary_songs => 'æ›²';

  @override
  String get summary_streamed_overall => 'ã¾ã‚‹ã”ã¨è´ã„ãŸ';

  @override
  String get summary_owed_to_artists =>
      'ä»Šæœˆã‚¢ãƒ¼ãƒ†ã‚£ã‚¹ãƒˆã«æ‰•ã†\nã¹ãé¡';

  @override
  String get summary_top_artist => 'ãƒˆãƒƒãƒ—ã‚¢ãƒ¼ãƒ†ã‚£ã‚¹ãƒˆ\nã“ã®æœŸé–“';

  @override
  String get summary_artists => 'ã‚¢ãƒ¼ãƒ†ã‚£ã‚¹ãƒˆ';

  @override
  String get summary_music_reached_you => 'ã®éŸ³æ¥½ãŒå±Šã„ãŸ';

  @override
  String get summary_full_albums => 'ãƒ•ãƒ«ã‚¢ãƒ«ãƒãƒ ';

  @override
  String get summary_got_your_love => 'ãŒã‚ãªãŸã®æ„›ã‚’å—ã‘å–ã£ãŸ';

  @override
  String get summary_playlists => 'å†ç”Ÿãƒªã‚¹ãƒˆ';

  @override
  String get summary_were_on_repeat => 'ã‚’ãƒªãƒ”ãƒ¼ãƒˆã—ã¾ã—ãŸ';

  @override
  String get summary_listening_share => 'å†ç”Ÿã‚·ã‚§ã‚¢';

  @override
  String summary_listening_share_description(Object tracks_length) {
    return 'æœ€ã‚‚å¤šãå†ç”Ÿã—ãŸä¸Šä½$tracks_lengthæ›²ã®åˆ†å¸ƒ';
  }

  @override
  String get summary_plays => 'å›žå†ç”Ÿ';

  @override
  String get insights => 'Insights';

  @override
  String get insights_top_track => 'Top track';

  @override
  String get insights_listening_hours => 'Hours listened';

  @override
  String get insights_best_day => 'Best day';

  @override
  String get insights_current_streak => 'Play streak';

  @override
  String get insights_vs_last_week => 'vs last week';

  @override
  String total_money(Object money) {
    return 'è¨ˆ $money';
  }

  @override
  String get webview_not_found => 'WebviewãŒè¦‹ã¤ã‹ã‚Šã¾ã›ã‚“';

  @override
  String get webview_not_found_description =>
      'ç«¯æœ«ã«Webviewãƒ©ãƒ³ã‚¿ã‚¤ãƒ ãŒã‚¤ãƒ³ã‚¹ãƒˆãƒ¼ãƒ«ã•ã‚Œã¦ã„ã¾ã›ã‚“ã€‚\nã‚¤ãƒ³ã‚¹ãƒˆãƒ¼ãƒ«ã•ã‚Œã¦ã„ã‚‹å ´åˆã¯ã€ç’°å¢ƒå¤‰æ•°ã®ãƒ‘ã‚¹ã«ã‚ã‚‹ã‹ç¢ºèªã—ã¦ãã ã•ã„\n\nã‚¤ãƒ³ã‚¹ãƒˆãƒ¼ãƒ«å¾Œã€ã‚¢ãƒ—ãƒªã‚’å†èµ·å‹•ã—ã¦ãã ã•ã„';

  @override
  String get unsupported_platform => 'æœªå¯¾å¿œã®ãƒ—ãƒ©ãƒƒãƒˆãƒ•ã‚©ãƒ¼ãƒ ';

  @override
  String get cache_music => 'éŸ³æ¥½ã‚’ã‚­ãƒ£ãƒƒã‚·ãƒ¥';

  @override
  String get open => 'é–‹ã';

  @override
  String get cache_folder => 'ã‚­ãƒ£ãƒƒã‚·ãƒ¥ãƒ•ã‚©ãƒ«ãƒ€ãƒ¼';

  @override
  String get export => 'ã‚¨ã‚¯ã‚¹ãƒãƒ¼ãƒˆ';

  @override
  String get clear_cache => 'ã‚­ãƒ£ãƒƒã‚·ãƒ¥ã‚’ã‚¯ãƒªã‚¢';

  @override
  String get clear_cache_confirmation =>
      'ã‚­ãƒ£ãƒƒã‚·ãƒ¥ã‚’ã‚¯ãƒªã‚¢ã—ã¾ã™ã‹ï¼Ÿ';

  @override
  String get export_cache_files =>
      'ã‚­ãƒ£ãƒƒã‚·ãƒ¥ã•ã‚ŒãŸãƒ•ã‚¡ã‚¤ãƒ«ã‚’ã‚¨ã‚¯ã‚¹ãƒãƒ¼ãƒˆ';

  @override
  String found_n_files(Object count) {
    return '$countãƒ•ã‚¡ã‚¤ãƒ«ãŒè¦‹ã¤ã‹ã‚Šã¾ã—ãŸ';
  }

  @override
  String get export_cache_confirmation =>
      'ã“ã‚Œã‚‰ã®ãƒ•ã‚¡ã‚¤ãƒ«ã‚’ã‚¨ã‚¯ã‚¹ãƒãƒ¼ãƒˆã—ã¾ã™ã‹';

  @override
  String exported_n_out_of_m_files(Object files, Object filesExported) {
    return '$filesExported / $filesãƒ•ã‚¡ã‚¤ãƒ«ãŒã‚¨ã‚¯ã‚¹ãƒãƒ¼ãƒˆã•ã‚Œã¾ã—ãŸ';
  }

  @override
  String get undo => 'å…ƒã«æˆ»ã™';

  @override
  String get add_all_to_playlist => 'ã™ã¹ã¦å†ç”Ÿãƒªã‚¹ãƒˆã«è¿½åŠ ';

  @override
  String get add_all_to_queue => 'ã™ã¹ã¦ã‚­ãƒ¥ãƒ¼ã«è¿½åŠ ';

  @override
  String get play_all_next => 'ã™ã¹ã¦ã‚’æ¬¡ã«å†ç”Ÿ';

  @override
  String get pause => 'ä¸€æ™‚åœæ­¢';

  @override
  String get view_all => 'ã™ã¹ã¦è¡¨ç¤º';

  @override
  String get no_tracks_added_yet =>
      'ã¾ã æ›²ã‚’è¿½åŠ ã—ã¦ã„ãªã„ã‚ˆã†ã§ã™';

  @override
  String get no_tracks => 'ã“ã“ã«ã¯æ›²ãŒãªã„ã‚ˆã†ã§ã™';

  @override
  String get no_tracks_listened_yet =>
      'ã¾ã ä½•ã‚‚èžã„ã¦ã„ãªã„ã‚ˆã†ã§ã™';

  @override
  String get not_following_artists =>
      'ã‚¢ãƒ¼ãƒ†ã‚£ã‚¹ãƒˆã‚’ãƒ•ã‚©ãƒ­ãƒ¼ã—ã¦ã„ã¾ã›ã‚“';

  @override
  String get no_favorite_albums_yet =>
      'ã¾ã ãŠæ°—ã«å…¥ã‚Šã®ã‚¢ãƒ«ãƒãƒ ã‚’è¿½åŠ ã—ã¦ã„ãªã„ã‚ˆã†ã§ã™';

  @override
  String get no_logs_found => 'ãƒ­ã‚°ãªã—';

  @override
  String get youtube_engine => 'YouTubeã‚¨ãƒ³ã‚¸ãƒ³';

  @override
  String youtube_engine_not_installed_title(Object engine) {
    return '$engineã¯ã‚¤ãƒ³ã‚¹ãƒˆãƒ¼ãƒ«ã•ã‚Œã¦ã„ã¾ã›ã‚“';
  }

  @override
  String youtube_engine_not_installed_message(Object engine) {
    return '$engineã¯ã‚·ã‚¹ãƒ†ãƒ ã«ã‚¤ãƒ³ã‚¹ãƒˆãƒ¼ãƒ«ã•ã‚Œã¦ã„ã¾ã›ã‚“ã€‚';
  }

  @override
  String youtube_engine_set_path(Object engine) {
    return 'PATHå¤‰æ•°ã«è¨­å®šã•ã‚Œã¦ã„ã‚‹ã“ã¨ã‚’ç¢ºèªã™ã‚‹ã‹\n$engineå®Ÿè¡Œãƒ•ã‚¡ã‚¤ãƒ«ã®çµ¶å¯¾ãƒ‘ã‚¹ã‚’ä¸‹è¨˜ã«è¨­å®šã—ã¦ãã ã•ã„';
  }

  @override
  String get youtube_engine_unix_issue_message =>
      'macOS/Linux/Unixç³»OSã§ã¯ã€.zshrc/.bashrc/.bash_profileãªã©ã§ãƒ‘ã‚¹ã‚’è¨­å®šã—ã¦ã‚‚å‹•ä½œã—ã¾ã›ã‚“ã€‚\nã‚·ã‚§ãƒ«ã®è¨­å®šãƒ•ã‚¡ã‚¤ãƒ«ã«ãƒ‘ã‚¹ã‚’è¨­å®šã™ã‚‹å¿…è¦ãŒã‚ã‚Šã¾ã™';

  @override
  String get download => 'ãƒ€ã‚¦ãƒ³ãƒ­ãƒ¼ãƒ‰';

  @override
  String get file_not_found => 'ãƒ•ã‚¡ã‚¤ãƒ«ãŒè¦‹ã¤ã‹ã‚Šã¾ã›ã‚“';

  @override
  String get custom => 'ç‹¬è‡ª';

  @override
  String get add_custom_url => 'ç‹¬è‡ªã«URLã‚’è¿½åŠ ';

  @override
  String get edit_port => 'ãƒãƒ¼ãƒˆã‚’ç·¨é›†';

  @override
  String get port_helper_msg =>
      'åˆæœŸè¨­å®šã¯-1ã§ã€ãƒ©ãƒ³ãƒ€ãƒ ãªç•ªå·ã‚’ç¤ºã—ã¾ã™ã€‚ãƒ•ã‚¡ã‚¤ã‚¢ã‚¦ã‚©ãƒ¼ãƒ«ã‚’è¨­å®šã—ã¦ã„ã‚‹å ´åˆã«è¨­å®šã™ã‚‹ã“ã¨ã‚’æŽ¨å¥¨ã—ã¾ã™ã€‚';

  @override
  String connect_request(Object client) {
    return '$clientã®æŽ¥ç¶šã‚’è¨±å¯ã—ã¾ã™ã‹ï¼Ÿ';
  }

  @override
  String get connection_request_denied =>
      'æŽ¥ç¶šãŒæ‹’å¦ã•ã‚Œã¾ã—ãŸã€‚ãƒ¦ãƒ¼ã‚¶ãƒ¼ãŒã‚¢ã‚¯ã‚»ã‚¹ã‚’æ‹’å¦ã—ã¾ã—ãŸã€‚';

  @override
  String get an_error_occurred => 'ã‚¨ãƒ©ãƒ¼ãŒç™ºç”Ÿã—ã¾ã—ãŸ';

  @override
  String get copy_to_clipboard => 'ã‚¯ãƒªãƒƒãƒ—ãƒœãƒ¼ãƒ‰ã«ã‚³ãƒ”ãƒ¼';

  @override
  String get view_logs => 'ãƒ­ã‚°ã‚’è¡¨ç¤º';

  @override
  String get retry => 'å†è©¦è¡Œ';

  @override
  String get no_default_metadata_provider_selected =>
      'ãƒ‡ãƒ•ã‚©ãƒ«ãƒˆã®ãƒ¡ã‚¿ãƒ‡ãƒ¼ã‚¿ãƒ—ãƒ­ãƒã‚¤ãƒ€ãƒ¼ãŒè¨­å®šã•ã‚Œã¦ã„ã¾ã›ã‚“';

  @override
  String get manage_metadata_providers =>
      'ãƒ¡ã‚¿ãƒ‡ãƒ¼ã‚¿ãƒ—ãƒ­ãƒã‚¤ãƒ€ãƒ¼ã‚’ç®¡ç†';

  @override
  String get open_link_in_browser =>
      'ãƒªãƒ³ã‚¯ã‚’ãƒ–ãƒ©ã‚¦ã‚¶ã§é–‹ãã¾ã™ã‹ï¼Ÿ';

  @override
  String get do_you_want_to_open_the_following_link =>
      'æ¬¡ã®ãƒªãƒ³ã‚¯ã‚’é–‹ãã¾ã™ã‹';

  @override
  String get unsafe_url_warning =>
      'ä¿¡é ¼ã§ããªã„ã‚½ãƒ¼ã‚¹ã‹ã‚‰ã®ãƒªãƒ³ã‚¯ã‚’é–‹ãã®ã¯å®‰å…¨ã§ã¯ãªã„å ´åˆãŒã‚ã‚Šã¾ã™ã€‚æ³¨æ„ã—ã¦ãã ã•ã„ï¼\nãƒªãƒ³ã‚¯ã‚’ã‚¯ãƒªãƒƒãƒ—ãƒœãƒ¼ãƒ‰ã«ã‚³ãƒ”ãƒ¼ã™ã‚‹ã“ã¨ã‚‚ã§ãã¾ã™ã€‚';

  @override
  String get copy_link => 'ãƒªãƒ³ã‚¯ã‚’ã‚³ãƒ”ãƒ¼';

  @override
  String get building_your_timeline =>
      'ã‚ãªãŸã®è¦–è´å±¥æ­´ã«åŸºã¥ã„ã¦ã‚¿ã‚¤ãƒ ãƒ©ã‚¤ãƒ³ã‚’ä½œæˆã—ã¦ã„ã¾ã™...';

  @override
  String get official => 'å…¬å¼';

  @override
  String author_name(Object author) {
    return 'ä½œè€…: $author';
  }

  @override
  String get third_party => 'ã‚µãƒ¼ãƒ‰ãƒ‘ãƒ¼ãƒ†ã‚£';

  @override
  String get plugin_requires_authentication =>
      'ãƒ—ãƒ©ã‚°ã‚¤ãƒ³ã«ã¯èªè¨¼ãŒå¿…è¦ã§ã™';

  @override
  String get update_available => 'ã‚¢ãƒƒãƒ—ãƒ‡ãƒ¼ãƒˆãŒåˆ©ç”¨å¯èƒ½ã§ã™';

  @override
  String get supports_scrobbling => 'scrobblingã«å¯¾å¿œ';

  @override
  String get plugin_scrobbling_info =>
      'ã“ã®ãƒ—ãƒ©ã‚°ã‚¤ãƒ³ã¯ã€ã‚ãªãŸã®éŸ³æ¥½ã‚’scrobbleã—ã¦è¦–è´å±¥æ­´ã‚’ç”Ÿæˆã—ã¾ã™ã€‚';

  @override
  String get default_metadata_source =>
      'ãƒ‡ãƒ•ã‚©ãƒ«ãƒˆãƒ¡ã‚¿ãƒ‡ãƒ¼ã‚¿ã‚½ãƒ¼ã‚¹';

  @override
  String get set_default_metadata_source =>
      'ãƒ‡ãƒ•ã‚©ãƒ«ãƒˆãƒ¡ã‚¿ãƒ‡ãƒ¼ã‚¿ã‚½ãƒ¼ã‚¹ã‚’è¨­å®š';

  @override
  String get default_audio_source => 'ãƒ‡ãƒ•ã‚©ãƒ«ãƒˆã‚ªãƒ¼ãƒ‡ã‚£ã‚ªã‚½ãƒ¼ã‚¹';

  @override
  String get set_default_audio_source =>
      'ãƒ‡ãƒ•ã‚©ãƒ«ãƒˆã‚ªãƒ¼ãƒ‡ã‚£ã‚ªã‚½ãƒ¼ã‚¹ã‚’è¨­å®š';

  @override
  String get set_default => 'ãƒ‡ãƒ•ã‚©ãƒ«ãƒˆã«è¨­å®š';

  @override
  String get support => 'ã‚µãƒãƒ¼ãƒˆ';

  @override
  String get support_plugin_development =>
      'ãƒ—ãƒ©ã‚°ã‚¤ãƒ³é–‹ç™ºã‚’ã‚µãƒãƒ¼ãƒˆ';

  @override
  String can_access_name_api(Object name) {
    return '- **$name** APIã«ã‚¢ã‚¯ã‚»ã‚¹ã§ãã¾ã™';
  }

  @override
  String get do_you_want_to_install_this_plugin =>
      'ã“ã®ãƒ—ãƒ©ã‚°ã‚¤ãƒ³ã‚’ã‚¤ãƒ³ã‚¹ãƒˆãƒ¼ãƒ«ã—ã¾ã™ã‹ï¼Ÿ';

  @override
  String get third_party_plugin_warning =>
      'ã“ã®ãƒ—ãƒ©ã‚°ã‚¤ãƒ³ã¯ã‚µãƒ¼ãƒ‰ãƒ‘ãƒ¼ãƒ†ã‚£ã®ãƒªãƒã‚¸ãƒˆãƒªã‹ã‚‰ã®ã‚‚ã®ã§ã™ã€‚ã‚¤ãƒ³ã‚¹ãƒˆãƒ¼ãƒ«ã™ã‚‹å‰ã«ã‚½ãƒ¼ã‚¹ã‚’ä¿¡é ¼ã§ãã‚‹ã‹ç¢ºèªã—ã¦ãã ã•ã„ã€‚';

  @override
  String get author => 'ä½œè€…';

  @override
  String get this_plugin_can_do_following =>
      'ã“ã®ãƒ—ãƒ©ã‚°ã‚¤ãƒ³ã¯ä»¥ä¸‹ã®ã“ã¨ãŒã§ãã¾ã™';

  @override
  String get install => 'ã‚¤ãƒ³ã‚¹ãƒˆãƒ¼ãƒ«';

  @override
  String get install_a_metadata_provider =>
      'ãƒ¡ã‚¿ãƒ‡ãƒ¼ã‚¿ãƒ—ãƒ­ãƒã‚¤ãƒ€ãƒ¼ã‚’ã‚¤ãƒ³ã‚¹ãƒˆãƒ¼ãƒ«';

  @override
  String get no_tracks_playing =>
      'ç¾åœ¨å†ç”Ÿä¸­ã®ãƒˆãƒ©ãƒƒã‚¯ã¯ã‚ã‚Šã¾ã›ã‚“';

  @override
  String get synced_lyrics_not_available =>
      'ã“ã®æ›²ã®åŒæœŸæ­Œè©žã¯åˆ©ç”¨ã§ãã¾ã›ã‚“ã€‚ä»£ã‚ã‚Šã«';

  @override
  String get plain_lyrics => 'ã‚·ãƒ³ãƒ—ãƒ«ãªæ­Œè©ž';

  @override
  String get tab_instead => 'ã‚¿ãƒ–ã‚’ä½¿ç”¨ã—ã¦ãã ã•ã„ã€‚';

  @override
  String get disclaimer => 'å…è²¬äº‹é …';

  @override
  String get third_party_plugin_dmca_notice =>
      'Soulful Bhaktiãƒãƒ¼ãƒ ã¯ã€ã„ã‹ãªã‚‹ã€Œã‚µãƒ¼ãƒ‰ãƒ‘ãƒ¼ãƒ†ã‚£ã€ãƒ—ãƒ©ã‚°ã‚¤ãƒ³ã«ã¤ã„ã¦ã‚‚è²¬ä»»ï¼ˆæ³•çš„è²¬ä»»ã‚’å«ã‚€ï¼‰ã‚’è² ã„ã¾ã›ã‚“ã€‚\nã”è‡ªèº«ã®è²¬ä»»ã§ã”ä½¿ç”¨ãã ã•ã„ã€‚ãƒã‚°ã‚„å•é¡Œã«ã¤ã„ã¦ã¯ã€ãƒ—ãƒ©ã‚°ã‚¤ãƒ³ãƒªãƒã‚¸ãƒˆãƒªã«å ±å‘Šã—ã¦ãã ã•ã„ã€‚\n\nã€Œã‚µãƒ¼ãƒ‰ãƒ‘ãƒ¼ãƒ†ã‚£ã€ãƒ—ãƒ©ã‚°ã‚¤ãƒ³ãŒä½•ã‚‰ã‹ã®ã‚µãƒ¼ãƒ“ã‚¹/æ³•äººã®ToS/DMCAã‚’ä¾µå®³ã—ã¦ã„ã‚‹å ´åˆã€ãã®ã€Œã‚µãƒ¼ãƒ‰ãƒ‘ãƒ¼ãƒ†ã‚£ã€ãƒ—ãƒ©ã‚°ã‚¤ãƒ³ã®ä½œè€…ã¾ãŸã¯ãƒ›ã‚¹ãƒ†ã‚£ãƒ³ã‚°ãƒ—ãƒ©ãƒƒãƒˆãƒ•ã‚©ãƒ¼ãƒ ï¼ˆä¾‹ï¼šGitHub/Codebergï¼‰ã«æŽªç½®ã‚’è¬›ã˜ã‚‹ã‚ˆã†ä¾é ¼ã—ã¦ãã ã•ã„ã€‚ä¸Šè¨˜ã«è¨˜è¼‰ã•ã‚Œã¦ã„ã‚‹ï¼ˆã€Œã‚µãƒ¼ãƒ‰ãƒ‘ãƒ¼ãƒ†ã‚£ã€ã¨ãƒ©ãƒ™ãƒ«ä»˜ã‘ã•ã‚ŒãŸï¼‰ã‚‚ã®ã¯ã™ã¹ã¦ã€ãƒ‘ãƒ–ãƒªãƒƒã‚¯/ã‚³ãƒŸãƒ¥ãƒ‹ãƒ†ã‚£ã«ã‚ˆã£ã¦ç¶­æŒã•ã‚Œã¦ã„ã‚‹ãƒ—ãƒ©ã‚°ã‚¤ãƒ³ã§ã™ã€‚ç§ãŸã¡ã¯ãã‚Œã‚‰ã‚’ã‚­ãƒ¥ãƒ¬ãƒ¼ã‚·ãƒ§ãƒ³ã—ã¦ã„ãªã„ãŸã‚ã€ãã‚Œã‚‰ã«å¯¾ã—ã¦æŽªç½®ã‚’è¬›ã˜ã‚‹ã“ã¨ã¯ã§ãã¾ã›ã‚“ã€‚\n\n';

  @override
  String get input_does_not_match_format =>
      'å…¥åŠ›ãŒå¿…é ˆãƒ•ã‚©ãƒ¼ãƒžãƒƒãƒˆã¨ä¸€è‡´ã—ã¾ã›ã‚“';

  @override
  String get plugins => 'ãƒ—ãƒ©ã‚°ã‚¤ãƒ³';

  @override
  String get paste_plugin_download_url =>
      'ãƒ€ã‚¦ãƒ³ãƒ­ãƒ¼ãƒ‰URLã€GitHub/Codebergãƒªãƒã‚¸ãƒˆãƒªURLã€ã¾ãŸã¯.smplugãƒ•ã‚¡ã‚¤ãƒ«ã¸ã®ç›´æŽ¥ãƒªãƒ³ã‚¯ã‚’è²¼ã‚Šä»˜ã‘ã¾ã™';

  @override
  String get download_and_install_plugin_from_url =>
      'URLã‹ã‚‰ãƒ—ãƒ©ã‚°ã‚¤ãƒ³ã‚’ãƒ€ã‚¦ãƒ³ãƒ­ãƒ¼ãƒ‰ã—ã¦ã‚¤ãƒ³ã‚¹ãƒˆãƒ¼ãƒ«';

  @override
  String failed_to_add_plugin_error(Object error) {
    return 'ãƒ—ãƒ©ã‚°ã‚¤ãƒ³ã®è¿½åŠ ã«å¤±æ•—ã—ã¾ã—ãŸ: $error';
  }

  @override
  String get upload_plugin_from_file =>
      'ãƒ•ã‚¡ã‚¤ãƒ«ã‹ã‚‰ãƒ—ãƒ©ã‚°ã‚¤ãƒ³ã‚’ã‚¢ãƒƒãƒ—ãƒ­ãƒ¼ãƒ‰';

  @override
  String get installed => 'ã‚¤ãƒ³ã‚¹ãƒˆãƒ¼ãƒ«æ¸ˆã¿';

  @override
  String get available_plugins => 'åˆ©ç”¨å¯èƒ½ãªãƒ—ãƒ©ã‚°ã‚¤ãƒ³';

  @override
  String get configure_plugins =>
      'ç‹¬è‡ªã®ãƒ¡ã‚¿ãƒ‡ãƒ¼ã‚¿ãƒ—ãƒ­ãƒã‚¤ãƒ€ãƒ¼ã¨ã‚ªãƒ¼ãƒ‡ã‚£ã‚ªã‚½ãƒ¼ã‚¹ãƒ—ãƒ©ã‚°ã‚¤ãƒ³ã‚’è¨­å®š';

  @override
  String get source => 'ã‚½ãƒ¼ã‚¹: ';

  @override
  String get uncompressed => 'éžåœ§ç¸®';

  @override
  String get dab_music_source_description =>
      'ã‚ªãƒ¼ãƒ‡ã‚£ã‚ªãƒ•ã‚¡ã‚¤ãƒ«å‘ã‘ã€‚é«˜å“è³ª/ãƒ­ã‚¹ãƒ¬ã‚¹ã‚ªãƒ¼ãƒ‡ã‚£ã‚ªã‚¹ãƒˆãƒªãƒ¼ãƒ ã‚’æä¾›ã€‚æ­£ç¢ºãªISRCãƒ™ãƒ¼ã‚¹ã®ãƒˆãƒ©ãƒƒã‚¯ãƒžãƒƒãƒãƒ³ã‚°ã€‚';

  @override
  String get summary_top_track => 'ãƒˆãƒƒãƒ—æ›²\nã“ã®æœŸé–“';

  @override
  String get local => 'ãƒ­ãƒ¼ã‚«ãƒ«';

  @override
  String get set_as_ringtone => 'Set as ringtone';

  @override
  String get ringtone_set => 'Ringtone set';

  @override
  String get ringtone_failed => 'Could not set ringtone';

  @override
  String get specials => 'Specials';

  @override
  String get featured_playlist => 'おすすめプレイリスト';

  @override
  String get play_now => 'Play Now';

  @override
  String songs_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$_temp0';
  }
}
