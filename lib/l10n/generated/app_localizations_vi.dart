// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get guest => 'KhÃ¡ch';

  @override
  String get browse => 'KhÃ¡m phÃ¡';

  @override
  String get search => 'TÃ¬m kiáº¿m';

  @override
  String get library => 'ThÆ° viÃªn';

  @override
  String get lyrics => 'Lá»i bÃ i hÃ¡t';

  @override
  String get settings => 'CÃ i Ä‘áº·t';

  @override
  String get settings_subtitle =>
      'TÃ¹y chá»‰nh Soulful Bhakti theo Ã½ thÃ­ch cá»§a báº¡n';

  @override
  String get genre_categories_filter => 'Lá»c theo thá»ƒ loáº¡i nháº¡c...';

  @override
  String get genre => 'Thá»ƒ loáº¡i nháº¡c';

  @override
  String get personalized => 'CÃ¡ nhÃ¢n hÃ³a';

  @override
  String get featured => 'Ná»•i báº­t';

  @override
  String get new_releases => 'Báº£n phÃ¡t hÃ nh má»›i';

  @override
  String get songs => 'BÃ i hÃ¡t';

  @override
  String get newest_arrivals => 'Má»›i nháº¥t';

  @override
  String get top_trending => 'Thá»‹nh hÃ nh';

  @override
  String get see_more => 'Xem thÃªm';

  @override
  String playing_track(Object track) {
    return 'Äang phÃ¡t $track';
  }

  @override
  String queue_clear_alert(Object track_length) {
    return 'Äiá»u nÃ y sáº½ xÃ³a hÃ ng Ä‘á»£i hiá»‡n táº¡i. $track_length bÃ i hÃ¡t sáº½ bá»‹ xÃ³a\nBáº¡n cÃ³ muá»‘n tiáº¿p tá»¥c khÃ´ng?';
  }

  @override
  String get load_more => 'Táº£i thÃªm';

  @override
  String get playlists => 'Danh sÃ¡ch phÃ¡t';

  @override
  String get artists => 'Nghá»‡ sÄ©';

  @override
  String get albums => 'Album';

  @override
  String get tracks => 'BÃ i hÃ¡t';

  @override
  String get downloads => 'Táº£i vá»';

  @override
  String get filter_playlists => 'Lá»c danh sÃ¡ch phÃ¡t...';

  @override
  String get liked_tracks => 'BÃ i hÃ¡t Ä‘Æ°á»£c thÃ­ch';

  @override
  String get liked_tracks_description =>
      'Táº¥t cáº£ bÃ i hÃ¡t báº¡n Ä‘Ã£ thÃ­ch';

  @override
  String get playlist => 'Danh sÃ¡ch phÃ¡t';

  @override
  String get create_a_playlist => 'Táº¡o danh sÃ¡ch phÃ¡t';

  @override
  String get new_playlist => 'Danh sÃ¡ch phÃ¡t má»›i';

  @override
  String get playlist_name => 'TÃªn danh sÃ¡ch phÃ¡t';

  @override
  String get no_playlists_yet =>
      'ChÆ°a cÃ³ danh sÃ¡ch phÃ¡t nÃ o. Táº¡o má»™t danh sÃ¡ch tá»« cÃ¡c bÃ i hÃ¡t Ä‘Ã£ chá»n.';

  @override
  String get update_playlist => 'Cáº­p nháº­t danh sÃ¡ch phÃ¡t';

  @override
  String get create => 'Táº¡o';

  @override
  String get cancel => 'Há»§y';

  @override
  String get update => 'Cáº­p nháº­t';

  @override
  String get name_of_playlist => 'TÃªn cá»§a danh sÃ¡ch phÃ¡t';

  @override
  String get description => 'MÃ´ táº£';

  @override
  String get public => 'CÃ´ng khai';

  @override
  String get collaborative => 'Há»£p tÃ¡c';

  @override
  String get search_local_tracks => 'TÃ¬m kiáº¿m bÃ i hÃ¡t trong mÃ¡y...';

  @override
  String get play => 'PhÃ¡t';

  @override
  String get delete => 'XÃ³a';

  @override
  String get none => 'KhÃ´ng cÃ³';

  @override
  String get sort_a_z => 'Sáº¯p xáº¿p theo A-Z';

  @override
  String get sort_z_a => 'Sáº¯p xáº¿p theo Z-A';

  @override
  String get sort_artist => 'Sáº¯p xáº¿p theo Nghá»‡ sÄ©';

  @override
  String get sort_album => 'Sáº¯p xáº¿p theo Album';

  @override
  String get sort_duration => 'Sáº¯p xáº¿p theo Thá»i lÆ°á»£ng';

  @override
  String get sort_tracks => 'Sáº¯p xáº¿p cÃ¡c bÃ i hÃ¡t';

  @override
  String currently_downloading(Object tracks_length) {
    return 'Äang táº£i vá» ($tracks_length bÃ i hÃ¡t)';
  }

  @override
  String get cancel_all => 'Há»§y táº¥t cáº£';

  @override
  String get filter_artist => 'Lá»c nghá»‡ sÄ©...';

  @override
  String followers(Object followers) {
    return '$followers NgÆ°á»i theo dÃµi';
  }

  @override
  String get add_artist_to_blacklist => 'ThÃªm nghá»‡ sÄ© vÃ o blacklist';

  @override
  String get top_tracks => 'BÃ i hÃ¡t ná»•i báº­t';

  @override
  String get fans_also_like => 'NgÆ°á»i hÃ¢m má»™ cÅ©ng thÃ­ch';

  @override
  String get loading => 'Äang táº£i...';

  @override
  String get artist => 'Nghá»‡ sÄ©';

  @override
  String get blacklisted => 'ÄÃ£ Ä‘Æ°a vÃ o blacklist';

  @override
  String get following => 'Äang theo dÃµi';

  @override
  String get follow => 'Theo dÃµi';

  @override
  String get artist_url_copied => 'ÄÃ£ sao chÃ©p URL nghá»‡ sÄ©';

  @override
  String added_to_queue(Object tracks) {
    return 'ÄÃ£ thÃªm $tracks bÃ i hÃ¡t vÃ o hÃ ng Ä‘á»£i';
  }

  @override
  String get filter_albums => 'Lá»c album...';

  @override
  String get synced => 'Äá»“ng bá»™';

  @override
  String get plain => 'BÃ¬nh thÆ°á»ng';

  @override
  String get shuffle => 'Trá»™n';

  @override
  String get search_tracks => 'TÃ¬m kiáº¿m bÃ i hÃ¡t...';

  @override
  String get released => 'PhÃ¡t hÃ nh';

  @override
  String error(Object error) {
    return 'Lá»—i $error';
  }

  @override
  String get title => 'Äá» má»¥c';

  @override
  String get time => 'Thá»i gian';

  @override
  String get more_actions => 'Thao tÃ¡c khÃ¡c';

  @override
  String add_count_to_playlist(Object count) {
    return 'ThÃªm ($count) vÃ o danh sÃ¡ch phÃ¡t';
  }

  @override
  String add_count_to_queue(Object count) {
    return 'ThÃªm ($count) vÃ o hÃ ng Ä‘á»£i';
  }

  @override
  String play_count_next(Object count) {
    return 'PhÃ¡t ($count) tiáº¿p theo';
  }

  @override
  String get album => 'Album';

  @override
  String copied_to_clipboard(Object data) {
    return 'ÄÃ£ sao chÃ©p $data vÃ o clipboard';
  }

  @override
  String add_to_following_playlists(Object track) {
    return 'ThÃªm $track vÃ o danh sÃ¡ch phÃ¡t Ä‘ang theo dÃµi';
  }

  @override
  String get add => 'ThÃªm';

  @override
  String added_track_to_queue(Object track) {
    return 'ÄÃ£ thÃªm $track vÃ o hÃ ng Ä‘á»£i';
  }

  @override
  String get add_to_queue => 'ThÃªm vÃ o hÃ ng Ä‘á»£i';

  @override
  String track_will_play_next(Object track) {
    return '$track sáº½ Ä‘Æ°á»£c phÃ¡t tiáº¿p theo';
  }

  @override
  String get play_next => 'PhÃ¡t tiáº¿p theo';

  @override
  String removed_track_from_queue(Object track) {
    return 'ÄÃ£ xÃ³a $track khá»i hÃ ng Ä‘á»£i';
  }

  @override
  String get remove_from_queue => 'XÃ³a khá»i hÃ ng Ä‘á»£i';

  @override
  String get remove_from_favorites => 'XÃ³a khá»i bÃ i hÃ¡t yÃªu thÃ­ch';

  @override
  String get save_as_favorite => 'ThÃªm vÃ o bÃ i hÃ¡t yÃªu thÃ­ch';

  @override
  String get add_to_playlist => 'ThÃªm vÃ o danh sÃ¡ch phÃ¡t';

  @override
  String get remove_from_playlist => 'XÃ³a khá»i danh sÃ¡ch phÃ¡t';

  @override
  String get add_to_blacklist => 'ThÃªm vÃ o blacklist';

  @override
  String get remove_from_blacklist => 'XÃ³a khá»i blacklist';

  @override
  String get share => 'Chia sáº»';

  @override
  String get mini_player => 'TrÃ¬nh phÃ¡t thu nhá»';

  @override
  String get slide_to_seek => 'TrÆ°á»£t Ä‘á»ƒ tÃ¬m kiáº¿m tiáº¿n hoáº·c lÃ¹i';

  @override
  String get shuffle_playlist => 'XÃ¡o trá»™n bÃ i hÃ¡t';

  @override
  String get unshuffle_playlist => 'Há»§y xÃ¡o trá»™n bÃ i hÃ¡t';

  @override
  String get previous_track => 'BÃ i hÃ¡t trÆ°á»›c';

  @override
  String get next_track => 'BÃ i hÃ¡t tiáº¿p theo';

  @override
  String get pause_playback => 'Táº¡m dá»«ng phÃ¡t';

  @override
  String get resume_playback => 'Tiáº¿p tá»¥c phÃ¡t';

  @override
  String get loop_track => 'Láº·p láº¡i bÃ i hÃ¡t';

  @override
  String get no_loop => 'KhÃ´ng láº·p láº¡i';

  @override
  String get repeat_playlist => 'Láº·p láº¡i danh sÃ¡ch phÃ¡t';

  @override
  String get queue => 'HÃ ng Ä‘á»£i';

  @override
  String get alternative_track_sources => 'Äá»•i nguá»“n bÃ i hÃ¡t';

  @override
  String tracks_in_queue(Object tracks) {
    return '$tracks bÃ i hÃ¡t trong hÃ ng Ä‘á»£i';
  }

  @override
  String get clear_all => 'XÃ³a táº¥t cáº£';

  @override
  String get show_hide_ui_on_hover =>
      'Hiá»ƒn thá»‹/áº¨n giao diá»‡n ngÆ°á»i dÃ¹ng khi di chuá»™t qua';

  @override
  String get always_on_top => 'LuÃ´n á»Ÿ trÃªn cÃ¹ng';

  @override
  String get exit_mini_player => 'ThoÃ¡t khá»i trÃ¬nh phÃ¡t thu nhá»';

  @override
  String get local_library => 'ThÆ° viá»‡n Ä‘á»‹a phÆ°Æ¡ng';

  @override
  String get add_library_location => 'ThÃªm vÃ o thÆ° viá»‡n';

  @override
  String get remove_library_location => 'XÃ³a khá»i thÆ° viá»‡n';

  @override
  String get account => 'TÃ i khoáº£n';

  @override
  String get logout => 'ÄÄƒng xuáº¥t';

  @override
  String get logout_of_this_account => 'ÄÄƒng xuáº¥t khá»i tÃ i khoáº£n nÃ y';

  @override
  String get language_region => 'NgÃ´n ngá»¯ vÃ  Khu vá»±c';

  @override
  String get language => 'NgÃ´n ngá»¯';

  @override
  String get system_default => 'Máº·c Ä‘á»‹nh há»‡ thá»‘ng';

  @override
  String get market_place_region => 'Khu vá»±c Marketplace';

  @override
  String get recommendation_country => 'Quá»‘c gia gá»£i Ã½';

  @override
  String get appearance => 'Giao diá»‡n';

  @override
  String get layout_mode => 'Cháº¿ Ä‘á»™ layout';

  @override
  String get override_layout_settings => 'Ghi Ä‘Ã¨ cÃ i Ä‘áº·t layout';

  @override
  String get adaptive => 'TÆ°Æ¡ng thÃ­ch';

  @override
  String get compact => 'Nhá» gá»n';

  @override
  String get extended => 'Má»Ÿ rá»™ng';

  @override
  String get theme => 'Chá»§ Ä‘á»';

  @override
  String get dark => 'Tá»‘i';

  @override
  String get light => 'SÃ¡ng';

  @override
  String get system => 'Há»‡ thá»‘ng';

  @override
  String get accent_color => 'MÃ u nháº¥n';

  @override
  String get sync_album_color => 'Äá»“ng bá»™ mÃ u album';

  @override
  String get sync_album_color_description =>
      'Sá»­ dá»¥ng mÃ u chá»§ Ä‘áº¡o cá»§a hÃ¬nh áº£nh album lÃ m mÃ u nháº¥n';

  @override
  String get playback => 'PhÃ¡t';

  @override
  String get audio_quality => 'Cháº¥t lÆ°á»£ng Ã¢m thanh';

  @override
  String get high => 'Cao';

  @override
  String get low => 'Tháº¥p';

  @override
  String get pre_download_play => 'Táº£i xuá»‘ng vÃ  phÃ¡t';

  @override
  String get pre_download_play_description =>
      'Thay vÃ¬ stream Ã¢m thanh, táº£i xuá»‘ng trÆ°á»›c vÃ  phÃ¡t (Khuyáº¿n nghá»‹ cho ngÆ°á»i dÃ¹ng cÃ³ bÄƒng thÃ´ng cao)';

  @override
  String get skip_non_music =>
      'Bá» qua cÃ¡c Ä‘oáº¡n khÃ´ng pháº£i nháº¡c (SponsorBlock)';

  @override
  String get blacklist_description =>
      'CÃ¡c bÃ i hÃ¡t vÃ  nghá»‡ sÄ© trong blacklist';

  @override
  String get wait_for_download_to_finish =>
      'Vui lÃ²ng Ä‘á»£i quÃ¡ trÃ¬nh táº£i xuá»‘ng hiá»‡n táº¡i hoÃ n thÃ nh';

  @override
  String get desktop => 'MÃ¡y tÃ­nh';

  @override
  String get close_behavior => 'Thao tÃ¡c Ä‘Ã³ng';

  @override
  String get close => 'ÄÃ³ng';

  @override
  String get minimize_to_tray => 'Thu nhá» vÃ o khay há»‡ thá»‘ng';

  @override
  String get show_tray_icon =>
      'Hiá»ƒn thá»‹ biá»ƒu tÆ°á»£ng trÃªn khay há»‡ thá»‘ng';

  @override
  String get about => 'Vá» chÃºng tÃ´i';

  @override
  String get u_love_spotube => 'ChÃºng tÃ´i biáº¿t báº¡n yÃªu Soulful Bhakti';

  @override
  String get check_for_updates => 'Kiá»ƒm tra cáº­p nháº­t';

  @override
  String get about_spotube => 'Vá» Soulful Bhakti';

  @override
  String get blacklist => 'blacklist';

  @override
  String get please_sponsor => 'Vui lÃ²ng tÃ i trá»£/á»§ng há»™';

  @override
  String get spotube_description =>
      'Soulful Bhakti, má»™t á»©ng dá»¥ng Spotify nháº¹, Ä‘a ná»n táº£ng vÃ  miá»…n phÃ­';

  @override
  String get version => 'PhiÃªn báº£n';

  @override
  String get build_number => 'Sá»‘ phiÃªn báº£n';

  @override
  String get founder => 'NgÆ°á»i sÃ¡ng láº­p';

  @override
  String get repository => 'MÃ£ nguá»“n';

  @override
  String get bug_issues => 'BÃ¡o cÃ¡o lá»—i';

  @override
  String get made_with => 'ÄÆ°á»£c lÃ m báº±ng â¤ï¸ á»Ÿ BÄƒng-la-Ä‘Ã©t';

  @override
  String get kingkor_roy_tirtho => 'Kingkor Roy Tirtho';

  @override
  String copyright(Object current_year) {
    return 'Â© 2021-$current_year Kingkor Roy Tirtho';
  }

  @override
  String get license => 'Giáº¥y phÃ©p';

  @override
  String get credentials_will_not_be_shared_disclaimer =>
      'Äá»«ng lo, thÃ´ng tin Ä‘Äƒng nháº­p cá»§a báº¡n sáº½ khÃ´ng Ä‘Æ°á»£c thu tháº­p hoáº·c chia sáº» vá»›i báº¥t ká»³ ai';

  @override
  String get know_how_to_login =>
      'KhÃ´ng biáº¿t cÃ¡ch láº¥y thÃ´ng tin Ä‘Äƒng nháº­p?';

  @override
  String get follow_step_by_step_guide =>
      'CÃ¡c bÆ°á»›c láº¥y thÃ´ng tin Ä‘Äƒng nháº­p';

  @override
  String cookie_name_cookie(Object name) {
    return 'Cookie $name';
  }

  @override
  String get fill_in_all_fields => 'Vui lÃ²ng Ä‘iá»n Ä‘áº§y Ä‘á»§ thÃ´ng tin';

  @override
  String get submit => 'Gá»­i';

  @override
  String get exit => 'ThoÃ¡t';

  @override
  String get previous => 'TrÆ°á»›c';

  @override
  String get next => 'Tiáº¿p';

  @override
  String get done => 'HoÃ n táº¥t';

  @override
  String get step_1 => 'BÆ°á»›c 1';

  @override
  String get first_go_to => 'Äáº§u tiÃªn, truy cáº­p';

  @override
  String get something_went_wrong => 'ÄÃ£ xáº£y ra lá»—i';

  @override
  String get piped_instance => 'PhiÃªn báº£n Server Piped';

  @override
  String get piped_description =>
      'PhiÃªn báº£n Piped Ä‘á»ƒ sá»­ dá»¥ng cho Track matching';

  @override
  String get piped_warning =>
      'Má»™t sá»‘ phiÃªn báº£n Piped cÃ³ thá»ƒ khÃ´ng hoáº¡t Ä‘á»™ng tá»‘t';

  @override
  String get invidious_instance => 'PhiÃªn báº£n mÃ¡y chá»§ Invidious';

  @override
  String get invidious_description =>
      'PhiÃªn báº£n mÃ¡y chá»§ Invidious Ä‘á»ƒ sá»­ dá»¥ng Ä‘á»ƒ so khá»›p báº£n nháº¡c';

  @override
  String get invidious_warning =>
      'Má»™t sá»‘ cÃ³ thá»ƒ sáº½ khÃ´ng hoáº¡t Ä‘á»™ng tá»‘t. VÃ¬ váº­y hÃ£y sá»­ dá»¥ng vá»›i rá»§i ro cá»§a riÃªng báº¡n';

  @override
  String get generate => 'Táº¡o';

  @override
  String track_exists(Object track) {
    return 'BÃ i hÃ¡t $track Ä‘Ã£ tá»“n táº¡i';
  }

  @override
  String get replace => 'Thay tháº¿';

  @override
  String get skip => 'Bá» qua';

  @override
  String select_up_to_count_type(Object count, Object type) {
    return 'Chá»n tá»‘i Ä‘a $count $type';
  }

  @override
  String get select_genres => 'Chá»n Thá»ƒ loáº¡i';

  @override
  String get add_genres => 'ThÃªm Thá»ƒ loáº¡i';

  @override
  String get country => 'Quá»‘c gia';

  @override
  String get number_of_tracks_generate => 'Sá»‘ lÆ°á»£ng bÃ i hÃ¡t Ä‘á»ƒ táº¡o';

  @override
  String get acousticness => 'Äá»™ Ã¢m thanh';

  @override
  String get danceability => 'Kháº£ nÄƒng nháº£y';

  @override
  String get energy => 'NÄƒng lÆ°á»£ng';

  @override
  String get instrumentalness => 'Äá»™ nháº¡c cá»¥';

  @override
  String get liveness => 'Sá»‘ng Ä‘á»™ng';

  @override
  String get loudness => 'Äá»™ á»“n';

  @override
  String get speechiness => 'Äá»™ nÃ³i';

  @override
  String get valence => 'TÃ­nh tÃ­ch cá»±c';

  @override
  String get popularity => 'Äá»™ phá»• biáº¿n';

  @override
  String get key => 'TÃ´ng';

  @override
  String get duration => 'Thá»i lÆ°á»£ng (giÃ¢y)';

  @override
  String get tempo => 'Nhá»‹p Ä‘á»™ (BPM)';

  @override
  String get mode => 'Cháº¿ Ä‘á»™';

  @override
  String get time_signature => 'Chá»¯ kÃ½ thá»i gian';

  @override
  String get short => 'Ngáº¯n';

  @override
  String get medium => 'Trung bÃ¬nh';

  @override
  String get long => 'DÃ i';

  @override
  String get min => 'Tá»‘i thiá»ƒu';

  @override
  String get max => 'Tá»‘i Ä‘a';

  @override
  String get target => 'Má»¥c tiÃªu';

  @override
  String get moderate => 'Trung bÃ¬nh';

  @override
  String get deselect_all => 'Bá» chá»n táº¥t cáº£';

  @override
  String get select_all => 'Chá»n táº¥t cáº£';

  @override
  String get are_you_sure => 'Báº¡n cÃ³ cháº¯c cháº¯n?';

  @override
  String get generating_playlist =>
      'Äang táº¡o danh sÃ¡ch phÃ¡t tÃ¹y chá»‰nh cá»§a báº¡n...';

  @override
  String selected_count_tracks(Object count) {
    return 'ÄÃ£ chá»n $count bÃ i hÃ¡t';
  }

  @override
  String get download_warning =>
      'Táº£i xuá»‘ng táº¥t cáº£ cÃ¡c bÃ i hÃ¡t má»™t láº§n, sáº½ vi pháº¡m báº£n quyá»n Ã¢m nháº¡c vÃ  gÃ¢y thiá»‡t háº¡i cho xÃ£ há»™i sÃ¡ng táº¡o Ã¢m nháº¡c. Hy vá»ng báº¡n nháº­n thá»©c Ä‘Æ°á»£c Ä‘iá»u nÃ y. HÃ£y luÃ´n tÃ´n trá»ng vÃ  á»§ng há»™ cÃ´ng sá»©c cá»§a nghá»‡ sÄ©';

  @override
  String get download_ip_ban_warning =>
      'Äá»‹a chá»‰ IP cá»§a báº¡n cÃ³ thá»ƒ bá»‹ cháº·n trÃªn YouTube do yÃªu cáº§u táº£i xuá»‘ng quÃ¡ má»©c so vá»›i bÃ¬nh thÆ°á»ng. Cháº·n IP cÃ³ nghÄ©a lÃ  báº¡n khÃ´ng thá»ƒ sá»­ dá»¥ng YouTube (ngay cáº£ khi báº¡n Ä‘Ã£ Ä‘Äƒng nháº­p) Ã­t nháº¥t 2-3 thÃ¡ng tá»« thiáº¿t bá»‹ IP Ä‘Ã³. VÃ  Soulful Bhakti khÃ´ng chá»‹u trÃ¡ch nhiá»‡m náº¿u Ä‘iá»u nÃ y xáº£y ra';

  @override
  String get by_clicking_accept_terms =>
      'Báº±ng cÃ¡ch nháº¥p vÃ o \'Cháº¥p nháº­n\', báº¡n Ä‘á»“ng Ã½ vá»›i cÃ¡c Ä‘iá»u khoáº£n sau:';

  @override
  String get download_agreement_1 =>
      'TÃ´i biáº¿t mÃ¬nh Ä‘ang vi pháº¡m báº£n quyá»n Ã¢m nháº¡c. ÄÃ³ lÃ  khÃ´ng tá»‘t.';

  @override
  String get download_agreement_2 =>
      'TÃ´i sáº½ á»§ng há»™ nghá»‡ sÄ© báº¥t cá»© nÆ¡i nÃ o tÃ´i cÃ³ thá»ƒ vÃ  tÃ´i chá»‰ lÃ m Ä‘iá»u nÃ y vÃ¬ tÃ´i khÃ´ng cÃ³ tiá»n Ä‘á»ƒ mua tÃ¡c pháº©m cá»§a há»';

  @override
  String get download_agreement_3 =>
      'TÃ´i hoÃ n toÃ n nháº­n thá»©c Ä‘Æ°á»£c ráº±ng Ä‘á»‹a chá»‰ IP cá»§a tÃ´i cÃ³ thá»ƒ bá»‹ cháº·n trÃªn YouTube vÃ  tÃ´i khÃ´ng Ä‘á»• lá»—i cho Soulful Bhakti hoáº·c chá»§ sá»Ÿ há»¯u/ngÆ°á»i Ä‘Ã³ng gÃ³p cá»§a nÃ³ vá» báº¥t ká»³ tai náº¡n nÃ o do hÃ nh Ä‘á»™ng nÃ y cá»§a tÃ´i';

  @override
  String get decline => 'Tá»« chá»‘i';

  @override
  String get accept => 'Cháº¥p nháº­n';

  @override
  String get details => 'Chi tiáº¿t';

  @override
  String get youtube => 'YouTube';

  @override
  String get channel => 'KÃªnh';

  @override
  String get likes => 'ThÃ­ch';

  @override
  String get dislikes => 'KhÃ´ng thÃ­ch';

  @override
  String get views => 'LÆ°á»£t xem';

  @override
  String get streamUrl => 'URL phÃ¡t trá»±c tiáº¿p';

  @override
  String get stop => 'Dá»«ng';

  @override
  String get sort_newest => 'Sáº¯p xáº¿p theo má»›i nháº¥t';

  @override
  String get sort_oldest => 'Sáº¯p xáº¿p theo cÅ© nháº¥t';

  @override
  String get sleep_timer => 'Háº¹n giá» táº¯t';

  @override
  String mins(Object minutes) {
    return '$minutes PhÃºt';
  }

  @override
  String hours(Object hours) {
    return '$hours Giá»';
  }

  @override
  String hour(Object hours) {
    return '$hours Giá»';
  }

  @override
  String get custom_hours => 'Giá» TÃ¹y chá»‰nh';

  @override
  String get logs => 'Nháº­t kÃ½';

  @override
  String get developers => 'NhÃ  phÃ¡t triá»ƒn';

  @override
  String get not_logged_in => 'Báº¡n chÆ°a Ä‘Äƒng nháº­p';

  @override
  String get search_mode => 'Cháº¿ Ä‘á»™ tÃ¬m kiáº¿m';

  @override
  String get audio_source => 'Nguá»“n Ã¢m thanh';

  @override
  String get ok => 'Ok';

  @override
  String get failed_to_encrypt => 'MÃ£ hÃ³a khÃ´ng thÃ nh cÃ´ng';

  @override
  String get encryption_failed_warning =>
      'Soulful Bhakti khÃ´ng thÃ nh cÃ´ng trong viá»‡c mÃ£ hÃ³a nháº±m lÆ°u trá»¯ dá»¯ liÃªu an toÃ n. váº­y nÃªn sáº½ chuyá»ƒn vá» lÆ°u trá»¯ khÃ´ng an toÃ n\nNáº¿u báº¡n Ä‘ang sá»­ dá»¥ng Linux, Ä‘áº£m báº£o ráº±ng báº¡n cÃ³ sá»­ dá»¥ng dá»‹ch vá»¥ báº£o máº­t (gnome-keyring, kde-wallet, keepassxc, v.v.)';

  @override
  String get querying_info => 'Äang truy váº¥n thÃ´ng tin...';

  @override
  String get piped_api_down => 'API Piped Ä‘ang gáº·p sá»± cá»‘';

  @override
  String piped_down_error_instructions(Object pipedInstance) {
    return 'PhiÃªn báº£n Piped $pipedInstance hiá»‡n Ä‘ang gáº·p sá»± cá»‘\n\nThay Ä‘á»•i phiÃªn báº£n hoáº·c thay Ä‘á»•i \'Loáº¡i API\' thÃ nh API YouTube official\n\nKhá»Ÿi Ä‘á»™ng lai á»©ng dá»¥ng sau khi thay Ä‘á»•i.';
  }

  @override
  String get you_are_offline => 'Báº¡n Ä‘ang ngoáº¡i tuyáº¿n';

  @override
  String get connection_restored =>
      'Káº¿t ná»‘i internet cá»§a báº¡n Ä‘Ã£ Ä‘Æ°á»£c khÃ´i phá»¥c';

  @override
  String get use_system_title_bar =>
      'Sá»­ dá»¥ng thanh tiÃªu Ä‘á» há»‡ thá»‘ng';

  @override
  String get crunching_results => 'Äang tÃ¬m kiáº¿m...';

  @override
  String get search_to_get_results => 'ChÆ°a tÃ¬m kiáº¿m';

  @override
  String get use_amoled_mode => 'Chá»§ Ä‘á» tá»‘i hoÃ n toÃ n';

  @override
  String get pitch_dark_theme => 'Cháº¿ Ä‘á»™ AMOLED';

  @override
  String get normalize_audio => 'BÃ¬nh thÆ°á»ng hÃ³a Ã¢m thanh';

  @override
  String get change_cover => 'Thay Ä‘á»•i áº£nh bÃ¬a';

  @override
  String get add_cover => 'ThÃªm áº£nh bÃ¬a';

  @override
  String get restore_defaults => 'KhÃ´i phá»¥c máº·c Ä‘á»‹nh';

  @override
  String get restore_defaults_confirmation =>
      'Thao tÃ¡c nÃ y sáº½ Ä‘áº·t láº¡i táº¥t cáº£ cÃ i Ä‘áº·t cá»§a báº¡n vá» giÃ¡ trá»‹ máº·c Ä‘á»‹nh. HÃ nh Ä‘á»™ng nÃ y khÃ´ng thá»ƒ hoÃ n tÃ¡c.';

  @override
  String get streaming_music_format =>
      'Äá»‹nh dáº¡ng nháº¡c phÃ¡t trá»±c tuyáº¿n';

  @override
  String get streaming_music_quality =>
      'Cháº¥t lÆ°á»£ng nháº¡c phÃ¡t trá»±c tuyáº¿n';

  @override
  String get connect => 'LiÃªn káº¿t';

  @override
  String get disconnect => 'Ngáº¯t káº¿t ná»‘i';

  @override
  String get username => 'TÃªn ngÆ°á»i dÃ¹ng';

  @override
  String get password => 'Máº­t kháº©u';

  @override
  String get login => 'ÄÄƒng nháº­p';

  @override
  String get sign_in => 'ÄÄƒng nháº­p';

  @override
  String get sign_up => 'ÄÄƒng kÃ½';

  @override
  String get sign_out => 'ÄÄƒng xuáº¥t';

  @override
  String get verify => 'XÃ¡c minh';

  @override
  String get create_account => 'Táº¡o tÃ i khoáº£n cá»§a báº¡n';

  @override
  String get already_have_account => 'ÄÃ£ cÃ³ tÃ i khoáº£n? ÄÄƒng nháº­p';

  @override
  String get dont_have_account => 'ChÆ°a cÃ³ tÃ i khoáº£n? ÄÄƒng kÃ½';

  @override
  String signed_in_as(Object userId) {
    return 'ÄÃ£ Ä‘Äƒng nháº­p vá»›i tÃªn $userId';
  }

  @override
  String get verification_code => 'MÃ£ xÃ¡c minh';

  @override
  String get verification_code_hint =>
      'Nháº­p mÃ£ Ä‘Ã£ gá»­i Ä‘áº¿n email cá»§a báº¡n';

  @override
  String get verify_email_code =>
      'ChÃºng tÃ´i Ä‘Ã£ gá»­i mÃ£ xÃ¡c minh Ä‘áº¿n email cá»§a báº¡n';

  @override
  String get go_to_album => 'Äi Ä‘áº¿n Album';

  @override
  String get discord_rich_presence => 'Hiá»ƒn thá»‹ tráº¡ng thÃ¡i Discord';

  @override
  String get browse_all => 'Duyá»‡t táº¥t cáº£';

  @override
  String get genres => 'Thá»ƒ loáº¡i';

  @override
  String get explore_genres => 'KhÃ¡m phÃ¡ Thá»ƒ loáº¡i';

  @override
  String get friends => 'Báº¡n bÃ¨';

  @override
  String get no_lyrics_available =>
      'Xin lá»—i, khÃ´ng tÃ¬m tháº¥y lá»i cho bÃ i hÃ¡t nÃ y';

  @override
  String get start_a_radio => 'Báº¯t Ä‘áº§u Má»™t ÄÃ i phÃ¡t thanh';

  @override
  String get how_to_start_radio =>
      'Báº¡n muá»‘n báº¯t Ä‘áº§u Ä‘Ã i phÃ¡t thanh nhÆ° tháº¿ nÃ o?';

  @override
  String get replace_queue_question =>
      'Báº¡n muá»‘n thay tháº¿ hÃ ng Ä‘á»£i hiá»‡n táº¡i hay thÃªm vÃ o?';

  @override
  String get endless_playback => 'PhÃ¡t khÃ´ng giá»›i háº¡n';

  @override
  String get delete_playlist => 'XÃ³a Danh sÃ¡ch phÃ¡t';

  @override
  String get delete_playlist_confirmation =>
      'Báº¡n cÃ³ cháº¯c cháº¯n muá»‘n xÃ³a danh sÃ¡ch phÃ¡t nÃ y khÃ´ng?';

  @override
  String get local_tracks => 'BÃ i hÃ¡t Äá»‹a phÆ°Æ¡ng';

  @override
  String get local_tab => 'Äá»‹a phÆ°Æ¡ng';

  @override
  String get song_link => 'LiÃªn káº¿t BÃ i hÃ¡t';

  @override
  String get skip_this_nonsense => 'Bá» qua bá»›t rá»‘i nÃ y';

  @override
  String get freedom_of_music => 'â€œSá»± Tá»± do cá»§a Ã‚m nháº¡câ€';

  @override
  String get freedom_of_music_palm =>
      'â€œSá»± Tá»± do cá»§a Ã‚m nháº¡c trong lÃ²ng bÃ n tay cá»§a báº¡nâ€';

  @override
  String get get_started => 'Báº¯t Ä‘áº§u thÃ´i';

  @override
  String get youtube_source_description =>
      'ÄÆ°á»£c Ä‘á» xuáº¥t vÃ  hoáº¡t Ä‘á»™ng tá»‘t nháº¥t.';

  @override
  String get piped_source_description =>
      'Cáº£m tháº¥y tá»± do? Giá»‘ng nhÆ° YouTube nhÆ°ng miá»…n phÃ­ hÆ¡n ráº¥t nhiá»u.';

  @override
  String get jiosaavn_source_description =>
      'Tá»‘t nháº¥t cho khu vá»±c Nam Ã.';

  @override
  String get invidious_source_description =>
      'TÆ°Æ¡ng tá»± nhÆ° Piped nhÆ°ng cÃ³ tÃ­nh kháº£ dá»¥ng cao hÆ¡n.';

  @override
  String highest_quality(Object quality) {
    return 'Cháº¥t lÆ°á»£ng Tá»‘t nháº¥t: $quality';
  }

  @override
  String get select_audio_source => 'Chá»n Nguá»“n Ã‚m thanh';

  @override
  String get endless_playback_description =>
      'Tá»± Ä‘á»™ng thÃªm cÃ¡c bÃ i hÃ¡t má»›i\nvÃ o cuá»‘i hÃ ng Ä‘á»£i';

  @override
  String get choose_your_region => 'Chá»n khu vá»±c cá»§a báº¡n';

  @override
  String get choose_your_region_description =>
      'Äiá»u nÃ y sáº½ giÃºp Soulful Bhakti hiá»ƒn thá»‹ ná»™i dung phÃ¹ há»£p cho vá»‹ trÃ­ cá»§a báº¡n.';

  @override
  String get choose_your_language => 'Chá»n ngÃ´n ngá»¯ cá»§a báº¡n';

  @override
  String get help_project_grow => 'HÃ£y giÃºp dá»± Ã¡n nÃ y phÃ¡t triá»ƒn';

  @override
  String get help_project_grow_description =>
      'Soulful Bhakti lÃ  má»™t dá»± Ã¡n mÃ£ nguá»“n má»Ÿ. Báº¡n cÃ³ thá»ƒ giÃºp dá»± Ã¡n nÃ y phÃ¡t triá»ƒn báº±ng cÃ¡ch Ä‘Ã³ng gÃ³p vÃ o dá»± Ã¡n, bÃ¡o cÃ¡o lá»—i hoáº·c Ä‘á» xuáº¥t tÃ­nh nÄƒng má»›i.';

  @override
  String get contribute_on_github => 'ÄÃ³ng gÃ³p trÃªn GitHub';

  @override
  String get donate_on_open_collective => 'QuyÃªn gÃ³p trÃªn Open Collective';

  @override
  String get browse_anonymously => 'Duyá»‡t Anonymously';

  @override
  String get enable_connect => 'KÃ­ch hoáº¡t káº¿t ná»‘i';

  @override
  String get enable_connect_description =>
      'Äiá»u khiá»ƒn Soulful Bhakti tá»« cÃ¡c thiáº¿t bá»‹ khÃ¡c';

  @override
  String get devices => 'Thiáº¿t bá»‹';

  @override
  String get select => 'Chá»n';

  @override
  String connect_client_alert(Object client) {
    return 'Báº¡n Ä‘ang Ä‘Æ°á»£c Ä‘iá»u khiá»ƒn bá»Ÿi $client';
  }

  @override
  String get this_device => 'Thiáº¿t bá»‹ nÃ y';

  @override
  String get remote => 'Tá»« xa';

  @override
  String get stats => 'Thá»‘ng kÃª';

  @override
  String and_n_more(Object count) {
    return 'vÃ  $count cÃ¡i khÃ¡c';
  }

  @override
  String get recently_played => 'Gáº§n Ä‘Ã¢y Ä‘Ã£ phÃ¡t';

  @override
  String get browse_more => 'Xem thÃªm';

  @override
  String get no_title => 'KhÃ´ng cÃ³ tiÃªu Ä‘á»';

  @override
  String get not_playing => 'KhÃ´ng phÃ¡t';

  @override
  String get epic_failure => 'Tháº¥t báº¡i hoÃ n toÃ n!';

  @override
  String added_num_tracks_to_queue(Object tracks_length) {
    return 'ÄÃ£ thÃªm $tracks_length bÃ i hÃ¡t vÃ o danh sÃ¡ch phÃ¡t';
  }

  @override
  String get spotube_has_an_update => 'Soulful Bhakti cÃ³ báº£n cáº­p nháº­t';

  @override
  String get download_now => 'Táº£i vá» ngay';

  @override
  String nightly_version(Object nightlyBuildNum) {
    return 'Soulful Bhakti Nightly $nightlyBuildNum Ä‘Ã£ Ä‘Æ°á»£c phÃ¡t hÃ nh';
  }

  @override
  String release_version(Object version) {
    return 'Soulful Bhakti v$version Ä‘Ã£ Ä‘Æ°á»£c phÃ¡t hÃ nh';
  }

  @override
  String get read_the_latest => 'Äá»c tin má»›i nháº¥t';

  @override
  String get release_notes => 'ghi chÃº phÃ¡t hÃ nh';

  @override
  String get pick_color_scheme => 'Chá»n chá»§ Ä‘á» mÃ u sáº¯c';

  @override
  String get save => 'LÆ°u';

  @override
  String get choose_the_device => 'Chá»n thiáº¿t bá»‹:';

  @override
  String get multiple_device_connected =>
      'CÃ³ nhiá»u thiáº¿t bá»‹ káº¿t ná»‘i.\nChá»n thiáº¿t bá»‹ mÃ  báº¡n muá»‘n thá»±c hiá»‡n hÃ nh Ä‘á»™ng nÃ y';

  @override
  String get nothing_found => 'KhÃ´ng tÃ¬m tháº¥y gÃ¬';

  @override
  String get the_box_is_empty => 'Há»™p trá»‘ng';

  @override
  String get top_artists => 'Nhá»¯ng Nghá»‡ SÄ© HÃ ng Äáº§u';

  @override
  String get top_albums => 'Nhá»¯ng Album HÃ ng Äáº§u';

  @override
  String get this_week => 'Tuáº§n nÃ y';

  @override
  String get this_month => 'ThÃ¡ng nÃ y';

  @override
  String get last_6_months => '6 thÃ¡ng qua';

  @override
  String get this_year => 'NÄƒm nay';

  @override
  String get last_2_years => '2 nÄƒm qua';

  @override
  String get all_time => 'Má»i thá»i Ä‘áº¡i';

  @override
  String powered_by_provider(Object providerName) {
    return 'Cung cáº¥p bá»Ÿi $providerName';
  }

  @override
  String get email => 'Email';

  @override
  String get send_code => 'Gá»­i mÃ£';

  @override
  String get change_identifier => 'DÃ¹ng email khÃ¡c';

  @override
  String get sign_in_with_otp => 'ÄÄƒng nháº­p báº±ng mÃ£ dÃ¹ng má»™t láº§n';

  @override
  String get enter_otp_sent => 'Nháº­p mÃ£ chÃºng tÃ´i Ä‘Ã£ gá»­i cho báº¡n';

  @override
  String get verify_email_reminder =>
      'Vui lÃ²ng xÃ¡c minh Ä‘á»‹a chá»‰ email cá»§a báº¡n Ä‘á»ƒ báº£o máº­t tÃ i khoáº£n';

  @override
  String get verify_now => 'XÃ¡c minh ngay';

  @override
  String get enter_email_to_verify =>
      'Nháº­p Ä‘á»‹a chá»‰ email cá»§a báº¡n Ä‘á»ƒ nháº­n mÃ£ xÃ¡c minh';

  @override
  String get profile_followers => 'NgÆ°á»i theo dÃµi';

  @override
  String get birthday => 'NgÃ y sinh';

  @override
  String get subscription => 'GÃ³i cÆ°á»›c';

  @override
  String get not_born => 'ChÆ°a sinh';

  @override
  String get hacker => 'Tin táº·c';

  @override
  String get profile => 'Há»“ sÆ¡';

  @override
  String get no_name => 'KhÃ´ng cÃ³ tÃªn';

  @override
  String get edit => 'Chá»‰nh sá»­a';

  @override
  String get user_profile => 'Há»“ sÆ¡ ngÆ°á»i dÃ¹ng';

  @override
  String count_plays(Object count) {
    return '$count láº§n phÃ¡t';
  }

  @override
  String get streaming_fees_hypothetical =>
      '*TÃ­nh toÃ¡n dá»±a trÃªn thanh toÃ¡n cá»§a Spotify cho má»—i láº§n phÃ¡t\ntá»« \$0.003 Ä‘áº¿n \$0.005. ÄÃ¢y lÃ  má»™t tÃ­nh toÃ¡n giáº£ Ä‘á»‹nh Ä‘á»ƒ\ngive ngÆ°á»i dÃ¹ng cÃ¡i nhÃ¬n vá» sá»‘ tiá»n há» sáº½ chi tráº£ cho cÃ¡c nghá»‡ sÄ© náº¿u há» nghe\nbÃ i hÃ¡t cá»§a há» trÃªn Spotify.';

  @override
  String get minutes_listened => 'Thá»i gian nghe';

  @override
  String get streamed_songs => 'BÃ i hÃ¡t Ä‘Ã£ phÃ¡t';

  @override
  String count_streams(Object count) {
    return '$count lÆ°á»£t phÃ¡t';
  }

  @override
  String get owned_by_you => 'Thuá»™c sá»Ÿ há»¯u cá»§a báº¡n';

  @override
  String copied_shareurl_to_clipboard(Object shareUrl) {
    return '$shareUrl Ä‘Ã£ sao chÃ©p vÃ o báº£ng táº¡m';
  }

  @override
  String get hipotetical_calculation =>
      '*Äiá»u nÃ y Ä‘Æ°á»£c tÃ­nh toÃ¡n dá»±a trÃªn khoáº£n thanh toÃ¡n trung bÃ¬nh má»—i luá»“ng cá»§a ná»n táº£ng phÃ¡t nháº¡c trá»±c tuyáº¿n lÃ  \$0,003 Ä‘áº¿n \$0,005. ÄÃ¢y lÃ  má»™t phÃ©p tÃ­nh giáº£ Ä‘á»‹nh Ä‘á»ƒ cung cáº¥p cho ngÆ°á»i dÃ¹ng cÃ¡i nhÃ¬n sÃ¢u sáº¯c vá» sá»‘ tiá»n há» Ä‘Ã£ tráº£ cho cÃ¡c nghá»‡ sÄ© náº¿u há» nghe bÃ i hÃ¡t cá»§a há» trÃªn cÃ¡c ná»n táº£ng phÃ¡t nháº¡c trá»±c tuyáº¿n khÃ¡c nhau.';

  @override
  String count_mins(Object minutes) {
    return '$minutes phÃºt';
  }

  @override
  String get summary_minutes => 'phÃºt';

  @override
  String get summary_listened_to_music => 'ÄÃ£ nghe nháº¡c';

  @override
  String get summary_songs => 'bÃ i hÃ¡t';

  @override
  String get summary_streamed_overall => 'Stream tá»•ng cá»™ng';

  @override
  String get summary_owed_to_artists => 'Ná»£ nghá»‡ sÄ©\ntrong thÃ¡ng nÃ y';

  @override
  String get summary_top_artist => 'Nghá»‡ sÄ© hÃ ng Ä‘áº§u\nká»³ nÃ y';

  @override
  String get summary_artists => 'nghá»‡ sÄ©';

  @override
  String get summary_music_reached_you => 'Ã‚m nháº¡c Ä‘Ã£ Ä‘áº¿n vá»›i báº¡n';

  @override
  String get summary_full_albums => 'album Ä‘áº§y Ä‘á»§';

  @override
  String get summary_got_your_love => 'Nháº­n Ä‘Æ°á»£c tÃ¬nh yÃªu cá»§a báº¡n';

  @override
  String get summary_playlists => 'danh sÃ¡ch phÃ¡t';

  @override
  String get summary_were_on_repeat => 'ÄÃ£ Ä‘Æ°á»£c phÃ¡t láº¡i';

  @override
  String get summary_listening_share => 'Thá»‹ pháº§n nghe';

  @override
  String summary_listening_share_description(Object tracks_length) {
    return 'PhÃ¢n bá»‘ $tracks_length bÃ i hÃ¡t hÃ ng Ä‘áº§u báº¡n Ä‘Ã£ nghe nhiá»u nháº¥t';
  }

  @override
  String get summary_plays => 'lÆ°á»£t phÃ¡t';

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
    return 'Tá»•ng cá»™ng $money';
  }

  @override
  String get webview_not_found => 'KhÃ´ng tÃ¬m tháº¥y Webview';

  @override
  String get webview_not_found_description =>
      'KhÃ´ng cÃ³ runtime Webview nÃ o Ä‘Æ°á»£c cÃ i Ä‘áº·t trÃªn thiáº¿t bá»‹ cá»§a báº¡n.\nNáº¿u Ä‘Ã£ cÃ i Ä‘áº·t, hÃ£y Ä‘áº£m báº£o ráº±ng nÃ³ náº±m trong environment PATH\n\nSau khi cÃ i Ä‘áº·t, hÃ£y khá»Ÿi Ä‘á»™ng láº¡i á»©ng dá»¥ng';

  @override
  String get unsupported_platform => 'Ná»n táº£ng khÃ´ng Ä‘Æ°á»£c há»— trá»£';

  @override
  String get cache_music => 'LÆ°u nháº¡c vÃ o bá»™ nhá»› Ä‘á»‡m';

  @override
  String get open => 'Má»Ÿ';

  @override
  String get cache_folder => 'ThÆ° má»¥c bá»™ nhá»› Ä‘á»‡m';

  @override
  String get export => 'Xuáº¥t';

  @override
  String get clear_cache => 'XÃ³a bá»™ nhá»› Ä‘á»‡m';

  @override
  String get clear_cache_confirmation =>
      'Báº¡n cÃ³ muá»‘n xÃ³a bá»™ nhá»› Ä‘á»‡m khÃ´ng?';

  @override
  String get export_cache_files =>
      'Xuáº¥t cÃ¡c tá»‡p Ä‘Æ°á»£c lÆ°u trong bá»™ nhá»› Ä‘á»‡m';

  @override
  String found_n_files(Object count) {
    return 'TÃ¬m tháº¥y $count tá»‡p';
  }

  @override
  String get export_cache_confirmation =>
      'Báº¡n cÃ³ muá»‘n xuáº¥t cÃ¡c tá»‡p nÃ y Ä‘áº¿n';

  @override
  String exported_n_out_of_m_files(Object files, Object filesExported) {
    return 'ÄÃ£ xuáº¥t $filesExported trÃªn $files tá»‡p';
  }

  @override
  String get undo => 'HoÃ n tÃ¡c';

  @override
  String get add_all_to_playlist => 'ThÃªm táº¥t cáº£ vÃ o danh sÃ¡ch phÃ¡t';

  @override
  String get add_all_to_queue => 'ThÃªm táº¥t cáº£ vÃ o danh sÃ¡ch chá»';

  @override
  String get play_all_next => 'ChÆ¡i táº¥t cáº£ tiáº¿p theo';

  @override
  String get pause => 'Táº¡m dá»«ng';

  @override
  String get view_all => 'Xem táº¥t cáº£';

  @override
  String get no_tracks_added_yet =>
      'CÃ³ váº» báº¡n chÆ°a thÃªm báº¥t ká»³ bÃ i hÃ¡t nÃ o';

  @override
  String get no_tracks => 'CÃ³ váº» khÃ´ng cÃ³ bÃ i hÃ¡t nÃ o á»Ÿ Ä‘Ã¢y';

  @override
  String get no_tracks_listened_yet => 'CÃ³ váº» báº¡n chÆ°a nghe gÃ¬ cáº£';

  @override
  String get not_following_artists =>
      'Báº¡n khÃ´ng Ä‘ang theo dÃµi báº¥t ká»³ nghá»‡ sÄ© nÃ o';

  @override
  String get no_favorite_albums_yet =>
      'CÃ³ váº» báº¡n chÆ°a thÃªm album nÃ o vÃ o danh sÃ¡ch yÃªu thÃ­ch';

  @override
  String get no_logs_found => 'KhÃ´ng tÃ¬m tháº¥y nháº­t kÃ½';

  @override
  String get youtube_engine => 'CÃ´ng cá»¥ YouTube';

  @override
  String youtube_engine_not_installed_title(Object engine) {
    return '$engine chÆ°a Ä‘Æ°á»£c cÃ i Ä‘áº·t';
  }

  @override
  String youtube_engine_not_installed_message(Object engine) {
    return '$engine chÆ°a Ä‘Æ°á»£c cÃ i Ä‘áº·t trong há»‡ thá»‘ng cá»§a báº¡n.';
  }

  @override
  String youtube_engine_set_path(Object engine) {
    return 'Äáº£m báº£o nÃ³ cÃ³ sáºµn trong biáº¿n PATH hoáº·c\nÄ‘áº·t Ä‘Æ°á»ng dáº«n tuyá»‡t Ä‘á»‘i Ä‘áº¿n tá»‡p thá»±c thi $engine dÆ°á»›i Ä‘Ã¢y';
  }

  @override
  String get youtube_engine_unix_issue_message =>
      'TrÃªn macOS/Linux/Unix, viá»‡c thiáº¿t láº­p Ä‘Æ°á»ng dáº«n trong .zshrc/.bashrc/.bash_profile v.v. sáº½ khÃ´ng hoáº¡t Ä‘á»™ng.\nBáº¡n cáº§n thiáº¿t láº­p Ä‘Æ°á»ng dáº«n trong tá»‡p cáº¥u hÃ¬nh shell';

  @override
  String get download => 'Táº£i xuá»‘ng';

  @override
  String get file_not_found => 'KhÃ´ng tÃ¬m tháº¥y tá»‡p';

  @override
  String get custom => 'TÃ¹y chá»‰nh';

  @override
  String get add_custom_url => 'ThÃªm URL tÃ¹y chá»‰nh';

  @override
  String get edit_port => 'Chá»‰nh sá»­a cá»•ng';

  @override
  String get port_helper_msg =>
      'Máº·c Ä‘á»‹nh lÃ  -1, cÃ³ nghÄ©a lÃ  sá»‘ ngáº«u nhiÃªn. Náº¿u báº¡n Ä‘Ã£ cáº¥u hÃ¬nh tÆ°á»ng lá»­a, nÃªn Ä‘áº·t Ä‘iá»u nÃ y.';

  @override
  String connect_request(Object client) {
    return 'Cho phÃ©p $client káº¿t ná»‘i?';
  }

  @override
  String get connection_request_denied =>
      'Káº¿t ná»‘i bá»‹ tá»« chá»‘i. NgÆ°á»i dÃ¹ng Ä‘Ã£ tá»« chá»‘i quyá»n truy cáº­p.';

  @override
  String get an_error_occurred => 'ÄÃ£ xáº£y ra lá»—i';

  @override
  String get copy_to_clipboard => 'Sao chÃ©p vÃ o khay nhá»› táº¡m';

  @override
  String get view_logs => 'Xem nháº­t kÃ½';

  @override
  String get retry => 'Thá»­ láº¡i';

  @override
  String get no_default_metadata_provider_selected =>
      'Báº¡n chÆ°a Ä‘áº·t nhÃ  cung cáº¥p siÃªu dá»¯ liá»‡u máº·c Ä‘á»‹nh nÃ o';

  @override
  String get manage_metadata_providers =>
      'Quáº£n lÃ½ nhÃ  cung cáº¥p siÃªu dá»¯ liá»‡u';

  @override
  String get open_link_in_browser => 'Má»Ÿ liÃªn káº¿t trong TrÃ¬nh duyá»‡t?';

  @override
  String get do_you_want_to_open_the_following_link =>
      'Báº¡n cÃ³ muá»‘n má»Ÿ liÃªn káº¿t sau khÃ´ng';

  @override
  String get unsafe_url_warning =>
      'Viá»‡c má»Ÿ cÃ¡c liÃªn káº¿t tá»« cÃ¡c nguá»“n khÃ´ng Ä‘Ã¡ng tin cáº­y cÃ³ thá»ƒ khÃ´ng an toÃ n. HÃ£y tháº­n trá»ng!\nBáº¡n cÅ©ng cÃ³ thá»ƒ sao chÃ©p liÃªn káº¿t vÃ o khay nhá»› táº¡m cá»§a mÃ¬nh.';

  @override
  String get copy_link => 'Sao chÃ©p liÃªn káº¿t';

  @override
  String get building_your_timeline =>
      'Äang xÃ¢y dá»±ng dÃ²ng thá»i gian cá»§a báº¡n dá»±a trÃªn nhá»¯ng gÃ¬ báº¡n Ä‘Ã£ nghe...';

  @override
  String get official => 'ChÃ­nh thá»©c';

  @override
  String author_name(Object author) {
    return 'TÃ¡c giáº£: $author';
  }

  @override
  String get third_party => 'BÃªn thá»© ba';

  @override
  String get plugin_requires_authentication => 'Plugin yÃªu cáº§u xÃ¡c thá»±c';

  @override
  String get update_available => 'CÃ³ báº£n cáº­p nháº­t';

  @override
  String get supports_scrobbling => 'Há»— trá»£ scrobbling';

  @override
  String get plugin_scrobbling_info =>
      'Plugin nÃ y scrobble nháº¡c cá»§a báº¡n Ä‘á»ƒ táº¡o lá»‹ch sá»­ nghe cá»§a báº¡n.';

  @override
  String get default_metadata_source =>
      'Nguá»“n siÃªu dá»¯ liá»‡u máº·c Ä‘á»‹nh';

  @override
  String get set_default_metadata_source =>
      'Äáº·t nguá»“n siÃªu dá»¯ liá»‡u máº·c Ä‘á»‹nh';

  @override
  String get default_audio_source => 'Nguá»“n Ã¢m thanh máº·c Ä‘á»‹nh';

  @override
  String get set_default_audio_source =>
      'Äáº·t nguá»“n Ã¢m thanh máº·c Ä‘á»‹nh';

  @override
  String get set_default => 'Äáº·t lÃ m máº·c Ä‘á»‹nh';

  @override
  String get support => 'Há»— trá»£';

  @override
  String get support_plugin_development => 'Há»— trá»£ phÃ¡t triá»ƒn plugin';

  @override
  String can_access_name_api(Object name) {
    return '- CÃ³ thá»ƒ truy cáº­p API **$name**';
  }

  @override
  String get do_you_want_to_install_this_plugin =>
      'Báº¡n cÃ³ muá»‘n cÃ i Ä‘áº·t plugin nÃ y khÃ´ng?';

  @override
  String get third_party_plugin_warning =>
      'Plugin nÃ y Ä‘áº¿n tá»« má»™t kho lÆ°u trá»¯ cá»§a bÃªn thá»© ba. Vui lÃ²ng Ä‘áº£m báº£o ráº±ng báº¡n tin tÆ°á»Ÿng nguá»“n trÆ°á»›c khi cÃ i Ä‘áº·t.';

  @override
  String get author => 'TÃ¡c giáº£';

  @override
  String get this_plugin_can_do_following =>
      'Plugin nÃ y cÃ³ thá»ƒ lÃ m nhá»¯ng viá»‡c sau';

  @override
  String get install => 'CÃ i Ä‘áº·t';

  @override
  String get install_a_metadata_provider =>
      'CÃ i Ä‘áº·t má»™t NhÃ  cung cáº¥p siÃªu dá»¯ liá»‡u';

  @override
  String get no_tracks_playing =>
      'Hiá»‡n khÃ´ng cÃ³ báº£n nháº¡c nÃ o Ä‘ang phÃ¡t';

  @override
  String get synced_lyrics_not_available =>
      'Lá»i bÃ i hÃ¡t Ä‘Æ°á»£c Ä‘á»“ng bá»™ hÃ³a khÃ´ng cÃ³ sáºµn cho bÃ i hÃ¡t nÃ y. Vui lÃ²ng sá»­ dá»¥ng';

  @override
  String get plain_lyrics => 'Lá»i bÃ i hÃ¡t thuáº§n tÃºy';

  @override
  String get tab_instead => 'thay tháº¿.';

  @override
  String get disclaimer => 'Miá»…n trá»« trÃ¡ch nhiá»‡m';

  @override
  String get third_party_plugin_dmca_notice =>
      'NhÃ³m Soulful Bhakti khÃ´ng chá»‹u báº¥t ká»³ trÃ¡ch nhiá»‡m nÃ o (bao gá»“m cáº£ phÃ¡p lÃ½) Ä‘á»‘i vá»›i báº¥t ká»³ plugin \"BÃªn thá»© ba\" nÃ o.\nVui lÃ²ng sá»­ dá»¥ng chÃºng vá»›i rá»§i ro cá»§a riÃªng báº¡n. Äá»‘i vá»›i báº¥t ká»³ lá»—i/váº¥n Ä‘á» nÃ o, vui lÃ²ng bÃ¡o cÃ¡o chÃºng cho kho lÆ°u trá»¯ plugin.\n\nNáº¿u báº¥t ká»³ plugin \"BÃªn thá»© ba\" nÃ o vi pháº¡m ToS/DMCA cá»§a báº¥t ká»³ dá»‹ch vá»¥/thá»±c thá»ƒ phÃ¡p lÃ½ nÃ o, vui lÃ²ng yÃªu cáº§u tÃ¡c giáº£ plugin \"BÃªn thá»© ba\" hoáº·c ná»n táº£ng lÆ°u trá»¯, vÃ­ dá»¥: GitHub/Codeberg, thá»±c hiá»‡n hÃ nh Ä‘á»™ng. Táº¥t cáº£ cÃ¡c plugin Ä‘Æ°á»£c liá»‡t kÃª á»Ÿ trÃªn (Ä‘Æ°á»£c gáº¯n nhÃ£n \"BÃªn thá»© ba\") Ä‘á»u lÃ  cÃ¡c plugin cÃ´ng cá»™ng/do cá»™ng Ä‘á»“ng duy trÃ¬. ChÃºng tÃ´i khÃ´ng quáº£n lÃ½ chÃºng, vÃ¬ váº­y chÃºng tÃ´i khÃ´ng thá»ƒ thá»±c hiá»‡n báº¥t ká»³ hÃ nh Ä‘á»™ng nÃ o Ä‘á»‘i vá»›i chÃºng.\n\n';

  @override
  String get input_does_not_match_format =>
      'Äáº§u vÃ o khÃ´ng khá»›p vá»›i Ä‘á»‹nh dáº¡ng yÃªu cáº§u';

  @override
  String get plugins => 'Tiá»‡n Ã­ch bá»• sung';

  @override
  String get paste_plugin_download_url =>
      'DÃ¡n url táº£i xuá»‘ng hoáº·c url kho lÆ°u trá»¯ GitHub/Codeberg hoáº·c liÃªn káº¿t trá»±c tiáº¿p Ä‘áº¿n tá»‡p .smplug';

  @override
  String get download_and_install_plugin_from_url =>
      'Táº£i xuá»‘ng vÃ  cÃ i Ä‘áº·t plugin tá»« url';

  @override
  String failed_to_add_plugin_error(Object error) {
    return 'KhÃ´ng thá»ƒ thÃªm plugin: $error';
  }

  @override
  String get upload_plugin_from_file => 'Táº£i lÃªn plugin tá»« tá»‡p';

  @override
  String get installed => 'ÄÃ£ cÃ i Ä‘áº·t';

  @override
  String get available_plugins => 'CÃ¡c plugin cÃ³ sáºµn';

  @override
  String get configure_plugins =>
      'Cáº¥u hÃ¬nh nhÃ  cung cáº¥p siÃªu dá»¯ liá»‡u vÃ  tiá»‡n Ã­ch nguá»“n Ã¢m thanh riÃªng';

  @override
  String get source => 'Nguá»“n: ';

  @override
  String get uncompressed => 'KhÃ´ng nÃ©n';

  @override
  String get dab_music_source_description =>
      'DÃ nh cho ngÆ°á»i yÃªu Ã¢m nháº¡c cháº¥t lÆ°á»£ng cao. Cung cáº¥p luá»“ng Ã¢m thanh cháº¥t lÆ°á»£ng cao/khÃ´ng nÃ©n. PhÃ¹ há»£p bÃ i hÃ¡t dá»±a trÃªn ISRC chÃ­nh xÃ¡c.';

  @override
  String get summary_top_track => 'BÃ i hÃ¡t hÃ ng Ä‘áº§u\nká»³ nÃ y';

  @override
  String get local => 'Cá»¥c bá»™';

  @override
  String get set_as_ringtone => 'Set as ringtone';

  @override
  String get ringtone_set => 'Ringtone set';

  @override
  String get ringtone_failed => 'Could not set ringtone';

  @override
  String get specials => 'Specials';

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
