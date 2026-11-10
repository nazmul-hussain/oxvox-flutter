import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/app_state.dart';
import 'auth_screen.dart';
import 'listen_screen.dart';
import 'settings_screen.dart';
import 'today_screen.dart';
import 'topics_screen.dart';
import 'welcome_screen.dart';
import 'words_screen.dart';

/// Web: fixed header (brand + avatar) and a 4-item bottom nav: Today, Words, Topics, Listen.
class HomeShell extends StatefulWidget {
  final AppState state;
  const HomeShell({super.key, required this.state});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  String _view = 'today';
  // Bumped on every navigation tap, so a page always opens from the top (even when tapping the current tab).
  int _navTick = 0;
  // Lets Settings ask about a changed study plan before we navigate away from it.
  final _settingsKey = GlobalKey<SettingsScreenState>();

  Future<void> _go(String v) async {
    if (_view == 'settings' && v != 'settings') {
      await _settingsKey.currentState?.confirmPlanChange();
      if (!mounted) return;
    }
    setState(() {
      _view = v;
      _navTick++;
    });
  }

  // Set when the study plan is saved from the level test, so the welcome modal closes.
  bool _welcomeHidden = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final p = paletteFor(resolveThemeId(s.themeSetting));
    final navActive = _view == 'settings' ? '' : _view;

    Widget page = switch (_view) {
      'words' => WordsScreen(state: s, p: p),
      'topics' => TopicsScreen(state: s, p: p),
      'listen' => ListenScreen(state: s, p: p),
      'settings' => SettingsScreen(
        key: _settingsKey,
        state: s,
        p: p,
        onClose: () => _go('words'),
      ),
      _ => TodayScreen(state: s, p: p, go: (v) => _go(v)),
    };

    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _Header(
                  p: p,
                  onLogin: () => openAuth(context, s, p),
                  onBrand: () => _go('today'),
                  onAvatar: () => _go('settings'),
                  active: _view == 'settings',
                  name: s.accountName,
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: SingleChildScrollView(
                        // Keyed per screen so every navigation starts at the top.
                        key: ValueKey('$_view-$_navTick'),
                        padding: EdgeInsets.fromLTRB(
                          0,
                          _view == 'today' ? 0 : 8,
                          0,
                          76,
                        ),
                        // Today's hero is full-width (web: negative margin); other pages get the 16px side padding.
                        child: _view == 'today'
                            ? page
                            : Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: page,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Web Welcome: first-visit setup, shown until onboarded.
          if (!s.onboarded && !_welcomeHidden)
            WelcomeScreen(
              state: s,
              p: p,
              onOpenPlan: () {
                // After the level test: close the welcome and open the study plan in Settings.
                setState(() {
                  _welcomeHidden = true;
                  _view = 'settings';
                  _navTick++;
                });
                s.setOnboarded();
              },
            ),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        p: p,
        active: navActive,
        onTap: (v) => _go(v),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final OxPalette p;
  final VoidCallback onBrand;
  final VoidCallback onAvatar;
  final VoidCallback onLogin;
  final bool active;
  final String? name;
  const _Header({
    required this.p,
    required this.onBrand,
    required this.onAvatar,
    required this.onLogin,
    required this.active,
    this.name,
  });

  @override
  Widget build(BuildContext context) {
    final initial = (name?.trim().isNotEmpty == true)
        ? name!.trim()[0].toUpperCase()
        : '?';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: p.headerBg,
        boxShadow: [
          BoxShadow(color: p.shadow, offset: const Offset(0, 1), blurRadius: 3),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: onBrand,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: p.brand,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Ox',
                    style: TextStyle(
                      color: p.onBrand,
                      fontSize: OxType.appName,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  'Vox',
                  style: TextStyle(
                    color: p.brand,
                    fontSize: OxType.appName,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          name == null
              ? _LoginChip(p: p, onPressed: onLogin)
              : InkWell(
                  onTap: onAvatar,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.brand,
                      border: Border.all(
                        color: active ? p.ink : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: p.onBrand,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final OxPalette p;
  final String active;
  final ValueChanged<String> onTap;
  const _BottomNav({
    required this.p,
    required this.active,
    required this.onTap,
  });

  static const _items = [
    ('today', 'Today', Icons.calendar_today_outlined, Icons.calendar_today),
    ('words', 'Words', Icons.menu_book_outlined, Icons.menu_book),
    ('topics', 'Topics', Icons.auto_awesome_outlined, Icons.auto_awesome),
    ('listen', 'Listen', Icons.headphones_outlined, Icons.headphones),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54 + MediaQuery.paddingOf(context).bottom,
      padding: EdgeInsets.fromLTRB(
        6,
        4,
        6,
        4 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.line)),
        boxShadow: [
          BoxShadow(
            color: p.shadow,
            offset: const Offset(0, -6),
            blurRadius: 18,
          ),
        ],
      ),
      child: Row(
        children: [
          for (final (id, label, icon, activeIcon) in _items)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onTap(id),
                child: Container(
                  decoration: BoxDecoration(
                    color: active == id ? p.accentSoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        active == id ? activeIcon : icon,
                        size: 19,
                        color: active == id ? p.accent : p.muted,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10.2,
                          fontWeight: active == id
                              ? FontWeight.w500
                              : FontWeight.w400,
                          color: active == id ? p.accent : p.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LoginChip extends StatelessWidget {
  final OxPalette p;
  final VoidCallback onPressed;
  const _LoginChip({required this.p, required this.onPressed});

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: p.accent,
      side: BorderSide(color: p.accent),
      shape: const StadiumBorder(),
    ),
    child: const Text('Log in', style: TextStyle(fontWeight: FontWeight.w400)),
  );
}
