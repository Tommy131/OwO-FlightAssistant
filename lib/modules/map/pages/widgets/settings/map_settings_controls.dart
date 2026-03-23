import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme_data.dart';

/// 警报开关标签（胶囊样式）
///
/// 在设置页"飞行警报"区块中，每条可配置的告警项目都以此标签形式呈现，
/// 支持选中高亮动画和禁用状态。
class AlertToggleTag extends StatelessWidget {
  /// 标签显示文字（经 `tr(context)` 翻译的本地化字符串）
  final String label;

  /// 是否已选中（启用该告警类型）
  final bool selected;

  /// 是否可交互（当全局警报被禁用时为 false）
  final bool enabled;

  /// 点击回调
  final VoidCallback onTap;

  const AlertToggleTag({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary;
    // 选中时边框高亮，未选中时使用半透明边框
    final borderColor = selected
        ? activeColor
        : theme.colorScheme.outline.withValues(alpha: 0.5);
    // 禁用时文字变灰
    final textColor = enabled
        ? (selected ? activeColor : theme.colorScheme.onSurface)
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
          color: selected
              ? activeColor.withValues(alpha: enabled ? 0.12 : 0.06)
              : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 选中/未选中图标
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: textColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: textColor,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单选条目组件（带边框和选中动画）
///
/// 用于自动计时器的"启动条件"和"停止条件"单选列表，
/// 每个选项以圆角卡片形式展示，选中时高亮边框和背景色。
class SelectionTile extends StatelessWidget {
  /// 是否已选中
  final bool selected;

  /// 显示文字
  final String label;

  /// 左侧图标
  final IconData icon;

  /// 点击回调（无需 enabled 参数，计时器区块整体不区分禁用态）
  final VoidCallback onTap;

  const SelectionTile({
    super.key,
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 选中时边框高亮，未选中时使用次要轮廓颜色
    final borderColor = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppThemeData.spacingSmall,
          vertical: AppThemeData.spacingSmall,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
          border: Border.all(color: borderColor),
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.06)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? theme.colorScheme.primary : null,
            ),
            const SizedBox(width: AppThemeData.spacingSmall),
            Expanded(child: Text(label)),
            // 右侧选中/未选中指示图标
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? theme.colorScheme.primary : null,
            ),
          ],
        ),
      ),
    );
  }
}
