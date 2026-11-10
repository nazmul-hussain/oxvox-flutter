import 'package:flutter/material.dart';

/// Asks a yes/no question before something that cannot be undone.
/// True only when the user taps [confirmLabel]; Cancel, back and tapping outside are all "no".
Future<bool> confirmAction(
  BuildContext context, {
  required String message,
  String confirmLabel = 'OK',
  String cancelLabel = 'Cancel',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}
