import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/simulator_data.dart';
import '../../services/msfs_service.dart';
import '../../services/xplane_service.dart';
import '../../data/airports_database.dart';
import '../../data/aircraft_catalog.dart';
import 'dart:math' as math;

import 'chart_history_mixin.dart';
import 'weather_sync_mixin.dart';

enum SimulatorType { none, msfs, xplane }

enum ConnectionStatus { disconnected, connecting, connected, error }

class SimulatorProvider
    with ChangeNotifier, WeatherSyncMixin, ChartHistoryMixin {
  final MSFSService _msfsService = MSFSService();
  final XPlaneService _xplaneService = XPlaneService();

  SimulatorType _currentSimulator = SimulatorType.none;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  SimulatorData _simulatorData = SimulatorData.empty();
  String? _errorMessage;
  AirportInfo? _destinationAirport;

  XPlaneService get xplaneService => _xplaneService;
  MSFSService get msfsService => _msfsService;
  AirportInfo? _alternateAirport;
  StreamSubscription<SimulatorData>? _dataSubscription;
  Timer? _weatherTimer;

  SimulatorProvider() {
    // Start a periodic timer to check for METAR expiration every minute
    _weatherTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _syncWeatherState();
    });
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _weatherTimer?.cancel();
    disconnect();
    super.dispose();
  }

  SimulatorType get currentSimulator => _currentSimulator;
  ConnectionStatus get status => _status;
  SimulatorData get simulatorData => _simulatorData;
  String? get errorMessage => _errorMessage;
  AirportInfo? get destinationAirport => _destinationAirport;
  AirportInfo? get alternateAirport => _alternateAirport;

  /// 获取当前位置最近的机场
  AirportInfo? get nearestAirport {
    if (_simulatorData.latitude == null || _simulatorData.longitude == null) {
      return null;
    }
    return AirportsDatabase.findNearestByCoords(
      _simulatorData.latitude!,
      _simulatorData.longitude!,
      threshold: 1.0, // 扩大范围到约110km
    );
  }

  /// 获取当前飞行阶段
  String get flightPhase {
    if (_simulatorData.onGround == true) {
      return (_simulatorData.airspeed ?? 0) > 30 ? '起飞中' : '地面停留';
    }
    final vs = _simulatorData.verticalSpeed ?? 0;
    final alt = _simulatorData.altitude ?? 0;
    final dist = remainingDistance;

    if (alt < 3000 && vs < -300 && (dist != null && dist < 20)) return '进近中';
    if (vs > 500) return '爬升中';
    if (vs < -500) return '下降中';
    if (alt > 5000 && vs.abs() < 300) return '巡航中';
    return '飞行中';
  }

  /// 获取飞行阶段图标
  IconData get flightPhaseIcon {
    switch (flightPhase) {
      case '地面停留':
        return Icons.local_airport;
      case '起飞中':
        return Icons.flight_takeoff;
      case '爬升中':
        return Icons.trending_up;
      case '巡航中':
        return Icons.flight;
      case '下降中':
        return Icons.trending_down;
      case '进近中':
        return Icons.flight_land;
      default:
        return Icons.flight;
    }
  }

  /// 获取天气状况描述
  String get weatherQuality {
    final wind = _simulatorData.windSpeed ?? 0;
    if (wind < 10) return '天气极佳';
    if (wind < 25) return '天气良好';
    if (wind < 40) return '气流扰动';
    return '恶劣天气';
  }

  /// 获取天气图标
  IconData get weatherIcon {
    final wind = _simulatorData.windSpeed ?? 0;
    if (wind < 10) return Icons.wb_sunny;
    if (wind < 25) return Icons.wb_cloudy;
    return Icons.air;
  }

  /// 获取预计到达时间 (ETE)
  String? get estimatedTimeEnroute {
    final hoursVal = estimatedTimeEnrouteHours;
    if (hoursVal == null) return null;

    final totalMinutes = (hoursVal * 60).round();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}mins';
    }
    return 'et. ${minutes}mins';
  }

  void setDestination(AirportInfo? airport) {
    _destinationAirport = airport;
    _fetchWeather();
    notifyListeners();
  }

  void setAlternate(AirportInfo? airport) {
    _alternateAirport = airport;
    _fetchWeather();
    notifyListeners();
  }

  void _fetchWeather() {
    fetchRequiredMetars(
      nearest: nearestAirport,
      destination: _destinationAirport,
      alternate: _alternateAirport,
    );
  }

  void _syncWeatherState() {
    syncWeatherState(
      nearest: nearestAirport,
      destination: _destinationAirport,
      alternate: _alternateAirport,
    );
  }

  /// 计算到目的地的剩余距离 (海里)
  double? get remainingDistance {
    if (_destinationAirport == null ||
        _simulatorData.latitude == null ||
        _simulatorData.longitude == null) {
      return null;
    }

    return _calculateDistance(
      _simulatorData.latitude!,
      _simulatorData.longitude!,
      _destinationAirport!.latitude,
      _destinationAirport!.longitude,
    );
  }

  /// 预计剩余飞行时间 (小时)
  double? get estimatedTimeEnrouteHours {
    final distance = remainingDistance;
    if (distance == null) return null;

    double gs = _simulatorData.groundSpeed ?? 0;
    final onGround = _simulatorData.onGround ?? true;

    if (onGround || gs < 50) {
      final title = (_simulatorData.aircraftTitle ?? '').toLowerCase();
      final isJet =
          title.contains('737') ||
          title.contains('320') ||
          title.contains('boeing') ||
          title.contains('airbus');
      gs = isJet ? 440.0 : 120.0;
    }

    if (gs <= 0) return null;
    return distance / gs;
  }

  /// 计算所需燃油 (kg)
  double? get requiredFuel {
    final timeHours = estimatedTimeEnrouteHours;
    if (timeHours == null) return null;

    double ff = _simulatorData.fuelFlow ?? 0;
    final title = (_simulatorData.aircraftTitle ?? '').toLowerCase();
    final isJet =
        title.contains('737') ||
        title.contains('320') ||
        title.contains('boeing') ||
        title.contains('airbus');
    final cruiseFF = isJet ? 2400.0 : 45.0;

    if ((_simulatorData.onGround ?? true) || ff < (isJet ? 800 : 15)) {
      ff = cruiseFF;
    }

    return (timeHours * ff) * 1.15; // 15% 冗余
  }

  /// 燃油是否充足
  bool? get isFuelSufficient {
    final required = requiredFuel;
    final actual = _simulatorData.fuelQuantity;
    if (required == null || actual == null) return null;
    return actual > required;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 3440.065;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _toRadians(double degree) => degree * math.pi / 180.0;

  bool get isConnected => _status == ConnectionStatus.connected;

  String get statusText {
    switch (_status) {
      case ConnectionStatus.connecting:
        return '正在连接...';
      case ConnectionStatus.connected:
        return '已连接 $simulatorName';
      case ConnectionStatus.error:
        return '连接错误';
      case ConnectionStatus.disconnected:
        return '未连接模拟器';
    }
  }

  String get simulatorName {
    switch (_currentSimulator) {
      case SimulatorType.msfs:
        return 'MSFS 2020';
      case SimulatorType.xplane:
        return 'X-Plane';
      case SimulatorType.none:
        return '未连接';
    }
  }

  Future<bool> connectToXPlane() async {
    if (_status == ConnectionStatus.connecting) return false;
    await disconnect();

    _status = ConnectionStatus.connecting;
    _currentSimulator = SimulatorType.xplane;
    _errorMessage = null;
    notifyListeners();

    final success = await _xplaneService.connect();
    if (!success) {
      _status = ConnectionStatus.error;
      _errorMessage = '无法绑定 UDP 端口，请确认 X-Plane 运行且 49001 端口未被占用';
      notifyListeners();
      return false;
    }

    final Completer<bool> verificationCompleter = Completer<bool>();
    _dataSubscription?.cancel();
    _dataSubscription = _xplaneService.dataStream.listen((data) {
      _simulatorData = data;
      bool shouldNotify = false;

      _applyEngineCountFallback();

      if (data.isConnected && !verificationCompleter.isCompleted) {
        _status = ConnectionStatus.connected;
        verificationCompleter.complete(true);
        shouldNotify = true;
      } else if (!data.isConnected && _status == ConnectionStatus.connected) {
        _handleConnectionLoss();
        shouldNotify = true;
      }

      _detectAndSyncAircraft();
      updateChartHistory(isConnected, _simulatorData);

      if (shouldNotify || isConnected) notifyListeners();
    });

    try {
      final result = await verificationCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );
      if (!result) {
        await disconnect();
        _status = ConnectionStatus.error;
        _errorMessage = '连接超时：未收到 X-Plane 数据。';
        notifyListeners();
        return false;
      }
      return true;
    } catch (e) {
      await disconnect();
      _status = ConnectionStatus.error;
      _errorMessage = '异常: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> connectToMSFS() async {
    if (_status == ConnectionStatus.connecting) return false;
    await disconnect();

    _status = ConnectionStatus.connecting;
    _currentSimulator = SimulatorType.msfs;
    _errorMessage = null;
    notifyListeners();

    final success = await _msfsService.connect();
    if (success) {
      _status = ConnectionStatus.connected;
      _subscribeToData(_msfsService.dataStream);
      notifyListeners();
      return true;
    } else {
      _status = ConnectionStatus.error;
      _errorMessage = '连接失败。';
      notifyListeners();
      return false;
    }
  }

  void _handleConnectionLoss() {
    _status = ConnectionStatus.disconnected;
    _currentSimulator = SimulatorType.none;
    _errorMessage = '模拟器连接已中断';
    clearChartHistory();
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _dataSubscription?.cancel();
    _dataSubscription = null;

    if (_msfsService.isActive) await _msfsService.disconnect();
    if (_xplaneService.isActive) await _xplaneService.disconnect();

    _status = ConnectionStatus.disconnected;
    _currentSimulator = SimulatorType.none;
    _simulatorData = SimulatorData.empty();
    _errorMessage = null;
    _lastDetectedAircraft = null;
    clearChartHistory();
    notifyListeners();
  }

  void _subscribeToData(Stream<SimulatorData> stream) {
    _dataSubscription?.cancel();
    _dataSubscription = stream.listen((data) {
      if (!data.isConnected && isConnected) _handleConnectionLoss();
      _simulatorData = data;
      _applyEngineCountFallback();
      _detectAndSyncAircraft();
      _syncWeatherState();
      updateChartHistory(isConnected, _simulatorData);
      notifyListeners();
    });
  }

  String? _lastDetectedAircraft;
  void _detectAndSyncAircraft() {
    final title = _simulatorData.aircraftTitle;
    if (title != null &&
        title != 'Unknown Aircraft' &&
        title != _lastDetectedAircraft) {
      _lastDetectedAircraft = title;
      _notifyAircraftDetected(title);
    }
  }

  void _applyEngineCountFallback() {
    final title = _simulatorData.aircraftTitle;
    if (title == null || title.isEmpty) return;
    final currentCount = _simulatorData.numEngines;
    final match = AircraftCatalog.match(title: title);
    final fallbackCount = match?.identity.engineCount;
    final isSpecificGa = match?.identity.generalAviation == true &&
        match?.identity.id != 'general-aviation';
    if (fallbackCount != null &&
        fallbackCount > 0 &&
        (currentCount == null ||
            currentCount <= 0 ||
            (isSpecificGa && currentCount != fallbackCount))) {
      _simulatorData = _simulatorData.copyWith(numEngines: fallbackCount);
    }
  }

  Function(String)? onAircraftDetected;
  void setAircraftDetectionCallback(Function(String) callback) =>
      onAircraftDetected = callback;

  void _notifyAircraftDetected(String aircraftTitle) {
    if (onAircraftDetected != null) {
      final title = aircraftTitle.toLowerCase();
      String? aircraftId;
      final match = AircraftCatalog.match(title: aircraftTitle);
      if (match != null) {
        final manufacturer = match.identity.manufacturer.toLowerCase();
        final family = match.identity.family.toLowerCase();
        if (manufacturer.contains('airbus') || family.contains('a320')) {
          aircraftId = 'a320_series';
        } else if (manufacturer.contains('boeing') ||
            family.contains('737') ||
            family.contains('747') ||
            family.contains('787')) {
          aircraftId = 'b737_series';
        }
      }
      aircraftId ??= title.contains('airbus') || title.contains('a320')
          ? 'a320_series'
          : title.contains('boeing') || title.contains('737')
          ? 'b737_series'
          : null;
      if (aircraftId != null) {
        onAircraftDetected!(aircraftId);
      }
    }
  }
}
