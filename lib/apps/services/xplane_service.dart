import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../models/simulator_data.dart';
import '../data/airports_database.dart';
import '../utils/aircraft_detector.dart';
import '../utils/data_converters.dart';
import '../../core/utils/logger.dart';
import 'config/xplane_datarefs.dart';

/// X-Plane 连接服务（通过UDP）
class XPlaneService {
  static const int _xplanePort = 49000; // X-Plane 接收端口
  static const int _localPort = 19190; // 本地监听端口
  static const Duration _connectionTimeout = Duration(seconds: 5);

  RawDatagramSocket? _socket;
  bool _isConnected = false;
  bool _isDisposed = false;
  Timer? _heartbeatTimer;
  Timer? _connectionVerificationTimer;
  DateTime? _lastDataReceived;

  // 缓存复合状态
  final List<bool> _landingLightSwitches = List.filled(4, false);
  bool _mainLandingLightOn = false;

  final List<bool> _runwayTurnoffSwitches = List.filled(2, false);

  // 机型检测器
  final AircraftDetector _aircraftDetector = AircraftDetector();

  final StreamController<SimulatorData> _dataController =
      StreamController<SimulatorData>.broadcast();
  SimulatorData _currentData = SimulatorData();

  // 当前订阅的DataRefs
  final Map<XPlaneDataRefKey, String> _subscribedDataRefs = {};

  bool get isConnected => _isConnected;
  Stream<SimulatorData> get dataStream => _dataController.stream;
  SimulatorData get currentData => _currentData;

  /// 服务是否正在运行（是否有活跃资源需要清理）
  bool get isActive =>
      _socket != null ||
      _heartbeatTimer != null ||
      _connectionVerificationTimer != null;

