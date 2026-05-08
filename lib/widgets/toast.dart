import 'package:flutter/material.dart';
import '../main.dart';
import 'AnimatedToast.dart';

class AppToast {
  static OverlayEntry? _overlayEntry;

  static void show(String message, {bool isError = false}) {
    final context = navigatorKey.currentContext;
    final overlayState = navigatorKey.currentState?.overlay;

    if (context == null || overlayState == null) {
      debugPrint("Toast context or overlay is null");
      return;
    }

    _overlayEntry?.remove();
    _overlayEntry = null;

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

    overlayState.insert(_overlayEntry!);
  }
}