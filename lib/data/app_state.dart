import '../core/languages.dart';
import '../core/listening.dart';

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/plan.dart';
import '../core/srs.dart';
import '../core/theme.dart';
import '../services/api_client.dart';
import '../models/topic.dart';
import '../models/word.dart';
import 'content_repository.dart';
import '../services/reminder_service.dart';

/// Single source of truth for user data on the device. Keys mirror the Atlas collections.
class AppState extends ChangeNotifier {
  final ContentRepository repo;
  late SharedPreferences _prefs;

  ContentBundle? content;
  List<ListeningLesson> get lessons => content?.lessons ?? const [];
  List<Word> get words => content?.allWords ?? const [];

  // users / settings
  String themeSetting = 'afternoon';
  // User font size multiplier on top of kBaseTextScale (0.85 to 1.3, 1.0 = Medium).
  double fontScale = kDefaultFontScale;
  int dailyGoal = 10;
  String? displayName;
  int currentDay = 1;

  // reminders
  bool reminderEnabled = false;
  // Daily reminder times as "HH:mm", sorted, unique.
  List<String> reminderTimes = ['20:00'];

  // progress: wordId -> SrsCard
  final Map<String, SrsCard> progress = {};
  // activity: date -> {words, lessons, xp}
  final Map<String, Map<String, int>> activity = {};
  // study plan
  final Map<int, bool> completedDays = {};
  final Map<String, bool> studyLog = {};
  final Map<String, Map<String, dynamic>> bookmarks = {};
  // Listening results: lesson id -> {correct: [bool], date}. Same shape as web state.listening.
  Map<String, dynamic> listening = {};
  ListeningQuestions questions = const ListeningQuestions({});
  List<TopicItem> topics = const [];

  // Quiz: history (web quizHistory), missed words (web missed).
  List<Map<String, dynamic>> quizHistory = [];
  Map<String, dynamic> missed = {};

  // Study plan (web getPlan): levels and topics pick the ordered words, days split them.
  // Ordered lists come from assets/data/plan_index.json, exported from the web levelWords().
  final Map<String, Word> _wordIndex = {};
  final Map<String, Map<String, List<String>>> _orders = {};
  List<Map<String, dynamic>> levelOptions = const [];
  List<String> levels = List.of(defaultLevels);
  bool includeTopics = true;
  int planDays = defaultPlanDays;
  Map<int, List<Word>> _days = {};
  final Map<String, int> _planDayOf = {};
  List<Word> planWords = const [];

  static const planPresets = [7, 30, 60, 90, 180, 365];

  Future<void> _loadPlanIndex() async {
    final raw = jsonDecode(
      await rootBundle.loadString('assets/data/plan_index.json'),
    ) as Map<String, dynamic>;
    for (final w in raw['words'] as List) {
      final word = Word.fromJson(w as Map<String, dynamic>);
      _wordIndex[word.id] = word;
    }
    levelOptions = [
      for (final l in raw['levels'] as List)
        Map<String, dynamic>.from(l as Map),
    ];
    for (final e in (raw['orders'] as Map<String, dynamic>).entries) {
      final v = e.value as Map<String, dynamic>;
      _orders[e.key] = {
        't': List<String>.from(v['t'] as List),
        'n': List<String>.from(v['n'] as List),
      };
    }
    placementUsed = _prefs.getStringList('placementUsed') ?? [];
    final pl = _prefs.getString('placementLast');
    placementLast = pl == null ? null : jsonDecode(pl) as Map<String, dynamic>;
    placementSuggested = _prefs.getString('placementSuggested');
    levels = pickLevels(_prefs.getStringList('levels') ?? defaultLevels);
    includeTopics = _prefs.getBool('includeTopics') ?? true;
    planDays = _prefs.getInt('planDays') ?? defaultPlanDays;
    _buildDays();
  }

  void _buildDays() {
    final key = pickLevels(levels).join(',');
    final order = _orders[key]?[includeTopics ? 't' : 'n'] ?? const <String>[];
    planWords = [
      for (final id in order)
        if (_wordIndex[id] != null) _wordIndex[id]!,
    ];
    _days = buildPlanDays(
      planWords,
      planDays.clamp(minPlanDays, maxPlanDays).toInt(),
    );
    _planDayOf.clear();
    _days.forEach((d, list) {
      for (final w in list) {
        _planDayOf[w.id] = d;
      }
    });
  }

