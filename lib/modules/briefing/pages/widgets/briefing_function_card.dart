import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme_data.dart';

/// 简报功能入口卡片
/// 用于主页面展示功能入口 (如“生成简报”、“历史记录”)
class BriefingFunctionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const BriefingFunctionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppThemeData.spacingSmall),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        child: Container(
          padding: const EdgeInsets.all(AppThemeData.spacingMedium),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(
              AppThemeData.borderRadiusMedium,
            ),
            border: Border.all(
              color: AppThemeData.getBorderColor(theme).withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // 图标背景区域
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppThemeData.borderRadiusSmall,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: AppThemeData.spacingMedium),
              // 文字描述区域
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              // 向右箭头
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
