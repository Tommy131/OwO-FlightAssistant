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
  final Map<int, String> _subscribedDataRefs = {};

  bool get isConnected => _isConnected;
  Stream<SimulatorData> get dataStream => _dataController.stream;
  SimulatorData get currentData => _currentData;

  /// 连接到 X-Plane
  Future<bool> connect() async {
    try {
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
      await _subscribeDataRef(dataRef.index, dataRef.path);
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
        _updateDataByIndex(index, value);
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

  void _updateDataByIndex(int index, double value) {
    switch (index) {
      case 0:
        _currentData = _currentData.copyWith(airspeed: value);
        break;
      case 1:
        _currentData = _currentData.copyWith(
          altitude: DataConverters.metersToFeet(value),
        );
        break;
      case 2:
        _currentData = _currentData.copyWith(heading: value);
        break;
      case 3:
        _currentData = _currentData.copyWith(
          verticalSpeed: DataConverters.mpsToFpm(value),
        );
        break;
      case 4:
        _currentData = _currentData.copyWith(latitude: value);
        _detectAirportByCoords(
          _currentData.latitude ?? 0,
          _currentData.longitude ?? 0,
        );
        break;
      case 5:
        _currentData = _currentData.copyWith(longitude: value);
        _detectAirportByCoords(
          _currentData.latitude ?? 0,
          _currentData.longitude ?? 0,
        );
        break;
      case 6:
        _currentData = _currentData.copyWith(
          groundSpeed: DataConverters.mpsToKnots(value),
        );
        break;
      case 7:
        _currentData = _currentData.copyWith(
          trueAirspeed: DataConverters.mpsToKnots(value),
        );
        break;
      case 10:
        _currentData = _currentData.copyWith(parkingBrake: value > 0.5);
        break;
      case 11:
        _currentData = _currentData.copyWith(beacon: value > 0.5);
        break;
      case 12:
        _mainLandingLightOn = value > 0.5;
        _updateLandingLightsStatus();
        break;
      case 13:
        _currentData = _currentData.copyWith(taxiLights: value > 0.01);
        break;
      case 14:
        _currentData = _currentData.copyWith(navLights: value > 0.5);
        break;
      case 15:
        _currentData = _currentData.copyWith(strobes: value > 0.5);
        break;
      case 16:
        _currentData = _currentData.copyWith(flapsPosition: value.toInt());
        break;
      case 17:
        _currentData = _currentData.copyWith(gearDown: value > 0.5);
        break;
      case 18:
        _currentData = _currentData.copyWith(logoLights: value > 0.5);
        break;
      case 19:
        _currentData = _currentData.copyWith(wingLights: value > 0.5);
        break;
      case 20:
        _currentData = _currentData.copyWith(apuRunning: value > 0.5);
        break;
      case 21:
        _currentData = _currentData.copyWith(engine1Running: value > 0.5);
        break;
      case 22:
        _currentData = _currentData.copyWith(engine2Running: value > 0.5);
        break;
      case 250:
        _runwayTurnoffSwitches[0] = value > 0.5;
        _updateRunwayTurnoffStatus();
        break;
      case 251:
        _runwayTurnoffSwitches[1] = value > 0.5;
        _updateRunwayTurnoffStatus();
        break;
      case 26:
        // 襟翼角度,0-1的比例转换为实际角度(假设最大40度)
        _currentData = _currentData.copyWith(
          flapsAngle: DataConverters.flapRatioToDegrees(value),
        );
        break;
      case 27:
        _currentData = _currentData.copyWith(wheelWellLights: value > 0.5);
        break;
      case 30:
        _currentData = _currentData.copyWith(autopilotEngaged: value > 0);
        break;
      case 31:
        _currentData = _currentData.copyWith(autothrottleEngaged: value > 0);
        break;
      case 40:
        _currentData = _currentData.copyWith(outsideAirTemperature: value);
        break;
      case 41:
        _currentData = _currentData.copyWith(totalAirTemperature: value);
        break;
      case 42:
        _currentData = _currentData.copyWith(windSpeed: value);
        break;
      case 43:
        _currentData = _currentData.copyWith(windDirection: value);
        break;
      case 50:
        _currentData = _currentData.copyWith(fuelQuantity: value);
        break;
      case 51:
        _currentData = _currentData.copyWith(
          fuelFlow: DataConverters.kgsToKgh(value),
        );
        break;
      case 60:
        _currentData = _currentData.copyWith(engine1N1: value);
        _detectAircraftType(); // 发动机数据也可以辅助判断
        break;
      case 61:
        _currentData = _currentData.copyWith(engine2N1: value);
        break;
      case 62:
        _currentData = _currentData.copyWith(engine1EGT: value);
        break;
      case 63:
        _currentData = _currentData.copyWith(engine2EGT: value);
        break;
      case 70:
        _currentData = _currentData.copyWith(gForce: value);
        break;
      case 71:
        _currentData = _currentData.copyWith(baroPressure: value);
        break;
      case 100:
        _currentData = _currentData.copyWith(isPaused: value > 0.5);
        break;
      case 101:
        _currentData = _currentData.copyWith(onGround: value > 0.5);
        break;
      case 104:
        _currentData = _currentData.copyWith(flapsPosition: value.toInt());
        // 收到襟翼档位数据，这是区分机型的关键特征
        _detectAircraftType();
        break;
      case 110:
        _currentData = _currentData.copyWith(atisFrequency: value / 100);
        break;
      case 120:
        _landingLightSwitches[0] = value > 0.5;
        _updateLandingLightsStatus();
        break;
      case 121:
        _landingLightSwitches[1] = value > 0.5;
        _updateLandingLightsStatus();
        break;
      case 122:
        _landingLightSwitches[2] = value > 0.5;
        _updateLandingLightsStatus();
        break;
      case 123:
        _landingLightSwitches[3] = value > 0.5;
        _updateLandingLightsStatus();
        break;
      // 起落架详细状态
      case 130:
        _currentData = _currentData.copyWith(noseGearDown: value > 0.5);
        break;
      case 131:
        _currentData = _currentData.copyWith(leftGearDown: value > 0.5);
        break;
      case 132:
        _currentData = _currentData.copyWith(rightGearDown: value > 0.5);
        break;
      // 襟翼状态
      case 135:
        _currentData = _currentData.copyWith(
          flapsDeployRatio: value,
          flapsDeployed: value > 0.05, // 展开比例 > 5% 认为已展开
        );
        break;
      case 136:
        _currentData = _currentData.copyWith(flapsAngle: value);
        break;
      case 137:
        // ZIBO 738 襟翼手柄位置: 0, 1, 2, 3, 4, 5, 6, 7, 8
        // 对应: UP, 1, 2, 5, 10, 15, 25, 30, 40
        final leverPos = value.round();
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
      case 140:
        _currentData = _currentData.copyWith(
          speedBrake: value > 0.05,
          speedBrakePosition: value,
        );
        break;
      case 141:
        _currentData = _currentData.copyWith(
          spoilersDeployed: value > 5.0, // 角度大于5度认为展开
        );
        break;
      // 自动刹车
      case 150:
        // 注意：-1 表示不支持或未设置，0 表示 OFF
        final level = value.toInt();
        _currentData = _currentData.copyWith(
          autoBrakeLevel: (level >= 1 && level <= 5) ? level : null,
        );
        break;
      case 151:
        // ZIBO 738 自动刹车原始值：0, 1, 2, 3, 4, 5
        // 对应：0=RTO, 1=OFF, 2=1, 3=2, 4=3, 5=MAX(4)
        final ziboPos = value.round();
        int? displayLevel;
        if (ziboPos == 0) {
          displayLevel = 5; // RTO
        } else if (ziboPos >= 2 && ziboPos <= 5) {
          displayLevel = ziboPos - 1; // 2->1, 3->2, 4->3, 5->4(MAX)
        } else {
          displayLevel = null; // OFF (1)
        }
        _currentData = _currentData.copyWith(autoBrakeLevel: displayLevel);
        break;
      // 警告系统
      case 160:
        _currentData = _currentData.copyWith(masterWarning: value > 0.5);
        break;
      case 161:
        _currentData = _currentData.copyWith(masterCaution: value > 0.5);
        break;
      case 162:
        _currentData = _currentData.copyWith(fireWarningEngine1: value > 0.5);
        break;
      case 163:
        _currentData = _currentData.copyWith(fireWarningEngine2: value > 0.5);
        break;
      case 164:
        _currentData = _currentData.copyWith(fireWarningAPU: value > 0.5);
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

  Future<void> _subscribeDataRef(int index, String dref) async {
    if (_isDisposed) return;

    _subscribedDataRefs[index] = dref;
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
        _subscribeDataRef(0, 'sim/flightmodel/position/indicated_airspeed');
      }
    });
  }

  void _sendData(List<int> data) {
    if (_socket != null && !_isDisposed) {
      _socket!.send(data, InternetAddress('127.0.0.1'), _xplanePort);
    }
  }

  Future<void> disconnect() async {
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
