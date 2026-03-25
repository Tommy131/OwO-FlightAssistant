import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme_data.dart';

/// 主要飞行参数单格数据卡片，用于展示一个带图标、标签、数值的数据块
class DataCard extends StatelessWidget {
  /// 卡片图标
  final IconData icon;

  /// 参数标签文本
  final String label;

  /// 主数值
  final String value;

  /// 可选副数值（如马赫数）
  final String? subValue;

  /// 主题色
  final Color color;
  final bool compactRow;

  const DataCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.subValue,
    required this.color,
    this.compactRow = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (compactRow) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppThemeData.spacingMedium,
          vertical: AppThemeData.spacingSmall,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.end,
            ),
            if (subValue != null) ...[
              const SizedBox(width: 8),
              Text(
                subValue!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.end,
              ),
            ],
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          if (subValue != null) ...[
            const SizedBox(height: 2),
            Text(
              subValue!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
