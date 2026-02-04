import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../models/simulator_data.dart';
import '../utils/logger.dart';

/// X-Plane 连接服务（通过UDP）
class XPlaneService {
  static const int _xplanePort = 49000; // X-Plane 接收端口
  static const int _localPort = 49001; // 本地监听端口
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

  // 机型识别防抖
  String? _lastPendingAircraft;
  int _aircraftDetectionCount = 0;
  static const int _requiredDetectionFrames = 5; // 需要连续5帧一致

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

    final n1_1 = _currentData.engine1N1 ?? 0;
    final n1_2 = _currentData.engine2N1 ?? 0;
    final flapDetents = _currentData.flapsPosition ?? 0;

    // 如果还没有获取到关键特征数据，继续等待
    if (flapDetents == 0 && n1_1 < 0.1 && n1_2 < 0.1) {
      return;
    }

    String detectedType = 'Unknown Aircraft';
    final isJet = n1_1 > 5 || n1_2 > 5 || flapDetents >= 5;

    if (isJet) {
      if (flapDetents >= 8) {
        detectedType = 'Boeing 737';
      } else if (flapDetents > 0) {
        detectedType = 'Airbus A320';
      } else {
        // 如果是喷气机但还没收到襟翼档位数据，先不急着下结论
        return;
      }
    } else if (flapDetents > 0) {
      detectedType = 'General Aviation Aircraft';
    } else {
      return;
    }

    // 防抖逻辑：必须连续多帧识别到同一机型
    if (detectedType == _lastPendingAircraft) {
      _aircraftDetectionCount++;
    } else {
      _lastPendingAircraft = detectedType;
      _aircraftDetectionCount = 1;
      return;
    }

    if (_aircraftDetectionCount < _requiredDetectionFrames) {
      return;
    }

