import 'package:flutter/material.dart';
import '../../common/models/home_models.dart';
import '../models/flight_log_models.dart';

abstract class FlightLogsAdapter {
  Future<List<FlightLog>> loadLogs();
  Future<void> deleteLog(String id);
  Future<void> exportLog(FlightLog log);
  Future<void> importLog();
  Future<void> saveLog(FlightLog log);
}

class FlightLogsProvider extends ChangeNotifier {
  FlightLogsProvider({FlightLogsAdapter? adapter}) : _adapter = adapter;
  static const Duration _minimumRecordDuration = Duration(minutes: 1);

  FlightLogsAdapter? _adapter;
  List<FlightLog> _logs = [];
  bool _isLoading = false;
  FlightLog? _selectedLog;
  bool _isRecording = false;
  FlightLog? _activeLog;
  DateTime? _lastSampleAt;
  bool? _lastOnGround;

  List<FlightLog> get logs => _logs;
  bool get isLoading => _isLoading;
  FlightLog? get selectedLog => _selectedLog;
  bool get isRecording => _isRecording;
  FlightLog? get activeLog => _activeLog;

  void attachAdapter(FlightLogsAdapter? adapter) {
    _adapter = adapter;
    notifyListeners();
  }

  Future<void> refreshLogs() async {
    if (_adapter == null) return;
    _isLoading = true;
    notifyListeners();
    _logs = await _adapter!.loadLogs();
    _isLoading = false;
    if (_selectedLog != null &&
        !_logs.any((log) => log.id == _selectedLog!.id)) {
      _selectedLog = null;
    }
    notifyListeners();
  }

  void selectLog(FlightLog log) {
    _selectedLog = log;
    notifyListeners();
  }

  void clearSelection() {
    _selectedLog = null;
    notifyListeners();
  }

  Future<bool> deleteLog(String id) async {
    if (_adapter == null) return false;
    await _adapter!.deleteLog(id);
    await refreshLogs();
    return true;
  }

  Future<bool> exportLog(FlightLog log) async {
    if (_adapter == null) return false;
    await _adapter!.exportLog(log);
    return true;
  }

  Future<bool> importLog() async {
    if (_adapter == null) return false;
    await _adapter!.importLog();
    await refreshLogs();
    return true;
  }

  bool startRecording({
    required HomeDataSnapshot snapshot,
    String? flightNumber,
  }) {
    if (_adapter == null || _isRecording) return false;
    final now = DateTime.now();
    final data = snapshot.flightData;
    final departure =
        _normalizeText(data.departureAirport) ??
        _normalizeText(snapshot.nearestAirport?.icaoCode) ??
        '--';
    _activeLog = FlightLog(
      id: now.millisecondsSinceEpoch.toString(),
      aircraftTitle:
          _normalizeText(snapshot.aircraftTitle) ??
          _normalizeText(data.aircraftDisplayName) ??
          'Unknown',
      aircraftType:
          _normalizeText(data.aircraftIcao) ??
          _normalizeText(data.aircraftModel),
      simulatorLabel: _simulatorLabel(snapshot.simulatorType),
      flightNumber: _normalizeText(flightNumber),
      departureAirport: departure,
      arrivalAirport:
          _normalizeText(data.arrivalAirport) ??
          _normalizeText(snapshot.destinationAirport?.icaoCode),
      startTime: now,
      points: [],
      wasOnGroundAtStart: data.onGround ?? false,
    );
    _isRecording = true;
    _lastSampleAt = null;
    _lastOnGround = data.onGround;
    captureSnapshot(snapshot, force: true);
    notifyListeners();
    return true;
  }

