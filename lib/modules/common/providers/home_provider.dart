import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/utils/logger.dart';
import '../../http/models/http_models.dart';
import '../../http/services/middleware_http_service.dart';
import '../models/home_models.dart';

abstract class HomeDataAdapter {
  Stream<HomeDataSnapshot> get stream;
  Future<bool> connect(HomeSimulatorType type);
  Future<void> disconnect();
  Future<void> setFlightNumber(String? value);
  Future<void> setDestination(HomeAirportInfo? airport);
  Future<void> setAlternate(HomeAirportInfo? airport);
  Future<List<HomeAirportInfo>> searchAirports(String keyword);
  Future<void> refreshMetar(HomeAirportInfo airport);
}

class HomeProvider extends ChangeNotifier {
  HomeProvider({HomeDataAdapter? adapter}) : _adapter = adapter {
    _subscribeAdapter();
  }

  HomeDataAdapter? _adapter;
  StreamSubscription<HomeDataSnapshot>? _subscription;
  HomeDataSnapshot _snapshot = HomeDataSnapshot.empty();

  bool get isConnected => _snapshot.isConnected;
  HomeDataSnapshot get snapshot => _snapshot;
  HomeSimulatorType get simulatorType => _snapshot.simulatorType;
  String? get errorMessage => _snapshot.errorMessage;
  String? get aircraftTitle => _snapshot.aircraftTitle;
  bool? get isPaused => _snapshot.isPaused;
  String? get transponderState => _snapshot.transponderState;
  String? get transponderCode => _snapshot.transponderCode;
  String? get flightNumber => _snapshot.flightNumber;
  bool get hasFlightNumber =>
      _snapshot.flightNumber != null && _snapshot.flightNumber!.isNotEmpty;
  bool? get isFuelSufficient => _snapshot.isFuelSufficient;
  HomeChecklistPhase? get checklistPhase => _snapshot.checklistPhase;
  double get checklistProgress => _snapshot.checklistProgress ?? 0;
  HomeFlightData get flightData => _snapshot.flightData;
  HomeAirportInfo? get destinationAirport => _snapshot.destinationAirport;
  HomeAirportInfo? get alternateAirport => _snapshot.alternateAirport;
  HomeAirportInfo? get nearestAirport => _snapshot.nearestAirport;
  List<HomeAirportInfo> get suggestedAirports => _snapshot.suggestedAirports;
  Map<String, HomeMetarData> get metarsByIcao => _snapshot.metarsByIcao;
  Map<String, String> get metarErrorsByIcao => _snapshot.metarErrorsByIcao;

  void attachAdapter(HomeDataAdapter? adapter) {
    _adapter = adapter;
    _subscribeAdapter();
  }

  Future<bool> connect(HomeSimulatorType type) async {
    final adapter = _adapter;
    if (adapter == null) return false;
    return adapter.connect(type);
  }

  Future<void> disconnect() async {
    final adapter = _adapter;
    if (adapter == null) return;
    await adapter.disconnect();
  }

  Future<void> setFlightNumber(String? value) async {
    final adapter = _adapter;
    if (adapter == null) return;
    await adapter.setFlightNumber(value);
  }

  Future<void> setDestination(HomeAirportInfo? airport) async {
    final adapter = _adapter;
    if (adapter == null) return;
    await adapter.setDestination(airport);
  }

  Future<void> setAlternate(HomeAirportInfo? airport) async {
    final adapter = _adapter;
    if (adapter == null) return;
    await adapter.setAlternate(airport);
  }

  Future<List<HomeAirportInfo>> searchAirports(String keyword) async {
    final adapter = _adapter;
    if (adapter == null) return [];
    return adapter.searchAirports(keyword);
  }

  Future<void> refreshMetar(HomeAirportInfo airport) async {
    final adapter = _adapter;
    if (adapter == null) return;
    await adapter.refreshMetar(airport);
  }

