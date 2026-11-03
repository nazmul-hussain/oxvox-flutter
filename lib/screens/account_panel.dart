import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/app_state.dart';
import '../widgets/web_ui.dart';
import 'auth_screen.dart';

/// Web: components/Account.js. Guest card, or the signed-in account (profile, password, delete).
///
/// Embed it in the Settings > Profile section: `AccountPanel(state: s, p: p)`.
class AccountPanel extends StatefulWidget {
  final AppState state;
  final OxPalette p;
  const AccountPanel({super.key, required this.state, required this.p});

  @override
  State<AccountPanel> createState() => _AccountPanelState();
}

class _AccountPanelState extends State<AccountPanel> {
  final _name = TextEditingController();
  final _login = TextEditingController();
  final _currentPw = TextEditingController();
  final _nextPw = TextEditingController();
  final _deletePw = TextEditingController();
  bool _confirmDelete = false;
  bool _editing = false;
  bool _busy = false;
  String _statusText = '';
  bool _statusOk = true;

  @override
  void initState() {
    super.initState();
    _name.text = widget.state.accountName ?? '';
    _login.text = widget.state.accountUsername ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _login.dispose();
    _currentPw.dispose();
    _nextPw.dispose();
    _deletePw.dispose();
    super.dispose();
  }

  void _setStatus(String text, {bool ok = true}) {
    setState(() {
      _statusText = text;
      _statusOk = ok;
    });
  }

