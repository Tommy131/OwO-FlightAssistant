import 'package:fl_chart/fl_chart.dart';

/// 监控模块图表数据模型
///
/// 存储用于实时折线图渲染的历史数据点集合，
/// 包括 G 力、高度与大气压的时间序列数据。
class MonitorChartData {
  /// G 力历史数据点列表（X 轴为时间戳，Y 轴为 G 值）
  final List<FlSpot> gForceSpots;

  /// 高度历史数据点列表（X 轴为时间戳，Y 轴为 FT）
  final List<FlSpot> altitudeSpots;

  /// 大气压历史数据点列表（X 轴为时间戳，Y 轴为 inHg）
  final List<FlSpot> pressureSpots;

  /// 当前时间戳（用于图表 X 轴范围计算）
  final double currentTime;

  const MonitorChartData({
    required this.gForceSpots,
    required this.altitudeSpots,
    required this.pressureSpots,
    required this.currentTime,
  });

  /// 创建空白图表数据（初始状态）
  factory MonitorChartData.empty() {
    return const MonitorChartData(
      gForceSpots: [],
      altitudeSpots: [],
      pressureSpots: [],
      currentTime: 0,
    );
  }
}