  void _subscribeAdapter() {
    _subscription?.cancel();
    final adapter = _adapter;
    if (adapter == null) return;
    _subscription = adapter.stream.listen((snapshot) {
      _snapshot = snapshot;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class MiddlewareHomeDataAdapter implements HomeDataAdapter {
  MiddlewareHomeDataAdapter({
    MiddlewareHttpService? httpService,
    Duration? pollInterval,
  }) : _httpService = httpService ?? MiddlewareHttpService(),
       _pollInterval = pollInterval ?? const Duration(seconds: 1);

  final MiddlewareHttpService _httpService;
  final Duration _pollInterval;
  final StreamController<HomeDataSnapshot> _controller =
      StreamController<HomeDataSnapshot>.broadcast();

  Timer? _pollTimer;
  WebSocketChannel? _wsChannel;
  StreamSubscription<dynamic>? _wsSubscription;
  String? _token;
  HomeSimulatorType _simulatorType = HomeSimulatorType.none;
  bool _isConnected = false;
  String? _errorMessage;
  String? _aircraftTitle;
  bool? _isPaused;
  String? _transponderState;
  String? _transponderCode;
  String? _flightNumber;
  bool? _isFuelSufficient;
  HomeChecklistPhase? _checklistPhase;
  double? _checklistProgress;
  HomeFlightData _flightData = const HomeFlightData();
  HomeAirportInfo? _destinationAirport;
  HomeAirportInfo? _alternateAirport;
  HomeAirportInfo? _nearestAirport;
  List<HomeAirportInfo> _suggestedAirports = const [];
  final Map<String, HomeMetarData> _metarsByIcao = {};
  final Map<String, String> _metarErrorsByIcao = {};
  final Set<String> _metarRefreshingIcaos = <String>{};
  final Map<String, DateTime> _metarLastAutoFetchAt = {};
  bool _isDisposed = false;
  bool _isPolling = false;

  @override
  Stream<HomeDataSnapshot> get stream => _controller.stream;

  @override
  Future<bool> connect(HomeSimulatorType type) async {
    await _httpService.init();
    _errorMessage = null;
    final simType = _toSimulatorApiType(type);
    if (simType == null) {
      _errorMessage = 'invalid_simulator_type';
      _emitSnapshot();
      return false;
    }

    try {
      if (_token != null && _token!.isNotEmpty) {
        await disconnect();
      }
      final response = await _httpService.connectSimulator(type: simType);
      final body = response.decodedBody;
      if (body is! Map<String, dynamic>) {
        _errorMessage = 'invalid_connect_response';
        _emitSnapshot();
        return false;
      }
      final token = body['token']?.toString().trim() ?? '';
      if (token.isEmpty) {
        _errorMessage = 'missing_token';
        _emitSnapshot();
        return false;
      }

      _token = token;
      _simulatorType = type;
      _isConnected = true;
      await _startRealtimeUpdates(token);
      await _pollData();
      _emitSnapshot();
      return true;
    } catch (e, stackTrace) {
      _errorMessage = _extractErrorMessage(e);
      _isConnected = false;
      _simulatorType = HomeSimulatorType.none;
      _token = null;
      _stopPolling();
      AppLogger.error('Home simulator connect failed', e, stackTrace);
      _emitSnapshot();
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    final token = _token;
    _token = null;
    await _closeWebSocket();
    _stopPolling();
    if (token != null && token.isNotEmpty) {
      try {
        await _httpService.disconnectSimulator(token: token);
      } catch (_) {}
    }
    _isConnected = false;
    _simulatorType = HomeSimulatorType.none;
    _aircraftTitle = null;
    _isPaused = null;
    _transponderState = null;
    _transponderCode = null;
    _errorMessage = null;
    _flightData = const HomeFlightData();
    _metarRefreshingIcaos.clear();
    _metarLastAutoFetchAt.clear();
    _emitSnapshot();
  }

  @override
  Future<void> setFlightNumber(String? value) async {
    _flightNumber = value?.trim().isEmpty ?? true ? null : value?.trim();
    _emitSnapshot();
  }

  @override
  Future<void> setDestination(HomeAirportInfo? airport) async {
    if (airport == null) {
      _destinationAirport = null;
      _updateFuelSufficiency();
      _emitSnapshot();
      return;
    }
    final target = _withBestCoordinates(await _resolveAirportTarget(airport));
    _destinationAirport = target;
    _addToSuggestions(target);
    await refreshMetar(target);
    _updateFuelSufficiency();
    _emitSnapshot();
  }

  @override
  Future<void> setAlternate(HomeAirportInfo? airport) async {
    if (airport == null) {
      _alternateAirport = null;
      _updateFuelSufficiency();
      _emitSnapshot();
      return;
    }
    final target = _withBestCoordinates(await _resolveAirportTarget(airport));
    _alternateAirport = target;
    _addToSuggestions(target);
    await refreshMetar(target);
    _updateFuelSufficiency();
    _emitSnapshot();
  }

  @override
  Future<List<HomeAirportInfo>> searchAirports(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return [];
    try {
      await _httpService.init();
      final response = await _httpService.getAirportSuggestions(trimmed);
      final body = response.decodedBody;
      if (body is! Map<String, dynamic>) {
        return [];
      }
      final suggestions = body['suggestions'];
      if (suggestions is! List) {
        return [];
      }
      return suggestions
          .whereType<Map<String, dynamic>>()
          .map(_airportFromSuggestion)
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> refreshMetar(HomeAirportInfo airport) async {
    final icao = airport.icaoCode.trim().toUpperCase();
    if (icao.isEmpty) return;
    if (_metarRefreshingIcaos.contains(icao)) return;
    _metarRefreshingIcaos.add(icao);
    try {
      await _httpService.init();
      final response = await _httpService.getMetarByIcao(icao);
      final body = response.decodedBody;
      if (body is! Map<String, dynamic>) {
        _metarErrorsByIcao[icao] = 'invalid_metar_response';
        _emitSnapshot();
        return;
      }
      final raw = body['raw_metar']?.toString().trim() ?? '';
      final translated = body['translated_metar']?.toString().trim() ?? '';
      final displayWind =
          _pickString(body, const ['display_wind', 'wind']) ?? '--';
      final displayVisibility =
          _pickString(body, const ['display_visibility', 'visibility']) ?? '--';
      final displayTemperature =
          _pickString(body, const ['display_temperature', 'temperature']) ??
          '--';
      final displayAltimeter =
          _pickString(body, const ['display_altimeter', 'altimeter']) ?? '--';
      final metarTimestamp =
          _toInt(body['metar_timestamp_unix']) ??
          _toInt(body['timestamp']) ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000;
      _metarsByIcao[icao] = HomeMetarData(
        raw: raw.isEmpty ? translated : raw,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          metarTimestamp * 1000,
          isUtc: true,
        ).toLocal(),
        displayWind: displayWind,
        displayVisibility: displayVisibility,
        displayTemperature: displayTemperature,
        displayAltimeter: displayAltimeter,
      );
      _metarErrorsByIcao.remove(icao);
      _emitSnapshot();
    } catch (e) {
      _metarErrorsByIcao[icao] = _extractErrorMessage(e);
      _emitSnapshot();
    } finally {
      _metarRefreshingIcaos.remove(icao);
    }
  }

  void dispose() {
    _isDisposed = true;
    _closeWebSocket();
    _stopPolling();
    _controller.close();
  }

  Future<void> _startRealtimeUpdates(String token) async {
    final connected = await _connectWebSocket(token);
    if (!connected) {
      _startPolling();
    }
  }

  Future<bool> _connectWebSocket(String token) async {
    try {
      final wsUri = await _httpService.resolveSimulatorWebSocketUri(
        token: token,
      );
      final channel = WebSocketChannel.connect(wsUri);
      await _wsSubscription?.cancel();
      await _wsChannel?.sink.close();
      _wsChannel = channel;
      _wsSubscription = channel.stream.listen(
        (event) {
          _handleWebSocketEvent(event);
        },
        onError: (_) {
          _handleWebSocketClosed();
        },
        onDone: () {
          _handleWebSocketClosed();
        },
        cancelOnError: true,
      );
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Home websocket connect failed', e, stackTrace);
      return false;
    }
  }

  void _handleWebSocketEvent(dynamic event) {
    if (event is! String) {
      return;
    }
    try {
      final payload = jsonDecode(event);
      if (payload is! Map<String, dynamic>) {
        return;
      }
      if (payload['error'] != null) {
        _errorMessage = payload['error'].toString();
        _emitSnapshot();
        return;
      }
      _applySimulatorResponseBody(payload);
    } catch (_) {}
  }

  void _handleWebSocketClosed() {
    if (_token != null && _token!.isNotEmpty && !_isDisposed) {
      _startPolling();
    }
  }

  Future<void> _closeWebSocket() async {
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    await _wsChannel?.sink.close();
    _wsChannel = null;
  }

  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      _pollData();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollData() async {
    if (_isPolling) return;
    final token = _token;
    if (token == null || token.isEmpty) return;
    _isPolling = true;
    try {
      final response = await _httpService.getSimulatorData(token: token);
      final body = response.decodedBody;
      if (body is! Map<String, dynamic>) return;
      _applySimulatorResponseBody(body);
    } catch (e, stackTrace) {
      final message = _extractErrorMessage(e);
      _errorMessage = message;
      if (_isConnectionLostError(e)) {
        _isConnected = false;
        _simulatorType = HomeSimulatorType.none;
        _token = null;
        _stopPolling();
      }
      AppLogger.error('Home simulator polling failed', e, stackTrace);
      _emitSnapshot();
    } finally {
      _isPolling = false;
    }
  }

  HomeAirportInfo _airportFromSuggestion(Map<String, dynamic> raw) {
    final icao = _pickString(raw, const ['icao', 'ICAO'])?.toUpperCase() ?? '';
    final iata = _pickString(raw, const ['iata', 'IATA']) ?? '';
    final name = _pickString(raw, const ['name', 'Name']) ?? icao;
    final latitude = _pickDouble(raw, const ['latitude', 'lat', 'Lat']) ?? 0;
    final longitude =
        _pickDouble(raw, const ['longitude', 'lon', 'lng', 'Lng', 'Lon']) ?? 0;
    return HomeAirportInfo(
      icaoCode: icao,
      iataCode: iata,
      name: name,
      nameChinese: '',
      latitude: latitude,
      longitude: longitude,
    );
  }

  void _applySimulatorResponseBody(Map<String, dynamic> body) {
    final clientDataset = body['client_dataset'];
    final rawDataset = body['raw_dataset'];
    final dataset =
        _toStringDynamicMap(clientDataset) ?? _toStringDynamicMap(rawDataset);
    if (dataset == null) {
      return;
    }
    _errorMessage = null;
    _isConnected = _toBool(dataset['connected']) ?? true;
    _isPaused = _toBool(dataset['is_paused']);
    _transponderState = _pickString(dataset, const ['transponder_state']);
    _transponderCode = _pickString(dataset, const ['transponder_code']);
    _aircraftTitle =
        dataset['aircraft_display_name']?.toString() ??
        dataset['aircraft_model']?.toString() ??
        dataset['aircraft_profile']?.toString() ??
        body['simulator_version']?.toString() ??
        _aircraftTitle;
    _flightData = _flightDataFromDataset(dataset);
    _updateFuelSufficiency();
    final nearest = dataset['nearest_airport'];
    if (nearest is Map<String, dynamic>) {
      _nearestAirport = _airportFromNearestAirport(nearest);
      if (_nearestAirport != null) {
        _addToSuggestions(_nearestAirport!);
      }
    }
    _ensureCurrentAirportMetar();
    _emitSnapshot();
  }

  void _ensureCurrentAirportMetar() {
    if (!_isConnected) return;
    final airport = _nearestAirport;
    if (airport == null) return;
    final icao = airport.icaoCode.trim().toUpperCase();
    if (icao.isEmpty) return;
    if (_metarRefreshingIcaos.contains(icao)) return;
    final now = DateTime.now();
    final metar = _metarsByIcao[icao];
    if (metar != null &&
        now.difference(metar.timestamp) <= const Duration(minutes: 15)) {
      return;
    }
    final lastAutoFetch = _metarLastAutoFetchAt[icao];
    if (lastAutoFetch != null &&
        now.difference(lastAutoFetch) <= const Duration(minutes: 2)) {
      return;
    }
    _metarLastAutoFetchAt[icao] = now;
    unawaited(refreshMetar(airport));
  }

  HomeFlightData _flightDataFromDataset(Map<String, dynamic> dataset) {
    return HomeFlightData(
      airspeed: _toDouble(dataset['ias_kt'] ?? dataset['airspeed_kt']),
      machNumber: _toDouble(dataset['mach_number']),
      trueAirspeed: _toDouble(dataset['tas_kt'] ?? dataset['true_airspeed_kt']),
      altitude: _toDouble(dataset['altitude_ft']),
      heading: _toDouble(dataset['heading_deg']),
      verticalSpeed: _toDouble(
        dataset['vertical_speed_fpm'] ?? dataset['vs_fpm'],
      ),
      gForce: _toDouble(dataset['g_force_g'] ?? dataset['g_force']),
      pitch: _toDouble(dataset['pitch_deg'] ?? dataset['pitch']),
      bank: _toDouble(
        dataset['bank_deg'] ?? dataset['roll_deg'] ?? dataset['bank'],
      ),
      angleOfAttack: _toDouble(
        dataset['aoa_deg'] ?? dataset['angle_of_attack_deg'] ?? dataset['aoa'],
      ),
      stallWarning: _toBool(
        dataset['stall_warning'] ??
            dataset['is_stalling'] ??
            dataset['stall_warning_active'],
      ),
      latitude: _toDouble(dataset['latitude']),
      longitude: _toDouble(dataset['longitude']),
      departureAirport: _pickString(dataset, const [
        'departure_airport',
        'departure_airport_icao',
        'origin_airport',
      ]),
      arrivalAirport: _pickString(dataset, const [
        'arrival_airport',
        'arrival_airport_icao',
        'destination_airport',
      ]),
      groundSpeed: _toDouble(dataset['ground_speed_kt']),
      com1Frequency: _toDouble(dataset['com1_frequency_mhz']),
      outsideAirTemperature: _toDouble(dataset['outside_temp_c']),
      totalAirTemperature: _toDouble(dataset['total_temp_c']),
      windSpeed: _toDouble(dataset['wind_speed_kt']),
      windDirection: _toDouble(dataset['wind_direction_deg']),
      baroPressure: _toDouble(dataset['baro_pressure_inhg']),
      baroPressureUnit: dataset['baro_pressure_unit']?.toString(),
      visibility: _toDouble(dataset['visibility_m']),
      numEngines: _toInt(dataset['num_engines']),
      fuelQuantity: _toDouble(dataset['fuel_quantity_kg']),
      fuelFlow: _toDouble(dataset['fuel_flow_kg_h']),
      engine1N1: _toDouble(dataset['engine1_n1']),
      engine2N1: _toDouble(dataset['engine2_n1']),
      engine1EGT: _toDouble(dataset['engine1_egt_c']),
      engine2EGT: _toDouble(dataset['engine2_egt_c']),
      masterWarning: _toBool(dataset['master_warning']),
      masterCaution: _toBool(dataset['master_caution']),
      fireWarningEngine1: _toBool(dataset['fire_warning_engine1']),
      fireWarningEngine2: _toBool(dataset['fire_warning_engine2']),
      fireWarningAPU: _toBool(dataset['fire_warning_apu']),
      beacon: _toBool(dataset['beacon']),
      strobes: _toBool(dataset['strobes']),
      navLights: _toBool(dataset['nav_lights']),
      logoLights: _toBool(dataset['logo_lights']),
      wingLights: _toBool(dataset['wing_lights']),
      landingLights: _toBool(dataset['landing_lights']),
      taxiLights: _toBool(dataset['taxi_lights']),
      runwayTurnoffLights: _toBool(dataset['runway_turnoff_lights']),
      wheelWellLights: _toBool(dataset['wheel_well_lights']),
      onGround: _toBool(dataset['on_ground']),
      parkingBrake: _toBool(dataset['parking_brake']),
      speedBrake: _toBool(dataset['speed_brake_active']),
      speedBrakeLabel: _buildSpeedBrakeLabel(dataset),
      spoilersDeployed: _toBool(dataset['spoilers_deployed']),
      autoBrakeLabel: dataset['auto_brake_label']?.toString(),
      flapsDeployed: _toBool(dataset['flaps_deployed']),
      flapsLabel: _buildFlapsLabel(dataset),
      flapsAngle: _toDouble(dataset['flaps_angle_deg']),
      flapsDeployRatio: _toDouble(dataset['flaps_deploy_ratio']),
      gearDown: _toBool(dataset['gear_down']),
      noseGearDown: _toDouble(dataset['nose_gear_down']),
      leftGearDown: _toDouble(dataset['left_gear_down']),
      rightGearDown: _toDouble(dataset['right_gear_down']),
      apuRunning: _toBool(dataset['apu_running']),
      engine1Running: _toBool(dataset['engine1_running']),
      engine2Running: _toBool(dataset['engine2_running']),
      autopilotEngaged: _toBool(dataset['autopilot_engaged']),
      autothrottleEngaged: _toBool(dataset['autothrottle_engaged']),
      aircraftProfile: dataset['aircraft_profile']?.toString(),
      aircraftId: dataset['aircraft_id']?.toString(),
      aircraftManufacturer: dataset['aircraft_manufacturer']?.toString(),
      aircraftFamily: dataset['aircraft_family']?.toString(),
      aircraftModel: dataset['aircraft_model']?.toString(),
      aircraftIcao: dataset['aircraft_icao']?.toString(),
      aircraftDisplayName: dataset['aircraft_display_name']?.toString(),
    );
  }

  HomeAirportInfo? _airportFromNearestAirport(Map<String, dynamic> raw) {
    final icao = raw['icao']?.toString().trim().toUpperCase() ?? '';
    if (icao.isEmpty) {
      return null;
    }
    final label = raw['label']?.toString().trim();
    return HomeAirportInfo(
      icaoCode: icao,
      iataCode: '',
      name: (label == null || label.isEmpty) ? icao : label,
      nameChinese: '',
      latitude: _toDouble(raw['latitude']) ?? 0,
      longitude: _toDouble(raw['longitude']) ?? 0,
    );
  }

  void _addToSuggestions(HomeAirportInfo airport) {
    final next = <HomeAirportInfo>[airport];
    for (final item in _suggestedAirports) {
      if (item.icaoCode.toUpperCase() == airport.icaoCode.toUpperCase()) {
        continue;
      }
      next.add(item);
      if (next.length >= 8) break;
    }
    _suggestedAirports = next;
  }

  Future<HomeAirportInfo> _resolveAirportTarget(HomeAirportInfo airport) async {
    final normalizedIcao = airport.icaoCode.trim().toUpperCase();
    if (normalizedIcao.isEmpty) {
      return airport;
    }
    try {
      await _httpService.init();
      final response = await _httpService.getAirportByIcao(normalizedIcao);
      final root = _toStringDynamicMap(response.decodedBody);
      if (root == null) {
        return airport;
      }
      final payload = _pickMap(root, const ['data']) ?? root;
      final detail =
          _pickMap(payload, const ['airport_detail', 'airportDetail']) ??
          payload;
      final airportMap = _pickMap(detail, const ['airport']) ?? detail;
      final icao =
          _pickString(airportMap, const ['icao', 'ICAO'])?.toUpperCase() ??
          normalizedIcao;
      final iata = _pickString(airportMap, const ['iata', 'IATA']) ?? '';
      final name =
          _pickString(airportMap, const ['name', 'Name']) ??
          _pickString(detail, const ['name', 'Name']) ??
          airport.name;
      final latitude =
          _pickDouble(airportMap, const ['latitude', 'lat', 'Lat']) ??
          _pickDouble(detail, const ['latitude', 'lat', 'Lat']) ??
          _pickDouble(payload, const ['latitude', 'lat', 'Lat']) ??
          airport.latitude;
      final longitude =
          _pickDouble(airportMap, const ['longitude', 'lon', 'lng', 'Lon']) ??
          _pickDouble(detail, const [
            'longitude',
            'lon',
            'lng',
            'Lng',
            'Lon',
          ]) ??
          _pickDouble(payload, const [
            'longitude',
            'lon',
            'lng',
            'Lng',
            'Lon',
          ]) ??
          airport.longitude;
      return HomeAirportInfo(
        icaoCode: icao,
        iataCode: iata,
        name: name,
        nameChinese: airport.nameChinese,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (_) {
      return airport;
    }
  }

  HomeAirportInfo _withBestCoordinates(HomeAirportInfo airport) {
    if (airport.latitude != 0 && airport.longitude != 0) {
      return airport;
    }
    final code = airport.icaoCode.trim().toUpperCase();
    if (code.isEmpty) {
      return airport;
    }
    final candidates = <HomeAirportInfo?>[
      _nearestAirport,
      _destinationAirport,
      _alternateAirport,
      ..._suggestedAirports,
    ];
    for (final item in candidates) {
      if (item == null) continue;
      if (item.icaoCode.trim().toUpperCase() != code) continue;
      if (item.latitude == 0 || item.longitude == 0) continue;
      return HomeAirportInfo(
        icaoCode: airport.icaoCode,
        iataCode: airport.iataCode,
        name: airport.name,
        nameChinese: airport.nameChinese,
        latitude: item.latitude,
        longitude: item.longitude,
      );
    }
    return airport;
  }

  void _updateFuelSufficiency() {
    final fuelQuantity = _flightData.fuelQuantity;
    final destination = _destinationAirport == null
        ? null
        : _withBestCoordinates(_destinationAirport!);
    if (fuelQuantity == null || destination == null) {
      _isFuelSufficient = null;
      return;
    }
    final currentLat = _flightData.latitude;
    final currentLon = _flightData.longitude;
    if (currentLat == null ||
        currentLon == null ||
        destination.latitude == 0 ||
        destination.longitude == 0) {
      _isFuelSufficient = null;
      return;
    }
    final distanceNm = _calculateDistanceNm(
      currentLat,
      currentLon,
      destination.latitude,
      destination.longitude,
    );
    final fuelPlan = _buildFuelPlan(
      distanceNm: distanceNm,
      hasAlternate: _alternateAirport != null,
    );
    _isFuelSufficient = fuelQuantity >= fuelPlan.total;
  }

  _HomeFuelPlan _buildFuelPlan({
    required double distanceNm,
    required bool hasAlternate,
  }) {
    final trip = distanceNm * 2.5;
    final alternate = hasAlternate ? 200 * 2.5 : 0.0;
    const reserve = 1500.0;
    const taxi = 200.0;
    final extra = trip * 0.05;
    final total = trip + alternate + reserve + taxi + extra;
    return _HomeFuelPlan(total: total);
  }

  double _calculateDistanceNm(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
  ) {
    const earthRadiusKm = 6371.0;
    final lat1 = _toRadians(startLat);
    final lon1 = _toRadians(startLon);
    final lat2 = _toRadians(endLat);
    final lon2 = _toRadians(endLon);
    final deltaLat = lat2 - lat1;
    final deltaLon = lon2 - lon1;
    final a =
        _pow2(_sin(deltaLat / 2)) +
        _cos(lat1) * _cos(lat2) * _pow2(_sin(deltaLon / 2));
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    final km = earthRadiusKm * c;
    return km * 0.539956803;
  }

  double _toRadians(double degree) => degree * 0.017453292519943295;
  double _sin(double value) => math.sin(value);
  double _cos(double value) => math.cos(value);
  double _sqrt(double value) => math.sqrt(value);
  double _atan2(double y, double x) => math.atan2(y, x);
  double _pow2(double value) => value * value;

  void _emitSnapshot() {
    if (_isDisposed || _controller.isClosed) return;
    _controller.add(
      HomeDataSnapshot(
        isConnected: _isConnected,
        simulatorType: _simulatorType,
        errorMessage: _errorMessage,
        aircraftTitle: _aircraftTitle,
        isPaused: _isPaused,
        transponderState: _transponderState,
        transponderCode: _transponderCode,
        flightNumber: _flightNumber,
        isFuelSufficient: _isFuelSufficient,
        checklistPhase: _checklistPhase,
        checklistProgress: _checklistProgress,
        flightData: _flightData,
        destinationAirport: _destinationAirport,
        alternateAirport: _alternateAirport,
        nearestAirport: _nearestAirport,
        suggestedAirports: _suggestedAirports,
        metarsByIcao: Map<String, HomeMetarData>.from(_metarsByIcao),
        metarErrorsByIcao: Map<String, String>.from(_metarErrorsByIcao),
      ),
    );
  }

  String? _toSimulatorApiType(HomeSimulatorType type) {
    return switch (type) {
      HomeSimulatorType.xplane => 'xplane',
      HomeSimulatorType.msfs => 'msfs',
      HomeSimulatorType.none => null,
    };
  }

  bool _isConnectionLostError(Object error) {
    if (error is! MiddlewareHttpException) return false;
    final status = error.statusCode;
    return status == 401 || status == 409;
  }

  String _extractErrorMessage(Object error) {
    if (error is MiddlewareHttpException) {
      final data = error.data;
      if (data is Map<String, dynamic>) {
        final errorMessage = data['error']?.toString().trim();
        if (errorMessage != null && errorMessage.isNotEmpty) {
          return errorMessage;
        }
      }
      return error.message;
    }
    return error.toString();
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String? _pickString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      if (map.containsKey(key)) {
        final value = map[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }
    for (final key in keys) {
      for (final entry in map.entries) {
        if (entry.key.toLowerCase() == key.toLowerCase()) {
          final value = entry.value?.toString().trim();
          if (value != null && value.isNotEmpty) return value;
        }
      }
    }
    return null;
  }

  Map<String, dynamic>? _pickMap(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      if (map.containsKey(key)) {
        final value = _toStringDynamicMap(map[key]);
        if (value != null) return value;
      }
    }
    for (final key in keys) {
      for (final entry in map.entries) {
        if (entry.key.toLowerCase() == key.toLowerCase()) {
          final value = _toStringDynamicMap(entry.value);
          if (value != null) return value;
        }
      }
    }
    return null;
  }

  double? _pickDouble(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      if (map.containsKey(key)) {
        final value = _toDouble(map[key]);
        if (value != null) return value;
      }
    }
    for (final key in keys) {
      for (final entry in map.entries) {
        if (entry.key.toLowerCase() == key.toLowerCase()) {
          final value = _toDouble(entry.value);
          if (value != null) return value;
        }
      }
    }
    return null;
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  bool? _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase();
    if (text == 'true') return true;
    if (text == 'false') return false;
    return null;
  }

  Map<String, dynamic>? _toStringDynamicMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return null;
  }

  String? _buildSpeedBrakeLabel(Map<String, dynamic> dataset) {
    final ratio = _toDouble(dataset['speed_brake_ratio']);
    if (ratio == null) return null;
    return '${(ratio * 100).toStringAsFixed(0)}%';
  }

  String? _buildFlapsLabel(Map<String, dynamic> dataset) {
    final angle = _toDouble(dataset['flaps_angle_deg']);
    if (angle != null) {
      return '${angle.toStringAsFixed(0)}°';
    }
    final ratio = _toDouble(dataset['flaps_deploy_ratio']);
    if (ratio != null) {
      return '${(ratio * 100).toStringAsFixed(0)}%';
    }
    return null;
  }
}

class _HomeFuelPlan {
  final double total;

  const _HomeFuelPlan({required this.total});
}
