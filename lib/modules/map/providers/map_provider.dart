import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../common/models/home_models.dart';
import '../models/map_models.dart';

class MapProvider extends ChangeNotifier {
  MapProvider({MapDataAdapter? adapter}) : _adapter = adapter {
    _subscribeAdapter();
  }

  MapDataAdapter? _adapter;
  StreamSubscription<MapDataSnapshot>? _subscription;

  MapLayerStyle _layerStyle = MapLayerStyle.dark;
  MapOrientationMode _orientationMode = MapOrientationMode.northUp;
  bool _followAircraft = true;
  bool _showRoute = true;
  bool _showAirports = true;
  bool _showCompass = true;
  bool _showWeather = false;
  bool _isLoading = false;
  bool _isConnected = false;
  int? _weatherRadarTimestamp;
  Timer? _radarRefreshTimer;
  DateTime? _lastRadarFetch;
  DateTime? _weatherRadarCooldownUntil;
  Timer? _radarCooldownTimer;

  MapAircraftState? _aircraft;
  List<MapRoutePoint> _route = [];
  List<MapAirportMarker> _airports = [];
  MapCoordinate? _takeoffPoint;
  MapCoordinate? _landingPoint;
  bool? _lastOnGround;
  DateTime? _lastRouteTimestamp;

  MapLayerStyle get layerStyle => _layerStyle;
  MapOrientationMode get orientationMode => _orientationMode;
  bool get followAircraft => _followAircraft;
  bool get showRoute => _showRoute;
  bool get showAirports => _showAirports;
  bool get showCompass => _showCompass;
  bool get showWeather => _showWeather;
  int? get weatherRadarTimestamp => _weatherRadarTimestamp;
  bool get isWeatherRadarCoolingDown =>
      _weatherRadarCooldownUntil != null &&
      DateTime.now().isBefore(_weatherRadarCooldownUntil!);
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  MapAircraftState? get aircraft => _aircraft;
  List<MapRoutePoint> get route => _route;
  List<MapAirportMarker> get airports => _airports;
  MapCoordinate? get takeoffPoint => _takeoffPoint;
  MapCoordinate? get landingPoint => _landingPoint;

  void attachAdapter(MapDataAdapter? adapter) {
    _adapter = adapter;
    _subscribeAdapter();
  }

  void updateFromHomeSnapshot(HomeDataSnapshot snapshot) {
    _isConnected = snapshot.isConnected;
    _airports = _buildAirportsFromSnapshot(snapshot);
    final flightData = snapshot.flightData;
    final lat = flightData.latitude;
    final lon = flightData.longitude;
    if (lat != null && lon != null) {
      final now = DateTime.now();
      final aircraftState = MapAircraftState(
        position: MapCoordinate(latitude: lat, longitude: lon),
        heading: flightData.heading,
        altitude: flightData.altitude,
        groundSpeed: flightData.groundSpeed,
        onGround: flightData.onGround,
      );
      _aircraft = aircraftState;
      _appendRoutePoint(aircraftState, now);
      _updateTakeoffLandingMarker(flightData.onGround, aircraftState.position);
    } else if (!_isConnected) {
      _aircraft = null;
      _lastOnGround = null;
    }
    notifyListeners();
  }

  void setLayerStyle(MapLayerStyle style) {
    _layerStyle = style;
    notifyListeners();
  }

  void setOrientationMode(MapOrientationMode mode) {
    _orientationMode = mode;
    notifyListeners();
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

  void clearRoute() {
    if (_route.isEmpty) return;
    _route = [];
    _takeoffPoint = null;
    _landingPoint = null;
    _lastOnGround = null;
    _lastRouteTimestamp = null;
    notifyListeners();
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
      _aircraft = snapshot.aircraft;
      _route = snapshot.route;
      _airports = snapshot.airports;
      _isConnected = snapshot.isConnected;
      notifyListeners();
    });
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

  void _appendRoutePoint(MapAircraftState aircraftState, DateTime now) {
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

  @override
  void dispose() {
    _subscription?.cancel();
    _radarRefreshTimer?.cancel();
    _radarCooldownTimer?.cancel();
    super.dispose();
  }
}
