import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/widgets/common/dialog.dart';
import '../../../../core/widgets/common/snack_bar.dart';
import '../../providers/checklist_provider.dart';
import '../../localization/checklist_localization_keys.dart';

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
          TextButton.icon(
            onPressed: () async {
              try {
                final count = await provider.importFromFilePicker();
                if (count > 0) {
                  SnackBarHelper.showSuccess(
                    context,
                    ChecklistLocalizationKeys.importSuccess.tr(context),
                  );
                  return;
                }
                if (count == 0) {
                  SnackBarHelper.showWarning(
                    context,
                    ChecklistLocalizationKeys.importFailed.tr(context),
                  );
                }
              } catch (_) {
                SnackBarHelper.showError(
                  context,
                  ChecklistLocalizationKeys.importFailed.tr(context),
                );
              }
            },
            icon: const Icon(Icons.file_open, size: 18),
            label: Text(ChecklistLocalizationKeys.importFile.tr(context)),
          ),
          const SizedBox(width: AppThemeData.spacingSmall),
          TextButton.icon(
            onPressed: () async {
              try {
                final result = await provider.exportToFilePicker();
                if (result == 1) {
                  SnackBarHelper.showSuccess(
                    context,
                    ChecklistLocalizationKeys.exportSuccess.tr(context),
                  );
                  return;
                }
                if (result == -1) {
                  SnackBarHelper.showWarning(
                    context,
                    ChecklistLocalizationKeys.exportFailed.tr(context),
                  );
                }
              } catch (_) {
                SnackBarHelper.showError(
                  context,
                  ChecklistLocalizationKeys.exportFailed.tr(context),
                );
              }
            },
            icon: const Icon(Icons.file_download, size: 18),
            label: Text(ChecklistLocalizationKeys.exportFile.tr(context)),
          ),
          const SizedBox(width: AppThemeData.spacingSmall),
          TextButton.icon(
            onPressed: () async {
              try {
                final count = await provider.reloadFromDirectory(
                  fallbackToBuiltIn: true,
                );
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
                SnackBarHelper.showError(
                  context,
                  ChecklistLocalizationKeys.refreshFailed.tr(context),
                );
              }
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(ChecklistLocalizationKeys.refresh.tr(context)),
          ),
          const SizedBox(width: AppThemeData.spacingSmall),
          TextButton.icon(
            onPressed: () async {
              final confirm = await showAdvancedConfirmDialog(
                context: context,
                title: ChecklistLocalizationKeys.resetPhaseConfirmTitle.tr(
                  context,
                ),
                content: ChecklistLocalizationKeys.resetPhaseConfirmContent.tr(
                  context,
                ),
                icon: Icons.warning_amber_rounded,
              );
              if (confirm != true) return;
              provider.resetCurrentPhase();
              SnackBarHelper.showSuccess(
                context,
                ChecklistLocalizationKeys.resetPhaseSuccess.tr(context),
              );
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(ChecklistLocalizationKeys.resetPhase.tr(context)),
          ),
          const SizedBox(width: AppThemeData.spacingSmall),
          ElevatedButton.icon(
            onPressed: () async {
              final confirm = await showAdvancedConfirmDialog(
                context: context,
                title: ChecklistLocalizationKeys.resetAllConfirmTitle.tr(
                  context,
                ),
                content: ChecklistLocalizationKeys.resetAllConfirmContent.tr(
                  context,
                ),
                icon: Icons.warning_amber_rounded,
              );
              if (confirm != true) return;
              provider.resetAll();
              SnackBarHelper.showSuccess(
                context,
                ChecklistLocalizationKeys.resetAllSuccess.tr(context),
              );
            },
            icon: const Icon(Icons.layers_clear, size: 18),
            label: Text(ChecklistLocalizationKeys.resetAll.tr(context)),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
          ),
        ],
      ),
    );
  }
}
