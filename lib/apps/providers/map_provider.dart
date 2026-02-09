import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/airport_detail_data.dart';
import '../models/flight_log/flight_log.dart';
import '../services/airport_detail_service.dart';
import '../services/flight_log_service.dart';
import '../data/airports_database.dart';
import '../../core/utils/logger.dart';
import 'simulator/simulator_provider.dart';

class MapProvider with ChangeNotifier {
  final SimulatorProvider _simulatorProvider;
  final AirportDetailService _airportService = AirportDetailService();
  final FlightLogService _flightLogService = FlightLogService();

  AirportDetailData? _currentAirport;
  AirportDetailData? _destinationAirport;
  AirportDetailData? _alternateAirport;
  AirportDetailData? _targetAirport;
  AirportDetailData? _centerAirport;
  AirportDetailData? _departureAirport;

  final Map<String, AirportDetailData> _airportDetails = {};
  final List<LatLng> _path = [];
  LatLng? _takeoffPoint;
  LatLng? _landingPoint;

  bool _isLoadingAirport = false;
  bool _showWeatherRadar = false;
  int? _weatherRadarTimestamp;
  String? _lastIcao;
  String? _lastDestIcao;
  String? _lastAltIcao;
  String? _currentRunway;
  String? _currentRunwayAirportIcao;

  StreamSubscription<TakeoffData>? _takeoffSubscription;
  StreamSubscription<LandingData>? _landingSubscription;

  MapProvider(this._simulatorProvider) {
    _simulatorProvider.addListener(_onSimulatorUpdate);
    _updateWeatherRadarTimestamp();
    _initFlightLogSubscriptions();
  }

  void _initFlightLogSubscriptions() {
    _takeoffSubscription = _flightLogService.takeoffStream.listen((data) {
      _takeoffPoint = LatLng(data.latitude, data.longitude);
      notifyListeners();
    });
    _landingSubscription = _flightLogService.landingStream.listen((data) {
      _landingPoint = LatLng(
        data.touchdownSequence.last.latitude,
        data.touchdownSequence.last.longitude,
      );
      notifyListeners();
    });
  }

  bool get showWeatherRadar => _showWeatherRadar;
  int? get weatherRadarTimestamp => _weatherRadarTimestamp;
  Timer? _radarRefreshTimer;
  DateTime? _lastRadarFetch;

