import 'package:fl_chart/fl_chart.dart';
import '../models/monitor_chart_data.dart';

/// 图表时序数据缓冲管理器
///
/// 负责维护监控页面三条折线图（G力、高度、大气压）的滚动历史数据点。
/// 每帧接收最新采样值后追加至各序列末尾，并在超出最大容量时自动裁剪旧数据，
/// 从而实现固定时间窗口的滚动显示效果。
///
/// 该类被 [MonitorProvider] 持有，不直接与 Flutter Widget 交互。
class MonitorChartBuffer {
  /// 图表展示的最大历史帧数（超出后裁剪最旧的数据点）
  static const int maxPoints = 60;

  /// 当前时间轴计数（每帧 +1，用于 X 轴坐标）
  double _chartTime = 0;

  /// G 力历史数据点列表
  List<FlSpot> _gForceSpots = const [];

  /// 高度历史数据点列表
  List<FlSpot> _altitudeSpots = const [];

  /// 大气压历史数据点列表
  List<FlSpot> _pressureSpots = const [];

  /// 追加一帧采样值并更新内部缓冲区
  ///
  /// [gForce] - 当前 G 力值（默认 1.0）
  /// [altitude] - 当前飞行高度（默认 0）
  /// [pressure] - 当前大气压（默认 29.92 inHg）
  void append({
    required double gForce,
    required double altitude,
    required double pressure,
  }) {
    _chartTime += 1;
    _gForceSpots = _appendSpot(_gForceSpots, FlSpot(_chartTime, gForce));
    _altitudeSpots = _appendSpot(_altitudeSpots, FlSpot(_chartTime, altitude));
    _pressureSpots = _appendSpot(_pressureSpots, FlSpot(_chartTime, pressure));
  }

  /// 生成当前缓冲区快照，供 UI 层读取
  MonitorChartData buildSnapshot() {
    return MonitorChartData(
      gForceSpots: _gForceSpots,
      altitudeSpots: _altitudeSpots,
      pressureSpots: _pressureSpots,
      currentTime: _chartTime,
    );
  }

  /// 向序列末尾追加数据点，若超出最大容量则裁剪最旧端
  List<FlSpot> _appendSpot(List<FlSpot> source, FlSpot spot) {
    final next = <FlSpot>[...source, spot];
    if (next.length <= maxPoints) return next;
    return next.sublist(next.length - maxPoints);
  }
}
