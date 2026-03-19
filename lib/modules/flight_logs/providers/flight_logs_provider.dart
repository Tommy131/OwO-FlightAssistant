import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/services/persistence_service.dart';
import '../../airport_search/models/airport_search_models.dart';
import '../../home/models/home_models.dart';
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
    final anomalyAlerts = _buildPointAlerts(data.flightAlerts);
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
      runway: _runwayIdentFromHeading(touchPoint.heading),
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
      final message = _backendAlertMessageMap[rawMessage.toLowerCase()] ?? rawMessage;
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
      final deltaSeconds = current.timestamp
          .difference(previous.timestamp)
          .inMilliseconds /
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
    if (takeoff != null && (takeoff.runway == null || takeoff.remainingRunwayFt == null)) {
      final estimate = await _estimateRunwayAtAirport(
        airportIcao: log.departureAirport,
        latitude: takeoff.latitude,
        longitude: takeoff.longitude,
        heading: takeoff.heading,
      );
      if (estimate != null) {
        log.takeoffData = TakeoffData(
          latitude: takeoff.latitude,
          longitude: takeoff.longitude,
          airspeed: takeoff.airspeed,
          groundSpeed: takeoff.groundSpeed,
          verticalSpeed: takeoff.verticalSpeed,
          pitch: takeoff.pitch,
          heading: takeoff.heading,
          timestamp: takeoff.timestamp,
          runway: takeoff.runway ?? estimate.ident,
          remainingRunwayFt: takeoff.remainingRunwayFt ?? estimate.remainingFt,
        );
      }
    }
    final landing = log.landingData;
    final arrivalIcao = _normalizeText(log.arrivalAirport) ?? _normalizeText(log.departureAirport);
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
          runway: landing.runway ?? estimate.ident,
          remainingRunwayFt: landing.remainingRunwayFt ?? estimate.remainingFt,
        );
      }
    }
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
      final lengthM = runway.lengthM ?? _distanceMeters(leLat, leLon, heLat, heLon);
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
          _angleDelta(eventHeading, leHeading) * 120 + leEstimate.distanceToThresholdM;
      if (leScore < bestScore) {
        bestScore = leScore;
        best = leEstimate;
      }
      final heScore =
          _angleDelta(eventHeading, heHeading) * 120 + heEstimate.distanceToThresholdM;
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
      ident: ident.isNotEmpty ? ident : _runwayIdentFromHeading(_bearingDegrees(startLat, startLon, endLat, endLon)),
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
    final x = (lonRad - refLonRad) * math.cos((latRad + refLatRad) / 2) * earthRadius;
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
