import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/simulator_data.dart';

mixin ChartHistoryMixin on ChangeNotifier {
  final List<FlSpot> _gForceSpots = [];
  final List<FlSpot> _altitudeSpots = [];
  final List<FlSpot> _pressureSpots = [];
  double _chartTime = 0;
  DateTime? _lastChartUpdate;
  static const int _maxSpots = 300; // 记录约1分钟的数据 (以5Hz采样计)

  List<FlSpot> get gForceSpots => _gForceSpots;
  List<FlSpot> get altitudeSpots => _altitudeSpots;
  List<FlSpot> get pressureSpots => _pressureSpots;
  double get chartTime => _chartTime;

  void updateChartHistory(bool isConnected, SimulatorData data) {
    if (!isConnected) return;

    final now = DateTime.now();
    if (_lastChartUpdate != null &&
        now.difference(_lastChartUpdate!).inMilliseconds < 200) {
      return;
    }

    _lastChartUpdate = now;
    _chartTime += 0.2;

    // G-Force
    _gForceSpots.add(FlSpot(_chartTime, data.gForce ?? 1.0));
    if (_gForceSpots.length > _maxSpots) _gForceSpots.removeAt(0);

    // Altitude
    if (data.altitude != null) {
      _altitudeSpots.add(FlSpot(_chartTime, data.altitude!));
      if (_altitudeSpots.length > _maxSpots) _altitudeSpots.removeAt(0);
    }

    // Pressure
    if (data.baroPressure != null) {
      _pressureSpots.add(FlSpot(_chartTime, data.baroPressure!));
      if (_pressureSpots.length > _maxSpots) _pressureSpots.removeAt(0);
    }

    // Note: We don't notifyListeners here to avoid over-refreshing,
    // the parent provider will notify.
  }

  void clearChartHistory() {
    _gForceSpots.clear();
    _altitudeSpots.clear();
    _pressureSpots.clear();
    _chartTime = 0;
    _lastChartUpdate = null;
    notifyListeners();
  }
}
