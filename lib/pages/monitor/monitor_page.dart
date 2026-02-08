import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../apps/providers/simulator/simulator_provider.dart';
import '../../core/theme/app_theme_data.dart';
import '../../core/widgets/common/data_link_placeholder.dart';
import 'widgets/compass_section.dart';
import 'widgets/landing_gear_card.dart';
import 'widgets/monitor_charts.dart';
import 'widgets/monitor_header.dart';
import 'widgets/systems_status_card.dart';

class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key});

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  @override
  Widget build(BuildContext context) {
    return Consumer<SimulatorProvider>(
      builder: (context, simProvider, _) {
        if (!simProvider.isConnected) {
          return const DataLinkPlaceholder(
            title: '数据链路未就绪',
            description: '实时飞行监控系统需要激活的模拟器连接。目前由于缺少数据流，仪表盘已进入待机模式。',
          );
        }

        final data = simProvider.simulatorData;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppThemeData.spacingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MonitorHeader(data: data),
                const SizedBox(height: AppThemeData.spacingLarge),

                // 顶层仪表行: 航向/系统状态 与 起落架 并行
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          CompassSection(data: data),
                          const SizedBox(height: AppThemeData.spacingLarge),
                          SystemsStatusCard(data: data),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppThemeData.spacingLarge),
                    Expanded(child: LandingGearCard(data: data)),
                  ],
                ),

                const SizedBox(height: AppThemeData.spacingLarge),

                // 图表网格
                MonitorCharts(simProvider: simProvider),
              ],
            ),
          ),
        );
      },
    );
  }
}
