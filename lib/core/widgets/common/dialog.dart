import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum ConfirmDialogStyle { material, cupertino, glass, darkNeon }

Future<bool?> showAdvancedConfirmDialog({
  required BuildContext context,
  ConfirmDialogStyle style = ConfirmDialogStyle.material,
  required String title,
  required String content,
  IconData icon = Icons.help_outline,
  Color confirmColor = Colors.blue,
  String confirmText = 'Yes',
  String cancelText = 'Cancel',
}) {
  switch (style) {
    case ConfirmDialogStyle.cupertino:
      return showCupertinoConfirmDialog(
        context: context,
        title: title,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
      );
    case ConfirmDialogStyle.glass:
      return showGlassConfirmDialog(
        context: context,
        title: title,
        content: content,
        icon: icon,
        confirmColor: confirmColor,
        confirmText: confirmText,
        cancelText: cancelText,
      );
    case ConfirmDialogStyle.darkNeon:
      return showDarkNeonConfirmDialog(
        context: context,
        title: title,
        content: content,
        icon: icon,
        confirmText: confirmText,
        cancelText: cancelText,
      );
    default:
      return showMaterialConfirmDialog(
        context: context,
        title: title,
        content: content,
        icon: icon,
        confirmColor: confirmColor,
        confirmText: confirmText,
        cancelText: cancelText,
      );
  }
}

// Material 高级动画弹窗 (Android 推荐)
Future<bool?> showMaterialConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  required IconData icon,
  required Color confirmColor,
  required String confirmText,
  required String cancelText,
}) {
  final bool hasConfirm = confirmText.isNotEmpty;
  final bool hasCancel = cancelText.isNotEmpty;

  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: '',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, _, _) {
      final isDark = Theme.of(context).brightness == Brightness.dark;

      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 20),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 42, color: confirmColor),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500),
                ),
                if (hasConfirm || hasCancel) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (hasCancel)
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text(cancelText),
                          ),
                        ),
                      if (hasCancel && hasConfirm) const SizedBox(width: 8),
                      if (hasConfirm)
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: confirmColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text(confirmText),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, animation, _, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(animation),
          child: child,
        ),
      );
    },
  );
}

// Cupertino (iOS 原生风格)
Future<bool?> showCupertinoConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  required String confirmText,
  required String cancelText,
}) {
  final bool hasConfirm = confirmText.isNotEmpty;
  final bool hasCancel = cancelText.isNotEmpty;

  return showCupertinoDialog<bool>(
    context: context,
    builder: (_) => CupertinoAlertDialog(
      title: Text(title),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(content),
      ),
      actions: [
        if (hasCancel)
          CupertinoDialogAction(
            child: Text(cancelText),
            onPressed: () => Navigator.pop(context, false),
          ),
        if (hasCancel && hasConfirm) const SizedBox(width: 8),
        if (hasConfirm)
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(confirmText),
            onPressed: () => Navigator.pop(context, true),
          ),
      ],
    ),
  );
}

// Glassmorphism 毛玻璃高级感弹窗
Future<bool?> showGlassConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  required IconData icon,
  required Color confirmColor,
  required String confirmText,
  required String cancelText,
}) {
  final bool hasConfirm = confirmText.isNotEmpty;
  final bool hasCancel = cancelText.isNotEmpty;

  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black38,
    builder: (_) => Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 40, color: confirmColor),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    decoration: TextDecoration.none,
                  ),
                ),
                if (hasConfirm || hasCancel) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (hasCancel)
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(
                              cancelText,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                      if (hasCancel && hasConfirm) const SizedBox(width: 8),
                      if (hasConfirm)
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: confirmColor,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(confirmText),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// Dark + Neon 科技感弹窗
Future<bool?> showDarkNeonConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  required IconData icon,
  required String confirmText,
  required String cancelText,
}) {
  final bool hasConfirm = confirmText.isNotEmpty;
  final bool hasCancel = cancelText.isNotEmpty;

  return showGeneralDialog<bool>(
    context: context,
    barrierColor: Colors.black87,
    barrierDismissible: false,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, _, _) {
      return Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withValues(alpha: 0.4),
                blurRadius: 25,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.cyanAccent, size: 36),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                content,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  decoration: TextDecoration.none,
                ),
              ),
              if (hasConfirm || hasCancel) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (hasCancel)
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                          ),
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(
                            cancelText,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    if (hasCancel && hasConfirm) const SizedBox(width: 8),
                    if (hasConfirm)
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(confirmText),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    },
    transitionBuilder: (_, anim, _, child) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: child,
      );
    },
  );
}

// Loading 加载中弹窗 (毛玻璃)
void showLoadingDialog({
  required BuildContext context,
  String message = '正在加载数据...',
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black26,
    builder: (_) => Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: 200,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.normal,
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

void hideLoadingDialog(BuildContext context) {
  Navigator.of(context, rootNavigator: true).pop();
}
