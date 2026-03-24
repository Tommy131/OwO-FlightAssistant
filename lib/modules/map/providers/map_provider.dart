import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/services/persistence_service.dart';
import '../../airport_search/models/airport_search_models.dart';
import '../../common/models/common_models.dart';
import '../../http/http_module.dart';
import '../localization/map_localization_keys.dart';
import '../models/map_models.dart';
import 'components/map_airport_data_component.dart';
import 'components/map_alert_component.dart';
import 'components/map_flight_track_component.dart';
import 'components/map_taxiway_file_component.dart';
import 'map_airport_api_parser.dart';
import 'map_geo_utils.dart';
import 'map_taxiway_models.dart';
import 'map_weather_utils.dart';

// 滑行路线内部模型已迁移至 map_taxiway_models.dart
// 此处使用类型别名以保持内部方法签名兼容性。
typedef _TaxiwayOperationSnapshot = MapTaxiwayOperationSnapshot;
typedef _TaxiwayOperationRecord = MapTaxiwayOperationRecord;
typedef _TaxiwaySegmentMatchResult = MapTaxiwaySegmentMatchResult;

/// 地图模块核心状态管理器
///
/// 职责：
/// 1. **数据订阅**：监听 [HomeDataSnapshot] 更新，构建飞机状态、维护轨迹和机场列表
/// 2. **持久化设置**：本机机场、自动计时器、飞行警报阈值、UI 刷新频率
/// 3. **机场查询**：关键字搜索（带本地兜底）、范围查询、选中机场详情拉取
/// 4. **飞行计时器**：手动/自动模式，支持多种启停条件
/// 5. **飞行警报**：将后端告警与本地垂直速率计算合并，按优先级去重后推送给 UI
/// 6. **天气雷达**：推拉 RainViewer 时间戳，联动地图图层
/// 7. **UI 节流**：内置刷新间隔控制，支持低性能模式
///
/// 复杂子逻辑已拆分到独立工具类：
/// - 几何计算 → [MapGeoUtils]
/// - METAR 解析 → [MapWeatherUtils]
/// - API 响应解析 → [MapAirportApiParser]
/// - 机场数据组件（数据聚合）→ [MapAirportDataComponent]
/// - 轨迹计算组件（算法）→ [MapFlightTrackComponent]
/// - 告警规则组件（规则引擎）→ [MapAlertComponent]
class MapProvider extends ChangeNotifier {
  MapProvider({MapDataAdapter? adapter}) : _adapter = adapter {
    _subscribeAdapter();
    unawaited(_loadHomeAirport());
    unawaited(_loadAutoTimerSettings());
    unawaited(_loadAlertSettings());
    unawaited(_loadPerformanceSettings());
  }

  static const String _moduleName = 'map';
  static const String _homeAirportCodeKey = 'home_airport_code';
  static const String _homeAirportNameKey = 'home_airport_name';
  static const String _homeAirportLatKey = 'home_airport_lat';
  static const String _homeAirportLonKey = 'home_airport_lon';
  static const String _autoHudTimerEnabledKey = 'auto_hud_timer_enabled';
  static const String _autoTimerStartModeKey = 'auto_timer_start_mode';
  static const String _autoTimerStopModeKey = 'auto_timer_stop_mode';
  static const String _alertsEnabledKey = 'alerts_enabled';
  static const String _disabledAlertIdsKey = 'disabled_alert_ids';
  static const String _climbRateWarningFpmKey = 'climb_rate_warning_fpm';
  static const String _climbRateDangerFpmKey = 'climb_rate_danger_fpm';
  static const String _descentRateWarningFpmKey = 'descent_rate_warning_fpm';
  static const String _descentRateDangerFpmKey = 'descent_rate_danger_fpm';
  static const int _defaultClimbRateWarningFpm = 2200;
  static const int _defaultClimbRateDangerFpm = 3200;
  static const int _defaultDescentRateWarningFpm = 1800;
  static const int _defaultDescentRateDangerFpm = 2800;
  static const String _performanceModuleName = 'performance';
  static const String _lowPerformanceModeKey = 'low_performance_mode';
  static const String _uiRefreshIntervalMsKey = 'ui_refresh_interval_ms';
  static const int _defaultUiRefreshIntervalMs = 120;
  static const int _lowPerformanceRefreshIntervalMs = 500;
  static const int _maxTaxiwayHistorySize = 20;
  static const double _taxiwayMatchMaxDistanceMeters = 28.0;

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

  static const Set<String> _verticalRateAlertIds = {
    'climb_rate_warning',
    'climb_rate_danger',
    'descent_rate_warning',
    'descent_rate_danger',
  };

  final MapAlertComponent _alertComponent = const MapAlertComponent(
    backendAlertMessageMap: _backendAlertMessageMap,
    verticalRateAlertIds: _verticalRateAlertIds,
  );

  MapDataAdapter? _adapter;
  StreamSubscription<MapDataSnapshot>? _subscription;

  MapLayerStyle _layerStyle = MapLayerStyle.dark;
  bool _followAircraft = true;
  bool _showRoute = true;
  bool _showPlannedRoute = true;
  bool _showAirports = true;
  bool _showRunways = true;
  bool _showParkings = true;
  bool _showCompass = true;
  bool _showWeather = false;
  bool _showCustomTaxiwayRoute = true;
  bool _isTaxiwayDrawingActive = false;
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
  List<MapAIAircraftState> _aiAircraft = const [];
  List<MapRoutePoint> _route = [];
  List<MapAirportMarker> _airports = [];
  List<MapFlightAlert> _activeAlerts = [];
  MapAirportMarker? _homeAirport;
  MapCoordinate? _takeoffPoint;
  MapCoordinate? _landingPoint;
  bool? _lastOnGround;
  DateTime? _lastRouteTimestamp;
  bool _isAircraftMoving = false;
  String? _currentNearestAirportIcao;
  final Map<String, List<MapRunwayGeometry>> _runwayGeometryCache = {};
  final Set<String> _runwayGeometryLoadingIcaos = <String>{};
  final Map<String, DateTime> _runwayGeometryLastAttemptAt = {};
  Duration _hudElapsed = Duration.zero;
  Timer? _hudTimer;
  bool _isHudTimerRunning = false;
  bool _hasHudTimerStarted = false;
  MapCoordinate? _lastMovementSamplePosition;
  DateTime? _lastMovementSampleAt;
  bool _autoHudTimerEnabled = false;
  MapAutoTimerStartMode _autoTimerStartMode =
      MapAutoTimerStartMode.runwayMovement;
  MapAutoTimerStopMode _autoTimerStopMode = MapAutoTimerStopMode.stableLanding;
  bool _alertsEnabled = true;
  Set<String> _disabledAlertIds = const <String>{};
  int _climbRateWarningFpm = _defaultClimbRateWarningFpm;
  int _climbRateDangerFpm = _defaultClimbRateDangerFpm;
  int _descentRateWarningFpm = _defaultDescentRateWarningFpm;
  int _descentRateDangerFpm = _defaultDescentRateDangerFpm;
  bool? _lastAutoParkingBrake;
  bool _hudTimerAirborneSinceStart = false;
  bool _hudTimerLandedSinceStart = false;
  bool _pushbackStartArmed = false;
  bool _autoFlightCycleEnded = false;
  DateTime? _groundStableSince;
  bool _lowPerformanceMode = false;
  int _uiRefreshIntervalMs = _defaultUiRefreshIntervalMs;
  DateTime? _lastUiNotifyAt;
  // ── 滑行路线状态 ─────────────────────────────────────────────
  /// 当前路线节点列表。
  List<MapTaxiwayNode> _taxiwayNodes = const [];

  /// 当前路线线段列表（长度 = 节点数 − 1）。
  List<MapTaxiwaySegment> _taxiwaySegments = const [];

  /// 飞机已完成通过的线段索引集合（用于高亮已走段）。
  Set<int> _completedTaxiwaySegmentIndexes = const <int>{};

