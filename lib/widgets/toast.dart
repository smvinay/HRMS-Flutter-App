import 'package:flutter/material.dart';

import '../main.dart';
import 'AnimatedToast.dart';

class AppToast {
  static OverlayEntry? _overlayEntry;

  static void show(String message, {bool isError = false}) {
    final context = navigatorKey.currentContext;

    if (context == null) return;

    if (_overlayEntry != null) {
      _overlayEntry!.remove();
    }

    final overlay = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return AnimatedToast(
          message: message,
          isError: isError,
          onDismiss: () {
            _overlayEntry?.remove();
            _overlayEntry = null;
          },
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }
}