import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../apps/models/flight_checklist.dart';
import '../../apps/providers/checklist_provider.dart';
import '../../apps/providers/simulator_provider.dart';
import '../../core/theme/app_theme_data.dart';

class ChecklistPage extends StatelessWidget {
  const ChecklistPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<ChecklistProvider>();
    final selectedAircraft = provider.selectedAircraft;

    if (selectedAircraft == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        children: [
          // 左侧阶段导航
          _buildPhaseSidebar(context, theme, provider),

          // 右侧检查单内容
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(AppThemeData.spacingLarge),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(
                  AppThemeData.borderRadiusLarge,
                ),
                border: Border.all(color: AppThemeData.getBorderColor(theme)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildChecklistHeader(context, theme, provider),
                  const Divider(height: 1),
                  Expanded(child: _buildItemsList(context, theme, provider)),
                  _buildFooter(context, theme, provider),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseSidebar(
    BuildContext context,
    ThemeData theme,
    ChecklistProvider provider,
  ) {
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

  Widget _buildChecklistHeader(
    BuildContext context,
    ThemeData theme,
    ChecklistProvider provider,
  ) {
    final aircraft = provider.selectedAircraft!;

    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      child: Row(
        children: [
          Icon(
            aircraft.family == AircraftFamily.a320
                ? Icons.airplanemode_active
                : Icons.flight,
            color: theme.colorScheme.primary,
            size: 32,
          ),
          const SizedBox(width: AppThemeData.spacingMedium),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(aircraft.name, style: theme.textTheme.displaySmall),
              const SizedBox(height: 4),
              Text(
                '当前阶段: ${provider.currentPhase.label}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          const Spacer(),
          // 模拟器连接状态和暂停提示
          Consumer<SimulatorProvider>(
            builder: (context, simProvider, _) {
              final isConnected = simProvider.isConnected;
              final isPaused = simProvider.simulatorData.isPaused == true;
              final statusColor = isConnected ? Colors.green : Colors.grey;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 暂停状态
                  if (isPaused && isConnected)
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.pause_circle,
                            size: 16,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '模拟器已暂停',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // 连接状态
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isConnected ? Icons.link : Icons.link_off,
                          size: 16,
                          color: statusColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          simProvider.statusText,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(
    BuildContext context,
    ThemeData theme,
    ChecklistProvider provider,
  ) {
    final aircraft = provider.selectedAircraft!;
    ChecklistSection? currentSection;
    try {
      currentSection = aircraft.sections.firstWhere(
        (s) => s.phase == provider.currentPhase,
      );
    } catch (e) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.checklist_rtl,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            Text('该机型尚无此阶段数据', style: theme.textTheme.bodyLarge),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      itemCount: currentSection.items.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppThemeData.spacingSmall),
      itemBuilder: (context, index) {
        final item = currentSection!.items[index];
        return _ChecklistItemTile(
          item: item,
          onTap: () => provider.toggleItem(item.id),
        );
      },
    );
  }

  Widget _buildFooter(
    BuildContext context,
    ThemeData theme,
    ChecklistProvider provider,
  ) {
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

class _ChecklistItemTile extends StatelessWidget {
  final ChecklistItem item;
  final VoidCallback onTap;

  const _ChecklistItemTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: item.isChecked
              ? theme.colorScheme.primary.withValues(alpha: 0.05)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
          border: Border.all(
            color: item.isChecked
                ? theme.colorScheme.primary.withValues(alpha: 0.3)
                : AppThemeData.getBorderColor(theme),
          ),
        ),
        child: Row(
          children: [
            AnimatedScale(
              scale: item.isChecked ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                item.isChecked
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: item.isChecked
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                item.task,
                style: theme.textTheme.bodyLarge?.copyWith(
                  decoration: item.isChecked
                      ? TextDecoration.lineThrough
                      : null,
                  color: item.isChecked
                      ? AppThemeData.getTextColor(theme, isPrimary: false)
                      : AppThemeData.getTextColor(theme),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.response,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
