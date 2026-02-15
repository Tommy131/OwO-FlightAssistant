import 'package:fl_chart/fl_chart.dart';

class MonitorChartData {
  final List<FlSpot> gForceSpots;
  final List<FlSpot> altitudeSpots;
  final List<FlSpot> pressureSpots;
  final double currentTime;

  const MonitorChartData({
    required this.gForceSpots,
    required this.altitudeSpots,
    required this.pressureSpots,
    required this.currentTime,
  });

  factory MonitorChartData.empty() {
    return const MonitorChartData(
      gForceSpots: [],
      altitudeSpots: [],
      pressureSpots: [],
      currentTime: 0,
    );
  }
}

class MonitorData {
  final bool isConnected;
  final bool? isPaused;
  final bool? masterWarning;
  final bool? masterCaution;
  final double? heading;
  final bool? parkingBrake;
  final String? transponderState;
  final String? transponderCode;
  final String? flapsLabel;
  final double? flapsDeployRatio;
  final String? speedBrakeLabel;
  final bool? speedBrake;
  final bool? fireWarningEngine1;
  final bool? fireWarningEngine2;
  final bool? fireWarningAPU;
  final double? noseGearDown;
  final double? leftGearDown;
  final double? rightGearDown;
  final double? gForce;
  final double? altitude;
  final double? baroPressure;
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

  factory MonitorData.empty() {
    return MonitorData(isConnected: false, chartData: MonitorChartData.empty());
  }
}
