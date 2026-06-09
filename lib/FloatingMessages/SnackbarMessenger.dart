import 'package:flutter/material.dart';

class SnackbarMessenger {
  static const int success = 0;
  static const int neutral = 1;
  static const int failed = 2;

  void showSnackbar(BuildContext context, int type, String message) {
    if (!context.mounted) return;
    Color backgroundColor;
    IconData icon;

    switch (type) {
      case success:
        backgroundColor = Colors.green.shade700;
        icon = Icons.check_circle_outline;
        break;
      case failed:
        backgroundColor = Colors.red.shade700;
        icon = Icons.error_outline;
        break;
      case neutral:
      default:
        backgroundColor = const Color(0xFF323232);
        icon = Icons.info_outline;
        break;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
