import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

import '../models/simulator_data.dart';
import '../../core/utils/logger.dart';
import 'config/msfs_simvars.dart';

/// MSFS 连接服务（通过WebSocket中间层）
class MSFSService {
  static const String _defaultWsUrl = 'ws://localhost:8080';

  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isDisposed = false;
  Timer? _reconnectTimer;

  final StreamController<SimulatorData> _dataController =
      StreamController<SimulatorData>.broadcast();
  Stream<SimulatorData> get dataStream => _dataController.stream;

  SimulatorData _currentData = SimulatorData.empty();

  bool get isConnected => _isConnected;

  /// 服务是否正在运行（是否有活跃资源需要清理）
  bool get isActive => _channel != null || _reconnectTimer != null;

  /// 连接到 MSFS WebSocket 服务器
  Future<bool> connect({String? wsUrl}) async {
    try {
      _isDisposed = false;
      final url = wsUrl ?? _defaultWsUrl;
      AppLogger.info('正在尝试连接 MSFS WebSocket 服务器: $url');

      // 关闭旧连接
      await disconnect();
      _isDisposed = false; // disconnect 会设为 true，这里重置

      _channel = WebSocketChannel.connect(Uri.parse(url));

      // 核心修复：等待连接就绪，捕获握手阶段的同步/异步错误
      try {
        await _channel!.ready.timeout(const Duration(seconds: 3));
      } catch (e) {
        AppLogger.error('MSFS WebSocket 握手失败 (服务器可能未启动)', e);
        _handleDisconnect();
        return false;
      }

      // 监听消息
      _channel!.stream.listen(
        _handleIncomingMessage,
        onError: (error) {
          AppLogger.error('MSFS WebSocket 运行中错误', error);
          _handleDisconnect();
        },
        onDone: () {
          AppLogger.info('MSFS WebSocket 连接由服务器关闭');
          _handleDisconnect();
        },
        cancelOnError: true,
      );

      // 发送订阅请求
      await _subscribeToSimVars();

      _isConnected = true;
      _currentData = _currentData.copyWith(isConnected: true);
      _notifyData(_currentData);

      AppLogger.info('已成功连接到 MSFS！');
      return true;
    } catch (e) {
      AppLogger.error('连接 MSFS 过程出现异常', e);
      _handleDisconnect();
      return false;
    }
  }

  void _notifyData(SimulatorData data) {
    if (!_isDisposed && !_dataController.isClosed) {
      _dataController.add(data);
    }
  }

  /// 订阅SimConnect变量
  Future<void> _subscribeToSimVars() async {
    if (!_isConnected && _channel == null) return;

    // 使用配置类生成订阅消息
    final subscriptionMessage = MSFSSimVars.generateSubscriptionMessage();
    _sendMessage(subscriptionMessage);
  }

  /// 处理接收到的消息
  void _handleIncomingMessage(dynamic message) {
    if (_isDisposed) return;

    try {
      final data = jsonDecode(message as String);

      if (data is Map<String, dynamic>) {
        _updateSimulatorData(data);
        _notifyData(_currentData);
      }
    } catch (e) {
      AppLogger.error('解析 MSFS 数据失败', e);
    }
  }

