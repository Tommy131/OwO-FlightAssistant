import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme_data.dart';

/// 设置页通用卡片组件
///
/// 每个功能配置区块（如"本机机场"、"飞行警报"、"自动计时器"）
/// 均使用此卡片作为容器，统一头部样式（图标 + 标题 + 副标题）。
class SettingsSectionCard extends StatelessWidget {
  /// 头部图标
  final IconData icon;

  /// 卡片标题（粗体）
  final String title;

  /// 卡片副标题（小字说明）
  final String subtitle;

  /// 卡片内容区
  final Widget child;

  const SettingsSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：图标 + 标题 + 副标题
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppThemeData.borderRadiusSmall,
                    ),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: AppThemeData.spacingSmall),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            // 内容区
            child,
          ],
        ),
      ),
    );
  }
}

/// 设置卡片内的分组标题
///
/// 用于在设置项之间插入加粗小标题，区分不同子功能区域（如"启动条件"、"停止条件"）。
class SettingsGroupTitle extends StatelessWidget {
  /// 分组标题文字
  final String title;

  const SettingsGroupTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
