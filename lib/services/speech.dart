import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    await _backToEnglish();
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
    'daniel',
    'arthur',
    'oliver',
    'thomas',
    'alex',
    'fred',
    'tom',
    'aaron',
    'gordon',
    'rishi',
    'ralph',
    'evan',
    'reed',
    'lee',
    'george',
    'james',
    'male',
    'en-gb-x-rjs',
    'en-gb-x-gbd',
    'en-us-x-iom',
    'en-us-x-iob',
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
        final score =
            (locale.toLowerCase() == 'en-gb' ? 1000 : 0) + (100 - idx);
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
    } else {
      await _backToEnglish();
    }
    _otherLang = false;
    _tts.setCompletionHandler(() => onEnd?.call());
    _tts.setErrorHandler((_) => onEnd?.call());
    await _tts.stop();
    await _tts.speak(text);
  }

  /// True after speaking another language, so English is set again before the next English line.
  static bool _otherLang = false;

  static Future<void> _backToEnglish() async {
    if (!_otherLang) return;
    _otherLang = false;
    if (_maleVoice != null) {
      await _tts.setVoice(_maleVoice!);
    } else {
      await _tts.setLanguage('en-GB');
    }
  }

  /// Name parts of known male voices in other languages (Google, Samsung, Apple).
  static const _maleHints = [
    'male',
    'hamed',
    'maged',
    'tarik',
    'majed',
    'rishi',
    'aaron',
    'thomas',
    'jorge',
    'diego',
    'yuri',
    'luca',
    'yannick',
    'daniel',
    'markus',
    'otoya',
    'hattori',
  ];

  static final Map<String, Map<String, String>?> _langVoice = {};

  /// Best voice for [tag]: an offline male voice first, then any male voice,
  /// then any offline voice. Null leaves the engine's default for the language.
  static Future<Map<String, String>?> _voiceFor(String tag) async {
    if (_langVoice.containsKey(tag)) return _langVoice[tag];
    Map<String, String>? best;
    try {
      final chosen = await chosenVoice(tag);
      if (chosen != null) {
        for (final v in await voicesFor(tag)) {
          if (v['name'] == chosen) return _langVoice[tag] = v;
        }
      }
      final base = tag.split('-').first.toLowerCase();
      final voices = await _tts.getVoices as List? ?? [];
      var bestScore = -1;
      for (final v in voices) {
        final m = Map<String, dynamic>.from(v as Map);
        final name = (m['name'] ?? '').toString();
        final locale = (m['locale'] ?? '').toString().toLowerCase();
        if (locale.replaceAll('_', '-').split('-').first != base) continue;
        // Android lists voices that are not downloaded yet; skip them.
        if ((m['features'] ?? '').toString().contains('notInstalled')) {
          continue;
        }
        final lower = name.toLowerCase();
        final gender = (m['gender'] ?? '').toString().toLowerCase();
        final male =
            gender == 'male' ||
            (!lower.contains('female') && _maleHints.any(lower.contains));
        final local =
            !lower.contains('network') && m['network_required'] != '1';
        final exact = locale.replaceAll('_', '-') == tag.toLowerCase();
        final score = (male ? 100 : 0) + (local ? 10 : 0) + (exact ? 1 : 0);
        if (score > bestScore) {
          bestScore = score;
          best = {'name': name, 'locale': m['locale'].toString()};
        }
      }
    } catch (_) {}
    return _langVoice[tag] = best;
  }

  /// Whether the phone can speak [tag] (e.g. "ar-SA"): ready, needs a voice
  /// download, or not supported by the speech engine at all.
  /// Matches on the language only, because engines use their own regions
  /// (Google lists Arabic as "ar-XA", not "ar-SA").
  static Future<TtsLangStatus> langStatus(String tag) async {
    await _setup();
    try {
      _langVoice.remove(tag); // re-check: a voice may have just been installed
      if (await _voiceFor(tag) != null) return TtsLangStatus.ready;
      final base = tag.split('-').first;
      final available =
          await _tts.isLanguageAvailable(tag) == true ||
          await _tts.isLanguageAvailable(base) == true;
      if (!Platform.isAndroid) {
        return available ? TtsLangStatus.ready : TtsLangStatus.missing;
      }
      return available ? TtsLangStatus.notDownloaded : TtsLangStatus.missing;
    } catch (_) {
      return TtsLangStatus.ready;
    }
  }

  /// Speak [text] in language [tag] with a male voice when the phone has one.
  static Future<void> speakLang(
    String text,
    String tag, {
    void Function()? onEnd,
  }) async {
    await _setup();
    await _tts.stop();
    _otherLang = true;
    final voice = await _voiceFor(tag);
    // Use the voice's own locale (e.g. "ar-XA"); the engine may reject "ar-SA".
    await _tts.setLanguage(voice?['locale'] ?? tag);
    if (voice != null) await _tts.setVoice(voice);
    _tts.setCompletionHandler(() => onEnd?.call());
    _tts.setErrorHandler((_) => onEnd?.call());
    await _tts.speak(text);
  }

  static String _prefKey(String tag) =>
      'meaningVoice_${tag.split('-').first.toLowerCase()}';

  /// Voice name the learner picked for this language in Settings, if any.
  static Future<String?> chosenVoice(String tag) async =>
      (await SharedPreferences.getInstance()).getString(_prefKey(tag));

  static Future<void> setChosenVoice(String tag, String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (name == null) {
      await prefs.remove(_prefKey(tag));
    } else {
      await prefs.setString(_prefKey(tag), name);
    }
    _langVoice.remove(tag);
  }

  /// Downloaded voices for [tag]'s language, sorted by name.
  static Future<List<Map<String, String>>> voicesFor(String tag) async {
    await _setup();
    final base = tag.split('-').first.toLowerCase();
    final out = <Map<String, String>>[];
    try {
      final voices = await _tts.getVoices as List? ?? [];
      for (final v in voices) {
        final m = Map<String, dynamic>.from(v as Map);
        final locale = (m['locale'] ?? '').toString();
        if (locale.toLowerCase().replaceAll('_', '-').split('-').first !=
            base) {
          continue;
        }
        if ((m['features'] ?? '').toString().contains('notInstalled')) {
          continue;
        }
        out.add({'name': (m['name'] ?? '').toString(), 'locale': locale});
      }
    } catch (_) {}
    out.sort((a, b) => a['name']!.compareTo(b['name']!));
    return out;
  }

  /// Speak [text] with one exact [voice] (used to preview voices in Settings).
  static Future<void> speakWithVoice(
    String text,
    Map<String, String> voice,
  ) async {
    await _setup();
    await _tts.stop();
    _otherLang = true;
    await _tts.setLanguage(voice['locale']!);
    await _tts.setVoice(voice);
    _tts.setCompletionHandler(() {});
    _tts.setErrorHandler((_) {});
    await _tts.speak(text);
  }
}

enum TtsLangStatus { ready, notDownloaded, missing }
