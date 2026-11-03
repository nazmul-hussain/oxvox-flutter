import 'speech.dart';

/// Plays a word's pronunciation in a male voice (device TTS), so every word sounds the same.
class Pronunciation {
  Pronunciation._();

  /// Speak [word]. Calls [onEnd] when speech finishes or fails.
  static Future<void> speak(String word, {void Function()? onEnd}) =>
      Speech.speakMale(word, onEnd: onEnd);

  static Future<void> stop() => Speech.stop();
}
