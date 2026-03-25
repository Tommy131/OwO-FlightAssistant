import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/module_registry/navigation/navigation_registry.dart';
import '../../../core/services/persistence_service.dart';
import '../../../core/utils/logger.dart';
import '../../http/models/http_models.dart';
import '../../http/services/middleware_http_service.dart';
import '../models/common_models.dart';
import 'flight_data_adapter.dart';

/// Middleware 后端飞行数据适配器
///
/// 通过 HTTP 轮询或 WebSocket 实时推送从后端获取模拟器数据，
/// 并将原始响应转换为标准 [FlightDataSnapshot]。
///
/// 主要职责：
///   - WebSocket 连接管理（含自动回退到轮询）
///   - 后端健康监控与掉线处理
///   - METAR 气象数据刷新（含速率限制）
///   - 油量充足性计算（Haversine 大圆距离）
class MiddlewareFlightDataAdapter implements FlightDataAdapter {
  static const Duration _backendMonitorInterval = Duration(seconds: 2);
  static const Duration _backendDisconnectGracePeriod = Duration(seconds: 10);
  static const String _pollIntervalMsKey = 'middleware_flight_data_interval_ms';
  static const int defaultPollIntervalMs = 300;
  static const int minPollIntervalMs = 100;
  static const int maxPollIntervalMs = 2000;

  MiddlewareFlightDataAdapter({
    MiddlewareHttpService? httpService,
    Duration? pollInterval,
  }) : _httpService = httpService ?? MiddlewareHttpService(),
       _pollIntervalMs = _sanitizePollIntervalMs(
         pollInterval?.inMilliseconds ?? defaultPollIntervalMs,
       );

  final MiddlewareHttpService _httpService;
  int _pollIntervalMs;
  final StreamController<FlightDataSnapshot> _controller =
      StreamController<FlightDataSnapshot>.broadcast();

  Timer? _pollTimer;
  WebSocketChannel? _wsChannel;
  StreamSubscription<dynamic>? _wsSubscription;
  String? _token;
  SimulatorType _simulatorType = SimulatorType.none;
  bool _isConnected = false;
  String? _errorMessage;
  String? _aircraftTitle;
  bool? _isPaused;
  String? _transponderState;
  String? _transponderCode;
  String? _flightNumber;
  bool? _isFuelSufficient;
  FlightChecklistPhase? _checklistPhase;
  double? _checklistProgress;
  FlightData _flightData = const FlightData();
  AirportInfo? _departureAirport;
  AirportInfo? _destinationAirport;
  AirportInfo? _alternateAirport;
  AirportInfo? _nearestAirport;
  List<AirportInfo> _suggestedAirports = const [];
  final Map<String, LiveMetarData> _metarsByIcao = {};
  final Map<String, String> _metarErrorsByIcao = {};
  final Set<String> _metarRefreshingIcaos = <String>{};
  final Map<String, DateTime> _metarLastAutoFetchAt = {};
  bool _isDisposed = false;
  bool _isPolling = false;
  bool _isBackendReachable = false;
  Future<bool>? _checkingBackendHealthTask;
  Timer? _backendHealthMonitorTimer;
  bool _isMonitorChecking = false;
  bool _isBackendDisconnectHandled = false;
  DateTime? _lastBackendReachableAt;
  int _backendOutageVersion = 0;

  @override
  Stream<FlightDataSnapshot> get stream => _controller.stream;

  @override
  Future<bool> connect(SimulatorType type) async {
    await _httpService.init();
    await _loadPollIntervalFromStorage();
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
      _simulatorType = SimulatorType.none;
      _token = null;
      _stopPolling();
      AppLogger.error('FlightData simulator connect failed', e, stackTrace);
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
    _simulatorType = SimulatorType.none;
    _aircraftTitle = null;
    _isPaused = null;
    _transponderState = null;
    _transponderCode = null;
    _errorMessage = null;
    _flightData = const FlightData();
    _metarRefreshingIcaos.clear();
    _metarLastAutoFetchAt.clear();
    _stopBackendHealthMonitor();
    _isBackendDisconnectHandled = false;
    _lastBackendReachableAt = null;
    _emitSnapshot();
  }