  void toggleWeatherRadar() {
    _showWeatherRadar = !_showWeatherRadar;
    if (_showWeatherRadar) {
      // 仅在数据过期或为空时刷新
      if (_weatherRadarTimestamp == null ||
          _lastRadarFetch == null ||
          DateTime.now().difference(_lastRadarFetch!).inMinutes >= 15) {
        _updateWeatherRadarTimestamp();
      }

      // 开启定时自动刷新 (RainViewer 建议每 10-15 分钟刷新一次)
      _radarRefreshTimer?.cancel();
      _radarRefreshTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
        AppLogger.info('Refreshing weather radar timestamp...');
        _updateWeatherRadarTimestamp();
      });
    } else {
      _radarRefreshTimer?.cancel();
      _radarRefreshTimer = null;
    }
    notifyListeners();
  }

  Future<void> _updateWeatherRadarTimestamp() async {
    // 简单的节流，防止短时间内多次触发
    if (_lastRadarFetch != null &&
        DateTime.now().difference(_lastRadarFetch!).inSeconds < 5) {
      return;
    }

    try {
      final response = await _airportService.fetchWeatherRadarTimestamp();
      if (response != null) {
        _weatherRadarTimestamp = response;
        _lastRadarFetch = DateTime.now();
        notifyListeners();
      }
    } catch (e) {
      // Ignore
    }
  }

  AirportDetailData? get currentAirport => _currentAirport;
  AirportDetailData? get destinationAirport => _destinationAirport;
  AirportDetailData? get alternateAirport => _alternateAirport;
  AirportDetailData? get targetAirport => _targetAirport;
  AirportDetailData? get centerAirport => _centerAirport;
  AirportDetailData? get departureAirport => _departureAirport;
  LatLng? get takeoffPoint => _takeoffPoint;
  LatLng? get landingPoint => _landingPoint;
  String? get currentRunway => _currentRunway;
  String? get currentRunwayAirportIcao => _currentRunwayAirportIcao;

  /// 清除当前飞行轨迹及相关标记点数据
  void clearFlightData() {
    _path.clear();
    _takeoffPoint = null;
    _landingPoint = null;
    _departureAirport = null;
    notifyListeners();
  }

  /// 获取所有已加载详细信息的机场列表
  List<AirportDetailData> get allDetailedAirports {
    final list = <AirportDetailData>[];
    if (_currentAirport != null) list.add(_currentAirport!);
    if (_destinationAirport != null &&
        _destinationAirport?.icaoCode != _currentAirport?.icaoCode) {
      list.add(_destinationAirport!);
    }
    if (_alternateAirport != null &&
        _alternateAirport?.icaoCode != _currentAirport?.icaoCode &&
        _alternateAirport?.icaoCode != _destinationAirport?.icaoCode) {
      list.add(_alternateAirport!);
    }
    if (_targetAirport != null &&
        _targetAirport?.icaoCode != _currentAirport?.icaoCode &&
        _targetAirport?.icaoCode != _destinationAirport?.icaoCode &&
        _targetAirport?.icaoCode != _alternateAirport?.icaoCode) {
      list.add(_targetAirport!);
    }
    if (_centerAirport != null &&
        _centerAirport?.icaoCode != _currentAirport?.icaoCode &&
        _centerAirport?.icaoCode != _destinationAirport?.icaoCode &&
        _centerAirport?.icaoCode != _alternateAirport?.icaoCode &&
        _centerAirport?.icaoCode != _targetAirport?.icaoCode) {
      list.add(_centerAirport!);
    }
    return list;
  }

  DateTime? _lastCenterUpdate;

  /// 根据地图中心坐标更新最近机场
  void updateCenterAirport(double lat, double lon, {double? zoom}) {
    if (lat == 0 && lon == 0) return;

    // 如果缩放级别太低（全局视野），不进行搜索以节省性能，且逻辑上中心机场也无意义
    if (zoom != null && zoom < 10) {
      if (_centerAirport != null) {
        _centerAirport = null;
        notifyListeners();
      }
      return;
    }

    // 增加节流处理：100ms 内只处理一次，防止滑动/缩放时高频触发导致卡顿
    final now = DateTime.now();
    if (_lastCenterUpdate != null &&
        now.difference(_lastCenterUpdate!).inMilliseconds < 100) {
      return;
    }
    _lastCenterUpdate = now;

    final nearest = AirportsDatabase.findNearestByCoords(
      lat,
      lon,
      threshold: 0.05,
    ); // 约5km
    if (nearest != null) {
      if (_centerAirport?.icaoCode != nearest.icaoCode) {
        _loadSpecificAirport(nearest.icaoCode, (data) => _centerAirport = data);
      }
    } else {
      if (_centerAirport != null) {
        _centerAirport = null;
        notifyListeners();
      }
    }
  }

  List<LatLng> get path => _path;
  bool get isLoadingAirport => _isLoadingAirport;

  void _onSimulatorUpdate() {
    final data = _simulatorProvider.simulatorData;
    if (data.latitude != null && data.longitude != null) {
      final pos = LatLng(data.latitude!, data.longitude!);

      // Update path
      if (_path.isEmpty || _path.last != pos) {
        _path.add(pos);
        if (_path.length > 5000) _path.removeAt(0);
        notifyListeners();
      }

      // Check for nearest airport change
      final nearest = _simulatorProvider.nearestAirport;
      if (nearest != null && nearest.icaoCode != _lastIcao) {
        _lastIcao = nearest.icaoCode;
        _loadSpecificAirport(
          nearest.icaoCode,
          (data) => _currentAirport = data,
        );
      }

      // Check for destination change
      final dest = _simulatorProvider.destinationAirport;
      if (dest != null && dest.icaoCode != _lastDestIcao) {
        _lastDestIcao = dest.icaoCode;
        _loadSpecificAirport(
          dest.icaoCode,
          (data) => _destinationAirport = data,
        );
      }

      // Check for alternate change
      final alt = _simulatorProvider.alternateAirport;
      if (alt != null && alt.icaoCode != _lastAltIcao) {
        _lastAltIcao = alt.icaoCode;
        _loadSpecificAirport(alt.icaoCode, (data) => _alternateAirport = data);
      }

      // Map-Matching for active runway
      _updateCurrentRunway(data.latitude!, data.longitude!);

      // Auto-detect departure airport (Lock the first airport found when on ground)
      if (_departureAirport == null &&
          data.onGround == true &&
          _currentAirport != null) {
        _departureAirport = _currentAirport;
        notifyListeners();
      }
    }
  }

  void _updateCurrentRunway(double lat, double lon) {
    // 优先从当前机场（起飞/降落机场）匹配
    final potentialAirports = <AirportDetailData>[];
    if (_currentAirport != null) potentialAirports.add(_currentAirport!);
    if (_destinationAirport != null) {
      potentialAirports.add(_destinationAirport!);
    }
    if (_centerAirport != null) potentialAirports.add(_centerAirport!);

    String? foundRunway;
    String? foundAirportIcao;
    for (final airport in potentialAirports) {
      for (final r in airport.runways) {
        if (r.isPointOnRunway(lat, lon)) {
          foundRunway = r.ident;
          foundAirportIcao = airport.icaoCode;
          break;
        }
      }
      if (foundRunway != null) break;
    }

    if (foundRunway != _currentRunway) {
      _currentRunway = foundRunway;
      _currentRunwayAirportIcao = foundAirportIcao;
      notifyListeners();
    }
  }

  Future<void> _loadSpecificAirport(
    String icao,
    Function(AirportDetailData?) setter,
  ) async {
    if (_airportDetails.containsKey(icao)) {
      final detail = _airportDetails[icao];
      setter(detail);
      if (setter == (data) => _currentAirport = data) {
        _flightLogService.setCurrentAirportDetail(detail);
      }
      notifyListeners();
      return;
    }

    try {
      final detail = await _airportService.fetchAirportDetail(icao);
      if (detail != null) {
        _airportDetails[icao] = detail;
        setter(detail);
        if (setter == (data) => _currentAirport = data) {
          _flightLogService.setCurrentAirportDetail(detail);
        }
        notifyListeners();
      }
    } catch (e) {
      // Ignore errors for secondary airports
    }
  }

  /// 选择并定位到搜索的机场
  Future<void> selectTargetAirport(String icao) async {
    _isLoadingAirport = true;
    notifyListeners();
    try {
      final detail = await _airportService.fetchAirportDetail(icao);
      if (detail != null) {
        _airportDetails[icao] = detail;
        _targetAirport = detail;
        notifyListeners();
      }
    } catch (e) {
      // Handle error
    } finally {
      _isLoadingAirport = false;
      notifyListeners();
    }
  }

  /// 清除搜索选中的机场，释放渲染资源
  void clearTargetAirport() {
    _targetAirport = null;
    notifyListeners();
  }

  Future<void> _loadAirportDetail(String icao, {bool force = false}) async {
    _isLoadingAirport = true;
    notifyListeners();

    try {
      final detail = await _airportService.fetchAirportDetail(
        icao,
        forceRefresh: force,
      );
      _currentAirport = detail;
      _flightLogService.setCurrentAirportDetail(detail);
    } catch (e) {
      _currentAirport = null;
    } finally {
      _isLoadingAirport = false;
      notifyListeners();
    }
  }

  /// 强制重新加载当前机场数据
  Future<void> refreshAirport() async {
    if (_lastIcao != null) {
      await _loadAirportDetail(_lastIcao!, force: true);
    }
  }

  @override
  void dispose() {
    _simulatorProvider.removeListener(_onSimulatorUpdate);
    _takeoffSubscription?.cancel();
    _landingSubscription?.cancel();
    _radarRefreshTimer?.cancel();
    super.dispose();
  }
}
