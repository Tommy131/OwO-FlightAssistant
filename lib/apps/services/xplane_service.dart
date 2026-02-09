import 'dart:async';

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/simulator_data.dart';
import '../data/airports_database.dart';
import '../data/aircraft_catalog.dart';
import '../utils/aircraft_detector.dart';
import '../utils/data_converters.dart';
import '../../core/utils/logger.dart';
import 'config/xplane_datarefs.dart';
import 'config/simulator_config_service.dart';

/// X-Plane 连接服务（通过UDP）
class XPlaneService {
  static const Duration _connectionTimeout = Duration(seconds: 5);

  RawDatagramSocket? _socket;
  bool _isConnected = false;
  bool _isDisposed = false;
  Timer? _heartbeatTimer;
  Timer? _connectionVerificationTimer;
  DateTime? _lastDataReceived;
  DateTime? _lastSubscriptionRequest;

  // 动态配置
  String _targetIp = '127.0.0.1';
  int _targetPort = 49000;
  int _localPort = 19190;

  // 缓存复合状态
  final List<bool> _landingLightSwitches = List.filled(16, false);
  // bool _mainLandingLightOn = false; // (no more needed)
  bool _logoLightOn = false;
  final List<bool> _genericLightSwitches = List.filled(80, false);
  // bool _taxiLightOn = false; // (no more needed)

