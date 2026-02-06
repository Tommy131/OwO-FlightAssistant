import 'dart:async';
import 'package:flutter/material.dart';
import '../models/simulator_data.dart';
import '../services/msfs_service.dart';
import '../services/xplane_service.dart';
import '../../core/utils/logger.dart';

import '../data/airports_database.dart';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';

enum SimulatorType { none, msfs, xplane }

enum ConnectionStatus { disconnected, connecting, connected, error }

class SimulatorProvider with ChangeNotifier {
  final MSFSService _msfsService = MSFSService();
  final XPlaneService _xplaneService = XPlaneService();

  SimulatorType _currentSimulator = SimulatorType.none;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  SimulatorData _simulatorData = SimulatorData.empty();
  String? _errorMessage;
  AirportInfo? _destinationAirport;
  StreamSubscription<SimulatorData>? _dataSubscription;

  // 图表历史数据
  final List<FlSpot> _gForceSpots = [];
  final List<FlSpot> _altitudeSpots = [];
  final List<FlSpot> _pressureSpots = [];
  double _chartTime = 0;
  DateTime? _lastChartUpdate;
  static const int _maxSpots = 300; // 记录约1分钟的数据 (以5Hz采样计)

  SimulatorType get currentSimulator => _currentSimulator;
  ConnectionStatus get status => _status;
  SimulatorData get simulatorData => _simulatorData;
  String? get errorMessage => _errorMessage;
  AirportInfo? get destinationAirport => _destinationAirport;

  // 图表历史数据 Getters
  List<FlSpot> get gForceSpots => _gForceSpots;
  List<FlSpot> get altitudeSpots => _altitudeSpots;
  List<FlSpot> get pressureSpots => _pressureSpots;
  double get chartTime => _chartTime;

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
      return _simulatorData.airspeed! > 30 ? '起飞中' : '地面停留';
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

    if (hoursVal == null) {
      return null;
    }

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
    notifyListeners();
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

    // 如果在地面或速度较低，使用参考速度预估 (喷气机 440kt, 活塞机 120kt)
    if (onGround || gs < 50) {
      final title = (_simulatorData.aircraftTitle ?? '').toLowerCase();
      final isJet =
          title.contains('737') ||
          title.contains('320') ||
          title.contains('747') ||
          title.contains('777') ||
          title.contains('airbus') ||
          title.contains('boeing');
      gs = isJet ? 440.0 : 120.0;
    }

