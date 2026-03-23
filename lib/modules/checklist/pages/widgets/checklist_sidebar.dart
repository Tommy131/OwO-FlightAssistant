import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../../../core/services/localization_service.dart';
import '../../models/flight_checklist.dart';
import '../../providers/checklist_provider.dart';
import '../../localization/checklist_localization_keys.dart';
import 'phase_nav_item.dart';

/// 检查单侧边栏
///
/// 显示所有飞行阶段列表，用户可通过点击切换当前阶段。
/// 每个阶段条目的渲染逻辑已拆分至 [PhaseNavItem]。
class ChecklistSidebar extends StatelessWidget {
  final ChecklistProvider provider;

  const ChecklistSidebar({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 240,
      padding: const EdgeInsets.symmetric(vertical: AppThemeData.spacingLarge),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: AppThemeData.getBorderColor(theme)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 侧边栏标题
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppThemeData.spacingLarge,
            ),
            child: Text(
              ChecklistLocalizationKeys.sidebarTitle.tr(context),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: AppThemeData.spacingMedium),
          // 阶段列表
          Expanded(
            child: ListView.builder(
              itemCount: ChecklistPhase.values.length,
              itemBuilder: (context, index) {
                final phase = ChecklistPhase.values[index];
                return PhaseNavItem(
                  phase: phase,
                  isSelected: provider.currentPhase == phase,
                  progress: provider.getPhaseProgress(phase),
                  onTap: () => provider.setPhase(phase),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
