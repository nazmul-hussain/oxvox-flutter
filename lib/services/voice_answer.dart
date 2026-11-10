import 'dart:async';

import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Listens once and returns what the learner said, for voice answers in quizzes.
class VoiceAnswer {
  VoiceAnswer._();
  static final SpeechToText _stt = SpeechToText();
  static bool? _available;
  static List<LocaleName>? _locales;

  /// Asks for the mic permission on first use. False when the device has no recognizer
  /// or the learner refused the permission.
  static Future<bool> init() async {
    if (_available == true) return true;
    try {
      _available = await _stt.initialize();
    } catch (_) {
      _available = false;
    }
    return _available!;
  }

  /// Default region for each meaning language, used when the phone does not list
  /// the language itself (Google's recognizer still accepts it, often online).
  /// Speech language tag (e.g. bn-BD) for a meaning-language code.
  static String tagFor(String lang) =>
      _defaultRegion[lang.toLowerCase()] ?? lang.toLowerCase();

  static const _defaultRegion = {
    'en': 'en-GB',
    'bn': 'bn-BD',
    'ar': 'ar-SA',
    'hi': 'hi-IN',
    'ur': 'ur-PK',
    'fa': 'fa-IR',
    'he': 'he-IL',
    'ne': 'ne-NP',
    'si': 'si-LK',
    'ta': 'ta-IN',
    'te': 'te-IN',
    'zh': 'zh-CN',
    'ja': 'ja-JP',
    'ko': 'ko-KR',
    'th': 'th-TH',
    'vi': 'vi-VN',
    'id': 'id-ID',
    'ms': 'ms-MY',
    'fil': 'fil-PH',
    'es': 'es-ES',
    'pt': 'pt-BR',
    'fr': 'fr-FR',
    'de': 'de-DE',
    'it': 'it-IT',
    'ru': 'ru-RU',
    'uk': 'uk-UA',
    'pl': 'pl-PL',
    'tr': 'tr-TR',
    'sw': 'sw-KE',
    'am': 'am-ET',
    'ha': 'ha-NG',
  };

  /// Recognizer locale for an ISO language code. Uses the phone's own entry when it
  /// lists one; otherwise the default region, so the phone's language is never used
  /// by mistake (that was why Bangla answers were heard as English).
  static Future<String> _localeFor(String lang) async {
    final want = lang.toLowerCase();
    final fallback = _defaultRegion[want] ?? want;
    try {
      _locales ??= await _stt.locales();
    } catch (_) {
      _locales = const [];
    }
    final pref = fallback.replaceAll('-', '_').toLowerCase();
    String? hit;
    for (final l in _locales!) {
      final id = l.localeId.replaceAll('-', '_').toLowerCase();
      if (id == pref) return l.localeId;
      if (id == want || id.startsWith('${want}_')) hit ??= l.localeId;
    }
    return hit ?? fallback;
  }

  /// One listening session in [lang]. Every result, partial or final, goes to
  /// [match]; the session ends as soon as it returns an option. Ends on its own
  /// when the recognizer stops (Android stops after a short silence).
  /// Returns the matched option (or null) and the last words heard.
  static Future<({String? option, String heard})> listen(
    String lang, {
    required String? Function(List<String> guesses) match,
    void Function(String text)? onPartial,
    void Function(double level)? onLevel,
  }) async {
    if (!await init()) return (option: null, heard: '');
    final localeId = await _localeFor(lang);
    assert(() {
      // Debug-only: shows which locale was requested and what the phone offers.
      // ignore: avoid_print
      print(
        'VOICE lang=$lang localeId=$localeId phone-has='
        '${(_locales ?? const []).map((l) => l.localeId).where((i) => i.toLowerCase().startsWith(lang.toLowerCase())).toList()} '
        'total=${_locales?.length}',
      );
      return true;
    }());
    // Always cancel: Android can still be tearing down the last session even when
    // isListening is false, and starting over it fails or hangs.
    await _cancelQuietly();
    await Future.delayed(const Duration(milliseconds: 150));
    final done = Completer<({String? option, String heard})>();
    var last = '';
    void finish(String? option) {
      if (!done.isCompleted) done.complete((option: option, heard: last));
    }

    _stt.statusListener = (status) {
      if (status == SpeechToText.doneStatus) {
        // The final result can land just after "done"; wait briefly for it.
        Future.delayed(const Duration(milliseconds: 700), () => finish(null));
      }
    };
    _stt.errorListener = (_) => finish(null);
    try {
      await _stt.listen(
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 10),
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.confirmation,
        ),
        // Android reports roughly -2 (quiet) to 10 (loud) dB; scale to 0..1.
        onSoundLevelChange: onLevel == null
            ? null
            : (db) => onLevel(((db + 2) / 12).clamp(0.0, 1.0)),
        onResult: (SpeechRecognitionResult r) {
          if (done.isCompleted) return;
          final guesses = [
            r.recognizedWords,
            for (final a in r.alternates) a.recognizedWords,
          ].where((g) => g.trim().isNotEmpty).toList();
          if (guesses.isEmpty) return;
          last = guesses.first;
          onPartial?.call(last);
          final option = match(guesses);
          if (option != null) {
            _cancelQuietly();
            finish(option);
          } else if (r.finalResult) {
            finish(null);
          }
        },
      );
    } catch (_) {
      // e.g. ListenFailedException when the engine is still busy; caller retries.
      finish(null);
    }
    // Safety net: never hang if the recognizer goes silent without a status.
    return done.future.timeout(
      const Duration(seconds: 65),
      onTimeout: () {
        _cancelQuietly();
        return (option: null, heard: last);
      },
    );
  }

  static Future<void> _cancelQuietly() async {
    try {
      await _stt.cancel();
    } catch (_) {}
  }

  static Future<void> stop() => _cancelQuietly();
}

