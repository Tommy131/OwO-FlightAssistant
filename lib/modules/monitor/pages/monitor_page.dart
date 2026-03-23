import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme_data.dart';
import '../providers/monitor_provider.dart';
import 'widgets/compass_section.dart';
import 'widgets/landing_gear_card.dart';
import 'widgets/monitor_charts.dart';
import 'widgets/monitor_header.dart';
import 'widgets/monitor_no_connection_page.dart';
import 'widgets/systems_status_card.dart';

/// 监控模块主页面
///
/// 根据模拟器连接状态决定显示内容：
/// - **已连接**：显示完整仪表盘（标题栏、罗盘、系统状态、起落架、图表）
/// - **未连接**：显示 [MonitorNoConnectionPage] 引导用户建立连接
///
/// 本页面仅负责布局调度，各区域细节由独立的子组件承担：
/// | 子组件 | 职责 |
/// |--------|------|
/// | [MonitorHeader] | 标题、副标题、暂停徽章、警告横幅 |
/// | [CompassSection] | 磁航向罗盘 |
/// | [SystemsStatusCard] | 各系统状态行列表 |
/// | [LandingGearCard] | 起落架指示灯与手柄动画 |
/// | [MonitorCharts] | G力、高度、气压折线图 |
/// | [MonitorNoConnectionPage] | 无连接占位引导页 |
class MonitorPage extends StatelessWidget {
  const MonitorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MonitorProvider>(
      builder: (context, provider, _) {
        // 未连接时显示引导占位页，不渲染仪表盘
        if (!provider.isConnected) {
          return const MonitorNoConnectionPage();
        }

        final data = provider.data;

        // 已连接：渲染完整仪表盘布局
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppThemeData.spacingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 页面顶部：标题栏（含警告横幅、暂停状态）
                MonitorHeader(data: data),
                const SizedBox(height: AppThemeData.spacingLarge),

                // 中部双列区域：左列（罗盘 + 系统状态），右列（起落架）
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          // 磁航向罗盘卡片
                          CompassSection(data: data),
                          const SizedBox(height: AppThemeData.spacingLarge),
                          // 飞行系统状态列表卡片
                          SystemsStatusCard(data: data),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppThemeData.spacingLarge),
                    // 起落架状态仪表卡片（右列单独占满）
                    Expanded(child: LandingGearCard(data: data)),
                  ],
                ),
                const SizedBox(height: AppThemeData.spacingLarge),

                // 底部：实时图表区域（G力、高度、气压，宽屏三列/窄屏堆叠）
                MonitorCharts(provider: provider),
              ],
            ),
          ),
        );
      },
    );
  }
}