    // 只有当机型真正改变时才通知
    if (_currentData.aircraftTitle != detectedType) {
      _currentData = _currentData.copyWith(
        aircraftTitle: detectedType,
        isConnected: true,
      );
      _notifyData(_currentData);
      AppLogger.info('机型自动识别成功: $detectedType (稳定接收)');
    }
  }

  /// 基于坐标识别机场
  void _detectAirportByCoords(double lat, double lon) {
    if (lat == 0 && lon == 0 || _isDisposed) return;

    // TODO: 完善机场数据库
    final Map<String, List<double>> airportDb = {
      'ZBAA 北京首都': [40.072, 116.597],
      'ZBSJ 石家庄正定': [38.281, 114.697],
      'ZBTJ 天津滨海': [39.124, 117.346],
      'ZSPD 上海浦东': [31.144, 121.805],
      'ZSSS 上海虹桥': [31.198, 121.336],
      'ZGGZ 广州白云': [23.392, 113.299],
      'ZGSZ 深圳宝安': [22.639, 113.811],
      'VHHH 香港赤鱲角': [22.308, 113.914],
      'ZUUU 成都双流': [30.578, 103.947],
      'RKSI 首尔仁川': [37.469, 126.451],
      'RJTT 东京羽田': [35.549, 139.779],
      'KJFK 纽约肯尼迪': [40.641, -73.778],
      'EGLL 伦敦希思罗': [51.470, -0.454],
    };

    String? foundAirport;
    double minDistance = 0.05;

    airportDb.forEach((icao, coords) {
      final double dLat = (lat - coords[0]).abs();
      final double dLon = (lon - coords[1]).abs();
      if (dLat < minDistance && dLon < minDistance) {
        foundAirport = icao;
      }
    });

    if (foundAirport != null && _currentData.departureAirport != foundAirport) {
      _currentData = _currentData.copyWith(departureAirport: foundAirport);
      AppLogger.info('经纬度匹配到临近机场: $foundAirport');
    }
  }

  /// 订阅DataRefs
  Future<void> _subscribeToDataRefs() async {
    // 飞行数据
    await _subscribeDataRef(0, 'sim/flightmodel/position/indicated_airspeed');
    await _subscribeDataRef(1, 'sim/flightmodel/position/elevation');
    await _subscribeDataRef(2, 'sim/flightmodel/position/mag_psi');
    await _subscribeDataRef(3, 'sim/flightmodel/position/vh_ind');

    // 位置和导航
    await _subscribeDataRef(4, 'sim/flightmodel/position/latitude');
    await _subscribeDataRef(5, 'sim/flightmodel/position/longitude');
    await _subscribeDataRef(6, 'sim/flightmodel/position/groundspeed');
    await _subscribeDataRef(7, 'sim/flightmodel/position/true_airspeed');

    // 环境数据
    await _subscribeDataRef(40, 'sim/weather/temperature_ambient_c');
    await _subscribeDataRef(41, 'sim/weather/temperature_le_c');
    await _subscribeDataRef(42, 'sim/weather/wind_speed_kt');
    await _subscribeDataRef(43, 'sim/weather/wind_direction_degt');

    // 模拟器状态
    await _subscribeDataRef(100, 'sim/time/paused'); // 暂停状态
    await _subscribeDataRef(
      101,
      'sim/flightmodel/failures/onground_any',
    ); // 地面状态

    // 系统状态
    await _subscribeDataRef(10, 'sim/cockpit/switches/parking_brake');
    await _subscribeDataRef(11, 'sim/cockpit/electrical/beacon_lights_on');

    // Landing Lights (组合检测)
    await _subscribeDataRef(
      12,
      'sim/cockpit2/switches/landing_lights_on',
    ); // 通用开关
    await _subscribeDataRef(
      120,
      'sim/cockpit2/switches/landing_lights_switch[0]',
    );
    await _subscribeDataRef(
      121,
      'sim/cockpit2/switches/landing_lights_switch[1]',
    );
    await _subscribeDataRef(
      122,
      'sim/cockpit2/switches/landing_lights_switch[2]',
    );
    await _subscribeDataRef(
      123,
      'sim/cockpit2/switches/landing_lights_switch[3]',
    );

    // Taxi Lights
    await _subscribeDataRef(
      13,
      'sim/cockpit2/switches/generic_lights_switch[4]',
    );

    await _subscribeDataRef(14, 'sim/cockpit2/switches/navigation_lights_on');
    await _subscribeDataRef(15, 'sim/cockpit/electrical/strobe_lights_on');

    // 修正 Logo 和 Wing 灯的映射 (交换索引)
    // 根据用户反馈反了，此处假设 generic[0] 是 Wing, generic[1] 是 Logo
    await _subscribeDataRef(
      18,
      'sim/cockpit2/switches/generic_lights_switch[1]',
    ); // Logo灯
    await _subscribeDataRef(
      19,
      'sim/cockpit2/switches/generic_lights_switch[0]',
    ); // 机翼灯

    // 跑道脱离灯 (Runway Turnoff - 左右双开关，基于插件机常用的 generic 索引)
    await _subscribeDataRef(
      250,
      'sim/cockpit2/switches/generic_lights_switch[2]',
    ); // 左开关
    await _subscribeDataRef(
      251,
      'sim/cockpit2/switches/generic_lights_switch[3]',
    ); // 右开关

    // 轮舱灯 (Wheel Well - 您已确认是索引5)
    await _subscribeDataRef(
      27,
      'sim/cockpit2/switches/generic_lights_switch[5]',
    );

    await _subscribeDataRef(16, 'sim/flightmodel/controls/flaprqst');
    await _subscribeDataRef(
      26,
      'sim/flightmodel2/controls/flap_handle_deploy_ratio',
    ); // 襟翼角度
    await _subscribeDataRef(17, 'sim/aircraft/parts/acf_gear_deploy');

    // 燃油和发动机
    await _subscribeDataRef(50, 'sim/flightmodel/weight/m_fuel_total');
    await _subscribeDataRef(
      51,
      'sim/cockpit2/engine/indicators/fuel_flow_kg_sec[0]',
    );
    await _subscribeDataRef(20, 'sim/cockpit/engine/APU_running');
    await _subscribeDataRef(21, 'sim/flightmodel/engine/ENGN_running[0]');
    await _subscribeDataRef(22, 'sim/flightmodel/engine/ENGN_running[1]');
    await _subscribeDataRef(60, 'sim/flightmodel/engine/ENGN_N1_[0]');
    await _subscribeDataRef(61, 'sim/flightmodel/engine/ENGN_N1_[1]');
    await _subscribeDataRef(62, 'sim/flightmodel/engine/ENGN_EGT_c[0]');
    await _subscribeDataRef(63, 'sim/flightmodel/engine/ENGN_EGT_c[1]');

    // 机型与机场辅助
    await _subscribeDataRef(102, 'sim/aircraft/engine/acf_num_engines');
    await _subscribeDataRef(104, 'sim/aircraft/controls/acf_flap_detents');
    await _subscribeDataRef(
      110,
      'sim/cockpit2/radios/indicators/com1_frequency_hz',
    );

    // 自动驾驶
    await _subscribeDataRef(30, 'sim/cockpit/autopilot/autopilot_mode');
    await _subscribeDataRef(31, 'sim/cockpit/autopilot/autothrottle_enabled');

    // 监控数据 (G力与气压)
    await _subscribeDataRef(70, 'sim/flightmodel/forces/g_nrml');
    await _subscribeDataRef(71, 'sim/weather/barometer_current_inhg');
  }

  int _debugPacketCounter = 0;

  void _handleIncomingData(Uint8List data) {
    if (_isDisposed) return;
    _lastDataReceived = DateTime.now();

    if (data.length < 5) return;

    final String header = String.fromCharCodes(data.sublist(0, 4));
    if (header != 'RREF') return;

    final int dataCount = (data.length - 5) ~/ 8;

    // 调试输出：每100个包输出一次原始数据采样
    _debugPacketCounter++;
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
    }

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
        _currentData = _currentData.copyWith(altitude: value * 3.28084);
        break;
      case 2:
        _currentData = _currentData.copyWith(heading: value);
        break;
      case 3:
        _currentData = _currentData.copyWith(verticalSpeed: value * 196.85);
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
        _currentData = _currentData.copyWith(groundSpeed: value * 1.94384);
        break;
      case 7:
        _currentData = _currentData.copyWith(trueAirspeed: value * 1.94384);
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
        _currentData = _currentData.copyWith(flapsAngle: value * 40.0);
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
        _currentData = _currentData.copyWith(fuelFlow: value * 3600);
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
    return ByteData.sublistView(bytes).getInt32(0, Endian.little);
  }

  double _bytesToFloat32(Uint8List bytes) {
    return ByteData.sublistView(bytes).getFloat32(0, Endian.little);
  }

  List<int> _int32ToBytes(int value) {
    final Uint8List bytes = Uint8List(4);
    ByteData.view(bytes.buffer).setInt32(0, value, Endian.little);
    return bytes.toList();
  }
}
