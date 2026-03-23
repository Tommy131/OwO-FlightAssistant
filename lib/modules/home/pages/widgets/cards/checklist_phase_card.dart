import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/services/localization_service.dart';
import '../../../../../core/theme/app_theme_data.dart';
import '../../../../checklist/providers/checklist_provider.dart';
import '../../../../common/models/common_models.dart';
import '../../../localization/home_localization_keys.dart';

/// 检查单阶段卡片，显示当前所处飞行阶段及该阶段检查单完成进度
class ChecklistPhaseCard extends StatelessWidget {
  const ChecklistPhaseCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checklistProvider = context.watch<ChecklistProvider>();
    final checklistPhase = checklistProvider.currentPhase;

    // 将 checklist 模块的阶段数据适配为 home 模块数据模型
    final phase = HomeChecklistPhase(
      labelKey: checklistPhase.labelKey,
      icon: checklistPhase.icon,
    );
    final progress = checklistProvider.getPhaseProgress(checklistPhase);
    // 若未选择机型则展示空状态
    final showEmpty = checklistProvider.selectedAircraft == null;

    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(color: AppThemeData.getBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行：阶段图标 + 标签
          Row(
            children: [
              Icon(phase.icon, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  HomeLocalizationKeys.checklistTitle.tr(context),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 当前阶段名称或空状态文本
          Text(
            showEmpty
                ? HomeLocalizationKeys.checklistEmpty.tr(context)
                : phase.labelKey.tr(context),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const Spacer(),
          const SizedBox(height: 12),
          // 进度条及百分比
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  // 空状态时使用不定进度动画
                  value: showEmpty ? null : progress,
                  backgroundColor: theme.colorScheme.outline.withValues(
                    alpha: 0.1,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                showEmpty ? '--' : '${(progress * 100).toInt()}%',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
