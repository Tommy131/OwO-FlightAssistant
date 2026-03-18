import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../airport_search/models/airport_search_models.dart';
import '../../home/models/home_models.dart';
import '../../http/http_module.dart';
import '../localization/map_localization_keys.dart';
import '../models/map_models.dart';

class MapProvider extends ChangeNotifier {
  MapProvider({MapDataAdapter? adapter}) : _adapter = adapter {
    _subscribeAdapter();
  }

  MapDataAdapter? _adapter;
  StreamSubscription<MapDataSnapshot>? _subscription;

  MapLayerStyle _layerStyle = MapLayerStyle.dark;
  bool _followAircraft = true;
  bool _showRoute = true;
  bool _showAirports = true;
  bool _showRunways = true;
  bool _showParkings = true;
  bool _showCompass = true;
  bool _showWeather = false;
  bool _isLoading = false;
  bool _isConnected = false;
  int _connectionEpoch = 0;
  int _lastReconnectPromptEpoch = 0;
  bool _isPaused = false;
  int? _weatherRadarTimestamp;
  Timer? _radarRefreshTimer;
  DateTime? _lastRadarFetch;
  DateTime? _weatherRadarCooldownUntil;
  Timer? _radarCooldownTimer;
  int _tileReloadToken = 0;

  MapAircraftState? _aircraft;
  List<MapRoutePoint> _route = [];
  List<MapAirportMarker> _airports = [];
  List<MapFlightAlert> _activeAlerts = [];
  MapCoordinate? _takeoffPoint;
  MapCoordinate? _landingPoint;
  bool? _lastOnGround;
  DateTime? _lastRouteTimestamp;
  bool _isAircraftMoving = false;
  Duration _hudElapsed = Duration.zero;
  Timer? _hudTimer;
  bool _isHudTimerRunning = false;
  MapCoordinate? _lastMovementSamplePosition;
  DateTime? _lastMovementSampleAt;
  bool _autoHudTimerEnabled = false;
  MapAutoTimerStartMode _autoTimerStartMode =
      MapAutoTimerStartMode.runwayMovement;
  MapAutoTimerStopMode _autoTimerStopMode = MapAutoTimerStopMode.stableLanding;
  bool? _lastAutoParkingBrake;
  bool _hudTimerAirborneSinceStart = false;
  DateTime? _groundStableSince;

  MapLayerStyle get layerStyle => _layerStyle;
  bool get followAircraft => _followAircraft;
  bool get showRoute => _showRoute;
  bool get showAirports => _showAirports;
  bool get showRunways => _showRunways;
  bool get showParkings => _showParkings;
  bool get showCompass => _showCompass;
  bool get showWeather => _showWeather;
  int? get weatherRadarTimestamp => _weatherRadarTimestamp;
  bool get isWeatherRadarCoolingDown =>
      _weatherRadarCooldownUntil != null &&
      DateTime.now().isBefore(_weatherRadarCooldownUntil!);
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  int get connectionEpoch => _connectionEpoch;
  int get lastReconnectPromptEpoch => _lastReconnectPromptEpoch;
  bool get isPaused => _isPaused;
  MapAircraftState? get aircraft => _aircraft;
  List<MapRoutePoint> get route => _route;
  List<MapAirportMarker> get airports => _airports;
  List<MapFlightAlert> get activeAlerts => _activeAlerts;
  int get tileReloadToken => _tileReloadToken;
  MapCoordinate? get takeoffPoint => _takeoffPoint;
  MapCoordinate? get landingPoint => _landingPoint;
  bool get isAircraftMoving => _isAircraftMoving;
  Duration get hudElapsed => _hudElapsed;
  bool get isHudTimerRunning => _isHudTimerRunning;
  bool get autoHudTimerEnabled => _autoHudTimerEnabled;
  MapAutoTimerStartMode get autoTimerStartMode => _autoTimerStartMode;
  MapAutoTimerStopMode get autoTimerStopMode => _autoTimerStopMode;

  void attachAdapter(MapDataAdapter? adapter) {
    _adapter = adapter;
    _subscribeAdapter();
  }

  void updateFromHomeSnapshot(HomeDataSnapshot snapshot) {
    final wasConnected = _isConnected;
    _isConnected = snapshot.isConnected;
    if (!wasConnected && _isConnected) {
      _connectionEpoch += 1;
    }
    _isPaused = snapshot.isPaused == true && _isConnected;
    _airports = _buildAirportsFromSnapshot(snapshot);
    final flightData = snapshot.flightData;
    final lat = flightData.latitude;
    final lon = flightData.longitude;
    final hasValidPosition =
        lat != null && lon != null && _isValidCoordinate(lat, lon);
    if (_isConnected && hasValidPosition) {
      final now = DateTime.now();
      final aircraftState = MapAircraftState(
        position: MapCoordinate(latitude: lat, longitude: lon),
        heading: flightData.heading,
        headingTarget: flightData.autopilotHeadingTarget,
        altitude: flightData.altitude,
        groundSpeed: flightData.groundSpeed,
        airspeed: flightData.airspeed,
        pitch: flightData.pitch,
        bank: flightData.bank,
        angleOfAttack: flightData.angleOfAttack,
        verticalSpeed: flightData.verticalSpeed,
        stallWarning: flightData.stallWarning,
        onGround: flightData.onGround,
        parkingBrake: flightData.parkingBrake,
      );
      _aircraft = aircraftState;
      final isMoving = _resolveIsAircraftMoving(aircraftState, now);
      _isAircraftMoving = isMoving;
      _handleAutoHudTimer(
        flightData: flightData,
        aircraftState: aircraftState,
        isMoving: isMoving,
        now: now,
      );
      _appendRoutePoint(aircraftState, now, isMoving);
      _updateTakeoffLandingMarker(flightData.onGround, aircraftState.position);
    } else if (!_isConnected) {
      _clearAircraftVisualState();
    }
    _evaluateFlightAlerts(flightData);
    notifyListeners();
  }