    if (gs <= 0) return null;
    return distance / gs;
  }

  /// 计算所需燃油 (kg)
  /// 包含 15% 的储备燃油
  double? get requiredFuel {
    final distance = remainingDistance;
    if (distance == null) return null;

    final timeHours = estimatedTimeEnrouteHours;
    if (timeHours == null) return null;

    double ff = _simulatorData.fuelFlow ?? 0;
    final onGround = _simulatorData.onGround ?? true;

    // 判断机型，提供参考巡航数值
    final title = (_simulatorData.aircraftTitle ?? '').toLowerCase();
    final isJet =
        title.contains('737') ||
        title.contains('320') ||
        title.contains('747') ||
        title.contains('777') ||
        title.contains('airbus') ||
        title.contains('boeing');

    // 巡航参考油耗 (kg/h)
    final cruiseFF = isJet ? 2400.0 : 45.0;

    // 如果油耗太低（未启动或怠速），使用参考值进行预估
    if (onGround || ff < (isJet ? 800 : 15)) {
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
    const r = 3440.065; // 地球半径 (海里)
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

  void setAircraftDetectionCallback(Function(String) callback) {
    onAircraftDetected = callback;
    // 如果设置回调时已经有识别出的机型，立即通知一次
    final title = _simulatorData.aircraftTitle;
    if (title != null && title != 'Unknown Aircraft') {
      _notifyAircraftDetected(title);
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

  /// 连接到 X-Plane
  /// 返回连接结果，支持等待真实连接校验
  Future<bool> connectToXPlane() async {
    if (_status == ConnectionStatus.connecting) return false;

    // 先断开/清理旧连接
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

    // 创建一个 Completer 来等待真实数据的接收验证
    final Completer<bool> verificationCompleter = Completer<bool>();

    _dataSubscription?.cancel();
    _dataSubscription = _xplaneService.dataStream.listen((data) {
      _simulatorData = data;
      bool shouldNotify = false;

      if (data.isConnected && !verificationCompleter.isCompleted) {
        _status = ConnectionStatus.connected;
        verificationCompleter.complete(true);
        AppLogger.info('SimulatorProvider: X-Plane 数据校验成功');
        shouldNotify = true;
      } else if (!data.isConnected) {
        // 如果收到断开信号,且当前是已连接状态,则处理连接丢失
        if (_status == ConnectionStatus.connected) {
          _handleConnectionLoss();
          shouldNotify = true;
        }
        // 如果还在验证阶段收到断开信号,可能是手动断开
        if (!verificationCompleter.isCompleted) {
          verificationCompleter.complete(false);
        }
      }

      _detectAndSyncAircraft();

      // 更新图表记录
      _updateChartHistory();

      // 只在状态变化或已连接时通知
      if (shouldNotify || _status == ConnectionStatus.connected) {
        notifyListeners();
      }
    });

    try {
      // 等待最多 10 秒来校验真实连接(延长超时时间以适应模拟器加载完成的情况)
      final result = await verificationCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (!verificationCompleter.isCompleted) {
            verificationCompleter.complete(false);
          }
          return false;
        },
      );

      if (!result) {
        await disconnect();
        _status = ConnectionStatus.error;
        _errorMessage = '连接超时：未收到 X-Plane 数据。请确保 X-Plane 已启动并正确配置数据输出。';
        notifyListeners();
        return false;
      }
      return true;
    } catch (e) {
      await disconnect();
      _status = ConnectionStatus.error;
      _errorMessage = '连接校验过程出现异常: $e';
      notifyListeners();
      return false;
    }
  }

  /// 连接到 MSFS
  Future<bool> connectToMSFS() async {
    if (_status == ConnectionStatus.connecting) return false;

    // 先断开/清理旧连接
    await disconnect();

    _status = ConnectionStatus.connecting;
    _currentSimulator = SimulatorType.msfs;
    _errorMessage = null;
    notifyListeners();

    final success = await _msfsService.connect();
    if (success) {
      _status = ConnectionStatus.connected;
      _subscribeToData(_msfsService.dataStream);
      AppLogger.info('SimulatorProvider: 已连接到 MSFS');
      notifyListeners();
      return true;
    } else {
      _status = ConnectionStatus.error;
      _errorMessage = '无法连接到 MSFS WebSocket 服务器。请确保中间件已启动。';
      notifyListeners();
      return false;
    }
  }

  void _handleConnectionLoss() {
    _status = ConnectionStatus.disconnected;
    _currentSimulator = SimulatorType.none;
    _errorMessage = '模拟器连接已中断';
    _clearChartHistory();
    AppLogger.error('SimulatorProvider: 连接中断');
    notifyListeners();
  }

  /// 断开连接
  Future<void> disconnect() async {
    // AppLogger.info('SimulatorProvider: 开始断开连接...');

    // 先取消数据订阅
    await _dataSubscription?.cancel();
    _dataSubscription = null;

    // 仅在服务活跃时断开连接
    final List<Future> disconnectFutures = [];

    if (_msfsService.isActive) {
      disconnectFutures.add(
        _msfsService.disconnect().timeout(
          const Duration(seconds: 2),
          onTimeout: () => AppLogger.error('MSFS 断开超时'),
        ),
      );
    }

    if (_xplaneService.isActive) {
      disconnectFutures.add(
        _xplaneService.disconnect().timeout(
          const Duration(seconds: 2),
          onTimeout: () => AppLogger.error('X-Plane 断开超时'),
        ),
      );
    }

    if (disconnectFutures.isNotEmpty) {
      await Future.wait(disconnectFutures).catchError((e) {
        AppLogger.error('断开服务时出现异常: $e');
        return <void>[];
      });
    }

    // 重置状态
    _status = ConnectionStatus.disconnected;
    _currentSimulator = SimulatorType.none;
    _simulatorData = SimulatorData.empty();
    _errorMessage = null;
    _lastDetectedAircraft = null;
    _clearChartHistory();

    // AppLogger.info('SimulatorProvider: 断开连接完成');
    notifyListeners();
  }

  void _subscribeToData(Stream<SimulatorData> stream) {
    _dataSubscription?.cancel();
    _dataSubscription = stream.listen((data) {
      if (!data.isConnected && _status == ConnectionStatus.connected) {
        _handleConnectionLoss();
      }

      _simulatorData = data;
      _detectAndSyncAircraft();
      _updateChartHistory();
      notifyListeners();
    });
  }

  // 记录最后一次检测到的机型，避免重复通知
  String? _lastDetectedAircraft;

  void _detectAndSyncAircraft() {
    final title = _simulatorData.aircraftTitle;

    // 过滤掉空标题或未知机型，避免无效切换
    if (title != null &&
        title != 'Unknown Aircraft' &&
        title != _lastDetectedAircraft) {
      _lastDetectedAircraft = title;
      AppLogger.info('检测到机型变更: $title');
      _notifyAircraftDetected(title);
    }
  }

  Function(String)? onAircraftDetected;

  void _notifyAircraftDetected(String aircraftTitle) {
    if (onAircraftDetected != null) {
      String aircraftId = 'a320_series'; // 默认
      if (aircraftTitle.contains('737')) {
        aircraftId = 'b737_series';
      } else if (aircraftTitle.contains('A320')) {
        aircraftId = 'a320_series';
      }
      onAircraftDetected!(aircraftId);
    }
  }

  /// 更新图表历史记录 (采样频率控制在约 5Hz)
  void _updateChartHistory() {
    if (!isConnected) return;

    final now = DateTime.now();
    if (_lastChartUpdate != null &&
        now.difference(_lastChartUpdate!).inMilliseconds < 200) {
      return;
    }

    _lastChartUpdate = now;
    _chartTime += 0.2;

    // G-Force
    _gForceSpots.add(FlSpot(_chartTime, _simulatorData.gForce ?? 1.0));
    if (_gForceSpots.length > _maxSpots) _gForceSpots.removeAt(0);

    // Altitude
    if (_simulatorData.altitude != null) {
      _altitudeSpots.add(FlSpot(_chartTime, _simulatorData.altitude!));
      if (_altitudeSpots.length > _maxSpots) _altitudeSpots.removeAt(0);
    }

    // Pressure
    if (_simulatorData.baroPressure != null) {
      _pressureSpots.add(FlSpot(_chartTime, _simulatorData.baroPressure!));
      if (_pressureSpots.length > _maxSpots) _pressureSpots.removeAt(0);
    }
  }

  /// 清除图表历史记录
  void _clearChartHistory() {
    _gForceSpots.clear();
    _altitudeSpots.clear();
    _pressureSpots.clear();
    _chartTime = 0;
    _lastChartUpdate = null;
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