  /// 连接到 X-Plane
  Future<bool> connect() async {
    try {
      await disconnect(); // 确保旧的 socket 已关闭
      _isDisposed = false;
      _isConnected = false;
      _lastDataReceived = null;
      _currentData = SimulatorData();

      AppLogger.info('正在绑定 UDP 端口 $_localPort...');

      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _localPort,
      );

      _socket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          // 安全检查：确保 socket 未被释放或重置为 null
          if (_socket == null) return;

          final Datagram? dg = _socket!.receive();
          if (dg != null) {
            _handleIncomingData(dg.data);
          }
        }
      });

      // 订阅关键DataRefs
      await _subscribeToDataRefs();

      // 启动心跳
      _startHeartbeat();

      // 启动连接验证
      _startConnectionVerification();

      AppLogger.info('UDP 端口绑定成功，等待 X-Plane 数据...');
      return true;
    } catch (e) {
      AppLogger.error('连接 X-Plane 失败', e);
      return false;
    }
  }

  /// 启动连接验证定时器
  void _startConnectionVerification() {
    _connectionVerificationTimer?.cancel();
    _connectionVerificationTimer = Timer.periodic(const Duration(seconds: 2), (
      timer,
    ) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }

      if (_lastDataReceived == null) {
        // 持续发送订阅请求，直到收到数据
        AppLogger.info('等待数据中，重试订阅...');
        _subscribeToDataRefs();
        return;
      }

      final timeSinceLastData = DateTime.now().difference(_lastDataReceived!);
      if (timeSinceLastData > _connectionTimeout) {
        if (_isConnected) {
          AppLogger.error('X-Plane 数据超时，连接已丢失');
          _isConnected = false;
          _notifyData(
            _currentData.copyWith(aircraftTitle: null, isConnected: false),
          );
        }
      }
    });
  }

  /// 发送数据到流，带安全性检查
  void _notifyData(SimulatorData data) {
    if (!_isDisposed && !_dataController.isClosed) {
      _dataController.add(data);
    }
  }

  /// 智能检测机型类型
  void _detectAircraftType() {
    if (_isDisposed) return;

    // 使用 AircraftDetector 进行机型检测
    final result = _aircraftDetector.detectAircraft(_currentData);
    if (result == null || !result.isStable) {
      return; // 等待更多数据或等待稳定
    }

    // 只有当机型真正改变时才通知
    if (_currentData.aircraftTitle != result.aircraftType) {
      _currentData = _currentData.copyWith(
        aircraftTitle: result.aircraftType,
        isConnected: true,
      );
      _notifyData(_currentData);
      AppLogger.info(
        '机型自动识别成功: ${result.aircraftType} (稳定接收, 检测次数: ${result.detectionCount})',
      );
    }
  }

  /// 基于坐标识别机场
  void _detectAirportByCoords(double lat, double lon) {
    if (lat == 0 && lon == 0 || _isDisposed) return;

    // 使用 AirportsDatabase 查找最近的机场
    final nearestAirport = AirportsDatabase.findNearestByCoords(lat, lon);

    if (nearestAirport != null &&
        _currentData.departureAirport != nearestAirport.displayName) {
      _currentData = _currentData.copyWith(
        departureAirport: nearestAirport.displayName,
      );
      AppLogger.info('经纬度匹配到临近机场: ${nearestAirport.displayName}');
    }
  }

  /// 订阅DataRefs
  Future<void> _subscribeToDataRefs() async {
    // 批量订阅所有配置的 DataRefs
    final allDataRefs = XPlaneDataRefs.getAllDataRefs();
    for (final dataRef in allDataRefs) {
      await _subscribeDataRef(dataRef.key, dataRef.path);
    }
  }

  // int _debugPacketCounter = 0;

  void _handleIncomingData(Uint8List data) {
    if (_isDisposed) return;
    _lastDataReceived = DateTime.now();

    if (data.length < 5) return;

    final String header = String.fromCharCodes(data.sublist(0, 4));
    if (header != 'RREF') return;

    final int dataCount = (data.length - 5) ~/ 8;

    // 调试输出：每100个包输出一次原始数据采样
    /* _debugPacketCounter++;
    if (_debugPacketCounter >= 100) {
      _debugPacketCounter = 0;
      final List<String> parsedValues = [];
      for (int i = 0; i < dataCount; i++) {
        final int offset = 5 + i * 8;
        final int index = _bytesToInt32(data.sublist(offset, offset + 4));
        final double value = _bytesToFloat32(
          data.sublist(offset + 4, offset + 8),
        );
        parsedValues.add('Index $index: ${value.toStringAsFixed(4)}');
      }
      AppLogger.debug(
        'X-Plane 原始数据包采样: Len=${data.length}, 内容: ${parsedValues.join(", ")}...',
      );
    } */

    if (dataCount > 0) {
      for (int i = 5; i < data.length; i += 8) {
        if (i + 8 > data.length) break;
        final index = _bytesToInt32(data.sublist(i, i + 4));
        final value = _bytesToFloat32(data.sublist(i + 4, i + 8));

        // 防止数组越界; 如果在枚举中插入新的数据ref, 需要重启XPlane; 从末尾插入不需要
        if (index >= 0 && index < XPlaneDataRefKey.values.length) {
          _updateDataByRefKey(XPlaneDataRefKey.values[index], value);
        }
      }
      if (dataCount > 0) {
        // 收到有效的RREF数据包,立即标记为已连接
        if (!_isConnected) {
          _isConnected = true;
          AppLogger.info('X-Plane 连接已验证！收到有效数据包');
          _detectAircraftType();
        }

        // 如果机型仍未识别，持续尝试
        if (_currentData.aircraftTitle == null ||
            _currentData.aircraftTitle == 'Unknown Aircraft') {
          _detectAircraftType();
        }

        _notifyData(_currentData.copyWith(isConnected: true));
      }
    }
  }

  void _updateDataByRefKey(XPlaneDataRefKey key, double value) {
    switch (key) {
      case XPlaneDataRefKey.airspeed:
        _currentData = _currentData.copyWith(airspeed: value);
        break;
      case XPlaneDataRefKey.altitude:
        _currentData = _currentData.copyWith(
          altitude: DataConverters.metersToFeet(value),
        );
        break;
      case XPlaneDataRefKey.heading:
        _currentData = _currentData.copyWith(heading: value);
        break;
      case XPlaneDataRefKey.verticalSpeed:
        _currentData = _currentData.copyWith(
          verticalSpeed: DataConverters.mpsToFpm(value),
        );
        break;
      case XPlaneDataRefKey.latitude:
        _currentData = _currentData.copyWith(latitude: value);
        _detectAirportByCoords(
          _currentData.latitude ?? 0,
          _currentData.longitude ?? 0,
        );
        break;
      case XPlaneDataRefKey.longitude:
        _currentData = _currentData.copyWith(longitude: value);
        _detectAirportByCoords(
          _currentData.latitude ?? 0,
          _currentData.longitude ?? 0,
        );
        break;
      case XPlaneDataRefKey.groundSpeed:
        _currentData = _currentData.copyWith(
          groundSpeed: DataConverters.mpsToKnots(value),
        );
        break;
      case XPlaneDataRefKey.trueAirspeed:
        _currentData = _currentData.copyWith(
          trueAirspeed: DataConverters.mpsToKnots(value),
        );
        break;
      case XPlaneDataRefKey.parkingBrake:
        _currentData = _currentData.copyWith(parkingBrake: value > 0.5);
        break;
      case XPlaneDataRefKey.beaconLights:
        _currentData = _currentData.copyWith(beacon: value > 0.5);
        break;
      case XPlaneDataRefKey.landingLightsMain:
        _mainLandingLightOn = value > 0.5;
        _updateLandingLightsStatus();
        break;
      case XPlaneDataRefKey.taxiLights:
        _currentData = _currentData.copyWith(taxiLights: value > 0.01);
        break;
      case XPlaneDataRefKey.navLights:
        _currentData = _currentData.copyWith(navLights: value > 0.5);
        break;
      case XPlaneDataRefKey.strobeLights:
        _currentData = _currentData.copyWith(strobes: value > 0.5);
        break;
      case XPlaneDataRefKey.flapsRequest:
        _currentData = _currentData.copyWith(flapsPosition: value.toInt());
        break;
      case XPlaneDataRefKey.gearDeploy:
        _currentData = _currentData.copyWith(gearDown: value > 0.5);
        break;
      case XPlaneDataRefKey.logoLights:
        _currentData = _currentData.copyWith(logoLights: value > 0.5);
        break;
      case XPlaneDataRefKey.wingLights:
        _currentData = _currentData.copyWith(wingLights: value > 0.5);
        break;
      case XPlaneDataRefKey.apuRunning:
        _currentData = _currentData.copyWith(apuRunning: value > 0.5);
        break;
      case XPlaneDataRefKey.engine1Running:
        _currentData = _currentData.copyWith(engine1Running: value > 0.5);
        break;
      case XPlaneDataRefKey.engine2Running:
        _currentData = _currentData.copyWith(engine2Running: value > 0.5);
        break;
      case XPlaneDataRefKey.runwayTurnoffLeft:
        _runwayTurnoffSwitches[0] = value > 0.5;
        _updateRunwayTurnoffStatus();
        break;
      case XPlaneDataRefKey.runwayTurnoffRight:
        _runwayTurnoffSwitches[1] = value > 0.5;
        _updateRunwayTurnoffStatus();
        break;
      case XPlaneDataRefKey.flapsAngle:
        // 襟翼角度,0-1的比例转换为实际角度(假设最大40度)
        _currentData = _currentData.copyWith(
          flapsAngle: DataConverters.flapRatioToDegrees(value),
        );
        break;
      case XPlaneDataRefKey.wheelWellLights:
        _currentData = _currentData.copyWith(wheelWellLights: value > 0.5);
        break;
      case XPlaneDataRefKey.autopilotMode:
        _currentData = _currentData.copyWith(autopilotEngaged: value > 0);
        break;
      case XPlaneDataRefKey.autothrottle:
        _currentData = _currentData.copyWith(autothrottleEngaged: value > 0);
        break;
      case XPlaneDataRefKey.outsideTemp:
        _currentData = _currentData.copyWith(outsideAirTemperature: value);
        break;
      case XPlaneDataRefKey.totalTemp:
        _currentData = _currentData.copyWith(totalAirTemperature: value);
        break;
      case XPlaneDataRefKey.windSpeed:
        _currentData = _currentData.copyWith(windSpeed: value);
        break;
      case XPlaneDataRefKey.windDirection:
        _currentData = _currentData.copyWith(windDirection: value);
        break;
      case XPlaneDataRefKey.fuelTotal:
        _currentData = _currentData.copyWith(fuelQuantity: value);
        break;
      case XPlaneDataRefKey.fuelFlow:
        _currentData = _currentData.copyWith(
          fuelFlow: DataConverters.kgsToKgh(value),
        );
        break;
      case XPlaneDataRefKey.engine1N1:
        _currentData = _currentData.copyWith(engine1N1: value);
        _detectAircraftType(); // 发动机数据也可以辅助判断
        break;
      case XPlaneDataRefKey.engine2N1:
        _currentData = _currentData.copyWith(engine2N1: value);
        break;
      case XPlaneDataRefKey.engine1EGT:
        _currentData = _currentData.copyWith(engine1EGT: value);
        break;
      case XPlaneDataRefKey.engine2EGT:
        _currentData = _currentData.copyWith(engine2EGT: value);
        break;
      case XPlaneDataRefKey.gForce:
        _currentData = _currentData.copyWith(gForce: value);
        break;
      case XPlaneDataRefKey.baroPressure:
        _currentData = _currentData.copyWith(baroPressure: value);
        break;
      case XPlaneDataRefKey.isPaused:
        _currentData = _currentData.copyWith(isPaused: value > 0.5);
        break;
      case XPlaneDataRefKey.onGround:
        _currentData = _currentData.copyWith(onGround: value > 0.5);
        break;
      case XPlaneDataRefKey.flapDetents:
        _currentData = _currentData.copyWith(flapsPosition: value.toInt());
        // 收到襟翼档位数据，这是区分机型的关键特征
        _detectAircraftType();
        break;
      case XPlaneDataRefKey.com1Frequency:
        _currentData = _currentData.copyWith(com1Frequency: value / 100);
        break;
      case XPlaneDataRefKey.landingLight0:
        _landingLightSwitches[0] = value > 0.5;
        _updateLandingLightsStatus();
        break;
      case XPlaneDataRefKey.landingLight1:
        _landingLightSwitches[1] = value > 0.5;
        _updateLandingLightsStatus();
        break;
      case XPlaneDataRefKey.landingLight2:
        _landingLightSwitches[2] = value > 0.5;
        _updateLandingLightsStatus();
        break;
      case XPlaneDataRefKey.landingLight3:
        _landingLightSwitches[3] = value > 0.5;
        _updateLandingLightsStatus();
        break;
      // 起落架详细状态
      case XPlaneDataRefKey.noseGearDeploy:
        _currentData = _currentData.copyWith(noseGearDown: value);
        break;
      case XPlaneDataRefKey.leftGearDeploy:
        _currentData = _currentData.copyWith(leftGearDown: value);
        break;
      case XPlaneDataRefKey.rightGearDeploy:
        _currentData = _currentData.copyWith(rightGearDown: value);
        break;
      // 襟翼状态
      case XPlaneDataRefKey.flapsDeployRatio:
        _currentData = _currentData.copyWith(
          flapsDeployRatio: value,
          flapsDeployed: value > 0.05, // 展开比例 > 5% 认为已展开
        );
        break;
      case XPlaneDataRefKey.flapsActualDegrees:
        _currentData = _currentData.copyWith(flapsAngle: value);
        break;
      case XPlaneDataRefKey.flapsLeverZibo:
        // ZIBO 738 襟翼手柄位置可能作为 0.0-1.0 (比例) 或 0-8 (索引) 返回
        // 对应比例步骤: 0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1.0 为 9 个位置
        int leverPos;
        if (value >= 0 && value <= 1.0) {
          leverPos = (value * 8).round();
        } else {
          leverPos = value.round();
        }

        String? label;
        double? angle;
        const ziboFlaps = [
          0.0, // 0 = UP
          1.0, // 1 = 1°
          2.0, // 2 = 2°
          5.0, // 3 = 5°
          10.0, // 4 = 10°
          15.0, // 5 = 15°
          25.0, // 6 = 25°
          30.0, // 7 = 30°
          40.0, // 8 = 40°
        ];
        if (leverPos >= 0 && leverPos < ziboFlaps.length) {
          angle = ziboFlaps[leverPos];
          label = leverPos == 0 ? 'UP' : angle.toInt().toString();
          _currentData = _currentData.copyWith(
            flapsAngle: angle,
            flapsDeployed: leverPos > 0,
            flapsLabel: label,
          );
        }
        break;
      // 减速板与扰流板
      case XPlaneDataRefKey.speedBrakeRatio:
        _currentData = _currentData.copyWith(
          speedBrake: value > 0.05,
          speedBrakePosition: value,
        );
        break;
      case XPlaneDataRefKey.spoilersDeployed:
        _currentData = _currentData.copyWith(
          spoilersDeployed: value > 5.0, // 角度大于5度认为展开
        );
        break;
      // 自动刹车
      case XPlaneDataRefKey.autoBrake:
        // 注意：-1 表示不支持或未设置，0 表示 OFF
        final level = value.toInt();
        _currentData = _currentData.copyWith(
          autoBrakeLevel: (level >= 1 && level <= 5) ? level : null,
        );
        break;
      case XPlaneDataRefKey.autoBrakeZibo:
        // ZIBO 738 自动刹车原始值：0, 1, 2, 3, 4, 5
        // 对应：0=RTO, 1=OFF, 2=1, 3=2, 4=3, 5=MAX(4)
        _currentData = _currentData.copyWith(autoBrakeLevel: value.round() - 1);
        break;
      // 警告系统
      case XPlaneDataRefKey.masterWarning:
        _currentData = _currentData.copyWith(masterWarning: value > 0.5);
        break;
      case XPlaneDataRefKey.masterCaution:
        _currentData = _currentData.copyWith(masterCaution: value > 0.5);
        break;
      case XPlaneDataRefKey.fireWarningEng1:
        _currentData = _currentData.copyWith(fireWarningEngine1: value > 0.5);
        break;
      case XPlaneDataRefKey.fireWarningEng2:
        _currentData = _currentData.copyWith(fireWarningEngine2: value > 0.5);
        break;
      case XPlaneDataRefKey.fireWarningAPU:
        _currentData = _currentData.copyWith(fireWarningAPU: value > 0.5);
        break;
      case XPlaneDataRefKey.numEngines:
        // 特殊处理或忽略
        break;
    }
  }

  void _updateLandingLightsStatus() {
    final bool anySwitchOn = _landingLightSwitches.any((isOn) => isOn);
    _currentData = _currentData.copyWith(
      landingLights: _mainLandingLightOn || anySwitchOn,
    );
  }

  void _updateRunwayTurnoffStatus() {
    final bool anySwitchOn = _runwayTurnoffSwitches.any((isOn) => isOn);
    _currentData = _currentData.copyWith(
      runwayTurnoffLights: anySwitchOn, // 只要左或右开了一个就算开
    );
  }

  Future<void> _subscribeDataRef(XPlaneDataRefKey key, String dref) async {
    if (_isDisposed) return;

    _subscribedDataRefs[key] = dref;
    final int index = key.index; // 使用枚举索引作为 UDP 标识
    final List<int> data = [
      ...'RREF'.codeUnits,
      0,
      ..._int32ToBytes(5), // 频率 (Hz)
      ..._int32ToBytes(index),
      ...dref.codeUnits,
      ...List.filled(400 - dref.length, 0),
    ];
    _sendData(data);
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      if (_isConnected && _socket != null) {
        _subscribeDataRef(
          XPlaneDataRefKey.airspeed,
          'sim/flightmodel/position/indicated_airspeed',
        );
      }
    });
  }

  void _sendData(List<int> data) {
    if (_socket != null && !_isDisposed) {
      _socket!.send(data, InternetAddress('127.0.0.1'), _xplanePort);
    }
  }

  Future<void> disconnect() async {
    if (!isActive) return;
    AppLogger.info('XPlaneService: 开始断开连接...');

    _isDisposed = true;
    _isConnected = false;
    _heartbeatTimer?.cancel();
    _connectionVerificationTimer?.cancel();

    // 发送断开连接状态到流
    _currentData = _currentData.copyWith(
      isConnected: false,
      aircraftTitle: null,
    );
    _notifyData(_currentData);

    _socket?.close();
    _socket = null;
    _lastDataReceived = null;

    AppLogger.info('XPlaneService: 已断开与 X-Plane 的连接，资源已释放');
  }

  int _bytesToInt32(Uint8List bytes) {
    return DataConverters.bytesToInt32(bytes);
  }

  double _bytesToFloat32(Uint8List bytes) {
    return DataConverters.bytesToFloat32(bytes);
  }

  List<int> _int32ToBytes(int value) {
    return DataConverters.int32ToBytes(value);
  }
}