  @override
  Future<void> setFlightNumber(String? value) async {
    _flightNumber = value?.trim().isEmpty ?? true ? null : value?.trim();
    _emitSnapshot();
  }

  @override
  Future<void> setDeparture(AirportInfo? airport) async {
    if (airport == null) {
      _departureAirport = null;
      _emitSnapshot();
      return;
    }
    final target = _withBestCoordinates(await _resolveAirportTarget(airport));
    _departureAirport = target;
    _addToSuggestions(target);
    await refreshMetar(target);
    _emitSnapshot();
  }

  @override
  Future<void> setDestination(AirportInfo? airport) async {
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
  Future<void> setAlternate(AirportInfo? airport) async {
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
  Future<List<AirportInfo>> searchAirports(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return [];
    try {
      await _httpService.init();
      final response = await _httpService.getAirportSuggestions(trimmed);
      final body = response.decodedBody;
      if (body is! Map<String, dynamic>) return [];
      final suggestions = body['suggestions'];
      if (suggestions is! List) return [];
      return suggestions
          .whereType<Map<String, dynamic>>()
          .map(_airportFromSuggestion)
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> refreshMetar(AirportInfo airport) async {
    final icao = airport.icaoCode.trim().toUpperCase();
    if (icao.isEmpty) return;
    if (_metarRefreshingIcaos.contains(icao)) return;
    _metarRefreshingIcaos.add(icao);
    _emitSnapshot();
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
      _metarsByIcao[icao] = LiveMetarData(
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
      _emitSnapshot();
    }
  }

  /// 释放所有资源（WebSocket、定时器、Stream）
  void dispose() {
    _isDisposed = true;
    _stopBackendHealthMonitor();
    _closeWebSocket();
    _stopPolling();
    _controller.close();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 后端健康监控
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Future<bool> refreshBackendHealth() async => _checkBackendHealth();

  Future<bool> _checkBackendHealth() async {
    if (_isDisposed) return false;
    final inFlightTask = _checkingBackendHealthTask;
    if (inFlightTask != null) return inFlightTask;
    final task = _performBackendHealthCheck();
    _checkingBackendHealthTask = task;
    try {
      return await task;
    } finally {
      if (identical(_checkingBackendHealthTask, task)) {
        _checkingBackendHealthTask = null;
      }
    }
  }

  Future<bool> _performBackendHealthCheck() async {
    try {
      await _httpService.init();
      await _httpService.getHealth();
      _updateBackendHealth(true);
      return true;
    } catch (_) {
      _updateBackendHealth(false);
      return false;
    }
  }

  void _updateBackendHealth(bool reachable) {
    if (reachable) {
      _lastBackendReachableAt = DateTime.now();
      _isBackendDisconnectHandled = false;
      if (_backendHealthMonitorTimer == null) _startBackendHealthMonitor();
    }
    if (_isBackendReachable == reachable) return;
    _isBackendReachable = reachable;
    _emitSnapshot();
  }

  void _startBackendHealthMonitor() {
    _backendHealthMonitorTimer?.cancel();
    _backendHealthMonitorTimer = Timer.periodic(_backendMonitorInterval, (_) {
      unawaited(_monitorBackendHealth());
    });
  }

  void _stopBackendHealthMonitor() {
    _backendHealthMonitorTimer?.cancel();
    _backendHealthMonitorTimer = null;
    _isMonitorChecking = false;
  }

  Future<void> _monitorBackendHealth() async {
    if (_isDisposed || _isBackendDisconnectHandled || _isMonitorChecking) {
      return;
    }
    if (_lastBackendReachableAt == null) return;
    _isMonitorChecking = true;
    try {
      final reachable = await _performBackendHealthCheck();
      if (reachable) return;
      final lastReachableAt = _lastBackendReachableAt;
      if (lastReachableAt == null) return;
      final disconnectedDuration = DateTime.now().difference(lastReachableAt);
      if (disconnectedDuration < _backendDisconnectGracePeriod) return;
      _isBackendDisconnectHandled = true;
      _stopBackendHealthMonitor();
      _backendOutageVersion += 1;
      _emitSnapshot();
      NavigationCommandBus().goTo('home');
    } finally {
      _isMonitorChecking = false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 轮询间隔配置
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Future<int> getFlightDataIntervalMs() async {
    await _loadPollIntervalFromStorage();
    return _pollIntervalMs;
  }

  @override
  Future<void> setFlightDataIntervalMs(int milliseconds) async {
    final next = _sanitizePollIntervalMs(milliseconds);
    _pollIntervalMs = next;
    final persistence = PersistenceService();
    if (!persistence.isInitialized) await persistence.ensureReady();
    await persistence.setInt(_pollIntervalMsKey, next);
    if (_pollTimer != null) _startPolling();
  }

  Future<void> _loadPollIntervalFromStorage() async {
    final persistence = PersistenceService();
    if (!persistence.isInitialized) await persistence.ensureReady();
    final stored = persistence.getInt(_pollIntervalMsKey);
    _pollIntervalMs = _sanitizePollIntervalMs(stored ?? _pollIntervalMs);
  }

  static int _sanitizePollIntervalMs(int value) {
    if (value < minPollIntervalMs) return minPollIntervalMs;
    if (value > maxPollIntervalMs) return maxPollIntervalMs;
    return value;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // WebSocket 与轮询
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _startRealtimeUpdates(String token) async {
    final connected = await _connectWebSocket(token);
    if (!connected) _startPolling(minIntervalMs: 1000);
  }

  Future<bool> _connectWebSocket(String token) async {
    try {
      final wsUri = await _httpService.resolveSimulatorWebSocketUri(
        token: token,
      );
      final channel = WebSocketChannel.connect(wsUri);
      await _wsSubscription?.cancel();
      _wsSubscription = null;
      await _safeCloseChannel(_wsChannel);
      _wsChannel = channel;
      await _awaitChannelReady(channel);
      _wsSubscription = channel.stream.listen(
        _handleWebSocketEvent,
        onError: (_) => _handleWebSocketClosed(),
        onDone: _handleWebSocketClosed,
        cancelOnError: true,
      );
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('FlightData websocket connect failed', e, stackTrace);
      return false;
    }
  }

  void _handleWebSocketEvent(dynamic event) {
    if (event is! String) return;
    try {
      final payload = jsonDecode(event);
      if (payload is! Map<String, dynamic>) return;
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
      _startPolling(minIntervalMs: 1000);
    }
  }

  Future<void> _closeWebSocket() async {
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    await _safeCloseChannel(_wsChannel);
    _wsChannel = null;
  }

  Future<void> _safeCloseChannel(WebSocketChannel? channel) async {
    if (channel == null) return;
    try {
      await channel.sink.close();
    } catch (_) {}
  }

  Future<void> _awaitChannelReady(WebSocketChannel channel) async {
    try {
      final dynamic readyFuture = (channel as dynamic).ready;
      if (readyFuture is Future) {
        await readyFuture;
      }
    } catch (_) {}
  }

  void _startPolling({int? minIntervalMs}) {
    _stopPolling();
    final intervalMs = minIntervalMs == null
        ? _pollIntervalMs
        : (_pollIntervalMs < minIntervalMs ? minIntervalMs : _pollIntervalMs);
    final interval = Duration(milliseconds: intervalMs);
    _pollTimer = Timer.periodic(interval, (_) => _pollData());
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
      _errorMessage = _extractErrorMessage(e);
      if (_isConnectionLostError(e)) {
        _isConnected = false;
        _simulatorType = SimulatorType.none;
        _token = null;
        _stopPolling();
      }
      AppLogger.error('FlightData simulator polling failed', e, stackTrace);
      _emitSnapshot();
    } finally {
      _isPolling = false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 数据解析
  // ──────────────────────────────────────────────────────────────────────────

  void _applySimulatorResponseBody(Map<String, dynamic> body) {
    final clientDataset = body['client_dataset'];
    final rawDataset = body['raw_dataset'];
    final clientMap = _toStringDynamicMap(clientDataset);
    final rawMap = _toStringDynamicMap(rawDataset);
    if (clientMap == null && rawMap == null) return;
    final dataset = <String, dynamic>{...?rawMap, ...?clientMap};
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
      if (_nearestAirport != null) _addToSuggestions(_nearestAirport!);
    }
    _ensureCurrentAirportMetar();
    _emitSnapshot();
  }

  /// 按需自动刷新最近机场 METAR（每15分钟一次，防抖2分钟）
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

  FlightData _flightDataFromDataset(Map<String, dynamic> dataset) {
    final noseGearDown = _toDouble(dataset['nose_gear_down']);
    final leftGearDown = _toDouble(dataset['left_gear_down']);
    final rightGearDown = _toDouble(dataset['right_gear_down']);
    final gearDown = _resolveGearDownState(
      directState: _toBool(dataset['gear_down']),
      noseGearDown: noseGearDown,
      leftGearDown: leftGearDown,
      rightGearDown: rightGearDown,
    );
    return FlightData(
      airspeed: _toDouble(dataset['ias_kt'] ?? dataset['airspeed_kt']),
      machNumber: _toDouble(dataset['mach_number']),
      trueAirspeed: _toDouble(dataset['tas_kt'] ?? dataset['true_airspeed_kt']),
      altitude: _toDouble(dataset['altitude_ft']),
      heading: _toDouble(dataset['heading_deg']),
      verticalSpeed: _toDouble(
        dataset['vertical_speed_fpm'] ?? dataset['vs_fpm'],
      ),
      gForce: _toDouble(dataset['g_force_g'] ?? dataset['g_force']),
      touchdownGearG: _toDouble(dataset['touchdown_gear_g']),
      noseGearG: _toDouble(dataset['nose_gear_g']),
      leftGearG: _toDouble(dataset['left_gear_g']),
      rightGearG: _toDouble(dataset['right_gear_g']),
      pitch: _readAngleDegrees(
        dataset,
        degreeKeys: const ['pitch_deg'],
        fallbackKeys: const ['pitch'],
      ),
      bank: _readAngleDegrees(
        dataset,
        degreeKeys: const ['bank_deg', 'roll_deg'],
        fallbackKeys: const ['bank', 'roll'],
      ),
      angleOfAttack: _readAngleDegrees(
        dataset,
        degreeKeys: const [
          'aoa_deg',
          'angle_of_attack_deg',
          'alpha_deg',
          'angleofattack_deg',
        ],
        fallbackKeys: const [
          'aoa',
          'angle_of_attack',
          'alpha',
          'angleofattack',
        ],
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
      windGust: _toDouble(dataset['wind_gust_kt']),
      gustDelta: _toDouble(dataset['gust_delta_kt']),
      gustFactorRate: _toDouble(dataset['gust_factor_rate']),
      crosswindComponent: _toDouble(dataset['crosswind_component_kt']),
      radioAltitude: _toDouble(dataset['radio_altitude_ft']),
      baroPressure: _toDouble(dataset['baro_pressure_inhg']),
      baroPressureUnit: dataset['baro_pressure_unit']?.toString(),
      visibility: _toDouble(dataset['visibility_m']),
      numEngines: _toInt(dataset['num_engines']),
      fuelQuantity: _toDouble(dataset['fuel_quantity_kg']),
      fuelFlow: _toDouble(dataset['fuel_flow_kg_h']),
      engine1N1: _toDouble(dataset['engine1_n1']),
      engine2N1: _toDouble(dataset['engine2_n1']),
      engine1N2: _toDouble(dataset['engine1_n2']),
      engine2N2: _toDouble(dataset['engine2_n2']),
      engine1EGT: _toDouble(dataset['engine1_egt_c']),
      engine2EGT: _toDouble(dataset['engine2_egt_c']),
      aileronInput: _toDouble(dataset['aileron_input']),
      elevatorInput: _toDouble(dataset['elevator_input']),
      rudderInput: _toDouble(dataset['rudder_input']),
      aileronTrim: _toDouble(dataset['aileron_trim']),
      elevatorTrim: _toDouble(dataset['elevator_trim']),
      rudderTrim: _toDouble(dataset['rudder_trim']),
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
      gearDown: gearDown,
      noseGearDown: noseGearDown,
      leftGearDown: leftGearDown,
      rightGearDown: rightGearDown,
      apuRunning: _toBool(dataset['apu_running']),
      engine1Running: _toBool(dataset['engine1_running']),
      engine2Running: _toBool(dataset['engine2_running']),
      autopilotEngaged: _toBool(dataset['autopilot_engaged']),
      autothrottleEngaged: _toBool(dataset['autothrottle_engaged']),
      autopilotHeadingTarget: _toDouble(
        dataset['autopilot_heading_target_deg'] ?? dataset['heading_target'],
      ),
      autopilotLateralMode: _pickString(dataset, const [
        'autopilot_lateral_mode',
      ]),
      autopilotVerticalMode: _pickString(dataset, const [
        'autopilot_vertical_mode',
      ]),
      aircraftProfile: dataset['aircraft_profile']?.toString(),
      aircraftId: dataset['aircraft_id']?.toString(),
      aircraftManufacturer: dataset['aircraft_manufacturer']?.toString(),
      aircraftFamily: dataset['aircraft_family']?.toString(),
      aircraftModel: dataset['aircraft_model']?.toString(),
      aircraftIcao: dataset['aircraft_icao']?.toString(),
      aircraftDisplayName: dataset['aircraft_display_name']?.toString(),
      flightPhase: _pickString(dataset, const ['flight_phase']),
      flightAlertLevel: _pickString(dataset, const ['flight_alert_level']),
      flightAlerts: _parseFlightAlerts(dataset['flight_alerts']),
      aiAircraft: _parseAIAircraft(dataset['ai_aircraft']),
    );
  }

  List<AIAircraftState> _parseAIAircraft(dynamic raw) {
    if (raw is! List) {
      return const [];
    }
    final result = <AIAircraftState>[];
    for (final item in raw) {
      final map = _toStringDynamicMap(item);
      if (map == null) {
        continue;
      }
      final latitude = _toDouble(map['latitude']);
      final longitude = _toDouble(map['longitude']);
      if (latitude == null || longitude == null) {
        continue;
      }
      if (latitude < -90 ||
          latitude > 90 ||
          longitude < -180 ||
          longitude > 180) {
        continue;
      }
      final id = map['id']?.toString().trim();
      result.add(
        AIAircraftState(
          id: (id == null || id.isEmpty) ? 'AI-${result.length + 1}' : id,
          type: map['type']?.toString().trim(),
          latitude: latitude,
          longitude: longitude,
          altitude: _toDouble(map['altitude_ft']),
          heading: _toDouble(map['heading_deg']),
          groundSpeed: _toDouble(map['ground_speed_kt']),
          onGround: _toBool(map['on_ground']),
        ),
      );
    }
    return result;
  }

  AirportInfo _airportFromSuggestion(Map<String, dynamic> raw) {
    final icao = _pickString(raw, const ['icao', 'ICAO'])?.toUpperCase() ?? '';
    final iata = _pickString(raw, const ['iata', 'IATA']) ?? '';
    final name = _pickString(raw, const ['name', 'Name']) ?? icao;
    final latitude = _pickDouble(raw, const ['latitude', 'lat', 'Lat']) ?? 0;
    final longitude =
        _pickDouble(raw, const ['longitude', 'lon', 'lng', 'Lng', 'Lon']) ?? 0;
    return AirportInfo(
      icaoCode: icao,
      iataCode: iata,
      name: name,
      nameChinese: '',
      latitude: latitude,
      longitude: longitude,
    );
  }

  AirportInfo? _airportFromNearestAirport(Map<String, dynamic> raw) {
    final icao = raw['icao']?.toString().trim().toUpperCase() ?? '';
    if (icao.isEmpty) return null;
    final label = raw['label']?.toString().trim();
    return AirportInfo(
      icaoCode: icao,
      iataCode: '',
      name: (label == null || label.isEmpty) ? icao : label,
      nameChinese: '',
      latitude: _toDouble(raw['latitude']) ?? 0,
      longitude: _toDouble(raw['longitude']) ?? 0,
    );
  }

  void _addToSuggestions(AirportInfo airport) {
    final next = <AirportInfo>[airport];
    for (final item in _suggestedAirports) {
      if (item.icaoCode.toUpperCase() == airport.icaoCode.toUpperCase()) {
        continue;
      }
      next.add(item);
      if (next.length >= 8) break;
    }
    _suggestedAirports = next;
  }

  Future<AirportInfo> _resolveAirportTarget(AirportInfo airport) async {
    final normalizedIcao = airport.icaoCode.trim().toUpperCase();
    if (normalizedIcao.isEmpty) return airport;
    try {
      await _httpService.init();
      final response = await _httpService.getAirportByIcao(normalizedIcao);
      final root = _toStringDynamicMap(response.decodedBody);
      if (root == null) return airport;
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
      return AirportInfo(
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

  /// 若坐标为 (0,0) 则从已知机场列表中补充坐标
  AirportInfo _withBestCoordinates(AirportInfo airport) {
    if (airport.latitude != 0 && airport.longitude != 0) return airport;
    final code = airport.icaoCode.trim().toUpperCase();
    if (code.isEmpty) return airport;
    final candidates = <AirportInfo?>[
      _nearestAirport,
      _departureAirport,
      _destinationAirport,
      _alternateAirport,
      ..._suggestedAirports,
    ];
    for (final item in candidates) {
      if (item == null) continue;
      if (item.icaoCode.trim().toUpperCase() != code) continue;
      if (item.latitude == 0 || item.longitude == 0) continue;
      return AirportInfo(
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

  // ──────────────────────────────────────────────────────────────────────────
  // 油量充足性计算
  // ──────────────────────────────────────────────────────────────────────────

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

  _FuelPlan _buildFuelPlan({
    required double distanceNm,
    required bool hasAlternate,
  }) {
    final trip = distanceNm * 2.5;
    final alternate = hasAlternate ? 200 * 2.5 : 0.0;
    const reserve = 1500.0;
    const taxi = 200.0;
    final extra = trip * 0.05;
    return _FuelPlan(total: trip + alternate + reserve + taxi + extra);
  }

  /// Haversine 公式计算两点间大圆距离（海里）
  double _calculateDistanceNm(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
  ) {
    const earthRadiusKm = 6371.0;
    final lat1 = startLat * 0.017453292519943295;
    final lon1 = startLon * 0.017453292519943295;
    final lat2 = endLat * 0.017453292519943295;
    final lon2 = endLon * 0.017453292519943295;
    final deltaLat = lat2 - lat1;
    final deltaLon = lon2 - lon1;
    final a =
        (math.sin(deltaLat / 2) * math.sin(deltaLat / 2)) +
        (math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2));
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c * 0.539956803;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 快照推送
  // ──────────────────────────────────────────────────────────────────────────

  void _emitSnapshot() {
    if (_isDisposed || _controller.isClosed) return;
    _controller.add(
      FlightDataSnapshot(
        isConnected: _isConnected,
        isBackendReachable: _isBackendReachable,
        backendOutageVersion: _backendOutageVersion,
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
        departureAirport: _departureAirport,
        destinationAirport: _destinationAirport,
        alternateAirport: _alternateAirport,
        nearestAirport: _nearestAirport,
        suggestedAirports: _suggestedAirports,
        metarsByIcao: Map<String, LiveMetarData>.from(_metarsByIcao),
        metarErrorsByIcao: Map<String, String>.from(_metarErrorsByIcao),
        metarRefreshingIcaos: Set<String>.from(_metarRefreshingIcaos),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 工具方法
  // ──────────────────────────────────────────────────────────────────────────

  String? _toSimulatorApiType(SimulatorType type) {
    return switch (type) {
      SimulatorType.xplane => 'xplane',
      SimulatorType.msfs => 'msfs',
      SimulatorType.none => null,
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
        final msg = data['error']?.toString().trim();
        if (msg != null && msg.isNotEmpty) return msg;
      }
      return error.message;
    }
    return error.toString();
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
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

  double? _readAngleDegrees(
    Map<String, dynamic> map, {
    required List<String> degreeKeys,
    required List<String> fallbackKeys,
  }) {
    final degree = _pickDouble(map, degreeKeys);
    if (degree != null) return degree;
    return _normalizeAngleDegrees(_pickDouble(map, fallbackKeys));
  }

  double? _normalizeAngleDegrees(double? value) {
    if (value == null) return null;
    // 小于 3.2 认为是弧度制，自动转换为度
    if (value.abs() <= 3.2) return value * 57.29577951308232;
    return value;
  }

  Map<String, dynamic>? _toStringDynamicMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return null;
  }

  List<FlightAlert> _parseFlightAlerts(dynamic value) {
    if (value is! List) return const [];
    final alerts = <FlightAlert>[];
    for (final item in value) {
      final map = _toStringDynamicMap(item);
      if (map == null) continue;
      final id = _pickString(map, const ['id']) ?? '';
      final level = _pickString(map, const ['level']) ?? '';
      final message = _pickString(map, const ['message']) ?? '';
      if (id.isEmpty && message.isEmpty) continue;
      alerts.add(FlightAlert(id: id, level: level, message: message));
    }
    return alerts;
  }

  String? _buildSpeedBrakeLabel(Map<String, dynamic> dataset) {
    final ratio = _toDouble(dataset['speed_brake_ratio']);
    if (ratio == null) return null;
    return '${(ratio * 100).toStringAsFixed(0)}%';
  }

  String? _buildFlapsLabel(Map<String, dynamic> dataset) {
    final angle = _toDouble(dataset['flaps_angle_deg']);
    if (angle != null) return '${angle.toStringAsFixed(0)}°';
    final ratio = _toDouble(dataset['flaps_deploy_ratio']);
    if (ratio != null) return '${(ratio * 100).toStringAsFixed(0)}%';
    return null;
  }

  bool? _resolveGearDownState({
    required bool? directState,
    required double? noseGearDown,
    required double? leftGearDown,
    required double? rightGearDown,
  }) {
    final inferred = _inferGearDownStateFromRatio(
      noseGearDown: noseGearDown,
      leftGearDown: leftGearDown,
      rightGearDown: rightGearDown,
    );
    return inferred ?? directState;
  }

  bool? _inferGearDownStateFromRatio({
    required double? noseGearDown,
    required double? leftGearDown,
    required double? rightGearDown,
  }) {
    final ratios = <double>[];
    for (final raw in [noseGearDown, leftGearDown, rightGearDown]) {
      final normalized = _normalizeGearRatio(raw);
      if (normalized != null) ratios.add(normalized);
    }
    if (ratios.isEmpty) return null;
    final average = ratios.reduce((a, b) => a + b) / ratios.length;
    return average >= 0.5;
  }

  double? _normalizeGearRatio(double? value) {
    if (value == null || value.isNaN || !value.isFinite) return null;
    if (value >= 0 && value <= 1) return value;
    if (value > 1 && value <= 100) return value / 100;
    return null;
  }
}

/// 内部燃油计划辅助模型
class _FuelPlan {
  final double total;
  const _FuelPlan({required this.total});
}
