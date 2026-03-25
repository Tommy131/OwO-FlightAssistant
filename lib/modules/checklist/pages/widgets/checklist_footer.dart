import 'package:flutter/material.dart';
import '../../../../../core/services/localization_service.dart';
import '../../../../../core/widgets/common/dialog.dart';
import '../../../../../core/widgets/common/snack_bar.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/checklist_localization_keys.dart';
import '../../providers/checklist_provider.dart';
import 'checklist_file_actions.dart';
import 'checklist_reset_actions.dart';

/// 检查单页面底部工具栏
///
/// 作为组合容器，将文件操作 [ChecklistFileActions] 与
/// 重置操作 [ChecklistResetActions] 水平排列展示。
/// 本身不再持有具体业务逻辑。
class ChecklistFooter extends StatefulWidget {
  final ChecklistProvider provider;

  const ChecklistFooter({super.key, required this.provider});

  @override
  State<ChecklistFooter> createState() => _ChecklistFooterState();
}

class _ChecklistFooterState extends State<ChecklistFooter> {
  bool _showMoreActions = false;

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 670;
          if (!isCompact) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ChecklistFileActions(provider: widget.provider),
                const SizedBox(width: AppThemeData.spacingSmall),
                ChecklistResetActions(provider: widget.provider),
              ],
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRect(
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  offset: _showMoreActions ? Offset.zero : const Offset(0, 0.2),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _showMoreActions ? 1 : 0,
                    child: _showMoreActions
                        ? Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(
                              bottom: AppThemeData.spacingSmall,
                            ),
                            padding: const EdgeInsets.all(
                              AppThemeData.spacingSmall,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withValues(
                                alpha: 0.9,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppThemeData.borderRadiusMedium,
                              ),
                              border: Border.all(
                                color: AppThemeData.getBorderColor(theme),
                              ),
                            ),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _onImport(context),
                                  icon: const Icon(Icons.file_open, size: 18),
                                  label: Text(
                                    ChecklistLocalizationKeys.importFile.tr(
                                      context,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _onExport(context),
                                  icon: const Icon(
                                    Icons.file_download,
                                    size: 18,
                                  ),
                                  label: Text(
                                    ChecklistLocalizationKeys.exportFile.tr(
                                      context,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _onRefresh(context),
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: Text(
                                    ChecklistLocalizationKeys.refresh.tr(
                                      context,
                                    ),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _onResetAll(context),
                                  icon: const Icon(
                                    Icons.layers_clear,
                                    size: 18,
                                  ),
                                  label: Text(
                                    ChecklistLocalizationKeys.resetAll.tr(
                                      context,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.error,
                                    foregroundColor: theme.colorScheme.onError,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _onResetPhase(context),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(
                        ChecklistLocalizationKeys.resetPhase.tr(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppThemeData.spacingSmall),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showMoreActions = !_showMoreActions;
                        });
                      },
                      icon: Icon(
                        _showMoreActions
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                        size: 18,
                      ),
                      label: Text(ChecklistLocalizationKeys.more.tr(context)),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _onImport(BuildContext context) async {
    setState(() {
      _showMoreActions = false;
    });
    try {
      final count = await widget.provider.importFromFilePicker();
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
    } catch (_) {
      if (!context.mounted) return;
      SnackBarHelper.showError(
        context,
        ChecklistLocalizationKeys.importFailed.tr(context),
      );
    }
  }

  Future<void> _onExport(BuildContext context) async {
    setState(() {
      _showMoreActions = false;
    });
    try {
      final result = await widget.provider.exportToFilePicker();
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
    setState(() {
      _showMoreActions = false;
    });
    try {
      final count = await widget.provider.reloadFromDirectory(
        fallbackToBuiltIn: true,
      );
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

  Future<void> _onResetPhase(BuildContext context) async {
    final confirm = await showAdvancedConfirmDialog(
      context: context,
      title: ChecklistLocalizationKeys.resetPhaseConfirmTitle.tr(context),
      content: ChecklistLocalizationKeys.resetPhaseConfirmContent.tr(context),
      icon: Icons.warning_amber_rounded,
    );
    if (confirm != true) return;
    widget.provider.resetCurrentPhase();
    if (!context.mounted) return;
    SnackBarHelper.showSuccess(
      context,
      ChecklistLocalizationKeys.resetPhaseSuccess.tr(context),
    );
  }

  Future<void> _onResetAll(BuildContext context) async {
    setState(() {
      _showMoreActions = false;
    });
    final confirm = await showAdvancedConfirmDialog(
      context: context,
      title: ChecklistLocalizationKeys.resetAllConfirmTitle.tr(context),
      content: ChecklistLocalizationKeys.resetAllConfirmContent.tr(context),
      icon: Icons.warning_amber_rounded,
    );
    if (confirm != true) return;
    widget.provider.resetAll();
    if (!context.mounted) return;
    SnackBarHelper.showSuccess(
      context,
      ChecklistLocalizationKeys.resetAllSuccess.tr(context),
    );
  }
}