  /// Web run(): busy while the action runs, then the done text or the error text.
  Future<void> _run(
    Future<String?> Function() action,
    String doneText, {
    VoidCallback? after,
  }) async {
    setState(() {
      _busy = true;
      _statusText = '';
    });
    final err = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) {
      _setStatus(doneText);
      if (after != null) setState(after);
    } else {
      _setStatus(err, ok: false);
    }
  }

  void _saveProfile() {
    if (_name.text.trim().isEmpty || _login.text.trim().isEmpty) {
      _setStatus('Please fill out this field.', ok: false);
      return;
    }
    _run(
      () =>
          widget.state.updateProfile(name: _name.text, identifier: _login.text),
      'Profile saved.',
      after: () {
        _name.text = widget.state.accountName ?? '';
        _login.text = widget.state.accountUsername ?? '';
      },
    );
  }

  void _changePassword() {
    if (_currentPw.text.isEmpty || _nextPw.text.isEmpty) {
      _setStatus('Please fill out this field.', ok: false);
      return;
    }
    if (_nextPw.text.length < 6) {
      final len = _nextPw.text.length;
      _setStatus(
        'Please lengthen this text to 6 characters or more (you are currently using $len characters).',
        ok: false,
      );
      return;
    }
    _run(
      () => widget.state.changePassword(
        current: _currentPw.text,
        next: _nextPw.text,
      ),
      'Password changed.',
      after: () {
        _currentPw.clear();
        _nextPw.clear();
      },
    );
  }

  void _deleteAccount() {
    _run(
      () => widget.state.deleteAccount(password: _deletePw.text),
      'Account deleted.',
      after: () {
        _deletePw.clear();
        _confirmDelete = false;
      },
    );
  }

  Future<void> _logOut() async {
    await widget.state.logOut();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) =>
          s.isSignedIn ? _signedIn(context) : _guest(context),
    );
  }

  Widget _guest(BuildContext context) {
    final p = widget.p;
    return WebCard(
      p: p,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account',
            style: TextStyle(fontWeight: FontWeight.w500, color: p.ink),
          ),
          const SizedBox(height: 4),
          Text(
            'You are not logged in. Progress is not saved. Log in to save it on every device and to take quizzes.',
            style: TextStyle(color: p.muted, fontSize: 13.6),
          ),
          const SizedBox(height: 12),
          WebButton(
            p: p,
            label: 'Log in or sign up',
            onPressed: () => openAuth(context, widget.state, p),
          ),
        ],
      ),
    );
  }

  Widget _signedIn(BuildContext context) {
    final p = widget.p;
    final s = widget.state;
    final name = s.accountName ?? '';
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().substring(0, 1).toUpperCase();
    return WebCard(
      p: p,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.brand,
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: p.ink,
                      ),
                    ),
                    Text(
                      s.accountUsername ?? '',
                      style: TextStyle(color: p.muted, fontSize: 13.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _fullWidth(
            _outlineButton(
              _editing ? 'Close profile' : 'Update profile',
              () => setState(() {
                _editing = !_editing;
                _statusText = '';
              }),
              icon: _editing ? Icons.close : Icons.edit_outlined,
            ),
          ),
          const SizedBox(height: 10),
          _fullWidth(
            _outlineButton(
              'Log out',
              _busy ? null : _logOut,
              icon: Icons.logout,
            ),
          ),
          if (_editing) ...[const SizedBox(height: 12), _editPanel()],
          if (_statusText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _statusText,
                style: TextStyle(
                  color: _statusOk ? p.green : const Color(0xFFDC2626),
                  fontSize: 14.4,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: p.line)),
            ),
            child: _confirmDelete ? _deleteConfirm() : _deleteStart(),
          ),
        ],
      ),
    );
  }

  Widget _editPanel() {
    final p = widget.p;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Profile',
            style: TextStyle(fontWeight: FontWeight.w500, color: p.ink),
          ),
          const SizedBox(height: 8),
          _field(_name, 'Name', maxLength: 60),
          const SizedBox(height: 8),
          _field(_login, 'Username, email or phone'),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: WebButton(
              p: p,
              label: 'Save profile',
              onPressed: _busy ? null : _saveProfile,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Change password',
            style: TextStyle(fontWeight: FontWeight.w500, color: p.ink),
          ),
          const SizedBox(height: 8),
          _field(_currentPw, 'Current password', obscure: true),
          const SizedBox(height: 8),
          _field(_nextPw, 'New password (min 6 characters)', obscure: true),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: WebButton(
              p: p,
              label: 'Change password',
              onPressed: _busy ? null : _changePassword,
            ),
          ),
        ],
      ),
    );
  }

  Widget _deleteStart() => _fullWidth(
    _outlineButton(
      'Delete account',
      () => setState(() => _confirmDelete = true),
      danger: true,
      icon: Icons.delete_outline,
    ),
  );

  Widget _deleteConfirm() {
    final p = widget.p;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'This deletes your login and all saved progress. It cannot be undone.',
          style: TextStyle(color: p.ink, fontSize: 14.4),
        ),
        const SizedBox(height: 8),
        _field(_deletePw, 'Enter your password to confirm', obscure: true),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _outlineButton(
              'Delete my account',
              _busy || _deletePw.text.isEmpty ? null : _deleteAccount,
              danger: true,
              filled: true,
            ),
            _outlineButton('Cancel', () {
              setState(() {
                _confirmDelete = false;
                _deletePw.clear();
              });
            }),
          ],
        ),
      ],
    );
  }

  Widget _fullWidth(Widget child) =>
      SizedBox(width: double.infinity, child: child);

  /// .btn.ghost.account-btn (and .danger, and filled danger for the final delete).
  Widget _outlineButton(
    String label,
    VoidCallback? onPressed, {
    bool danger = false,
    bool filled = false,
    IconData? icon,
  }) {
    final p = widget.p;
    final fg = danger ? p.red : p.accent;
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label),
            ],
          );
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      backgroundColor: WidgetStatePropertyAll(filled ? p.red : p.surface),
      foregroundColor: WidgetStatePropertyAll(filled ? Colors.white : fg),
      side: WidgetStatePropertyAll(BorderSide(color: fg)),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w500, fontSize: 14.4),
      ),
    );
    return OutlinedButton(onPressed: onPressed, style: style, child: child);
  }

  Widget _field(
    TextEditingController c,
    String hint, {
    bool obscure = false,
    int? maxLength,
  }) {
    final p = widget.p;
    final line = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: p.line),
    );
    return TextField(
      controller: c,
      obscureText: obscure,
      maxLength: maxLength,
      onChanged: (_) => setState(() {}),
      style: TextStyle(color: p.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: p.faint),
        isDense: true,
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12.8,
          vertical: 11.2,
        ),
        border: line,
        enabledBorder: line,
        focusedBorder: line.copyWith(borderSide: BorderSide(color: p.accent)),
        counterText: '',
      ),
    );
  }
}
