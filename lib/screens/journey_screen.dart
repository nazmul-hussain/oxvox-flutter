import 'dart:math';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/app_state.dart';
import '../models/lab.dart';
import 'lab_screen.dart';

/// The learning journey: four tracks of lessons on a winding path, with stars, a story guide,
/// a "continue" card and the Daily 5 challenge. Replaces the flat topic grid.
class JourneyView extends StatefulWidget {
  final AppState state;
  final OxPalette p;
  final void Function(String topicId) onOpenTopic;
  const JourneyView({
    super.key,
    required this.state,
    required this.p,
    required this.onOpenTopic,
  });

  @override
  State<JourneyView> createState() => _JourneyViewState();
}

const _icons = <String, IconData>{
  'foundation': Icons.foundation,
  'help': Icons.help_outline,
  'article': Icons.article,
  'place': Icons.place,
  'inventory': Icons.inventory_2,
  'timeline': Icons.timeline,
  'gavel': Icons.gavel,
  'swap_horiz': Icons.swap_horiz,
  'published_with_changes': Icons.published_with_changes,
  'link': Icons.link,
  'record_voice_over': Icons.record_voice_over,
  'directions_run': Icons.directions_run,
  'join_inner': Icons.join_inner,
  'forum': Icons.forum,
  'account_tree': Icons.account_tree,
  'emoji_objects': Icons.emoji_objects,
  'handshake': Icons.handshake,
  'volunteer_activism': Icons.volunteer_activism,
  'tune': Icons.tune,
  'thumbs_up_down': Icons.thumbs_up_down,
  'event': Icons.event,
  'build': Icons.build,
  'auto_stories': Icons.auto_stories,
  'balance': Icons.balance,
  'work': Icons.work,
  'mail': Icons.mail,
  'waving_hand': Icons.waving_hand,
  'call': Icons.call,
  'badge': Icons.badge,
  'co_present': Icons.co_present,
  'support_agent': Icons.support_agent,
  'flight': Icons.flight,
  'storefront': Icons.storefront,
};

IconData iconFor(String name) => _icons[name] ?? Icons.school;

class _JourneyViewState extends State<JourneyView> {
  Future<void>? _loading;

  /// Track shown below the picker; null = the one holding the next lesson.
  String? _trackId;

  AppState get s => widget.state;
  OxPalette get p => widget.p;

  @override
  void initState() {
    super.initState();
    _loading = _loadAll();
  }

  /// Lab files are small; load them all so the map can show stars for every node.
  Future<void> _loadAll() async {
    final j = s.journey;
    if (j == null) return;
    await Future.wait([
      for (final t in j.tracks)
        for (final n in t.nodes)
          if (n.kind == 'lab') s.loadLab(n.key),
    ]);
  }

  /// Stars for a node: lab = average unit stars; word topic = share of words studied.
  int _stars(JourneyNode n) {
    if (n.kind == 'lab') {
      final lab = s.labs[n.key];
      return lab == null ? 0 : s.labStars(n.key, lab);
    }
    if (n.kind == 'words') {
      final t = s.topics.where((t) => t.id == n.topic).firstOrNull;
      if (t == null || t.words.isEmpty) return 0;
      final f =
          t.words.where((w) => s.progress[w.id] != null).length /
          t.words.length;
      return f >= 0.9
          ? 3
          : f >= 0.6
          ? 2
          : f >= 0.3
          ? 1
          : 0;
    }
    return 0;
  }

  bool _available(JourneyNode n) => n.kind == 'words'
      ? s.topics.any((t) => t.id == n.topic)
      : n.kind == 'lab' && s.labs[n.key] != null;

