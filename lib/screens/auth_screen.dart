import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/app_state.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/web_ui.dart';

/// Web: components/Auth.js. Log in or sign up with a username, email or phone.
///
/// On success the screen closes itself, then [onAuthed] runs. The quiz gate uses it to
/// start the quiz the guest tried to open (web pendingQuiz).
class AuthScreen extends StatefulWidget {
  final AppState state;
  final OxPalette p;
  final VoidCallback? onAuthed;
  const AuthScreen({
    super.key,
    required this.state,
    required this.p,
    this.onAuthed,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _register = false;
  final _name = TextEditingController();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;
  // Synchronous guard: blocks repeat submits (double tap, Enter spam), as web inFlight.
  bool _inFlight = false;

  @override
  void dispose() {
    _name.dispose();
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_inFlight) return;
    // Browser-style "required" and minLength messages, as the web form shows them.
    final native = _nativeError();
    if (native != null) {
      setState(() => _error = native);
      return;
    }
    final s = widget.state;
    // Logging in loads the account's saved progress onto this device, replacing whatever
    // is here. Say so first when this device has progress of its own.
    if (!_register && s.hasLocalProgress) {
      final go = await confirmAction(
        context,
        message:
            'This device has progress that is not in an account. If your '
            "account already has saved progress, logging in replaces this device's "
            'progress with it.',
        confirmLabel: 'Log in',
      );
      if (!go || !mounted) return;
    }
    _inFlight = true;
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final err = _register
          ? await s.signUp(
              name: _name.text,
              identifier: _identifier.text,
              password: _password.text,
            )
          : await s.logIn(
              identifier: _identifier.text,
              password: _password.text,
            );
      if (!mounted) return;
      if (err != null) {
        setState(() {
          _error = err;
          _busy = false;
        });
        return;
      }
      Navigator.of(context).pop();
      widget.onAuthed?.call();
    } finally {
      _inFlight = false;
    }
  }

  String? _nativeError() {
    if (_register && _name.text.isEmpty) return 'Please fill out this field.';
    if (_identifier.text.isEmpty || _password.text.isEmpty) {
      return 'Please fill out this field.';
    }
    final len = _password.text.length;
    if (_register && len < 6) {
      return 'Please lengthen this text to 6 characters or more (you are currently using $len characters).';
    }
    return null;
  }

  InputDecoration _decoration(String hint) {
    final p = widget.p;
    final line = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: p.line),
    );
    return InputDecoration(
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
    );
  }

  Widget _seg(String label, bool active, VoidCallback onTap) {
    final p = widget.p;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9.6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? p.accent : p.surface,
            border: Border.all(color: active ? p.accent : p.line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: active ? p.accentInk : p.muted,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final brandStyle = TextStyle(
      fontSize: 28.8,
      fontWeight: FontWeight.w500,
      color: p.brand,
    );
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: WebButton(
                      p: p,
                      label: 'Close',
                      ghost: true,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                            fontSize: 28.8,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text('Vox', style: brandStyle),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _seg(
                        'Log in',
                        !_register,
                        () => setState(() => _register = false),
                      ),
                      const SizedBox(width: 8),
                      _seg(
                        'Sign up',
                        _register,
                        () => setState(() => _register = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_register)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: _name,
                        maxLength: 60,
                        autofillHints: const [AutofillHints.name],
                        textInputAction: TextInputAction.next,
                        style: TextStyle(color: p.ink),
                        decoration: _decoration('Name'),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: _identifier,
                      autofillHints: const [AutofillHints.username],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      style: TextStyle(color: p.ink),
                      decoration: _decoration('Username, email or phone'),
                    ),
                  ),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: [
                      _register
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    style: TextStyle(color: p.ink),
                    decoration: _decoration('Password (min 6 characters)'),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 14.4,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: WebButton(
                      p: p,
                      label: _busy
                          ? 'Please wait…'
                          : _register
                          ? 'Create account'
                          : 'Log in',
                      onPressed: _busy ? null : _submit,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the log in / sign up screen. [onAuthed] runs after a successful login.
Future<void> openAuth(
  BuildContext context,
  AppState state,
  OxPalette p, {
  VoidCallback? onAuthed,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AuthScreen(state: state, p: p, onAuthed: onAuthed),
    ),
  );
}

/// Web startQuiz: a guest who starts a quiz is asked to log in first, and the quiz
/// starts right after a successful login. Quiz start points should call this.
void guardQuiz(
  BuildContext context,
  AppState state,
  OxPalette p,
  VoidCallback startQuiz,
) {
  if (state.isSignedIn) {
    startQuiz();
    return;
  }
  openAuth(context, state, p, onAuthed: startQuiz);
}
