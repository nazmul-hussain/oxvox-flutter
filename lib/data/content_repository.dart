import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/config.dart';
import '../models/word.dart';

/// Loads content in this order:
///  1. Cached copy downloaded from the CDN (if newer than bundled)
///  2. Bundled asset (always works offline)
/// `refreshFromCdn()` checks the manifest and downloads a newer version in the background.
class ContentRepository {
  static const _bundledVersion = 1;

  Future<Directory> _dir() async {
    final d = Directory('${(await getApplicationSupportDirectory()).path}/content');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<({int version, List<Word> words, List<ListeningLesson> lessons})> load() async {
    final dir = await _dir();
    final versionFile = File('${dir.path}/version.txt');
    final cachedVersion =
        await versionFile.exists() ? int.tryParse(await versionFile.readAsString()) ?? 0 : 0;

    if (cachedVersion > _bundledVersion) {
      try {
        final words = await File('${dir.path}/words.json').readAsString();
        final lessons = await File('${dir.path}/lessons.json').readAsString();
        return (
          version: cachedVersion,
          words: _parseWords(words),
          lessons: _parseLessons(lessons),
        );
      } catch (_) {
        // Cache corrupted: fall through to bundled data.
      }
    }

    final words = await rootBundle.loadString('assets/data/words.json');
    final lessons = await rootBundle.loadString('assets/data/listening_lessons.json');
    return (
      version: _bundledVersion,
      words: _parseWords(words),
      lessons: _parseLessons(lessons),
    );
  }

  /// Returns true if new content was downloaded. Never throws (offline is fine).
  Future<bool> refreshFromCdn() async {
    try {
      final dir = await _dir();
      final manifest = jsonDecode(await _get(AppConfig.manifestPath)) as Map<String, dynamic>;
      final remoteVersion = manifest['contentVersion'] as int;
      final versionFile = File('${dir.path}/version.txt');
      final cached = await versionFile.exists()
          ? int.tryParse(await versionFile.readAsString()) ?? 0
          : 0;
      final current = cached > _bundledVersion ? cached : _bundledVersion;
      if (remoteVersion <= current) return false;

      final files = manifest['files'] as Map<String, dynamic>;
      final words = await _get(files['words'] as String);
      final lessons = await _get(files['listeningLessons'] as String);
      // Validate before saving so a bad download can never break the app.
      _parseWords(words);
      _parseLessons(lessons);

      await File('${dir.path}/words.json').writeAsString(words);
      await File('${dir.path}/lessons.json').writeAsString(lessons);
      await versionFile.writeAsString('$remoteVersion');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> _get(String path) async {
    final res = await http
        .get(Uri.parse('${AppConfig.contentBase}$path'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}', uri: Uri.parse(path));
    return utf8.decode(res.bodyBytes);
  }

  // Parsing runs in an isolate-friendly way: compute() is used by the caller if needed.
  static List<Word> _parseWords(String raw) =>
      (jsonDecode(raw) as List).map((e) => Word.fromJson(e as Map<String, dynamic>)).toList();

  static List<ListeningLesson> _parseLessons(String raw) => (jsonDecode(raw) as List)
      .map((e) => ListeningLesson.fromJson(e as Map<String, dynamic>))
      .toList();
}