  void _open(JourneyNode n) {
    if (n.soon || !_available(n)) {
      _soon(n);
      return;
    }
    if (n.kind == 'words') {
      widget.onOpenTopic(n.topic);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LabScreen(
          state: s,
          p: p,
          labKey: n.key,
          title: n.title,
          story: n.story,
        ),
      ),
    );
  }

  void _soon(JourneyNode n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: p.surface,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(iconFor(n.icon), color: p.accent, size: 32),
            const SizedBox(height: 8),
            Text(
              n.title,
              style: TextStyle(
                color: p.ink,
                fontSize: OxType.title,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              n.story,
              style: TextStyle(color: p.muted, fontSize: OxType.body),
            ),
            const SizedBox(height: 12),
            Text(
              'Coming soon. New lessons arrive automatically, no update needed.',
              style: TextStyle(color: p.accent, fontSize: OxType.small),
            ),
          ],
        ),
      ),
    );
  }

  /// Daily 5: five random drills from every lab, a quick 2-minute habit with bonus XP.
  void _daily() {
    final pool = <LabDrill>[for (final l in s.labs.values) ...l.allDrills];
    if (pool.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LabDrillScreen(
          state: s,
          p: p,
          title: 'Daily 5',
          drills: pool,
          labKey: 'daily',
          unitId: 'best',
          limit: 5,
          bonusXp: 20,
          onFinished: s.markDailyDone,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final j = s.journey;
    if (j == null) {
      return Text('Lessons are loading.', style: TextStyle(color: p.muted));
    }
    return FutureBuilder(
      future: _loading,
      builder: (context, snap) => ListenableBuilder(
        listenable: s,
        builder: (context, _) =>
            _body(j, snap.connectionState == ConnectionState.done),
      ),
    );
  }

  Widget _body(Journey j, bool ready) {
    final all = [for (final t in j.tracks) ...t.nodes];
    final next = all
        .where((n) => !n.soon && _available(n) && _stars(n) < 2)
        .firstOrNull;
    final totalStars = all.fold<int>(0, (a, n) => a + _stars(n));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your English journey',
          style: TextStyle(
            fontSize: OxType.heading,
            fontWeight: FontWeight.w500,
            color: p.ink,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _pill(
              Icons.local_fire_department,
              '${s.streak}',
              'day streak',
              legible(p.orange, p),
            ),
            const SizedBox(width: 8),
            _pill(Icons.bolt, '${s.xpToday}', 'XP today', p.accent),
            const SizedBox(width: 8),
            _pill(Icons.star_rounded, '$totalStars', 'stars', starColor(p)),
          ],
        ),
        const SizedBox(height: 12),
        if (next != null) _continueCard(next),
        const SizedBox(height: 10),
        _dailyCard(ready),
        const SizedBox(height: 6),
        const SizedBox(height: 14),
        _trackPicker(j, next),
        _track(_selected(j, next)),
      ],
    );
  }

  Widget _pill(IconData icon, String v, String label, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: c, size: 20),
          const SizedBox(width: 4),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v,
                  style: TextStyle(
                    color: p.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: OxType.subtitle,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(color: p.muted, fontSize: OxType.micro),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _continueCard(JourneyNode n) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: () => _open(n),
    child: Ink(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [p.heroFrom, p.heroTo]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _stars(n) == 0 ? 'START HERE' : 'CONTINUE',
            style: TextStyle(
              color: p.heroInk,
              fontSize: OxType.micro,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(iconFor(n.icon), color: p.heroInk, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  n.title,
                  style: TextStyle(
                    color: p.heroInk,
                    fontSize: OxType.title,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.play_circle_fill, color: p.heroInk, size: 36),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            n.story,
            style: TextStyle(color: p.heroInk, fontSize: OxType.small),
          ),
        ],
      ),
    ),
  );

  Widget _dailyCard(bool ready) {
    final done = s.dailyDoneToday;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: done ? p.greenSoft : p.surface,
        border: Border.all(color: done ? p.green : p.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.emoji_events : Icons.today,
            color: done ? p.green : p.accent,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  done ? 'Daily 5 done!' : 'Daily 5',
                  style: TextStyle(
                    color: p.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: OxType.subtitle,
                  ),
                ),
                Text(
                  done
                      ? 'Come back tomorrow to keep your streak.'
                      : '5 mixed drills, about 2 minutes. +20 bonus XP at 80%.',
                  style: TextStyle(color: p.muted, fontSize: OxType.caption),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: ready ? _daily : null,
            style: FilledButton.styleFrom(
              backgroundColor: p.brand,
              foregroundColor: p.onBrand,
            ),
            child: Text(done ? 'Again' : 'Go'),
          ),
        ],
      ),
    );
  }

  JourneyTrack _selected(Journey j, JourneyNode? next) {
    final id =
        _trackId ??
        j.tracks
            .where((t) => next != null && t.nodes.contains(next))
            .firstOrNull
            ?.id;
    return j.tracks.where((t) => t.id == id).firstOrNull ?? j.tracks.first;
  }

  /// All tracks at once, two per row: tap one to show its path.
  Widget _trackPicker(Journey j, JourneyNode? next) {
    final sel = _selected(j, next);
    return LayoutBuilder(
      builder: (context, box) {
        final w = (box.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in j.tracks)
              SizedBox(width: w, child: _trackTile(t, t.id == sel.id)),
          ],
        );
      },
    );
  }

  Widget _trackTile(JourneyTrack t, bool on) {
    final live = t.nodes.where((n) => !n.soon).toList();
    final done = live.where((n) => _stars(n) >= 2).length;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _trackId = t.id),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: on ? p.brand : p.surface,
          border: Border.all(color: on ? p.brand : p.line, width: on ? 2 : 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  iconFor(t.icon),
                  size: 20,
                  color: on ? p.onBrand : p.accent,
                ),
                const Spacer(),
                Text(
                  '$done/${live.length}',
                  style: TextStyle(
                    color: on ? p.onBrand : p.muted,
                    fontSize: OxType.caption,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              t.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: on ? p.onBrand : p.ink,
                fontSize: OxType.small,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: live.isEmpty ? 0 : done / live.length,
                minHeight: 4,
                color: on ? p.onBrand : p.green,
                backgroundColor: on
                    ? p.onBrand.withValues(alpha: 0.25)
                    : p.surface2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _track(JourneyTrack t) {
    final live = t.nodes.where((n) => !n.soon).toList();
    final done = live.where((n) => _stars(n) >= 2).length;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconFor(t.icon), color: p.accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      style: TextStyle(
                        color: p.ink,
                        fontSize: OxType.subtitle,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      t.subtitle,
                      style: TextStyle(
                        color: p.muted,
                        fontSize: OxType.caption,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$done/${live.length}',
                style: TextStyle(color: p.muted, fontSize: OxType.small),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: live.isEmpty ? 0 : done / live.length,
              minHeight: 5,
              color: p.green,
              backgroundColor: p.surface2,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, box) => Column(
              children: [
                for (var i = 0; i < t.nodes.length; i++)
                  _node(t.nodes[i], i, box.maxWidth),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A node on the winding path: offset left and right like a trail.
  Widget _node(JourneyNode n, int i, double width) {
    final stars = _stars(n);
    final soon = n.soon || !_available(n);
    final passed = stars >= 2;
    final offset = sin(i * pi / 2.2) * (width * 0.22);
    final color = soon ? p.surface2 : (passed ? p.green : p.brand);
    final ink = soon ? p.faint : (passed ? readableOn(p.green) : p.onBrand);
    return Column(
      children: [
        if (i > 0)
          Transform.translate(
            offset: Offset(
              offset * 0.5 + sin((i - 1) * pi / 2.2) * (width * 0.11),
              0,
            ),
            child: Column(
              children: [
                for (var k = 0; k < 3; k++)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: p.line,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        Transform.translate(
          offset: Offset(offset, 0),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _open(n),
            child: SizedBox(
              width: 150,
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.black.withValues(alpha: 0.18),
                              width: 5,
                            ),
                          ),
                          boxShadow: soon
                              ? null
                              : [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                        ),
                        child: Icon(
                          soon ? Icons.lock_clock : iconFor(n.icon),
                          color: ink,
                          size: 30,
                        ),
                      ),
                      if (n.level.isNotEmpty)
                        Positioned(
                          right: -22,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: p.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: p.line),
                            ),
                            child: Text(
                              n.level,
                              style: TextStyle(
                                color: p.muted,
                                fontSize: OxType.micro,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (!soon) Stars(p: p, n: stars, size: 14),
                  Text(
                    n.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: soon ? p.muted : p.ink,
                      fontSize: OxType.small,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (soon)
                    Text(
                      'Soon',
                      style: TextStyle(color: p.faint, fontSize: OxType.micro),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
