import 'dart:async';
import 'package:flutter/material.dart';
import '../models/simulator_data.dart';
import '../services/msfs_service.dart';
import '../services/xplane_service.dart';
import '../../core/utils/logger.dart';

enum SimulatorType { none, msfs, xplane }

enum ConnectionStatus { disconnected, connecting, connected, error }

class SimulatorProvider with ChangeNotifier {
  final MSFSService _msfsService = MSFSService();
  final XPlaneService _xplaneService = XPlaneService();

  SimulatorType _currentSimulator = SimulatorType.none;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  SimulatorData _simulatorData = SimulatorData.empty();
  String? _errorMessage;

  StreamSubscription<SimulatorData>? _dataSubscription;

  SimulatorType get currentSimulator => _currentSimulator;
  ConnectionStatus get status => _status;
  SimulatorData get simulatorData => _simulatorData;
  String? get errorMessage => _errorMessage;

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

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
