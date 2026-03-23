import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../../../core/services/localization_service.dart';
import '../../models/flight_checklist.dart';

/// 侧边栏单个飞行阶段导航条目
///
/// 展示阶段图标、名称，以及已完成进度的环形指示器。
/// 通过 [isSelected] 高亮当前激活阶段，点击后通过 [onTap] 回调切换阶段。
class PhaseNavItem extends StatelessWidget {
  final ChecklistPhase phase;

  /// 是否为当前激活阶段
  final bool isSelected;

  /// 阶段完成进度（0.0 ~ 1.0），为 0 时不显示环形指示器
  final double progress;

  /// 点击回调
  final VoidCallback onTap;

  const PhaseNavItem({
    super.key,
    required this.phase,
    required this.isSelected,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(
              AppThemeData.borderRadiusMedium,
            ),
          ),
          child: Row(
            children: [
              // 阶段图标
              Icon(
                phase.icon,
                color: isSelected
                    ? theme.colorScheme.primary
                    : AppThemeData.getTextColor(theme, isPrimary: false),
                size: 20,
              ),
              const SizedBox(width: 12),
              // 阶段名称
              Expanded(
                child: Text(
                  phase.labelKey.tr(context),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : AppThemeData.getTextColor(theme),
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              // 进度环形指示器（仅在有进度时显示）
              if (progress > 0)
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      backgroundColor: theme.colorScheme.outline.withValues(
                        alpha: 0.1,
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress == 1.0
                            ? theme.colorScheme.primary
                            : theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