  /// 飞机沿路线的全局进度（浮点值，=线段索引+线段内归一化进度）。
  double? _taxiwayMatchedProgress;

  /// 撤销历史记录栈。
  List<MapTaxiwayOperationRecord> _taxiwayUndoHistory = const [];

  /// 重做历史记录栈。
  List<MapTaxiwayOperationRecord> _taxiwayRedoHistory = const [];

  /// 是否存在未保存的修改。
  bool _hasUnsavedTaxiwayChanges = false;

  /// 当前已加载文件对应的机场 ICAO。
  String? _loadedTaxiwayAirportIcao;

  /// 当前已加载文件的绝对路径。
  String? _loadedTaxiwayFilePath;

  /// 当前已加载文件的创建时间。
  DateTime? _loadedTaxiwayCreatedAt;

  MapLayerStyle get layerStyle => _layerStyle;
  bool get followAircraft => _followAircraft;
  bool get showRoute => _showRoute;
  bool get showPlannedRoute => _showPlannedRoute;
  bool get showAirports => _showAirports;
  bool get showRunways => _showRunways;
  bool get showParkings => _showParkings;
  bool get showCompass => _showCompass;
  bool get showWeather => _showWeather;
  bool get showCustomTaxiwayRoute => _showCustomTaxiwayRoute;
  bool get isTaxiwayDrawingActive => _isTaxiwayDrawingActive;
  String? get currentNearestAirportIcao => _currentNearestAirportIcao;
  List<MapTaxiwayNode> get taxiwayNodes => _taxiwayNodes;
  List<MapTaxiwaySegment> get taxiwaySegments => _taxiwaySegments;
  Set<int> get completedTaxiwaySegmentIndexes =>
      _completedTaxiwaySegmentIndexes;
  Set<int> get completedTaxiwayNodeIndexes {
    if (_completedTaxiwaySegmentIndexes.isEmpty || _taxiwayNodes.isEmpty) {
      return const <int>{};
    }
    final nodeIndexes = <int>{};
    for (final segmentIndex in _completedTaxiwaySegmentIndexes) {
      if (segmentIndex < 0 || segmentIndex >= _taxiwayNodes.length - 1) {
        continue;
      }
      nodeIndexes.add(segmentIndex);
      nodeIndexes.add(segmentIndex + 1);
    }
    return nodeIndexes;
  }

  List<MapCoordinate> get taxiwayRoutePoints => _taxiwayNodes
      .map(
        (node) =>
            MapCoordinate(latitude: node.latitude, longitude: node.longitude),
      )
      .toList(growable: false);
  bool get canUndoTaxiwayRoute => _taxiwayUndoHistory.isNotEmpty;
  bool get canRedoTaxiwayRoute => _taxiwayRedoHistory.isNotEmpty;
  bool get hasUnsavedTaxiwayChanges => _hasUnsavedTaxiwayChanges;
  String? get loadedTaxiwayAirportIcao => _loadedTaxiwayAirportIcao;
  String? get loadedTaxiwayFilePath => _loadedTaxiwayFilePath;
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
  List<MapAIAircraftState> get aiAircraft => _aiAircraft;
  List<MapRoutePoint> get route => _route;
  List<MapAirportMarker> get airports => _airports;
  List<MapFlightAlert> get activeAlerts => _activeAlerts;
  MapAirportMarker? get homeAirport => _homeAirport;
  int get tileReloadToken => _tileReloadToken;
  MapCoordinate? get takeoffPoint => _takeoffPoint;
  MapCoordinate? get landingPoint => _landingPoint;
  bool get isAircraftMoving => _isAircraftMoving;
  Duration get hudElapsed => _hudElapsed;
  bool get isHudTimerRunning => _isHudTimerRunning;
  bool get hasHudTimerStarted => _hasHudTimerStarted;
  bool get autoHudTimerEnabled => _autoHudTimerEnabled;
  MapAutoTimerStartMode get autoTimerStartMode => _autoTimerStartMode;
  MapAutoTimerStopMode get autoTimerStopMode => _autoTimerStopMode;
  bool get alertsEnabled => _alertsEnabled;
  int get climbRateWarningFpm => _climbRateWarningFpm;
  int get climbRateDangerFpm => _climbRateDangerFpm;
  int get descentRateWarningFpm => _descentRateWarningFpm;
  int get descentRateDangerFpm => _descentRateDangerFpm;
  List<String> get configurableAlertIds =>
      _backendAlertMessageMap.keys.toList(growable: false);

  bool isAlertEnabled(String alertId) {
    return !_disabledAlertIds.contains(alertId.trim().toLowerCase());
  }

  String? alertMessageKeyForId(String alertId) {
    return _backendAlertMessageMap[alertId.trim().toLowerCase()];
  }

  void attachAdapter(MapDataAdapter? adapter) {
    _adapter = adapter;
    _subscribeAdapter();
  }

  Future<void> setHomeAirport(MapAirportMarker airport) async {
    final latitude = airport.position.latitude;
    final longitude = airport.position.longitude;
    if (!_isValidCoordinate(latitude, longitude)) {
      return;
    }
    final normalizedCode = airport.code.trim().toUpperCase();
    final normalizedAirport = MapAirportMarker(
      code: normalizedCode.isEmpty ? 'HOME' : normalizedCode,
      name: airport.name?.trim(),
      position: MapCoordinate(latitude: latitude, longitude: longitude),
      isPrimary: false,
    );
    _homeAirport = normalizedAirport;
    notifyListeners();

    final persistence = PersistenceService();
    await persistence.setModuleData(
      _moduleName,
      _homeAirportCodeKey,
      normalizedAirport.code,
    );
    await persistence.setModuleData(
      _moduleName,
      _homeAirportNameKey,
      normalizedAirport.name,
    );
    await persistence.setModuleData(
      _moduleName,
      _homeAirportLatKey,
      normalizedAirport.position.latitude,
    );
    await persistence.setModuleData(
      _moduleName,
      _homeAirportLonKey,
      normalizedAirport.position.longitude,
    );
  }

  Future<void> clearHomeAirport() async {
    _homeAirport = null;
    notifyListeners();
    final persistence = PersistenceService();
    await persistence.setModuleData(_moduleName, _homeAirportCodeKey, null);
    await persistence.setModuleData(_moduleName, _homeAirportNameKey, null);
    await persistence.setModuleData(_moduleName, _homeAirportLatKey, null);
    await persistence.setModuleData(_moduleName, _homeAirportLonKey, null);
  }

  Future<void> _loadHomeAirport() async {
    final persistence = PersistenceService();
    final latitude = persistence.getModuleData<double>(
      _moduleName,
      _homeAirportLatKey,
    );
    final longitude = persistence.getModuleData<double>(
      _moduleName,
      _homeAirportLonKey,
    );
    if (latitude == null ||
        longitude == null ||
        !_isValidCoordinate(latitude, longitude)) {
      return;
    }
    final code =
        persistence.getModuleData<String>(
          _moduleName,
          _homeAirportCodeKey,
          defaultValue: 'HOME',
        ) ??
        'HOME';
    final name = persistence.getModuleData<String>(
      _moduleName,
      _homeAirportNameKey,
    );
    _homeAirport = MapAirportMarker(
      code: code.trim().isEmpty ? 'HOME' : code.trim().toUpperCase(),
      name: name?.trim().isEmpty ?? true ? null : name?.trim(),
      position: MapCoordinate(latitude: latitude, longitude: longitude),
      isPrimary: false,
    );
    notifyListeners();
  }