  /// Words per day for the current plan, e.g. "99" or "98–99".
  String get perDayText => perDayLabel(_days);

  /// Plan day of a word in the current plan (null when the word is not in the plan).
  int? planDayOf(String wid) => _planDayOf[wid];

  /// Every word we can show (plan words and topic items), for missed and saved lists.
  Iterable<Word> get allWords => _wordIndex.values;

  Future<void> setPlanDays(int d) async {
    planDays = d.clamp(minPlanDays, maxPlanDays).toInt();
    _buildDays();
    currentDay = currentDay.clamp(1, totalDays);
    await _prefs.setInt('planDays', planDays);
    await _prefs.setInt('currentDay', currentDay);
    notifyListeners();
  }

  /// Web toggleLevel: pick one or more CEFR levels; at least one stays selected.
  Future<void> setLevels(List<String> next) async {
    if (next.isEmpty) return;
    levels = pickLevels(next);
    _buildDays();
    currentDay = currentDay.clamp(1, totalDays);
    await _prefs.setStringList('levels', levels);
    await _prefs.setInt('currentDay', currentDay);
    notifyListeners();
  }

  /// Web includeTopics switch: native-speech topics in the plan, quizzes and study.
  Future<void> setIncludeTopics(bool on) async {
    includeTopics = on;
    _buildDays();
    currentDay = currentDay.clamp(1, totalDays);
    await _prefs.setBool('includeTopics', on);
    await _prefs.setInt('currentDay', currentDay);
    notifyListeners();
  }

  /// Missed words sorted by wrong count (web missedList).
  List<({Word w, int count})> get missedList {
    final list = <({Word w, int count})>[];
    for (final e in missed.entries) {
      final w = _wordIndex[e.key];
      if (w == null) continue;
      list.add((w: w, count: (e.value as Map)['count'] as int));
    }
    list.sort((a, b) => b.count.compareTo(a.count));
    return list;
  }

  /// Saved (bookmarked) words (web savedList).
  List<Word> get savedWords => [
    for (final id in bookmarks.keys)
      if (_wordIndex[id] != null) _wordIndex[id]!,
  ];

  // Level test (web placement): asked word ids, last result and the level suggested to the plan.
  List<String> placementUsed = [];
  Map<String, dynamic>? placementLast;
  String? placementSuggested;

  /// Words per CEFR level for the level test (web placementPools: bank words with a meaning).
  Map<String, List<Word>> placementPools() {
    final out = {for (final c in cefrLevels) c: <Word>[]};
    for (final w in _wordIndex.values) {
      if (w.meaning.isEmpty || !out.containsKey(w.cefr)) continue;
      out[w.cefr]!.add(w);
    }
    return out;
  }

  /// Web estimateWordLevel: highest CEFR level where at least half of its words are seen.
  String get estimatedWordLevel {
    final seenIds = progress.keys.toSet();
    var level = cefrLevels.first;
    for (final c in cefrLevels) {
      final words = _wordIndex.values.where((w) => w.cefr == c).toList();
      if (words.isEmpty) continue;
      final share =
          words.where((w) => seenIds.contains(w.id)).length / words.length;
      if (share < 0.5) break;
      level = c;
    }
    return level;
  }

  Future<void> recordPlacementAnswer(String wid) async {
    if (!placementUsed.contains(wid)) placementUsed.add(wid);
    await _prefs.setStringList('placementUsed', placementUsed);
  }

  Future<void> setPlacementResult(String level) async {
    placementLast = {'level': level, 'date': todayStr()};
    placementSuggested = level;
    await _prefs.setString('placementLast', jsonEncode(placementLast));
    await _prefs.setString('placementSuggested', level);
    notifyListeners();
  }

  Future<void> resetPlacementUsed() async {
    placementUsed = [];
    await _prefs.setStringList('placementUsed', placementUsed);
  }

  /// Web FlashCards: rate one card (again / hard / good / easy) and save the review.
  Future<void> rateCard(String wid, Rating rating) async {
    progress[wid] = reviewCard(progress[wid], rating);
    await _saveProgress();
    notifyListeners();
  }

  Future<void> clearMissed(String wid) async {
    missed.remove(wid);
    await _prefs.setString('missed', jsonEncode(missed));
    notifyListeners();
  }

