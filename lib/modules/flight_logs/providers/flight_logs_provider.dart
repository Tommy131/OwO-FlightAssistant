import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/persistence_service.dart';
import '../../home/models/home_models.dart';
import '../models/flight_log_models.dart';

abstract class FlightLogsAdapter {
  Future<List<FlightLog>> loadLogs();
  Future<void> deleteLog(String id);
  Future<void> exportLog(FlightLog log);
  Future<void> importLog();
  Future<void> saveLog(FlightLog log);
}

class FlightLogsProvider extends ChangeNotifier {
  FlightLogsProvider({FlightLogsAdapter? adapter}) : _adapter = adapter {
    unawaited(_loadSamplingSettings());
  }

  static const String _moduleName = 'flight_logs';
  static const String _sampleIntervalMsKey = 'sample_interval_ms';
  static const int defaultSampleIntervalMs = 100;
  static const int minSampleIntervalMs = 100;
  static const int maxSampleIntervalMs = 2000;
  static const Duration _minimumRecordDuration = Duration(minutes: 1);
  static const Duration _landingStableDuration = Duration(seconds: 2);

  FlightLogsAdapter? _adapter;
  List<FlightLog> _logs = [];
  bool _isLoading = false;
  FlightLog? _selectedLog;
  bool _isRecording = false;
  FlightLog? _activeLog;
  DateTime? _lastSampleAt;
  bool? _lastOnGround;
  int _sampleIntervalMs = defaultSampleIntervalMs;
  bool _isRecordingPaused = false;
  bool _isAutoStopping = false;
  DateTime? _pendingLandingStartAt;
  int? _pendingLandingStartIndex;

  List<FlightLog> get logs => _logs;
  bool get isLoading => _isLoading;
  FlightLog? get selectedLog => _selectedLog;
  bool get isRecording => _isRecording;
  FlightLog? get activeLog => _activeLog;
  int get sampleIntervalMs => _sampleIntervalMs;
  bool get isRecordingPaused => _isRecordingPaused;

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

  Future<void> setSampleIntervalMs(int milliseconds) async {
    final next = milliseconds
        .clamp(minSampleIntervalMs, maxSampleIntervalMs)
        .toInt();
    if (next == _sampleIntervalMs) return;
    _sampleIntervalMs = next;
    final persistence = PersistenceService();
    await persistence.setModuleData(_moduleName, _sampleIntervalMsKey, next);
    notifyListeners();
  }

  void handleHomeSnapshot(HomeDataSnapshot snapshot) {
    if (!_isRecording) {
      return;
    }
    if (!snapshot.isConnected) {
      if (_isAutoStopping) {
        return;
      }
      _isAutoStopping = true;
      unawaited(
        stopRecording(snapshot).whenComplete(() {
          _isAutoStopping = false;
        }),
      );
      return;
    }
    final paused = snapshot.isPaused == true;
    if (_isRecordingPaused != paused) {
      _isRecordingPaused = paused;
      notifyListeners();
    }
    if (paused) {
      return;
    }
    captureSnapshot(snapshot);
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
    _isRecordingPaused = snapshot.isPaused == true;
    _lastSampleAt = null;
    _lastOnGround = data.onGround;
    _pendingLandingStartAt = null;
    _pendingLandingStartIndex = null;
    captureSnapshot(snapshot, force: true);
    notifyListeners();
    return true;
  }

