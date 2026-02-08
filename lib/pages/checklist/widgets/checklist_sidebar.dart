import 'package:flutter/material.dart';
import '../../../apps/models/flight_checklist.dart';
import '../../../apps/providers/checklist_provider.dart';
import '../../../core/theme/app_theme_data.dart';

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
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppThemeData.spacingLarge,
            ),
            child: Text(
              '飞行阶段',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: AppThemeData.spacingMedium),
          Expanded(
            child: ListView.builder(
              itemCount: ChecklistPhase.values.length,
              itemBuilder: (context, index) {
                final phase = ChecklistPhase.values[index];
                final isSelected = provider.currentPhase == phase;
                final progress = provider.getPhaseProgress(phase);

                return _PhaseNavItem(
                  phase: phase,
                  isSelected: isSelected,
                  progress: progress,
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

class _PhaseNavItem extends StatelessWidget {
  final ChecklistPhase phase;
  final bool isSelected;
  final double progress;
  final VoidCallback onTap;

  const _PhaseNavItem({
    required this.phase,
    required this.isSelected,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(
              AppThemeData.borderRadiusMedium,
            ),
          ),
          child: Row(
            children: [
              Icon(
                phase.icon,
                color: isSelected
                    ? theme.colorScheme.primary
                    : AppThemeData.getTextColor(theme, isPrimary: false),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  phase.label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : AppThemeData.getTextColor(theme),
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              if (progress > 0)
                Container(
                  width: 32,
                  height: 32,
                  padding: const EdgeInsets.all(4),
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    backgroundColor: theme.colorScheme.outline.withValues(
                      alpha: 0.1,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress == 1.0
                          ? theme.colorScheme.primary
                          : theme.colorScheme.secondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