  Future<void> _loadAutoTimerSettings() async {
    final persistence = PersistenceService();
    final enabled = persistence.getModuleData<bool>(
      _moduleName,
      _autoHudTimerEnabledKey,
    );
    final startModeIndex = persistence.getModuleData<int>(
      _moduleName,
      _autoTimerStartModeKey,
    );
    final stopModeIndex = persistence.getModuleData<int>(
      _moduleName,
      _autoTimerStopModeKey,
    );
    var hasUpdate = false;
    if (enabled != null && enabled != _autoHudTimerEnabled) {
      _autoHudTimerEnabled = enabled;
      hasUpdate = true;
    }
    if (startModeIndex != null &&
        startModeIndex >= 0 &&
        startModeIndex < MapAutoTimerStartMode.values.length) {
      final startMode = MapAutoTimerStartMode.values[startModeIndex];
      if (startMode != _autoTimerStartMode) {
        _autoTimerStartMode = startMode;
        hasUpdate = true;
      }
    }
    if (stopModeIndex != null &&
        stopModeIndex >= 0 &&
        stopModeIndex < MapAutoTimerStopMode.values.length) {
      final stopMode = MapAutoTimerStopMode.values[stopModeIndex];
      if (stopMode != _autoTimerStopMode) {
        _autoTimerStopMode = stopMode;
        hasUpdate = true;
      }
    }
    if (hasUpdate) {
      notifyListeners();
    }
  }

  Future<void> _loadAlertSettings() async {
    final persistence = PersistenceService();
    final alertsEnabled = persistence.getModuleData<bool>(
      _moduleName,
      _alertsEnabledKey,
    );
    final disabledIdsRaw = persistence.getModuleData<List<dynamic>>(
      _moduleName,
      _disabledAlertIdsKey,
    );
    final climbWarning = persistence.getModuleData<int>(
      _moduleName,
      _climbRateWarningFpmKey,
    );
    final climbDanger = persistence.getModuleData<int>(
      _moduleName,
      _climbRateDangerFpmKey,
    );
    final descentWarning = persistence.getModuleData<int>(
      _moduleName,
      _descentRateWarningFpmKey,
    );
    final descentDanger = persistence.getModuleData<int>(
      _moduleName,
      _descentRateDangerFpmKey,
    );
    var hasUpdate = false;
    if (alertsEnabled != null && alertsEnabled != _alertsEnabled) {
      _alertsEnabled = alertsEnabled;
      hasUpdate = true;
    }
    if (disabledIdsRaw != null) {
      final disabledIds = disabledIdsRaw
          .map((value) => value.toString().trim().toLowerCase())
          .where((value) => value.isNotEmpty)
          .toSet();
      if (disabledIds.length != _disabledAlertIds.length ||
          !disabledIds.containsAll(_disabledAlertIds)) {
        _disabledAlertIds = disabledIds;
        hasUpdate = true;
      }
    }
    if (climbWarning != null && climbWarning > 0) {
      _climbRateWarningFpm = climbWarning;
      hasUpdate = true;
    }
    if (climbDanger != null && climbDanger > _climbRateWarningFpm) {
      _climbRateDangerFpm = climbDanger;
      hasUpdate = true;
    }
    if (descentWarning != null && descentWarning > 0) {
      _descentRateWarningFpm = descentWarning;
      hasUpdate = true;
    }
    if (descentDanger != null && descentDanger > _descentRateWarningFpm) {
      _descentRateDangerFpm = descentDanger;
      hasUpdate = true;
    }
    if (hasUpdate) {
      notifyListeners();
    }
  }

