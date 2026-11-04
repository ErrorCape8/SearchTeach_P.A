import 'dart:async';

import 'package:flutter/material.dart';

/// Compact role-colored notice that enters from the right side of the screen.
class RoleToast {
  RoleToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context, {
    required String message,
    required Color roleColor,
    Duration duration = const Duration(seconds: 4),
    IconData icon = Icons.info_outline_rounded,
  }) {
    _showContent(
      context,
      content: Text(message),
      roleColor: roleColor,
      duration: duration,
      icon: icon,
    );
  }

  static void showSnackBar(BuildContext context, SnackBar snackBar) {
    _showContent(
      context,
      content: snackBar.content,
      roleColor: Theme.of(context).colorScheme.primary,
      duration: snackBar.duration,
      action: snackBar.action,
    );
  }

  static void _showContent(
    BuildContext context, {
    required Widget content,
    required Color roleColor,
    required Duration duration,
    SnackBarAction? action,
    IconData icon = Icons.info_outline_rounded,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _timer?.cancel();
    _entry?.remove();
    final entry = OverlayEntry(
      builder: (overlayContext) {
        final availableWidth = MediaQuery.sizeOf(overlayContext).width - 32;
        return Positioned(
          top: MediaQuery.paddingOf(overlayContext).top + 82,
          left: 16,
          right: 16,
          child: Align(
            alignment: Alignment.topRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: availableWidth.clamp(0, 420).toDouble()),
              child: TweenAnimationBuilder<Offset>(
                tween: Tween<Offset>(
                  begin: const Offset(1.08, 0),
                  end: Offset.zero,
                ),
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutCubic,
                builder: (context, offset, child) => FractionalTranslation(
                  translation: offset,
                  child: child,
                ),
                child: Material(
                  color: Colors.white,
                  elevation: 12,
                  shadowColor: const Color(0x26000000),
                  borderRadius: BorderRadius.circular(14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE8EAF0)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: IntrinsicHeight(
                        child: Row(children: [
                          Container(width: 5, color: roleColor),
                          const SizedBox(width: 14),
                          Icon(icon, color: roleColor, size: 21),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              child: DefaultTextStyle.merge(
                                style: const TextStyle(
                                  color: Color(0xFF242936),
                                  fontSize: 13,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                                child: content,
                              ),
                            ),
                          ),
                          if (action != null)
                            TextButton(
                              onPressed: action.onPressed,
                              style: TextButton.styleFrom(
                                  foregroundColor: roleColor),
                              child: Text(action.label),
                            ),
                          const SizedBox(width: 14),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(duration, () {
      if (entry.mounted) entry.remove();
      if (identical(_entry, entry)) _entry = null;
    });
  }
}
