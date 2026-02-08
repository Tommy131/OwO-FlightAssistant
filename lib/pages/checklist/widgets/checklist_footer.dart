import 'package:flutter/material.dart';
import '../../../apps/providers/checklist_provider.dart';
import '../../../core/theme/app_theme_data.dart';

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
            onPressed: () => provider.resetCurrentPhase(),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重置本阶段'),
          ),
          const SizedBox(width: AppThemeData.spacingSmall),
          ElevatedButton.icon(
            onPressed: () => provider.resetAll(),
            icon: const Icon(Icons.layers_clear, size: 18),
            label: const Text('重置全部'),
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
