import 'monitor_chart_data.dart';

/// 监控模块飞行数据快照模型
///
/// 封装某一时刻从模拟器采集到的完整飞行状态信息，
/// 包括连接状态、告警状态、各系统仪表读数以及图表数据。
class MonitorData {
  /// 模拟器是否已连接
  final bool isConnected;

  /// 模拟器是否处于暂停状态
  final bool? isPaused;

  /// 主警告（MASTER WARNING）是否激活
  final bool? masterWarning;

  /// 主告警（MASTER CAUTION）是否激活
  final bool? masterCaution;

  /// 磁航向（单位：度，0–360）
  final double? heading;

  /// 停机刹车是否已启用
  final bool? parkingBrake;

  /// 应答机工作状态描述
  final String? transponderState;

  /// 应答机编码（如 1200、7700 等）
  final String? transponderCode;

  /// 襟翼当前位置标签（如 "FLAP 5"）
  final String? flapsLabel;

  /// 襟翼展开比例（0.0 = 收起，1.0 = 全展开）
  final double? flapsDeployRatio;

  /// 减速板当前状态标签
  final String? speedBrakeLabel;

  /// 减速板是否展开
  final bool? speedBrake;

  /// 发动机 1 火警是否激活
  final bool? fireWarningEngine1;

  /// 发动机 2 火警是否激活
  final bool? fireWarningEngine2;

  /// APU 火警是否激活
  final bool? fireWarningAPU;

  /// 前起落架收放比例（0.0 = 收起，1.0 = 放下）
  final double? noseGearDown;

  /// 左主起落架收放比例
  final double? leftGearDown;

  /// 右主起落架收放比例
  final double? rightGearDown;

  /// 当前重力加速度（G 值）
  final double? gForce;

  /// 当前飞行高度（单位：英尺）
  final double? altitude;

  /// 当前大气压（单位：inHg）
  final double? baroPressure;

  /// 当前帧的图表历史数据
  final MonitorChartData chartData;

  const MonitorData({
    required this.isConnected,
    required this.chartData,
    this.isPaused,
    this.masterWarning,
    this.masterCaution,
    this.heading,
    this.parkingBrake,
    this.transponderState,
    this.transponderCode,
    this.flapsLabel,
    this.flapsDeployRatio,
    this.speedBrakeLabel,
    this.speedBrake,
    this.fireWarningEngine1,
    this.fireWarningEngine2,
    this.fireWarningAPU,
    this.noseGearDown,
    this.leftGearDown,
    this.rightGearDown,
    this.gForce,
    this.altitude,
    this.baroPressure,
  });

  /// 创建初始空白数据（未连接状态）
  factory MonitorData.empty() {
    return MonitorData(isConnected: false, chartData: MonitorChartData.empty());
  }
}