  // 机型检测器
  final AircraftDetector _aircraftDetector = AircraftDetector();
  final _FlapResolver _flapResolver = _FlapResolver();
  final _LightResolver _lightResolver = _LightResolver();
  double? _flapsDeployRatio;
  double? _flapsActualDegrees;
  double? _flapsLeverZibo;
  int _flapsDetentsCount = 0;

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
  Future<bool> connect({String? host, int? targetPort, int? localPort}) async {
    try {
      await disconnect(); // 确保旧的 socket 已关闭
      _isDisposed = false;
      _isConnected = false;
      _lastDataReceived = null;
      _currentData = SimulatorData();

      _currentData = SimulatorData();

      // 加载配置或使用传入参数
      if (host != null && targetPort != null && localPort != null) {
        _targetIp = host;
        _targetPort = targetPort;
        _localPort = localPort;
      } else {
        final config = await SimulatorConfigService().getXPlaneConfig();
        _targetIp = config['ip'] as String;
        _targetPort = config['port'] as int;
        _localPort = config['local_port'] as int;
      }

      AppLogger.info(
        'X-Plane 目标地址: $_targetIp:$_targetPort, 本地端口: $_localPort',
      );

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

  /// 验证 X-Plane 连接是否可用 (包含握手验证)
  Future<bool> verifyConnection({
    String? host,
    int? targetPort,
    int? localPort,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final success = await connect(
      host: host,
      targetPort: targetPort,
      localPort: localPort,
    );
    if (!success) return false;

    final Completer<bool> completer = Completer<bool>();
    late StreamSubscription subscription;

    subscription = dataStream.listen((data) {
      if (data.isConnected && !completer.isCompleted) {
        completer.complete(true);
      }
    });

    try {
      final result = await completer.future.timeout(
        timeout,
        onTimeout: () => false,
      );
      return result;
    } catch (_) {
      return false;
    } finally {
      await subscription.cancel();
      // 验证完后断开，避免占用资源
      await disconnect();
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
        // 持续发送订阅请求，直到收到数据 (增加频率限制，防止 X-Plane 堆积重复订阅)
        final now = DateTime.now();
        if (_lastSubscriptionRequest == null ||
            now.difference(_lastSubscriptionRequest!) >
                const Duration(seconds: 5)) {
          AppLogger.info('等待数据中，重试订阅...');
          _subscribeToDataRefs();
        }
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
    if (_currentData.aircraftTitle != result.aircraftType ||
        _currentData.identity != result.identity) {
      _currentData = _currentData.copyWith(
        aircraftTitle: result.aircraftType,
        identity: result.identity,
        isConnected: true,
      );

      // 如果识别到了 identity，且 numEngines 位空/0，则同步 catalog 中的引擎数
      if ((_currentData.numEngines == null || _currentData.numEngines == 0) &&
          result.identity?.engineCount != null) {
        _currentData = _currentData.copyWith(
          numEngines: result.identity!.engineCount,
        );
      }

      _updateLightStatus();
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
    _lastSubscriptionRequest = DateTime.now();
    // 批量订阅所有配置的 DataRefs
    final allDataRefs = XPlaneDataRefs.getAllDataRefs();
    for (final dataRef in allDataRefs) {
      await _subscribeDataRef(dataRef);
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
        final int rawId = _bytesToInt32(data.sublist(i, i + 4));
        final double value = _bytesToFloat32(data.sublist(i + 4, i + 8));

        // 核心解码逻辑
        int keyIndex;
        int subIndex = 0;

        if (rawId > 0xFFFF) {
          // 说明是组合编码格式 (keyIndex << 16 | subIndex)
          keyIndex = rawId >> 16;
          subIndex = rawId & 0xFFFF;
        } else {
          // 普通索引
          keyIndex = rawId;
        }

        if (keyIndex >= 0 && keyIndex < XPlaneDataRefKey.values.length) {
          _updateDataByRefKey(
            XPlaneDataRefKey.values[keyIndex],
            value,
            subIndex: subIndex,
          );
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

  void _updateDataByRefKey(
    XPlaneDataRefKey key,
    double value, {
    int subIndex = 0,
  }) {
    void onChanged(
      String lightType,
      List<bool> array,
      int index,
      bool newValue,
    ) {
      final activeIndices = array
          .asMap()
          .entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();
      if (kDebugMode) {
        print(
          'X-Plane $lightType 灯光更新: 索引 $index -> ${newValue ? "开启" : "关闭"}, 当前激活列表: $activeIndices',
        );
      }
    }

    switch (key) {
      case XPlaneDataRefKey.landingLightArray:
        _updateArrayStatus(
          _landingLightSwitches,
          subIndex,
          value,
          onChanged: (index, newValue) =>
              onChanged('起落灯', _landingLightSwitches, index, newValue),
        );
        break;
      case XPlaneDataRefKey.genericLightArray:
        _updateArrayStatus(
          _genericLightSwitches,
          subIndex,
          value,
          onChanged: (index, newValue) =>
              onChanged('泛用灯', _genericLightSwitches, index, newValue),
        );
        break;
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
      case XPlaneDataRefKey.machNumber:
        _currentData = _currentData.copyWith(machNumber: value);
        break;
      case XPlaneDataRefKey.parkingBrake:
        _currentData = _currentData.copyWith(parkingBrake: value > 0.5);
        break;
      case XPlaneDataRefKey.beaconLights:
        _currentData = _currentData.copyWith(beacon: value > 0.5);
        break;
      // // (No more needed)
      /* case XPlaneDataRefKey.landingLightsMain:
        final newValue = value > 0.5;
        if (_mainLandingLightOn != newValue) {
          _mainLandingLightOn = newValue;
          _updateLightStatus();
        }
        break;
      case XPlaneDataRefKey.taxiLights:
        final newValue = value > 0.01;
        if (_taxiLightOn != newValue) {
          _taxiLightOn = newValue;
          _updateLightStatus();
        }
        break; */
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
      case XPlaneDataRefKey.apuRunning:
        _currentData = _currentData.copyWith(apuRunning: value > 0.5);
        break;
      case XPlaneDataRefKey.engine1Running:
        _currentData = _currentData.copyWith(engine1Running: value > 0.5);
        break;
      case XPlaneDataRefKey.engine2Running:
        _currentData = _currentData.copyWith(engine2Running: value > 0.5);
        break;
      case XPlaneDataRefKey.visibility:
        _currentData = _currentData.copyWith(visibility: value);
        break;

      case XPlaneDataRefKey.flapsAngle:
        _setFlapsState(deployRatio: value);
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
        _currentData = _currentData.copyWith(
          baroPressure: value,
          baroPressureUnit: 'inHg',
        );
        break;
      case XPlaneDataRefKey.isPaused:
        _currentData = _currentData.copyWith(isPaused: value > 0.5);
        break;
      case XPlaneDataRefKey.onGround:
        _currentData = _currentData.copyWith(onGround: value > 0.5);
        break;
      case XPlaneDataRefKey.flapDetents:
        _currentData = _currentData.copyWith(flapDetentsCount: value.toInt());
        _setFlapsState(detentsCount: value.toInt());
        _detectAircraftType();
        break;
      case XPlaneDataRefKey.com1Frequency:
        _currentData = _currentData.copyWith(com1Frequency: value / 100);
        break;
      case XPlaneDataRefKey.transponderMode:
        _currentData = _currentData.copyWith(transponderState: value.toInt());
        break;
      case XPlaneDataRefKey.transponderCode:
        _currentData = _currentData.copyWith(
          transponderCode: _formatTransponderCode(value),
        );
        break;

      case XPlaneDataRefKey.logoLight:
        final newValue = value > 0.5;
        if (_logoLightOn != newValue) {
          _logoLightOn = newValue;
          _updateLightStatus();
        }
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
        _setFlapsState(deployRatio: value);
        break;
      case XPlaneDataRefKey.flapsActualDegrees:
        _setFlapsState(actualDegrees: value);
        break;
      case XPlaneDataRefKey.flapsLeverZibo:
        _setFlapsState(ziboLever: value);
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
        // X-Plane 11/12 默认机型自动刹车挡位：
        // B747: 0=RTO, 1=OFF, 2=DISARM (747-8), 3=1, 4=2, 5=3, 6=4, 7=MAX (或 MAX AUTO)
        // B737: 0=RTO, 1=OFF, 2=1, 3=2, 4=3, 5=MAX
        // 映射为：1->0(OFF), 0->-1(RTO), 2->1(DISARM), 3->2(1) ...
        final level = value.round();
        final mappedLevel = (level >= 0 && level <= 7) ? level - 1 : null;
        _currentData = _currentData.copyWith(autoBrakeLevel: mappedLevel);
        break;
      case XPlaneDataRefKey.autoBrakeZibo:
        // ZIBO 738 自动刹车原始值：0, 1, 2, 3, 4, 5
        // 对应：0=RTO, 1=OFF, 2=1, 3=2, 4=3, 5=MAX(4)
        // 只有识别为 Zibo 时才接受此专有数据反馈，避免干扰默认机型
        if (_currentData.identity?.id == 'zibo-738') {
          _currentData = _currentData.copyWith(
            autoBrakeLevel: value.round() - 1,
          );
        }
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
        _currentData = _currentData.copyWith(numEngines: value.toInt());
        _detectAircraftType();
        break;
      case XPlaneDataRefKey.wingArea:
        _currentData = _currentData.copyWith(wingArea: value);
        _detectAircraftType();
        break;
    }
  }

  void _updateLightStatus() {
    final match = AircraftCatalog.match(
      title: _currentData.aircraftTitle,
      engineCount: _currentData.numEngines,
      flapDetents: _currentData.flapDetentsCount,
      wingArea: _currentData.wingArea,
    );

    final result = _lightResolver.resolve(
      identity: match?.identity,
      // landingMain: _mainLandingLightOn, // (no more needed)
      landingSwitches: _landingLightSwitches,
      logoStandard: _logoLightOn,
      // taxiStandard: _taxiLightOn, // (no more needed)
      genericSwitches: _genericLightSwitches,
    );
    _currentData = _currentData.copyWith(
      landingLights: result.landingLights,
      taxiLights: result.taxiLights,
      logoLights: result.logoLights,
      wingLights: result.wingLights,
      runwayTurnoffLights: result.runwayTurnoffLights,
      wheelWellLights: result.wheelWellLights,
    );
  }

  void _setFlapsState({
    double? deployRatio,
    double? actualDegrees,
    double? ziboLever,
    int? detentsCount,
  }) {
    if (deployRatio != null) {
      _flapsDeployRatio = deployRatio.clamp(0.0, 1.0);
    }
    if (actualDegrees != null) {
      _flapsActualDegrees = actualDegrees;
    }
    if (ziboLever != null) {
      _flapsLeverZibo = ziboLever;
    }
    if (detentsCount != null) {
      _flapsDetentsCount = detentsCount;
    }

    final match = AircraftCatalog.match(
      title: _currentData.aircraftTitle,
      engineCount: _currentData.numEngines,
      flapDetents: _flapsDetentsCount,
      wingArea: _currentData.wingArea,
    );

    final result = _flapResolver.resolve(
      identity: match?.identity,
      flapDetentsCount: _flapsDetentsCount,
      deployRatio: _flapsDeployRatio,
      actualDegrees: _flapsActualDegrees,
      ziboLever: _flapsLeverZibo,
    );

    _currentData = _currentData.copyWith(
      flapsDeployRatio: result.deployRatio,
      flapsAngle: result.angle,
      flapsDeployed: result.deployed,
      flapsLabel: result.label,
    );
  }

  Future<void> _subscribeDataRef(XPlaneDataRef dataRef) async {
    if (_isDisposed) return;

    _subscribedDataRefs[dataRef.key] = dataRef.path;
    final int encodedIndex = dataRef.index; // 使用编码后的 ID
    final List<int> data = [
      ...'RREF'.codeUnits,
      0,
      ..._int32ToBytes(5), // 频率 (Hz)
      ..._int32ToBytes(encodedIndex),
      ...dataRef.path.codeUnits,
      ...List.filled(400 - dataRef.path.length, 0),
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
        _subscribeDataRef(XPlaneDataRefs.airspeed);
      }
    });
  }

  void _sendData(List<int> data) {
    if (_socket != null && !_isDisposed) {
      try {
        _socket!.send(data, InternetAddress(_targetIp), _targetPort);
      } catch (e) {
        // AppLogger.error('发送数据失败: $e');
      }
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

  String? _formatTransponderCode(double value) {
    final raw = value.round();
    if (raw < 0) return null;
    final rawDigits = raw.toString();
    if (raw <= 7777 && RegExp(r'^[0-7]{1,4}$').hasMatch(rawDigits)) {
      return rawDigits.padLeft(4, '0');
    }
    if (raw <= 0xFFFF) {
      final d1 = (raw >> 12) & 0xF;
      final d2 = (raw >> 8) & 0xF;
      final d3 = (raw >> 4) & 0xF;
      final d4 = raw & 0xF;
      final digits = [d1, d2, d3, d4];
      final isBcd = digits.every((d) => d >= 0 && d <= 7);
      if (isBcd) {
        return digits.join();
      }
    }
    if (rawDigits.length <= 4) return rawDigits.padLeft(4, '0');
    return rawDigits.substring(rawDigits.length - 4);
  }

  /// 更新布尔状态数组并触发状态刷新
  void _updateArrayStatus(
    List<bool> targetList,
    int index,
    double value, {
    void Function(int index, bool newValue)? onChanged,
  }) {
    if (index >= 0 && index < targetList.length) {
      final newValue = value > 0.5;
      if (targetList[index] != newValue) {
        targetList[index] = newValue;
        _updateLightStatus();
        onChanged?.call(index, newValue);
      }
    }
  }
}

class _LightResult {
  final bool landingLights;
  final bool taxiLights;
  final bool logoLights;
  final bool wingLights;
  final bool runwayTurnoffLights;
  final bool wheelWellLights;

  const _LightResult({
    required this.landingLights,
    required this.taxiLights,
    required this.logoLights,
    required this.wingLights,
    required this.runwayTurnoffLights,
    required this.wheelWellLights,
  });
}

class _LightResolver {
  _LightResult resolve({
    required AircraftIdentity? identity,
    // required bool landingMain, // (no more needed)
    required List<bool> landingSwitches,
    required bool logoStandard,
    // required bool taxiStandard, // (no more needed)
    required List<bool> genericSwitches,
  }) {
    final profile = identity?.lightProfile ?? const LightProfile();

    // 起落灯
    final landingOn = _anySwitchOn(landingSwitches, profile.landingIndices);
    // (profile.hasMainLandingLightControl && landingMain) || // (no more needed)
    // landingSwitches.any((isOn) => isOn) || // (no more needed)

    // 滑行灯
    final taxiOn = _switchOn(genericSwitches, profile.taxiIndex);
    // taxiStandard || _switchOn(genericSwitches, profile.taxiIndex); // (no more needed)

    // 标志灯
    final logoOn =
        logoStandard ||
        _anySwitchOn(
          genericSwitches,
          profile.logoIndices ??
              (profile.logoIndex != null ? [profile.logoIndex!] : null),
        );

    // 翼灯
    final wingOn = _switchOn(genericSwitches, profile.wingIndex);

    // 跑道灯
    final runwayOn =
        _switchOn(genericSwitches, profile.runwayLeftIndex) ||
        _switchOn(genericSwitches, profile.runwayRightIndex);

    // 轮舱灯
    final wheelOn = _switchOn(genericSwitches, profile.wheelWellIndex);

    return _LightResult(
      landingLights: landingOn,
      taxiLights: taxiOn,
      logoLights: logoOn,
      wingLights: wingOn,
      runwayTurnoffLights: runwayOn,
      wheelWellLights: wheelOn,
    );
  }

  bool _switchOn(List<bool> values, int? index) {
    if (index == null || index < 0 || index >= values.length) return false;
    return values[index];
  }

  bool _anySwitchOn(List<bool> values, List<int>? indices) {
    if (indices == null) return false;
    return indices.any((index) => _switchOn(values, index));
  }
}

class _FlapResult {
  final double? deployRatio;
  final double? angle;
  final bool deployed;
  final String label;
  final bool isZiboActive;

  const _FlapResult({
    required this.deployRatio,
    required this.angle,
    required this.deployed,
    required this.label,
    required this.isZiboActive,
  });
}

class _FlapResolver {
  _FlapResult resolve({
    required AircraftIdentity? identity,
    required int flapDetentsCount,
    double? deployRatio,
    double? actualDegrees,
    double? ziboLever,
  }) {
    final ziboActive =
        _isZiboLeverActive(ziboLever) || (identity?.id == 'zibo-738');

    final profile = identity?.flapProfile ?? _defaultProfile(flapDetentsCount);
    final detentCount = profile.labels.length;

    double? normalizedRatio = deployRatio?.clamp(0.0, 1.0);
    int? detentIndex;

    if (ziboActive && ziboLever != null) {
      detentIndex = _ziboLeverToIndex(ziboLever, detentCount);
      if (detentCount > 1) {
        normalizedRatio = detentIndex / (detentCount - 1);
      } else {
        normalizedRatio = 0;
      }
    }

    if (detentIndex == null && normalizedRatio != null && detentCount > 1) {
      detentIndex = (normalizedRatio * (detentCount - 1)).round();
    }

    if (detentIndex == null &&
        actualDegrees != null &&
        profile.angles != null) {
      detentIndex = _nearestAngleIndex(actualDegrees, profile.angles!);
    }

    if (detentIndex == null &&
        actualDegrees != null &&
        profile.maxAngle > 0 &&
        detentCount > 1) {
      normalizedRatio = (actualDegrees / profile.maxAngle).clamp(0.0, 1.0);
      detentIndex = (normalizedRatio * (detentCount - 1)).round();
    }

    double? angle;
    if (detentIndex != null && profile.angles != null) {
      angle = profile.angles![detentIndex];
    } else if (actualDegrees != null) {
      angle = actualDegrees;
    } else if (normalizedRatio != null) {
      angle = DataConverters.flapRatioToDegrees(
        normalizedRatio,
        maxDegrees: profile.maxAngle,
      );
    }

    final label = _labelFor(profile, detentIndex, angle);
    final deployed = angle != null
        ? angle > 0.5
        : (normalizedRatio != null ? normalizedRatio > 0.01 : false);

    return _FlapResult(
      deployRatio: normalizedRatio,
      angle: angle,
      deployed: deployed,
      label: label,
      isZiboActive: ziboActive,
    );
  }

  FlapProfile _defaultProfile(int flapDetentsCount) {
    final count = flapDetentsCount > 0 ? flapDetentsCount + 1 : 2;
    final labels = List.generate(
      count,
      (index) => index == 0 ? 'UP' : '$index',
    );
    return FlapProfile(labels: labels, maxAngle: 40);
  }

  int _ziboLeverToIndex(double value, int detentCount) {
    int index;
    if (value >= 0 && value <= 1.0) {
      index = (value * (detentCount - 1)).round();
    } else {
      index = value.round();
    }
    if (index < 0) return 0;
    if (index >= detentCount) return detentCount - 1;
    return index;
  }

  bool _isZiboLeverActive(double? value) {
    if (value == null) return false;
    return value > 0.01 || value >= 1;
  }

  int _nearestAngleIndex(double angle, List<double> angles) {
    double bestDiff = double.infinity;
    int best = 0;
    for (var i = 0; i < angles.length; i++) {
      final diff = (angle - angles[i]).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = i;
      }
    }
    return best;
  }

  String _labelFor(FlapProfile profile, int? detentIndex, double? angle) {
    if (detentIndex != null && detentIndex < profile.labels.length) {
      return profile.labels[detentIndex];
    }
    if (angle == null || angle < 0.5) return 'UP';
    return angle.round().toString();
  }
}