/// What the phone's speech recognizer can do with a language.
enum SpeechLangStatus {
  /// Downloaded on the phone: works offline.
  ready,

  /// Download already in progress.
  downloading,

  /// Can be downloaded for offline use (not yet).
  downloadable,

  /// Works only with internet; no offline download offered.
  onlineOnly,

  /// The phone's speech service does not support it.
  missing,

  /// The phone cannot tell (Android 12 or older).
  unknown,
}

/// Android 13+ checks and downloads for speech languages (MainActivity.kt).
class SpeechLangs {
  SpeechLangs._();
  static const _ch = MethodChannel('oxvox/speech_langs');

  static bool _has(List<dynamic>? list, String tag) {
    if (list == null) return false;
    final want = tag.toLowerCase().replaceAll('_', '-');
    final base = want.split('-').first;
    for (final t in list) {
      final have = t.toString().toLowerCase().replaceAll('_', '-');
      if (have == want || have == base || have.split('-').first == base) {
        return true;
      }
    }
    return false;
  }

  static Future<SpeechLangStatus> status(String langCode) async {
    final tag = VoiceAnswer.tagFor(langCode);
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>('support', {
        'lang': tag,
      });
      if (r == null) return SpeechLangStatus.unknown;
      if (_has(r['installed'], tag)) return SpeechLangStatus.ready;
      if (_has(r['pending'], tag)) return SpeechLangStatus.downloading;
      if (_has(r['supported'], tag)) return SpeechLangStatus.downloadable;
      if (_has(r['online'], tag)) return SpeechLangStatus.onlineOnly;
      return SpeechLangStatus.missing;
    } catch (_) {
      return SpeechLangStatus.unknown;
    }
  }

  /// Starts the download; the phone shows its own prompt and progress.
  static Future<bool> download(String langCode) async {
    try {
      return await _ch.invokeMethod<bool>('download', {
            'lang': VoiceAnswer.tagFor(langCode),
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// True while the phone rings or a phone/WhatsApp-style call is active.
  static Future<bool> inCall() async {
    try {
      return await _ch.invokeMethod<bool>('inCall') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the phone's text-to-speech voice download screen.
  static Future<void> installTtsVoice() async {
    try {
      await _ch.invokeMethod('installTts');
    } catch (_) {}
  }

  static Future<void> openSettings() async {
    try {
      await _ch.invokeMethod('openSettings');
    } catch (_) {}
  }
}

const _ordinals = <List<String>>[
  ['1', 'one', 'first', 'a', 'option one', 'option a', 'number one'],
  [
    '2',
    'two',
    'second',
    'b',
    'option two',
    'option b',
    'number two',
    'to',
    'too',
  ],
  [
    '3',
    'three',
    'third',
    'c',
    'option three',
    'option c',
    'number three',
    'see',
    'sea',
  ],
  ['4', 'four', 'fourth', 'd', 'option four', 'option d', 'number four', 'for'],
];

String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}\s]', unicode: true), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

int _distance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = [
        prev[j] + 1,
        cur[j - 1] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}

/// Picks the option the learner said, or null when nothing is a confident match.
/// Accepts the option text itself, or its position ("two", "option B", "second").
String? matchSpokenOption(List<String> heard, List<String> options) {
  // An option can hold several meanings ("ত্যাগ করা, পরিত্যাগ"); any one counts.
  final parts = <(int, String)>[];
  for (var i = 0; i < options.length; i++) {
    parts.add((i, _norm(options[i])));
    for (final piece in options[i].split(RegExp(r'[,;/|،؛]'))) {
      final n = _norm(piece);
      if (n.isNotEmpty && n != parts.last.$2) parts.add((i, n));
    }
  }
  final hit = _matchParts(heard, parts);
  if (hit != null) return options[hit];
  // Position words.
  for (final raw in heard) {
    final h = _norm(raw);
    for (var i = 0; i < options.length && i < _ordinals.length; i++) {
      if (_ordinals[i].contains(h)) return options[i];
    }
  }
  return _closest(heard, parts, options);
}

int? _matchParts(List<String> heard, List<(int, String)> parts) {
  for (final raw in heard) {
    final h = _norm(raw);
    if (h.isEmpty) continue;
    for (final (i, o) in parts) {
      if (h == o) return i;
    }
    for (final (i, o) in parts) {
      if (o.isNotEmpty &&
          RegExp('(^| )${RegExp.escape(o)}( |\$)').hasMatch(h)) {
        return i;
      }
    }
  }
  return null;
}

/// Closest by spelling, only when clearly better than the next different option.
String? _closest(
  List<String> heard,
  List<(int, String)> parts,
  List<String> options,
) {
  for (final raw in heard) {
    final h = _norm(raw);
    if (h.isEmpty) continue;
    final best = <int, double>{};
    for (final (i, o) in parts) {
      final d = _distance(h, o) / (o.length.clamp(1, 999));
      if (d < (best[i] ?? 99)) best[i] = d;
    }
    final ranked = best.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final next = ranked.length > 1 ? ranked[1].value : 1.0;
    if (ranked.first.value <= 0.34 && next - ranked.first.value >= 0.2) {
      return options[ranked.first.key];
    }
  }
  return null;
}
