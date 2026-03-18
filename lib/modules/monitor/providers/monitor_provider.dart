import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../home/models/home_models.dart';
import '../models/monitor_models.dart';

abstract class MonitorDataAdapter {
  Stream<MonitorData> get stream;
}

class MonitorProvider extends ChangeNotifier {
  MonitorProvider({MonitorDataAdapter? adapter}) : _adapter = adapter {
    _subscribeAdapter();
  }

  static const int _maxChartPoints = 60;
  MonitorDataAdapter? _adapter;
  StreamSubscription<MonitorData>? _subscription;
  MonitorData _data = MonitorData.empty();
  double _chartTime = 0;
  List<FlSpot> _gForceSpots = const [];
  List<FlSpot> _altitudeSpots = const [];
  List<FlSpot> _pressureSpots = const [];

  MonitorData get data => _data;
  bool get isConnected => _data.isConnected;
  MonitorChartData get chartData => _data.chartData;

  void attachAdapter(MonitorDataAdapter? adapter) {
    _adapter = adapter;
    _subscribeAdapter();
  }

  void updateData(MonitorData data) {
    _data = data;
    notifyListeners();
  }

  void updateFromHomeSnapshot(HomeDataSnapshot snapshot) {
    final flightData = snapshot.flightData;
    _chartTime += 1;
    final currentG = flightData.gForce ?? 1.0;
    final currentAltitude = flightData.altitude ?? 0;
    final currentPressure = flightData.baroPressure ?? 29.92;
    _gForceSpots = _appendSpot(_gForceSpots, FlSpot(_chartTime, currentG));
    _altitudeSpots = _appendSpot(
      _altitudeSpots,
      FlSpot(_chartTime, currentAltitude),
    );
    _pressureSpots = _appendSpot(
      _pressureSpots,
      FlSpot(_chartTime, currentPressure),
    );
    final chartData = MonitorChartData(
      gForceSpots: _gForceSpots,
      altitudeSpots: _altitudeSpots,
      pressureSpots: _pressureSpots,
      currentTime: _chartTime,
    );
    _data = MonitorData(
      isConnected: snapshot.isConnected,
      chartData: chartData,
      isPaused: snapshot.isPaused,
      masterWarning: flightData.masterWarning,
      masterCaution: flightData.masterCaution,
      heading: flightData.heading,
      parkingBrake: flightData.parkingBrake,
      transponderState: snapshot.transponderState,
      transponderCode: snapshot.transponderCode,
      flapsLabel: flightData.flapsLabel,
      flapsDeployRatio: flightData.flapsDeployRatio,
      speedBrakeLabel: flightData.speedBrakeLabel,
      speedBrake: flightData.speedBrake,
      fireWarningEngine1: flightData.fireWarningEngine1,
      fireWarningEngine2: flightData.fireWarningEngine2,
      fireWarningAPU: flightData.fireWarningAPU,
      noseGearDown: flightData.noseGearDown,
      leftGearDown: flightData.leftGearDown,
      rightGearDown: flightData.rightGearDown,
      gForce: currentG,
      altitude: flightData.altitude,
      baroPressure: flightData.baroPressure,
    );
    notifyListeners();
  }

  List<FlSpot> _appendSpot(List<FlSpot> source, FlSpot spot) {
    final next = <FlSpot>[...source, spot];
    if (next.length <= _maxChartPoints) {
      return next;
    }
    return next.sublist(next.length - _maxChartPoints);
  }

  void _subscribeAdapter() {
    _subscription?.cancel();
    final adapter = _adapter;
    if (adapter == null) return;
    _subscription = adapter.stream.listen((data) {
      _data = data;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
