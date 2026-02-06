import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../apps/providers/simulator/simulator_provider.dart';
import '../../../core/theme/app_theme_data.dart';

class WelcomeCard extends StatelessWidget {
  const WelcomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<SimulatorProvider>(
      builder: (context, simProvider, _) {
        final isConnected = simProvider.isConnected;
        final aircraftTitle = simProvider.simulatorData.aircraftTitle;
        final isPaused = simProvider.simulatorData.isPaused ?? false;

        String title;
        String subtitle;
        Widget? statusIndicator;

        if (!isConnected) {
          title = '未连接模拟器！';
          subtitle = '等待建立数据链路...';
        } else if (isPaused) {
          title = '模拟器已暂停';
          subtitle = '检测到模拟器处于暂停状态 ($aircraftTitle)';
          statusIndicator = Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.yellow.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pause_circle_filled,
              color: Colors.yellow,
              size: 32,
            ),
          );
        } else {
          title = '飞行准备就绪';
          subtitle = aircraftTitle != null
              ? '当前机型: $aircraftTitle'
              : '等待识别机型...';
          statusIndicator = Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.greenAccent,
              size: 32,
            ),
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppThemeData.spacingLarge),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppThemeData.borderRadiusLarge),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (statusIndicator != null) statusIndicator,
                ],
              ),
              const SizedBox(height: AppThemeData.spacingSmall),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: AppThemeData.spacingLarge),
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '支持 MSFS 2020/2024 & X-Plane 11/12',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
