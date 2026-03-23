import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../../../core/widgets/common/snack_bar.dart';
import '../../localization/briefing_localization_keys.dart';
import '../../providers/briefing_provider.dart';

/// 简报操作面板 (导入/导出按钮组)
class BriefingActions extends StatelessWidget {
  final BriefingProvider provider;

  const BriefingActions({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppThemeData.spacingSmall,
      runSpacing: AppThemeData.spacingSmall,
      children: [
        // 导入按钮
        TextButton.icon(
          onPressed: () => _handleImport(context),
          icon: const Icon(Icons.file_upload, size: 18),
          label: Text(BriefingLocalizationKeys.importFile.tr(context)),
        ),
        // 导出按钮
        TextButton.icon(
          onPressed: () => _handleExport(context),
          icon: const Icon(Icons.file_download, size: 18),
          label: Text(BriefingLocalizationKeys.exportFile.tr(context)),
        ),
      ],
    );
  }

  /// 处理文件导入逻辑
  Future<void> _handleImport(BuildContext context) async {
    try {
      final count = await provider.importFromFilePicker();
      if (!context.mounted) return;
      if (count > 0) {
        SnackBarHelper.showSuccess(
          context,
          BriefingLocalizationKeys.importSuccess.tr(context),
        );
      } else {
        SnackBarHelper.showWarning(
          context,
          BriefingLocalizationKeys.importFailed.tr(context),
        );
      }
    } catch (_) {
      if (context.mounted) {
        SnackBarHelper.showError(
          context,
          BriefingLocalizationKeys.importFailed.tr(context),
        );
      }
    }
  }

  /// 处理批量导出逻辑
  Future<void> _handleExport(BuildContext context) async {
    try {
      final result = await provider.exportToFilePicker();
      if (!context.mounted) return;
      if (result == 1) {
        SnackBarHelper.showSuccess(
          context,
          BriefingLocalizationKeys.exportSuccess.tr(context),
        );
      } else if (result == -1) {
        SnackBarHelper.showWarning(
          context,
          BriefingLocalizationKeys.exportFailed.tr(context),
        );
      }
    } catch (_) {
      if (context.mounted) {
        SnackBarHelper.showError(
          context,
          BriefingLocalizationKeys.exportFailed.tr(context),
        );
      }
    }
  }
}
