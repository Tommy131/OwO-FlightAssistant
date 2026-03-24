import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/services/persistence_service.dart';
import '../../airport_search/models/airport_search_models.dart';
import '../../common/models/common_models.dart';
import '../../http/http_module.dart';
import '../../map/localization/map_localization_keys.dart';
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
  static const Duration _approachMetricsWindow = Duration(seconds: 12);
  static const Duration _takeoffPreMetricsWindow = Duration(seconds: 18);
  static const Duration _takeoffPostMetricsWindow = Duration(seconds: 20);
  static const double _approachDetectionRadioAltitudeFt = 1800;
  static const double _approachDetectionAltitudeFt = 4500;
  static const double _approachDetectionVsThreshold = -250;
  static const double _minValidLandingG = 0.3;
  static const double _maxValidLandingG = 8.0;
  static const int _touchdownPeakSearchRadiusPoints = 2;
  static const Map<String, String> _backendAlertMessageMap = {
    'pitch_up_danger': MapLocalizationKeys.alertPitchUpDanger,
    'pitch_up_warning': MapLocalizationKeys.alertPitchUpWarning,
    'pitch_down_danger': MapLocalizationKeys.alertPitchDownDanger,
    'pitch_down_warning': MapLocalizationKeys.alertPitchDownWarning,
    'bank_danger': MapLocalizationKeys.alertBankDanger,
    'bank_warning': MapLocalizationKeys.alertBankWarning,
    'stall_warning': MapLocalizationKeys.alertStallWarning,
    'sink_rate_danger': MapLocalizationKeys.alertSinkRateDanger,
    'sink_rate_warning': MapLocalizationKeys.alertSinkRateWarning,
    'inverted_flight_danger': MapLocalizationKeys.alertInvertedFlightDanger,
    'knife_edge_danger': MapLocalizationKeys.alertKnifeEdgeDanger,
    'knife_edge_warning': MapLocalizationKeys.alertKnifeEdgeWarning,
    'pull_up_danger': MapLocalizationKeys.alertPullUpDanger,
    'pull_up_warning': MapLocalizationKeys.alertPullUpWarning,
    'push_over_danger': MapLocalizationKeys.alertPushOverDanger,
    'push_over_warning': MapLocalizationKeys.alertPushOverWarning,
    'spiral_dive_danger': MapLocalizationKeys.alertSpiralDiveDanger,
    'spiral_dive_warning': MapLocalizationKeys.alertSpiralDiveWarning,
    'unusual_attitude_danger': MapLocalizationKeys.alertUnusualAttitudeDanger,
    'unusual_attitude_warning': MapLocalizationKeys.alertUnusualAttitudeWarning,
    'climb_rate_danger': MapLocalizationKeys.alertClimbRateDanger,
    'climb_rate_warning': MapLocalizationKeys.alertClimbRateWarning,
    'descent_rate_danger': MapLocalizationKeys.alertDescentRateDanger,
    'descent_rate_warning': MapLocalizationKeys.alertDescentRateWarning,
    'high_g_danger': MapLocalizationKeys.alertHighGDanger,
    'high_g_warning': MapLocalizationKeys.alertHighGWarning,
    'negative_g_danger': MapLocalizationKeys.alertNegativeGDanger,
    'negative_g_warning': MapLocalizationKeys.alertNegativeGWarning,
    'overspeed_danger': MapLocalizationKeys.alertOverspeedDanger,
    'overspeed_warning': MapLocalizationKeys.alertOverspeedWarning,
    'terrain_pull_up_danger': MapLocalizationKeys.alertTerrainPullUpDanger,
    'terrain_pull_up_warning': MapLocalizationKeys.alertTerrainPullUpWarning,
  };

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
  bool _landingMonitorActive = false;
  DateTime? _stableGroundSince;
  int? _stableTouchdownIndex;
  final List<int> _touchdownPointIndexes = <int>[];

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
          _normalizeText(snapshot.destinationAirport?.icaoCode) ??
          departure,
      startTime: now,
      points: [],
      wasOnGroundAtStart: data.onGround ?? false,
    );
    _isRecording = true;
    _isRecordingPaused = snapshot.isPaused == true;
    _lastSampleAt = null;
    _lastOnGround = data.onGround;
    _landingMonitorActive = false;
    _stableGroundSince = null;
    _stableTouchdownIndex = null;
    _touchdownPointIndexes.clear();
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
    final anomalyAlerts = _buildPointAlerts(data.flightAlerts);
    final resolvedPointG = _resolveSnapshotPointG(data);
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
      gForce: resolvedPointG.value,
      gForceSource: resolvedPointG.source,
      fuelQuantity: data.fuelQuantity ?? 0,
      fuelFlow: data.fuelFlow,
      timestamp: now,
      autopilotEngaged: data.autopilotEngaged,
      autothrottleEngaged: data.autothrottleEngaged,
      flightPhase: data.flightPhase,
      autopilotHeadingTarget: data.autopilotHeadingTarget,
      autopilotLateralMode: data.autopilotLateralMode,
      autopilotVerticalMode: data.autopilotVerticalMode,
      gearDown: data.gearDown,
      touchdownGearG: data.touchdownGearG,
      noseGearG: data.noseGearG,
      leftGearG: data.leftGearG,
      rightGearG: data.rightGearG,
      flapsLabel: data.flapsLabel,
      windSpeed: data.windSpeed,
      windDirection: data.windDirection,
      windGust: data.windGust,
      gustDelta: data.gustDelta,
      gustFactorRate: data.gustFactorRate,
      crosswindComponent: data.crosswindComponent,
      radioAltitude: data.radioAltitude,
      outsideAirTemperature: data.outsideAirTemperature,
      baroPressure: data.baroPressure,
      masterWarning: data.masterWarning,
      masterCaution: data.masterCaution,
      engine1Running: data.engine1Running,
      engine2Running: data.engine2Running,
      engine1N1: data.engine1N1,
      engine2N1: data.engine2N1,
      engine1N2: data.engine1N2,
      engine2N2: data.engine2N2,
      engine1Egt: data.engine1EGT,
      engine2Egt: data.engine2EGT,
      transponderCode: snapshot.transponderCode,
      landingLights: data.landingLights,
      beacon: data.beacon,
      strobes: data.strobes,
      aileronInput: data.aileronInput,
      elevatorInput: data.elevatorInput,
      rudderInput: data.rudderInput,
      aileronTrim: data.aileronTrim,
      elevatorTrim: data.elevatorTrim,
      rudderTrim: data.rudderTrim,
      onGround: data.onGround,
      anomalyAlerts: anomalyAlerts,
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
    _updateFuelUsed(log);
    final onGround = point.onGround ?? false;
    if (_lastOnGround == true && !onGround && log.takeoffData == null) {
      final liftoffIndex = log.points.length - 1;
      final takeoffMetrics = _buildTakeoffMetrics(
        points: log.points,
        liftoffIndex: liftoffIndex,
      );
      log.takeoffData = TakeoffData(
        latitude: point.latitude,
        longitude: point.longitude,
        airspeed: point.airspeed,
        groundSpeed: point.groundSpeed,
        verticalSpeed: point.verticalSpeed,
        pitch: point.pitch,
        heading: point.heading,
        timestamp: point.timestamp,
        runway: _runwayIdentFromHeading(point.heading),
        takeoffStabilityScore: takeoffMetrics.takeoffStabilityScore,
        rotationSpeedKt: takeoffMetrics.rotationSpeedKt,
        rotationToLiftoffSec: takeoffMetrics.rotationToLiftoffSec,
        crosswindAtLiftoffKt: takeoffMetrics.crosswindAtLiftoffKt,
        pitchAt35FtDeg: takeoffMetrics.pitchAt35FtDeg,
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
    _finalizeLandingAtStop(log);
    if (log.points.isEmpty || log.duration < _minimumRecordDuration) {
      _resetRecordingState();
      notifyListeners();
      return false;
    }
    _updateFuelUsed(log);
    await _enrichRunwayInfo(log);
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
    _landingMonitorActive = false;
    _stableGroundSince = null;
    _stableTouchdownIndex = null;
    _touchdownPointIndexes.clear();
  }

  void _trackLandingState({
    required FlightLog log,
    required FlightLogPoint point,
  }) {
    if (log.landingData != null && (point.onGround ?? false) == true) {
      _landingMonitorActive = true;
    }
    if (!_landingMonitorActive && _isApproachAttitude(point)) {
      _landingMonitorActive = true;
      _stableGroundSince = null;
      _stableTouchdownIndex = null;
      _touchdownPointIndexes.clear();
    }
    if (!_landingMonitorActive) {
      return;
    }
    final onGround = point.onGround ?? false;
    final previousOnGround = _lastOnGround ?? log.wasOnGroundAtStart;
    final crossedToGround = !previousOnGround && onGround;
    final crossedToAir = previousOnGround && !onGround;
    final pointIndex = log.points.length - 1;
    if (crossedToGround) {
      _touchdownPointIndexes.add(pointIndex);
      _stableGroundSince = point.timestamp;
      _stableTouchdownIndex = pointIndex;
    }
    if (crossedToAir) {
      _stableGroundSince = null;
      _stableTouchdownIndex = null;
    }
    if (!onGround ||
        _stableGroundSince == null ||
        _stableTouchdownIndex == null) {
      return;
    }
    if (point.timestamp.difference(_stableGroundSince!) >=
        _landingStableDuration) {
      _updateLandingDataFromTouchdowns(
        log: log,
        finalTouchdownIndex: _stableTouchdownIndex!,
      );
    }
  }

  bool _isApproachAttitude(FlightLogPoint point) {
    final phase = (point.flightPhase ?? '').trim().toLowerCase();
    if (phase == 'approach' || phase == 'landing') {
      return true;
    }
    final radioAltitude = point.radioAltitude;
    if (radioAltitude != null &&
        radioAltitude > 0 &&
        radioAltitude <= _approachDetectionRadioAltitudeFt &&
        point.verticalSpeed <= _approachDetectionVsThreshold) {
      return true;
    }
    return point.altitude <= _approachDetectionAltitudeFt &&
        point.verticalSpeed <= _approachDetectionVsThreshold &&
        (point.gearDown ?? false);
  }

  void _finalizeLandingAtStop(FlightLog log) {
    if (_touchdownPointIndexes.isEmpty) {
      return;
    }
    final finalIndex = _stableTouchdownIndex ?? _touchdownPointIndexes.last;
    if (finalIndex < 0 || finalIndex >= log.points.length) {
      return;
    }
    _updateLandingDataFromTouchdowns(log: log, finalTouchdownIndex: finalIndex);
  }

  void _updateLandingDataFromTouchdowns({
    required FlightLog log,
    required int finalTouchdownIndex,
  }) {
    if (log.points.isEmpty ||
        finalTouchdownIndex < 0 ||
        finalTouchdownIndex >= log.points.length) {
      return;
    }
    final validIndexes =
        _touchdownPointIndexes
            .where(
              (index) =>
                  index >= 0 &&
                  index < log.points.length &&
                  index <= finalTouchdownIndex,
            )
            .toList()
          ..sort();
    if (validIndexes.isEmpty) {
      return;
    }
    final sequence = validIndexes
        .map((index) => log.points[index])
        .toList(growable: false);
    final touchdownGForces = validIndexes
        .map((index) => _touchdownPeakAtIndex(log.points, index).value)
        .toList(growable: false);
    final finalTouchdownPoint = log.points[finalTouchdownIndex];
    final finalTouchdown = _resolveFinalTouchdownG(
      points: log.points,
      touchdownIndexes: validIndexes,
      finalTouchdownIndex: finalTouchdownIndex,
      touchdownGForces: touchdownGForces,
    );
    final bounceCount = sequence.length > 1 ? sequence.length - 1 : 0;
    final approachMetrics = _buildApproachLandingMetrics(
      points: log.points,
      touchPointIndex: finalTouchdownIndex,
      bounceCount: bounceCount,
    );
    final rating = _ratingByTouchdown(
      gForce: finalTouchdown.value,
      touchdownVerticalSpeed: finalTouchdownPoint.verticalSpeed,
      bounceCount: bounceCount,
    );
    log.landingData = LandingData(
      latitude: finalTouchdownPoint.latitude,
      longitude: finalTouchdownPoint.longitude,
      gForce: finalTouchdown.value,
      gForceSource: finalTouchdown.source,
      verticalSpeed: finalTouchdownPoint.verticalSpeed,
      airspeed: finalTouchdownPoint.airspeed,
      groundSpeed: finalTouchdownPoint.groundSpeed,
      pitch: finalTouchdownPoint.pitch,
      roll: finalTouchdownPoint.roll,
      rating: rating,
      timestamp: finalTouchdownPoint.timestamp,
      touchdownSequence: sequence,
      touchdownGForces: touchdownGForces,
      runway: _runwayIdentFromHeading(finalTouchdownPoint.heading),
      approachStabilityScore: approachMetrics.stabilityScore,
      flareHeightFt: approachMetrics.flareHeightFt,
      sinkRateAt50FtFpm: approachMetrics.sinkRateAt50FtFpm,
      crosswindAtTouchdownKt: approachMetrics.crosswindAtTouchdownKt,
      bounceCount: approachMetrics.bounceCount,
    );
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

  List<FlightLogAlert> _buildPointAlerts(List<HomeFlightAlert> alerts) {
    if (alerts.isEmpty) {
      return const <FlightLogAlert>[];
    }
    final next = <FlightLogAlert>[];
    final seen = <String>{};
    for (final alert in alerts) {
      final rawMessage = alert.message.trim();
      if (rawMessage.isEmpty) {
        continue;
      }
      final message =
          _backendAlertMessageMap[rawMessage.toLowerCase()] ?? rawMessage;
      if (!seen.add(message)) {
        continue;
      }
      next.add(
        FlightLogAlert(
          id: alert.id.trim().isNotEmpty ? alert.id.trim() : rawMessage,
          level: _mapAlertLevel(alert.level),
          message: message,
        ),
      );
    }
    return next;
  }

  FlightLogAlertLevel _mapAlertLevel(String rawLevel) {
    final value = rawLevel.trim().toLowerCase();
    if (value == FlightLogAlertLevel.danger.name) {
      return FlightLogAlertLevel.danger;
    }
    if (value == FlightLogAlertLevel.warning.name) {
      return FlightLogAlertLevel.warning;
    }
    return FlightLogAlertLevel.caution;
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

  LandingRating _ratingByTouchdown({
    required double gForce,
    required double touchdownVerticalSpeed,
    required int bounceCount,
  }) {
    final baseRating = _ratingByG(gForce);
    final sinkRate = touchdownVerticalSpeed.abs();
    LandingRating minimumRating = LandingRating.perfect;
    if (sinkRate >= 1200) {
      minimumRating = LandingRating.rip;
    } else if (sinkRate >= 900) {
      minimumRating = LandingRating.fired;
    } else if (sinkRate >= 600) {
      minimumRating = LandingRating.hard;
    } else if (sinkRate >= 360 || bounceCount >= 2) {
      minimumRating = LandingRating.acceptable;
    }
    return baseRating.index > minimumRating.index ? baseRating : minimumRating;
  }

  List<_ResolvedLandingG> _touchdownSampleGSources(FlightLogPoint point) {
    final samples = <_ResolvedLandingG>[];
    final candidateValues = <_ResolvedLandingG>[
      if (point.touchdownGearG != null)
        _ResolvedLandingG(point.touchdownGearG!, LandingGSource.touchdownGear),
      if (point.leftGearG != null)
        _ResolvedLandingG(point.leftGearG!, LandingGSource.gear),
      if (point.rightGearG != null)
        _ResolvedLandingG(point.rightGearG!, LandingGSource.gear),
      if (point.noseGearG != null)
        _ResolvedLandingG(point.noseGearG!, LandingGSource.gear),
      _ResolvedLandingG(point.gForce, point.gForceSource),
    ];
    for (final candidate in candidateValues) {
      if (!_isValidLandingG(candidate.value)) {
        continue;
      }
      samples.add(candidate);
    }
    return samples;
  }

  _ResolvedLandingG _touchdownInstantG(FlightLogPoint point) {
    final samples = _touchdownSampleGSources(point);
    if (samples.isEmpty) {
      return _ResolvedLandingG(
        _normalizedLandingG(point.gForce),
        point.gForceSource,
      );
    }
    return _maxResolvedLandingG(samples);
  }

  _ResolvedLandingG _touchdownPeakAtIndex(
    List<FlightLogPoint> points,
    int centerIndex,
  ) {
    if (centerIndex < 0 || centerIndex >= points.length) {
      return const _ResolvedLandingG(1.0, LandingGSource.fallback);
    }
    var peak = _touchdownInstantG(points[centerIndex]);
    final start = math.max(0, centerIndex - _touchdownPeakSearchRadiusPoints);
    final end = math.min(
      points.length - 1,
      centerIndex + _touchdownPeakSearchRadiusPoints,
    );
    for (var i = start; i <= end; i++) {
      final candidate = _touchdownInstantG(points[i]);
      if (candidate.value > peak.value) {
        peak = candidate;
      }
    }
    return peak;
  }

  _ResolvedLandingG _resolveFinalTouchdownG({
    required List<FlightLogPoint> points,
    required List<int> touchdownIndexes,
    required int finalTouchdownIndex,
    required List<double> touchdownGForces,
  }) {
    final finalWindowPeak = _touchdownPeakAtIndex(points, finalTouchdownIndex);
    if (touchdownGForces.isEmpty) {
      return finalWindowPeak;
    }
    var globalPeak = finalWindowPeak;
    for (final touchdownIndex in touchdownIndexes) {
      final peakAtTouchdown = _touchdownPeakAtIndex(points, touchdownIndex);
      if (peakAtTouchdown.value > globalPeak.value) {
        globalPeak = peakAtTouchdown;
      }
    }
    final windowStart = math.max(
      0,
      finalTouchdownIndex - _touchdownPeakSearchRadiusPoints,
    );
    final windowEnd = math.min(
      points.length - 1,
      finalTouchdownIndex + _touchdownPeakSearchRadiusPoints,
    );
    for (final touchdownIndex in touchdownIndexes) {
      if (touchdownIndex >= windowStart && touchdownIndex <= windowEnd) {
        return finalWindowPeak.value >= globalPeak.value
            ? finalWindowPeak
            : globalPeak;
      }
    }
    return globalPeak;
  }

  _ResolvedLandingG _maxResolvedLandingG(List<_ResolvedLandingG> values) {
    var current = values.first;
    for (var i = 1; i < values.length; i++) {
      final candidate = values[i];
      if (candidate.value > current.value) {
        current = candidate;
      }
    }
    return current;
  }

  bool _isValidLandingG(double value) {
    return value >= _minValidLandingG && value <= _maxValidLandingG;
  }

  double _normalizedLandingG(double value) {
    if (_isValidLandingG(value)) {
      return value;
    }
    return value.clamp(_minValidLandingG, _maxValidLandingG).toDouble();
  }

  _ResolvedLandingG _resolveSnapshotPointG(FlightData data) {
    final bodyG = data.gForce;
    if (bodyG != null && _isValidLandingG(bodyG)) {
      return _ResolvedLandingG(bodyG, LandingGSource.body);
    }
    final gearCandidates = <double>[
      if (data.leftGearG != null && _isValidLandingG(data.leftGearG!))
        data.leftGearG!,
      if (data.rightGearG != null && _isValidLandingG(data.rightGearG!))
        data.rightGearG!,
      if (data.noseGearG != null && _isValidLandingG(data.noseGearG!))
        data.noseGearG!,
    ];
    if (data.touchdownGearG != null && _isValidLandingG(data.touchdownGearG!)) {
      return _ResolvedLandingG(
        data.touchdownGearG!,
        LandingGSource.touchdownGear,
      );
    }
    if (gearCandidates.isNotEmpty) {
      return _ResolvedLandingG(
        gearCandidates.reduce(math.max),
        LandingGSource.gear,
      );
    }
    if (bodyG == null || bodyG.isNaN || bodyG.isInfinite) {
      return const _ResolvedLandingG(1.0, LandingGSource.fallback);
    }
    return _ResolvedLandingG(_normalizedLandingG(bodyG), LandingGSource.body);
  }

  void _updateFuelUsed(FlightLog log) {
    if (log.points.length < 2) return;
    double? startFuel;
    double? endFuel;
    for (final point in log.points) {
      if (point.fuelQuantity > 0) {
        startFuel ??= point.fuelQuantity;
        endFuel = point.fuelQuantity;
      }
    }
    if (startFuel != null && endFuel != null) {
      final used = startFuel - endFuel;
      if (used >= 0) {
        log.totalFuelUsed = used;
        return;
      }
    }
    double integratedFuel = 0;
    for (int i = 1; i < log.points.length; i++) {
      final previous = log.points[i - 1];
      final current = log.points[i];
      final flow = previous.fuelFlow;
      if (flow == null || flow <= 0) continue;
      final deltaSeconds =
          current.timestamp.difference(previous.timestamp).inMilliseconds /
          1000;
      if (deltaSeconds <= 0) continue;
      integratedFuel += flow * deltaSeconds / 3600;
    }
    if (integratedFuel > 0) {
      log.totalFuelUsed = integratedFuel;
    }
  }

  Future<void> _enrichRunwayInfo(FlightLog log) async {
    final takeoff = log.takeoffData;
    if (takeoff != null) {
      _RunwayEstimate? estimate;
      if (takeoff.runway == null || takeoff.remainingRunwayFt == null) {
        estimate = await _estimateRunwayAtAirport(
          airportIcao: log.departureAirport,
          latitude: takeoff.latitude,
          longitude: takeoff.longitude,
          heading: takeoff.heading,
        );
      }
      final liftoffIndex = _findPointIndexByTimestamp(
        points: log.points,
        timestamp: takeoff.timestamp,
      );
      final takeoffMetrics = _buildTakeoffMetrics(
        points: log.points,
        liftoffIndex: liftoffIndex,
      );
      log.takeoffData = TakeoffData(
        latitude: takeoff.latitude,
        longitude: takeoff.longitude,
        airspeed: takeoff.airspeed,
        groundSpeed: takeoff.groundSpeed,
        verticalSpeed: takeoff.verticalSpeed,
        pitch: takeoff.pitch,
        heading: takeoff.heading,
        timestamp: takeoff.timestamp,
        runway: takeoff.runway ?? estimate?.ident,
        remainingRunwayFt: takeoff.remainingRunwayFt ?? estimate?.remainingFt,
        takeoffStabilityScore:
            takeoff.takeoffStabilityScore ??
            takeoffMetrics.takeoffStabilityScore,
        rotationSpeedKt:
            takeoff.rotationSpeedKt ?? takeoffMetrics.rotationSpeedKt,
        rotationToLiftoffSec:
            takeoff.rotationToLiftoffSec ?? takeoffMetrics.rotationToLiftoffSec,
        crosswindAtLiftoffKt:
            takeoff.crosswindAtLiftoffKt ?? takeoffMetrics.crosswindAtLiftoffKt,
        pitchAt35FtDeg: takeoff.pitchAt35FtDeg ?? takeoffMetrics.pitchAt35FtDeg,
      );
    }
    final landing = log.landingData;
    final arrivalIcao =
        _normalizeText(log.arrivalAirport) ??
        _normalizeText(log.departureAirport);
    if (landing != null &&
        arrivalIcao != null &&
        (landing.runway == null || landing.remainingRunwayFt == null)) {
      final estimate = await _estimateRunwayAtAirport(
        airportIcao: arrivalIcao,
        latitude: landing.latitude,
        longitude: landing.longitude,
        heading: landing.touchdownSequence.isNotEmpty
            ? landing.touchdownSequence.last.heading
            : 0,
      );
      if (estimate != null) {
        log.landingData = LandingData(
          latitude: landing.latitude,
          longitude: landing.longitude,
          gForce: landing.gForce,
          verticalSpeed: landing.verticalSpeed,
          airspeed: landing.airspeed,
          groundSpeed: landing.groundSpeed,
          pitch: landing.pitch,
          roll: landing.roll,
          rating: landing.rating,
          timestamp: landing.timestamp,
          touchdownSequence: landing.touchdownSequence,
          touchdownGForces: landing.touchdownGForces,
          runway: landing.runway ?? estimate.ident,
          remainingRunwayFt: landing.remainingRunwayFt ?? estimate.remainingFt,
          approachStabilityScore: landing.approachStabilityScore,
          flareHeightFt: landing.flareHeightFt,
          sinkRateAt50FtFpm: landing.sinkRateAt50FtFpm,
          crosswindAtTouchdownKt: landing.crosswindAtTouchdownKt,
          bounceCount: landing.bounceCount,
        );
      }
    }
  }

  int _findPointIndexByTimestamp({
    required List<FlightLogPoint> points,
    required DateTime timestamp,
  }) {
    if (points.isEmpty) return -1;
    var bestIndex = 0;
    var bestDelta = points.first.timestamp.difference(timestamp).abs();
    for (int i = 1; i < points.length; i++) {
      final delta = points[i].timestamp.difference(timestamp).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  _TakeoffMetrics _buildTakeoffMetrics({
    required List<FlightLogPoint> points,
    required int liftoffIndex,
  }) {
    if (points.isEmpty || liftoffIndex < 0 || liftoffIndex >= points.length) {
      return const _TakeoffMetrics();
    }
    final preWindowCount = _windowPointCount(_takeoffPreMetricsWindow);
    final postWindowCount = _windowPointCount(_takeoffPostMetricsWindow);
    final preStart = liftoffIndex > preWindowCount
        ? liftoffIndex - preWindowCount
        : 0;
    final preWindow = points.sublist(preStart, liftoffIndex + 1);
    final postEnd = (liftoffIndex + postWindowCount).clamp(
      0,
      points.length - 1,
    );
    final postWindow = points.sublist(liftoffIndex, postEnd + 1);
    final liftoffPoint = points[liftoffIndex];

    FlightLogPoint? rotationPoint;
    for (int i = 1; i < preWindow.length; i++) {
      final previous = preWindow[i - 1];
      final current = preWindow[i];
      final currentOnGround = current.onGround ?? false;
      if (!currentOnGround) {
        continue;
      }
      final pitchRaising = current.pitch - previous.pitch >= 0.35;
      final liftingIntent =
          current.pitch >= 2.2 || (current.elevatorInput ?? 0) >= 0.2;
      final speedReady = current.groundSpeed >= 45 || current.airspeed >= 45;
      if (pitchRaising && liftingIntent && speedReady) {
        rotationPoint = current;
        break;
      }
    }

    final liftoffTime = liftoffPoint.timestamp;
    final climbWindow = postWindow.where((point) {
      final delta = point.timestamp.difference(liftoffTime).inSeconds;
      return delta >= 0 && delta <= 20 && ((point.onGround ?? false) == false);
    }).toList();
    final verticalScore = _stabilityScoreFromStdDev(
      climbWindow.map((point) => point.verticalSpeed).toList(),
      threshold: 260,
    );
    final pitchScore = _stabilityScoreFromStdDev(
      climbWindow.map((point) => point.pitch).toList(),
      threshold: 2.5,
    );
    final rollScore = _stabilityScoreFromStdDev(
      climbWindow.map((point) => point.roll).toList(),
      threshold: 4.2,
    );
    final stabilityScore =
        ((verticalScore * 0.45) + (pitchScore * 0.3) + (rollScore * 0.25))
            .clamp(0.0, 100.0);

    FlightLogPoint? at35FtPoint;
    double? nearestDistance;
    for (final point in postWindow) {
      final radioAltitude = point.radioAltitude;
      if (radioAltitude == null || radioAltitude <= 0) {
        continue;
      }
      final distance = (radioAltitude - 35).abs();
      if (nearestDistance == null || distance < nearestDistance) {
        nearestDistance = distance;
        at35FtPoint = point;
      }
    }

    return _TakeoffMetrics(
      takeoffStabilityScore: climbWindow.length >= 2 ? stabilityScore : null,
      rotationSpeedKt: rotationPoint?.airspeed ?? rotationPoint?.groundSpeed,
      rotationToLiftoffSec: rotationPoint == null
          ? null
          : liftoffPoint.timestamp
                .difference(rotationPoint.timestamp)
                .inSeconds
                .clamp(0, 120),
      crosswindAtLiftoffKt: liftoffPoint.crosswindComponent?.abs(),
      pitchAt35FtDeg: at35FtPoint?.pitch,
    );
  }

  _ApproachLandingMetrics _buildApproachLandingMetrics({
    required List<FlightLogPoint> points,
    required int touchPointIndex,
    required int bounceCount,
  }) {
    if (points.isEmpty ||
        touchPointIndex < 0 ||
        touchPointIndex >= points.length) {
      return const _ApproachLandingMetrics();
    }
    final approachWindowCount = _windowPointCount(_approachMetricsWindow);
    final start = touchPointIndex > approachWindowCount
        ? touchPointIndex - approachWindowCount
        : 0;
    final window = points.sublist(start, touchPointIndex + 1);
    final approachWindow = window
        .where((point) => (point.onGround ?? false) == false)
        .toList();
    final stabilityWindow = approachWindow.isNotEmpty ? approachWindow : window;
    final verticalScore = _stabilityScoreFromStdDev(
      stabilityWindow.map((point) => point.verticalSpeed).toList(),
      threshold: 280,
    );
    final pitchScore = _stabilityScoreFromStdDev(
      stabilityWindow.map((point) => point.pitch).toList(),
      threshold: 2.8,
    );
    final rollScore = _stabilityScoreFromStdDev(
      stabilityWindow.map((point) => point.roll).toList(),
      threshold: 4.5,
    );
    final speedScore = _stabilityScoreFromStdDev(
      stabilityWindow.map((point) => point.airspeed).toList(),
      threshold: 7,
    );
    final score =
        ((verticalScore * 0.35) +
                (pitchScore * 0.2) +
                (rollScore * 0.25) +
                (speedScore * 0.2))
            .clamp(0.0, 100.0);
    final touchPoint = points[touchPointIndex];
    final flareHeightFt = _estimateFlareHeightFt(stabilityWindow);
    final sinkRateAt50FtFpm = _estimateSinkRateAtRadioAltitude(
      points: stabilityWindow,
      targetAltitude: 50,
    );
    return _ApproachLandingMetrics(
      stabilityScore: score,
      flareHeightFt: flareHeightFt,
      sinkRateAt50FtFpm: sinkRateAt50FtFpm,
      crosswindAtTouchdownKt: touchPoint.crosswindComponent?.abs(),
      bounceCount: bounceCount,
    );
  }

  double _stabilityScoreFromStdDev(
    List<double> values, {
    required double threshold,
  }) {
    if (values.length < 2 || threshold <= 0) {
      return 100;
    }
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values
            .map((value) => (value - mean) * (value - mean))
            .reduce((a, b) => a + b) /
        values.length;
    final stdDev = math.sqrt(variance);
    final normalized = (stdDev / threshold).clamp(0.0, 1.4);
    return (100 - normalized * 100).clamp(0.0, 100.0);
  }

  double? _estimateFlareHeightFt(List<FlightLogPoint> points) {
    FlightLogPoint? best;
    for (final point in points) {
      final radioAltitude = point.radioAltitude;
      if (radioAltitude == null || radioAltitude <= 0 || radioAltitude > 80) {
        continue;
      }
      if (point.pitch <= 2 || point.verticalSpeed >= -200) {
        continue;
      }
      if (best == null || radioAltitude > (best.radioAltitude ?? 0)) {
        best = point;
      }
    }
    return best?.radioAltitude;
  }

  double? _estimateSinkRateAtRadioAltitude({
    required List<FlightLogPoint> points,
    required double targetAltitude,
  }) {
    FlightLogPoint? selected;
    double? bestDistance;
    for (final point in points) {
      final radioAltitude = point.radioAltitude;
      if (radioAltitude == null || radioAltitude <= 0) {
        continue;
      }
      final distance = (radioAltitude - targetAltitude).abs();
      if (bestDistance == null || distance < bestDistance) {
        selected = point;
        bestDistance = distance;
      }
    }
    return selected?.verticalSpeed;
  }

  int _windowPointCount(Duration window) {
    final stepMs = _sampleIntervalMs <= 0
        ? defaultSampleIntervalMs
        : _sampleIntervalMs;
    final count = (window.inMilliseconds / stepMs).round();
    return count < 1 ? 1 : count;
  }

  Future<_RunwayEstimate?> _estimateRunwayAtAirport({
    required String airportIcao,
    required double latitude,
    required double longitude,
    required double heading,
  }) async {
    final normalizedIcao = _normalizeText(airportIcao)?.toUpperCase();
    if (normalizedIcao == null || normalizedIcao == '--') {
      return null;
    }
    try {
      await HttpModule.client.init();
      final response = await HttpModule.client.getAirportByIcao(normalizedIcao);
      final payload = response.decodedBody;
      if (payload is! Map<String, dynamic>) return null;
      final airport = AirportDetailData.fromApi(payload);
      return _pickBestRunwayEstimate(
        runways: airport.runways,
        eventLat: latitude,
        eventLon: longitude,
        eventHeading: heading,
      );
    } catch (_) {
      return null;
    }
  }

  _RunwayEstimate? _pickBestRunwayEstimate({
    required List<AirportRunwayData> runways,
    required double eventLat,
    required double eventLon,
    required double eventHeading,
  }) {
    _RunwayEstimate? best;
    double bestScore = double.infinity;
    for (final runway in runways) {
      final leLat = runway.leLat;
      final leLon = runway.leLon;
      final heLat = runway.heLat;
      final heLon = runway.heLon;
      if (leLat == null || leLon == null || heLat == null || heLon == null) {
        continue;
      }
      final lengthM =
          runway.lengthM ?? _distanceMeters(leLat, leLon, heLat, heLon);
      final leHeading = _bearingDegrees(leLat, leLon, heLat, heLon);
      final heHeading = _bearingDegrees(heLat, heLon, leLat, leLon);
      final leEstimate = _buildRunwayEstimate(
        ident: (runway.leIdent?.trim().isNotEmpty == true)
            ? runway.leIdent!.trim().toUpperCase()
            : runway.ident.trim().toUpperCase(),
        startLat: leLat,
        startLon: leLon,
        endLat: heLat,
        endLon: heLon,
        lengthM: lengthM,
        eventLat: eventLat,
        eventLon: eventLon,
      );
      final heEstimate = _buildRunwayEstimate(
        ident: (runway.heIdent?.trim().isNotEmpty == true)
            ? runway.heIdent!.trim().toUpperCase()
            : runway.ident.trim().toUpperCase(),
        startLat: heLat,
        startLon: heLon,
        endLat: leLat,
        endLon: leLon,
        lengthM: lengthM,
        eventLat: eventLat,
        eventLon: eventLon,
      );
      final leScore =
          _angleDelta(eventHeading, leHeading) * 120 +
          leEstimate.distanceToThresholdM;
      if (leScore < bestScore) {
        bestScore = leScore;
        best = leEstimate;
      }
      final heScore =
          _angleDelta(eventHeading, heHeading) * 120 +
          heEstimate.distanceToThresholdM;
      if (heScore < bestScore) {
        bestScore = heScore;
        best = heEstimate;
      }
    }
    return best;
  }

  _RunwayEstimate _buildRunwayEstimate({
    required String ident,
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    required double lengthM,
    required double eventLat,
    required double eventLon,
  }) {
    final startXY = _projectToMeters(startLat, startLon, startLat, startLon);
    final endXY = _projectToMeters(endLat, endLon, startLat, startLon);
    final eventXY = _projectToMeters(eventLat, eventLon, startLat, startLon);
    final runwayDx = endXY.dx - startXY.dx;
    final runwayDy = endXY.dy - startXY.dy;
    final runwayLenSq = runwayDx * runwayDx + runwayDy * runwayDy;
    double ratio = 0;
    if (runwayLenSq > 0) {
      ratio =
          ((eventXY.dx - startXY.dx) * runwayDx +
              (eventXY.dy - startXY.dy) * runwayDy) /
          runwayLenSq;
    }
    ratio = ratio.clamp(0, 1).toDouble();
    final remainingM = (1 - ratio) * lengthM;
    final distanceToThresholdM = _distanceMeters(
      eventLat,
      eventLon,
      startLat,
      startLon,
    );
    return _RunwayEstimate(
      ident: ident.isNotEmpty
          ? ident
          : _runwayIdentFromHeading(
              _bearingDegrees(startLat, startLon, endLat, endLon),
            ),
      remainingFt: remainingM * 3.28084,
      distanceToThresholdM: distanceToThresholdM,
    );
  }

  _ProjectedPoint _projectToMeters(
    double lat,
    double lon,
    double refLat,
    double refLon,
  ) {
    const earthRadius = 6371000.0;
    final latRad = lat * math.pi / 180;
    final lonRad = lon * math.pi / 180;
    final refLatRad = refLat * math.pi / 180;
    final refLonRad = refLon * math.pi / 180;
    final x =
        (lonRad - refLonRad) * math.cos((latRad + refLatRad) / 2) * earthRadius;
    final y = (latRad - refLatRad) * earthRadius;
    return _ProjectedPoint(dx: x, dy: y);
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _bearingDegrees(double lat1, double lon1, double lat2, double lon2) {
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final lambda1 = lon1 * math.pi / 180;
    final lambda2 = lon2 * math.pi / 180;
    final y = math.sin(lambda2 - lambda1) * math.cos(phi2);
    final x =
        math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(lambda2 - lambda1);
    final bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  double _angleDelta(double a, double b) {
    final diff = (a - b).abs() % 360;
    return diff > 180 ? 360 - diff : diff;
  }

  String _runwayIdentFromHeading(double heading) {
    final normalized = ((heading % 360) + 360) % 360;
    int runway = (normalized / 10).round();
    if (runway == 0 || runway == 36) {
      runway = 36;
    }
    return runway.toString().padLeft(2, '0');
  }
}

class _ProjectedPoint {
  final double dx;
  final double dy;

  const _ProjectedPoint({required this.dx, required this.dy});
}

class _RunwayEstimate {
  final String ident;
  final double remainingFt;
  final double distanceToThresholdM;

  const _RunwayEstimate({
    required this.ident,
    required this.remainingFt,
    required this.distanceToThresholdM,
  });
}

class _ApproachLandingMetrics {
  final double? stabilityScore;
  final double? flareHeightFt;
  final double? sinkRateAt50FtFpm;
  final double? crosswindAtTouchdownKt;
  final int? bounceCount;

  const _ApproachLandingMetrics({
    this.stabilityScore,
    this.flareHeightFt,
    this.sinkRateAt50FtFpm,
    this.crosswindAtTouchdownKt,
    this.bounceCount,
  });
}

class _TakeoffMetrics {
  final double? takeoffStabilityScore;
  final double? rotationSpeedKt;
  final int? rotationToLiftoffSec;
  final double? crosswindAtLiftoffKt;
  final double? pitchAt35FtDeg;

  const _TakeoffMetrics({
    this.takeoffStabilityScore,
    this.rotationSpeedKt,
    this.rotationToLiftoffSec,
    this.crosswindAtLiftoffKt,
    this.pitchAt35FtDeg,
  });
}

class _ResolvedLandingG {
  final double value;
  final LandingGSource source;

  const _ResolvedLandingG(this.value, this.source);
}
