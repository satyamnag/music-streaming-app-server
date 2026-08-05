class ISOLanguageName {
  final String name;
  final String nativeName;

  const ISOLanguageName({
    required this.name,
    required this.nativeName,
  });

  @override
  String toString() {
    return "$name ($nativeName)";
  }
}

// Extended language name table for all languages selectable in the app.
abstract class LanguageLocals {
  static final Map isoLangs = {
    "en": const ISOLanguageName(
      name: "English",
      nativeName: "English",
    ),
    "zh_CN": const ISOLanguageName(
      name: "Mandarin",
      nativeName: "简体中文",
    ),
    "hi": const ISOLanguageName(
      name: "Hindi",
      nativeName: "हिन्दी",
    ),
    "es": const ISOLanguageName(
      name: "Spanish",
      nativeName: "Español",
    ),
    "ar": const ISOLanguageName(
      name: "Arabic",
      nativeName: "العربية",
    ),
    "fr": const ISOLanguageName(
      name: "French",
      nativeName: "Français",
    ),
    "bn": const ISOLanguageName(
      name: "Bengali",
      nativeName: "বাংলা",
    ),
    "pt": const ISOLanguageName(
      name: "Portuguese",
      nativeName: "Português",
    ),
    "ru": const ISOLanguageName(
      name: "Russian",
      nativeName: "Русский",
    ),
    "ur": const ISOLanguageName(
      name: "Urdu",
      nativeName: "اردو",
    ),
    "id": const ISOLanguageName(
      name: "Indonesian",
      nativeName: "Bahasa Indonesia",
    ),
    "de": const ISOLanguageName(
      name: "German",
      nativeName: "Deutsch",
    ),
    "ja": const ISOLanguageName(
      name: "Japanese",
      nativeName: "日本語",
    ),
    "pcm": const ISOLanguageName(
      name: "Nigerian Pidgin",
      nativeName: "Naijá",
    ),
    "mr": const ISOLanguageName(
      name: "Marathi",
      nativeName: "मराठी",
    ),
    "te": const ISOLanguageName(
      name: "Telugu",
      nativeName: "తెలుగు",
    ),
    "tr": const ISOLanguageName(
      name: "Turkish",
      nativeName: "Türkçe",
    ),
    "ta": const ISOLanguageName(
      name: "Tamil",
      nativeName: "தமிழ்",
    ),
    "yue": const ISOLanguageName(
      name: "Cantonese (Yue)",
      nativeName: "粵語（廣東話）",
    ),
    "vi": const ISOLanguageName(
      name: "Vietnamese",
      nativeName: "Tiếng Việt",
    ),
    "wuu": const ISOLanguageName(
      name: "Wu Chinese",
      nativeName: "吴语",
    ),
    "ko": const ISOLanguageName(
      name: "Korean",
      nativeName: "한국어",
    ),
    "ha": const ISOLanguageName(
      name: "Hausa",
      nativeName: "Hausa هَوُسَ",
    ),
    "fa": const ISOLanguageName(
      name: "Persian",
      nativeName: "فارسی",
    ),
    "th": const ISOLanguageName(
      name: "Thai",
      nativeName: "ไทย",
    ),
    "gu": const ISOLanguageName(
      name: "Gujarati",
      nativeName: "ગુજરાતી",
    ),
    "kn": const ISOLanguageName(
      name: "Kannada",
      nativeName: "ಕನ್ನಡ",
    ),
    "jv": const ISOLanguageName(
      name: "Javanese",
      nativeName: "Basa Jawa",
    ),
    "it": const ISOLanguageName(
      name: "Italian",
      nativeName: "Italiano",
    ),
    "pl": const ISOLanguageName(
      name: "Polish",
      nativeName: "Polski",
    ),
    "ml": const ISOLanguageName(
      name: "Malayalam",
      nativeName: "മലയാളം",
    ),
    "pa": const ISOLanguageName(
      name: "Punjabi",
      nativeName: "ਪੰਜਾਬੀ",
    ),
    "uk": const ISOLanguageName(
      name: "Ukrainian",
      nativeName: "Українська",
    ),
    "bho": const ISOLanguageName(
      name: "Bhojpuri",
      nativeName: "भोजपुरी",
    ),
    "ro": const ISOLanguageName(
      name: "Romanian",
      nativeName: "Română",
    ),
    "nl": const ISOLanguageName(
      name: "Dutch",
      nativeName: "Nederlands",
    ),
    "om": const ISOLanguageName(
      name: "Oromo",
      nativeName: "Afaan Oromoo",
    ),
    "az": const ISOLanguageName(
      name: "Azerbaijani",
      nativeName: "Azərbaycan dili",
    ),
    "mai": const ISOLanguageName(
      name: "Maithili",
      nativeName: "मैथिली",
    ),
    "my": const ISOLanguageName(
      name: "Burmese",
      nativeName: "ဗမာစာ",
    ),
    "yo": const ISOLanguageName(
      name: "Yoruba",
      nativeName: "Yorùbá",
    ),
    "sd": const ISOLanguageName(
      name: "Sindhi",
      nativeName: "سنڌي",
    ),
    "ig": const ISOLanguageName(
      name: "Igbo",
      nativeName: "Asụsụ Igbo",
    ),
    "uz": const ISOLanguageName(
      name: "Uzbek",
      nativeName: "Oʻzbekcha",
    ),
    "ne": const ISOLanguageName(
      name: "Nepali",
      nativeName: "नेपाली",
    ),
    "am": const ISOLanguageName(
      name: "Amharic",
      nativeName: "አማርኛ",
    ),
    "si": const ISOLanguageName(
      name: "Sinhala",
      nativeName: "සිංහල",
    ),
    "km": const ISOLanguageName(
      name: "Khmer",
      nativeName: "ខ្មែរ",
    ),
    "ps": const ISOLanguageName(
      name: "Pashto",
      nativeName: "پښتو",
    ),
    "zu": const ISOLanguageName(
      name: "Zulu",
      nativeName: "isiZulu",
    ),
    "cs": const ISOLanguageName(
      name: "Czech",
      nativeName: "Čeština",
    ),
    "el": const ISOLanguageName(
      name: "Greek",
      nativeName: "Ελληνικά",
    ),
    "hu": const ISOLanguageName(
      name: "Hungarian",
      nativeName: "Magyar",
    ),
    "sv": const ISOLanguageName(
      name: "Swedish",
      nativeName: "Svenska",
    ),
    "be": const ISOLanguageName(
      name: "Belarusian",
      nativeName: "Беларуская",
    ),
    "sr": const ISOLanguageName(
      name: "Serbian",
      nativeName: "Српски",
    ),
    "hr": const ISOLanguageName(
      name: "Croatian",
      nativeName: "Hrvatski",
    ),
    "bg": const ISOLanguageName(
      name: "Bulgarian",
      nativeName: "Български",
    ),
    "sk": const ISOLanguageName(
      name: "Slovak",
      nativeName: "Slovenčina",
    ),
    "da": const ISOLanguageName(
      name: "Danish",
      nativeName: "Dansk",
    ),
    "fi": const ISOLanguageName(
      name: "Finnish",
      nativeName: "Suomi",
    ),
    "no": const ISOLanguageName(
      name: "Norwegian",
      nativeName: "Norsk",
    ),
    "he": const ISOLanguageName(
      name: "Hebrew",
      nativeName: "עברית",
    ),
    "lt": const ISOLanguageName(
      name: "Lithuanian",
      nativeName: "Lietuvių",
    ),
    "lv": const ISOLanguageName(
      name: "Latvian",
      nativeName: "Latviešu",
    ),
    "et": const ISOLanguageName(
      name: "Estonian",
      nativeName: "Eesti",
    ),
    "ka": const ISOLanguageName(
      name: "Georgian",
      nativeName: "ქართული",
    ),
    "hy": const ISOLanguageName(
      name: "Armenian",
      nativeName: "Հայերեն",
    ),
    "kk": const ISOLanguageName(
      name: "Kazakh",
      nativeName: "Қазақша",
    ),
    "ky": const ISOLanguageName(
      name: "Kyrgyz",
      nativeName: "Кыргызча",
    ),
    "tk": const ISOLanguageName(
      name: "Turkmen",
      nativeName: "Türkmençe",
    ),
    "tg": const ISOLanguageName(
      name: "Tajik",
      nativeName: "Тоҷикӣ",
    ),
    "mn": const ISOLanguageName(
      name: "Mongolian",
      nativeName: "Монгол",
    ),
    "lo": const ISOLanguageName(
      name: "Lao",
      nativeName: "ລາວ",
    ),
    "ms": const ISOLanguageName(
      name: "Malay",
      nativeName: "Bahasa Melayu",
    ),
    "ceb": const ISOLanguageName(
      name: "Cebuano",
      nativeName: "Cebuano",
    ),
    "hil": const ISOLanguageName(
      name: "Hiligaynon",
      nativeName: "Hiligaynon",
    ),
    "ilo": const ISOLanguageName(
      name: "Ilocano",
      nativeName: "Ilokano",
    ),
    "mg": const ISOLanguageName(
      name: "Malagasy",
      nativeName: "Malagasy",
    ),
    "sn": const ISOLanguageName(
      name: "Shona",
      nativeName: "chiShona",
    ),
    "so": const ISOLanguageName(
      name: "Somali",
      nativeName: "Soomaali",
    ),
    "rw": const ISOLanguageName(
      name: "Kinyarwanda",
      nativeName: "Ikinyarwanda",
    ),
    "rn": const ISOLanguageName(
      name: "Kirundi",
      nativeName: "Ikirundi",
    ),
    "xh": const ISOLanguageName(
      name: "Xhosa",
      nativeName: "isiXhosa",
    ),
    "af": const ISOLanguageName(
      name: "Afrikaans",
      nativeName: "Afrikaans",
    ),
    "sw": const ISOLanguageName(
      name: "Swahili",
      nativeName: "Kiswahili",
    ),
    "ff": const ISOLanguageName(
      name: "Fula",
      nativeName: "Fulfulde",
    ),
    "wo": const ISOLanguageName(
      name: "Wolof",
      nativeName: "Wolof",
    ),
    "ln": const ISOLanguageName(
      name: "Lingala",
      nativeName: "Lingála",
    ),
    "ny": const ISOLanguageName(
      name: "Chichewa",
      nativeName: "Chichewa",
    ),
    "ti": const ISOLanguageName(
      name: "Tigrinya",
      nativeName: "ትግርኛ",
    ),
    "qu": const ISOLanguageName(
      name: "Quechua",
      nativeName: "Runasimi",
    ),
    "gn": const ISOLanguageName(
      name: "Guaraní",
      nativeName: "Avañe'ẽ",
    ),
    "ht": const ISOLanguageName(
      name: "Haitian Creole",
      nativeName: "Kreyòl ayisyen",
    ),
    "ca": const ISOLanguageName(
      name: "Catalan",
      nativeName: "Català",
    ),
    "eu": const ISOLanguageName(
      name: "Basque",
      nativeName: "Euskara",
    ),
    "gl": const ISOLanguageName(
      name: "Galician",
      nativeName: "Galego",
    ),
    "ga": const ISOLanguageName(
      name: "Irish",
      nativeName: "Gaeilge",
    ),
    "cy": const ISOLanguageName(
      name: "Welsh",
      nativeName: "Cymraeg",
    ),
    "is": const ISOLanguageName(
      name: "Icelandic",
      nativeName: "Íslenska",
    ),
    "lb": const ISOLanguageName(
      name: "Luxembourgish",
      nativeName: "Lëtzebuergesch",
    ),
    "zh_TW": const ISOLanguageName(
      name: "Traditional Chinese",
      nativeName: "繁體中文（台灣）",
    ),
    "tl": const ISOLanguageName(
      name: "Tagalog",
      nativeName: "Wikang Tagalog",
    ),
  };

  static ISOLanguageName getDisplayLanguage(String key, String? countryCode) {
    if (isoLangs.containsKey(key)) {
      return isoLangs[key]!;
    } else if (countryCode != null &&
        countryCode.isNotEmpty &&
        isoLangs.containsKey("${key}_$countryCode")) {
      return isoLangs["${key}_$countryCode"]!;
    } else {
      throw Exception("Language key incorrect");
    }
  }
}
