import 'dart:async';
import 'package:flutter/material.dart';
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
  String? _token;
  HomeSimulatorType _simulatorType = HomeSimulatorType.none;
  bool _isConnected = false;
  String? _errorMessage;
  String? _aircraftTitle;
  bool? _isPaused;
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
      _startPolling();
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
    _stopPolling();
    final token = _token;
    _token = null;
    if (token != null && token.isNotEmpty) {
      try {
        await _httpService.disconnectSimulator(token: token);
      } catch (_) {}
    }
    _isConnected = false;
    _simulatorType = HomeSimulatorType.none;
    _aircraftTitle = null;
    _isPaused = null;
    _errorMessage = null;
    _flightData = const HomeFlightData();
    _emitSnapshot();
  }

  @override
  Future<void> setFlightNumber(String? value) async {
    _flightNumber = value?.trim().isEmpty ?? true ? null : value?.trim();
    _emitSnapshot();
  }

  @override
  Future<void> setDestination(HomeAirportInfo? airport) async {
    _destinationAirport = airport;
    if (airport != null) {
      _addToSuggestions(airport);
      await refreshMetar(airport);
    }
    _emitSnapshot();
  }

  @override
  Future<void> setAlternate(HomeAirportInfo? airport) async {
    _alternateAirport = airport;
    if (airport != null) {
      _addToSuggestions(airport);
      await refreshMetar(airport);
    }
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
      _metarsByIcao[icao] = HomeMetarData(
        raw: raw.isEmpty ? translated : raw,
        timestamp: DateTime.now(),
        displayWind: translated.isEmpty ? '--' : translated,
        displayVisibility: '--',
        displayTemperature: '--',
        displayAltimeter: '--',
      );
      _metarErrorsByIcao.remove(icao);
      _emitSnapshot();
    } catch (e) {
      _metarErrorsByIcao[icao] = _extractErrorMessage(e);
      _emitSnapshot();
    }
  }

  void dispose() {
    _isDisposed = true;
    _stopPolling();
    _controller.close();
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
      final dataset = body['raw_dataset'];
      if (dataset is! Map<String, dynamic>) return;
      _errorMessage = null;
      _isConnected = dataset['connected'] == true;
      _flightData = _flightDataFromDataset(dataset);
      _aircraftTitle ??= body['simulator_version']?.toString();
      _emitSnapshot();
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
    final icao = raw['ICAO']?.toString().trim().toUpperCase() ?? '';
    final name = raw['Name']?.toString().trim() ?? icao;
    return HomeAirportInfo(
      icaoCode: icao,
      iataCode: '',
      name: name,
      nameChinese: '',
      latitude: 0,
      longitude: 0,
    );
  }

  HomeFlightData _flightDataFromDataset(Map<String, dynamic> dataset) {
    return HomeFlightData(
      airspeed: _toDouble(dataset['airspeed_kt']),
      trueAirspeed: _toDouble(dataset['true_airspeed_kt']),
      altitude: _toDouble(dataset['altitude_ft']),
      heading: _toDouble(dataset['heading_deg']),
      verticalSpeed: _toDouble(dataset['vertical_speed_fpm']),
      latitude: _toDouble(dataset['latitude']),
      longitude: _toDouble(dataset['longitude']),
      groundSpeed: _toDouble(dataset['ground_speed_kt']),
      onGround: _toBool(dataset['on_ground']),
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

  void _emitSnapshot() {
    if (_isDisposed || _controller.isClosed) return;
    _controller.add(
      HomeDataSnapshot(
        isConnected: _isConnected,
        simulatorType: _simulatorType,
        errorMessage: _errorMessage,
        aircraftTitle: _aircraftTitle,
        isPaused: _isPaused,
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
      HomeSimulatorType.xp11 => 'xp11',
      HomeSimulatorType.xp12 => 'xp12',
      HomeSimulatorType.msfs2020 => 'msfs2020',
      HomeSimulatorType.msfs2024 => 'msfs2024',
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

  bool? _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase();
    if (text == 'true') return true;
    if (text == 'false') return false;
    return null;
  }
}
