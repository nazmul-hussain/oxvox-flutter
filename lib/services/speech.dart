import 'package:flutter_tts/flutter_tts.dart';

/// Web utils/speak.js: read text aloud (en-GB) for grammar narration and quiz sentences.
class Speech {
  Speech._();
  static final FlutterTts _tts = FlutterTts();
  static bool _ready = false;

  static Future<void> _setup() async {
    if (_ready) return;
    await _tts.setLanguage('en-GB');
    await _tts.setSpeechRate(0.5);
    await _tts.awaitSpeakCompletion(false);
    _ready = true;
  }

  /// Speak [text]; [onEnd] runs when speech finishes or fails.
  static Future<void> speak(String text, {void Function()? onEnd}) async {
    await _setup();
    _tts.setCompletionHandler(() => onEnd?.call());
    _tts.setErrorHandler((_) => onEnd?.call());
    await _tts.stop();
    await _tts.speak(text);
  }

  static Future<void> stop() => _tts.stop();

  static Map<String, String>? _maleVoice;
  static bool _maleLooked = false;

  /// Known male English voice names across iOS / macOS / Android.
  static const _maleNames = [
    'daniel', 'arthur', 'oliver', 'thomas', 'alex', 'fred', 'tom', 'aaron',
    'gordon', 'rishi', 'ralph', 'evan', 'reed', 'lee', 'george', 'james',
    'male', 'en-gb-x-rjs', 'en-gb-x-gbd', 'en-us-x-iom', 'en-us-x-iob',
  ];

  static Future<void> _pickMaleVoice() async {
    if (_maleLooked) return;
    _maleLooked = true;
    try {
      final voices = await _tts.getVoices as List? ?? [];
      Map<String, String>? best;
      var bestScore = -1;
      for (final v in voices) {
        final m = Map<String, dynamic>.from(v as Map);
        final name = (m['name'] ?? '').toString();
        final locale = (m['locale'] ?? '').toString();
        if (!locale.toLowerCase().startsWith('en')) continue;
        final lower = name.toLowerCase();
        final idx = _maleNames.indexWhere((n) => lower.contains(n));
        if (idx < 0) continue;
        // Prefer en-GB (matches the app's British accent), then earlier names in the list.
        final score = (locale.toLowerCase() == 'en-gb' ? 1000 : 0) +
            (100 - idx);
        if (score > bestScore) {
          bestScore = score;
          best = {'name': name, 'locale': locale};
        }
      }
      _maleVoice = best;
    } catch (_) {
      _maleVoice = null;
    }
  }

  /// Speak [text] with a male voice when one is installed (falls back to the default en-GB voice).
  static Future<void> speakMale(String text, {void Function()? onEnd}) async {
    await _setup();
    await _pickMaleVoice();
    if (_maleVoice != null) {
      await _tts.setVoice(_maleVoice!);
    }
    _tts.setCompletionHandler(() => onEnd?.call());
    _tts.setErrorHandler((_) => onEnd?.call());
    await _tts.stop();
    await _tts.speak(text);
  }
}
