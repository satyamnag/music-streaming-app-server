// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get guest => 'Ð“Ñ–ÑÑ‚ÑŒ';

  @override
  String get browse => 'ÐžÐ³Ð»ÑÐ´';

  @override
  String get search => 'ÐŸÐ¾ÑˆÑƒÐº';

  @override
  String get library => 'ÐœÐµÐ´Ñ–Ð°Ñ‚ÐµÐºÐ°';

  @override
  String get lyrics => 'Ð¢ÐµÐºÑÑ‚Ð¸ Ð¿Ñ–ÑÐµÐ½ÑŒ';

  @override
  String get settings => 'ÐÐ°Ð»Ð°ÑˆÑ‚ÑƒÐ²Ð°Ð½Ð½Ñ';

  @override
  String get settings_subtitle =>
      'ÐÐ°Ð»Ð°ÑˆÑ‚ÑƒÐ¹Ñ‚Ðµ Soulful Bhakti Ð½Ð° ÑÐ²Ñ–Ð¹ ÑÐ¼Ð°Ðº';

  @override
  String get genre_categories_filter =>
      'Ð¤Ñ–Ð»ÑŒÑ‚Ñ€ÑƒÐ²Ð°Ñ‚Ð¸ ÐºÐ°Ñ‚ÐµÐ³Ð¾Ñ€Ñ–Ñ— Ð°Ð±Ð¾ Ð¶Ð°Ð½Ñ€Ð¸...';

  @override
  String get genre => 'Ð–Ð°Ð½Ñ€';

  @override
  String get personalized => 'ÐŸÐµÑ€ÑÐ¾Ð½Ð°Ð»Ñ–Ð·Ð¾Ð²Ð°Ð½Ñ–';

  @override
  String get featured => 'Ð ÐµÐºÐ¾Ð¼ÐµÐ½Ð´Ð¾Ð²Ð°Ð½Ñ–';

  @override
  String get new_releases => 'ÐÐ¾Ð²Ñ– Ñ€ÐµÐ»Ñ–Ð·Ð¸';

  @override
  String get songs => 'ÐŸÑ–ÑÐ½Ñ–';

  @override
  String get newest_arrivals => 'ÐÐ¾Ð²Ð¸Ð½ÐºÐ¸';

  @override
  String get top_trending => 'Ð£ Ñ‚Ñ€ÐµÐ½Ð´Ñ–';

  @override
  String get see_more => 'ÐŸÐ¾ÐºÐ°Ð·Ð°Ñ‚Ð¸ Ð±Ñ–Ð»ÑŒÑˆÐµ';

  @override
  String playing_track(Object track) {
    return 'Ð’Ñ–Ð´Ñ‚Ð²Ð¾Ñ€ÑŽÑ”Ñ‚ÑŒÑÑ $track';
  }

  @override
  String queue_clear_alert(Object track_length) {
    return 'Ð¦Ðµ Ð¾Ñ‡Ð¸ÑÑ‚Ð¸Ñ‚ÑŒ Ð¿Ð¾Ñ‚Ð¾Ñ‡Ð½Ñƒ Ñ‡ÐµÑ€Ð³Ñƒ. Ð‘ÑƒÐ´Ðµ Ð²Ð¸Ð´Ð°Ð»ÐµÐ½Ð¾ $track_length Ñ‚Ñ€ÐµÐºÑ–Ð²\nÐŸÑ€Ð¾Ð´Ð¾Ð²Ð¶Ð¸Ñ‚Ð¸?';
  }

  @override
  String get load_more => 'Ð—Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶Ð¸Ñ‚Ð¸ Ð±Ñ–Ð»ÑŒÑˆÐµ';

  @override
  String get playlists => 'ÐŸÐ»ÐµÐ¹Ð»Ð¸ÑÑ‚Ð¸';

  @override
  String get artists => 'Ð’Ð¸ÐºÐ¾Ð½Ð°Ð²Ñ†Ñ–';

  @override
  String get albums => 'ÐÐ»ÑŒÐ±Ð¾Ð¼Ð¸';

  @override
  String get tracks => 'Ð¢Ñ€ÐµÐºÐ¸';

  @override
  String get downloads => 'Ð—Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶ÐµÐ½Ð½Ñ';

  @override
  String get filter_playlists => 'Ð¤Ñ–Ð»ÑŒÑ‚Ñ€ÑƒÐ²Ð°Ñ‚Ð¸ Ð¿Ð»ÐµÐ¹Ð»Ð¸ÑÑ‚Ð¸...';

  @override
  String get liked_tracks => 'Ð¡Ð¿Ð¾Ð´Ð¾Ð±Ð°Ð»Ð¸ÑÑ Ñ‚Ñ€ÐµÐºÐ¸';

  @override
  String get liked_tracks_description =>
      'Ð£ÑÑ– Ð²Ð°ÑˆÑ– ÑÐ¿Ð¾Ð´Ð¾Ð±Ð°Ð»Ð¸ÑÑ Ñ‚Ñ€ÐµÐºÐ¸';

  @override
  String get playlist => 'ÐŸÐ»ÐµÐ¹Ð»Ð¸ÑÑ‚';

  @override
  String get create_a_playlist => 'Ð¡Ñ‚Ð²Ð¾Ñ€Ð¸Ñ‚Ð¸ Ð¿Ð»ÐµÐ¹Ð»Ð¸ÑÑ‚';

  @override
  String get new_playlist => 'ÐÐ¾Ð²Ð¸Ð¹ Ð¿Ð»ÐµÐ¹Ð»Ð¸ÑÑ‚';

  @override
  String get playlist_name => 'ÐÐ°Ð·Ð²Ð° Ð¿Ð»ÐµÐ¹Ð»Ð¸ÑÑ‚Ð°';

  @override
  String get no_playlists_yet =>
      'ÐŸÐ»ÐµÐ¹Ð»Ð¸ÑÑ‚Ñ–Ð² Ð¿Ð¾ÐºÐ¸ Ð½ÐµÐ¼Ð°Ñ”. Ð¡Ñ‚Ð²Ð¾Ñ€Ñ–Ñ‚ÑŒ Ð¾Ð´Ð¸Ð½ Ñ–Ð· Ð²Ð¸Ð±Ñ€Ð°Ð½Ð¸Ñ… Ð¿Ñ–ÑÐµÐ½ÑŒ.';

  @override
  String get update_playlist => 'ÐžÐ½Ð¾Ð²Ð¸Ñ‚Ð¸ Ð¿Ð»ÐµÐ¹Ð»Ð¸ÑÑ‚';

  @override
  String get create => 'Ð¡Ñ‚Ð²Ð¾Ñ€Ð¸Ñ‚Ð¸';

  @override
  String get cancel => 'Ð¡ÐºÐ°ÑÑƒÐ²Ð°Ñ‚Ð¸';

  @override
  String get update => 'ÐžÐ½Ð¾Ð²Ð¸Ñ‚Ð¸';

  @override
  String get name_of_playlist => 'ÐÐ°Ð·Ð²Ð° Ð¿Ð»ÐµÐ¹Ð»Ð¸ÑÑ‚Ð°';

  @override
  String get description => 'ÐžÐ¿Ð¸Ñ';

  @override
  String get public => 'ÐŸÑƒÐ±Ð»Ñ–Ñ‡Ð½Ð¸Ð¹';

  @override
  String get collaborative => 'Ð¡Ð¿Ñ–Ð»ÑŒÐ½Ð¸Ð¹';

  @override
  String get search_local_tracks =>
      'ÐŸÐ¾ÑˆÑƒÐº Ð»Ð¾ÐºÐ°Ð»ÑŒÐ½Ð¸Ñ… Ñ‚Ñ€ÐµÐºÑ–Ð²...';

  @override
  String get play => 'Ð’Ñ–Ð´Ñ‚Ð²Ð¾Ñ€Ð¸Ñ‚Ð¸';

  @override
  String get delete => 'Ð’Ð¸Ð´Ð°Ð»Ð¸Ñ‚Ð¸';

  @override
  String get none => 'ÐÐµÐ¼Ð°Ñ”';

  @override
  String get sort_a_z => 'Ð¡Ð¾Ñ€Ñ‚ÑƒÐ²Ð°Ñ‚Ð¸ Ð·Ð° Ð°Ð»Ñ„Ð°Ð²Ñ–Ñ‚Ð¾Ð¼ A-Ð¯';

  @override
  String get sort_z_a => 'Ð¡Ð¾Ñ€Ñ‚ÑƒÐ²Ð°Ñ‚Ð¸ Ð·Ð° Ð°Ð»Ñ„Ð°Ð²Ñ–Ñ‚Ð¾Ð¼ Ð¯-Ð';

  @override
  String get sort_artist => 'Ð¡Ð¾Ñ€Ñ‚ÑƒÐ²Ð°Ñ‚Ð¸ Ð·Ð° Ð²Ð¸ÐºÐ¾Ð½Ð°Ð²Ñ†ÐµÐ¼';

  @override
  String get sort_album => 'Ð¡Ð¾Ñ€Ñ‚ÑƒÐ²Ð°Ñ‚Ð¸ Ð·Ð° Ð°Ð»ÑŒÐ±Ð¾Ð¼Ð¾Ð¼';

  @override
  String get sort_duration => 'Ð¡Ð¾Ñ€Ñ‚ÑƒÐ²Ð°Ñ‚Ð¸ Ð·Ð° Ñ‚Ñ€Ð¸Ð²Ð°Ð»Ñ–ÑÑ‚ÑŽ';

  @override
  String get sort_tracks => 'Ð¡Ð¾Ñ€Ñ‚ÑƒÐ²Ð°Ñ‚Ð¸ Ñ‚Ñ€ÐµÐºÐ¸';

  @override
  String currently_downloading(Object tracks_length) {
    return 'Ð—Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶ÑƒÑ”Ñ‚ÑŒÑÑ ($tracks_length)';
  }

  @override
  String get cancel_all => 'Ð¡ÐºÐ°ÑÑƒÐ²Ð°Ñ‚Ð¸ Ð²ÑÐµ';

  @override
  String get filter_artist => 'Ð¤Ñ–Ð»ÑŒÑ‚Ñ€ÑƒÐ²Ð°Ñ‚Ð¸ Ð²Ð¸ÐºÐ¾Ð½Ð°Ð²Ñ†Ñ–Ð²...';

  @override
  String followers(Object followers) {
    return '$followers Ð¿Ñ–Ð´Ð¿Ð¸ÑÐ½Ð¸ÐºÑ–Ð²';
  }

  @override
  String get add_artist_to_blacklist =>
      'Ð”Ð¾Ð´Ð°Ñ‚Ð¸ Ð²Ð¸ÐºÐ¾Ð½Ð°Ð²Ñ†Ñ Ð´Ð¾ Ñ‡Ð¾Ñ€Ð½Ð¾Ð³Ð¾ ÑÐ¿Ð¸ÑÐºÑƒ';

  @override
  String get top_tracks => 'Ð¢Ð¾Ð¿ Ñ‚Ñ€ÐµÐºÐ¸';

  @override
  String get fans_also_like =>
      'Ð¨Ð°Ð½ÑƒÐ²Ð°Ð»ÑŒÐ½Ð¸ÐºÐ°Ð¼ Ñ‚Ð°ÐºÐ¾Ð¶ Ð¿Ð¾Ð´Ð¾Ð±Ð°Ñ”Ñ‚ÑŒÑÑ';

  @override
  String get loading => 'Ð—Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶ÐµÐ½Ð½Ñ...';

  @override
  String get artist => 'Ð’Ð¸ÐºÐ¾Ð½Ð°Ð²ÐµÑ†ÑŒ';

  @override
  String get blacklisted => 'Ð£ Ñ‡Ð¾Ñ€Ð½Ð¾Ð¼Ñƒ ÑÐ¿Ð¸ÑÐºÑƒ';

  @override
  String get following => 'Ð¡Ñ‚ÐµÐ¶Ñƒ';

  @override
  String get follow => 'Ð¡Ñ‚ÐµÐ¶Ð¸Ñ‚Ð¸';

  @override
  String get artist_url_copied =>
      'URL Ð²Ð¸ÐºÐ¾Ð½Ð°Ð²Ñ†Ñ ÑÐºÐ¾Ð¿Ñ–Ð¹Ð¾Ð²Ð°Ð½Ð¾ Ð´Ð¾ Ð±ÑƒÑ„ÐµÑ€Ð° Ð¾Ð±Ð¼Ñ–Ð½Ñƒ';

  @override
  String added_to_queue(Object tracks) {
    return 'Ð”Ð¾Ð´Ð°Ð½Ð¾ $tracks Ñ‚Ñ€ÐµÐºÑ–Ð² Ð´Ð¾ Ñ‡ÐµÑ€Ð³Ð¸';
  }

  @override
  String get filter_albums => 'Ð¤Ñ–Ð»ÑŒÑ‚Ñ€ÑƒÐ²Ð°Ñ‚Ð¸ Ð°Ð»ÑŒÐ±Ð¾Ð¼Ð¸...';

  @override
  String get synced => 'Ð¡Ð¸Ð½Ñ…Ñ€Ð¾Ð½Ñ–Ð·Ð¾Ð²Ð°Ð½Ð¾';

  @override
  String get plain => 'Ð—Ð²Ð¸Ñ‡Ð°Ð¹Ð½Ð¸Ð¹';

  @override
  String get shuffle => 'Ð’Ð¸Ð¿Ð°Ð´ÐºÐ¾Ð²Ð¸Ð¹ Ð¿Ð¾Ñ€ÑÐ´Ð¾Ðº';

  @override
  String get search_tracks => 'ÐŸÐ¾ÑˆÑƒÐº Ñ‚Ñ€ÐµÐºÑ–Ð²...';

  @override
  String get released => 'Ð’Ð¸Ð¿ÑƒÑ‰ÐµÐ½Ð¾';

  @override
  String error(Object error) {
    return 'ÐŸÐ¾Ð¼Ð¸Ð»ÐºÐ° $error';
  }

  @override
  String get title => 'ÐÐ°Ð·Ð²Ð°';

  @override
  String get time => 'Ð§Ð°Ñ';

  @override
  String get more_actions => 'Ð‘Ñ–Ð»ÑŒÑˆÐµ Ð´Ñ–Ð¹';

  @override
  String add_count_to_playlist(Object count) {
    return 'Ð”Ð¾Ð´Ð°Ñ‚Ð¸ ($count) Ð´Ð¾ Ð¿Ð»ÐµÐ¹Ð»Ð¸ÑÑ‚Ð°';
  }

  @override
  String add_count_to_queue(Object count) {
    return 'Ð”Ð¾Ð´Ð°Ñ‚Ð¸ ($count) Ð´Ð¾ Ñ‡ÐµÑ€Ð³Ð¸';
  }

  @override
  String play_count_next(Object count) {
    return 'Ð’Ñ–Ð´Ñ‚Ð²Ð¾Ñ€Ð¸Ñ‚Ð¸ ($count) Ð½Ð°ÑÑ‚ÑƒÐ¿Ð½Ð¸Ð¼Ð¸';
  }

  @override
  String get album => 'ÐÐ»ÑŒÐ±Ð¾Ð¼';

  @override
  String copied_to_clipboard(Object data) {
    return 'Ð¡ÐºÐ¾Ð¿Ñ–Ð¹Ð¾Ð²Ð°Ð½Ð¾ $data Ð´Ð¾ Ð±ÑƒÑ„ÐµÑ€Ð° Ð¾Ð±Ð¼Ñ–Ð½Ñƒ';
  }

  @override
  String add_to_following_playlists(Object track) {
    return 'Ð”Ð¾Ð´Ð°Ñ‚Ð¸ $track Ð´Ð¾ Ð½Ð°ÑÑ‚ÑƒÐ¿Ð½Ð¸Ñ… Ð¿Ð»ÐµÐ¹Ð»Ð¸ÑÑ‚Ñ–Ð²';
  }

  @override
  String get add => 'Ð”Ð¾Ð´Ð°Ñ‚Ð¸';

  @override
  String added_track_to_queue(Object track) {
    return 'Ð”Ð¾Ð´Ð°Ð½Ð¾ $track Ð´Ð¾ Ñ‡ÐµÑ€Ð³Ð¸';
  }

  @override
  String get add_to_queue => 'Ð”Ð¾Ð´Ð°Ñ‚Ð¸ Ð´Ð¾ Ñ‡ÐµÑ€Ð³Ð¸';

  @override
  String track_will_play_next(Object track) {
    return '$track Ð±ÑƒÐ´Ðµ Ð²Ñ–Ð´Ñ‚Ð²Ð¾Ñ€ÐµÐ½Ð¾ Ð½Ð°ÑÑ‚ÑƒÐ¿Ð½Ð¸Ð¼';
  }

  @override
  String get play_next => 'Ð’Ñ–Ð´Ñ‚Ð²Ð¾Ñ€Ð¸Ñ‚Ð¸ Ð½Ð°ÑÑ‚ÑƒÐ¿Ð½Ð¸Ð¼';

  @override
  String removed_track_from_queue(Object track) {
    return 'Ð’Ð¸Ð´Ð°Ð»ÐµÐ½Ð¾ $track Ð· Ñ‡ÐµÑ€Ð³Ð¸';
  }

  @override
  String get remove_from_queue => 'Ð’Ð¸Ð´Ð°Ð»Ð¸Ñ‚Ð¸ Ð· Ñ‡ÐµÑ€Ð³Ð¸';

  @override
  String get remove_from_favorites => 'Ð’Ð¸Ð´Ð°Ð»Ð¸Ñ‚Ð¸ Ð· Ð¾Ð±Ñ€Ð°Ð½Ð¸Ñ…';

  @override
  String get save_as_favorite => 'Ð—Ð±ÐµÑ€ÐµÐ³Ñ‚Ð¸ ÑÐº Ð¾Ð±Ñ€Ð°Ð½Ðµ';

  @override
  String get add_to_playlist => 'Ð”Ð¾Ð´Ð°Ñ‚Ð¸ Ð´Ð¾ Ð¿Ð»ÐµÐ¹Ð»Ð¸ÑÑ‚Ð°';

  @override
  String get remove_from_playlist => 'Ð’Ð¸Ð´Ð°Ð»Ð¸Ñ‚Ð¸ Ð· Ð¿Ð»ÐµÐ¹Ð»Ð¸ÑÑ‚Ð°';

  @override
  String get add_to_blacklist =>
      'Ð”Ð¾Ð´Ð°Ñ‚Ð¸ Ð´Ð¾ Ñ‡Ð¾Ñ€Ð½Ð¾Ð³Ð¾ ÑÐ¿Ð¸ÑÐºÑƒ';

  @override
  String get remove_from_blacklist =>
      'Ð’Ð¸Ð´Ð°Ð»Ð¸Ñ‚Ð¸ Ð· Ñ‡Ð¾Ñ€Ð½Ð¾Ð³Ð¾ ÑÐ¿Ð¸ÑÐºÑƒ';

  @override
  String get share => 'ÐŸÐ¾Ð´Ñ–Ð»Ð¸Ñ‚Ð¸ÑÑ';

  @override
  String get mini_player => 'ÐœÑ–Ð½Ñ–-Ð¿Ð»ÐµÑ”Ñ€';

  @override
  String get slide_to_seek =>
      'ÐŸÑ€Ð¾Ð²ÐµÐ´Ñ–Ñ‚ÑŒ Ð¿Ð°Ð»ÑŒÑ†ÐµÐ¼, Ñ‰Ð¾Ð± Ð¿ÐµÑ€ÐµÐ¼Ð¾Ñ‚Ð°Ñ‚Ð¸ Ð²Ð¿ÐµÑ€ÐµÐ´ Ð°Ð±Ð¾ Ð½Ð°Ð·Ð°Ð´';

  @override
  String get shuffle_playlist =>
      'Ð’Ð¸Ð¿Ð°Ð´ÐºÐ¾Ð²Ð¸Ð¹ Ð¿Ð¾Ñ€ÑÐ´Ð¾Ðº Ð²Ñ–Ð´Ñ‚Ð²Ð¾Ñ€ÐµÐ½Ð½Ñ Ð¿Ð»ÐµÐ¹Ð»Ð¸ÑÑ‚Ð°';

  @override
  String get unshuffle_playlist =>
      'Ð’Ñ–Ð´ÐºÐ»ÑŽÑ‡Ð¸Ñ‚Ð¸ Ð²Ð¸Ð¿Ð°Ð´ÐºÐ¾Ð²Ð¸Ð¹ Ð¿Ð¾Ñ€ÑÐ´Ð¾Ðº Ð²Ñ–Ð´Ñ‚Ð²Ð¾Ñ€ÐµÐ½Ð½Ñ Ð¿Ð»ÐµÐ¹Ð»Ð¸ÑÑ‚Ð°';

  @override
  String get previous_track => 'ÐŸÐ¾Ð¿ÐµÑ€ÐµÐ´Ð½Ñ–Ð¹ Ñ‚Ñ€ÐµÐº';

  @override
  String get next_track => 'ÐÐ°ÑÑ‚ÑƒÐ¿Ð½Ð¸Ð¹ Ñ‚Ñ€ÐµÐº';

  @override
  String get pause_playback => 'ÐŸÑ€Ð¸Ð·ÑƒÐ¿Ð¸Ð½Ð¸Ñ‚Ð¸ Ð²Ñ–Ð´Ñ‚Ð²Ð¾Ñ€ÐµÐ½Ð½Ñ';

  @override
  String get resume_playback => 'Ð’Ñ–Ð´Ð½Ð¾Ð²Ð¸Ñ‚Ð¸ Ð²Ñ–Ð´Ñ‚Ð²Ð¾Ñ€ÐµÐ½Ð½Ñ';

  @override
  String get loop_track => 'ÐŸÐ¾Ð²Ñ‚Ð¾Ñ€ÑŽÐ²Ð°Ñ‚Ð¸ Ñ‚Ñ€ÐµÐº';

  @override
  String get no_loop => 'Ð‘ÐµÐ· Ð¿Ð¾Ð²Ñ‚Ð¾Ñ€Ñƒ';

  @override
  String get repeat_playlist => 'ÐŸÐ¾Ð²Ñ‚Ð¾Ñ€ÑŽÐ²Ð°Ñ‚Ð¸ Ð¿Ð»ÐµÐ¹Ð»Ð¸ÑÑ‚';

  @override
  String get queue => 'Ð§ÐµÑ€Ð³Ð°';

  @override
  String get alternative_track_sources =>
      'ÐÐ»ÑŒÑ‚ÐµÑ€Ð½Ð°Ñ‚Ð¸Ð²Ð½Ñ– Ð´Ð¶ÐµÑ€ÐµÐ»Ð° Ñ‚Ñ€ÐµÐºÑ–Ð²';

  @override
  String tracks_in_queue(Object tracks) {
    return '$tracks Ñ‚Ñ€ÐµÐºÑ–Ð² Ñƒ Ñ‡ÐµÑ€Ð·Ñ–';
  }

  @override
  String get clear_all => 'ÐžÑ‡Ð¸ÑÑ‚Ð¸Ñ‚Ð¸ Ð²ÑÐµ';

  @override
  String get show_hide_ui_on_hover =>
      'ÐŸÐ¾ÐºÐ°Ð·ÑƒÐ²Ð°Ñ‚Ð¸/Ð¿Ñ€Ð¸Ñ…Ð¾Ð²ÑƒÐ²Ð°Ñ‚Ð¸ Ñ–Ð½Ñ‚ÐµÑ€Ñ„ÐµÐ¹Ñ Ð¿Ñ€Ð¸ Ð½Ð°Ð²ÐµÐ´ÐµÐ½Ð½Ñ– ÐºÑƒÑ€ÑÐ¾Ñ€Ñƒ';

  @override
  String get always_on_top => 'Ð—Ð°Ð²Ð¶Ð´Ð¸ Ð·Ð²ÐµÑ€Ñ…Ñƒ';

  @override
  String get exit_mini_player => 'Ð’Ð¸Ð¹Ñ‚Ð¸ Ð· Ð¼Ñ–Ð½Ñ–-Ð¿Ð»ÐµÑ”Ñ€Ð°';

  @override
  String get local_library => 'ÐœÑ–ÑÑ†ÐµÐ²Ð° Ð±Ñ–Ð±Ð»Ñ–Ð¾Ñ‚ÐµÐºÐ°';

  @override
  String get add_library_location => 'Ð”Ð¾Ð´Ð°Ñ‚Ð¸ Ð´Ð¾ Ð±Ñ–Ð±Ð»Ñ–Ð¾Ñ‚ÐµÐºÐ¸';

  @override
  String get remove_library_location =>
      'Ð’Ð¸Ð´Ð°Ð»Ð¸Ñ‚Ð¸ Ð· Ð±Ñ–Ð±Ð»Ñ–Ð¾Ñ‚ÐµÐºÐ¸';

  @override
  String get account => 'ÐžÐ±Ð»Ñ–ÐºÐ¾Ð²Ð¸Ð¹ Ð·Ð°Ð¿Ð¸Ñ';

  @override
  String get logout => 'Ð’Ð¸Ð¹Ñ‚Ð¸';

  @override
  String get logout_of_this_account =>
      'Ð’Ð¸Ð¹Ñ‚Ð¸ Ð· Ñ†ÑŒÐ¾Ð³Ð¾ Ð¾Ð±Ð»Ñ–ÐºÐ¾Ð²Ð¾Ð³Ð¾ Ð·Ð°Ð¿Ð¸ÑÑƒ';

  @override
  String get language_region => 'ÐœÐ¾Ð²Ð° Ñ‚Ð° Ñ€ÐµÐ³Ñ–Ð¾Ð½';

  @override
  String get language => 'ÐœÐ¾Ð²Ð°';

  @override
  String get system_default => 'Ð¡Ð¸ÑÑ‚ÐµÐ¼Ð½Ð° Ð¼Ð¾Ð²Ð°';

  @override
  String get market_place_region => 'Ð ÐµÐ³Ñ–Ð¾Ð½ Ð¼Ð°Ñ€ÐºÐµÑ‚Ð¿Ð»ÐµÐ¹ÑÑƒ';

  @override
  String get recommendation_country => 'ÐšÑ€Ð°Ñ—Ð½Ð° Ñ€ÐµÐºÐ¾Ð¼ÐµÐ½Ð´Ð°Ñ†Ñ–Ð¹';

  @override
  String get appearance => 'Ð—Ð¾Ð²Ð½Ñ–ÑˆÐ½Ñ–Ð¹ Ð²Ð¸Ð³Ð»ÑÐ´';

  @override
  String get layout_mode => 'Ð ÐµÐ¶Ð¸Ð¼ Ð¼Ð°ÐºÐµÑ‚Ð°';

  @override
  String get override_layout_settings =>
      'ÐŸÐµÑ€ÐµÐ·Ð°Ð¿Ð¸ÑÐ°Ñ‚Ð¸ Ð½Ð°Ð»Ð°ÑˆÑ‚ÑƒÐ²Ð°Ð½Ð½Ñ Ð°Ð´Ð°Ð¿Ñ‚Ð¸Ð²Ð½Ð¾Ð³Ð¾ Ñ€ÐµÐ¶Ð¸Ð¼Ñƒ Ð¼Ð°ÐºÐµÑ‚Ð°';

  @override
  String get adaptive => 'ÐÐ´Ð°Ð¿Ñ‚Ð¸Ð²Ð½Ð¸Ð¹';

  @override
  String get compact => 'ÐšÐ¾Ð¼Ð¿Ð°ÐºÑ‚Ð½Ð¸Ð¹';

  @override
  String get extended => 'Ð Ð¾Ð·ÑˆÐ¸Ñ€ÐµÐ½Ð¸Ð¹';

  @override
  String get theme => 'Ð¢ÐµÐ¼Ð°';

  @override
  String get dark => 'Ð¢ÐµÐ¼Ð½Ð°';

  @override
  String get light => 'Ð¡Ð²Ñ–Ñ‚Ð»Ð°';

  @override
  String get system => 'Ð¡Ð¸ÑÑ‚ÐµÐ¼Ð½Ð°';

  @override
  String get accent_color => 'ÐšÐ¾Ð»Ñ–Ñ€ Ð°ÐºÑ†ÐµÐ½Ñ‚Ñƒ';

  @override
  String get sync_album_color =>
      'Ð¡Ð¸Ð½Ñ…Ñ€Ð¾Ð½Ñ–Ð·ÑƒÐ²Ð°Ñ‚Ð¸ ÐºÐ¾Ð»Ñ–Ñ€ Ð°Ð»ÑŒÐ±Ð¾Ð¼Ñƒ';

  @override
  String get sync_album_color_description =>
      'Ð’Ð¸ÐºÐ¾Ñ€Ð¸ÑÑ‚Ð¾Ð²ÑƒÑ” Ð´Ð¾Ð¼Ñ–Ð½ÑƒÑŽÑ‡Ð¸Ð¹ ÐºÐ¾Ð»Ñ–Ñ€ Ð¾Ð±ÐºÐ»Ð°Ð´Ð¸Ð½ÐºÐ¸ Ð°Ð»ÑŒÐ±Ð¾Ð¼Ñƒ ÑÐº ÐºÐ¾Ð»Ñ–Ñ€ Ð°ÐºÑ†ÐµÐ½Ñ‚Ñƒ';

  @override
  String get playback => 'Ð’Ñ–Ð´Ñ‚Ð²Ð¾Ñ€ÐµÐ½Ð½Ñ';

  @override
  String get audio_quality => 'Ð¯ÐºÑ–ÑÑ‚ÑŒ Ð°ÑƒÐ´Ñ–Ð¾';

  @override
  String get high => 'Ð’Ð¸ÑÐ¾ÐºÐ°';

  @override
  String get low => 'ÐÐ¸Ð·ÑŒÐºÐ°';

  @override
  String get pre_download_play =>
      'ÐŸÐ¾Ð¿ÐµÑ€ÐµÐ´Ð½Ñ” Ð·Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶ÐµÐ½Ð½Ñ Ñ‚Ð° Ð²Ñ–Ð´Ñ‚Ð²Ð¾Ñ€ÐµÐ½Ð½Ñ';

  @override
  String get pre_download_play_description =>
      'Ð—Ð°Ð¼Ñ–ÑÑ‚ÑŒ Ð¿Ð¾Ñ‚Ð¾ÐºÐ¾Ð²Ð¾Ð³Ð¾ Ð²Ñ–Ð´Ñ‚Ð²Ð¾Ñ€ÐµÐ½Ð½Ñ Ð°ÑƒÐ´Ñ–Ð¾ Ð·Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶Ñ‚Ðµ Ð±Ð°Ð¹Ñ‚Ð¸ Ñ‚Ð° Ð²Ñ–Ð´Ñ‚Ð²Ð¾Ñ€Ñ–Ñ‚ÑŒ Ñ—Ñ… (Ñ€ÐµÐºÐ¾Ð¼ÐµÐ½Ð´Ð¾Ð²Ð°Ð½Ð¾ Ð´Ð»Ñ ÐºÐ¾Ñ€Ð¸ÑÑ‚ÑƒÐ²Ð°Ñ‡Ñ–Ð² Ð· Ð²Ð¸ÑÐ¾ÐºÐ¾ÑŽ Ð¿Ñ€Ð¾Ð¿ÑƒÑÐºÐ½Ð¾ÑŽ Ð·Ð´Ð°Ñ‚Ð½Ñ–ÑÑ‚ÑŽ)';

  @override
  String get skip_non_music =>
      'ÐŸÑ€Ð¾Ð¿ÑƒÑÑ‚Ð¸Ñ‚Ð¸ Ð½Ðµ Ð¼ÑƒÐ·Ð¸Ñ‡Ð½Ñ– ÑÐµÐ³Ð¼ÐµÐ½Ñ‚Ð¸';

  @override
  String get blacklist_description =>
      'Ð¢Ñ€ÐµÐºÐ¸ Ñ‚Ð° Ð²Ð¸ÐºÐ¾Ð½Ð°Ð²Ñ†Ñ– Ð² Ñ‡Ð¾Ñ€Ð½Ð¾Ð¼Ñƒ ÑÐ¿Ð¸ÑÐºÑƒ';

  @override
  String get wait_for_download_to_finish =>
      'Ð—Ð°Ñ‡ÐµÐºÐ°Ð¹Ñ‚Ðµ, Ð¿Ð¾ÐºÐ¸ Ð·Ð°Ð²ÐµÑ€ÑˆÐ¸Ñ‚ÑŒÑÑ Ð¿Ð¾Ñ‚Ð¾Ñ‡Ð½Ð° Ð·Ð°Ð³Ñ€ÑƒÐ·ÐºÐ°';

  @override
  String get desktop => 'Ð Ð¾Ð±Ð¾Ñ‡Ð¸Ð¹ ÑÑ‚Ñ–Ð»';

  @override
  String get close_behavior => 'ÐŸÐ¾Ð²ÐµÐ´Ñ–Ð½ÐºÐ° Ð¿Ñ€Ð¸ Ð·Ð°ÐºÑ€Ð¸Ñ‚Ñ‚Ñ–';

  @override
  String get close => 'Ð—Ð°ÐºÑ€Ð¸Ñ‚Ð¸';

  @override
  String get minimize_to_tray => 'Ð—Ð³Ð¾Ñ€Ð½ÑƒÑ‚Ð¸ Ð² Ñ‚Ñ€ÐµÐ¹';

  @override
  String get show_tray_icon =>
      'ÐŸÐ¾ÐºÐ°Ð·ÑƒÐ²Ð°Ñ‚Ð¸ Ð·Ð½Ð°Ñ‡Ð¾Ðº Ñƒ ÑÐ¸ÑÑ‚ÐµÐ¼Ð½Ð¾Ð¼Ñƒ Ñ‚Ñ€ÐµÑ—';

  @override
  String get about => 'ÐŸÑ€Ð¾';

  @override
  String get u_love_spotube =>
      'ÐœÐ¸ Ð·Ð½Ð°Ñ”Ð¼Ð¾, Ñ‰Ð¾ Ð²Ð¸ Ð»ÑŽÐ±Ð¸Ñ‚Ðµ Soulful Bhakti';

  @override
  String get check_for_updates =>
      'ÐŸÐµÑ€ÐµÐ²Ñ–Ñ€Ð¸Ñ‚Ð¸ Ð½Ð°ÑÐ²Ð½Ñ–ÑÑ‚ÑŒ Ð¾Ð½Ð¾Ð²Ð»ÐµÐ½ÑŒ';

  @override
  String get about_spotube => 'ÐŸÑ€Ð¾ Soulful Bhakti';

  @override
  String get blacklist => 'Ð§Ð¾Ñ€Ð½Ð¸Ð¹ ÑÐ¿Ð¸ÑÐ¾Ðº';

  @override
  String get please_sponsor =>
      'Ð‘ÑƒÐ´ÑŒ Ð»Ð°ÑÐºÐ°, ÑÑ‚Ð°Ð½ÑŒÑ‚Ðµ ÑÐ¿Ð¾Ð½ÑÐ¾Ñ€Ð¾Ð¼/Ð·Ñ€Ð¾Ð±Ñ–Ñ‚ÑŒ Ð¿Ð¾Ð¶ÐµÑ€Ñ‚Ð²Ñƒ';

  @override
  String get spotube_description =>
      'Soulful Bhakti, Ð»ÐµÐ³ÐºÐ¸Ð¹, ÐºÑ€Ð¾ÑÐ¿Ð»Ð°Ñ‚Ñ„Ð¾Ñ€Ð¼Ð¾Ð²Ð¸Ð¹, Ð±ÐµÐ·ÐºÐ¾ÑˆÑ‚Ð¾Ð²Ð½Ð¸Ð¹ ÐºÐ»Ñ–Ñ”Ð½Ñ‚ Spotify';

  @override
  String get version => 'Ð’ÐµÑ€ÑÑ–Ñ';

  @override
  String get build_number => 'ÐÐ¾Ð¼ÐµÑ€ Ð·Ð±Ñ–Ñ€ÐºÐ¸';

  @override
  String get founder => 'Ð—Ð°ÑÐ½Ð¾Ð²Ð½Ð¸Ðº';

  @override
  String get repository => 'Ð ÐµÐ¿Ð¾Ð·Ð¸Ñ‚Ð¾Ñ€Ñ–Ð¹';

  @override
  String get bug_issues => 'ÐŸÐ¾Ð¼Ð¸Ð»ÐºÐ¸ Ñ‚Ð° Ð¿Ñ€Ð¾Ð±Ð»ÐµÐ¼Ð¸';

  @override
  String get made_with =>
      'Ð—Ñ€Ð¾Ð±Ð»ÐµÐ½Ð¾ Ð· â¤ï¸ Ð² Ð‘Ð°Ð½Ð³Ð»Ð°Ð´ÐµÑˆ ðŸ‡§ðŸ‡©';

  @override
  String get kingkor_roy_tirtho => 'Kingkor Roy Tirtho';

  @override
  String copyright(Object current_year) {
    return 'Â© 2021-$current_year Kingkor Roy Tirtho';
  }

  @override
  String get license => 'Ð›Ñ–Ñ†ÐµÐ½Ð·Ñ–Ñ';

  @override
  String get credentials_will_not_be_shared_disclaimer =>
      'ÐÐµ Ñ…Ð²Ð¸Ð»ÑŽÐ¹Ñ‚ÐµÑÑ, Ð¶Ð¾Ð´Ð½Ñ– Ð²Ð°ÑˆÑ– Ð¾Ð±Ð»Ñ–ÐºÐ¾Ð²Ñ– Ð´Ð°Ð½Ñ– Ð½Ðµ Ð±ÑƒÐ´ÑƒÑ‚ÑŒ Ð·Ñ–Ð±Ñ€Ð°Ð½Ñ– Ð°Ð±Ð¾ Ð¿ÐµÑ€ÐµÐ´Ð°Ð½Ñ– ÐºÐ¾Ð¼Ñƒ-Ð½ÐµÐ±ÑƒÐ´ÑŒ';

  @override
  String get know_how_to_login =>
      'ÐÐµ Ð·Ð½Ð°Ñ”Ñ‚Ðµ, ÑÐº Ñ†Ðµ Ð·Ñ€Ð¾Ð±Ð¸Ñ‚Ð¸?';

  @override
  String get follow_step_by_step_guide =>
      'Ð”Ð¾Ñ‚Ñ€Ð¸Ð¼ÑƒÐ¹Ñ‚ÐµÑÑŒ Ð¿Ð¾ÐºÑ€Ð¾ÐºÐ¾Ð²Ð¾Ñ— Ñ–Ð½ÑÑ‚Ñ€ÑƒÐºÑ†Ñ–Ñ—';

  @override
  String cookie_name_cookie(Object name) {
    return 'ÐšÑƒÐºÑ–-Ñ„Ð°Ð¹Ð» $name';
  }

  @override
  String get fill_in_all_fields =>
      'Ð‘ÑƒÐ´ÑŒ Ð»Ð°ÑÐºÐ°, Ð·Ð°Ð¿Ð¾Ð²Ð½Ñ–Ñ‚ÑŒ ÑƒÑÑ– Ð¿Ð¾Ð»Ñ';

  @override
  String get submit => 'ÐÐ°Ð´Ñ–ÑÐ»Ð°Ñ‚Ð¸';

  @override
  String get exit => 'Ð’Ð¸Ð¹Ñ‚Ð¸';

  @override
  String get previous => 'ÐŸÐ¾Ð¿ÐµÑ€ÐµÐ´Ð½Ñ–Ð¹';

  @override
  String get next => 'ÐÐ°ÑÑ‚ÑƒÐ¿Ð½Ð¸Ð¹';

  @override
  String get done => 'Ð“Ð¾Ñ‚Ð¾Ð²Ð¾';

  @override
  String get step_1 => 'ÐšÑ€Ð¾Ðº 1';

  @override
  String get first_go_to => 'Ð¡Ð¿Ð¾Ñ‡Ð°Ñ‚ÐºÑƒ Ð¿ÐµÑ€ÐµÐ¹Ð´Ñ–Ñ‚ÑŒ Ð½Ð°';

  @override
  String get something_went_wrong => 'Ð©Ð¾ÑÑŒ Ð¿Ñ–ÑˆÐ»Ð¾ Ð½Ðµ Ñ‚Ð°Ðº';

  @override
  String get piped_instance => 'ÐŸÑ€Ð¸Ð¼Ñ–Ñ€Ð½Ð¸Ðº ÑÐµÑ€Ð²ÐµÑ€Ð° Piped';

  @override
  String get piped_description =>
      'ÐŸÑ€Ð¸Ð¼Ñ–Ñ€Ð½Ð¸Ðº ÑÐµÑ€Ð²ÐµÑ€Ð° Piped, ÑÐºÐ¸Ð¹ Ð²Ð¸ÐºÐ¾Ñ€Ð¸ÑÑ‚Ð¾Ð²ÑƒÐ²Ð°Ñ‚Ð¸Ð¼ÐµÑ‚ÑŒÑÑ Ð´Ð»Ñ Ð·Ñ–ÑÑ‚Ð°Ð²Ð»ÐµÐ½Ð½Ñ Ñ‚Ñ€ÐµÐºÑ–Ð²';

  @override
  String get piped_warning =>
      'Ð”ÐµÑÐºÑ– Ð· Ð½Ð¸Ñ… Ð¼Ð¾Ð¶ÑƒÑ‚ÑŒ Ð¿Ñ€Ð°Ñ†ÑŽÐ²Ð°Ñ‚Ð¸ Ð½ÐµÐ¿Ñ€Ð°Ð²Ð¸Ð»ÑŒÐ½Ð¾. Ð¢Ð¾Ð¼Ñƒ Ð²Ð¸ÐºÐ¾Ñ€Ð¸ÑÑ‚Ð¾Ð²ÑƒÐ¹Ñ‚Ðµ Ð½Ð° ÑÐ²Ñ–Ð¹ ÑÑ‚Ñ€Ð°Ñ… Ñ– Ñ€Ð¸Ð·Ð¸Ðº';

  @override
  String get invidious_instance =>
      'Ð•ÐºÐ·ÐµÐ¼Ð¿Ð»ÑÑ€ ÑÐµÑ€Ð²ÐµÑ€Ð° Invidious';

  @override
  String get invidious_description =>
      'Ð•ÐºÐ·ÐµÐ¼Ð¿Ð»ÑÑ€ ÑÐµÑ€Ð²ÐµÑ€Ð° Invidious Ð´Ð»Ñ Ð·Ñ–ÑÑ‚Ð°Ð²Ð»ÐµÐ½Ð½Ñ Ñ‚Ñ€ÐµÐºÑ–Ð²';

  @override
  String get invidious_warning =>
      'Ð”ÐµÑÐºÑ– Ð¼Ð¾Ð¶ÑƒÑ‚ÑŒ Ð¿Ñ€Ð°Ñ†ÑŽÐ²Ð°Ñ‚Ð¸ Ð½Ðµ Ð´ÑƒÐ¶Ðµ Ð´Ð¾Ð±Ñ€Ðµ. Ð’Ð¸ÐºÐ¾Ñ€Ð¸ÑÑ‚Ð¾Ð²ÑƒÐ¹Ñ‚Ðµ Ð½Ð° Ð²Ð»Ð°ÑÐ½Ð¸Ð¹ Ñ€Ð¸Ð·Ð¸Ðº';

  @override
  String get generate => 'Ð“ÐµÐ½ÐµÑ€ÑƒÐ²Ð°Ñ‚Ð¸';

  @override
  String track_exists(Object track) {
    return 'Ð¢Ñ€ÐµÐº $track Ð²Ð¶Ðµ Ñ–ÑÐ½ÑƒÑ”';
  }

  @override
  String get replace => 'Ð—Ð°Ð¼Ñ–Ð½Ð¸Ñ‚Ð¸';

  @override
  String get skip => 'ÐŸÑ€Ð¾Ð¿ÑƒÑÑ‚Ð¸Ñ‚Ð¸';

  @override
  String select_up_to_count_type(Object count, Object type) {
    return 'Ð’Ð¸Ð±ÐµÑ€Ñ–Ñ‚ÑŒ Ð´Ð¾ $count $type';
  }

  @override
  String get select_genres => 'Ð’Ð¸Ð±ÐµÑ€Ñ–Ñ‚ÑŒ Ð¶Ð°Ð½Ñ€Ð¸';

  @override
  String get add_genres => 'Ð”Ð¾Ð´Ð°Ñ‚Ð¸ Ð¶Ð°Ð½Ñ€Ð¸';

  @override
  String get country => 'ÐšÑ€Ð°Ñ—Ð½Ð°';

  @override
  String get number_of_tracks_generate =>
      'ÐšÑ–Ð»ÑŒÐºÑ–ÑÑ‚ÑŒ Ñ‚Ñ€ÐµÐºÑ–Ð² Ð´Ð»Ñ ÑÑ‚Ð²Ð¾Ñ€ÐµÐ½Ð½Ñ';

  @override
  String get acousticness => 'ÐÐºÑƒÑÑ‚Ð¸Ñ‡Ð½Ñ–ÑÑ‚ÑŒ';

  @override
  String get danceability => 'Ð¢Ð°Ð½Ñ†ÑŽÐ²Ð°Ð»ÑŒÐ½Ñ–ÑÑ‚ÑŒ';

  @override
  String get energy => 'Ð•Ð½ÐµÑ€Ð³Ñ–Ñ';

  @override
  String get instrumentalness => 'Ð†Ð½ÑÑ‚Ñ€ÑƒÐ¼ÐµÐ½Ñ‚Ð°Ð»ÑŒÐ½Ñ–ÑÑ‚ÑŒ';

  @override
  String get liveness => 'Ð–Ð¸Ð²Ñ–ÑÑ‚ÑŒ';

  @override
  String get loudness => 'Ð“ÑƒÑ‡Ð½Ñ–ÑÑ‚ÑŒ';

  @override
  String get speechiness => 'Ð Ð¾Ð·Ð¼Ð¾Ð²Ð½Ñ–ÑÑ‚ÑŒ';

  @override
  String get valence => 'Ð’Ð°Ð»ÐµÐ½Ñ‚Ð½Ñ–ÑÑ‚ÑŒ';

  @override
  String get popularity => 'ÐŸÐ¾Ð¿ÑƒÐ»ÑÑ€Ð½Ñ–ÑÑ‚ÑŒ';

  @override
  String get key => 'Ð¢Ð¾Ð½Ð°Ð»ÑŒÐ½Ñ–ÑÑ‚ÑŒ';

  @override
  String get duration => 'Ð¢Ñ€Ð¸Ð²Ð°Ð»Ñ–ÑÑ‚ÑŒ (Ñ)';

  @override
  String get tempo => 'Ð¢ÐµÐ¼Ð¿ (BPM)';

  @override
  String get mode => 'Ð ÐµÐ¶Ð¸Ð¼';

  @override
  String get time_signature => 'Ð Ð¾Ð·Ð¼Ñ–Ñ€';

  @override
  String get short => 'ÐšÐ¾Ñ€Ð¾Ñ‚ÐºÐ¸Ð¹';

  @override
  String get medium => 'Ð¡ÐµÑ€ÐµÐ´Ð½Ñ–Ð¹';

  @override
  String get long => 'Ð”Ð¾Ð²Ð³Ð¸Ð¹';

  @override
  String get min => 'ÐœÑ–Ð½';

  @override
  String get max => 'ÐœÐ°ÐºÑ';

  @override
  String get target => 'Ð¦Ñ–Ð»ÑŒÐ¾Ð²Ð¸Ð¹';

  @override
  String get moderate => 'ÐŸÐ¾Ð¼Ñ–Ñ€Ð½Ð¸Ð¹';

  @override
  String get deselect_all => 'Ð—Ð½ÑÑ‚Ð¸ Ð²Ð¸Ð±Ñ–Ñ€ Ð· ÑƒÑÑ–Ñ…';

  @override
  String get select_all => 'Ð’Ð¸Ð±Ñ€Ð°Ñ‚Ð¸ Ð²ÑÑ–';

  @override
  String get are_you_sure => 'Ð’Ð¸ Ð²Ð¿ÐµÐ²Ð½ÐµÐ½Ñ–?';

  @override
  String get generating_playlist =>
      'Ð¡Ñ‚Ð²Ð¾Ñ€ÐµÐ½Ð½Ñ Ð²Ð°ÑˆÐ¾Ð³Ð¾ Ð¿ÐµÑ€ÑÐ¾Ð½Ð°Ð»ÑŒÐ½Ð¾Ð³Ð¾ Ð¿Ð»ÐµÐ¹Ð»Ð¸ÑÑ‚Ð°...';

  @override
  String selected_count_tracks(Object count) {
    return 'Ð’Ð¸Ð±Ñ€Ð°Ð½Ð¾ $count Ñ‚Ñ€ÐµÐºÑ–Ð²';
  }

  @override
  String get download_warning =>
      'Ð¯ÐºÑ‰Ð¾ Ð²Ð¸ Ð·Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶ÑƒÑ”Ñ‚Ðµ Ð²ÑÑ– Ñ‚Ñ€ÐµÐºÐ¸ Ð¼Ð°ÑÐ¾Ð²Ð¾, Ð²Ð¸ ÑÐ²Ð½Ð¾ Ð¿Ñ–Ñ€Ð°Ñ‚ÑÑ‚Ð²ÑƒÑ”Ñ‚Ðµ Ñ– Ð·Ð°Ð²Ð´Ð°Ñ”Ñ‚Ðµ ÑˆÐºÐ¾Ð´Ð¸ Ð¼ÑƒÐ·Ð¸Ñ‡Ð½Ð¾Ð¼Ñƒ Ñ‚Ð²Ð¾Ñ€Ñ‡Ð¾Ð¼Ñƒ ÑÐ¿Ñ–Ð²Ñ‚Ð¾Ð²Ð°Ñ€Ð¸ÑÑ‚Ð²Ñƒ. Ð¡Ð¿Ð¾Ð´Ñ–Ð²Ð°ÑŽÑÑ, Ð²Ð¸ ÑƒÑÐ²Ñ–Ð´Ð¾Ð¼Ð»ÑŽÑ”Ñ‚Ðµ Ñ†Ðµ. Ð—Ð°Ð²Ð¶Ð´Ð¸ Ð½Ð°Ð¼Ð°Ð³Ð°Ð¹Ñ‚ÐµÑÑ Ð¿Ð¾Ð²Ð°Ð¶Ð°Ñ‚Ð¸ Ñ– Ð¿Ñ–Ð´Ñ‚Ñ€Ð¸Ð¼ÑƒÐ²Ð°Ñ‚Ð¸ Ð²Ð°Ð¶ÐºÑƒ Ð¿Ñ€Ð°Ñ†ÑŽ Ð°Ñ€Ñ‚Ð¸ÑÑ‚Ð°';

  @override
  String get download_ip_ban_warning =>
      'Ð”Ð¾ Ñ€ÐµÑ‡Ñ–, Ð²Ð°Ñˆ IP Ð¼Ð¾Ð¶Ðµ Ð±ÑƒÑ‚Ð¸ Ð·Ð°Ð±Ð»Ð¾ÐºÐ¾Ð²Ð°Ð½Ð¸Ð¹ Ð½Ð° YouTube Ñ‡ÐµÑ€ÐµÐ· Ð½Ð°Ð´Ð¼Ñ–Ñ€Ð½Ñƒ ÐºÑ–Ð»ÑŒÐºÑ–ÑÑ‚ÑŒ Ð·Ð°Ð¿Ð¸Ñ‚Ñ–Ð² Ð½Ð° Ð·Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶ÐµÐ½Ð½Ñ, Ð½Ñ–Ð¶ Ð·Ð°Ð·Ð²Ð¸Ñ‡Ð°Ð¹. Ð‘Ð»Ð¾ÐºÑƒÐ²Ð°Ð½Ð½Ñ IP-Ð°Ð´Ñ€ÐµÑÐ¸ Ð¾Ð·Ð½Ð°Ñ‡Ð°Ñ”, Ñ‰Ð¾ Ð²Ð¸ Ð½Ðµ Ð·Ð¼Ð¾Ð¶ÐµÑ‚Ðµ ÐºÐ¾Ñ€Ð¸ÑÑ‚ÑƒÐ²Ð°Ñ‚Ð¸ÑÑ YouTube (Ð½Ð°Ð²Ñ–Ñ‚ÑŒ ÑÐºÑ‰Ð¾ Ð²Ð¸ ÑƒÐ²Ñ–Ð¹ÑˆÐ»Ð¸ Ð² ÑÐ¸ÑÑ‚ÐµÐ¼Ñƒ) Ð¿Ñ€Ð¾Ñ‚ÑÐ³Ð¾Ð¼ Ñ‰Ð¾Ð½Ð°Ð¹Ð¼ÐµÐ½ÑˆÐµ 2-3 Ð¼Ñ–ÑÑÑ†Ñ–Ð² Ð· Ñ†ÑŒÐ¾Ð³Ð¾ Ð¿Ñ€Ð¸ÑÑ‚Ñ€Ð¾ÑŽ. Ð† Soulful Bhakti Ð½Ðµ Ð½ÐµÑÐµ Ð¶Ð¾Ð´Ð½Ð¾Ñ— Ð²Ñ–Ð´Ð¿Ð¾Ð²Ñ–Ð´Ð°Ð»ÑŒÐ½Ð¾ÑÑ‚Ñ–, ÑÐºÑ‰Ð¾ Ñ†Ðµ ÑÑ‚Ð°Ð½ÐµÑ‚ÑŒÑÑ';

  @override
  String get by_clicking_accept_terms =>
      'ÐÐ°Ñ‚Ð¸ÑÐºÐ°ÑŽÑ‡Ð¸ \'Ð¿Ñ€Ð¸Ð¹Ð½ÑÑ‚Ð¸\', Ð²Ð¸ Ð¿Ð¾Ð³Ð¾Ð´Ð¶ÑƒÑ”Ñ‚ÐµÑÑ Ð· Ð½Ð°ÑÑ‚ÑƒÐ¿Ð½Ð¸Ð¼Ð¸ ÑƒÐ¼Ð¾Ð²Ð°Ð¼Ð¸:';

  @override
  String get download_agreement_1 =>
      'Ð¯ Ð·Ð½Ð°ÑŽ, Ñ‰Ð¾ ÐºÑ€Ð°Ð´Ñƒ Ð¼ÑƒÐ·Ð¸ÐºÑƒ. Ð¯ Ð¿Ð¾Ð³Ð°Ð½Ð¸Ð¹.';

  @override
  String get download_agreement_2 =>
      'Ð¯ Ð¿Ñ–Ð´Ñ‚Ñ€Ð¸Ð¼Ð°ÑŽ Ð°Ð²Ñ‚Ð¾Ñ€Ð°, Ð´Ðµ Ñ‚Ñ–Ð»ÑŒÐºÐ¸ Ð·Ð¼Ð¾Ð¶Ñƒ, Ñ– Ñ€Ð¾Ð±Ð»ÑŽ Ñ†Ðµ Ð»Ð¸ÑˆÐµ Ñ‚Ð¾Ð¼Ñƒ, Ñ‰Ð¾ Ð½Ðµ Ð¼Ð°ÑŽ Ð³Ñ€Ð¾ÑˆÐµÐ¹, Ñ‰Ð¾Ð± ÐºÑƒÐ¿Ð¸Ñ‚Ð¸ Ð¹Ð¾Ð³Ð¾ Ñ€Ð¾Ð±Ð¾Ñ‚Ð¸.';

  @override
  String get download_agreement_3 =>
      'Ð¯ Ð¿Ð¾Ð²Ð½Ñ–ÑÑ‚ÑŽ ÑƒÑÐ²Ñ–Ð´Ð¾Ð¼Ð»ÑŽÑŽ, Ñ‰Ð¾ Ð¼Ñ–Ð¹ IP Ð¼Ð¾Ð¶Ðµ Ð±ÑƒÑ‚Ð¸ Ð·Ð°Ð±Ð»Ð¾ÐºÐ¾Ð²Ð°Ð½Ð¸Ð¹ Ð½Ð° YouTube, Ñ– Ñ Ð½Ðµ Ð¿Ð¾ÐºÐ»Ð°Ð´Ð°ÑŽ Ð½Ð° Soulful Bhakti Ð°Ð±Ð¾ Ð¹Ð¾Ð³Ð¾ Ð²Ð»Ð°ÑÐ½Ð¸ÐºÑ–Ð²/ÐºÐ¾Ð½Ñ‚Ñ€Ð¸Ð±ÑƒÑ‚Ð¾Ñ€Ñ–Ð² Ð²Ñ–Ð´Ð¿Ð¾Ð²Ñ–Ð´Ð°Ð»ÑŒÐ½Ñ–ÑÑ‚ÑŒ Ð·Ð° Ð±ÑƒÐ´ÑŒ-ÑÐºÑ– Ð½ÐµÑ‰Ð°ÑÐ½Ñ– Ð²Ð¸Ð¿Ð°Ð´ÐºÐ¸, ÑÐ¿Ñ€Ð¸Ñ‡Ð¸Ð½ÐµÐ½Ñ– Ð¼Ð¾Ñ—Ð¼Ð¸ Ð´Ñ–ÑÐ¼Ð¸.';

  @override
  String get decline => 'Ð’Ñ–Ð´Ñ…Ð¸Ð»Ð¸Ñ‚Ð¸';

  @override
  String get accept => 'ÐŸÑ€Ð¸Ð¹Ð½ÑÑ‚Ð¸';

  @override
  String get details => 'Ð”ÐµÑ‚Ð°Ð»Ñ–';

  @override
  String get youtube => 'YouTube';

  @override
  String get channel => 'ÐšÐ°Ð½Ð°Ð»';

  @override
  String get likes => 'ÐŸÐ¾Ð´Ð¾Ð±Ð°Ñ”Ñ‚ÑŒÑÑ';

  @override
  String get dislikes => 'ÐÐµ Ð¿Ð¾Ð´Ð¾Ð±Ð°Ñ”Ñ‚ÑŒÑÑ';

  @override
  String get views => 'ÐŸÐµÑ€ÐµÐ³Ð»ÑÐ´Ñ–Ð²';

  @override
  String get streamUrl => 'ÐŸÐ¾ÑÐ¸Ð»Ð°Ð½Ð½Ñ Ð½Ð° ÑÑ‚Ñ€Ñ–Ð¼Ñ–Ð½Ð³';

  @override
  String get stop => 'Ð—ÑƒÐ¿Ð¸Ð½Ð¸Ñ‚Ð¸';

  @override
  String get sort_newest =>
      'Ð¡Ð¾Ñ€Ñ‚ÑƒÐ²Ð°Ñ‚Ð¸ Ð·Ð° Ð´Ð°Ñ‚Ð¾ÑŽ Ð´Ð¾Ð´Ð°Ð²Ð°Ð½Ð½Ñ (Ð½Ð¾Ð²Ñ–ÑˆÑ– Ð¿ÐµÑ€ÑˆÐ¸Ð¼Ð¸)';

  @override
  String get sort_oldest =>
      'Ð¡Ð¾Ñ€Ñ‚ÑƒÐ²Ð°Ñ‚Ð¸ Ð·Ð° Ð´Ð°Ñ‚Ð¾ÑŽ Ð´Ð¾Ð´Ð°Ð²Ð°Ð½Ð½Ñ (ÑÑ‚Ð°Ñ€Ñ–ÑˆÑ– Ð¿ÐµÑ€ÑˆÐ¸Ð¼Ð¸)';

  @override
  String get sleep_timer => 'Ð¢Ð°Ð¹Ð¼ÐµÑ€ ÑÐ½Ñƒ';

  @override
  String mins(Object minutes) {
    return '$minutes Ñ…Ð²Ð¸Ð»Ð¸Ð½';
  }

  @override
  String hours(Object hours) {
    return '$hours Ð³Ð¾Ð´Ð¸Ð½';
  }

  @override
  String hour(Object hours) {
    return '$hours Ð³Ð¾Ð´Ð¸Ð½Ð°';
  }

  @override
  String get custom_hours =>
      'ÐšÑ–Ð»ÑŒÐºÑ–ÑÑ‚ÑŒ Ð³Ð¾Ð´Ð¸Ð½ Ð½Ð° Ð·Ð°Ð¼Ð¾Ð²Ð»ÐµÐ½Ð½Ñ';

  @override
  String get logs => 'Ð›Ð¾Ð³Ð¸';

  @override
  String get developers => 'Ð Ð¾Ð·Ñ€Ð¾Ð±Ð½Ð¸ÐºÐ¸';

  @override
  String get not_logged_in =>
      'Ð’Ð¸ Ð½Ðµ Ð²Ð²Ñ–Ð¹ÑˆÐ»Ð¸ Ð² Ð¾Ð±Ð»Ñ–ÐºÐ¾Ð²Ð¸Ð¹ Ð·Ð°Ð¿Ð¸Ñ';

  @override
  String get search_mode => 'Ð ÐµÐ¶Ð¸Ð¼ Ð¿Ð¾ÑˆÑƒÐºÑƒ';

  @override
  String get audio_source => 'Ð”Ð¶ÐµÑ€ÐµÐ»Ð¾ Ð°ÑƒÐ´Ñ–Ð¾';

  @override
  String get ok => 'Ð“Ð°Ñ€Ð°Ð·Ð´';

  @override
  String get failed_to_encrypt => 'ÐÐµ Ð²Ð´Ð°Ð»Ð¾ÑÑ Ð·Ð°ÑˆÐ¸Ñ„Ñ€ÑƒÐ²Ð°Ñ‚Ð¸';

  @override
  String get encryption_failed_warning =>
      'Soulful Bhakti Ð²Ð¸ÐºÐ¾Ñ€Ð¸ÑÑ‚Ð¾Ð²ÑƒÑ” ÑˆÐ¸Ñ„Ñ€ÑƒÐ²Ð°Ð½Ð½Ñ Ð´Ð»Ñ Ð±ÐµÐ·Ð¿ÐµÑ‡Ð½Ð¾Ð³Ð¾ Ð·Ð±ÐµÑ€Ñ–Ð³Ð°Ð½Ð½Ñ Ð²Ð°ÑˆÐ¸Ñ… Ð´Ð°Ð½Ð¸Ñ…. ÐÐ»Ðµ Ð½Ðµ Ð²Ð´Ð°Ð»Ð¾ÑÑ Ñ†ÑŒÐ¾Ð³Ð¾ Ð·Ñ€Ð¾Ð±Ð¸Ñ‚Ð¸. Ð¢Ð¾Ð¼Ñƒ Ð²Ñ–Ð½ Ð¿ÐµÑ€ÐµÐ¹Ð´Ðµ Ð´Ð¾ Ð½ÐµÐ±ÐµÐ·Ð¿ÐµÑ‡Ð½Ð¾Ð³Ð¾ Ð·Ð±ÐµÑ€Ñ–Ð³Ð°Ð½Ð½Ñ\nÐ¯ÐºÑ‰Ð¾ Ð²Ð¸ Ð²Ð¸ÐºÐ¾Ñ€Ð¸ÑÑ‚Ð¾Ð²ÑƒÑ”Ñ‚Ðµ Linux, Ð¿ÐµÑ€ÐµÐºÐ¾Ð½Ð°Ð¹Ñ‚ÐµÑÑ, Ñ‰Ð¾ Ñƒ Ð²Ð°Ñ Ð²ÑÑ‚Ð°Ð½Ð¾Ð²Ð»ÐµÐ½Ð¾ Ð±ÑƒÐ´ÑŒ-ÑÐºÐ¸Ð¹ ÑÐµÐºÑ€ÐµÑ‚Ð½Ð¸Ð¹ ÑÐµÑ€Ð²Ñ–Ñ (gnome-keyring, kde-wallet, keepassxc Ñ‚Ð¾Ñ‰Ð¾)';

  @override
  String get querying_info => 'Ð—Ð°Ð¿Ð¸Ñ‚ Ñ–Ð½Ñ„Ð¾Ñ€Ð¼Ð°Ñ†Ñ–Ñ—...';

  @override
  String get piped_api_down => 'API Piped Ð½Ðµ Ð¿Ñ€Ð°Ñ†ÑŽÑ”';

  @override
  String piped_down_error_instructions(Object pipedInstance) {
    return 'ÐŸÐ¾Ñ‚Ð¾Ñ‡Ð½Ð¸Ð¹ ÐµÐºÐ·ÐµÐ¼Ð¿Ð»ÑÑ€ Piped $pipedInstance Ð½Ðµ Ð¿Ñ€Ð°Ñ†ÑŽÑ”\n\nÐ—Ð¼Ñ–Ð½Ñ–Ñ‚ÑŒ ÐµÐºÐ·ÐµÐ¼Ð¿Ð»ÑÑ€ Ð°Ð±Ð¾ Ð·Ð¼Ñ–Ð½Ñ–Ñ‚ÑŒ \'Ð¢Ð¸Ð¿ API\' Ð½Ð° Ð¾Ñ„Ñ–Ñ†Ñ–Ð¹Ð½Ð¸Ð¹ YouTube API\n\nÐžÐ±Ð¾Ð²\'ÑÐ·ÐºÐ¾Ð²Ð¾ Ð¿ÐµÑ€ÐµÐ·Ð°Ð¿ÑƒÑÑ‚Ñ–Ñ‚ÑŒ Ð¿Ñ€Ð¾Ð³Ñ€Ð°Ð¼Ñƒ Ð¿Ñ–ÑÐ»Ñ Ð·Ð¼Ñ–Ð½Ð¸';
  }

  @override
  String get you_are_offline => 'Ð’Ð¸ Ð·Ð°Ñ€Ð°Ð· Ð½Ðµ Ð² Ð¼ÐµÑ€ÐµÐ¶Ñ–';

  @override
  String get connection_restored =>
      'Ð’Ð°ÑˆÐµ Ñ–Ð½Ñ‚ÐµÑ€Ð½ÐµÑ‚-Ð·\'Ñ”Ð´Ð½Ð°Ð½Ð½Ñ Ð²Ñ–Ð´Ð½Ð¾Ð²Ð»ÐµÐ½Ð¾';

  @override
  String get use_system_title_bar =>
      'Ð’Ð¸ÐºÐ¾Ñ€Ð¸ÑÑ‚Ð¾Ð²ÑƒÐ²Ð°Ñ‚Ð¸ ÑÐ¸ÑÑ‚ÐµÐ¼Ð½Ð¸Ð¹ Ð·Ð°Ð³Ð¾Ð»Ð¾Ð²Ð¾Ðº';

  @override
  String get crunching_results =>
      'ÐžÐ¿Ñ€Ð°Ñ†ÑŽÐ²Ð°Ð½Ð½Ñ Ñ€ÐµÐ·ÑƒÐ»ÑŒÑ‚Ð°Ñ‚Ñ–Ð²...';

  @override
  String get search_to_get_results =>
      'ÐŸÐ¾Ñ‡Ð½Ñ–Ñ‚ÑŒ Ð¿Ð¾ÑˆÑƒÐº, Ñ‰Ð¾Ð± Ð¾Ñ‚Ñ€Ð¸Ð¼Ð°Ñ‚Ð¸ Ñ€ÐµÐ·ÑƒÐ»ÑŒÑ‚Ð°Ñ‚Ð¸';

  @override
  String get use_amoled_mode => 'Ð ÐµÐ¶Ð¸Ð¼ AMOLED';

  @override
  String get pitch_dark_theme => 'Ð¢ÐµÐ¼Ð½Ð° Ñ‚ÐµÐ¼Ð°';

  @override
  String get normalize_audio => 'ÐÐ¾Ñ€Ð¼Ð°Ð»Ñ–Ð·ÑƒÐ²Ð°Ñ‚Ð¸ Ð·Ð²ÑƒÐº';

  @override
  String get change_cover => 'Ð—Ð¼Ñ–Ð½Ð¸Ñ‚Ð¸ Ð¾Ð±ÐºÐ»Ð°Ð´Ð¸Ð½ÐºÑƒ';

  @override
  String get add_cover => 'Ð”Ð¾Ð´Ð°Ñ‚Ð¸ Ð¾Ð±ÐºÐ»Ð°Ð´Ð¸Ð½ÐºÑƒ';

  @override
  String get restore_defaults =>
      'Ð’Ñ–Ð´Ð½Ð¾Ð²Ð¸Ñ‚Ð¸ Ð½Ð°Ð»Ð°ÑˆÑ‚ÑƒÐ²Ð°Ð½Ð½Ñ Ð·Ð° Ð·Ð°Ð¼Ð¾Ð²Ñ‡ÑƒÐ²Ð°Ð½Ð½ÑÐ¼';

  @override
  String get restore_defaults_confirmation =>
      'Ð¦Ðµ ÑÐºÐ¸Ð½Ðµ Ð²ÑÑ– Ð²Ð°ÑˆÑ– Ð½Ð°Ð»Ð°ÑˆÑ‚ÑƒÐ²Ð°Ð½Ð½Ñ Ð´Ð¾ Ð·Ð½Ð°Ñ‡ÐµÐ½ÑŒ Ð·Ð° Ð·Ð°Ð¼Ð¾Ð²Ñ‡ÑƒÐ²Ð°Ð½Ð½ÑÐ¼. Ð¦ÑŽ Ð´Ñ–ÑŽ Ð½ÐµÐ¼Ð¾Ð¶Ð»Ð¸Ð²Ð¾ ÑÐºÐ°ÑÑƒÐ²Ð°Ñ‚Ð¸.';

  @override
  String get streaming_music_format =>
      'Ð¤Ð¾Ñ€Ð¼Ð°Ñ‚ Ð¿Ð¾Ñ‚Ð¾ÐºÐ¾Ð²Ð¾Ñ— Ð¼ÑƒÐ·Ð¸ÐºÐ¸';

  @override
  String get streaming_music_quality =>
      'Ð¯ÐºÑ–ÑÑ‚ÑŒ Ð¿Ð¾Ñ‚Ð¾ÐºÐ¾Ð²Ð¾Ñ— Ð¼ÑƒÐ·Ð¸ÐºÐ¸';

  @override
  String get connect => 'ÐŸÑ–Ð´ÐºÐ»ÑŽÑ‡Ð¸Ñ‚Ð¸';

  @override
  String get disconnect => 'Ð’Ñ–Ð´ÐºÐ»ÑŽÑ‡Ð¸Ñ‚Ð¸';

  @override
  String get username => 'Ð†Ð¼\'Ñ ÐºÐ¾Ñ€Ð¸ÑÑ‚ÑƒÐ²Ð°Ñ‡Ð°';

  @override
  String get password => 'ÐŸÐ°Ñ€Ð¾Ð»ÑŒ';

  @override
  String get login => 'Ð£Ð²Ñ–Ð¹Ñ‚Ð¸';

  @override
  String get sign_in => 'Ð£Ð²Ñ–Ð¹Ñ‚Ð¸';

  @override
  String get sign_up => 'Ð—Ð°Ñ€ÐµÑ”ÑÑ‚Ñ€ÑƒÐ²Ð°Ñ‚Ð¸ÑÑŒ';

  @override
  String get sign_out => 'Ð’Ð¸Ð¹Ñ‚Ð¸';

  @override
  String get verify => 'ÐŸÑ–Ð´Ñ‚Ð²ÐµÑ€Ð´Ð¸Ñ‚Ð¸';

  @override
  String get create_account => 'Ð¡Ñ‚Ð²Ð¾Ñ€Ñ–Ñ‚ÑŒ ÑÐ²Ñ–Ð¹ Ð°ÐºÐ°ÑƒÐ½Ñ‚';

  @override
  String get already_have_account =>
      'Ð’Ð¶Ðµ Ð¼Ð°Ñ”Ñ‚Ðµ Ð°ÐºÐ°ÑƒÐ½Ñ‚? Ð£Ð²Ñ–Ð¹Ð´Ñ–Ñ‚ÑŒ';

  @override
  String get dont_have_account =>
      'ÐÐµÐ¼Ð°Ñ” Ð°ÐºÐ°ÑƒÐ½Ñ‚Ð°? Ð—Ð°Ñ€ÐµÑ”ÑÑ‚Ñ€ÑƒÐ¹Ñ‚ÐµÑÑŒ';

  @override
  String signed_in_as(Object userId) {
    return 'Ð’Ð¸ ÑƒÐ²Ñ–Ð¹ÑˆÐ»Ð¸ ÑÐº $userId';
  }

  @override
  String get verification_code => 'ÐšÐ¾Ð´ Ð¿Ñ–Ð´Ñ‚Ð²ÐµÑ€Ð´Ð¶ÐµÐ½Ð½Ñ';

  @override
  String get verification_code_hint =>
      'Ð’Ð²ÐµÐ´Ñ–Ñ‚ÑŒ ÐºÐ¾Ð´, Ð½Ð°Ð´Ñ–ÑÐ»Ð°Ð½Ð¸Ð¹ Ð½Ð° Ð²Ð°ÑˆÑƒ Ð¿Ð¾ÑˆÑ‚Ñƒ';

  @override
  String get verify_email_code =>
      'ÐœÐ¸ Ð½Ð°Ð´Ñ–ÑÐ»Ð°Ð»Ð¸ ÐºÐ¾Ð´ Ð¿Ñ–Ð´Ñ‚Ð²ÐµÑ€Ð´Ð¶ÐµÐ½Ð½Ñ Ð½Ð° Ð²Ð°ÑˆÑƒ Ð¿Ð¾ÑˆÑ‚Ñƒ';

  @override
  String get go_to_album => 'ÐŸÐµÑ€ÐµÐ¹Ñ‚Ð¸ Ð´Ð¾ Ð°Ð»ÑŒÐ±Ð¾Ð¼Ñƒ';

  @override
  String get discord_rich_presence =>
      'Ð‘Ð°Ð³Ð°Ñ‚Ð° Ð¿Ñ€Ð¸ÑÑƒÑ‚Ð½Ñ–ÑÑ‚ÑŒ Ñƒ Discord';

  @override
  String get browse_all => 'ÐŸÐµÑ€ÐµÐ³Ð»ÑÐ½ÑƒÑ‚Ð¸ Ð²ÑÐµ';

  @override
  String get genres => 'Ð–Ð°Ð½Ñ€Ð¸';

  @override
  String get explore_genres => 'Ð”Ð¾ÑÐ»Ñ–Ð´Ð¶ÑƒÐ²Ð°Ñ‚Ð¸ Ð¶Ð°Ð½Ñ€Ð¸';

  @override
  String get friends => 'Ð”Ñ€ÑƒÐ·Ñ–';

  @override
  String get no_lyrics_available =>
      'Ð’Ð¸Ð±Ð°Ñ‡Ñ‚Ðµ, Ð½Ðµ Ð²Ð´Ð°Ð»Ð¾ÑÑ Ð·Ð½Ð°Ð¹Ñ‚Ð¸ Ñ‚ÐµÐºÑÑ‚ Ð´Ð»Ñ Ñ†ÑŒÐ¾Ð³Ð¾ Ñ‚Ñ€ÐµÐºÑƒ';

  @override
  String get start_a_radio => 'Ð—Ð°Ð¿ÑƒÑÑ‚Ð¸Ñ‚Ð¸ Ñ€Ð°Ð´Ñ–Ð¾';

  @override
  String get how_to_start_radio =>
      'Ð¯Ðº Ð²Ð¸ Ñ…Ð¾Ñ‡ÐµÑ‚Ðµ Ð·Ð°Ð¿ÑƒÑÑ‚Ð¸Ñ‚Ð¸ Ñ€Ð°Ð´Ñ–Ð¾?';

  @override
  String get replace_queue_question =>
      'Ð’Ð¸ Ñ…Ð¾Ñ‡ÐµÑ‚Ðµ Ð·Ð°Ð¼Ñ–Ð½Ð¸Ñ‚Ð¸ Ð¿Ð¾Ñ‚Ð¾Ñ‡Ð½Ñƒ Ñ‡ÐµÑ€Ð³Ñƒ Ñ‡Ð¸ Ð´Ð¾Ð´Ð°Ñ‚Ð¸ Ð´Ð¾ Ð½ÐµÑ—?';

  @override
  String get endless_playback => 'Ð‘ÐµÐ·ÐºÑ–Ð½ÐµÑ‡Ð½Ðµ Ð²Ñ–Ð´Ñ‚Ð²Ð¾Ñ€ÐµÐ½Ð½Ñ';

  @override
  String get delete_playlist => 'Ð’Ð¸Ð´Ð°Ð»Ð¸Ñ‚Ð¸ Ð¿Ð»ÐµÐ¹Ð»Ð¸ÑÑ‚';

  @override
  String get delete_playlist_confirmation =>
      'Ð’Ð¸ Ð²Ð¿ÐµÐ²Ð½ÐµÐ½Ñ–, Ñ‰Ð¾ Ñ…Ð¾Ñ‡ÐµÑ‚Ðµ Ð²Ð¸Ð´Ð°Ð»Ð¸Ñ‚Ð¸ Ñ†ÐµÐ¹ Ð¿Ð»ÐµÐ¹Ð»Ð¸ÑÑ‚?';

  @override
  String get local_tracks => 'ÐœÑ–ÑÑ†ÐµÐ²Ñ– Ñ‚Ñ€ÐµÐºÐ¸';

  @override
  String get local_tab => 'ÐœÑ–ÑÑ†ÐµÐ²Ð¸Ð¹';

  @override
  String get song_link => 'ÐŸÐ¾ÑÐ¸Ð»Ð°Ð½Ð½Ñ Ð½Ð° Ð¿Ñ–ÑÐ½ÑŽ';

  @override
  String get skip_this_nonsense => 'ÐŸÑ€Ð¾Ð¿ÑƒÑÑ‚Ð¸Ñ‚Ð¸ Ñ†ÐµÐ¹ Ð±Ñ€ÐµÐ´';

  @override
  String get freedom_of_music => 'â€œÐ¡Ð²Ð¾Ð±Ð¾Ð´Ð° Ð¼ÑƒÐ·Ð¸ÐºÐ¸â€';

  @override
  String get freedom_of_music_palm =>
      'â€œÐ¡Ð²Ð¾Ð±Ð¾Ð´Ð° Ð¼ÑƒÐ·Ð¸ÐºÐ¸ Ñƒ Ð²Ð°ÑˆÑ–Ð¹ Ð´Ð¾Ð»Ð¾Ð½Ñ–â€';

  @override
  String get get_started => 'Ð”Ð°Ð²Ð°Ð¹Ñ‚Ðµ Ð¿Ð¾Ñ‡Ð½ÐµÐ¼Ð¾';

  @override
  String get youtube_source_description =>
      'Ð ÐµÐºÐ¾Ð¼ÐµÐ½Ð´Ð¾Ð²Ð°Ð½Ð¾ Ñ‚Ð° Ð¿Ñ€Ð°Ñ†ÑŽÑ” ÐºÑ€Ð°Ñ‰Ðµ Ð·Ð° Ð²ÑÐµ.';

  @override
  String get piped_source_description =>
      'Ð§Ð¸ Ð¿Ð¾Ñ‡ÑƒÐ²Ð°Ñ”Ñ‚Ðµ ÑÐµÐ±Ðµ Ð²Ñ–Ð»ÑŒÐ½Ð¾? Ð¢Ðµ ÑÐ°Ð¼Ðµ, Ñ‰Ð¾ Ñ– Ð½Ð° YouTube, Ð°Ð»Ðµ Ð½Ð°Ð±Ð°Ð³Ð°Ñ‚Ð¾ Ð±ÐµÐ·ÐºÐ¾ÑˆÑ‚Ð¾Ð²Ð½Ð¾.';

  @override
  String get jiosaavn_source_description =>
      'ÐÐ°Ð¹ÐºÑ€Ð°Ñ‰Ðµ Ð´Ð»Ñ Ñ€ÐµÐ³Ñ–Ð¾Ð½Ñƒ ÐŸÑ–Ð²Ð´ÐµÐ½Ð½Ð¾Ñ— ÐÐ·Ñ–Ñ—.';

  @override
  String get invidious_source_description =>
      'ÐŸÐ¾Ð´Ñ–Ð±Ð½Ð¸Ð¹ Ð´Ð¾ Piped, Ð°Ð»Ðµ Ð· Ð²Ð¸Ñ‰Ð¾ÑŽ Ð´Ð¾ÑÑ‚ÑƒÐ¿Ð½Ñ–ÑÑ‚ÑŽ.';

  @override
  String highest_quality(Object quality) {
    return 'ÐÐ°Ð¹Ð²Ð¸Ñ‰Ð° ÑÐºÑ–ÑÑ‚ÑŒ: $quality';
  }

  @override
  String get select_audio_source =>
      'Ð’Ð¸Ð±ÐµÑ€Ñ–Ñ‚ÑŒ Ð´Ð¶ÐµÑ€ÐµÐ»Ð¾ Ð°ÑƒÐ´Ñ–Ð¾';

  @override
  String get endless_playback_description =>
      'ÐÐ²Ñ‚Ð¾Ð¼Ð°Ñ‚Ð¸Ñ‡Ð½Ð¾ Ð´Ð¾Ð´Ð°Ð²Ð°Ñ‚Ð¸ Ð½Ð¾Ð²Ñ– Ð¿Ñ–ÑÐ½Ñ–\nÐ² ÐºÑ–Ð½ÐµÑ†ÑŒ Ñ‡ÐµÑ€Ð³Ð¸';

  @override
  String get choose_your_region => 'Ð’Ð¸Ð±ÐµÑ€Ñ–Ñ‚ÑŒ Ð²Ð°Ñˆ Ñ€ÐµÐ³Ñ–Ð¾Ð½';

  @override
  String get choose_your_region_description =>
      'Ð¦Ðµ Ð´Ð¾Ð¿Ð¾Ð¼Ð¾Ð¶Ðµ Soulful Bhakti Ð¿Ð¾ÐºÐ°Ð·Ð°Ñ‚Ð¸ Ð²Ð°Ð¼ Ð¿Ñ€Ð°Ð²Ð¸Ð»ÑŒÐ½Ð¸Ð¹ ÐºÐ¾Ð½Ñ‚ÐµÐ½Ñ‚\nÐ´Ð»Ñ Ð²Ð°ÑˆÐ¾Ð³Ð¾ Ð¼Ñ–ÑÑ†ÐµÐ·Ð½Ð°Ñ…Ð¾Ð´Ð¶ÐµÐ½Ð½Ñ.';

  @override
  String get choose_your_language => 'Ð’Ð¸Ð±ÐµÑ€Ñ–Ñ‚ÑŒ ÑÐ²Ð¾ÑŽ Ð¼Ð¾Ð²Ñƒ';

  @override
  String get help_project_grow =>
      'Ð”Ð¾Ð¿Ð¾Ð¼Ð¾Ð¶Ñ–Ñ‚ÑŒ Ñ†ÑŒÐ¾Ð¼Ñƒ Ð¿Ñ€Ð¾ÐµÐºÑ‚Ñƒ Ñ€Ð¾ÑÑ‚Ð¸';

  @override
  String get help_project_grow_description =>
      'Soulful Bhakti - Ñ†Ðµ Ð¿Ñ€Ð¾ÐµÐºÑ‚ Ð· Ð²Ñ–Ð´ÐºÑ€Ð¸Ñ‚Ð¸Ð¼ ÐºÐ¾Ð´Ð¾Ð¼. Ð’Ð¸ Ð¼Ð¾Ð¶ÐµÑ‚Ðµ Ð´Ð¾Ð¿Ð¾Ð¼Ð¾Ð³Ñ‚Ð¸ Ñ†ÑŒÐ¾Ð¼Ñƒ Ð¿Ñ€Ð¾ÐµÐºÑ‚Ñƒ Ð·Ñ€Ð¾ÑÑ‚Ð°Ñ‚Ð¸, Ð²Ð½Ð¾ÑÑÑ‡Ð¸ ÑÐ²Ñ–Ð¹ Ð²Ð½ÐµÑÐ¾Ðº Ñƒ Ð¿Ñ€Ð¾ÐµÐºÑ‚, Ð¿Ð¾Ð²Ñ–Ð´Ð¾Ð¼Ð»ÑÑŽÑ‡Ð¸ Ð¿Ñ€Ð¾ Ð¿Ð¾Ð¼Ð¸Ð»ÐºÐ¸ Ð°Ð±Ð¾ Ð¿Ñ€Ð¾Ð¿Ð¾Ð½ÑƒÑŽÑ‡Ð¸ Ð½Ð¾Ð²Ñ– Ñ„ÑƒÐ½ÐºÑ†Ñ–Ñ—.';

  @override
  String get contribute_on_github => 'Ð”Ð¾Ð»ÑƒÑ‡Ð°Ð¹Ñ‚ÐµÑÑŒ Ð½Ð° GitHub';

  @override
  String get donate_on_open_collective =>
      'ÐŸÐ¾Ð¶ÐµÑ€Ñ‚Ð²ÑƒÐ¹Ñ‚Ðµ Ð½Ð° Open Collective';

  @override
  String get browse_anonymously => 'ÐÐ½Ð¾Ð½Ñ–Ð¼Ð½Ð¾ Ð¿ÐµÑ€ÐµÐ³Ð»ÑÐ´Ð°Ñ‚Ð¸';

  @override
  String get enable_connect => 'Ð£Ð²Ñ–Ð¼ÐºÐ½ÑƒÑ‚Ð¸ Ð¿Ñ–Ð´ÐºÐ»ÑŽÑ‡ÐµÐ½Ð½Ñ';

  @override
  String get enable_connect_description =>
      'ÐšÐµÑ€ÑƒÐ¹Ñ‚Ðµ Soulful Bhakti Ð· Ñ–Ð½ÑˆÐ¸Ñ… Ð¿Ñ€Ð¸ÑÑ‚Ñ€Ð¾Ñ—Ð²';

  @override
  String get devices => 'ÐŸÑ€Ð¸ÑÑ‚Ñ€Ð¾Ñ—';

  @override
  String get select => 'Ð’Ð¸Ð±Ñ€Ð°Ñ‚Ð¸';

  @override
  String connect_client_alert(Object client) {
    return 'Ð’Ð°Ñ ÐºÐµÑ€ÑƒÑ” $client';
  }

  @override
  String get this_device => 'Ð¦ÐµÐ¹ Ð¿Ñ€Ð¸ÑÑ‚Ñ€Ñ–Ð¹';

  @override
  String get remote => 'Ð’Ñ–Ð´Ð´Ð°Ð»ÐµÐ½Ð¸Ð¹';

  @override
  String get stats => 'Ð¡Ñ‚Ð°Ñ‚Ð¸ÑÑ‚Ð¸ÐºÐ°';

  @override
  String and_n_more(Object count) {
    return 'Ñ– $count Ð±Ñ–Ð»ÑŒÑˆÐµ';
  }

  @override
  String get recently_played => 'ÐÐµÑ‰Ð¾Ð´Ð°Ð²Ð½Ð¾ Ð’Ñ–Ð´Ñ‚Ð²Ð¾Ñ€ÐµÐ½Ðµ';

  @override
  String get browse_more => 'ÐŸÐµÑ€ÐµÐ³Ð»ÑÐ½ÑƒÑ‚Ð¸ Ð‘Ñ–Ð»ÑŒÑˆÐµ';

  @override
  String get no_title => 'Ð‘ÐµÐ· ÐÐ°Ð·Ð²Ð¸';

  @override
  String get not_playing => 'ÐÐµ Ð’Ñ–Ð´Ñ‚Ð²Ð¾Ñ€ÑŽÑ”Ñ‚ÑŒÑÑ';

  @override
  String get epic_failure => 'Ð•Ð¿Ñ–Ñ‡Ð½Ð¸Ð¹ Ð¿Ñ€Ð¾Ð²Ð°Ð»!';

  @override
  String added_num_tracks_to_queue(Object tracks_length) {
    return 'Ð”Ð¾Ð´Ð°Ð½Ð¾ $tracks_length Ñ‚Ñ€ÐµÐºÑ–Ð² Ð´Ð¾ Ñ‡ÐµÑ€Ð³Ð¸';
  }

  @override
  String get spotube_has_an_update =>
      'Soulful Bhakti Ð¼Ð°Ñ” Ð¾Ð½Ð¾Ð²Ð»ÐµÐ½Ð½Ñ';

  @override
  String get download_now => 'Ð—Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶Ð¸Ñ‚Ð¸ Ð—Ð°Ñ€Ð°Ð·';

  @override
  String nightly_version(Object nightlyBuildNum) {
    return 'Soulful Bhakti Nightly $nightlyBuildNum Ð±ÑƒÐ»Ð¾ Ð²Ð¸Ð¿ÑƒÑ‰ÐµÐ½Ð¾';
  }

  @override
  String release_version(Object version) {
    return 'Soulful Bhakti v$version Ð±ÑƒÐ»Ð¾ Ð²Ð¸Ð¿ÑƒÑ‰ÐµÐ½Ð¾';
  }

  @override
  String get read_the_latest => 'Ð§Ð¸Ñ‚Ð°Ñ‚Ð¸ Ð¾ÑÑ‚Ð°Ð½Ð½Ñ– Ð½Ð¾Ð²Ð¸Ð½Ð¸';

  @override
  String get release_notes => 'Ð½Ð¾Ñ‚Ð¸ Ð¿Ñ€Ð¾ Ð²Ð¸Ð¿ÑƒÑÐº';

  @override
  String get pick_color_scheme =>
      'ÐžÐ±ÐµÑ€Ñ–Ñ‚ÑŒ ÐºÐ¾Ð»ÑŒÐ¾Ñ€Ð¾Ð²Ñƒ ÑÑ…ÐµÐ¼Ñƒ';

  @override
  String get save => 'Ð—Ð±ÐµÑ€ÐµÐ³Ñ‚Ð¸';

  @override
  String get choose_the_device => 'Ð’Ð¸Ð±ÐµÑ€Ñ–Ñ‚ÑŒ Ð¿Ñ€Ð¸ÑÑ‚Ñ€Ñ–Ð¹:';

  @override
  String get multiple_device_connected =>
      'ÐŸÑ–Ð´ÐºÐ»ÑŽÑ‡ÐµÐ½Ð¾ ÐºÑ–Ð»ÑŒÐºÐ° Ð¿Ñ€Ð¸ÑÑ‚Ñ€Ð¾Ñ—Ð².\nÐ’Ð¸Ð±ÐµÑ€Ñ–Ñ‚ÑŒ Ð¿Ñ€Ð¸ÑÑ‚Ñ€Ñ–Ð¹, Ð½Ð° ÑÐºÐ¾Ð¼Ñƒ Ð²Ð¸ Ñ…Ð¾Ñ‡ÐµÑ‚Ðµ Ð²Ð¸ÐºÐ¾Ð½Ð°Ñ‚Ð¸ Ñ†ÑŽ Ð´Ñ–ÑŽ';

  @override
  String get nothing_found => 'ÐÑ–Ñ‡Ð¾Ð³Ð¾ Ð½Ðµ Ð·Ð½Ð°Ð¹Ð´ÐµÐ½Ð¾';

  @override
  String get the_box_is_empty => 'ÐšÐ¾Ñ€Ð¾Ð±ÐºÐ° Ð¿Ð¾Ñ€Ð¾Ð¶Ð½Ñ';

  @override
  String get top_artists => 'Ð¢Ð¾Ð¿ ÐÑ€Ñ‚Ð¸ÑÑ‚Ð¸';

  @override
  String get top_albums => 'Ð¢Ð¾Ð¿ ÐÐ»ÑŒÐ±Ð¾Ð¼Ð¸';

  @override
  String get this_week => 'Ð¦ÑŒÐ¾Ð³Ð¾ Ñ‚Ð¸Ð¶Ð½Ñ';

  @override
  String get this_month => 'Ð¦ÑŒÐ¾Ð³Ð¾ Ð¼Ñ–ÑÑÑ†Ñ';

  @override
  String get last_6_months => 'ÐžÑÑ‚Ð°Ð½Ð½Ñ– 6 Ð¼Ñ–ÑÑÑ†Ñ–Ð²';

  @override
  String get this_year => 'Ð¦ÑŒÐ¾Ð³Ð¾ Ñ€Ð¾ÐºÑƒ';

  @override
  String get last_2_years => 'ÐžÑÑ‚Ð°Ð½Ð½Ñ– 2 Ñ€Ð¾ÐºÐ¸';

  @override
  String get all_time => 'Ð£ÑÑ– Ñ‡Ð°ÑÐ¸';

  @override
  String powered_by_provider(Object providerName) {
    return 'Ð—Ð°Ð±ÐµÐ·Ð¿ÐµÑ‡ÐµÐ½Ð¾ $providerName';
  }

  @override
  String get email => 'Ð•Ð»ÐµÐºÑ‚Ñ€Ð¾Ð½Ð½Ð° Ð¿Ð¾ÑˆÑ‚Ð°';

  @override
  String get send_code => 'ÐÐ°Ð´Ñ–ÑÐ»Ð°Ñ‚Ð¸ ÐºÐ¾Ð´';

  @override
  String get change_identifier => 'Ð’Ð¸ÐºÐ¾Ñ€Ð¸ÑÑ‚Ð°Ñ‚Ð¸ Ñ–Ð½ÑˆÐ¸Ð¹ email';

  @override
  String get sign_in_with_otp =>
      'Ð£Ð²Ñ–Ð¹Ñ‚Ð¸ Ð· Ð¾Ð´Ð½Ð¾Ñ€Ð°Ð·Ð¾Ð²Ð¸Ð¼ ÐºÐ¾Ð´Ð¾Ð¼';

  @override
  String get enter_otp_sent =>
      'Ð’Ð²ÐµÐ´Ñ–Ñ‚ÑŒ ÐºÐ¾Ð´, ÑÐºÐ¸Ð¹ Ð¼Ð¸ Ð²Ð°Ð¼ Ð½Ð°Ð´Ñ–ÑÐ»Ð°Ð»Ð¸';

  @override
  String get verify_email_reminder =>
      'Ð‘ÑƒÐ´ÑŒ Ð»Ð°ÑÐºÐ°, Ð¿Ñ–Ð´Ñ‚Ð²ÐµÑ€Ð´ÑŒÑ‚Ðµ ÑÐ²Ð¾ÑŽ ÐµÐ»ÐµÐºÑ‚Ñ€Ð¾Ð½Ð½Ñƒ Ð¿Ð¾ÑˆÑ‚Ñƒ, Ñ‰Ð¾Ð± Ð·Ð°Ñ…Ð¸ÑÑ‚Ð¸Ñ‚Ð¸ Ð°ÐºÐ°ÑƒÐ½Ñ‚';

  @override
  String get verify_now => 'ÐŸÑ–Ð´Ñ‚Ð²ÐµÑ€Ð´Ð¸Ñ‚Ð¸ Ð·Ð°Ñ€Ð°Ð·';

  @override
  String get enter_email_to_verify =>
      'Ð’Ð²ÐµÐ´Ñ–Ñ‚ÑŒ ÑÐ²Ð¾ÑŽ ÐµÐ»ÐµÐºÑ‚Ñ€Ð¾Ð½Ð½Ñƒ Ð¿Ð¾ÑˆÑ‚Ñƒ, Ñ‰Ð¾Ð± Ð¾Ñ‚Ñ€Ð¸Ð¼Ð°Ñ‚Ð¸ ÐºÐ¾Ð´ Ð¿Ñ–Ð´Ñ‚Ð²ÐµÑ€Ð´Ð¶ÐµÐ½Ð½Ñ';

  @override
  String get profile_followers => 'ÐŸÑ–Ð´Ð¿Ð¸ÑÐ½Ð¸ÐºÐ¸';

  @override
  String get birthday => 'Ð”ÐµÐ½ÑŒ Ð½Ð°Ñ€Ð¾Ð´Ð¶ÐµÐ½Ð½Ñ';

  @override
  String get subscription => 'ÐŸÑ–Ð´Ð¿Ð¸ÑÐºÐ°';

  @override
  String get not_born => 'Ð©Ðµ Ð½Ðµ Ð½Ð°Ñ€Ð¾Ð´Ð¶ÐµÐ½Ð¸Ð¹';

  @override
  String get hacker => 'Ð¥Ð°ÐºÐµÑ€';

  @override
  String get profile => 'ÐŸÑ€Ð¾Ñ„Ñ–Ð»ÑŒ';

  @override
  String get no_name => 'Ð‘ÐµÐ· Ñ–Ð¼ÐµÐ½Ñ–';

  @override
  String get edit => 'Ð ÐµÐ´Ð°Ð³ÑƒÐ²Ð°Ñ‚Ð¸';

  @override
  String get user_profile => 'ÐŸÑ€Ð¾Ñ„Ñ–Ð»ÑŒ ÐºÐ¾Ñ€Ð¸ÑÑ‚ÑƒÐ²Ð°Ñ‡Ð°';

  @override
  String count_plays(Object count) {
    return '$count Ð²Ñ–Ð´Ñ‚Ð²Ð¾Ñ€ÐµÐ½ÑŒ';
  }

  @override
  String get streaming_fees_hypothetical =>
      '*Ð Ð¾Ð·Ñ€Ð°Ñ…Ð¾Ð²Ð°Ð½Ð¾ Ð½Ð° Ð¾ÑÐ½Ð¾Ð²Ñ– Ð²Ð¸Ð¿Ð»Ð°Ñ‚ Spotify Ð·Ð° ÑÑ‚Ñ€Ð¸Ð¼Ñ–Ð½Ð³\nÐ²Ñ–Ð´ \$0.003 Ð´Ð¾ \$0.005. Ð¦Ðµ Ð³Ñ–Ð¿Ð¾Ñ‚ÐµÑ‚Ð¸Ñ‡Ð½Ð¸Ð¹\nÑ€Ð¾Ð·Ñ€Ð°Ñ…ÑƒÐ½Ð¾Ðº, Ñ‰Ð¾Ð± Ð´Ð°Ñ‚Ð¸ ÑƒÑÐ²Ð»ÐµÐ½Ð½Ñ ÐºÐ¾Ñ€Ð¸ÑÑ‚ÑƒÐ²Ð°Ñ‡Ñƒ Ð¿Ñ€Ð¾ Ñ‚Ðµ, ÑÐºÑ–Ð»ÑŒÐºÐ¸ Ð± Ð²Ñ–Ð½\nÐ·Ð°Ð¿Ð»Ð°Ñ‚Ð¸Ð² Ð°Ñ€Ñ‚Ð¸ÑÑ‚Ð°Ð¼, ÑÐºÐ±Ð¸ ÑÐ»ÑƒÑ…Ð°Ð² Ñ—Ñ…Ð½Ñ– Ð¿Ñ–ÑÐ½Ñ– Ð½Ð° Spotify.';

  @override
  String get minutes_listened =>
      'Ð¥Ð²Ð¸Ð»Ð¸Ð½Ð¸ Ð¿Ñ€Ð¾ÑÐ»ÑƒÑ…Ð¾Ð²ÑƒÐ²Ð°Ð½Ð½Ñ';

  @override
  String get streamed_songs => 'Ð¡Ñ‚Ñ€Ð¸Ð¼Ð»ÐµÐ½Ñ– Ð¿Ñ–ÑÐ½Ñ–';

  @override
  String count_streams(Object count) {
    return '$count ÑÑ‚Ñ€Ð¸Ð¼Ñ–Ð²';
  }

  @override
  String get owned_by_you => 'Ð’Ð°ÑˆÐ° Ð²Ð»Ð°ÑÐ½Ñ–ÑÑ‚ÑŒ';

  @override
  String copied_shareurl_to_clipboard(Object shareUrl) {
    return '$shareUrl ÑÐºÐ¾Ð¿Ñ–Ð¹Ð¾Ð²Ð°Ð½Ð¾ Ð² Ð±ÑƒÑ„ÐµÑ€ Ð¾Ð±Ð¼Ñ–Ð½Ñƒ';
  }

  @override
  String get hipotetical_calculation =>
      '*Ð¦Ðµ Ñ€Ð¾Ð·Ñ€Ð°Ñ…Ð¾Ð²Ð°Ð½Ð¾ Ð½Ð° Ð¾ÑÐ½Ð¾Ð²Ñ– ÑÐµÑ€ÐµÐ´Ð½ÑŒÐ¾Ñ— Ð²Ð¸Ð¿Ð»Ð°Ñ‚Ð¸ Ð·Ð° ÑÑ‚Ñ€Ñ–Ð¼ Ð¾Ð½Ð»Ð°Ð¹Ð½-Ð¿Ð»Ð°Ñ‚Ñ„Ð¾Ñ€Ð¼ Ð´Ð»Ñ Ð¿Ð¾Ñ‚Ð¾ÐºÐ¾Ð²Ð¾Ð³Ð¾ Ð²Ñ–Ð´Ñ‚Ð²Ð¾Ñ€ÐµÐ½Ð½Ñ Ð¼ÑƒÐ·Ð¸ÐºÐ¸, Ñ‰Ð¾ ÑÑ‚Ð°Ð½Ð¾Ð²Ð¸Ñ‚ÑŒ Ð²Ñ–Ð´ \$0,003 Ð´Ð¾ \$0,005. Ð¦Ðµ Ð³Ñ–Ð¿Ð¾Ñ‚ÐµÑ‚Ð¸Ñ‡Ð½Ð¸Ð¹ Ñ€Ð¾Ð·Ñ€Ð°Ñ…ÑƒÐ½Ð¾Ðº, Ñ‰Ð¾Ð± Ð´Ð°Ñ‚Ð¸ ÐºÐ¾Ñ€Ð¸ÑÑ‚ÑƒÐ²Ð°Ñ‡ÐµÐ²Ñ– ÑƒÑÐ²Ð»ÐµÐ½Ð½Ñ Ð¿Ñ€Ð¾ Ñ‚Ðµ, ÑÐºÑ–Ð»ÑŒÐºÐ¸ Ð± Ð²Ð¾Ð½Ð¸ Ð·Ð°Ð¿Ð»Ð°Ñ‚Ð¸Ð»Ð¸ Ð°Ñ€Ñ‚Ð¸ÑÑ‚Ð°Ð¼, ÑÐºÑ‰Ð¾ Ð± ÑÐ»ÑƒÑ…Ð°Ð»Ð¸ Ñ—Ñ…Ð½Ñ– Ð¿Ñ–ÑÐ½Ñ– Ð½Ð° Ñ€Ñ–Ð·Ð½Ð¸Ñ… Ð¼ÑƒÐ·Ð¸Ñ‡Ð½Ð¸Ñ… ÑÑ‚Ñ€Ñ–Ð¼Ñ–Ð½Ð³Ð¾Ð²Ð¸Ñ… Ð¿Ð»Ð°Ñ‚Ñ„Ð¾Ñ€Ð¼Ð°Ñ….';

  @override
  String count_mins(Object minutes) {
    return '$minutes Ñ…Ð²';
  }

  @override
  String get summary_minutes => 'Ñ…Ð²Ð¸Ð»Ð¸Ð½Ð¸';

  @override
  String get summary_listened_to_music => 'ÐŸÑ€Ð¾ÑÐ»ÑƒÑ…Ð°Ð½Ð° Ð¼ÑƒÐ·Ð¸ÐºÐ°';

  @override
  String get summary_songs => 'Ð¿Ñ–ÑÐ½Ñ–';

  @override
  String get summary_streamed_overall => 'Ð—Ð°Ð³Ð°Ð»Ð¾Ð¼ ÑÑ‚Ñ€Ð¸Ð¼Ñ–Ð²';

  @override
  String get summary_owed_to_artists =>
      'Ð—Ð°Ð±Ð¾Ñ€Ð³Ð¾Ð²Ð°Ð½Ñ–ÑÑ‚ÑŒ Ð°Ñ€Ñ‚Ð¸ÑÑ‚Ð°Ð¼\nÑ†ÑŒÐ¾Ð³Ð¾ Ð¼Ñ–ÑÑÑ†Ñ';

  @override
  String get summary_top_artist =>
      'ÐšÑ€Ð°Ñ‰Ð¸Ð¹ Ð°Ñ€Ñ‚Ð¸ÑÑ‚\nÐ·Ð° Ñ†ÐµÐ¹ Ð¿ÐµÑ€Ñ–Ð¾Ð´';

  @override
  String get summary_artists => 'Ð°Ñ€Ñ‚Ð¸ÑÑ‚Ñ–Ð²';

  @override
  String get summary_music_reached_you => 'ÐœÑƒÐ·Ð¸ÐºÐ° Ð´Ð¾ÑÑÐ³Ð»Ð° Ð²Ð°Ñ';

  @override
  String get summary_full_albums => 'Ð¿Ð¾Ð²Ð½Ñ– Ð°Ð»ÑŒÐ±Ð¾Ð¼Ð¸';

  @override
  String get summary_got_your_love => 'ÐžÑ‚Ñ€Ð¸Ð¼Ð°Ð² Ð²Ð°ÑˆÑƒ Ð»ÑŽÐ±Ð¾Ð²';

  @override
  String get summary_playlists => 'Ð¿Ð»ÐµÐ¹Ð»Ð¸ÑÑ‚Ð¸';

  @override
  String get summary_were_on_repeat => 'Ð‘ÑƒÐ»Ð¸ Ð½Ð° Ð¿Ð¾Ð²Ñ‚Ð¾Ñ€Ñ–';

  @override
  String get summary_listening_share =>
      'Ð§Ð°ÑÑ‚ÐºÐ° Ð¿Ñ€Ð¾ÑÐ»ÑƒÑ…Ð¾Ð²ÑƒÐ²Ð°Ð½Ð½Ñ';

  @override
  String summary_listening_share_description(Object tracks_length) {
    return 'Ð Ð¾Ð·Ð¿Ð¾Ð´Ñ–Ð» $tracks_length Ñ‚Ñ€ÐµÐºÑ–Ð², ÑÐºÑ– Ð²Ð¸ ÑÐ»ÑƒÑ…Ð°Ð»Ð¸ Ð½Ð°Ð¹Ñ‡Ð°ÑÑ‚Ñ–ÑˆÐµ';
  }

  @override
  String get summary_plays => 'Ð²Ñ–Ð´Ñ‚Ð²Ð¾Ñ€ÐµÐ½ÑŒ';

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
    return 'Ð—Ð°Ð³Ð°Ð»Ð¾Ð¼ $money';
  }

  @override
  String get webview_not_found => 'Webview Ð½Ðµ Ð·Ð½Ð°Ð¹Ð´ÐµÐ½Ð¾';

  @override
  String get webview_not_found_description =>
      'ÐÐ° Ð²Ð°ÑˆÐ¾Ð¼Ñƒ Ð¿Ñ€Ð¸ÑÑ‚Ñ€Ð¾Ñ— Ð½Ðµ Ð²ÑÑ‚Ð°Ð½Ð¾Ð²Ð»ÐµÐ½Ð¾ Ð²Ð¸ÐºÐ¾Ð½ÑƒÐ²Ð°Ð½Ðµ ÑÐµÑ€ÐµÐ´Ð¾Ð²Ð¸Ñ‰Ðµ Webview.\nÐ¯ÐºÑ‰Ð¾ Ð²Ð¾Ð½Ð¾ Ð²ÑÑ‚Ð°Ð½Ð¾Ð²Ð»ÐµÐ½Ð¾, Ð¿ÐµÑ€ÐµÐºÐ¾Ð½Ð°Ð¹Ñ‚ÐµÑÑ, Ñ‰Ð¾ Ð²Ð¾Ð½Ð¾ Ð·Ð½Ð°Ñ…Ð¾Ð´Ð¸Ñ‚ÑŒÑÑ Ð² environment PATH\n\nÐŸÑ–ÑÐ»Ñ Ð²ÑÑ‚Ð°Ð½Ð¾Ð²Ð»ÐµÐ½Ð½Ñ Ð¿ÐµÑ€ÐµÐ·Ð°Ð¿ÑƒÑÑ‚Ñ–Ñ‚ÑŒ Ð¿Ñ€Ð¾Ð³Ñ€Ð°Ð¼Ñƒ';

  @override
  String get unsupported_platform =>
      'ÐÐµÐ¿Ñ–Ð´Ñ‚Ñ€Ð¸Ð¼ÑƒÐ²Ð°Ð½Ð° Ð¿Ð»Ð°Ñ‚Ñ„Ð¾Ñ€Ð¼Ð°';

  @override
  String get cache_music => 'ÐšÐµÑˆÑƒÐ²Ð°Ñ‚Ð¸ Ð¼ÑƒÐ·Ð¸ÐºÑƒ';

  @override
  String get open => 'Ð’Ñ–Ð´ÐºÑ€Ð¸Ñ‚Ð¸';

  @override
  String get cache_folder => 'Ð¢ÐµÐºÐ° ÐºÐµÑˆÑƒ';

  @override
  String get export => 'Ð•ÐºÑÐ¿Ð¾Ñ€Ñ‚';

  @override
  String get clear_cache => 'ÐžÑ‡Ð¸ÑÑ‚Ð¸Ñ‚Ð¸ ÐºÐµÑˆ';

  @override
  String get clear_cache_confirmation =>
      'Ð’Ð¸ Ñ…Ð¾Ñ‡ÐµÑ‚Ðµ Ð¾Ñ‡Ð¸ÑÑ‚Ð¸Ñ‚Ð¸ ÐºÐµÑˆ?';

  @override
  String get export_cache_files =>
      'Ð•ÐºÑÐ¿Ð¾Ñ€Ñ‚ÑƒÐ²Ð°Ñ‚Ð¸ ÐºÐµÑˆÐ¾Ð²Ð°Ð½Ñ– Ñ„Ð°Ð¹Ð»Ð¸';

  @override
  String found_n_files(Object count) {
    return 'Ð—Ð½Ð°Ð¹Ð´ÐµÐ½Ð¾ $count Ñ„Ð°Ð¹Ð»Ñ–Ð²';
  }

  @override
  String get export_cache_confirmation =>
      'Ð’Ð¸ Ñ…Ð¾Ñ‡ÐµÑ‚Ðµ ÐµÐºÑÐ¿Ð¾Ñ€Ñ‚ÑƒÐ²Ð°Ñ‚Ð¸ Ñ†Ñ– Ñ„Ð°Ð¹Ð»Ð¸ Ð´Ð¾';

  @override
  String exported_n_out_of_m_files(Object files, Object filesExported) {
    return 'Ð•ÐºÑÐ¿Ð¾Ñ€Ñ‚Ð¾Ð²Ð°Ð½Ð¾ $filesExported Ð· $files Ñ„Ð°Ð¹Ð»Ñ–Ð²';
  }

  @override
  String get undo => 'Ð¡ÐºÐ°ÑÑƒÐ²Ð°Ñ‚Ð¸';

  @override
  String get add_all_to_playlist =>
      'Ð”Ð¾Ð´Ð°Ñ‚Ð¸ Ð²ÑÐµ Ð´Ð¾ Ð¿Ð»ÐµÐ¹Ð»Ð¸ÑÑ‚Ð°';

  @override
  String get add_all_to_queue => 'Ð”Ð¾Ð´Ð°Ñ‚Ð¸ Ð²ÑÐµ Ð² Ñ‡ÐµÑ€Ð³Ñƒ';

  @override
  String get play_all_next => 'Ð’Ñ–Ð´Ñ‚Ð²Ð¾Ñ€Ð¸Ñ‚Ð¸ Ð²ÑÐµ Ð½Ð°ÑÑ‚ÑƒÐ¿Ð½Ðµ';

  @override
  String get pause => 'ÐŸÐ°ÑƒÐ·Ð°';

  @override
  String get view_all => 'ÐŸÐµÑ€ÐµÐ³Ð»ÑÐ½ÑƒÑ‚Ð¸ Ð²ÑÐµ';

  @override
  String get no_tracks_added_yet =>
      'Ð—Ð´Ð°Ñ”Ñ‚ÑŒÑÑ, Ð²Ð¸ Ñ‰Ðµ Ð½Ðµ Ð´Ð¾Ð´Ð°Ð»Ð¸ Ð¶Ð¾Ð´Ð½Ð¾Ñ— Ð¿Ñ–ÑÐ½Ñ–';

  @override
  String get no_tracks => 'Ð—Ð´Ð°Ñ”Ñ‚ÑŒÑÑ, Ñ‚ÑƒÑ‚ Ð½ÐµÐ¼Ð°Ñ” Ð¿Ñ–ÑÐµÐ½ÑŒ';

  @override
  String get no_tracks_listened_yet =>
      'Ð—Ð´Ð°Ñ”Ñ‚ÑŒÑÑ, Ð²Ð¸ Ñ‰Ðµ Ð½Ñ–Ñ‡Ð¾Ð³Ð¾ Ð½Ðµ ÑÐ»ÑƒÑ…Ð°Ð»Ð¸';

  @override
  String get not_following_artists =>
      'Ð’Ð¸ Ð½Ðµ Ð¿Ñ–Ð´Ð¿Ð¸ÑÐ°Ð½Ñ– Ð½Ð° Ð¶Ð¾Ð´Ð½Ð¾Ð³Ð¾ Ð°Ñ€Ñ‚Ð¸ÑÑ‚Ð°';

  @override
  String get no_favorite_albums_yet =>
      'Ð—Ð´Ð°Ñ”Ñ‚ÑŒÑÑ, Ð²Ð¸ Ñ‰Ðµ Ð½Ðµ Ð´Ð¾Ð´Ð°Ð»Ð¸ Ð¶Ð¾Ð´Ð½Ð¾Ð³Ð¾ Ð°Ð»ÑŒÐ±Ð¾Ð¼Ñƒ Ð² ÑƒÐ»ÑŽÐ±Ð»ÐµÐ½Ñ–';

  @override
  String get no_logs_found =>
      'Ð–Ð¾Ð´Ð½Ð¸Ñ… Ð¶ÑƒÑ€Ð½Ð°Ð»Ñ–Ð² Ð½Ðµ Ð·Ð½Ð°Ð¹Ð´ÐµÐ½Ð¾';

  @override
  String get youtube_engine => 'YouTube Ð”Ð²Ð¸Ð³ÑƒÐ½';

  @override
  String youtube_engine_not_installed_title(Object engine) {
    return '$engine Ð½Ðµ Ð²ÑÑ‚Ð°Ð½Ð¾Ð²Ð»ÐµÐ½Ð¾';
  }

  @override
  String youtube_engine_not_installed_message(Object engine) {
    return '$engine Ð½Ðµ Ð²ÑÑ‚Ð°Ð½Ð¾Ð²Ð»ÐµÐ½Ð¾ Ð½Ð° Ð²Ð°ÑˆÑ–Ð¹ ÑÐ¸ÑÑ‚ÐµÐ¼Ñ–.';
  }

  @override
  String youtube_engine_set_path(Object engine) {
    return 'ÐŸÐµÑ€ÐµÐºÐ¾Ð½Ð°Ð¹Ñ‚ÐµÑÑŒ, Ñ‰Ð¾ Ð²Ñ–Ð½ Ð´Ð¾ÑÑ‚ÑƒÐ¿Ð½Ð¸Ð¹ Ñƒ Ð·Ð¼Ñ–Ð½Ð½Ñ–Ð¹ PATH Ð°Ð±Ð¾\nÐ²ÑÑ‚Ð°Ð½Ð¾Ð²Ñ–Ñ‚ÑŒ Ð°Ð±ÑÐ¾Ð»ÑŽÑ‚Ð½Ð¸Ð¹ ÑˆÐ»ÑÑ… Ð´Ð¾ Ð²Ð¸ÐºÐ¾Ð½ÑƒÐ²Ð°Ð½Ð¾Ð³Ð¾ Ñ„Ð°Ð¹Ð»Ñƒ $engine Ð½Ð¸Ð¶Ñ‡Ðµ';
  }

  @override
  String get youtube_engine_unix_issue_message =>
      'Ð£ macOS/Linux/Unix-Ð¿Ð¾Ð´Ñ–Ð±Ð½Ð¸Ñ… ÐžÐ¡, Ð²ÑÑ‚Ð°Ð½Ð¾Ð²Ð»ÐµÐ½Ð½Ñ ÑˆÐ»ÑÑ…Ñƒ Ð² .zshrc/.bashrc/.bash_profile Ñ‚Ð¾Ñ‰Ð¾ Ð½Ðµ Ð¿Ñ€Ð°Ñ†ÑŽÑ”.\nÐ’Ð°Ð¼ Ð¿Ð¾Ñ‚Ñ€Ñ–Ð±Ð½Ð¾ Ð½Ð°Ð»Ð°ÑˆÑ‚ÑƒÐ²Ð°Ñ‚Ð¸ ÑˆÐ»ÑÑ… Ñƒ Ñ„Ð°Ð¹Ð»Ñ– ÐºÐ¾Ð½Ñ„Ñ–Ð³ÑƒÑ€Ð°Ñ†Ñ–Ñ— Ð¾Ð±Ð¾Ð»Ð¾Ð½ÐºÐ¸';

  @override
  String get download => 'Ð—Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶Ð¸Ñ‚Ð¸';

  @override
  String get file_not_found => 'Ð¤Ð°Ð¹Ð» Ð½Ðµ Ð·Ð½Ð°Ð¹Ð´ÐµÐ½Ð¾';

  @override
  String get custom => 'ÐšÐ¾Ñ€Ð¸ÑÑ‚ÑƒÐ²Ð°Ñ†ÑŒÐºÐ¸Ð¹';

  @override
  String get add_custom_url => 'Ð”Ð¾Ð´Ð°Ñ‚Ð¸ ÐºÐ¾Ñ€Ð¸ÑÑ‚ÑƒÐ²Ð°Ñ†ÑŒÐºÐ¸Ð¹ URL';

  @override
  String get edit_port => 'Ð ÐµÐ´Ð°Ð³ÑƒÐ²Ð°Ñ‚Ð¸ Ð¿Ð¾Ñ€Ñ‚';

  @override
  String get port_helper_msg =>
      'Ð—Ð° Ð·Ð°Ð¼Ð¾Ð²Ñ‡ÑƒÐ²Ð°Ð½Ð½ÑÐ¼ -1, Ñ‰Ð¾ Ð¾Ð·Ð½Ð°Ñ‡Ð°Ñ” Ð²Ð¸Ð¿Ð°Ð´ÐºÐ¾Ð²Ðµ Ñ‡Ð¸ÑÐ»Ð¾. Ð¯ÐºÑ‰Ð¾ Ñƒ Ð²Ð°Ñ Ð½Ð°Ð»Ð°ÑˆÑ‚Ð¾Ð²Ð°Ð½Ð¸Ð¹ Ð±Ñ€Ð°Ð½Ð´Ð¼Ð°ÑƒÐµÑ€, Ñ€ÐµÐºÐ¾Ð¼ÐµÐ½Ð´ÑƒÑ”Ñ‚ÑŒÑÑ Ñ†Ðµ Ð½Ð°Ð»Ð°ÑˆÑ‚ÑƒÐ²Ð°Ñ‚Ð¸.';

  @override
  String connect_request(Object client) {
    return 'Ð”Ð¾Ð·Ð²Ð¾Ð»Ð¸Ñ‚Ð¸ $client Ð¿Ñ–Ð´ÐºÐ»ÑŽÑ‡ÐµÐ½Ð½Ñ?';
  }

  @override
  String get connection_request_denied =>
      'ÐŸÑ–Ð´ÐºÐ»ÑŽÑ‡ÐµÐ½Ð½Ñ Ð²Ñ–Ð´Ñ…Ð¸Ð»ÐµÐ½Ð¾. ÐšÐ¾Ñ€Ð¸ÑÑ‚ÑƒÐ²Ð°Ñ‡ Ð²Ñ–Ð´Ð¼Ð¾Ð²Ð¸Ð² Ñƒ Ð´Ð¾ÑÑ‚ÑƒÐ¿Ñ–.';

  @override
  String get an_error_occurred => 'Ð¡Ñ‚Ð°Ð»Ð°ÑÑ Ð¿Ð¾Ð¼Ð¸Ð»ÐºÐ°';

  @override
  String get copy_to_clipboard =>
      'ÐšÐ¾Ð¿Ñ–ÑŽÐ²Ð°Ñ‚Ð¸ Ð² Ð±ÑƒÑ„ÐµÑ€ Ð¾Ð±Ð¼Ñ–Ð½Ñƒ';

  @override
  String get view_logs => 'ÐŸÐµÑ€ÐµÐ³Ð»ÑÐ½ÑƒÑ‚Ð¸ Ð»Ð¾Ð³Ð¸';

  @override
  String get retry => 'ÐŸÐ¾Ð²Ñ‚Ð¾Ñ€Ð¸Ñ‚Ð¸';

  @override
  String get no_default_metadata_provider_selected =>
      'Ð’Ð¸ Ð½Ðµ Ð²ÑÑ‚Ð°Ð½Ð¾Ð²Ð¸Ð»Ð¸ Ð¿Ñ€Ð¾Ð²Ð°Ð¹Ð´ÐµÑ€Ð° Ð¼ÐµÑ‚Ð°Ð´Ð°Ð½Ð¸Ñ… Ð·Ð° Ð·Ð°Ð¼Ð¾Ð²Ñ‡ÑƒÐ²Ð°Ð½Ð½ÑÐ¼';

  @override
  String get manage_metadata_providers =>
      'ÐšÐµÑ€ÑƒÐ²Ð°Ñ‚Ð¸ Ð¿Ñ€Ð¾Ð²Ð°Ð¹Ð´ÐµÑ€Ð°Ð¼Ð¸ Ð¼ÐµÑ‚Ð°Ð´Ð°Ð½Ð¸Ñ…';

  @override
  String get open_link_in_browser =>
      'Ð’Ñ–Ð´ÐºÑ€Ð¸Ñ‚Ð¸ Ð¿Ð¾ÑÐ¸Ð»Ð°Ð½Ð½Ñ Ð² Ð±Ñ€Ð°ÑƒÐ·ÐµÑ€Ñ–?';

  @override
  String get do_you_want_to_open_the_following_link =>
      'Ð’Ð¸ Ñ…Ð¾Ñ‡ÐµÑ‚Ðµ Ð²Ñ–Ð´ÐºÑ€Ð¸Ñ‚Ð¸ Ð½Ð°ÑÑ‚ÑƒÐ¿Ð½Ðµ Ð¿Ð¾ÑÐ¸Ð»Ð°Ð½Ð½Ñ';

  @override
  String get unsafe_url_warning =>
      'Ð’Ñ–Ð´ÐºÑ€Ð¸Ñ‚Ñ‚Ñ Ð¿Ð¾ÑÐ¸Ð»Ð°Ð½ÑŒ Ð· Ð½ÐµÐ½Ð°Ð´Ñ–Ð¹Ð½Ð¸Ñ… Ð´Ð¶ÐµÑ€ÐµÐ» Ð¼Ð¾Ð¶Ðµ Ð±ÑƒÑ‚Ð¸ Ð½ÐµÐ±ÐµÐ·Ð¿ÐµÑ‡Ð½Ð¸Ð¼. Ð‘ÑƒÐ´ÑŒÑ‚Ðµ Ð¾Ð±ÐµÑ€ÐµÐ¶Ð½Ñ–!\nÐ’Ð¸ Ñ‚Ð°ÐºÐ¾Ð¶ Ð¼Ð¾Ð¶ÐµÑ‚Ðµ ÑÐºÐ¾Ð¿Ñ–ÑŽÐ²Ð°Ñ‚Ð¸ Ð¿Ð¾ÑÐ¸Ð»Ð°Ð½Ð½Ñ Ð² Ð±ÑƒÑ„ÐµÑ€ Ð¾Ð±Ð¼Ñ–Ð½Ñƒ.';

  @override
  String get copy_link => 'ÐšÐ¾Ð¿Ñ–ÑŽÐ²Ð°Ñ‚Ð¸ Ð¿Ð¾ÑÐ¸Ð»Ð°Ð½Ð½Ñ';

  @override
  String get building_your_timeline =>
      'Ð¡Ñ‚Ð²Ð¾Ñ€ÐµÐ½Ð½Ñ Ð²Ð°ÑˆÐ¾Ñ— Ñ‡Ð°ÑÐ¾Ð²Ð¾Ñ— ÑˆÐºÐ°Ð»Ð¸ Ð½Ð° Ð¾ÑÐ½Ð¾Ð²Ñ– Ð²Ð°ÑˆÐ¸Ñ… Ð¿Ñ€Ð¾ÑÐ»ÑƒÑ…Ð¾Ð²ÑƒÐ²Ð°Ð½ÑŒ...';

  @override
  String get official => 'ÐžÑ„Ñ–Ñ†Ñ–Ð¹Ð½Ð¸Ð¹';

  @override
  String author_name(Object author) {
    return 'ÐÐ²Ñ‚Ð¾Ñ€: $author';
  }

  @override
  String get third_party => 'Ð¡Ñ‚Ð¾Ñ€Ð¾Ð½Ð½Ñ–Ð¹';

  @override
  String get plugin_requires_authentication =>
      'ÐŸÐ»Ð°Ð³Ñ–Ð½ Ð²Ð¸Ð¼Ð°Ð³Ð°Ñ” Ð°Ð²Ñ‚ÐµÐ½Ñ‚Ð¸Ñ„Ñ–ÐºÐ°Ñ†Ñ–Ñ—';

  @override
  String get update_available => 'Ð”Ð¾ÑÑ‚ÑƒÐ¿Ð½Ðµ Ð¾Ð½Ð¾Ð²Ð»ÐµÐ½Ð½Ñ';

  @override
  String get supports_scrobbling => 'ÐŸÑ–Ð´Ñ‚Ñ€Ð¸Ð¼ÑƒÑ” ÑÐºÑ€Ð¾Ð±Ð»Ñ–Ð½Ð³';

  @override
  String get plugin_scrobbling_info =>
      'Ð¦ÐµÐ¹ Ð¿Ð»Ð°Ð³Ñ–Ð½ ÑÐºÑ€Ð¾Ð±Ð±Ð¸Ñ‚ÑŒ Ð²Ð°ÑˆÑƒ Ð¼ÑƒÐ·Ð¸ÐºÑƒ, Ñ‰Ð¾Ð± ÑÑ‚Ð²Ð¾Ñ€Ð¸Ñ‚Ð¸ Ð²Ð°ÑˆÑƒ Ñ–ÑÑ‚Ð¾Ñ€Ñ–ÑŽ Ð¿Ñ€Ð¾ÑÐ»ÑƒÑ…Ð¾Ð²ÑƒÐ²Ð°Ð½ÑŒ.';

  @override
  String get default_metadata_source =>
      'Ð”Ð¶ÐµÑ€ÐµÐ»Ð¾ Ð¼ÐµÑ‚Ð°Ð´Ð°Ð½Ð¸Ñ… Ð·Ð° Ð·Ð°Ð¼Ð¾Ð²Ñ‡ÑƒÐ²Ð°Ð½Ð½ÑÐ¼';

  @override
  String get set_default_metadata_source =>
      'Ð’ÑÑ‚Ð°Ð½Ð¾Ð²Ð¸Ñ‚Ð¸ Ð´Ð¶ÐµÑ€ÐµÐ»Ð¾ Ð¼ÐµÑ‚Ð°Ð´Ð°Ð½Ð¸Ñ… Ð·Ð° Ð·Ð°Ð¼Ð¾Ð²Ñ‡ÑƒÐ²Ð°Ð½Ð½ÑÐ¼';

  @override
  String get default_audio_source =>
      'Ð”Ð¶ÐµÑ€ÐµÐ»Ð¾ Ð°ÑƒÐ´Ñ–Ð¾ Ð·Ð° Ð·Ð°Ð¼Ð¾Ð²Ñ‡ÑƒÐ²Ð°Ð½Ð½ÑÐ¼';

  @override
  String get set_default_audio_source =>
      'Ð’ÑÑ‚Ð°Ð½Ð¾Ð²Ð¸Ñ‚Ð¸ Ð´Ð¶ÐµÑ€ÐµÐ»Ð¾ Ð°ÑƒÐ´Ñ–Ð¾ Ð·Ð° Ð·Ð°Ð¼Ð¾Ð²Ñ‡ÑƒÐ²Ð°Ð½Ð½ÑÐ¼';

  @override
  String get set_default =>
      'Ð’ÑÑ‚Ð°Ð½Ð¾Ð²Ð¸Ñ‚Ð¸ Ð·Ð° Ð·Ð°Ð¼Ð¾Ð²Ñ‡ÑƒÐ²Ð°Ð½Ð½ÑÐ¼';

  @override
  String get support => 'ÐŸÑ–Ð´Ñ‚Ñ€Ð¸Ð¼ÐºÐ°';

  @override
  String get support_plugin_development =>
      'ÐŸÑ–Ð´Ñ‚Ñ€Ð¸Ð¼Ð°Ñ‚Ð¸ Ñ€Ð¾Ð·Ñ€Ð¾Ð±ÐºÑƒ Ð¿Ð»Ð°Ð³Ñ–Ð½Ð°';

  @override
  String can_access_name_api(Object name) {
    return '- ÐœÐ¾Ð¶Ðµ Ð¾Ñ‚Ñ€Ð¸Ð¼Ð°Ñ‚Ð¸ Ð´Ð¾ÑÑ‚ÑƒÐ¿ Ð´Ð¾ **$name** API';
  }

  @override
  String get do_you_want_to_install_this_plugin =>
      'Ð’Ð¸ Ñ…Ð¾Ñ‡ÐµÑ‚Ðµ Ð²ÑÑ‚Ð°Ð½Ð¾Ð²Ð¸Ñ‚Ð¸ Ñ†ÐµÐ¹ Ð¿Ð»Ð°Ð³Ñ–Ð½?';

  @override
  String get third_party_plugin_warning =>
      'Ð¦ÐµÐ¹ Ð¿Ð»Ð°Ð³Ñ–Ð½ Ñ–Ð· ÑÑ‚Ð¾Ñ€Ð¾Ð½Ð½ÑŒÐ¾Ð³Ð¾ Ñ€ÐµÐ¿Ð¾Ð·Ð¸Ñ‚Ð¾Ñ€Ñ–ÑŽ. Ð‘ÑƒÐ´ÑŒ Ð»Ð°ÑÐºÐ°, Ð¿ÐµÑ€ÐµÐºÐ¾Ð½Ð°Ð¹Ñ‚ÐµÑÑ, Ñ‰Ð¾ Ð²Ð¸ Ð´Ð¾Ð²Ñ–Ñ€ÑÑ”Ñ‚Ðµ Ð´Ð¶ÐµÑ€ÐµÐ»Ñƒ Ð¿ÐµÑ€ÐµÐ´ Ð²ÑÑ‚Ð°Ð½Ð¾Ð²Ð»ÐµÐ½Ð½ÑÐ¼.';

  @override
  String get author => 'ÐÐ²Ñ‚Ð¾Ñ€';

  @override
  String get this_plugin_can_do_following =>
      'Ð¦ÐµÐ¹ Ð¿Ð»Ð°Ð³Ñ–Ð½ Ð¼Ð¾Ð¶Ðµ Ñ€Ð¾Ð±Ð¸Ñ‚Ð¸ Ð½Ð°ÑÑ‚ÑƒÐ¿Ð½Ðµ';

  @override
  String get install => 'Ð’ÑÑ‚Ð°Ð½Ð¾Ð²Ð¸Ñ‚Ð¸';

  @override
  String get install_a_metadata_provider =>
      'Ð’ÑÑ‚Ð°Ð½Ð¾Ð²Ð¸Ñ‚Ð¸ Ð¿Ñ€Ð¾Ð²Ð°Ð¹Ð´ÐµÑ€Ð° Ð¼ÐµÑ‚Ð°Ð´Ð°Ð½Ð¸Ñ…';

  @override
  String get no_tracks_playing =>
      'ÐÐ°Ñ€Ð°Ð·Ñ– Ð½Ðµ Ð²Ñ–Ð´Ñ‚Ð²Ð¾Ñ€ÑŽÑ”Ñ‚ÑŒÑÑ Ð¶Ð¾Ð´ÐµÐ½ Ñ‚Ñ€ÐµÐº';

  @override
  String get synced_lyrics_not_available =>
      'Ð¡Ð¸Ð½Ñ…Ñ€Ð¾Ð½Ñ–Ð·Ð¾Ð²Ð°Ð½Ñ– Ñ‚ÐµÐºÑÑ‚Ð¸ Ð½ÐµÐ´Ð¾ÑÑ‚ÑƒÐ¿Ð½Ñ– Ð´Ð»Ñ Ñ†Ñ–Ñ”Ñ— Ð¿Ñ–ÑÐ½Ñ–. Ð‘ÑƒÐ´ÑŒ Ð»Ð°ÑÐºÐ°, Ð²Ð¸ÐºÐ¾Ñ€Ð¸ÑÑ‚Ð¾Ð²ÑƒÐ¹Ñ‚Ðµ Ð²ÐºÐ»Ð°Ð´ÐºÑƒ';

  @override
  String get plain_lyrics => 'Ð—Ð²Ð¸Ñ‡Ð°Ð¹Ð½Ñ– Ñ‚ÐµÐºÑÑ‚Ð¸';

  @override
  String get tab_instead => 'Ð·Ð°Ð¼Ñ–ÑÑ‚ÑŒ Ñ†ÑŒÐ¾Ð³Ð¾.';

  @override
  String get disclaimer =>
      'Ð’Ñ–Ð´Ð¼Ð¾Ð²Ð° Ð²Ñ–Ð´ Ð²Ñ–Ð´Ð¿Ð¾Ð²Ñ–Ð´Ð°Ð»ÑŒÐ½Ð¾ÑÑ‚Ñ–';

  @override
  String get third_party_plugin_dmca_notice =>
      'ÐšÐ¾Ð¼Ð°Ð½Ð´Ð° Soulful Bhakti Ð½Ðµ Ð½ÐµÑÐµ Ð¶Ð¾Ð´Ð½Ð¾Ñ— Ð²Ñ–Ð´Ð¿Ð¾Ð²Ñ–Ð´Ð°Ð»ÑŒÐ½Ð¾ÑÑ‚Ñ– (Ð²ÐºÐ»ÑŽÑ‡Ð½Ð¾ Ð· ÑŽÑ€Ð¸Ð´Ð¸Ñ‡Ð½Ð¾ÑŽ) Ð·Ð° Ð±ÑƒÐ´ÑŒ-ÑÐºÑ– Ð¿Ð»Ð°Ð³Ñ–Ð½Ð¸ \"Ñ‚Ñ€ÐµÑ‚Ñ–Ñ… ÑÑ‚Ð¾Ñ€Ñ–Ð½\".\nÐ‘ÑƒÐ´ÑŒ Ð»Ð°ÑÐºÐ°, Ð²Ð¸ÐºÐ¾Ñ€Ð¸ÑÑ‚Ð¾Ð²ÑƒÐ¹Ñ‚Ðµ Ñ—Ñ… Ð½Ð° ÑÐ²Ñ–Ð¹ ÑÑ‚Ñ€Ð°Ñ… Ñ– Ñ€Ð¸Ð·Ð¸Ðº. ÐŸÑ€Ð¾ Ð±ÑƒÐ´ÑŒ-ÑÐºÑ– Ð¿Ð¾Ð¼Ð¸Ð»ÐºÐ¸/Ð¿Ñ€Ð¾Ð±Ð»ÐµÐ¼Ð¸ Ð¿Ð¾Ð²Ñ–Ð´Ð¾Ð¼Ð»ÑÐ¹Ñ‚Ðµ Ð² Ñ€ÐµÐ¿Ð¾Ð·Ð¸Ñ‚Ð¾Ñ€Ñ–Ð¹ Ð¿Ð»Ð°Ð³Ñ–Ð½Ð°.\n\nÐ¯ÐºÑ‰Ð¾ ÑÐºÐ¸Ð¹ÑÑŒ Ð¿Ð»Ð°Ð³Ñ–Ð½ \"Ñ‚Ñ€ÐµÑ‚ÑŒÐ¾Ñ— ÑÑ‚Ð¾Ñ€Ð¾Ð½Ð¸\" Ð¿Ð¾Ñ€ÑƒÑˆÑƒÑ” ToS/DMCA Ð±ÑƒÐ´ÑŒ-ÑÐºÐ¾Ñ— ÑÐ»ÑƒÐ¶Ð±Ð¸/ÑŽÑ€Ð¸Ð´Ð¸Ñ‡Ð½Ð¾Ñ— Ð¾ÑÐ¾Ð±Ð¸, Ð±ÑƒÐ´ÑŒ Ð»Ð°ÑÐºÐ°, Ð¿Ð¾Ð¿Ñ€Ð¾ÑÑ–Ñ‚ÑŒ Ð°Ð²Ñ‚Ð¾Ñ€Ð° Ð¿Ð»Ð°Ð³Ñ–Ð½Ð° \"Ñ‚Ñ€ÐµÑ‚ÑŒÐ¾Ñ— ÑÑ‚Ð¾Ñ€Ð¾Ð½Ð¸\" Ð°Ð±Ð¾ Ñ…Ð¾ÑÑ‚Ð¸Ð½Ð³Ð¾Ð²Ñƒ Ð¿Ð»Ð°Ñ‚Ñ„Ð¾Ñ€Ð¼Ñƒ, Ð½Ð°Ð¿Ñ€Ð¸ÐºÐ»Ð°Ð´, GitHub/Codeberg, Ð²Ð¶Ð¸Ñ‚Ð¸ Ð·Ð°Ñ…Ð¾Ð´Ñ–Ð². Ð£ÑÑ– Ð¿ÐµÑ€ÐµÑ€Ð°Ñ…Ð¾Ð²Ð°Ð½Ñ– Ð²Ð¸Ñ‰Ðµ (Ð¿Ð¾Ð·Ð½Ð°Ñ‡ÐµÐ½Ñ– ÑÐº \"Ñ‚Ñ€ÐµÑ‚Ñ– ÑÑ‚Ð¾Ñ€Ð¾Ð½Ð¸\") Ñ” Ð¿Ð»Ð°Ð³Ñ–Ð½Ð°Ð¼Ð¸, ÑÐºÑ– Ð¿Ñ–Ð´Ñ‚Ñ€Ð¸Ð¼ÑƒÑŽÑ‚ÑŒÑÑ Ð¿ÑƒÐ±Ð»Ñ–Ñ‡Ð½Ð¾/ÑÐ¿Ñ–Ð»ÑŒÐ½Ð¾Ñ‚Ð¾ÑŽ. ÐœÐ¸ Ð½Ðµ ÐºÑƒÑ€ÑƒÑ”Ð¼Ð¾ Ñ—Ñ…, Ñ‚Ð¾Ð¼Ñƒ Ð½Ðµ Ð¼Ð¾Ð¶ÐµÐ¼Ð¾ Ð²Ð¶Ð¸Ñ‚Ð¸ Ð¶Ð¾Ð´Ð½Ð¸Ñ… Ð·Ð°Ñ…Ð¾Ð´Ñ–Ð² Ñ‰Ð¾Ð´Ð¾ Ð½Ð¸Ñ….\n\n';

  @override
  String get input_does_not_match_format =>
      'Ð’Ð²ÐµÐ´ÐµÐ½Ñ– Ð´Ð°Ð½Ñ– Ð½Ðµ Ð²Ñ–Ð´Ð¿Ð¾Ð²Ñ–Ð´Ð°ÑŽÑ‚ÑŒ Ð½ÐµÐ¾Ð±Ñ…Ñ–Ð´Ð½Ð¾Ð¼Ñƒ Ñ„Ð¾Ñ€Ð¼Ð°Ñ‚Ñƒ';

  @override
  String get plugins => 'ÐŸÐ»Ð°Ð³Ñ–Ð½Ð¸';

  @override
  String get paste_plugin_download_url =>
      'Ð’ÑÑ‚Ð°Ð²Ñ‚Ðµ URL-Ð°Ð´Ñ€ÐµÑÑƒ Ð´Ð»Ñ Ð·Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶ÐµÐ½Ð½Ñ Ð°Ð±Ð¾ URL-Ð°Ð´Ñ€ÐµÑÑƒ Ñ€ÐµÐ¿Ð¾Ð·Ð¸Ñ‚Ð¾Ñ€Ñ–ÑŽ GitHub/Codeberg Ð°Ð±Ð¾ Ð¿Ñ€ÑÐ¼Ðµ Ð¿Ð¾ÑÐ¸Ð»Ð°Ð½Ð½Ñ Ð½Ð° Ñ„Ð°Ð¹Ð» .smplug';

  @override
  String get download_and_install_plugin_from_url =>
      'Ð—Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶Ð¸Ñ‚Ð¸ Ñ‚Ð° Ð²ÑÑ‚Ð°Ð½Ð¾Ð²Ð¸Ñ‚Ð¸ Ð¿Ð»Ð°Ð³Ñ–Ð½ Ð· URL-Ð°Ð´Ñ€ÐµÑÐ¸';

  @override
  String failed_to_add_plugin_error(Object error) {
    return 'ÐÐµ Ð²Ð´Ð°Ð»Ð¾ÑÑ Ð´Ð¾Ð´Ð°Ñ‚Ð¸ Ð¿Ð»Ð°Ð³Ñ–Ð½: $error';
  }

  @override
  String get upload_plugin_from_file =>
      'Ð—Ð°Ð²Ð°Ð½Ñ‚Ð°Ð¶Ð¸Ñ‚Ð¸ Ð¿Ð»Ð°Ð³Ñ–Ð½ Ð· Ñ„Ð°Ð¹Ð»Ñƒ';

  @override
  String get installed => 'Ð’ÑÑ‚Ð°Ð½Ð¾Ð²Ð»ÐµÐ½Ð¾';

  @override
  String get available_plugins => 'Ð”Ð¾ÑÑ‚ÑƒÐ¿Ð½Ñ– Ð¿Ð»Ð°Ð³Ñ–Ð½Ð¸';

  @override
  String get configure_plugins =>
      'ÐÐ°Ð»Ð°ÑˆÑ‚ÑƒÐ¹Ñ‚Ðµ Ð²Ð»Ð°ÑÐ½Ñ– Ð¿Ð»Ð°Ð³Ñ–Ð½Ð¸ Ð¼ÐµÑ‚Ð°Ð´Ð°Ð½Ð¸Ñ… Ñ– Ð°ÑƒÐ´Ñ–Ð¾Ð´Ð¶ÐµÑ€ÐµÐ»Ð°';

  @override
  String get source => 'Ð”Ð¶ÐµÑ€ÐµÐ»Ð¾: ';

  @override
  String get uncompressed => 'Ð‘ÐµÐ· ÑÑ‚Ð¸ÑÐ½ÐµÐ½Ð½Ñ';

  @override
  String get dab_music_source_description =>
      'Ð”Ð»Ñ Ð°ÑƒÐ´Ñ–Ð¾Ñ„Ñ–Ð»Ñ–Ð². Ð—Ð°Ð±ÐµÐ·Ð¿ÐµÑ‡ÑƒÑ” Ð²Ð¸ÑÐ¾ÐºÐ¾ÑÐºÑ–ÑÐ½Ñ–/Ð±ÐµÐ· Ð²Ñ‚Ñ€Ð°Ñ‚ Ð°ÑƒÐ´Ñ–Ð¾Ð¿Ð¾Ñ‚Ð¾ÐºÐ¸. Ð¢Ð¾Ñ‡Ð½Ð° Ð²Ñ–Ð´Ð¿Ð¾Ð²Ñ–Ð´Ð½Ñ–ÑÑ‚ÑŒ Ñ‚Ñ€ÐµÐºÑ–Ð² Ð½Ð° Ð¾ÑÐ½Ð¾Ð²Ñ– ISRC.';

  @override
  String get summary_top_track =>
      'ÐšÑ€Ð°Ñ‰Ð¸Ð¹ Ñ‚Ñ€ÐµÐº\nÐ·Ð° Ñ†ÐµÐ¹ Ð¿ÐµÑ€Ñ–Ð¾Ð´';

  @override
  String get local => 'Ð›Ð¾ÐºÐ°Ð»ÑŒÐ½Ð¸Ð¹';

  @override
  String get set_as_ringtone => 'Set as ringtone';

  @override
  String get ringtone_set => 'Ringtone set';

  @override
  String get ringtone_failed => 'Could not set ringtone';

  @override
  String get specials => 'Specials';

  @override
  String get featured_playlist => 'Рекомендований плейлист';

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