  /// 更新模拟器数据
  void _updateSimulatorData(Map<String, dynamic> data) {
    if (data.containsKey('AIRSPEED_INDICATED')) {
      _currentData = _currentData.copyWith(
        airspeed: (data['AIRSPEED_INDICATED'] as num?)?.toDouble(),
      );
    }

    if (data.containsKey('INDICATED_ALTITUDE')) {
      _currentData = _currentData.copyWith(
        altitude: (data['INDICATED_ALTITUDE'] as num?)?.toDouble(),
      );
    }

    if (data.containsKey('PLANE_HEADING_DEGREES_MAGNETIC')) {
      _currentData = _currentData.copyWith(
        heading: (data['PLANE_HEADING_DEGREES_MAGNETIC'] as num?)?.toDouble(),
      );
    }

    if (data.containsKey('VERTICAL_SPEED')) {
      _currentData = _currentData.copyWith(
        verticalSpeed: (data['VERTICAL_SPEED'] as num?)?.toDouble(),
      );
    }

    if (data.containsKey('PLANE_LATITUDE')) {
      _currentData = _currentData.copyWith(
        latitude: (data['PLANE_LATITUDE'] as num?)?.toDouble(),
      );
    }

    if (data.containsKey('PLANE_LONGITUDE')) {
      _currentData = _currentData.copyWith(
        longitude: (data['PLANE_LONGITUDE'] as num?)?.toDouble(),
      );
    }

    if (data.containsKey('BRAKE PARKING INDICATOR')) {
      _currentData = _currentData.copyWith(
        parkingBrake:
            data['BRAKE PARKING INDICATOR'] == true ||
            data['BRAKE PARKING INDICATOR'] == 1,
      );
    }

    if (data.containsKey('LIGHT_BEACON')) {
      _currentData = _currentData.copyWith(
        beacon: data['LIGHT_BEACON'] == true || data['LIGHT_BEACON'] == 1,
      );
    }

    if (data.containsKey('LIGHT_LANDING')) {
      _currentData = _currentData.copyWith(
        landingLights:
            data['LIGHT_LANDING'] == true || data['LIGHT_LANDING'] == 1,
      );
    }

    if (data.containsKey('LIGHT_TAXI')) {
      _currentData = _currentData.copyWith(
        taxiLights: data['LIGHT_TAXI'] == true || data['LIGHT_TAXI'] == 1,
      );
    }

    if (data.containsKey('LIGHT_NAV')) {
      _currentData = _currentData.copyWith(
        navLights: data['LIGHT_NAV'] == true || data['LIGHT_NAV'] == 1,
      );
    }

    if (data.containsKey('LIGHT_STROBE')) {
      _currentData = _currentData.copyWith(
        strobes: data['LIGHT_STROBE'] == true || data['LIGHT_STROBE'] == 1,
      );
    }

    if (data.containsKey('FLAPS_HANDLE_INDEX')) {
      _currentData = _currentData.copyWith(
        flapsPosition: (data['FLAPS_HANDLE_INDEX'] as num?)?.toInt(),
      );
    }

    if (data.containsKey('TRAILING_EDGE_FLAPS_LEFT_PERCENT')) {
      final ratio = (data['TRAILING_EDGE_FLAPS_LEFT_PERCENT'] as num?)
          ?.toDouble();
      _currentData = _currentData.copyWith(
        flapsDeployRatio: ratio,
        flapsDeployed: ratio != null && ratio > 0.05,
      );
    }

    if (data.containsKey('APU_SWITCH')) {
      _currentData = _currentData.copyWith(
        apuRunning: data['APU_SWITCH'] == true || data['APU_SWITCH'] == 1,
      );
    }

    if (data.containsKey('GENERAL_ENG_COMBUSTION:1')) {
      _currentData = _currentData.copyWith(
        engine1Running:
            data['GENERAL_ENG_COMBUSTION:1'] == true ||
            data['GENERAL_ENG_COMBUSTION:1'] == 1,
      );
    }

    if (data.containsKey('GENERAL_ENG_COMBUSTION:2')) {
      _currentData = _currentData.copyWith(
        engine2Running:
            data['GENERAL_ENG_COMBUSTION:2'] == true ||
            data['GENERAL_ENG_COMBUSTION:2'] == 1,
      );
    }

    if (data.containsKey('ENG_N1:1')) {
      _currentData = _currentData.copyWith(
        engine1N1: (data['ENG_N1:1'] as num?)?.toDouble(),
      );
    }

    if (data.containsKey('ENG_N1:2')) {
      _currentData = _currentData.copyWith(
        engine2N1: (data['ENG_N1:2'] as num?)?.toDouble(),
      );
    }

    if (data.containsKey('AUTOPILOT_MASTER')) {
      _currentData = _currentData.copyWith(
        autopilotEngaged:
            data['AUTOPILOT_MASTER'] == true || data['AUTOPILOT_MASTER'] == 1,
      );
    }

    if (data.containsKey('AUTOPILOT_THROTTLE_ARM')) {
      _currentData = _currentData.copyWith(
        autothrottleEngaged:
            data['AUTOPILOT_THROTTLE_ARM'] == true ||
            data['AUTOPILOT_THROTTLE_ARM'] == 1,
      );
    }

    if (data.containsKey('G FORCE')) {
      _currentData = _currentData.copyWith(
        gForce: (data['G FORCE'] as num?)?.toDouble(),
      );
    }

    if (data.containsKey('BAROMETER PRESSURE')) {
      _currentData = _currentData.copyWith(
        baroPressure: (data['BAROMETER PRESSURE'] as num?)?.toDouble(),
      );
    }

    // 起落架详细状态
    if (data.containsKey('GEAR CENTER POSITION')) {
      _currentData = _currentData.copyWith(
        noseGearDown: (data['GEAR CENTER POSITION'] as num?)?.toDouble(),
      );
    }

    if (data.containsKey('GEAR LEFT POSITION')) {
      _currentData = _currentData.copyWith(
        leftGearDown: (data['GEAR LEFT POSITION'] as num?)?.toDouble(),
      );
    }

    if (data.containsKey('GEAR RIGHT POSITION')) {
      _currentData = _currentData.copyWith(
        rightGearDown: (data['GEAR RIGHT POSITION'] as num?)?.toDouble(),
      );
    }

    // 减速板与扰流板
    if (data.containsKey('SPOILERS HANDLE POSITION')) {
      final position = (data['SPOILERS HANDLE POSITION'] as num?)?.toDouble();
      _currentData = _currentData.copyWith(
        speedBrake: position != null && position > 0.05,
        speedBrakePosition: position,
      );
    }

    if (data.containsKey('SPOILERS LEFT POSITION')) {
      final position = (data['SPOILERS LEFT POSITION'] as num?)?.toDouble();
      _currentData = _currentData.copyWith(
        spoilersDeployed: position != null && position > 0.1,
      );
    }

    // 自动刹车
    if (data.containsKey('AUTOBRAKES_ACTIVE')) {
      final level = (data['AUTOBRAKES_ACTIVE'] as num?)?.toInt();
      _currentData = _currentData.copyWith(
        autoBrakeLevel: level != null && level > 0 ? level : null,
      );
    }

    // 警告系统
    if (data.containsKey('MASTER WARNING')) {
      _currentData = _currentData.copyWith(
        masterWarning:
            data['MASTER WARNING'] == true || data['MASTER WARNING'] == 1,
      );
    }

    if (data.containsKey('MASTER CAUTION')) {
      _currentData = _currentData.copyWith(
        masterCaution:
            data['MASTER CAUTION'] == true || data['MASTER CAUTION'] == 1,
      );
    }

    if (data.containsKey('ENG ON FIRE:1')) {
      _currentData = _currentData.copyWith(
        fireWarningEngine1:
            data['ENG ON FIRE:1'] == true || data['ENG ON FIRE:1'] == 1,
      );
    }

    if (data.containsKey('ENG ON FIRE:2')) {
      _currentData = _currentData.copyWith(
        fireWarningEngine2:
            data['ENG ON FIRE:2'] == true || data['ENG ON FIRE:2'] == 1,
      );
    }

    if (data.containsKey('APU ON FIRE')) {
      _currentData = _currentData.copyWith(
        fireWarningAPU: data['APU ON FIRE'] == true || data['APU ON FIRE'] == 1,
      );
    }

    // 环境数据
    if (data.containsKey('AMBIENT TEMPERATURE')) {
      _currentData = _currentData.copyWith(
        outsideAirTemperature: (data['AMBIENT TEMPERATURE'] as num?)
            ?.toDouble(),
      );
    }

    if (data.containsKey('TOTAL AIR TEMPERATURE')) {
      _currentData = _currentData.copyWith(
        totalAirTemperature: (data['TOTAL AIR TEMPERATURE'] as num?)
            ?.toDouble(),
      );
    }

    if (data.containsKey('AMBIENT WIND VELOCITY')) {
      _currentData = _currentData.copyWith(
        windSpeed: (data['AMBIENT WIND VELOCITY'] as num?)?.toDouble(),
      );
    }

    if (data.containsKey('AMBIENT WIND DIRECTION')) {
      _currentData = _currentData.copyWith(
        windDirection: (data['AMBIENT WIND DIRECTION'] as num?)?.toDouble(),
      );
    }

    if (data.containsKey('AMBIENT VISIBILITY')) {
      _currentData = _currentData.copyWith(
        visibility: (data['AMBIENT VISIBILITY'] as num?)?.toDouble(),
      );
    }

    if (data.containsKey('COM ACTIVE FREQUENCY:1')) {
      _currentData = _currentData.copyWith(
        com1Frequency: (data['COM ACTIVE FREQUENCY:1'] as num?)?.toDouble(),
      );
    }

    // MSFS 机型识别辅助 (MSFS 一般会在消息中包含更多信息，或者我们根据经纬度反查)
    if (_currentData.aircraftTitle == null ||
        _currentData.aircraftTitle == 'Unknown Aircraft') {
      _detectAircraftType();
    }
  }

