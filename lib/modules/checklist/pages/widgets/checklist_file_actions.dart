import 'package:flutter/material.dart';
import '../../../../../core/services/localization_service.dart';
import '../../../../../core/widgets/common/snack_bar.dart';
import '../../providers/checklist_provider.dart';
import '../../localization/checklist_localization_keys.dart';

/// 检查单文件操作按钮组（导入 / 导出 / 刷新）
///
/// 职责唯一：仅处理文件 I/O 类操作的 UI 与交互反馈，
/// 不涉及检查单条目重置等状态操作（见 [ChecklistResetActions]）。
class ChecklistFileActions extends StatelessWidget {
  final ChecklistProvider provider;

  const ChecklistFileActions({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── 导入
        TextButton.icon(
          onPressed: () => _onImport(context),
          icon: const Icon(Icons.file_open, size: 18),
          label: Text(ChecklistLocalizationKeys.importFile.tr(context)),
        ),
        const SizedBox(width: 8),
        // ── 导出
        TextButton.icon(
          onPressed: () => _onExport(context),
          icon: const Icon(Icons.file_download, size: 18),
          label: Text(ChecklistLocalizationKeys.exportFile.tr(context)),
        ),
        const SizedBox(width: 8),
        // ── 刷新目录
        TextButton.icon(
          onPressed: () => _onRefresh(context),
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(ChecklistLocalizationKeys.refresh.tr(context)),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 事件处理
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _onImport(BuildContext context) async {
    try {
      final count = await provider.importFromFilePicker();
      if (!context.mounted) return;
      if (count > 0) {
        SnackBarHelper.showSuccess(
          context,
          ChecklistLocalizationKeys.importSuccess.tr(context),
        );
      } else if (count == 0) {
        SnackBarHelper.showWarning(
          context,
          ChecklistLocalizationKeys.importFailed.tr(context),
        );
      }
      // count == -1 表示用户取消，不弹提示
    } catch (_) {
      if (!context.mounted) return;
      SnackBarHelper.showError(
        context,
        ChecklistLocalizationKeys.importFailed.tr(context),
      );
    }
  }

  Future<void> _onExport(BuildContext context) async {
    try {
      final result = await provider.exportToFilePicker();
      if (!context.mounted) return;
      if (result == 1) {
        SnackBarHelper.showSuccess(
          context,
          ChecklistLocalizationKeys.exportSuccess.tr(context),
        );
      } else if (result == -1) {
        SnackBarHelper.showWarning(
          context,
          ChecklistLocalizationKeys.exportFailed.tr(context),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      SnackBarHelper.showError(
        context,
        ChecklistLocalizationKeys.exportFailed.tr(context),
      );
    }
  }

  Future<void> _onRefresh(BuildContext context) async {
    try {
      final count = await provider.reloadFromDirectory(fallbackToBuiltIn: true);
      if (!context.mounted) return;
      if (count > 0) {
        final message = ChecklistLocalizationKeys.refreshSuccess
            .tr(context)
            .replaceAll('{}', count.toString());
        SnackBarHelper.showSuccess(context, message);
      } else {
        SnackBarHelper.showWarning(
          context,
          ChecklistLocalizationKeys.refreshEmpty.tr(context),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      SnackBarHelper.showError(
        context,
        ChecklistLocalizationKeys.refreshFailed.tr(context),
      );
    }
  }
}
