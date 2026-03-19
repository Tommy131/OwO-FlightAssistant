import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/services/persistence_service.dart';
import '../../home/models/home_models.dart';
import '../models/monitor_models.dart';

abstract class MonitorDataAdapter {
  Stream<MonitorData> get stream;
}

class MonitorProvider extends ChangeNotifier {
  MonitorProvider({MonitorDataAdapter? adapter}) : _adapter = adapter {
    _subscribeAdapter();
    unawaited(_loadPerformanceSettings());
  }

  static const int _maxChartPoints = 60;
  static const String _settingsModuleName = 'performance';
  static const String _lowPerformanceModeKey = 'low_performance_mode';
  static const String _uiRefreshIntervalMsKey = 'ui_refresh_interval_ms';
  static const int _defaultUiRefreshIntervalMs = 120;
  static const int _lowPerformanceRefreshIntervalMs = 500;
  MonitorDataAdapter? _adapter;
  StreamSubscription<MonitorData>? _subscription;
  MonitorData _data = MonitorData.empty();
  double _chartTime = 0;
  List<FlSpot> _gForceSpots = const [];
  List<FlSpot> _altitudeSpots = const [];
  List<FlSpot> _pressureSpots = const [];
  bool _lowPerformanceMode = false;
  int _uiRefreshIntervalMs = _defaultUiRefreshIntervalMs;
  DateTime? _lastUiNotifyAt;

  MonitorData get data => _data;
  bool get isConnected => _data.isConnected;
  MonitorChartData get chartData => _data.chartData;

  void attachAdapter(MonitorDataAdapter? adapter) {
    _adapter = adapter;
    _subscribeAdapter();
  }

  void updateData(MonitorData data) {
    _data = data;
    if (_shouldNotifyUi()) {
      notifyListeners();
    }
  }

  void updateFromHomeSnapshot(HomeDataSnapshot snapshot) {
    final flightData = snapshot.flightData;
    final currentG = flightData.gForce ?? 1.0;
    final currentAltitude = flightData.altitude ?? 0;
    final currentPressure = flightData.baroPressure ?? 29.92;
    final isPaused = snapshot.isPaused == true;
    if (!isPaused) {
      _chartTime += 1;
      _gForceSpots = _appendSpot(_gForceSpots, FlSpot(_chartTime, currentG));
      _altitudeSpots = _appendSpot(
        _altitudeSpots,
        FlSpot(_chartTime, currentAltitude),
      );
      _pressureSpots = _appendSpot(
        _pressureSpots,
        FlSpot(_chartTime, currentPressure),
      );
    }
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
    if (_shouldNotifyUi()) {
      notifyListeners();
    }
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
      if (_shouldNotifyUi()) {
        notifyListeners();
      }
    });
  }

  Future<void> refreshPerformanceSettings() async {
    await _loadPerformanceSettings();
    notifyListeners();
  }

  bool _shouldNotifyUi() {
    final now = DateTime.now();
    final minInterval = _lowPerformanceMode
        ? (_uiRefreshIntervalMs > _lowPerformanceRefreshIntervalMs
              ? _uiRefreshIntervalMs
              : _lowPerformanceRefreshIntervalMs)
        : _uiRefreshIntervalMs;
    if (_lastUiNotifyAt == null ||
        now.difference(_lastUiNotifyAt!).inMilliseconds >= minInterval) {
      _lastUiNotifyAt = now;
      return true;
    }
    return false;
  }

  Future<void> _loadPerformanceSettings() async {
    final persistence = PersistenceService();
    await persistence.ensureReady();
    _lowPerformanceMode =
        persistence.getModuleData<bool>(
          _settingsModuleName,
          _lowPerformanceModeKey,
        ) ??
        false;
    final storedInterval =
        persistence.getModuleData<int>(
          _settingsModuleName,
          _uiRefreshIntervalMsKey,
        ) ??
        _defaultUiRefreshIntervalMs;
    _uiRefreshIntervalMs = storedInterval.clamp(60, 2000).toInt();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
