import 'package:flutter/material.dart';

void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red.shade700,
      duration: const Duration(seconds: 4),
    ),
  );
}

void showInfo(BuildContext context, String message,
    {SnackBarAction? action, Duration? duration}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      action: action,
      duration: duration ?? const Duration(seconds: 4),
    ),
  );
}