  bool isDayQuizzed(int day) => quizHistory.any((h) => h['day'] == day);

  /// Web quizNext: a studied day that has no quiz yet, else the first day without a quiz.
  int? get quizNextDay {
    final days = List.generate(totalDays, (i) => i + 1);
    return days.where((d) => isDayStudied(d) && !isDayQuizzed(d)).firstOrNull ??
        days.where((d) => !isDayQuizzed(d)).firstOrNull;
  }

  double? get quizAverage {
    if (quizHistory.isEmpty) return null;
    final total = quizHistory.fold<int>(0, (a, h) => a + (h['total'] as int));
    final score = quizHistory.fold<int>(0, (a, h) => a + (h['score'] as int));
    return total == 0 ? null : score / total;
  }

  Future<void> answerQuiz(Word w, bool correct, String title) async {
    progress[w.id] = reviewCard(
      progress[w.id],
      correct ? Rating.good : Rating.again,
    );
    if (correct) {
      missed.remove(w.id);
    } else {
      final prev = missed[w.id] as Map<String, dynamic>?;
      missed[w.id] = {
        'count': (prev?['count'] as int? ?? 0) + 1,
        'last': todayStr(),
        'from': title,
      };
    }
    await _prefs.setString('missed', jsonEncode(missed));
    await _saveProgress();
  }

  Future<void> saveQuizResult({
    required int? day,
    required String title,
    required int score,
    required int total,
  }) async {
    quizHistory.add({
      'day': day,
      'title': title,
      'score': score,
      'total': total,
      'date': todayStr(),
    });
    await _prefs.setString('quizHistory', jsonEncode(quizHistory));
    notifyListeners();
  }

  // Account: the same Netlify API and MongoDB Atlas users as the web app (/api/auth/*).
  // Guests use the app without an account; signing in stores the server session cookie (OxApi).
  OxApi get api => OxApi(_prefs);
  Map<String, dynamic>? _user; // {name, username, email, phone}
  bool onboarded = false; // web oxvox.welcomeDone / settings.onboarded

  bool get isSignedIn => _user != null;
  String? get accountName => _user?['name'] as String?;

  /// The login the account uses (username, else email, else phone), as shown on the account form.
  String? get accountUsername {
    final u = _user;
    if (u == null) return null;
    for (final k in ['username', 'email', 'phone']) {
      final v = (u[k] ?? '') as String;
      if (v.isNotEmpty) return v;
    }
    return null;
  }

  static Map<String, dynamic> _userOf(Map<String, dynamic> u) => {
    'name': (u['name'] ?? '') as String,
    'username': (u['username'] ?? '') as String,
    'email': (u['email'] ?? '') as String,
    'phone': (u['phone'] ?? '') as String,
  };

  Future<void> _setUser(Map<String, dynamic>? u) async {
    _user = u;
    if (u == null) {
      await _prefs.remove('accountUser');
    } else {
      await _prefs.setString('accountUser', jsonEncode(u));
    }
    notifyListeners();
  }