  void _detectAircraftType() {
    // 简单的逻辑区分
    final flaps = _currentData.flapsPosition ?? 0;
    final isJet = (_currentData.engine1N1 ?? 0) > 10;

    if (isJet) {
      _currentData = _currentData.copyWith(
        aircraftTitle: flaps > 5 ? 'Boeing 737' : 'Airbus A320',
      );
    }
  }

  /// 发送消息到WebSocket服务器
  void _sendMessage(Map<String, dynamic> message) {
    if (_channel != null && _isConnected && !_isDisposed) {
      try {
        _channel!.sink.add(jsonEncode(message));
      } catch (e) {
        AppLogger.error('发送消息失败', e);
      }
    }
  }

  /// 处理断开连接
  void _handleDisconnect() {
    final wasConnected = _isConnected;
    _isConnected = false;
    _currentData = _currentData.copyWith(isConnected: false);
    _notifyData(_currentData);

    // 只有在曾经成功连接过的情况下才尝试自动重连
    if (wasConnected) {
      _scheduleReconnect();
    }
  }

  /// 计划重连
  void _scheduleReconnect() {
    if (_isDisposed) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 10), () {
      if (!_isConnected && !_isDisposed) {
        AppLogger.info('重连定时器触发: 尝试重新连接 MSFS...');
        connect();
      }
    });
  }

  /// 断开连接
  Future<void> disconnect() async {
    if (!isActive) return;
    AppLogger.info('MSFSService: 开始断开连接...');

    _isDisposed = true;
    _isConnected = false;
    _reconnectTimer?.cancel();

    // 发送断开连接状态到流
    _currentData = _currentData.copyWith(
      isConnected: false,
      aircraftTitle: null,
    );
    _notifyData(_currentData);

    try {
      // 避免某些情况下 sink.close 永远等待
      await _channel?.sink
          .close(status.goingAway)
          .timeout(
            const Duration(seconds: 1),
            onTimeout: () => AppLogger.error('MSFSService: WebSocket 关闭超时'),
          );
    } catch (e) {
      AppLogger.error('MSFSService: WebSocket 关闭异常: $e');
    }

    _channel = null;
    AppLogger.info('MSFSService: MSFS 服务已断开并重置');
  }

  void dispose() {
    disconnect();
    _dataController.close();
  }
}
