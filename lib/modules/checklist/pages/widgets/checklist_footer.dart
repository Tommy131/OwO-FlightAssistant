import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../providers/checklist_provider.dart';
import 'checklist_file_actions.dart';
import 'checklist_reset_actions.dart';

/// 检查单页面底部工具栏
///
/// 作为组合容器，将文件操作 [ChecklistFileActions] 与
/// 重置操作 [ChecklistResetActions] 水平排列展示。
/// 本身不再持有具体业务逻辑。
class ChecklistFooter extends StatelessWidget {
  final ChecklistProvider provider;

  const ChecklistFooter({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppThemeData.borderRadiusLarge),
          bottomRight: Radius.circular(AppThemeData.borderRadiusLarge),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 文件 I/O 操作组（导入 / 导出 / 刷新）
          ChecklistFileActions(provider: provider),
          const SizedBox(width: AppThemeData.spacingSmall),
          // 状态重置操作组（重置本阶段 / 重置全部）
          ChecklistResetActions(provider: provider),
        ],
      ),
    );
  }
}
