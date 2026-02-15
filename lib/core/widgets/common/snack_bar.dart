import 'package:flutter/material.dart';
import '../../theme/app_theme_data.dart';
import '../../localization/localization_keys.dart';
import '../../services/localization_service.dart';

enum SnackBarType { info, success, warning, error }

/// 全局通知/提示条辅助工具
class SnackBarHelper {
  /// 显示成功提示
  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
  }) {
    _show(context, message, title: title, type: SnackBarType.success);
  }

  /// 显示信息提示
  static void showInfo(BuildContext context, String message, {String? title}) {
    _show(context, message, title: title, type: SnackBarType.info);
  }

  /// 显示警告提示
  static void showWarning(
    BuildContext context,
    String message, {
    String? title,
  }) {
    _show(context, message, title: title, type: SnackBarType.warning);
  }

  /// 显示错误提示
  static void showError(BuildContext context, String message, {String? title}) {
    _show(context, message, title: title, type: SnackBarType.error);
  }

  static void _show(
    BuildContext context,
    String message, {
    String? title,
    required SnackBarType type,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 根据类型确定颜色和图标
    Color color;
    IconData icon;
    String defaultTitle;

    switch (type) {
      case SnackBarType.success:
        color = const Color(0xFF00B894);
        icon = Icons.check_circle_outline;
        defaultTitle = '成功';
        break;
      case SnackBarType.info:
        color = theme.primaryColor;
        icon = Icons.info_outline;
        defaultTitle = '提示';
        break;
      case SnackBarType.warning:
        color = const Color(0xFFF1C40F);
        icon = Icons.warning_amber_outlined;
        defaultTitle = '警告';
        break;
      case SnackBarType.error:
        color = const Color(0xFFE74C30);
        icon = Icons.error_outline;
        defaultTitle = '错误';
        break;
    }

    // 计算前景色（文字和图标）
    final bool useDarkText =
        AppThemeData.getContrastColor(color) == Colors.black87;
    final Color foregroundColor = useDarkText ? Colors.black87 : Colors.white;
    final Color secondaryForegroundColor = useDarkText
        ? Colors.black54
        : Colors.white.withValues(alpha: 0.8);

    final snackBar = SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24), // 增加边距，使其更像悬浮组件
      content: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          // 使用色彩饱和度较高的背景，强化提示感
          color: color,
          borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 2),
            ),
          ],
          // 增加一个微弱的内发光效果，提升高级感
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.2),
            width: 0.5,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // 图标区域：带有一个轻微的背景容器
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: foregroundColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title ?? defaultTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: foregroundColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          message,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: secondaryForegroundColor,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 关闭按钮
                  Material(
                    color: Colors.transparent,
                    child: Semantics(
                      button: true,
                      label: LocalizationKeys.close.tr(context),
                      child: ExcludeSemantics(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: foregroundColor.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
