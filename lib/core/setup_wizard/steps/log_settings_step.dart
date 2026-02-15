import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../wizard_step.dart';
import '../wizard_controller.dart';
import '../../localization/localization_keys.dart';
import '../../services/localization_service.dart';

class LogSettingsStep extends WizardStep {
  @override
  String get id => 'log_settings';

  @override
  String get title => LocalizationKeys.logSettingsStep;

  @override
  int get priority => 20;

  @override
  bool canGoNext() => true;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WizardController>();
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.description_outlined,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocalizationKeys.enableLogging.tr(context),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      LocalizationKeys.enableLoggingDesc.tr(context),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Switch(
                value: controller.logEnabled,
                onChanged: controller.setLogEnabled,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          LocalizationKeys.logSettingsHint.tr(context),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
