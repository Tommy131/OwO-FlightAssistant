import 'package:flutter/material.dart';
import '../../../../../core/services/localization_service.dart';
import '../../../../../core/widgets/common/dialog.dart';
import '../../../../../core/widgets/common/snack_bar.dart';
import '../../providers/checklist_provider.dart';
import '../../localization/checklist_localization_keys.dart';

/// 检查单重置操作按钮组（重置本阶段 / 重置全部）
///
/// 职责唯一：仅处理检查单状态重置的 UI 与交互确认，
/// 不涉及文件 I/O 操作（见 [ChecklistFileActions]）。
class ChecklistResetActions extends StatelessWidget {
  final ChecklistProvider provider;

  const ChecklistResetActions({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        // ── 重置本阶段
        TextButton.icon(
          onPressed: () => _onResetPhase(context),
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(ChecklistLocalizationKeys.resetPhase.tr(context)),
        ),
        const SizedBox(width: 8),
        // ── 重置全部（已标红强调危险操作）
        ElevatedButton.icon(
          onPressed: () => _onResetAll(context),
          icon: const Icon(Icons.layers_clear, size: 18),
          label: Text(ChecklistLocalizationKeys.resetAll.tr(context)),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 事件处理（含二次确认弹窗）
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _onResetPhase(BuildContext context) async {
    final confirm = await showAdvancedConfirmDialog(
      context: context,
      title: ChecklistLocalizationKeys.resetPhaseConfirmTitle.tr(context),
      content: ChecklistLocalizationKeys.resetPhaseConfirmContent.tr(context),
      icon: Icons.warning_amber_rounded,
    );
    if (confirm != true) return;
    provider.resetCurrentPhase();
    if (!context.mounted) return;
    SnackBarHelper.showSuccess(
      context,
      ChecklistLocalizationKeys.resetPhaseSuccess.tr(context),
    );
  }

  Future<void> _onResetAll(BuildContext context) async {
    final confirm = await showAdvancedConfirmDialog(
      context: context,
      title: ChecklistLocalizationKeys.resetAllConfirmTitle.tr(context),
      content: ChecklistLocalizationKeys.resetAllConfirmContent.tr(context),
      icon: Icons.warning_amber_rounded,
    );
    if (confirm != true) return;
    provider.resetAll();
    if (!context.mounted) return;
    SnackBarHelper.showSuccess(
      context,
      ChecklistLocalizationKeys.resetAllSuccess.tr(context),
    );
  }
}
