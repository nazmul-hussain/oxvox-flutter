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
}