  /// On start: ask the server who is signed in. Offline, fall back to the last known account.
  Future<void> _restoreSession() async {
    final cached = _prefs.getString('accountUser');
    if (cached != null) _user = jsonDecode(cached) as Map<String, dynamic>;
    if (!api.hasSession) {
      await _setUser(null);
      return;
    }
    try {
      final res = await api.request('GET', 'auth/me');
      await _setUser(_userOf(res['user'] as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (e.status == 401) {
        await api.clearSession();
        await _setUser(null);
      }
      // Other errors (offline): keep the cached account.
    }
  }

  /// Web Auth (sign up). Returns the message to show, or null when the account is created and signed in.
  Future<String?> signUp({
    required String name,
    required String identifier,
    required String password,
  }) async {
    try {
      final res = await api.request(
        'POST',
        'auth/register',
        body: {'name': name, 'identifier': identifier, 'password': password},
      );
      await _setUser(_userOf(res['user'] as Map<String, dynamic>));
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Web Auth (log in). Username, email or phone plus password.
  Future<String?> logIn({
    required String identifier,
    required String password,
  }) async {
    try {
      final res = await api.request(
        'POST',
        'auth/login',
        body: {'identifier': identifier, 'password': password},
      );
      await _setUser(_userOf(res['user'] as Map<String, dynamic>));
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<void> logOut() async {
    try {
      await api.request('POST', 'auth/logout');
    } on ApiException {
      // Signed out locally even if the server is unreachable.
    }
    await api.clearSession();
    await _setUser(null);
  }

  /// Account > Save profile (web Account.js saveProfile).
  Future<String?> updateProfile({
    required String name,
    required String identifier,
  }) async {
    try {
      final res = await api.request(
        'PUT',
        'auth/profile',
        body: {'name': name, 'identifier': identifier},
      );
      await _setUser(_userOf(res['user'] as Map<String, dynamic>));
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Account > Change password (web changePassword).
  Future<String?> changePassword({
    required String current,
    required String next,
  }) async {
    try {
      await api.request(
        'POST',
        'auth/password',
        body: {'current': current, 'next': next},
      );
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Account > Delete account (web deleteAccount): removes the login and the progress on this device.
  Future<String?> deleteAccount({required String password}) async {
    try {
      await api.request('DELETE', 'auth/account', body: {'password': password});
    } on ApiException catch (e) {
      return e.message;
    }
    await api.clearSession();
    await _setUser(null);
    await resetProgress();
    return null;
  }

  /// Welcome: first-visit setup is finished (web settings.onboarded).
  Future<void> setOnboarded() async {
    onboarded = true;
    await _prefs.setBool('onboarded', true);
    notifyListeners();
  }

  /// Welcome preview: words per day for a levels and days choice, topics included (web getPlan(levels, days, true)).
  String previewPerDayText(List<String> levels, int days) {
    final key = pickLevels(levels).join(',');
    final order = _orders[key]?['t'] ?? const <String>[];
    final list = [
      for (final id in order)
        if (_wordIndex[id] != null) _wordIndex[id]!,
    ];
    return perDayLabel(
      buildPlanDays(list, days.clamp(minPlanDays, maxPlanDays).toInt()),
    );
  }

  /// Web importData: replace saved progress with a backup checked by BackupService.parseBackup.
  Future<void> applyBackup(Map<String, dynamic> b) async {
    progress
      ..clear()
      ..addAll(b['progress'] as Map<String, SrsCard>);
    activity.clear();
    bookmarks
      ..clear()
      ..addAll(b['bookmarks'] as Map<String, Map<String, dynamic>>);
    completedDays
      ..clear()
      ..addAll(b['completedDays'] as Map<int, bool>);
    studyLog
      ..clear()
      ..addAll(b['studyLog'] as Map<String, bool>);
    quizHistory = b['quizHistory'] as List<Map<String, dynamic>>;
    missed = b['missed'] as Map<String, dynamic>;
    listening = b['listening'] as Map<String, dynamic>;
    placementUsed = b['placementUsed'] as List<String>;
    placementLast = b['placementLast'] as Map<String, dynamic>?;
    placementSuggested = b['placementSuggested'] as String?;
    themeSetting = b['theme'] as String;
    showSynonyms = b['showSynonyms'] as bool;
    includeTopics = b['includeTopics'] as bool;
    levels = b['levels'] as List<String>;
    planDays = b['planDays'] as int;
    currentDay = b['currentDay'] as int;
    _buildDays();
    currentDay = currentDay.clamp(1, totalDays).toInt();

    await _prefs.setString(
      'progress',
      jsonEncode(progress.map((k, v) => MapEntry(k, v.toJson()))),
    );
    await _prefs.remove('activity');
    await _prefs.setString(
      'completedDays',
      jsonEncode(completedDays.map((k, v) => MapEntry('$k', v))),
    );
    await _prefs.setString('studyLog', jsonEncode(studyLog));
    await _prefs.setString('bookmarks', jsonEncode(bookmarks));
    await _prefs.setString('listening', jsonEncode(listening));
    await _prefs.setString('quizHistory', jsonEncode(quizHistory));
    await _prefs.setString('missed', jsonEncode(missed));
    await _prefs.setStringList('placementUsed', placementUsed);
    if (placementLast == null) {
      await _prefs.remove('placementLast');
    } else {
      await _prefs.setString('placementLast', jsonEncode(placementLast));
    }
    if (placementSuggested == null) {
      await _prefs.remove('placementSuggested');
    } else {
      await _prefs.setString('placementSuggested', placementSuggested!);
    }
    await _prefs.setString('theme', themeSetting);
    await _prefs.setStringList('levels', levels);
    await _prefs.setBool('includeTopics', includeTopics);
    await _prefs.setInt('planDays', planDays);
    await _prefs.setInt('currentDay', currentDay);
    notifyListeners();
  }

  Future<void> resetProgress() async {
    // Web reset: the whole state goes back to defaults except settings, so level test state is cleared too.
    placementUsed = [];
    placementLast = null;
    placementSuggested = null;
    await _prefs.remove('placementUsed');
    await _prefs.remove('placementLast');
    await _prefs.remove('placementSuggested');
    progress.clear();
    activity.clear();
    completedDays.clear();
    studyLog.clear();
    bookmarks.clear();
    quizHistory = [];
    missed = {};
    listening = {};
    currentDay = 1;
    for (final k in [
      'progress',
      'activity',
      'completedDays',
      'studyLog',
      'bookmarks',
      'listening',
      'quizHistory',
      'missed',
      'currentDay',
    ]) {
      await _prefs.remove(k);
    }
    notifyListeners();
  }

  Future<void> saveListening(String id, List<bool> correct) async {
    listening[id] = {'correct': correct, 'date': todayStr()};
    await _prefs.setString('listening', jsonEncode(listening));
    notifyListeners();
  }

  bool loading = true;

  AppState(this.repo);

  int get totalDays =>
      _days.isNotEmpty ? _days.length : (content?.totalDays ?? 0);
  bool showSynonyms = true; // web default settings.showSynonyms

  // ---- meaning languages ----
  // Main meaning language (chosen from the device language on first start) and
  // the optional second line (default Arabic; 'none' hides it).
  String primaryLang = fallbackPrimaryLang;
  String secondaryLang = defaultSecondaryLang;
  // Loaded translation maps (lowercase headword -> meaning), keyed by language code.
  // Bangla uses word.meaning and Arabic uses content.arabic, so they are not stored here.
  final Map<String, Map<String, String>> _translations = {};

  MeaningLang get primaryMeaningLang => langByCode(primaryLang)!;
  MeaningLang? get secondaryMeaningLang => langByCode(secondaryLang);

  Map<String, String>? _mapFor(String code) {
    if (code == 'bn') return null;
    if (code == 'ar') return content?.arabic ?? const {};
    return _translations[code] ?? const {};
  }

  Future<void> _loadLangMaps() async {
    for (final code in {primaryLang, secondaryLang}) {
      if (code == 'bn' || code == 'ar' || _translations.containsKey(code)) {
        continue;
      }
      if (langByCode(code) == null) continue;
      _translations[code] = await repo.loadTranslations(code);
    }
  }

  /// Main meaning of a word in the chosen language. Falls back to the bundled
  /// Bangla meaning when a translation is missing, so every card always has text.
  String meaningOf(Word w) {
    if (primaryLang == 'bn') return w.meaning;
    final t = _mapFor(primaryLang)?[w.id];
    return (t == null || t.isEmpty) ? w.meaning : t;
  }

  /// Second line for a word, or null when it is off or missing.
  String? secondaryOf(Word w) {
    if (secondaryLang == secondaryNone || secondaryLang == primaryLang) {
      return null;
    }
    if (secondaryLang == 'bn') return w.meaning;
    final t = _mapFor(secondaryLang)?[w.id];
    return (t == null || t.isEmpty) ? null : t;
  }

  /// Second line for a headword id (used by quiz options, which hold word text).
  String? secondaryForId(String id) {
    final w = _wordIndex[id];
    return w == null ? null : secondaryOf(w);
  }

  /// Both meaning lines for a word, ready to pass to word cards.
  WordMeanings lineOf(Word w) => WordMeanings(
    primary: meaningOf(w),
    primaryRtl: primaryMeaningLang.rtl,
    secondary: secondaryOf(w),
    secondaryRtl: secondaryMeaningLang?.rtl ?? false,
  );

  Future<void> setPrimaryLang(String code) async {
    if (langByCode(code) == null) return;
    primaryLang = code;
    await _prefs.setString('primaryLang', code);
    await _loadLangMaps();
    notifyListeners();
  }

  Future<void> setSecondaryLang(String code) async {
    if (code != secondaryNone && langByCode(code) == null) return;
    secondaryLang = code;
    await _prefs.setString('secondaryLang', code);
    await _loadLangMaps();
    notifyListeners();
  }

  List<Word> dayWords(int day) => _days[day] ?? const [];

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    content = await repo.load();
    _refreshInBackground();

    themeSetting = _prefs.getString('theme') ?? 'afternoon';
    // One-time switch: older installs saved 'auto' (blue by day). Move them to the orange default once.
    if (!_prefs.containsKey('themeOrangeDefault')) {
      themeSetting = 'afternoon';
      await _prefs.setString('theme', themeSetting);
      await _prefs.setBool('themeOrangeDefault', true);
    }
    fontScale = snapFontScale(_prefs.getDouble('fontScale') ?? kDefaultFontScale);
    dailyGoal = _prefs.getInt('dailyGoal') ?? 10;
    displayName = _prefs.getString('displayName');
    onboarded = _prefs.getBool('onboarded') ?? false;
    primaryLang =
        _prefs.getString('primaryLang') ?? deviceDefaultPrimaryLang();
    secondaryLang = _prefs.getString('secondaryLang') ?? defaultSecondaryLang;
    await _loadLangMaps();
    await _restoreSession();
    currentDay = _prefs.getInt('currentDay') ?? 1;
    reminderEnabled = _prefs.getBool('reminderEnabled') ?? false;
    final savedTimes = _prefs.getStringList('reminderTimes');
    if (savedTimes != null) {
      reminderTimes = savedTimes;
    } else if (_prefs.containsKey('reminderHour')) {
      // Migrate the old single reminder.
      final h = _prefs.getInt('reminderHour') ?? 20;
      final m = _prefs.getInt('reminderMinute') ?? 0;
      reminderTimes = [_fmtTime(h, m)];
    }
    if (reminderEnabled) {
      ReminderService.sync(
        enabled: true,
        times: reminderTimes,
      ).catchError((_) {});
    }

    progress.addAll(
      (jsonDecode(_prefs.getString('progress') ?? '{}') as Map<String, dynamic>)
          .map(
            (k, v) => MapEntry(k, SrsCard.fromJson(v as Map<String, dynamic>)),
          ),
    );
    activity.addAll(
      (jsonDecode(_prefs.getString('activity') ?? '{}') as Map<String, dynamic>)
          .map(
            (k, v) => MapEntry(
              k,
              (v as Map<String, dynamic>).map((x, y) => MapEntry(x, y as int)),
            ),
          ),
    );
    completedDays.addAll(
      (jsonDecode(_prefs.getString('completedDays') ?? '{}')
              as Map<String, dynamic>)
          .map((k, v) => MapEntry(int.parse(k), v as bool)),
    );
    studyLog.addAll(
      (jsonDecode(_prefs.getString('studyLog') ?? '{}') as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as bool)),
    );
    bookmarks.addAll(
      (jsonDecode(_prefs.getString('bookmarks') ?? '{}')
              as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as Map<String, dynamic>)),
    );

    listening = (jsonDecode(
      _prefs.getString('listening') ?? '{}',
    ) as Map<String, dynamic>);
    questions = await ListeningQuestions.load();
    await _loadPlanIndex();
    quizHistory = [
      for (final h
          in (jsonDecode(_prefs.getString('quizHistory') ?? '[]') as List))
        Map<String, dynamic>.from(h as Map),
    ];
    missed =
        jsonDecode(_prefs.getString('missed') ?? '{}') as Map<String, dynamic>;
    topics = [
      for (final t in (jsonDecode(
        await rootBundle.loadString('assets/data/topics.json'),
      ) as List))
        TopicItem.fromJson(t as Map<String, dynamic>),
    ];

    loading = false;
    notifyListeners();
  }

  /// Pick up newer content from the CDN without blocking the UI.
  void _refreshInBackground() {
    repo.refreshFromCdn().then((updated) async {
      if (!updated) return;
      content = await repo.load();
      notifyListeners();
    });
  }

  // ---- settings ----
  Future<void> setTheme(String v) async {
    themeSetting = v;
    await _prefs.setString('theme', v);
    notifyListeners();
  }

  /// Font size multiplier, snapped to one of the fixed font size steps.
  Future<void> setFontScale(double v) async {
    fontScale = snapFontScale(v);
    await _prefs.setDouble('fontScale', fontScale);
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

  static String _fmtTime(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  /// Saves the reminder list and reschedules all notifications.
  Future<void> _saveReminders() async {
    reminderTimes = {...reminderTimes}.toList()..sort();
    await _prefs.setBool('reminderEnabled', reminderEnabled);
    await _prefs.setStringList('reminderTimes', reminderTimes);
    notifyListeners();
    await ReminderService.sync(
      enabled: reminderEnabled,
      times: reminderTimes,
    ).catchError((_) {});
  }

  Future<void> setReminderEnabled(bool v) async {
    reminderEnabled = v;
    await _saveReminders();
  }

  /// Replaces the time at [index] (or adds one when [index] is null).
  Future<void> setReminderTime({int? index, required String time}) async {
    final list = [...reminderTimes];
    if (index == null) {
      list.add(time);
    } else {
      list[index] = time;
    }
    reminderTimes = list;
    await _saveReminders();
  }

  Future<void> removeReminderTime(int index) async {
    final list = [...reminderTimes]..removeAt(index);
    reminderTimes = list;
    await _saveReminders();
  }

  /// Formats hour/minute as "HH:mm".
  static String formatReminderTime(int h, int m) => _fmtTime(h, m);

  // ---- study plan ----
  Future<void> setDay(int d) async {
    currentDay = d.clamp(1, totalDays);
    await _prefs.setInt('currentDay', currentDay);
    notifyListeners();
  }

  /// Web: "Mark day complete" toggles; completing also logs the study day.
  Future<void> toggleDayDone(int day) async {
    if (completedDays[day] == true) {
      completedDays.remove(day);
    } else {
      completedDays[day] = true;
      studyLog[todayStr()] = true;
    }
    await _prefs.setString(
      'completedDays',
      jsonEncode(completedDays.map((k, v) => MapEntry('$k', v))),
    );
    await _prefs.setString('studyLog', jsonEncode(studyLog));
    notifyListeners();
  }

  Future<void> toggleBookmark(String wid) async {
    if (bookmarks.containsKey(wid)) {
      bookmarks.remove(wid);
    } else {
      bookmarks[wid] = {'date': todayStr(), 'day': currentDay};
    }
    await _prefs.setString('bookmarks', jsonEncode(bookmarks));
    notifyListeners();
  }

  bool isDayStudied(int day) =>
      completedDays[day] == true ||
      dayWords(day).every((w) => progress.containsKey(w.id));

  // ---- learning ----
  String get today => todayStr();

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
    final day = activity.putIfAbsent(
      today,
      () => {'words': 0, 'lessons': 0, 'xp': 0},
    );
    if (isNew) day['words'] = (day['words'] ?? 0) + 1;
    day['xp'] =
        (day['xp'] ?? 0) +
        switch (r) {
          Rating.again => 1,
          Rating.hard => 2,
          Rating.good => 3,
          Rating.easy => 4,
        };
    await _saveProgress();
  }

  Future<void> completeLesson() async {
    final day = activity.putIfAbsent(
      today,
      () => {'words': 0, 'lessons': 0, 'xp': 0},
    );
    day['lessons'] = (day['lessons'] ?? 0) + 1;
    day['xp'] = (day['xp'] ?? 0) + 10;
    await _saveProgress();
  }

  Future<void> _saveProgress() async {
    await _prefs.setString(
      'progress',
      jsonEncode(progress.map((k, v) => MapEntry(k, v.toJson()))),
    );
    await _prefs.setString('activity', jsonEncode(activity));
    notifyListeners();
  }

  // ---- stats ----
  int get totalXp => activity.values.fold(0, (s, d) => s + (d['xp'] ?? 0));
  int get wordsLearned => progress.length;
  int get masteredWords =>
      progress.values.where((c) => c.interval >= 21).length;
  int get lessonsDone =>
      activity.values.fold(0, (s, d) => s + (d['lessons'] ?? 0));
  int get daysDone => completedDays.length;

  /// Consecutive study days ending today (or yesterday if today is not logged yet).
  int get streak {
    var d = DateTime.now();
    if (studyLog[fmtDate(d)] != true) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (studyLog[fmtDate(d)] == true) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }
}
