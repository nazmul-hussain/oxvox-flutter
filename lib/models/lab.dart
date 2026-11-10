/// Tense Lab content (CDN v1/data/tenses.json).
///
/// Drill types:
///  - choose: situation + sentence with ___, pick one option.
///  - type:   situation + sentence with ___ and a verb hint, type the form.
///  - fix:    pick the one correct sentence.
///  - bn:     Bangla sentence, pick the correct English.
class LabDrill {
  final String type;
  final String prompt;
  final String sentence;
  final String hint;
  final List<String> options;
  final List<String> answers;
  final String explain;
  final bool advanced;
  const LabDrill({
    required this.type,
    required this.prompt,
    required this.sentence,
    required this.hint,
    required this.options,
    required this.answers,
    required this.explain,
    this.advanced = false,
  });

  String get answer => answers.first;
  bool get typed => type == 'type';

  factory LabDrill.fromJson(Map<String, dynamic> j) {
    final a = j['a'];
    return LabDrill(
      type: j['t'] as String,
      prompt: (j['q'] ?? '') as String,
      sentence: (j['s'] ?? '') as String,
      hint: (j['hint'] ?? '') as String,
      options: [for (final o in (j['o'] as List? ?? const [])) o.toString()],
      answers: a is List ? [for (final x in a) x.toString()] : [a.toString()],
      explain: (j['x'] ?? '') as String,
      advanced: j['lv'] == 'adv',
    );
  }

  /// Typed answers: case, extra spaces, curly apostrophes and "..." are ignored.
  static String norm(String v) => v
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll('...', ' ')
      .replaceAll(RegExp(r'[?.!,]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  bool isCorrect(String given) {
    if (!typed) return given == answer;
    final g = norm(given);
    return answers.any((x) => norm(x) == g);
  }
}

/// One mark on the timeline. Positions run from -1 (far past) through 0 (now) to 1 (future).
class TimelineMark {
  final String kind; // point, span, wave, repeat, arrow
  final double from;
  final double to;
  final String label;
  const TimelineMark(this.kind, this.from, this.to, this.label);
  factory TimelineMark.fromJson(Map<String, dynamic> j) => TimelineMark(
    j['kind'] as String,
    (j['from'] as num).toDouble(),
    ((j['to'] ?? j['from']) as num).toDouble(),
    (j['label'] ?? '') as String,
  );
}

class LabUnit {
  final String id, title, level, idea, ideaBn;
  final List<TimelineMark> timeline;
  final List<({String name, String pos, String neg, String q})> formula;
  final List<({String rule, String bn, String ex})> uses;
  final List<String> signals;
  final List<({String wrong, String right, String why, String bn})> traps;
  final List<LabDrill> drills;
  const LabUnit({
    required this.id,
    required this.title,
    required this.level,
    required this.idea,
    required this.ideaBn,
    required this.timeline,
    required this.formula,
    required this.uses,
    required this.signals,
    required this.traps,
    required this.drills,
  });

  factory LabUnit.fromJson(Map<String, dynamic> j) {
    String s(Map m, String k) => (m[k] ?? '').toString();
    return LabUnit(
      id: j['id'] as String,
      title: j['title'] as String,
      level: s(j, 'level'),
      idea: s(j, 'idea'),
      ideaBn: s(j, 'ideaBn'),
      timeline: [
        for (final m in j['timeline'] as List? ?? const [])
          TimelineMark.fromJson(m as Map<String, dynamic>),
      ],
      formula: [
        for (final f in j['formula'] as List? ?? const [])
          (
            name: s(f as Map, 'name'),
            pos: s(f, 'pos'),
            neg: s(f, 'neg'),
            q: s(f, 'q'),
          ),
      ],
      uses: [
        for (final u in j['uses'] as List? ?? const [])
          (rule: s(u as Map, 'rule'), bn: s(u, 'bn'), ex: s(u, 'ex')),
      ],
      signals: [
        for (final x in j['signals'] as List? ?? const []) x.toString(),
      ],
      traps: [
        for (final t in j['traps'] as List? ?? const [])
          (
            wrong: s(t as Map, 'wrong'),
            right: s(t, 'right'),
            why: s(t, 'why'),
            bn: s(t, 'bn'),
          ),
      ],
      drills: [
        for (final d in j['drills'] as List? ?? const [])
          LabDrill.fromJson(d as Map<String, dynamic>),
      ],
    );
  }
}

class Lab {
  final String title, intro, introBn;
  final List<LabUnit> units;
  final List<LabDrill> mastery;
  final List<({String q, String yes, String no})> decide;
  const Lab({
    required this.title,
    required this.intro,
    required this.introBn,
    required this.units,
    required this.mastery,
    required this.decide,
  });

  List<LabDrill> get allDrills => [
    for (final u in units) ...u.drills,
    ...mastery,
  ];

  List<LabDrill> get advancedDrills => [
    for (final u in units) ...u.drills.where((d) => d.advanced),
  ];

  factory Lab.fromJson(Map<String, dynamic> j) => Lab(
    title: (j['title'] ?? 'Tense Lab') as String,
    intro: (j['intro'] ?? '') as String,
    introBn: (j['introBn'] ?? '') as String,
    units: [
      for (final u in j['units'] as List)
        LabUnit.fromJson(u as Map<String, dynamic>),
    ],
    mastery: [
      for (final d in j['mastery'] as List? ?? const [])
        LabDrill.fromJson(d as Map<String, dynamic>),
    ],
    decide: [
      for (final d in j['decide'] as List? ?? const [])
        (
          q: (d as Map)['q'].toString(),
          yes: d['yes'].toString(),
          no: d['no'].toString(),
        ),
    ],
  );
}

/// One stop on the journey map: a lab module, a word topic, or one that is coming soon.
class JourneyNode {
  final String id, title, kind, key, topic, icon, level, story;
  const JourneyNode({
    required this.id,
    required this.title,
    required this.kind,
    required this.key,
    required this.topic,
    required this.icon,
    required this.level,
    required this.story,
  });
  bool get soon => kind == 'soon';
  factory JourneyNode.fromJson(Map<String, dynamic> j) {
    String s(String k) => (j[k] ?? '').toString();
    return JourneyNode(
      id: s('id'),
      title: s('title'),
      kind: s('kind'),
      key: s('key'),
      topic: s('topic'),
      icon: s('icon'),
      level: s('level'),
      story: s('story'),
    );
  }
}

class JourneyTrack {
  final String id, title, subtitle, icon;
  final List<JourneyNode> nodes;
  const JourneyTrack(this.id, this.title, this.subtitle, this.icon, this.nodes);
}

class Journey {
  final String guide, guideIntro;
  final List<JourneyTrack> tracks;
  const Journey(this.guide, this.guideIntro, this.tracks);
  factory Journey.fromJson(Map<String, dynamic> j) => Journey(
    (j['guide'] ?? '').toString(),
    (j['guideIntro'] ?? '').toString(),
    [
      for (final t in j['tracks'] as List)
        JourneyTrack(
          (t as Map)['id'].toString(),
          t['title'].toString(),
          (t['subtitle'] ?? '').toString(),
          (t['icon'] ?? '').toString(),
          [
            for (final n in t['nodes'] as List)
              JourneyNode.fromJson(n as Map<String, dynamic>),
          ],
        ),
    ],
  );
}