  void setLayerStyle(MapLayerStyle style) {
    if (_layerStyle == style) {
      return;
    }
    _layerStyle = style;
    _tileReloadToken += 1;
    notifyListeners();
  }

  Future<List<MapAirportMarker>> searchAirports(String keyword) async {
    final query = keyword.trim();
    if (query.isEmpty) {
      return [];
    }
    try {
      await HttpModule.client.init();
      final response = await HttpModule.client.getAirportSuggestions(
        query,
        limit: 10,
      );
      final root = _asMap(response.decodedBody);
      if (root == null) {
        return _fallbackSearchAirports(query);
      }
      final result = _asMap(root['result']) ?? root;
      final candidates =
          _asList(result['suggestions']) ??
          _asList(result['items']) ??
          _asList(root['suggestions']) ??
          const [];
      final markers = candidates
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry('$k', v)))
          .map(_airportMarkerFromApi)
          .where(
            (airport) =>
                airport.code.isNotEmpty &&
                _isValidCoordinate(
                  airport.position.latitude,
                  airport.position.longitude,
                ),
          )
          .toList();
      if (markers.isNotEmpty) {
        return markers;
      }
      return _fallbackSearchAirports(query);
    } catch (_) {
      return _fallbackSearchAirports(query);
    }
  }

  Future<List<MapAirportMarker>> fetchAirportsByBounds({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
  }) async {
    try {
      await HttpModule.client.init();
      final response = await HttpModule.client.getAirportsByBounds(
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
      );
      final root = _asMap(response.decodedBody);
      if (root == null) return [];

      final result = _asMap(root['result']) ?? root;
      final candidates =
          _asList(result['airports']) ??
          _asList(result['items']) ??
          _asList(root['airports']) ??
          _asList(root['items']) ??
          [];

      return candidates
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry('$k', v)))
          .map(_airportMarkerFromApi)
          .where(
            (airport) =>
                airport.code.isNotEmpty &&
                _isValidCoordinate(
                  airport.position.latitude,
                  airport.position.longitude,
                ),
          )
          .toList();
    } catch (_) {
      try {
        final listResponse = await HttpModule.client.getAirportList();
        final listRoot = _asMap(listResponse.decodedBody);
        if (listRoot == null) return [];
        final result = _asMap(listRoot['result']) ?? listRoot;
        final candidates =
            _asList(result['airports']) ??
            _asList(result['items']) ??
            _asList(result['list']) ??
            _asList(listRoot['airports']) ??
            _asList(listRoot['items']) ??
            const [];
        return candidates
            .whereType<Map>()
            .map((item) => item.map((k, v) => MapEntry('$k', v)))
            .map(_airportMarkerFromApi)
            .where(
              (airport) =>
                  airport.code.isNotEmpty &&
                  _isValidCoordinate(
                    airport.position.latitude,
                    airport.position.longitude,
                  ) &&
                  airport.position.latitude >= minLat &&
                  airport.position.latitude <= maxLat &&
                  airport.position.longitude >= minLon &&
                  airport.position.longitude <= maxLon,
            )
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  Future<MapSelectedAirportDetail> fetchSelectedAirportDetail(
    MapAirportMarker airport,
  ) async {
    final icao = airport.code.trim().toUpperCase();
    final fallbackAirport = _findAirportByCode(icao) ?? airport;
    try {
      await HttpModule.client.init();
      Map<String, dynamic> airportRoot = const {};
      try {
        final layoutResponse = await HttpModule.client.getAirportLayoutByIcao(
          icao,
        );
        airportRoot = _asMap(layoutResponse.decodedBody) ?? const {};
      } catch (_) {
        final fallbackResponse = await HttpModule.client.getAirportByIcao(icao);
        airportRoot = _asMap(fallbackResponse.decodedBody) ?? const {};
      }
      final metarRoot = await _fetchMetarPayload(icao);
      final detail = AirportDetailData.fromApi(airportRoot);
      final metar = MetarData.fromApi(metarRoot);
      final rawMetar = _extractMetarField(metarRoot, [
        'raw_metar',
        'raw',
        'Raw',
        'metar',
      ]);
      final decodedMetar = _extractMetarField(metarRoot, [
        'translated_metar',
        'decoded',
        'Decoded',
        'translatedMetar',
      ]);
      final runwayGeometries = detail.runways
          .map(_toRunwayGeometry)
          .whereType<MapRunwayGeometry>()
          .toList();
      final parkingSpots = detail.parkings
          .map(_toParkingSpot)
          .whereType<MapParkingSpot>()
          .toList();
      final center = _resolveAirportCenter(
        runwayGeometries,
        detail.latitude,
        detail.longitude,
        fallbackAirport.position,
      );
      final marker = MapAirportMarker(
        code: icao,
        name: detail.name ?? airport.name ?? fallbackAirport.name,
        position: center,
      );
      final runwayValues = detail.runways
          .map((item) => _normalizeRunwayIdent(item.ident))
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();
      final atis = detail.frequencies
          .where((item) => (item.type ?? '').toUpperCase().contains('ATIS'))
          .map((item) => item.value?.trim() ?? '')
          .firstWhere((item) => item.isNotEmpty, orElse: () => '');
      final frequencyBadges = detail.frequencies
          .map((item) {
            final type = (item.type ?? '').trim().toUpperCase();
            final value = (item.value ?? '').trim();
            if (value.isEmpty) {
              return '';
            }
            if (type.isEmpty) {
              return value;
            }
            return '$type: $value';
          })
          .where((item) => item.isNotEmpty)
          .take(4)
          .toList();
      return MapSelectedAirportDetail(
        marker: marker,
        source: detail.source,
        runways: runwayValues,
        runwayGeometries: runwayGeometries,
        parkingSpots: parkingSpots,
        frequencyBadges: frequencyBadges,
        atis: atis.isEmpty ? null : atis,
        rawMetar: (rawMetar ?? metar.raw)?.trim(),
        decodedMetar: (decodedMetar ?? metar.decoded)?.trim(),
        approachRule: _resolveApproachRule(metarRoot, rawMetar ?? metar.raw),
      );
    } catch (_) {
      return MapSelectedAirportDetail(marker: fallbackAirport);
    }
  }

  Future<Map<String, dynamic>> _fetchMetarPayload(String icao) async {
    try {
      final response = await HttpModule.client.getMetarByIcao(icao);
      return _asMap(response.decodedBody) ?? const {};
    } catch (_) {
      return const {};
    }
  }

  void toggleFollowAircraft() {
    _followAircraft = !_followAircraft;
    notifyListeners();
  }

  void toggleRoute() {
    _showRoute = !_showRoute;
    notifyListeners();
  }

  void toggleAirports() {
    _showAirports = !_showAirports;
    notifyListeners();
  }

  void toggleRunways() {
    _showRunways = !_showRunways;
    notifyListeners();
  }

  void toggleParkings() {
    _showParkings = !_showParkings;
    notifyListeners();
  }

  void toggleCompass() {
    _showCompass = !_showCompass;
    notifyListeners();
  }

  void toggleWeather() {
    _showWeather = !_showWeather;
    if (_showWeather) {
      if (_weatherRadarTimestamp == null ||
          _lastRadarFetch == null ||
          DateTime.now().difference(_lastRadarFetch!).inMinutes >= 15) {
        _updateWeatherRadarTimestamp();
      }
      _radarRefreshTimer?.cancel();
      _radarRefreshTimer = Timer.periodic(
        const Duration(minutes: 15),
        (timer) => _updateWeatherRadarTimestamp(),
      );
    } else {
      _radarRefreshTimer?.cancel();
      _radarRefreshTimer = null;
      _radarCooldownTimer?.cancel();
      _radarCooldownTimer = null;
      _weatherRadarCooldownUntil = null;
    }
    notifyListeners();
  }

  void handleWeatherRadarRateLimit() {
    if (isWeatherRadarCoolingDown) return;
    _weatherRadarCooldownUntil = DateTime.now().add(const Duration(minutes: 5));
    _radarCooldownTimer?.cancel();
    _radarCooldownTimer = Timer(const Duration(minutes: 5), () {
      _weatherRadarCooldownUntil = null;
      if (_showWeather) {
        notifyListeners();
      }
    });
    notifyListeners();
  }

  Future<void> _updateWeatherRadarTimestamp() async {
    if (_lastRadarFetch != null &&
        DateTime.now().difference(_lastRadarFetch!).inSeconds < 5) {
      return;
    }
    try {
      final response = await http.get(
        Uri.parse('https://api.rainviewer.com/public/weather-maps.json'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> past = data['radar']['past'];
        if (past.isNotEmpty) {
          _weatherRadarTimestamp = past.last['time'] as int;
          _lastRadarFetch = DateTime.now();
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void updateAircraft(MapAircraftState? state) {
    _aircraft = state;
    notifyListeners();
  }

  void updateRoute(List<MapRoutePoint> route) {
    _route = route;
    notifyListeners();
  }

  void setAutoHudTimerEnabled(bool value) {
    if (_autoHudTimerEnabled == value) {
      return;
    }
    _autoHudTimerEnabled = value;
    notifyListeners();
  }

  void setAutoTimerStartMode(MapAutoTimerStartMode mode) {
    if (_autoTimerStartMode == mode) {
      return;
    }
    _autoTimerStartMode = mode;
    notifyListeners();
  }

  void setAutoTimerStopMode(MapAutoTimerStopMode mode) {
    if (_autoTimerStopMode == mode) {
      return;
    }
    _autoTimerStopMode = mode;
    notifyListeners();
  }

  void clearRoute() {
    _route = [];
    _takeoffPoint = null;
    _landingPoint = null;
    _lastOnGround = null;
    _lastRouteTimestamp = null;
    _hudElapsed = Duration.zero;
    _hudTimer?.cancel();
    _hudTimer = null;
    _isHudTimerRunning = false;
    _resetAutoTimerRuntimeState();
    notifyListeners();
  }

  void toggleHudTimer() {
    if (_isHudTimerRunning) {
      pauseHudTimer();
      return;
    }
    startHudTimer();
  }

  void startHudTimer() {
    if (_isHudTimerRunning) {
      return;
    }
    _resetAutoTimerFlightStateForNewRun();
    _isHudTimerRunning = true;
    _hudTimer?.cancel();
    _hudTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _hudElapsed += const Duration(seconds: 1);
      notifyListeners();
    });
    notifyListeners();
  }

  void pauseHudTimer() {
    if (!_isHudTimerRunning) {
      return;
    }
    _isHudTimerRunning = false;
    _hudTimer?.cancel();
    _hudTimer = null;
    notifyListeners();
  }

  void resetHudTimer() {
    _isHudTimerRunning = false;
    _hudTimer?.cancel();
    _hudTimer = null;
    _hudElapsed = Duration.zero;
    _resetAutoTimerRuntimeState();
    notifyListeners();
  }

  bool shouldShowReconnectPrompt() {
    return _isConnected &&
        _connectionEpoch >= 2 &&
        _route.isNotEmpty &&
        _connectionEpoch != _lastReconnectPromptEpoch;
  }

  void markReconnectPromptHandled() {
    _lastReconnectPromptEpoch = _connectionEpoch;
  }

  void updateAirports(List<MapAirportMarker> airports) {
    _airports = airports;
    notifyListeners();
  }

  void _subscribeAdapter() {
    _subscription?.cancel();
    final adapter = _adapter;
    if (adapter == null) return;
    _subscription = adapter.stream.listen((snapshot) {
      _isConnected = snapshot.isConnected;
      if (_isConnected) {
        _aircraft = snapshot.aircraft;
      } else {
        _clearAircraftVisualState();
      }
      _route = snapshot.route;
      _airports = snapshot.airports;
      notifyListeners();
    });
  }

  void _clearAircraftVisualState() {
    _aircraft = null;
    _lastOnGround = null;
    _isPaused = false;
    _isAircraftMoving = false;
    _lastMovementSamplePosition = null;
    _lastMovementSampleAt = null;
    _resetAutoTimerRuntimeState();
  }

  void _handleAutoHudTimer({
    required HomeFlightData flightData,
    required MapAircraftState aircraftState,
    required bool isMoving,
    required DateTime now,
  }) {
    final onGround = flightData.onGround ?? false;
    final parkingBrake = flightData.parkingBrake ?? false;
    final groundSpeed = aircraftState.groundSpeed ?? 0;
    final verticalSpeed = (aircraftState.verticalSpeed ?? 0).abs();
    if (_isHudTimerRunning) {
      if (!onGround) {
        _hudTimerAirborneSinceStart = true;
        _groundStableSince = null;
      }
    }

    if (_autoHudTimerEnabled) {
      if (!_isHudTimerRunning) {
        var shouldStart = false;
        switch (_autoTimerStartMode) {
          case MapAutoTimerStartMode.runwayMovement:
            final likelyOnRunwayRoll =
                onGround &&
                isMoving &&
                parkingBrake == false &&
                groundSpeed >= 20;
            shouldStart = likelyOnRunwayRoll;
            break;
          case MapAutoTimerStartMode.pushback:
            final brakeReleasedNow =
                _lastAutoParkingBrake == true && parkingBrake == false;
            shouldStart = onGround && brakeReleasedNow && isMoving;
            break;
          case MapAutoTimerStartMode.anyMovement:
            shouldStart = isMoving;
            break;
        }
        if (shouldStart) {
          startHudTimer();
        }
      } else {
        var shouldStop = false;
        switch (_autoTimerStopMode) {
          case MapAutoTimerStopMode.stableLanding:
            if (_hudTimerAirborneSinceStart && onGround) {
              if (groundSpeed <= 30 && verticalSpeed <= 120) {
                _groundStableSince ??= now;
              } else {
                _groundStableSince = null;
              }
              final stableForSeconds = _groundStableSince == null
                  ? 0
                  : now.difference(_groundStableSince!).inSeconds;
              shouldStop = stableForSeconds >= 8;
            }
            break;
          case MapAutoTimerStopMode.runwayExitAfterLanding:
            shouldStop =
                _hudTimerAirborneSinceStart && onGround && groundSpeed <= 18;
            break;
          case MapAutoTimerStopMode.parkingArrival:
            shouldStop =
                _hudTimerAirborneSinceStart &&
                onGround &&
                parkingBrake &&
                groundSpeed <= 1.5;
            break;
        }
        if (shouldStop) {
          pauseHudTimer();
        }
      }
    }

    _lastAutoParkingBrake = parkingBrake;
  }

  void _resetAutoTimerFlightStateForNewRun() {
    _hudTimerAirborneSinceStart = false;
    _groundStableSince = null;
  }

  void _resetAutoTimerRuntimeState() {
    _lastAutoParkingBrake = null;
    _resetAutoTimerFlightStateForNewRun();
  }

  List<MapAirportMarker> _buildAirportsFromSnapshot(HomeDataSnapshot snapshot) {
    final result = <MapAirportMarker>[];
    final added = <String>{};

    void addAirport(HomeAirportInfo? airport, {required bool isPrimary}) {
      if (airport == null) return;
      final code = airport.icaoCode.trim().toUpperCase();
      if (code.isEmpty || added.contains(code)) return;
      added.add(code);
      result.add(
        MapAirportMarker(
          code: code,
          name: airport.displayName,
          position: MapCoordinate(
            latitude: airport.latitude,
            longitude: airport.longitude,
          ),
          isPrimary: isPrimary,
        ),
      );
    }

    addAirport(snapshot.nearestAirport, isPrimary: true);
    addAirport(snapshot.destinationAirport, isPrimary: true);
    addAirport(snapshot.alternateAirport, isPrimary: false);
    for (final airport in snapshot.suggestedAirports) {
      addAirport(airport, isPrimary: false);
    }
    return result;
  }

  void _appendRoutePoint(
    MapAircraftState aircraftState,
    DateTime now,
    bool isMoving,
  ) {
    if (!isMoving) {
      return;
    }
    if (_route.isNotEmpty) {
      final last = _route.last;
      final movedDistance = const Distance().as(
        LengthUnit.Meter,
        LatLng(last.latitude, last.longitude),
        LatLng(
          aircraftState.position.latitude,
          aircraftState.position.longitude,
        ),
      );
      final secondsFromLast = _lastRouteTimestamp == null
          ? 999
          : now.difference(_lastRouteTimestamp!).inSeconds;
      if (movedDistance < 6 && secondsFromLast < 2) {
        return;
      }
    }

    _route = [
      ..._route,
      MapRoutePoint(
        latitude: aircraftState.position.latitude,
        longitude: aircraftState.position.longitude,
        altitude: aircraftState.altitude,
        groundSpeed: aircraftState.groundSpeed,
        timestamp: now,
      ),
    ];
    if (_route.length > 3600) {
      _route = _route.sublist(_route.length - 3600);
    }
    _lastRouteTimestamp = now;
  }

  bool _resolveIsAircraftMoving(MapAircraftState aircraftState, DateTime now) {
    if (!_isConnected || _isPaused) {
      _lastMovementSamplePosition = aircraftState.position;
      _lastMovementSampleAt = now;
      return false;
    }
    final speed = aircraftState.groundSpeed ?? 0;
    final movingBySpeed = speed >= 1.5;
    var movingByDistance = false;
    final lastPosition = _lastMovementSamplePosition;
    final lastAt = _lastMovementSampleAt;
    if (lastPosition != null && lastAt != null) {
      final movedDistance = const Distance().as(
        LengthUnit.Meter,
        LatLng(lastPosition.latitude, lastPosition.longitude),
        LatLng(
          aircraftState.position.latitude,
          aircraftState.position.longitude,
        ),
      );
      final elapsedMs = now.difference(lastAt).inMilliseconds;
      movingByDistance = elapsedMs >= 350 && movedDistance >= 2.5;
    }
    _lastMovementSamplePosition = aircraftState.position;
    _lastMovementSampleAt = now;
    return movingBySpeed || movingByDistance;
  }

  void _updateTakeoffLandingMarker(bool? onGround, MapCoordinate position) {
    if (onGround == null) {
      return;
    }
    if (_lastOnGround == null) {
      _lastOnGround = onGround;
      return;
    }
    if (_lastOnGround == true && onGround == false) {
      _takeoffPoint = position;
    } else if (_lastOnGround == false && onGround == true) {
      _landingPoint = position;
    }
    _lastOnGround = onGround;
  }

  void _evaluateFlightAlerts(HomeFlightData flightData) {
    if (!_isConnected) {
      _activeAlerts = const [];
      return;
    }
    final next = <MapFlightAlert>[];
    final onGround = flightData.onGround ?? false;
    final pitch = flightData.pitch;
    final bank = flightData.bank;
    final aoa = flightData.angleOfAttack;
    final airspeed = flightData.airspeed;
    final groundSpeed = flightData.groundSpeed;
    final verticalSpeed = flightData.verticalSpeed;
    final altitude = flightData.altitude;
    final stallWarning = flightData.stallWarning == true;

    if (!onGround && pitch != null) {
      if (pitch >= 35) {
        next.add(
          const MapFlightAlert(
            id: 'pitch_up_danger',
            level: MapFlightAlertLevel.danger,
            message: MapLocalizationKeys.alertPitchUpDanger,
          ),
        );
      } else if (pitch >= 25) {
        next.add(
          const MapFlightAlert(
            id: 'pitch_up_warning',
            level: MapFlightAlertLevel.warning,
            message: MapLocalizationKeys.alertPitchUpWarning,
          ),
        );
      } else if (pitch <= -30) {
        next.add(
          const MapFlightAlert(
            id: 'pitch_down_danger',
            level: MapFlightAlertLevel.danger,
            message: MapLocalizationKeys.alertPitchDownDanger,
          ),
        );
      } else if (pitch <= -20) {
        next.add(
          const MapFlightAlert(
            id: 'pitch_down_warning',
            level: MapFlightAlertLevel.warning,
            message: MapLocalizationKeys.alertPitchDownWarning,
          ),
        );
      }
    }

    if (!onGround && bank != null) {
      final absBank = bank.abs();
      if (absBank >= 60) {
        next.add(
          const MapFlightAlert(
            id: 'bank_danger',
            level: MapFlightAlertLevel.danger,
            message: MapLocalizationKeys.alertBankDanger,
          ),
        );
      } else if (absBank >= 45) {
        next.add(
          const MapFlightAlert(
            id: 'bank_warning',
            level: MapFlightAlertLevel.warning,
            message: MapLocalizationKeys.alertBankWarning,
          ),
        );
      }
    }

    if (!onGround) {
      final referenceSpeed = airspeed ?? groundSpeed;
      final highLiftAttitude = (pitch ?? 0) >= 10 || (aoa ?? 0) >= 10;
      final aggressiveClimb = (verticalSpeed ?? 0) >= 1000;
      final lowSpeedStallRisk =
          referenceSpeed != null &&
          referenceSpeed < 72 &&
          ((pitch ?? 0) >= 12 || (aoa ?? 0) >= 12 || aggressiveClimb);
      final lowSpeedStallWarning =
          referenceSpeed != null &&
          referenceSpeed < 95 &&
          (highLiftAttitude || aggressiveClimb);
      final highAoaStallRisk = aoa != null && aoa >= 14;
      if (stallWarning || lowSpeedStallRisk || highAoaStallRisk) {
        next.add(
          const MapFlightAlert(
            id: 'stall_warning',
            level: MapFlightAlertLevel.danger,
            message: MapLocalizationKeys.alertStallWarning,
          ),
        );
      } else if (lowSpeedStallWarning) {
        next.add(
          const MapFlightAlert(
            id: 'stall_speed_warning',
            level: MapFlightAlertLevel.warning,
            message: MapLocalizationKeys.alertStallWarning,
          ),
        );
      }
    }

    if (!onGround && verticalSpeed != null && altitude != null) {
      if (verticalSpeed <= -3000 && altitude <= 2500) {
        next.add(
          const MapFlightAlert(
            id: 'sink_rate_danger',
            level: MapFlightAlertLevel.danger,
            message: MapLocalizationKeys.alertSinkRateDanger,
          ),
        );
      } else if (verticalSpeed <= -2000 && altitude <= 3000) {
        next.add(
          const MapFlightAlert(
            id: 'sink_rate_warning',
            level: MapFlightAlertLevel.warning,
            message: MapLocalizationKeys.alertSinkRateWarning,
          ),
        );
      }
    }

    _activeAlerts = next;
  }

  List<MapAirportMarker> _fallbackSearchAirports(String keyword) {
    final query = keyword.toLowerCase();
    return _airports.where((airport) {
      final name = airport.name?.toLowerCase() ?? '';
      return airport.code.toLowerCase().contains(query) || name.contains(query);
    }).toList();
  }

  MapAirportMarker _airportMarkerFromApi(Map<String, dynamic> raw) {
    final code =
        (raw['icao'] ?? raw['ICAO'] ?? raw['iata'] ?? raw['IATA'] ?? '')
            .toString()
            .trim()
            .toUpperCase();
    final name = (raw['name'] ?? raw['Name'])?.toString().trim();
    final lat = _extractLatitude(raw);
    final lon = _extractLongitude(raw);
    final fallbackAirport = _findAirportByCode(code);
    final fallbackLat = fallbackAirport?.position.latitude;
    final fallbackLon = fallbackAirport?.position.longitude;
    final resolvedLat =
        lat != null && lon != null && _isValidCoordinate(lat, lon)
        ? lat
        : (fallbackLat != null &&
                  fallbackLon != null &&
                  _isValidCoordinate(fallbackLat, fallbackLon)
              ? fallbackLat
              : 0.0);
    final resolvedLon =
        lat != null && lon != null && _isValidCoordinate(lat, lon)
        ? lon
        : (fallbackLat != null &&
                  fallbackLon != null &&
                  _isValidCoordinate(fallbackLat, fallbackLon)
              ? fallbackLon
              : 0.0);
    return MapAirportMarker(
      code: code,
      name: name?.isEmpty ?? true ? null : name,
      position: MapCoordinate(latitude: resolvedLat, longitude: resolvedLon),
      isPrimary: false,
    );
  }

  MapAirportMarker? _findAirportByCode(String code) {
    for (final airport in _airports) {
      if (airport.code.toUpperCase() == code.toUpperCase()) {
        return airport;
      }
    }
    return null;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry('$key', val));
    }
    return null;
  }

  List<dynamic>? _asList(dynamic value) {
    if (value is List<dynamic>) return value;
    if (value is List) {
      return value.cast<dynamic>();
    }
    return null;
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  dynamic _pickValue(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      if (raw.containsKey(key)) {
        return raw[key];
      }
    }
    for (final key in keys) {
      for (final entry in raw.entries) {
        if (entry.key.toLowerCase() == key.toLowerCase()) {
          return entry.value;
        }
      }
    }
    return null;
  }

  double? _extractLatitude(Map<String, dynamic> raw) {
    final direct = _toDouble(
      _pickValue(raw, ['latitude', 'lat', 'Lat', 'Latitude', 'y']),
    );
    if (direct != null) return direct;
    for (final key in ['location', 'position', 'coordinate', 'coordinates']) {
      final nested = _asMap(_pickValue(raw, [key]));
      final value = _toDouble(
        _pickValue(nested ?? const {}, ['latitude', 'lat', 'Lat', 'y']),
      );
      if (value != null) {
        return value;
      }
    }
    final geometry = _asMap(_pickValue(raw, ['geometry', 'geojson']));
    final coordinates = _asList(
      _pickValue(geometry ?? const {}, ['coordinates']),
    );
    if (coordinates != null && coordinates.length >= 2) {
      return _toDouble(coordinates[1]);
    }
    return null;
  }

  double? _extractLongitude(Map<String, dynamic> raw) {
    final direct = _toDouble(
      _pickValue(raw, ['longitude', 'lon', 'lng', 'Lon', 'Lng', 'x']),
    );
    if (direct != null) return direct;
    for (final key in ['location', 'position', 'coordinate', 'coordinates']) {
      final nested = _asMap(_pickValue(raw, [key]));
      final value = _toDouble(
        _pickValue(nested ?? const {}, [
          'longitude',
          'lon',
          'lng',
          'Lon',
          'Lng',
          'x',
        ]),
      );
      if (value != null) {
        return value;
      }
    }
    final geometry = _asMap(_pickValue(raw, ['geometry', 'geojson']));
    final coordinates = _asList(
      _pickValue(geometry ?? const {}, ['coordinates']),
    );
    if (coordinates != null && coordinates.length >= 2) {
      return _toDouble(coordinates[0]);
    }
    return null;
  }

  String _normalizeRunwayIdent(String ident) {
    final text = ident.trim().toUpperCase();
    if (text.isEmpty) return '';
    final pairMatch = RegExp(r'(\d{2}[LCR]?/\d{2}[LCR]?)').firstMatch(text);
    if (pairMatch != null) {
      return pairMatch.group(1) ?? '';
    }
    final singleMatch = RegExp(r'\d{2}[LCR]?').firstMatch(text);
    return singleMatch?.group(0) ?? text;
  }

  MapRunwayGeometry? _toRunwayGeometry(AirportRunwayData data) {
    final startLat = data.leLat;
    final startLon = data.leLon;
    final endLat = data.heLat;
    final endLon = data.heLon;
    if (startLat == null ||
        startLon == null ||
        endLat == null ||
        endLon == null) {
      return null;
    }
    if (!_isValidCoordinate(startLat, startLon) ||
        !_isValidCoordinate(endLat, endLon)) {
      return null;
    }
    final leIdent = _resolveRunwayEndIdent(data.ident, data.leIdent, true);
    final heIdent = _resolveRunwayEndIdent(data.ident, data.heIdent, false);
    return MapRunwayGeometry(
      ident: data.ident,
      leIdent: leIdent,
      heIdent: heIdent,
      start: MapCoordinate(latitude: startLat, longitude: startLon),
      end: MapCoordinate(latitude: endLat, longitude: endLon),
      lengthM: data.lengthM,
    );
  }

  MapParkingSpot? _toParkingSpot(AirportParkingData data) {
    final lat = data.latitude;
    final lon = data.longitude;
    if (lat == null || lon == null) {
      return null;
    }
    if (!_isValidCoordinate(lat, lon)) {
      return null;
    }
    return MapParkingSpot(
      name: data.name,
      position: MapCoordinate(latitude: lat, longitude: lon),
      headingDeg: data.headingDeg,
    );
  }

  MapCoordinate _resolveAirportCenter(
    List<MapRunwayGeometry> runways,
    double? latitude,
    double? longitude,
    MapCoordinate fallback,
  ) {
    if (runways.isNotEmpty) {
      double latSum = 0;
      double lonSum = 0;
      double weightSum = 0;
      for (final runway in runways) {
        final midpointLat = (runway.start.latitude + runway.end.latitude) / 2;
        final midpointLon = (runway.start.longitude + runway.end.longitude) / 2;
        final weight = runway.lengthM != null && runway.lengthM! > 0
            ? runway.lengthM!
            : 1.0;
        latSum += midpointLat * weight;
        lonSum += midpointLon * weight;
        weightSum += weight;
      }
      if (weightSum > 0) {
        final candidateLat = latSum / weightSum;
        final candidateLon = lonSum / weightSum;
        if (_isValidCoordinate(candidateLat, candidateLon)) {
          return MapCoordinate(latitude: candidateLat, longitude: candidateLon);
        }
      }
    }
    if (latitude != null &&
        longitude != null &&
        _isValidCoordinate(latitude, longitude)) {
      return MapCoordinate(latitude: latitude, longitude: longitude);
    }
    return fallback;
  }

  bool _isValidCoordinate(double latitude, double longitude) {
    if (latitude < -90 || latitude > 90) {
      return false;
    }
    if (longitude < -180 || longitude > 180) {
      return false;
    }
    if (latitude.abs() < 0.0001 && longitude.abs() < 0.0001) {
      return false;
    }
    return true;
  }

  String? _extractMetarField(Map<String, dynamic> root, List<String> keys) {
    final payloadRoot = _asMap(_pickValue(root, ['data'])) ?? root;
    final raw = _pickValue(payloadRoot, keys);
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  String _resolveApproachRule(Map<String, dynamic> root, String? rawMetar) {
    final payloadRoot = _asMap(_pickValue(root, ['data'])) ?? root;
    final direct = _extractMetarField(payloadRoot, [
      'flight_rules',
      'flight_rule',
      'flight_category',
      'flightCategory',
      'category',
      'approach_rule',
      'approachRule',
    ]);
    final byDirect = _normalizeApproachRule(direct);
    if (byDirect != null) {
      return byDirect;
    }
    final visibility = _extractMetarField(payloadRoot, [
      'visibility',
      'display_visibility',
    ]);
    final clouds = _extractMetarField(payloadRoot, ['clouds']);
    final visibilitySm = _parseVisibilitySm(visibility);
    final ceilingFt = _parseCeilingFt(clouds);
    if (visibilitySm != null || ceilingFt != null) {
      if ((ceilingFt != null && ceilingFt < 500) ||
          (visibilitySm != null && visibilitySm < 1)) {
        return 'LIFR';
      }
      if ((ceilingFt != null && ceilingFt < 1000) ||
          (visibilitySm != null && visibilitySm < 3)) {
        return 'IFR';
      }
      if ((ceilingFt != null && ceilingFt <= 3000) ||
          (visibilitySm != null && visibilitySm <= 5)) {
        return 'MVFR';
      }
      return 'VFR';
    }
    final fromRaw = _normalizeApproachRule(rawMetar);
    if (fromRaw != null) {
      return fromRaw;
    }
    if ((rawMetar ?? '').toUpperCase().contains('CAVOK')) {
      return 'VFR';
    }
    return 'UNK';
  }

  String? _normalizeApproachRule(String? text) {
    final upper = (text ?? '').toUpperCase();
    if (upper.contains('LIFR')) return 'LIFR';
    if (upper.contains('MVFR')) return 'MVFR';
    if (upper.contains('IFR')) return 'IFR';
    if (upper.contains('VFR')) return 'VFR';
    return null;
  }

  double? _parseVisibilitySm(String? rawVisibility) {
    final text = (rawVisibility ?? '').trim().toUpperCase();
    if (text.isEmpty) {
      return null;
    }
    final meterMatch = RegExp(r'^\d{4}$').firstMatch(text);
    if (meterMatch != null) {
      final meters = double.tryParse(text);
      if (meters == null) {
        return null;
      }
      return meters / 1609.344;
    }
    final smMatch = RegExp(
      r'([PM]?\d+(?:/\d+)?(?:\.\d+)?)\s*SM',
    ).firstMatch(text);
    if (smMatch == null) {
      return null;
    }
    final token = smMatch.group(1) ?? '';
    final normalized = token.replaceAll('P', '').replaceAll('M', '');
    if (normalized.contains('/')) {
      final parts = normalized.split('/');
      if (parts.length == 2) {
        final numerator = double.tryParse(parts[0]);
        final denominator = double.tryParse(parts[1]);
        if (numerator != null && denominator != null && denominator != 0) {
          return numerator / denominator;
        }
      }
    }
    return double.tryParse(normalized);
  }

  double? _parseCeilingFt(String? cloudText) {
    final text = (cloudText ?? '').toUpperCase();
    if (text.isEmpty) {
      return null;
    }
    final matches = RegExp(r'(BKN|OVC|VV)(\d{3})').allMatches(text);
    int? minCeiling;
    for (final match in matches) {
      final value = int.tryParse(match.group(2) ?? '');
      if (value == null) {
        continue;
      }
      final ceiling = value * 100;
      if (minCeiling == null || ceiling < minCeiling) {
        minCeiling = ceiling;
      }
    }
    return minCeiling?.toDouble();
  }

  String? _resolveRunwayEndIdent(String ident, String? endpoint, bool isLeft) {
    final direct = endpoint?.trim();
    if (direct != null && direct.isNotEmpty) {
      return direct.toUpperCase();
    }
    final normalized = ident.trim().toUpperCase();
    if (normalized.isEmpty) {
      return null;
    }
    final parts = normalized.split('/');
    if (parts.length == 2) {
      return isLeft ? parts[0].trim() : parts[1].trim();
    }
    return normalized;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _radarRefreshTimer?.cancel();
    _radarCooldownTimer?.cancel();
    _hudTimer?.cancel();
    super.dispose();
  }
}
