import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../core/plan.dart';
import '../core/srs.dart';
import '../data/app_state.dart';

/// Web: components/Settings.js exportData / importData and utils/storage.js defaultState.
/// The backup JSON has the same shape as the web state, so the files are interchangeable.
class BackupService {
  static const invalidMessage = 'That file is not a valid OxVox backup.';
  static const _themes = ['auto', 'day', 'afternoon', 'night'];

  /// Web exportData: the full state as JSON (same keys as the web app).
  static Map<String, dynamic> buildBackup(AppState s) => {
    'currentDay': s.currentDay,
    'bookmarks': {for (final k in s.bookmarks.keys) k: true},
    'srs': {for (final e in s.progress.entries) e.key: e.value.toJson()},
    'completedDays': {
      for (final e in s.completedDays.entries) '${e.key}': e.value,
    },
    'quizHistory': s.quizHistory,
    'missed': s.missed,
    'studyLog': s.studyLog,
    'listening': s.listening,
    'placement': {
      'used': s.placementUsed,
      'last': s.placementLast,
      'suggested': s.placementSuggested,
    },
    'settings': {
      'levels': s.levels,
      'days': s.planDays,
      'onboarded': true,
      'showSynonyms': s.showSynonyms,
      'includeTopics': s.includeTopics,
      'quizCount': 30,
      'theme': s.themeSetting,
      'version': 3,
      // Daily reminders were removed on the web app, so these stay at web defaults.
      'reminderOn': false,
      'reminderTimes': ['19:00'],
      'reminded': <String>[],
    },
  };

  /// Builds the file and opens the share sheet (web: download oxvox-backup-YYYY-MM-DD.json).
  static Future<void> exportBackup(AppState s) async {
    final name = 'oxvox-backup-${fmtDate(DateTime.now())}.json';
    final text = const JsonEncoder.withIndent('  ').convert(buildBackup(s));
    final bytes = Uint8List.fromList(utf8.encode(text));
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, mimeType: 'application/json', name: name),
        ],
        fileNameOverrides: [name],
      ),
    );
  }

  /// Web importData: pick a JSON file and restore it.
  /// Returns the message to show, or null when the user cancels the picker.
  static Future<String?> importBackup(AppState s) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked.isEmpty) return null;
    try {
      final bytes = await picked.first.readAsBytes();
      final data = parseBackup(jsonDecode(utf8.decode(bytes)));
      await s.applyBackup(data);
      return 'Backup restored.';
    } catch (_) {
      return invalidMessage;
    }
  }

  /// Web merge: defaults + file data, settings merged with defaults, onboarded true.
  /// Throws when the file does not have the expected types.
  static Map<String, dynamic> parseBackup(Object? raw) {
    if (raw is! Map) throw const FormatException('Not an object');
    final d = Map<String, dynamic>.from(raw);
    final st = _map(d['settings']);

    final levels = st['levels'] == null
        ? defaultLevels
        : pickLevels(List<String>.from(st['levels'] as List));
    final days = (st['days'] as num?)?.toInt() ?? defaultPlanDays;
    final theme = st['theme'] as String? ?? 'afternoon';
    if (!_themes.contains(theme)) throw const FormatException('Bad theme');
    final currentDay = (d['currentDay'] as num?)?.toInt() ?? 1;

    final progress = <String, SrsCard>{
      for (final e in _map(d['srs']).entries)
        e.key: SrsCard.fromJson(Map<String, dynamic>.from(e.value as Map)),
    };
    final today = todayStr();
    final bookmarks = <String, Map<String, dynamic>>{
      for (final e in _map(d['bookmarks']).entries)
        e.key: e.value is Map
            ? Map<String, dynamic>.from(e.value as Map)
            : {'date': today, 'day': currentDay},
    };
    final completedDays = <int, bool>{
      for (final e in _map(d['completedDays']).entries)
        int.parse(e.key): e.value == true,
    };
    final studyLog = <String, bool>{
      for (final e in _map(d['studyLog']).entries) e.key: e.value == true,
    };
    final quizHistory = [
      for (final h in (d['quizHistory'] as List? ?? const []))
        Map<String, dynamic>.from(h as Map),
    ];
    final placement = _map(d['placement']);

    return {
      'currentDay': currentDay,
      'progress': progress,
      'bookmarks': bookmarks,
      'completedDays': completedDays,
      'studyLog': studyLog,
      'quizHistory': quizHistory,
      'missed': _map(d['missed']),
      'listening': _map(d['listening']),
      'placementUsed': [
        for (final id in (placement['used'] as List? ?? const [])) id as String,
      ],
      'placementLast': placement['last'] == null
          ? null
          : _map(placement['last']),
      'placementSuggested': placement['suggested'] as String?,
      'levels': levels,
      'planDays': days.clamp(minPlanDays, maxPlanDays).toInt(),
      'theme': theme,
      'showSynonyms': st['showSynonyms'] as bool? ?? true,
      'includeTopics': st['includeTopics'] as bool? ?? true,
    };
  }

  static Map<String, dynamic> _map(Object? v) =>
      v == null ? <String, dynamic>{} : Map<String, dynamic>.from(v as Map);
}