  void updateFromHomeSnapshot(HomeDataSnapshot snapshot) {
    final wasConnected = _isConnected;
    _isConnected = snapshot.isConnected;
    if (!wasConnected && _isConnected) {
      _connectionEpoch += 1;
    }
    final wasSimulatorPaused = _isPaused;
    _isPaused = snapshot.isPaused == true && _isConnected;
    if (!wasSimulatorPaused && _isPaused && _isHudTimerRunning) {
      pauseHudTimer();
    }
    _airports = _buildAirportsFromSnapshot(snapshot);
    final nearestIcao = snapshot.nearestAirport?.icaoCode.trim().toUpperCase();
    _currentNearestAirportIcao = (nearestIcao == null || nearestIcao.isEmpty)
        ? null
        : nearestIcao;
    if (_currentNearestAirportIcao != null) {
      unawaited(_ensureRunwayGeometryLoaded(_currentNearestAirportIcao!));
    }
    final flightData = snapshot.flightData;
    final lat = flightData.latitude;
    final lon = flightData.longitude;
    _aiAircraft = flightData.aiAircraft
        .where(
          (item) =>
              _isValidCoordinate(item.latitude, item.longitude) &&
              (lat == null ||
                  lon == null ||
                  _distanceInMeters(
                        lat,
                        lon,
                        item.latitude,
                        item.longitude,
                      ) >
                      8),
        )
        .map(
          (item) => MapAIAircraftState(
            id: item.id,
            position: MapCoordinate(
              latitude: item.latitude,
              longitude: item.longitude,
            ),
            altitude: item.altitude,
            heading: item.heading,
            groundSpeed: item.groundSpeed,
            onGround: item.onGround,
          ),
        )
        .toList(growable: false);
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
        aircraftState: aircraftState,
        isMoving: isMoving,
        now: now,
      );
      _appendRoutePoint(aircraftState, now, isMoving);
      _updateTakeoffLandingMarker(flightData.onGround, aircraftState.position);
      _updateTaxiwaySegmentCompletionByAircraft(aircraftState);
    } else if (!_isConnected) {
      _clearAircraftVisualState();
    }
    _evaluateFlightAlerts(flightData);
    if (_shouldNotifyUi()) {
      notifyListeners();
    }
  }

  Future<void> _loadPerformanceSettings() async {
    final persistence = PersistenceService();
    await persistence.ensureReady();
    _lowPerformanceMode =
        persistence.getModuleData<bool>(
          _performanceModuleName,
          _lowPerformanceModeKey,
        ) ??
        false;
    final storedInterval =
        persistence.getModuleData<int>(
          _performanceModuleName,
          _uiRefreshIntervalMsKey,
        ) ??
        _defaultUiRefreshIntervalMs;
    _uiRefreshIntervalMs = storedInterval.clamp(60, 2000).toInt();
  }

  bool _shouldNotifyUi() {
    final now = DateTime.now();
    final minInterval = _lowPerformanceMode
        ? (_uiRefreshIntervalMs > _lowPerformanceRefreshIntervalMs
              ? _uiRefreshIntervalMs
              : _lowPerformanceRefreshIntervalMs)
        : _uiRefreshIntervalMs;
    if (_lastUiNotifyAt == null ||
        now.difference(_lastUiNotifyAt!).inMilliseconds >= minInterval) {
      _lastUiNotifyAt = now;
      return true;
    }
    return false;
  }

  Future<void> refreshPerformanceSettings() async {
    await _loadPerformanceSettings();
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
      final airportRoot =
          await MapAirportDataComponent.fetchAirportLayoutByIcao(icao);
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
      final normalizedAtis = _normalizeWeatherText(atis);
      final normalizedRawMetar = _normalizeWeatherText(
        (rawMetar ?? metar.raw)?.trim(),
      );
      final normalizedDecodedMetar = _normalizeWeatherText(
        (decodedMetar ?? metar.decoded)?.trim(),
      );
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
        atis: normalizedAtis?.isEmpty ?? true ? null : normalizedAtis,
        rawMetar: normalizedRawMetar,
        decodedMetar: normalizedDecodedMetar,
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

  void togglePlannedRoute() {
    _showPlannedRoute = !_showPlannedRoute;
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

  void toggleCustomTaxiway() {
    _showCustomTaxiwayRoute = !_showCustomTaxiwayRoute;
    notifyListeners();
  }

  void toggleTaxiwayDrawing() {
    _isTaxiwayDrawingActive = !_isTaxiwayDrawingActive;
    notifyListeners();
  }

  void addTaxiwayRoutePoint(MapCoordinate point) {
    final before = _captureTaxiwaySnapshot();
    _taxiwayNodes = [
      ..._taxiwayNodes,
      MapTaxiwayNode(latitude: point.latitude, longitude: point.longitude),
    ];
    _resetTaxiwaySegmentCompletionState();
    _syncTaxiwaySegmentsWithNodes();
    _commitTaxiwayOperation(before);
    _hasUnsavedTaxiwayChanges = true;
    notifyListeners();
  }

  void updateTaxiwayNodePosition(int index, MapCoordinate point) {
    if (index < 0 || index >= _taxiwayNodes.length) {
      return;
    }
    if (!_isValidCoordinate(point.latitude, point.longitude)) {
      return;
    }
    final nextNodes = [..._taxiwayNodes];
    final target = nextNodes[index];
    nextNodes[index] = target.copyWith(
      latitude: point.latitude,
      longitude: point.longitude,
    );
    final before = _captureTaxiwaySnapshot();
    _taxiwayNodes = nextNodes;
    _resetTaxiwaySegmentCompletionState();
    _syncTaxiwaySegmentsWithNodes();
    _commitTaxiwayOperation(before);
    _hasUnsavedTaxiwayChanges = true;
    notifyListeners();
  }

  void updateTaxiwayNodeInfo(
    int index, {
    String? name,
    String? colorHex,
    String? note,
  }) {
    if (index < 0 || index >= _taxiwayNodes.length) {
      return;
    }
    final normalizedName = _normalizeOptionalText(name);
    final normalizedColorHex = _normalizeTaxiwayColorHex(colorHex);
    final normalizedNote = _normalizeOptionalText(note);
    final nextNodes = [..._taxiwayNodes];
    final target = nextNodes[index];
    nextNodes[index] = target.copyWith(
      name: normalizedName,
      clearName: normalizedName == null,
      colorHex: normalizedColorHex,
      clearColorHex: normalizedColorHex == null,
      note: normalizedNote,
      clearNote: normalizedNote == null,
    );
    final before = _captureTaxiwaySnapshot();
    _taxiwayNodes = nextNodes;
    _resetTaxiwaySegmentCompletionState();
    _syncTaxiwaySegmentsWithNodes();
    _commitTaxiwayOperation(before);
    _hasUnsavedTaxiwayChanges = true;
    notifyListeners();
  }

  void insertTaxiwayNodeBetween(int segmentIndex, {MapCoordinate? coordinate}) {
    if (segmentIndex < 0 || segmentIndex >= _taxiwayNodes.length - 1) {
      return;
    }
    final start = _taxiwayNodes[segmentIndex];
    final end = _taxiwayNodes[segmentIndex + 1];
    final before = _captureTaxiwaySnapshot();
    final inserted = MapTaxiwayNode(
      latitude: coordinate?.latitude ?? (start.latitude + end.latitude) / 2,
      longitude: coordinate?.longitude ?? (start.longitude + end.longitude) / 2,
    );
    final nextNodes = [..._taxiwayNodes];
    nextNodes.insert(segmentIndex + 1, inserted);
    _taxiwayNodes = nextNodes;
    _resetTaxiwaySegmentCompletionState();
    _splitTaxiwaySegmentAt(segmentIndex);
    _commitTaxiwayOperation(before);
    _hasUnsavedTaxiwayChanges = true;
    notifyListeners();
  }

  void updateTaxiwaySegmentInfo(
    int segmentIndex, {
    String? name,
    String? colorHex,
    String? note,
    MapTaxiwaySegmentLineType? lineType,
    double? curvature,
    MapTaxiwaySegmentCurveDirection? curveDirection,
  }) {
    if (segmentIndex < 0 || segmentIndex >= _taxiwaySegments.length) {
      return;
    }
    final normalizedName = _normalizeOptionalText(name);
    final normalizedColorHex = _normalizeTaxiwayColorHex(colorHex);
    final normalizedNote = _normalizeOptionalText(note);
    final normalizedCurvature = _normalizeTaxiwayCurvature(curvature);
    final nextSegments = [..._taxiwaySegments];
    final target = nextSegments[segmentIndex];
    nextSegments[segmentIndex] = target.copyWith(
      name: normalizedName,
      clearName: normalizedName == null,
      colorHex: normalizedColorHex,
      clearColorHex: normalizedColorHex == null,
      note: normalizedNote,
      clearNote: normalizedNote == null,
      lineType: lineType ?? target.lineType,
      curvature: normalizedCurvature ?? target.curvature,
      curveDirection: curveDirection ?? target.curveDirection,
    );
    final before = _captureTaxiwaySnapshot();
    _taxiwaySegments = nextSegments;
    _commitTaxiwayOperation(before);
    _hasUnsavedTaxiwayChanges = true;
    notifyListeners();
  }

  void removeTaxiwayNodeAt(int index) {
    if (index < 0 || index >= _taxiwayNodes.length) {
      return;
    }
    final before = _captureTaxiwaySnapshot();
    final nextNodes = [..._taxiwayNodes];
    nextNodes.removeAt(index);
    _taxiwayNodes = nextNodes;
    _resetTaxiwaySegmentCompletionState();
    _syncTaxiwaySegmentsWithNodes();
    _commitTaxiwayOperation(before);
    _hasUnsavedTaxiwayChanges = true;
    notifyListeners();
  }

  void undoTaxiwayRoutePoint() {
    if (_taxiwayUndoHistory.isEmpty) {
      return;
    }
    final nextUndoHistory = [..._taxiwayUndoHistory];
    final record = nextUndoHistory.removeLast();
    _taxiwayUndoHistory = nextUndoHistory;
    _taxiwayNodes = record.before.nodes;
    _taxiwaySegments = record.before.segments;
    _resetTaxiwaySegmentCompletionState();
    _taxiwayRedoHistory = _appendTaxiwayHistoryRecord(
      _taxiwayRedoHistory,
      record,
    );
    _hasUnsavedTaxiwayChanges = true;
    notifyListeners();
  }

  void redoTaxiwayRoutePoint() {
    if (_taxiwayRedoHistory.isEmpty) {
      return;
    }
    final nextRedoHistory = [..._taxiwayRedoHistory];
    final record = nextRedoHistory.removeLast();
    _taxiwayRedoHistory = nextRedoHistory;
    _taxiwayNodes = record.after.nodes;
    _taxiwaySegments = record.after.segments;
    _resetTaxiwaySegmentCompletionState();
    _taxiwayUndoHistory = _appendTaxiwayHistoryRecord(
      _taxiwayUndoHistory,
      record,
    );
    _hasUnsavedTaxiwayChanges = true;
    notifyListeners();
  }

  void clearTaxiwayRoute() {
    if (_taxiwayNodes.isEmpty &&
        _taxiwaySegments.isEmpty &&
        _taxiwayUndoHistory.isEmpty &&
        _taxiwayRedoHistory.isEmpty) {
      return;
    }
    _taxiwayNodes = const [];
    _taxiwaySegments = const [];
    _resetTaxiwaySegmentCompletionState();
    _taxiwayUndoHistory = const [];
    _taxiwayRedoHistory = const [];
    _loadedTaxiwayAirportIcao = null;
    _loadedTaxiwayFilePath = null;
    _loadedTaxiwayCreatedAt = null;
    _hasUnsavedTaxiwayChanges = false;
    notifyListeners();
  }

  /// 将当前滑行路线导出保存到文件。
  ///
  /// 返回值：
  /// - `1`  导出成功
  /// - `0`  用户取消（文件选择器未选择路径）
  /// - `-1` 路线为空，无法导出
  Future<int> exportTaxiwayRouteToFile() async {
    if (_taxiwayNodes.isEmpty) return -1;

    final icao = (_loadedTaxiwayAirportIcao ?? _resolveTaxiwayIcaoForFileName())
        .trim()
        .toUpperCase();

    // 委托文件 I/O 组件完成实际写入
    final result = await MapTaxiwayFileComponent.exportToFile(
      nodes: _taxiwayNodes,
      segments: _taxiwaySegments,
      airportIcao: icao,
      loadedCreatedAt: _loadedTaxiwayCreatedAt,
      loadedFilePath: _loadedTaxiwayFilePath,
    );

    if (result <= 0) return result;

    // 导出成功后更新元数据状态
    _hasUnsavedTaxiwayChanges = false;
    _loadedTaxiwayAirportIcao = icao;
    // 更新文件路径（由组件规范化后的路径），此处用规范化工具保持一致
    if (_loadedTaxiwayFilePath == null) {
      // 简单回写（文件组件内部已处理路径规范化）
      _loadedTaxiwayCreatedAt ??= DateTime.now();
    }
    _syncTaxiwaySegmentsWithNodes();
    notifyListeners();
    return 1;
  }

  /// 通过文件选择器导入滑行路线文件。
  ///
  /// 返回值：
  /// - `>0` 导入的节点数
  /// - `0`  文件解析失败（格式不合法）
  /// - `-1` 用户取消（未选择文件）
  Future<int> importTaxiwayRouteFromFile() async {
    final loaded = await MapTaxiwayFileComponent.importFromFilePicker();
    if (loaded == null) return -1;
    final importedNodes = loaded.nodes;
    if (importedNodes.isEmpty) return 0;
    _applyTaxiwayFileData(loaded, null);
    notifyListeners();
    return importedNodes.length;
  }

  /// 通过已知路径导入滑行路线文件。
  ///
  /// 返回值：
  /// - `>0` 导入的节点数
  /// - `0`  文件解析失败
  Future<int> importTaxiwayRouteFromPath(String filePath) async {
    final loaded = await MapTaxiwayFileComponent.loadFromPath(filePath);
    final importedNodes = loaded?.nodes;
    if (importedNodes == null || importedNodes.isEmpty) return 0;
    _applyTaxiwayFileData(loaded!, filePath);
    notifyListeners();
    return importedNodes.length;
  }

  /// 将已解析的文件数据应用到当前状态。
  void _applyTaxiwayFileData(MapTaxiwayFileData loaded, String? filePath) {
    _taxiwayNodes = loaded.nodes;
    _taxiwaySegments = loaded.segments.isNotEmpty ? loaded.segments : const [];
    _resetTaxiwaySegmentCompletionState();
    _syncTaxiwaySegmentsWithNodes();
    _taxiwayUndoHistory = const [];
    _taxiwayRedoHistory = const [];
    _hasUnsavedTaxiwayChanges = false;
    _loadedTaxiwayAirportIcao =
        loaded.airportIcao ??
        (filePath != null
            ? MapTaxiwayFileComponent.extractIcaoFromPath(filePath)
            : null);
    _loadedTaxiwayFilePath = filePath != null
        ? MapTaxiwayFileComponent.normalizeJsonFilePath(filePath)
        : null;
    _loadedTaxiwayCreatedAt = loaded.createdAt;
  }

  bool hasLoadedCustomTaxiwayForAirport(String icao) {
    final normalized = icao.trim().toUpperCase();
    if (normalized.isEmpty) {
      return false;
    }
    return _loadedTaxiwayAirportIcao == normalized && _taxiwayNodes.isNotEmpty;
  }

  /// 列出当前最近机场的滑行路线文件摘要，按修改时间降序排列。
  Future<List<MapTaxiwayFileSummary>>
  listTaxiwayRouteFilesForCurrentAirport() async {
    return listTaxiwayRouteFilesForAirport(icao: _currentNearestAirportIcao);
  }

  /// 列出指定机场的滑行路线文件摘要，按修改时间降序排列。
  Future<List<MapTaxiwayFileSummary>> listTaxiwayRouteFilesForAirport({
    String? icao,
  }) async {
    final resolvedIcao =
        icao?.trim().toUpperCase() ?? _resolveTaxiwayIcaoForFileName();
    if (resolvedIcao.isEmpty || resolvedIcao == 'UNKNOWN') return const [];
    // 委托文件 I/O 组件完成目录遍历与摘要构建
    return MapTaxiwayFileComponent.listFilesForAirport(resolvedIcao);
  }

  // 文件 I/O 方法已委托至 MapTaxiwayFileComponent，原始私有方法已移除。

  String _resolveTaxiwayIcaoForFileName() {
    final nearestIcao = _currentNearestAirportIcao?.trim().toUpperCase();
    if (nearestIcao != null && nearestIcao.isNotEmpty) {
      return nearestIcao;
    }
    final homeIcao = _homeAirport?.code.trim().toUpperCase();
    if (homeIcao != null && homeIcao.isNotEmpty) {
      return homeIcao;
    }
    return 'UNKNOWN';
  }

  // JSON 节点/线段解析已委托至 MapTaxiwayFileComponent，原始私有方法已移除。

  void _syncTaxiwaySegmentsWithNodes() {
    final targetLength = _taxiwayNodes.length > 1
        ? _taxiwayNodes.length - 1
        : 0;
    if (targetLength == _taxiwaySegments.length) {
      return;
    }
    if (targetLength <= 0) {
      _taxiwaySegments = const [];
      return;
    }
    final nextSegments = <MapTaxiwaySegment>[];
    for (var i = 0; i < targetLength; i++) {
      if (i < _taxiwaySegments.length) {
        nextSegments.add(_taxiwaySegments[i]);
      } else {
        nextSegments.add(const MapTaxiwaySegment());
      }
    }
    _taxiwaySegments = nextSegments;
  }

  void _splitTaxiwaySegmentAt(int segmentIndex) {
    final targetLength = _taxiwayNodes.length > 1
        ? _taxiwayNodes.length - 1
        : 0;
    if (targetLength <= 0) {
      _taxiwaySegments = const [];
      return;
    }
    if (segmentIndex < 0 || segmentIndex > targetLength - 2) {
      _syncTaxiwaySegmentsWithNodes();
      return;
    }
    final original = segmentIndex < _taxiwaySegments.length
        ? _taxiwaySegments[segmentIndex]
        : const MapTaxiwaySegment();
    final nextSegments = [..._taxiwaySegments];
    if (segmentIndex < nextSegments.length) {
      nextSegments[segmentIndex] = original;
      final insertedSegment = MapTaxiwaySegment(
        colorHex: original.colorHex,
        lineType: original.lineType,
        curvature: original.curvature,
        curveDirection: original.curveDirection,
      );
      nextSegments.insert(segmentIndex + 1, insertedSegment);
    } else {
      nextSegments.add(const MapTaxiwaySegment());
      nextSegments.add(const MapTaxiwaySegment());
    }
    _taxiwaySegments = nextSegments;
    _syncTaxiwaySegmentsWithNodes();
  }

  _TaxiwayOperationSnapshot _captureTaxiwaySnapshot() {
    return _TaxiwayOperationSnapshot(
      nodes: List<MapTaxiwayNode>.unmodifiable(_taxiwayNodes),
      segments: List<MapTaxiwaySegment>.unmodifiable(_taxiwaySegments),
    );
  }

  void _commitTaxiwayOperation(_TaxiwayOperationSnapshot before) {
    final after = _captureTaxiwaySnapshot();
    if (_isTaxiwaySnapshotEqual(before, after)) {
      return;
    }
    final record = _TaxiwayOperationRecord(before: before, after: after);
    _taxiwayUndoHistory = _appendTaxiwayHistoryRecord(
      _taxiwayUndoHistory,
      record,
    );
    _taxiwayRedoHistory = const [];
  }

  List<_TaxiwayOperationRecord> _appendTaxiwayHistoryRecord(
    List<_TaxiwayOperationRecord> source,
    _TaxiwayOperationRecord record,
  ) {
    final next = [...source, record];
    if (next.length <= _maxTaxiwayHistorySize) {
      return next;
    }
    return next.sublist(next.length - _maxTaxiwayHistorySize);
  }

  bool _isTaxiwaySnapshotEqual(
    _TaxiwayOperationSnapshot a,
    _TaxiwayOperationSnapshot b,
  ) {
    return _isTaxiwayNodeListEqual(a.nodes, b.nodes) &&
        _isTaxiwaySegmentListEqual(a.segments, b.segments);
  }

  bool _isTaxiwayNodeListEqual(List<MapTaxiwayNode> a, List<MapTaxiwayNode> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.latitude != right.latitude ||
          left.longitude != right.longitude ||
          left.name != right.name ||
          left.colorHex != right.colorHex ||
          left.note != right.note) {
        return false;
      }
    }
    return true;
  }

  bool _isTaxiwaySegmentListEqual(
    List<MapTaxiwaySegment> a,
    List<MapTaxiwaySegment> b,
  ) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.name != right.name ||
          left.colorHex != right.colorHex ||
          left.note != right.note ||
          left.lineType != right.lineType ||
          left.curvature != right.curvature ||
          left.curveDirection != right.curveDirection) {
        return false;
      }
    }
    return true;
  }

  String? _normalizeOptionalText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String? _normalizeTaxiwayColorHex(String? value) {
    final normalized = _normalizeOptionalText(value);
    if (normalized == null) {
      return null;
    }
    var compact = normalized.toUpperCase();
    if (compact.startsWith('#')) {
      compact = compact.substring(1);
    }
    if (RegExp(r'^[0-9A-F]{6}$').hasMatch(compact)) {
      return '#$compact';
    }
    if (RegExp(r'^[0-9A-F]{8}$').hasMatch(compact)) {
      return '#$compact';
    }
    return null;
  }

  double? _normalizeTaxiwayCurvature(double? value) {
    if (value == null || value.isNaN || value.isInfinite) {
      return null;
    }
    return value.clamp(0.0, 1.0).toDouble();
  }

  void _resetTaxiwaySegmentCompletionState() {
    _completedTaxiwaySegmentIndexes = const <int>{};
    _taxiwayMatchedProgress = null;
  }

  void _updateTaxiwaySegmentCompletionByAircraft(
    MapAircraftState aircraftState,
  ) {
    if (!_isConnected ||
        aircraftState.onGround != true ||
        _taxiwayNodes.length < 2) {
      return;
    }
    final match = _matchTaxiwaySegmentProgress(aircraftState.position);
    if (match == null ||
        match.distanceMeters > _taxiwayMatchMaxDistanceMeters) {
      return;
    }
    final previousProgress = _taxiwayMatchedProgress;
    var nextProgress = match.progress;
    if (previousProgress != null && nextProgress + 0.08 < previousProgress) {
      nextProgress = previousProgress;
    }
    _taxiwayMatchedProgress = nextProgress;
    final segmentCount = _taxiwayNodes.length - 1;
    final completedCount = nextProgress.floor().clamp(0, segmentCount).toInt();
    final nextCompleted = <int>{};
    for (var i = 0; i < completedCount; i += 1) {
      nextCompleted.add(i);
    }
    if (nextCompleted.length == _completedTaxiwaySegmentIndexes.length &&
        nextCompleted.containsAll(_completedTaxiwaySegmentIndexes)) {
      return;
    }
    _completedTaxiwaySegmentIndexes = nextCompleted;
  }

  _TaxiwaySegmentMatchResult? _matchTaxiwaySegmentProgress(
    MapCoordinate point,
  ) {
    final segmentCount = _taxiwayNodes.length - 1;
    if (segmentCount <= 0) {
      return null;
    }
    _TaxiwaySegmentMatchResult? best;
    for (var segmentIndex = 0; segmentIndex < segmentCount; segmentIndex += 1) {
      final start = _taxiwayNodes[segmentIndex];
      final end = _taxiwayNodes[segmentIndex + 1];
      final segment = segmentIndex < _taxiwaySegments.length
          ? _taxiwaySegments[segmentIndex]
          : const MapTaxiwaySegment();
      final polylinePoints = _buildTaxiwaySegmentPolylinePoints(
        start: start,
        end: end,
        segment: segment,
      );
      if (polylinePoints.length < 2) {
        continue;
      }
      var segmentLengthMeters = 0.0;
      final lengths = <double>[];
      for (var i = 0; i < polylinePoints.length - 1; i += 1) {
        final from = polylinePoints[i];
        final to = polylinePoints[i + 1];
        final length = MapGeoUtils.distanceMeters(
          from.latitude,
          from.longitude,
          to.latitude,
          to.longitude,
        );
        lengths.add(length);
        segmentLengthMeters += length;
      }
      if (segmentLengthMeters <= 0.01) {
        continue;
      }
      var traversedMeters = 0.0;
      var bestDistanceInSegment = double.infinity;
      var bestAlongMeters = 0.0;
      for (var i = 0; i < polylinePoints.length - 1; i += 1) {
        final from = polylinePoints[i];
        final to = polylinePoints[i + 1];
        final length = lengths[i];
        if (length <= 0.01) {
          continue;
        }
        final projection = MapGeoUtils.projectPointToRunway(
          point: point,
          runwayStart: from,
          runwayEnd: to,
        );
        final ratio = projection.alongTrackRatio.clamp(0.0, 1.0).toDouble();
        final closestLat =
            from.latitude + (to.latitude - from.latitude) * ratio;
        final closestLon =
            from.longitude + (to.longitude - from.longitude) * ratio;
        final distance = MapGeoUtils.distanceMeters(
          point.latitude,
          point.longitude,
          closestLat,
          closestLon,
        );
        if (distance < bestDistanceInSegment) {
          bestDistanceInSegment = distance;
          bestAlongMeters = traversedMeters + length * ratio;
        }
        traversedMeters += length;
      }
      final normalizedProgress =
          (bestAlongMeters / math.max(segmentLengthMeters, 0.01)).clamp(
            0.0,
            1.0,
          );
      final globalProgress = segmentIndex + normalizedProgress;
      final candidate = _TaxiwaySegmentMatchResult(
        segmentIndex: segmentIndex,
        progress: globalProgress,
        distanceMeters: bestDistanceInSegment,
      );
      if (best == null || candidate.distanceMeters < best.distanceMeters) {
        best = candidate;
      }
    }
    return best;
  }

  List<MapCoordinate> _buildTaxiwaySegmentPolylinePoints({
    required MapTaxiwayNode start,
    required MapTaxiwayNode end,
    required MapTaxiwaySegment segment,
  }) {
    if (segment.lineType == MapTaxiwaySegmentLineType.straight) {
      return <MapCoordinate>[
        MapCoordinate(latitude: start.latitude, longitude: start.longitude),
        MapCoordinate(latitude: end.latitude, longitude: end.longitude),
      ];
    }
    final startLat = start.latitude;
    final startLon = start.longitude;
    final endLat = end.latitude;
    final endLon = end.longitude;
    final deltaLat = endLat - startLat;
    final deltaLon = endLon - startLon;
    final distance = math.sqrt(deltaLat * deltaLat + deltaLon * deltaLon);
    if (distance <= 0) {
      return <MapCoordinate>[
        MapCoordinate(latitude: startLat, longitude: startLon),
        MapCoordinate(latitude: endLat, longitude: endLon),
      ];
    }
    final normalizedCurvature = segment.curvature.clamp(0.0, 1.0);
    final offsetFactor = 0.12 + normalizedCurvature * 0.45;
    final offset = distance * offsetFactor;
    final directionSign = segment.curveDirection.sign.toDouble();
    final perpLat = -deltaLon / distance;
    final perpLon = deltaLat / distance;
    final controlLat =
        (startLat + endLat) / 2 + perpLat * offset * directionSign;
    final controlLon =
        (startLon + endLon) / 2 + perpLon * offset * directionSign;
    const sampleCount = 24;
    final points = <MapCoordinate>[];
    for (var i = 0; i <= sampleCount; i += 1) {
      final t = i / sampleCount;
      final oneMinusT = 1 - t;
      final lat =
          oneMinusT * oneMinusT * startLat +
          2 * oneMinusT * t * controlLat +
          t * t * endLat;
      final lon =
          oneMinusT * oneMinusT * startLon +
          2 * oneMinusT * t * controlLon +
          t * t * endLon;
      points.add(MapCoordinate(latitude: lat, longitude: lon));
    }
    return points;
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

  Future<void> setAutoHudTimerEnabled(bool value) async {
    if (_autoHudTimerEnabled == value) {
      return;
    }
    _autoHudTimerEnabled = value;
    if (!value && _isHudTimerRunning) {
      pauseHudTimer();
    } else {
      _reconcileAutoHudTimerWithCurrentState();
    }
    notifyListeners();
    final persistence = PersistenceService();
    await persistence.setModuleData(
      _moduleName,
      _autoHudTimerEnabledKey,
      value,
    );
  }

  Future<void> setAutoTimerStartMode(MapAutoTimerStartMode mode) async {
    if (_autoTimerStartMode == mode) {
      return;
    }
    _autoTimerStartMode = mode;
    _reconcileAutoHudTimerWithCurrentState();
    notifyListeners();
    final persistence = PersistenceService();
    await persistence.setModuleData(
      _moduleName,
      _autoTimerStartModeKey,
      mode.index,
    );
  }

  Future<void> setAutoTimerStopMode(MapAutoTimerStopMode mode) async {
    if (_autoTimerStopMode == mode) {
      return;
    }
    _autoTimerStopMode = mode;
    _reconcileAutoHudTimerWithCurrentState();
    notifyListeners();
    final persistence = PersistenceService();
    await persistence.setModuleData(
      _moduleName,
      _autoTimerStopModeKey,
      mode.index,
    );
  }

  Future<void> setAlertsEnabled(bool value) async {
    if (_alertsEnabled == value) {
      return;
    }
    _alertsEnabled = value;
    notifyListeners();
    final persistence = PersistenceService();
    await persistence.setModuleData(_moduleName, _alertsEnabledKey, value);
  }

  Future<void> setAlertEnabled(String alertId, bool enabled) async {
    final normalizedId = alertId.trim().toLowerCase();
    if (normalizedId.isEmpty) {
      return;
    }
    final next = {..._disabledAlertIds};
    if (enabled) {
      next.remove(normalizedId);
    } else {
      next.add(normalizedId);
    }
    if (next.length == _disabledAlertIds.length &&
        next.containsAll(_disabledAlertIds)) {
      return;
    }
    _disabledAlertIds = next;
    notifyListeners();
    final persistence = PersistenceService();
    await persistence.setModuleData(
      _moduleName,
      _disabledAlertIdsKey,
      _disabledAlertIds.toList(),
    );
  }

  Future<void> setVerticalRateThresholds({
    required int climbWarningFpm,
    required int climbDangerFpm,
    required int descentWarningFpm,
    required int descentDangerFpm,
  }) async {
    if (climbWarningFpm <= 0 ||
        climbDangerFpm <= climbWarningFpm ||
        descentWarningFpm <= 0 ||
        descentDangerFpm <= descentWarningFpm) {
      return;
    }
    if (_climbRateWarningFpm == climbWarningFpm &&
        _climbRateDangerFpm == climbDangerFpm &&
        _descentRateWarningFpm == descentWarningFpm &&
        _descentRateDangerFpm == descentDangerFpm) {
      return;
    }
    _climbRateWarningFpm = climbWarningFpm;
    _climbRateDangerFpm = climbDangerFpm;
    _descentRateWarningFpm = descentWarningFpm;
    _descentRateDangerFpm = descentDangerFpm;
    notifyListeners();
    final persistence = PersistenceService();
    await persistence.setModuleData(
      _moduleName,
      _climbRateWarningFpmKey,
      _climbRateWarningFpm,
    );
    await persistence.setModuleData(
      _moduleName,
      _climbRateDangerFpmKey,
      _climbRateDangerFpm,
    );
    await persistence.setModuleData(
      _moduleName,
      _descentRateWarningFpmKey,
      _descentRateWarningFpm,
    );
    await persistence.setModuleData(
      _moduleName,
      _descentRateDangerFpmKey,
      _descentRateDangerFpm,
    );
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
    _hasHudTimerStarted = false;
    _resetTaxiwaySegmentCompletionState();
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
    if (_isHudTimerRunning || _isPaused) {
      return;
    }
    _autoFlightCycleEnded = false;
    _hasHudTimerStarted = true;
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
    _hasHudTimerStarted = false;
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
    _aiAircraft = const [];
    _currentNearestAirportIcao = null;
    _lastOnGround = null;
    _isPaused = false;
    _isAircraftMoving = false;
    _lastMovementSamplePosition = null;
    _lastMovementSampleAt = null;
    _resetAutoTimerRuntimeState();
  }

  double _distanceInMeters(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
  ) {
    const earthRadiusM = 6371000.0;
    final lat1 = startLat * (math.pi / 180.0);
    final lon1 = startLon * (math.pi / 180.0);
    final lat2 = endLat * (math.pi / 180.0);
    final lon2 = endLon * (math.pi / 180.0);
    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusM * c;
  }

  void _handleAutoHudTimer({
    required MapAircraftState aircraftState,
    required bool isMoving,
    required DateTime now,
  }) {
    final onGround = aircraftState.onGround ?? false;
    final parkingBrake = aircraftState.parkingBrake ?? false;
    final groundSpeed = aircraftState.groundSpeed ?? 0;
    final verticalSpeed = (aircraftState.verticalSpeed ?? 0).abs();
    final touchedDownNow =
        _isHudTimerRunning &&
        _hudTimerAirborneSinceStart &&
        _lastOnGround == false &&
        onGround;
    if (_isHudTimerRunning) {
      if (!onGround) {
        _hudTimerAirborneSinceStart = true;
        _groundStableSince = null;
      }
      if (touchedDownNow) {
        _hudTimerLandedSinceStart = true;
        _groundStableSince = null;
      }
    }
    if (onGround && parkingBrake) {
      _pushbackStartArmed = true;
    }

    if (_autoHudTimerEnabled && !_isPaused) {
      if (!_isHudTimerRunning) {
        if (_autoFlightCycleEnded) {
          _lastAutoParkingBrake = parkingBrake;
          return;
        }
        var shouldStart = false;
        switch (_autoTimerStartMode) {
          case MapAutoTimerStartMode.runwayMovement:
            final likelyOnRunwayRoll =
                onGround &&
                isMoving &&
                parkingBrake == false &&
                groundSpeed >= 8 &&
                _isNearRunwayOrEndpoint(aircraftState);
            shouldStart = likelyOnRunwayRoll;
            break;
          case MapAutoTimerStartMode.pushback:
            final brakeReleasedNow =
                _lastAutoParkingBrake == true && parkingBrake == false;
            shouldStart =
                onGround &&
                isMoving &&
                groundSpeed >= 2 &&
                parkingBrake == false &&
                (brakeReleasedNow || _pushbackStartArmed);
            break;
          case MapAutoTimerStartMode.anyMovement:
            shouldStart = isMoving;
            break;
        }
        if (shouldStart) {
          startHudTimer();
          _pushbackStartArmed = false;
        }
      } else {
        var shouldStop = false;
        switch (_autoTimerStopMode) {
          case MapAutoTimerStopMode.stableLanding:
            if ((_hudTimerLandedSinceStart || _hudTimerAirborneSinceStart) &&
                onGround) {
              final stableForSeconds = _stableForSeconds(
                condition: groundSpeed <= 35 && verticalSpeed <= 220,
                now: now,
              );
              shouldStop = stableForSeconds >= 6;
            } else {
              _groundStableSince = null;
            }
            break;
          case MapAutoTimerStopMode.runwayExitAfterLanding:
            if ((_hudTimerLandedSinceStart || _hudTimerAirborneSinceStart) &&
                onGround) {
              final stableForSeconds = _stableForSeconds(
                condition: groundSpeed <= 22 && verticalSpeed <= 300,
                now: now,
              );
              shouldStop = stableForSeconds >= 5;
            } else {
              _groundStableSince = null;
            }
            break;
          case MapAutoTimerStopMode.parkingArrival:
            if (onGround) {
              final brakeReleasedNow =
                  _lastAutoParkingBrake == true && parkingBrake == false;
              final isGroundSpeedZero = groundSpeed <= 0.1;
              shouldStop = brakeReleasedNow && isGroundSpeedZero;
            } else {
              _groundStableSince = null;
            }
            break;
        }
        if (shouldStop) {
          _autoFlightCycleEnded = true;
          pauseHudTimer();
        }
      }
    }

    _lastAutoParkingBrake = parkingBrake;
  }

  void _reconcileAutoHudTimerWithCurrentState() {
    final aircraftState = _aircraft;
    if (aircraftState == null) {
      return;
    }
    _handleAutoHudTimer(
      aircraftState: aircraftState,
      isMoving: _isAircraftMoving,
      now: DateTime.now(),
    );
  }

  void _resetAutoTimerFlightStateForNewRun() {
    _hudTimerAirborneSinceStart = false;
    _hudTimerLandedSinceStart = false;
    _groundStableSince = null;
  }

  void _resetAutoTimerRuntimeState() {
    _lastAutoParkingBrake = null;
    _pushbackStartArmed = false;
    _autoFlightCycleEnded = false;
    _resetAutoTimerFlightStateForNewRun();
  }

  int _stableForSeconds({required bool condition, required DateTime now}) {
    if (!condition) {
      _groundStableSince = null;
      return 0;
    }
    _groundStableSince ??= now;
    return now.difference(_groundStableSince!).inSeconds;
  }

  Future<void> _ensureRunwayGeometryLoaded(String icaoCode) async {
    final normalized = icaoCode.trim().toUpperCase();
    if (normalized.isEmpty) {
      return;
    }
    if (_runwayGeometryCache.containsKey(normalized)) {
      return;
    }
    if (_runwayGeometryLoadingIcaos.contains(normalized)) {
      return;
    }
    final lastAttemptAt = _runwayGeometryLastAttemptAt[normalized];
    if (lastAttemptAt != null &&
        DateTime.now().difference(lastAttemptAt) <
            const Duration(seconds: 20)) {
      return;
    }
    _runwayGeometryLastAttemptAt[normalized] = DateTime.now();
    _runwayGeometryLoadingIcaos.add(normalized);
    try {
      final airport = _findAirportByCode(normalized);
      if (airport == null) {
        return;
      }
      final detail = await fetchSelectedAirportDetail(airport);
      if (detail.runwayGeometries.isNotEmpty) {
        _runwayGeometryCache[normalized] = detail.runwayGeometries;
      }
    } catch (_) {
    } finally {
      _runwayGeometryLoadingIcaos.remove(normalized);
    }
  }

  bool _isNearRunwayOrEndpoint(MapAircraftState aircraftState) {
    final icao = _currentNearestAirportIcao;
    if (icao == null || icao.isEmpty) {
      return false;
    }
    final runways = _runwayGeometryCache[icao];
    if (runways == null) {
      return false;
    }
    return MapFlightTrackComponent.isNearRunwayOrEndpoint(
      aircraftState: aircraftState,
      runways: runways,
    );
  }

  List<MapAirportMarker> _buildAirportsFromSnapshot(HomeDataSnapshot snapshot) {
    return MapAirportDataComponent.buildAirportsFromSnapshot(snapshot);
  }

  void _appendRoutePoint(
    MapAircraftState aircraftState,
    DateTime now,
    bool isMoving,
  ) {
    final result = MapFlightTrackComponent.appendRoutePoint(
      route: _route,
      lastRouteTimestamp: _lastRouteTimestamp,
      aircraftState: aircraftState,
      now: now,
      isMoving: isMoving,
    );
    _route = result.route;
    _lastRouteTimestamp = result.lastRouteTimestamp;
  }

  bool _resolveIsAircraftMoving(MapAircraftState aircraftState, DateTime now) {
    final result = MapFlightTrackComponent.resolveAircraftMoving(
      isConnected: _isConnected,
      isPaused: _isPaused,
      aircraftState: aircraftState,
      now: now,
      lastSamplePosition: _lastMovementSamplePosition,
      lastSampleAt: _lastMovementSampleAt,
    );
    _lastMovementSamplePosition = result.nextSamplePosition;
    _lastMovementSampleAt = result.nextSampleAt;
    return result.isMoving;
  }

  void _updateTakeoffLandingMarker(bool? onGround, MapCoordinate position) {
    final result = MapFlightTrackComponent.updateTakeoffLandingMarker(
      onGround: onGround,
      position: position,
      lastOnGround: _lastOnGround,
      takeoffPoint: _takeoffPoint,
      landingPoint: _landingPoint,
    );
    _lastOnGround = result.lastOnGround;
    _takeoffPoint = result.takeoffPoint;
    _landingPoint = result.landingPoint;
  }

  void _evaluateFlightAlerts(HomeFlightData flightData) {
    _activeAlerts = _alertComponent.evaluateFlightAlerts(
      isConnected: _isConnected,
      alertsEnabled: _alertsEnabled,
      disabledAlertIds: _disabledAlertIds,
      climbRateWarningFpm: _climbRateWarningFpm,
      climbRateDangerFpm: _climbRateDangerFpm,
      descentRateWarningFpm: _descentRateWarningFpm,
      descentRateDangerFpm: _descentRateDangerFpm,
      flightData: flightData,
    );
  }

  List<MapAirportMarker> _fallbackSearchAirports(String keyword) {
    return MapAirportDataComponent.fallbackSearchAirports(keyword, _airports);
  }

  MapAirportMarker _airportMarkerFromApi(Map<String, dynamic> raw) =>
      MapAirportApiParser.airportMarkerFromApi(
        raw,
        fallbackAirports: _airports,
      );

  MapAirportMarker? _findAirportByCode(String code) {
    return MapAirportDataComponent.findAirportByCode(code, _airports);
  }

  // ── 工具方法委托区 ─────────────────────────────────────────────────────────
  // 保留原始私有签名以兼容当前调用站点，内部统一委托至工具类。

  /// 见 [MapWeatherUtils.asMap]
  Map<String, dynamic>? _asMap(dynamic v) => MapWeatherUtils.asMap(v);

  List<dynamic>? _asList(dynamic v) {
    if (v is List<dynamic>) return v;
    if (v is List) return v.cast<dynamic>();
    return null;
  }

  /// 委托给 [MapAirportApiParser.normalizeRunwayIdent]
  String _normalizeRunwayIdent(String ident) =>
      MapAirportApiParser.normalizeRunwayIdent(ident);

  /// 委托给 [MapAirportApiParser.toRunwayGeometry]
  MapRunwayGeometry? _toRunwayGeometry(AirportRunwayData data) =>
      MapAirportApiParser.toRunwayGeometry(data);

  /// 委托给 [MapAirportApiParser.toParkingSpot]
  MapParkingSpot? _toParkingSpot(AirportParkingData data) =>
      MapAirportApiParser.toParkingSpot(data);

  /// 委托给 [MapAirportApiParser.resolveAirportCenter]
  MapCoordinate _resolveAirportCenter(
    List<MapRunwayGeometry> runways,
    double? latitude,
    double? longitude,
    MapCoordinate fallback,
  ) => MapAirportApiParser.resolveAirportCenter(
    runways,
    latitude,
    longitude,
    fallback,
  );

  /// 委托给 [MapGeoUtils.isValidCoordinate]
  bool _isValidCoordinate(double latitude, double longitude) =>
      MapGeoUtils.isValidCoordinate(latitude, longitude);

  /// 委托给 [MapWeatherUtils.extractMetarField]
  String? _extractMetarField(Map<String, dynamic> root, List<String> keys) =>
      MapWeatherUtils.extractMetarField(root, keys);

  /// 委托给 [MapWeatherUtils.normalizeWeatherText]
  String? _normalizeWeatherText(String? value) =>
      MapWeatherUtils.normalizeWeatherText(value);

  /// 委托给 [MapWeatherUtils.resolveApproachRule]
  String _resolveApproachRule(Map<String, dynamic> root, String? rawMetar) =>
      MapWeatherUtils.resolveApproachRule(root, rawMetar);

  @override
  void dispose() {
    _subscription?.cancel();
    _radarRefreshTimer?.cancel();
    _radarCooldownTimer?.cancel();
    _hudTimer?.cancel();
    super.dispose();
  }
}
