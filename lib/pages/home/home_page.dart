import 'package:flutter/material.dart';

import '../../core/theme/app_theme_data.dart';
import 'widgets/welcome_card.dart';
import 'widgets/simulator_connection_card.dart';
import 'widgets/checklist_phase_card.dart';
import 'widgets/flight_number_card.dart';
import 'widgets/flight_data_dashboard.dart';

/// 首页 - 模拟器数据仪表盘
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppThemeData.spacingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 欢迎卡片
            const WelcomeCard(),

            const SizedBox(height: AppThemeData.spacingLarge),

            // 航班号设置
            const FlightNumberCard(),

            const SizedBox(height: AppThemeData.spacingLarge),

            // 模拟器连接状态和检查阶段
            _buildStatusRow(context, theme),

            const SizedBox(height: AppThemeData.spacingLarge),

            // 飞行数据仪表盘
            const FlightDataDashboard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context, ThemeData theme) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          // 模拟器连接状态
          Expanded(child: SimulatorConnectionCard()),
          SizedBox(width: AppThemeData.spacingMedium),
          // 当前检查阶段
          Expanded(child: ChecklistPhaseCard()),
        ],
      ),
    );
  }
}
