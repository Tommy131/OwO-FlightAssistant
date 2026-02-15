import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/persistence_service.dart';
import '../wizard_step.dart';
import '../wizard_controller.dart';
import '../../localization/localization_keys.dart';
import '../../services/localization_service.dart';
import 'dart:io';

/// 配置确认步骤
class SummaryStep extends WizardStep {
  SummaryStep();

  @override
  String get id => 'summary';

  @override
  String get title => LocalizationKeys.summaryStep;

  @override
  int get priority => 1000; // 总结步骤始终最后

  @override
  bool canGoNext() => true;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WizardController>();
    final summaryItems = _collectSummaryItems(context, controller);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              LocalizationKeys.configSummary.tr(context),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          LocalizationKeys.configCompleted
              .tr(context)
              .replaceFirst('{}', controller.currentStep.toString()),
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 32),
        Expanded(
          child: ListView.separated(
            itemCount: summaryItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final item = summaryItems[index];
              return _buildSummaryCard(context, item);
            },
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.green.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  LocalizationKeys.finishSetupHint.tr(context),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 智能收集所有步骤的配置摘要
  List<_SummaryItem> _collectSummaryItems(
    BuildContext context,
    WizardController controller,
  ) {
    final items = <_SummaryItem>[];

    // 遍历所有已完成的步骤（不包括当前的 Summary 步骤）
    for (int i = 0; i < controller.currentStep; i++) {
      final step = controller.getStepAt(i);
      final stepTitle = step.title.tr(context);

      // 获取步骤的配置摘要
      final summary = step.getSummary();

      if (summary != null && summary.isNotEmpty) {
        items.add(
          _SummaryItem(
            stepTitle: stepTitle,
            icon: _getIconForStep(step.id),
            configurations: summary,
          ),
        );
      } else {
        // 智能推断配置内容
        final inferredConfig = _inferStepConfiguration(
          context,
          step,
          controller,
        );
        if (inferredConfig.isNotEmpty) {
          items.add(
            _SummaryItem(
              stepTitle: stepTitle,
              icon: _getIconForStep(step.id),
              configurations: inferredConfig,
            ),
          );
        }
      }
    }

    return items;
  }

  /// 智能推断步骤配置
  Map<String, String> _inferStepConfiguration(
    BuildContext context,
    WizardStep step,
    WizardController controller,
  ) {
    switch (step.id) {
      case 'language_selection':
        final languages = LocalizationService().supportedLanguages;
        final selected = languages.firstWhere(
          (l) => l['code'] == controller.languageCode,
          orElse: () => {'name': 'Unknown'},
        );
        return {LocalizationKeys.language.tr(context): selected['name']!};
      case 'storage_path':
        final path = controller.selectedPath;
        if (path != null) {
          final finalPath = PersistenceService.getProcessedRootPath(path);
          final dir = Directory(finalPath);
          final pathName = dir.path.split(Platform.pathSeparator).last;
          return {
            LocalizationKeys.originalSelection.tr(context): path,
            LocalizationKeys.finalStorage.tr(context): finalPath,
            LocalizationKeys.directoryName.tr(context): pathName,
            LocalizationKeys.pathType.tr(context): _getPathType(context, path),
          };
        }
        return {};
      case 'log_settings':
        return {
          LocalizationKeys.logging.tr(context): controller.logEnabled
              ? LocalizationKeys.enabled.tr(context)
              : LocalizationKeys.disabled.tr(context),
        };
      default:
        return {};
    }
  }

  /// 获取路径类型描述
  String _getPathType(BuildContext context, String path) {
    if (path.contains('Documents')) return LocalizationKeys.docsDir.tr(context);
    if (path.contains('AppData')) {
      return LocalizationKeys.appDataDir.tr(context);
    }
    if (path.contains('Desktop')) return LocalizationKeys.desktop.tr(context);
    if (path.contains('Downloads')) {
      return LocalizationKeys.downloadsDir.tr(context);
    }
    return LocalizationKeys.customPath.tr(context);
  }

  /// 根据步骤索引获取图标
  IconData _getIconForStep(String stepId) {
    switch (stepId) {
      case 'language_selection':
        return Icons.language;
      case 'storage_path':
        return Icons.folder_open;
      case 'log_settings':
        return Icons.description_outlined;
      default:
        return Icons.settings;
    }
  }

  /// 构建配置摘要卡片
  Widget _buildSummaryCard(BuildContext context, _SummaryItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                item.stepTitle,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...item.configurations.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// 配置摘要项
class _SummaryItem {
  final String stepTitle;
  final IconData icon;
  final Map<String, String> configurations;

  _SummaryItem({
    required this.stepTitle,
    required this.icon,
    required this.configurations,
  });
}
