import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../apps/models/flight_checklist.dart';
import '../../../apps/providers/checklist_provider.dart';
import '../../../apps/providers/simulator/simulator_provider.dart';
import '../../../core/theme/app_theme_data.dart';

class ChecklistHeader extends StatelessWidget {
  final ChecklistProvider provider;

  const ChecklistHeader({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
}
