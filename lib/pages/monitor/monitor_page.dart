import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../apps/providers/simulator_provider.dart';
import '../../apps/models/simulator_data.dart';
import '../../core/theme/app_theme_data.dart';
import '../../core/widgets/common/data_link_placeholder.dart';
import 'widgets/heading_compass.dart';
import 'widgets/landing_gear_card.dart';
import 'widgets/systems_status_card.dart';
import 'widgets/monitor_chart_card.dart';
import 'package:fl_chart/fl_chart.dart';

class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key});

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  final List<FlSpot> _gForceSpots = [];
  final List<FlSpot> _altitudeSpots = [];
  final List<FlSpot> _pressureSpots = [];
  double _time = 0;
  static const int _maxSpots = 300; // 5次/秒 * 60秒 = 300个点 (1分钟历史)

  // 用于检测变更以防过度绘制
  double? _lastAltitude;
  double? _lastGForce;
  bool _initialized = false;

  void _updateSpots(SimulatorData data) {
    if (!data.isConnected) return;

    // 如果数据和上一帧完全一样（且不是初始帧），则跳过，防止X轴空转
    if (_initialized &&
        data.altitude == _lastAltitude &&
        data.gForce == _lastGForce) {
      return;
    }

    _time += 0.2;
    _initialized = true;
    _lastAltitude = data.altitude;
    _lastGForce = data.gForce;

    // G-Force (保持 1.0 为默认)
    _gForceSpots.add(FlSpot(_time, data.gForce ?? 1.0));
    if (_gForceSpots.length > _maxSpots) _gForceSpots.removeAt(0);

    // Altitude (仅在有数据时记录，防止从0跳变)
    if (data.altitude != null) {
      _altitudeSpots.add(FlSpot(_time, data.altitude!));
      if (_altitudeSpots.length > _maxSpots) _altitudeSpots.removeAt(0);
    }

    // Air Pressure
    if (data.baroPressure != null) {
      _pressureSpots.add(FlSpot(_time, data.baroPressure!));
      if (_pressureSpots.length > _maxSpots) _pressureSpots.removeAt(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<SimulatorProvider>(
      builder: (context, simProvider, _) {
        if (!simProvider.isConnected) {
          return const DataLinkPlaceholder(
            title: '数据链路未就绪',
            description: '实时飞行监控系统需要激活的模拟器连接。目前由于缺少数据流，仪表盘已进入待机模式。',
          );
        }

        final data = simProvider.simulatorData;

        // 只有当数据真正更新或时间流逝时才更新点
        _updateSpots(data);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppThemeData.spacingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme, data),
                const SizedBox(height: AppThemeData.spacingLarge),

                // 顶层仪表行: 航向/系统状态 与 起落架 并行
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _buildCompassSection(theme, data),
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    bool isThreeColumn = constraints.maxWidth > 900;

                    if (isThreeColumn) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildGForceChart(data)),
                          const SizedBox(width: AppThemeData.spacingLarge),
                          Expanded(child: _buildAltitudeChart(theme, data)),
                          const SizedBox(width: AppThemeData.spacingLarge),
                          Expanded(child: _buildPressureChart(data)),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildGForceChart(data),
                          const SizedBox(height: AppThemeData.spacingLarge),
                          _buildAltitudeChart(theme, data),
                          const SizedBox(height: AppThemeData.spacingLarge),
                          _buildPressureChart(data),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme, SimulatorData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.masterWarning == true || data.masterCaution == true)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: AppThemeData.spacingMedium),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: (data.masterWarning == true ? Colors.red : Colors.orange)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(
                AppThemeData.borderRadiusMedium,
              ),
              border: Border.all(
                color: (data.masterWarning == true ? Colors.red : Colors.orange)
                    .withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  data.masterWarning == true ? Icons.warning : Icons.info,
                  color: data.masterWarning == true
                      ? Colors.red
                      : Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    data.masterWarning == true
                        ? '主警告 (MASTER WARNING) - 请检查警报面板'
                        : '主告警 (MASTER CAUTION) - 系统异常',
                    style: TextStyle(
                      color: data.masterWarning == true
                          ? Colors.red
                          : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '实时飞行监控',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  data.isConnected ? '正在接收来自模拟器的实时数据' : '模拟器未连接',
                  style: TextStyle(color: theme.hintColor),
                ),
              ],
            ),
            if (data.isConnected && data.isPaused == true)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pause, size: 16, color: Colors.orange),
                    const SizedBox(width: 4),
                    const Text(
                      '已暂停',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompassSection(ThemeData theme, SimulatorData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusLarge),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          const Text(
            '磁航向 (Magnetic Heading)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            width: double.infinity,
            child: HeadingCompass(heading: data.heading ?? 0),
          ),
          const SizedBox(height: 10),
          Text(
            '${(data.heading ?? 0).toStringAsFixed(0)}°',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGForceChart(SimulatorData data) {
    return MonitorChartCard(
      title: '重力监控 (G-Force)',
      value: '${data.gForce?.toStringAsFixed(2) ?? "1.00"} G',
      spots: _gForceSpots,
      color: Colors.orangeAccent,
      minY: 0,
      maxY: 2,
      currentTime: _time,
    );
  }

  Widget _buildAltitudeChart(ThemeData theme, SimulatorData data) {
    return MonitorChartCard(
      title: '高度趋势 (Altitude)',
      value: '${data.altitude?.toStringAsFixed(0) ?? "0"} FT',
      spots: _altitudeSpots,
      color: theme.colorScheme.primary,
      minY: MonitorChartCard.calculateMinY(_altitudeSpots, 100, defaultVal: 0),
      maxY: MonitorChartCard.calculateMaxY(
        _altitudeSpots,
        100,
        defaultVal: 100,
      ),
      currentTime: _time,
    );
  }

  Widget _buildPressureChart(SimulatorData data) {
    return MonitorChartCard(
      title: '大气压强 (Baro)',
      value: '${data.baroPressure?.toStringAsFixed(2) ?? "29.92"} inHg',
      spots: _pressureSpots,
      color: Colors.cyanAccent,
      minY: 28,
      maxY: 31,
      currentTime: _time,
    );
  }
}
