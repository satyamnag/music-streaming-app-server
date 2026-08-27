import 'package:lrc/lrc.dart';

/// Language labels for the multi-language synced lyrics. These map 1:1 to the
/// `synced_lyrics_*` columns of the Supabase `tracks` table:
///  - [languageTe]     -> Telugu (main, `synced_lyrics`)
///  - [languageEn]     -> English (Translation, `synced_lyrics_en`)
///  - [languageHi]     -> Hindi (Translation, `synced_lyrics_hi`)
///  - [languageEnTr]   -> English (Transliteration, `synced_lyrics_en_tr`)
///  - [languageHiTr]   -> Hindi (Transliteration, `synced_lyrics_hi_tr`)
abstract final class LyricLanguages {
  static const te = 'telugu';
  static const en = 'en_translation';
  static const hi = 'hi_translation';
  static const enTr = 'en_transliteration';
  static const hiTr = 'hi_transliteration';

  /// Display order used by the Synced & Plain lyrics screens.
  static const order = [te, en, hi, enTr, hiTr];

  /// Reads a field value from [entry] by its [language] key.
  static String fieldOf(LyricVariant entry, String language) {
    return switch (language) {
      te => entry.te,
      en => entry.en,
      hi => entry.hi,
      enTr => entry.enTr,
      hiTr => entry.hiTr,
      _ => '',
    };
  }
}

/// A single synchronized line rendered in up to five languages. The admin
/// portal keeps every line's timestamp aligned across the language columns, so
/// a [LyricVariant] holds all available texts for one timestamp.
class LyricVariant {
  Duration time;
  String te;
  String en;
  String hi;
  String enTr;
  String hiTr;

  LyricVariant({
    required this.time,
    this.te = '',
    this.en = '',
    this.hi = '',
    this.enTr = '',
    this.hiTr = '',
  });

  factory LyricVariant.fromJson(Map<String, dynamic> json) {
    return LyricVariant(
      time: Duration(milliseconds: json["time"]),
      te: json["te"] as String? ?? '',
      en: json["en"] as String? ?? '',
      hi: json["hi"] as String? ?? '',
      enTr: json["enTr"] as String? ?? '',
      hiTr: json["hiTr"] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "time": time.inMilliseconds,
      "te": te,
      "en": en,
      "hi": hi,
      "enTr": enTr,
      "hiTr": hiTr,
    };
  }
}

class SubtitleSimple {
  Uri uri;
  String name;
  List<LyricSlice> lyrics;
  int rating;
  String provider;

  /// Optional aligned multi-language rendering, one entry per timestamp in
  /// the same order as [lyrics]. When null the caller falls back to showing
  /// the single-language [lyrics] (existing behaviour). Added for backward
  /// compatibility — older cached lyrics simply have no variants.
  List<LyricVariant>? variants;

  SubtitleSimple({
    required this.uri,
    required this.name,
    required this.lyrics,
    required this.rating,
    required this.provider,
    this.variants,
  });

  factory SubtitleSimple.fromJson(Map<String, dynamic> json) {
    return SubtitleSimple(
      uri: Uri.parse(json["uri"] as String),
      name: json["name"] as String,
      lyrics: (json["lyrics"] as List<dynamic>)
          .map((e) => LyricSlice.fromJson(e as Map<String, dynamic>))
          .toList(),
      rating: json["rating"] as int,
      provider: json["provider"] as String? ?? "unknown",
      variants: (json["variants"] as List<dynamic>?)
          ?.map((e) => LyricVariant.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "uri": uri.toString(),
      "name": name,
      "lyrics": lyrics.map((e) => e.toJson()).toList(),
      "rating": rating,
      "provider": provider,
      if (variants != null)
        "variants": variants!.map((e) => e.toJson()).toList(),
    };
  }
}

class LyricSlice {
  Duration time;
  String text;

  LyricSlice({required this.time, required this.text});

  factory LyricSlice.fromLrcLine(LrcLine line) {
    return LyricSlice(
      time: line.timestamp,
      text: line.lyrics.trim(),
    );
  }

  factory LyricSlice.fromJson(Map<String, dynamic> json) {
    return LyricSlice(
      time: Duration(milliseconds: json["time"]),
      text: json["text"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "time": time.inMilliseconds,
      "text": text,
    };
  }

  @override
  String toString() {
    return "LyricsSlice({time: $time, text: $text})";
  }
}
