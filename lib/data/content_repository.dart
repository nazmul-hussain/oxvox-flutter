import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/config.dart';

/// Content files the app reads, by manifest key, with their bundled fallback copy.
const contentAssets = {
  'planIndex': 'assets/data/plan_index.json',
  'topics': 'assets/data/topics.json',
  'tenses': 'assets/data/tenses.json',
  'listeningQuestions': 'assets/data/listening_questions.json',
  'listeningLessons': 'assets/data/listening_lessons.json',
  'arabic': 'assets/data/arabic.json',
  'exampleBn': 'assets/data/example_bn.json',
};

/// Reads content one file at a time, only when the app needs it:
///  1. The copy downloaded from the CDN, if there is one.
///  2. The bundled asset copy (works offline on first launch).
///
/// `refreshFromCdn()` compares the per-file hashes in the CDN manifest with what the
/// device has and downloads only the changed files. Any data change pushed to oxvox-cdn
/// (with `scripts/build_manifest.py` run) reaches the app on its next start, no release needed.
/// Bundled copy of a content file. Lab modules (keys "labs" and "lab_*") live in assets/labs/.
String assetFor(String key) => contentAssets[key] ?? 'assets/labs/$key.json';

bool isLabKey(String key) => key == 'labs' || key.startsWith('lab_');

class ContentRepository {
  static const _bundledManifest = 'assets/data/manifest.json';

  Directory? _dirCache;
  Map<String, dynamic>? _bundled;

  Future<Directory> _dir() async {
    if (_dirCache != null) return _dirCache!;
    final d = Directory(
      '${(await getApplicationSupportDirectory()).path}/content2',
    );
    if (!await d.exists()) await d.create(recursive: true);
    return _dirCache = d;
  }

  File _file(Directory dir, String key) =>
      File('${dir.path}/${key.replaceAll('/', '_')}.json');

  File _metaFile(Directory dir) => File('${dir.path}/meta.json');

  /// Local state: {"contentVersion": n, "hashes": {key: hash}} for downloaded files.
  Future<Map<String, dynamic>> _meta(Directory dir) async {
    try {
      return jsonDecode(await _metaFile(dir).readAsString())
          as Map<String, dynamic>;
    } catch (_) {
      return {'contentVersion': 0, 'hashes': <String, dynamic>{}};
    }
  }

  Future<Map<String, dynamic>> _bundledManifestData() async => _bundled ??=
      jsonDecode(await rootBundle.loadString(_bundledManifest))
          as Map<String, dynamic>;

  /// Call once at start: drops downloaded files that are older than the copies bundled
  /// in this app build (after an app update ships newer content).
  Future<void> prepare() async {
    try {
      final dir = await _dir();
      final meta = await _meta(dir);
      final bundledVersion =
          (await _bundledManifestData())['contentVersion'] as int;
      if ((meta['contentVersion'] as int? ?? 0) < bundledVersion) {
        await for (final f in dir.list()) {
          if (f is File) await f.delete();
        }
      }
    } catch (_) {}
  }

  /// Raw text of one content file: downloaded copy, else bundled asset.
  Future<String> readRaw(String key) async {
    try {
      final f = _file(await _dir(), key);
      if (await f.exists()) return await f.readAsString();
    } catch (_) {
      // Unreadable download: use the bundled copy.
    }
    return rootBundle.loadString(assetFor(key));
  }

  /// Reads and parses one file on a background isolate, so big files never freeze the UI.
  /// [parse] must be a top-level or static function.
  Future<T> load<T>(String key, T Function(Object? json) parse) async {
    final raw = await readRaw(key);
    try {
      return await _parseRaw(raw, parse);
    } catch (_) {
      // A downloaded file can be valid JSON with the wrong shape (for example after a
      // content change that this app version does not understand). That must never stop
      // the app from opening: drop the download and use the copy bundled with the app.
      if (!await _dropDownloaded(key)) rethrow;
      return _parseRaw(await rootBundle.loadString(assetFor(key)), parse);
    }
  }

  Future<T> _parseRaw<T>(String raw, T Function(Object? json) parse) async {
    if (raw.length < 100000) return parse(jsonDecode(raw));
    return Isolate.run(() => parse(jsonDecode(raw)));
  }