  void captureSnapshot(HomeDataSnapshot snapshot, {bool force = false}) {
    if (!_isRecording || _activeLog == null) return;
    final now = DateTime.now();
    if (!force &&
        _lastSampleAt != null &&
        now.difference(_lastSampleAt!).inMilliseconds < 1800) {
      return;
    }
    final data = snapshot.flightData;
    final point = FlightLogPoint(
      latitude: data.latitude ?? 0,
      longitude: data.longitude ?? 0,
      altitude: data.altitude ?? 0,
      airspeed: data.airspeed ?? 0,
      groundSpeed: data.groundSpeed ?? data.airspeed ?? 0,
      verticalSpeed: data.verticalSpeed ?? 0,
      heading: data.heading ?? 0,
      pitch: 0,
      roll: 0,
      gForce: 1,
      fuelQuantity: data.fuelQuantity ?? 0,
      fuelFlow: data.fuelFlow,
      timestamp: now,
      autopilotEngaged: data.autopilotEngaged,
      autothrottleEngaged: data.autothrottleEngaged,
      gearDown: data.gearDown,
      flapsLabel: data.flapsLabel,
      windSpeed: data.windSpeed,
      windDirection: data.windDirection,
      outsideAirTemperature: data.outsideAirTemperature,
      baroPressure: data.baroPressure,
      masterWarning: data.masterWarning,
      masterCaution: data.masterCaution,
      engine1Running: data.engine1Running,
      engine2Running: data.engine2Running,
      transponderCode: snapshot.transponderCode,
      landingLights: data.landingLights,
      beacon: data.beacon,
      strobes: data.strobes,
      onGround: data.onGround,
    );
    final log = _activeLog!;
    log.points.add(point);
    log.endTime = now;
    log.maxAltitude = point.altitude > log.maxAltitude
        ? point.altitude
        : log.maxAltitude;
    log.maxAirspeed = point.airspeed > log.maxAirspeed
        ? point.airspeed
        : log.maxAirspeed;
    log.maxGroundSpeed = point.groundSpeed > log.maxGroundSpeed
        ? point.groundSpeed
        : log.maxGroundSpeed;
    log.maxG = point.gForce > log.maxG ? point.gForce : log.maxG;
    log.minG = point.gForce < log.minG ? point.gForce : log.minG;
    final onGround = point.onGround ?? false;
    if (_lastOnGround == true && !onGround && log.takeoffData == null) {
      log.takeoffData = TakeoffData(
        latitude: point.latitude,
        longitude: point.longitude,
        airspeed: point.airspeed,
        groundSpeed: point.groundSpeed,
        verticalSpeed: point.verticalSpeed,
        pitch: point.pitch,
        heading: point.heading,
        timestamp: point.timestamp,
      );
    }
    if (_lastOnGround == false && onGround && log.landingData == null) {
      final sequence = log.points.length <= 5
          ? List<FlightLogPoint>.from(log.points)
          : List<FlightLogPoint>.from(
              log.points.sublist(log.points.length - 5),
            );
      final rating = _ratingByG(point.gForce);
      log.landingData = LandingData(
        latitude: point.latitude,
        longitude: point.longitude,
        gForce: point.gForce,
        verticalSpeed: point.verticalSpeed,
        airspeed: point.airspeed,
        groundSpeed: point.groundSpeed,
        pitch: point.pitch,
        roll: point.roll,
        rating: rating,
        timestamp: point.timestamp,
        touchdownSequence: sequence,
      );
    }
    _lastOnGround = onGround;
    _lastSampleAt = now;
    notifyListeners();
  }

  Future<bool> stopRecording(HomeDataSnapshot snapshot) async {
    if (!_isRecording || _activeLog == null || _adapter == null) return false;
    captureSnapshot(snapshot, force: true);
    final log = _activeLog!;
    log.endTime = DateTime.now();
    log.wasOnGroundAtEnd = snapshot.flightData.onGround ?? false;
    if (log.points.isEmpty || log.duration < _minimumRecordDuration) {
      _isRecording = false;
      _activeLog = null;
      _lastSampleAt = null;
      _lastOnGround = null;
      notifyListeners();
      return false;
    }
    await _adapter!.saveLog(log);
    _isRecording = false;
    _activeLog = null;
    _lastSampleAt = null;
    _lastOnGround = null;
    await refreshLogs();
    notifyListeners();
    return true;
  }

  String _simulatorLabel(HomeSimulatorType type) {
    return switch (type) {
      HomeSimulatorType.xplane => 'X-Plane',
      HomeSimulatorType.msfs => 'MSFS',
      HomeSimulatorType.none => 'Unknown',
    };
  }

  String? _normalizeText(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  LandingRating _ratingByG(double gForce) {
    if (gForce <= LandingRating.perfect.maxG) return LandingRating.perfect;
    if (gForce <= LandingRating.soft.maxG) return LandingRating.soft;
    if (gForce <= LandingRating.acceptable.maxG) {
      return LandingRating.acceptable;
    }
    if (gForce <= LandingRating.hard.maxG) return LandingRating.hard;
    if (gForce <= LandingRating.fired.maxG) return LandingRating.fired;
    return LandingRating.rip;
  }
}
