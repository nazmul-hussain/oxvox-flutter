import 'dart:ui' show PlatformDispatcher;

/// A language the learner can pick for word meanings.
class MeaningLang {
  final String code; // ISO 639-1 / 639-2 code, also the translation file name
  final String name; // English name
  final String native; // name in the language itself
  final bool rtl;
  const MeaningLang(this.code, this.name, this.native, {this.rtl = false});
}

/// Languages that can show word meanings. Bangla is the bundled default (word.meaning);
/// Arabic comes from assets/data/arabic.json; the rest load from translation files.
const meaningLangs = <MeaningLang>[
  MeaningLang('bn', 'Bangla', 'বাংলা'),
  MeaningLang('ar', 'Arabic', 'العربية', rtl: true),
  MeaningLang('hi', 'Hindi', 'हिन्दी'),
  MeaningLang('ur', 'Urdu', 'اردو', rtl: true),
  MeaningLang('fa', 'Persian', 'فارسی', rtl: true),
  MeaningLang('he', 'Hebrew', 'עברית', rtl: true),
  MeaningLang('ne', 'Nepali', 'नेपाली'),
  MeaningLang('si', 'Sinhala', 'සිංහල'),
  MeaningLang('ta', 'Tamil', 'தமிழ்'),
  MeaningLang('te', 'Telugu', 'తెలుగు'),
  MeaningLang('zh', 'Chinese', '中文'),
  MeaningLang('ja', 'Japanese', '日本語'),
  MeaningLang('ko', 'Korean', '한국어'),
  MeaningLang('th', 'Thai', 'ไทย'),
  MeaningLang('vi', 'Vietnamese', 'Tiếng Việt'),
  MeaningLang('id', 'Indonesian', 'Bahasa Indonesia'),
  MeaningLang('ms', 'Malay', 'Bahasa Melayu'),
  MeaningLang('fil', 'Filipino', 'Filipino'),
  MeaningLang('es', 'Spanish', 'Español'),
  MeaningLang('pt', 'Portuguese', 'Português'),
  MeaningLang('fr', 'French', 'Français'),
  MeaningLang('de', 'German', 'Deutsch'),
  MeaningLang('it', 'Italian', 'Italiano'),
  MeaningLang('ru', 'Russian', 'Русский'),
  MeaningLang('uk', 'Ukrainian', 'Українська'),
  MeaningLang('pl', 'Polish', 'Polski'),
  MeaningLang('tr', 'Turkish', 'Türkçe'),
  MeaningLang('sw', 'Swahili', 'Kiswahili'),
  MeaningLang('am', 'Amharic', 'አማርኛ'),
  MeaningLang('ha', 'Hausa', 'Hausa'),
];

/// Stored value for "no secondary language".
const secondaryNone = 'none';

/// Secondary language when the learner has not chosen one.
const defaultSecondaryLang = 'ar';

/// Primary meaning language when the device language is not in [meaningLangs].
const fallbackPrimaryLang = 'bn';

MeaningLang? langByCode(String? code) {
  if (code == null) return null;
  for (final l in meaningLangs) {
    if (l.code == code) return l;
  }
  return null;
}

/// Device language if we have meanings for it, else the bundled Bangla.
String deviceDefaultPrimaryLang() {
  final code = PlatformDispatcher.instance.locale.languageCode;
  if (langByCode(code) != null) return code;
  return fallbackPrimaryLang;
}

/// The meanings shown for one word: the main line and the optional secondary line.
class WordMeanings {
  final String primary;
  final bool primaryRtl;
  final String? secondary;
  final bool secondaryRtl;

  /// Language code of the secondary line (for reading it aloud).
  final String? secondaryLang;
  const WordMeanings({
    required this.primary,
    required this.primaryRtl,
    this.secondary,
    this.secondaryRtl = false,
    this.secondaryLang,
  });
}