  void captureSnapshot(HomeDataSnapshot snapshot, {bool force = false}) {
    if (!_isRecording || _activeLog == null) return;
    if (!force && _isRecordingPaused) return;
    final now = DateTime.now();
    if (!force &&
        _lastSampleAt != null &&
        now.difference(_lastSampleAt!).inMilliseconds < _sampleIntervalMs) {
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
      pitch: data.pitch ?? 0,
      roll: data.bank ?? 0,
      angleOfAttack: data.angleOfAttack,
      gForce: data.gForce ?? 1,
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
    _trackLandingState(log: log, point: point);
    _lastOnGround = onGround;
    _lastSampleAt = now;
    notifyListeners();
  }

  Future<bool> stopRecording(HomeDataSnapshot snapshot) async {
    if (!_isRecording || _activeLog == null || _adapter == null) return false;
    if (snapshot.isConnected) {
      captureSnapshot(snapshot, force: true);
    }
    final log = _activeLog!;
    log.endTime = DateTime.now();
    log.wasOnGroundAtEnd = snapshot.flightData.onGround ?? false;
    if (log.landingData == null &&
        log.wasOnGroundAtEnd &&
        _pendingLandingStartIndex != null) {
      _finalizeLandingCandidate(log, force: true);
    }
    if (log.points.isEmpty || log.duration < _minimumRecordDuration) {
      _resetRecordingState();
      notifyListeners();
      return false;
    }
    await _adapter!.saveLog(log);
    _resetRecordingState();
    await refreshLogs();
    notifyListeners();
    return true;
  }

  Future<void> _loadSamplingSettings() async {
    final persistence = PersistenceService();
    await persistence.ensureReady();
    final stored = persistence.getModuleData<int>(
      _moduleName,
      _sampleIntervalMsKey,
    );
    if (stored == null) {
      await persistence.setModuleData(
        _moduleName,
        _sampleIntervalMsKey,
        defaultSampleIntervalMs,
      );
      _sampleIntervalMs = defaultSampleIntervalMs;
      return;
    }
    _sampleIntervalMs = stored
        .clamp(minSampleIntervalMs, maxSampleIntervalMs)
        .toInt();
  }

  void _resetRecordingState() {
    _isRecording = false;
    _isRecordingPaused = false;
    _activeLog = null;
    _lastSampleAt = null;
    _lastOnGround = null;
    _pendingLandingStartAt = null;
    _pendingLandingStartIndex = null;
  }

  void _trackLandingState({
    required FlightLog log,
    required FlightLogPoint point,
  }) {
    final onGround = point.onGround ?? false;
    final crossedToGround = _lastOnGround == false && onGround;
    final crossedToAir = _lastOnGround == true && !onGround;
    if (crossedToGround) {
      _pendingLandingStartAt = point.timestamp;
      _pendingLandingStartIndex = log.points.length - 1;
    }
    if (crossedToAir && _pendingLandingStartIndex != null) {
      _pendingLandingStartAt = null;
      _pendingLandingStartIndex = null;
      return;
    }
    if (!onGround ||
        _pendingLandingStartAt == null ||
        _pendingLandingStartIndex == null ||
        log.landingData != null) {
      return;
    }
    if (point.timestamp.difference(_pendingLandingStartAt!) >=
        _landingStableDuration) {
      _finalizeLandingCandidate(log, force: false);
    }
  }

  void _finalizeLandingCandidate(FlightLog log, {required bool force}) {
    final startIndex = _pendingLandingStartIndex;
    if (startIndex == null ||
        startIndex < 0 ||
        startIndex >= log.points.length) {
      return;
    }
    final from = startIndex > 2 ? startIndex - 2 : 0;
    final sequence = List<FlightLogPoint>.from(log.points.sublist(from));
    final touchPoint = log.points[startIndex];
    if (!force && (touchPoint.onGround ?? false) == false) {
      return;
    }
    final rating = _ratingByG(touchPoint.gForce);
    log.landingData = LandingData(
      latitude: touchPoint.latitude,
      longitude: touchPoint.longitude,
      gForce: touchPoint.gForce,
      verticalSpeed: touchPoint.verticalSpeed,
      airspeed: touchPoint.airspeed,
      groundSpeed: touchPoint.groundSpeed,
      pitch: touchPoint.pitch,
      roll: touchPoint.roll,
      rating: rating,
      timestamp: touchPoint.timestamp,
      touchdownSequence: sequence,
    );
    _pendingLandingStartAt = null;
    _pendingLandingStartIndex = null;
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
