import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/config.dart';
import '../models/word.dart';

/// Everything the app reads from content. Built from the web app's own plan export,
/// so days and word order match the web exactly.
class ContentBundle {
  final Map<int, List<Word>> days; // day -> words (web dailyData)
  final List<Word> allWords;
  final Map<String, String> arabic; // lowercase headword -> Arabic meaning
  final Map<String, String> exampleBn; // English sentence -> Bangla
  final List<ListeningLesson> lessons;
  final int version;

  const ContentBundle({
    required this.days,
    required this.allWords,
    required this.arabic,
    required this.exampleBn,
    required this.lessons,
    required this.version,
  });

  int get totalDays => days.length;

  /// Full audio URL for a lesson (web: /listening/lNNN.mp3 on the content host).
  String audioUrl(ListeningLesson l) =>
      '${AppConfig.contentBase}${l.audio.replaceFirst(RegExp(r'^/'), '')}';
}

/// Loads content in this order:
///  1. Cached copy downloaded from the CDN, if it is at least as new as the bundled copy.
///  2. Bundled asset copy (always works offline).
/// `refreshFromCdn()` checks the manifest and downloads a newer version.
class ContentRepository {
  /// Version of the content bundled in assets/data (matches oxvox-cdn manifest contentVersion).
  static const bundledVersion = 3;

  Future<Directory> _dir() async {
    final d = Directory(
      '${(await getApplicationSupportDirectory()).path}/content',
    );
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<int> _cachedVersion(Directory dir) async {
    final f = File('${dir.path}/version.txt');
    return await f.exists()
        ? int.tryParse((await f.readAsString()).trim()) ?? 0
        : 0;
  }

  Future<ContentBundle> load() async {
    final dir = await _dir();
    if (await _cachedVersion(dir) >= bundledVersion) {
      try {
        return _parse(
          await File('${dir.path}/plan.json').readAsString(),
          await File('${dir.path}/arabic.json').readAsString(),
          await File('${dir.path}/example_bn.json').readAsString(),
          await File('${dir.path}/lessons.json').readAsString(),
          await _cachedVersion(dir),
        );
      } catch (_) {
        // Cache is unreadable: fall through to the bundled copy.
      }
    }
    return _parse(
      await rootBundle.loadString('assets/data/plan_default.json'),
      await rootBundle.loadString('assets/data/arabic.json'),
      await rootBundle.loadString('assets/data/example_bn.json'),
      await rootBundle.loadString('assets/data/listening_lessons.json'),
      bundledVersion,
    );
  }

  /// Downloads newer content. Returns true if a new version was saved. Never throws.
  Future<bool> refreshFromCdn() async {
    try {
      final dir = await _dir();
      final manifest = jsonDecode(
        await _get(AppConfig.manifestPath),
      ) as Map<String, dynamic>;
      final remote = manifest['contentVersion'] as int;
      final current = await _cachedVersion(dir) > bundledVersion
          ? await _cachedVersion(dir)
          : bundledVersion;
      if (remote <= current) return false;

      final files = manifest['files'] as Map<String, dynamic>;
      final plan = await _get(files['planDefault'] as String);
      final arabic = await _get(files['arabic'] as String);
      final bn = await _get(files['exampleBn'] as String);
      final lessons = await _get(files['listeningLessons'] as String);
      // Validate before saving, so a bad download can never break the app.
      _parse(plan, arabic, bn, lessons, remote);

      await File('${dir.path}/plan.json').writeAsString(plan);
      await File('${dir.path}/arabic.json').writeAsString(arabic);
      await File('${dir.path}/example_bn.json').writeAsString(bn);
      await File('${dir.path}/lessons.json').writeAsString(lessons);
      await File('${dir.path}/version.txt').writeAsString('$remote');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> _get(String path) async {
    final url = path.startsWith('http')
        ? path
        : '${AppConfig.contentBase}$path';
    final res = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200)
      throw HttpException('HTTP ${res.statusCode}', uri: Uri.parse(url));
    return utf8.decode(res.bodyBytes);
  }

  static ContentBundle _parse(
    String planRaw,
    String arabicRaw,
    String bnRaw,
    String lessonsRaw,
    int version,
  ) {
    final plan = jsonDecode(planRaw) as Map<String, dynamic>;
    final dailyData = plan['dailyData'] as Map<String, dynamic>;
    final days = <int, List<Word>>{};
    final all = <Word>[];
    for (final e in dailyData.entries) {
      final list = (e.value as List)
          .map((w) => Word.fromJson(w as Map<String, dynamic>))
          .toList();
      days[int.parse(e.key)] = list;
      all.addAll(list);
    }
    return ContentBundle(
      days: days,
      allWords: all,
      arabic: (jsonDecode(arabicRaw) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as String),
      ),
      exampleBn: (jsonDecode(bnRaw) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as String),
      ),
      lessons: (jsonDecode(lessonsRaw) as List)
          .map((e) => ListeningLesson.fromJson(e as Map<String, dynamic>))
          .toList(),
      version: version,
    );
  }
}