  /// Deletes the downloaded copy of [key] and forgets its hash. False if there was none.
  Future<bool> _dropDownloaded(String key) async {
    try {
      final dir = await _dir();
      final f = _file(dir, key);
      if (!await f.exists()) return false;
      await f.delete();
      final meta = await _meta(dir);
      final hashes = Map<String, dynamic>.from(meta['hashes'] as Map? ?? {})
        ..remove(key);
      meta['hashes'] = hashes;
      await _metaFile(dir).writeAsString(jsonEncode(meta));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Word meanings for one language (lowercase headword -> meaning), from the CDN.
  /// Downloads the file the first time the language is picked. Empty when offline.
  Future<Map<String, String>> loadTranslations(String code) async {
    try {
      final dir = await _dir();
      final key = 'meanings/$code';
      final cache = _file(dir, key);
      String raw;
      if (await cache.exists()) {
        raw = await cache.readAsString();
      } else {
        final manifest = await _manifest();
        final path = (manifest['meanings'] as Map<String, dynamic>?)?[code];
        if (path == null) return const {};
        raw = await _get(path as String);
        jsonDecode(raw);
        await _save(dir, key, raw, manifest);
      }
      return await Isolate.run(
        () => (jsonDecode(raw) as Map<String, dynamic>).map(
          (k, v) => MapEntry(k.toLowerCase(), v as String),
        ),
      );
    } catch (_) {
      return const {};
    }
  }

  Map<String, dynamic>? _manifestCache;

  Future<Map<String, dynamic>> _manifest() async => _manifestCache ??=
      jsonDecode(await _get(AppConfig.manifestPath)) as Map<String, dynamic>;

  Future<void> _save(
    Directory dir,
    String key,
    String raw,
    Map<String, dynamic> manifest,
  ) async {
    // Write to a temp file and rename, so a crash never leaves half a file.
    final tmp = File('${_file(dir, key).path}.tmp');
    await tmp.writeAsString(raw, flush: true);
    await tmp.rename(_file(dir, key).path);
    final meta = await _meta(dir);
    final hashes = Map<String, dynamic>.from(meta['hashes'] as Map? ?? {});
    final h = (manifest['hashes'] as Map<String, dynamic>?)?[key];
    if (h != null) hashes[key] = h;
    final bundledVersion =
        (await _bundledManifestData())['contentVersion'] as int;
    await _metaFile(dir).writeAsString(
      jsonEncode({
        'contentVersion': [
          meta['contentVersion'] as int? ?? 0,
          bundledVersion,
        ].reduce((a, b) => a > b ? a : b),
        'hashes': hashes,
      }),
    );
  }

  /// Downloads the content files that changed on the CDN.
  /// Returns the keys that were updated (empty when nothing changed or offline). Never throws.
  Future<Set<String>> refreshFromCdn() async {
    final updated = <String>{};
    try {
      final dir = await _dir();
      _manifestCache = null;
      final manifest = await _manifest();
      final remoteHashes = manifest['hashes'] as Map<String, dynamic>? ?? {};
      final bundledHashes =
          (await _bundledManifestData())['hashes'] as Map<String, dynamic>? ??
          {};
      final files = manifest['files'] as Map<String, dynamic>;
      final meanings = manifest['meanings'] as Map<String, dynamic>? ?? {};

      // Data files the app reads, plus meaning languages already downloaded.
      final paths = <String, String>{
        for (final k in contentAssets.keys)
          if (files[k] is String) k: files[k] as String,
        // New lab modules can ship from the CDN without an app release.
        for (final k in files.keys)
          if (isLabKey(k) && files[k] is String) k: files[k] as String,
      };
      for (final e in meanings.entries) {
        final key = 'meanings/${e.key}';
        if (await _file(dir, key).exists()) paths[key] = e.value as String;
      }

      for (final e in paths.entries) {
        final remote = remoteHashes[e.key];
        if (remote == null) continue;
        final meta = await _meta(dir);
        final downloaded = await _file(dir, e.key).exists();
        final downloadedHashes = meta['hashes'] as Map? ?? const {};
        final have = downloaded
            ? downloadedHashes[e.key]
            : bundledHashes[e.key];
        if (have == remote) continue;
        try {
          final raw = await _get(e.value);
          jsonDecode(raw); // never save a broken file
          await _save(dir, e.key, raw, manifest);
          updated.add(e.key);
        } catch (_) {
          // Try again next start.
        }
      }
      if (updated.isNotEmpty) {
        final meta = await _meta(dir);
        meta['contentVersion'] = manifest['contentVersion'];
        await _metaFile(dir).writeAsString(jsonEncode(meta));
      }
    } catch (_) {}
    return updated;
  }

  Future<String> _get(String path) async {
    final url = path.startsWith('http')
        ? path
        : '${AppConfig.contentBase}$path';
    final res = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}', uri: Uri.parse(url));
    }
    return utf8.decode(res.bodyBytes);
  }
}
