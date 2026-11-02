import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/srs.dart';
import '../models/word.dart';
import 'content_repository.dart';

/// Single source of truth for user data on the device.
/// Keys mirror the Atlas collections (progress, activity, userBadges, reminders, users)
/// so a later sync can upload them without reshaping.
class AppState extends ChangeNotifier {
  final ContentRepository content;
  late SharedPreferences _prefs;

  List<Word> words = [];
  List<ListeningLesson> lessons = [];

  // users
  String themeSetting = 'auto'; // auto | day | afternoon | night
  int dailyGoal = 10;
  String? displayName;

  // reminders
  bool reminderEnabled = false;
  int reminderHour = 20;
  int reminderMinute = 0;

  // progress: wordId -> SrsCard
  final Map<String, SrsCard> progress = {};
  // activity: date -> {words, lessons, xp}
  final Map<String, Map<String, int>> activity = {};

  bool loading = true;

  AppState(this.content);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final c = await content.load();
    words = c.words;
    lessons = c.lessons;

    themeSetting = _prefs.getString('theme') ?? 'auto';
    dailyGoal = _prefs.getInt('dailyGoal') ?? 10;
    displayName = _prefs.getString('displayName');
    reminderEnabled = _prefs.getBool('reminderEnabled') ?? false;
    reminderHour = _prefs.getInt('reminderHour') ?? 20;
    reminderMinute = _prefs.getInt('reminderMinute') ?? 0;

    final p = jsonDecode(_prefs.getString('progress') ?? '{}') as Map<String, dynamic>;
    progress.addAll(p.map((k, v) => MapEntry(k, SrsCard.fromJson(v as Map<String, dynamic>))));
    final a = jsonDecode(_prefs.getString('activity') ?? '{}') as Map<String, dynamic>;
    activity.addAll(a.map((k, v) => MapEntry(k, (v as Map<String, dynamic>).map((x, y) => MapEntry(x, y as int)))));

    loading = false;
    notifyListeners();

    // Non-blocking: pick up new content when online.
    content.refreshFromCdn().then((updated) async {
      if (!updated) return;
      final fresh = await content.load();
      words = fresh.words;
      lessons = fresh.lessons;
      notifyListeners();
    });
  }

  // ---- settings ----
  Future<void> setTheme(String v) async {
    themeSetting = v;
    await _prefs.setString('theme', v);
    notifyListeners();
  }

  Future<void> setDailyGoal(int v) async {
    dailyGoal = v;
    await _prefs.setInt('dailyGoal', v);
    notifyListeners();
  }

  Future<void> setDisplayName(String v) async {
    displayName = v;
    await _prefs.setString('displayName', v);
    notifyListeners();
  }

  Future<void> setReminder({bool? enabled, int? hour, int? minute}) async {
    reminderEnabled = enabled ?? reminderEnabled;
    reminderHour = hour ?? reminderHour;
    reminderMinute = minute ?? reminderMinute;
    await _prefs.setBool('reminderEnabled', reminderEnabled);
    await _prefs.setInt('reminderHour', reminderHour);
    await _prefs.setInt('reminderMinute', reminderMinute);
    notifyListeners();
  }

  // ---- learning ----
  String get today => todayStr();

  Map<String, int> get todayActivity => activity[today] ?? {'words': 0, 'lessons': 0, 'xp': 0};

  int get todayWords => todayActivity['words'] ?? 0;

  List<Word> get dueWords {
    final out = <Word>[];
    for (final w in words) {
      if (isDue(progress[w.id])) out.add(w);
      if (out.length >= 50) break;
    }
    return out;
  }

  Future<void> rate(Word w, Rating r) async {
    final isNew = !progress.containsKey(w.id);
    progress[w.id] = reviewCard(progress[w.id], r);
    _bump(isNew ? 'words' : null, xp: switch (r) {
      Rating.again => 1,
      Rating.hard => 2,
      Rating.good => 3,
      Rating.easy => 4,
    });
    await _save();
  }

  Future<void> completeLesson() async {
    _bump(null, lessons: 1, xp: 10);
    await _save();
  }

  void _bump(String? field, {int lessons = 0, int xp = 0}) {
    final day = activity.putIfAbsent(today, () => {'words': 0, 'lessons': 0, 'xp': 0});
    if (field != null) day[field] = (day[field] ?? 0) + 1;
    day['lessons'] = (day['lessons'] ?? 0) + lessons;
    day['xp'] = (day['xp'] ?? 0) + xp;
  }

  Future<void> _save() async {
    await _prefs.setString('progress', jsonEncode(progress.map((k, v) => MapEntry(k, v.toJson()))));
    await _prefs.setString('activity', jsonEncode(activity));
    notifyListeners();
  }

  // ---- stats ----
  int get totalXp => activity.values.fold(0, (s, d) => s + (d['xp'] ?? 0));
  int get wordsLearned => progress.length;
  int get masteredWords => progress.values.where((c) => c.interval >= 21).length;
  int get lessonsDone => activity.values.fold(0, (s, d) => s + (d['lessons'] ?? 0));

  /// Consecutive days with any activity, ending today (or yesterday if today is empty).
  int get streak {
    var d = DateTime.now();
    if ((activity[fmt(d)]?['xp'] ?? 0) == 0) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while ((activity[fmt(d)]?['xp'] ?? 0) > 0) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  String fmt(DateTime d) => fmtDate(d);
}
