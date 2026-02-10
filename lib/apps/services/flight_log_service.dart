import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../models/flight_log.dart';
import '../models/simulator_data.dart';
import '../models/airport_detail_data.dart';
import '../../core/utils/logger.dart';
import '../../core/services/persistence/app_storage_paths.dart';

/// 飞行日志记录服务
class FlightLogService extends ChangeNotifier {
  static final FlightLogService _instance = FlightLogService._internal();
  factory FlightLogService() => _instance;
  FlightLogService._internal();

  FlightLog? _currentLog;
  bool _isRecording = false;
  DateTime? _lastPointTime;

  // 着陆检测相关
  bool _wasInAir = false;
  final List<FlightPoint> _recentPoints = []; // 循环队列，存储最近30秒的数据点
  static const int _maxRecentPoints = 30; // 约1分钟的数据（假设2秒一个点）

  final _landingController = StreamController<LandingData>.broadcast();
  Stream<LandingData> get landingStream => _landingController.stream;

  final _takeoffController = StreamController<TakeoffData>.broadcast();
  Stream<TakeoffData> get takeoffStream => _takeoffController.stream;

  AirportDetailData? _currentAirportDetail;

  // 记录配置
  static const int _minIntervalMs = 2000; // 最小记录间隔 2秒
  static const double _minDistanceMove = 0.0001; // 约10米，最小移动距离

  FlightLog? get currentLog => _currentLog;
  bool get isRecording => _isRecording;

  /// 切换录制状态
  void toggleRecording(SimulatorData data, {String? flightNumber}) {
    if (_isRecording) {
      stopRecording(
        arrivalAirport: data.arrivalAirport,
        onGround: data.onGround,
      );
    } else {
      startRecording(data, flightNumber: flightNumber);
    }
  }

  /// 开始记录
  void startRecording(SimulatorData data, {String? flightNumber}) {
    if (_isRecording) return;

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _currentLog = FlightLog(
      id: id,
      aircraftTitle: data.aircraftTitle ?? 'Unknown Aircraft',
      aircraftType: data.aircraftType,
      flightNumber: flightNumber,
      departureAirport: data.departureAirport ?? 'Unknown',
      startTime: DateTime.now(),
      points: [],
      wasOnGroundAtStart: data.onGround ?? false,
    );
    _isRecording = true;
    _lastPointTime = null;
    _wasInAir = !(data.onGround ?? true);

    // 记录初始点
    recordPoint(data);
    AppLogger.info('开始记录飞行日志: $id');
    notifyListeners();
  }

  /// 记录一个点
  void recordPoint(SimulatorData data) {
    if (!_isRecording || _currentLog == null) return;

    final now = DateTime.now();

    // 检查时间间隔 (除非是关键事件点，这里简单处理统一间隔)
    if (_lastPointTime != null &&
        now.difference(_lastPointTime!).inMilliseconds < _minIntervalMs) {
      return;
    }

    final lat = data.latitude;
    final lon = data.longitude;
    if (lat == null || lon == null) return;

    // 如果有上一个点，检查移动距离
    if (_currentLog!.points.isNotEmpty) {
      final last = _currentLog!.points.last;
      final distSq =
          (last.latitude - lat) * (last.latitude - lat) +
          (last.longitude - lon) * (last.longitude - lon);
      if (distSq < _minDistanceMove * _minDistanceMove &&
          (now.difference(_lastPointTime!).inSeconds < 10)) {
        // 如果移动很小且时间不到10秒，不记录
        return;
      }
    }

    final point = FlightPoint(
      latitude: lat,
      longitude: lon,
      altitude: data.altitude ?? 0,
      airspeed: data.airspeed ?? 0,
      groundSpeed: data.groundSpeed ?? 0,
      verticalSpeed: data.verticalSpeed ?? 0,
      heading: data.heading ?? 0,
      pitch: data.pitch ?? 0,
      roll: data.roll ?? 0,
      gForce: data.gForce ?? 1.0,
      fuelQuantity: data.fuelQuantity ?? 0,
      fuelFlow: data.fuelFlow,
      timestamp: now,
      autopilotEngaged: data.autopilotEngaged,
      autothrottleEngaged: data.autothrottleEngaged,
      gearDown: data.gearDown,
      flapsPosition: data.flapsPosition,
      flapsLabel: data.flapsLabel,
      windSpeed: data.windSpeed,
      windDirection: data.windDirection,
      outsideAirTemperature: data.outsideAirTemperature,
      baroPressure: data.baroPressure,
      masterWarning: data.masterWarning,
      masterCaution: data.masterCaution,
      engine1Running: data.engine1Running,
      engine2Running: data.engine2Running,
      transponderCode: data.transponderCode,
      landingLights: data.landingLights,
      beacon: data.beacon,
      strobes: data.strobes,
      onGround: data.onGround,
      autoBrakeLevel: data.autoBrakeLevel,
      speedBrakePosition: data.speedBrakePosition,
    );

    _currentLog!.points.add(point);
    _lastPointTime = now;

    // 维护最近点序列
    _recentPoints.add(point);
    if (_recentPoints.length > _maxRecentPoints) {
      _recentPoints.removeAt(0);
    }

    // 状态更新与检测
    final onGround = data.onGround ?? false;

    // 起飞检测逻辑
    if (!_wasInAir && !onGround) {
      _handleTakeoff(point, data.activeRunway);
    }

    // 着陆检测逻辑
    if (_wasInAir && onGround) {
      // 触发着陆
      _handleLanding(point, data.activeRunway);
    }
    _wasInAir = !onGround;

    // 更新统计数据
    if (point.gForce > _currentLog!.maxG) _currentLog!.maxG = point.gForce;
    if (point.gForce < _currentLog!.minG) _currentLog!.minG = point.gForce;
    if (point.altitude > _currentLog!.maxAltitude) {
      _currentLog!.maxAltitude = point.altitude;
    }
    if (point.airspeed > _currentLog!.maxAirspeed) {
      _currentLog!.maxAirspeed = point.airspeed;
    }
    if (point.groundSpeed > _currentLog!.maxGroundSpeed) {
      _currentLog!.maxGroundSpeed = point.groundSpeed;
    }

    // 持续更新是否在地面
    _currentLog!.wasOnGroundAtEnd = data.onGround ?? false;
  }

  void _handleTakeoff(FlightPoint takeoffPoint, String? runwayFromData) async {
    if (_currentLog == null) return;

    // 获取当前最近的机场跑道信息，用于计算剩余跑道长度
    double? remainingRunwayFt;
    String? runway = runwayFromData;

    try {
      final airport = _currentAirportDetail;
      if (airport != null) {
        for (final r in airport.runways) {
          if (r.isPointOnRunway(
            takeoffPoint.latitude,
            takeoffPoint.longitude,
          )) {
            runway ??= r.ident;
            if (r.leLat != null && r.heLat != null) {
              final distToLe = _calculateDistance(
                takeoffPoint.latitude,
                takeoffPoint.longitude,
                r.leLat!,
                r.leLon!,
              );
              final distToHe = _calculateDistance(
                takeoffPoint.latitude,
                takeoffPoint.longitude,
                r.heLat!,
                r.heLon!,
              );
              remainingRunwayFt =
                  (distToLe > distToHe ? distToLe : distToHe) / 0.3048;

              if (r.lengthFt != null && remainingRunwayFt > r.lengthFt!) {
                remainingRunwayFt = r.lengthFt!.toDouble();
              }
            }
            break;
          }
        }
      }
    } catch (e) {
      AppLogger.error('计算起飞剩余跑道长度失败', e);
    }

    final takeoffData = TakeoffData(
      latitude: takeoffPoint.latitude,
      longitude: takeoffPoint.longitude,
      airspeed: takeoffPoint.airspeed,
      groundSpeed: takeoffPoint.groundSpeed,
      verticalSpeed: takeoffPoint.verticalSpeed,
      pitch: takeoffPoint.pitch,
      heading: takeoffPoint.heading,
      timestamp: takeoffPoint.timestamp,
      remainingRunwayFt: remainingRunwayFt,
      runway: runway,
    );

    _currentLog!.takeoffData = takeoffData;
    _currentLog!.endTime = null; // Clear end time if taking off again
    _takeoffController.add(takeoffData);

    AppLogger.info(
      '检测到起飞: Spd: ${takeoffData.airspeed.toStringAsFixed(1)}, Rwy: $runway',
    );
  }

  void _handleLanding(
    FlightPoint touchdownPoint,
    String? runwayFromData,
  ) async {
    if (_currentLog == null) return;

    double? remainingRunwayFt;
    String? runway = runwayFromData;

    try {
      final airport = _currentAirportDetail;
      if (airport != null) {
        for (final r in airport.runways) {
          if (r.isPointOnRunway(
            touchdownPoint.latitude,
            touchdownPoint.longitude,
          )) {
            runway ??= r.ident;
            if (r.leLat != null && r.heLat != null) {
              final distToLe = _calculateDistance(
                touchdownPoint.latitude,
                touchdownPoint.longitude,
                r.leLat!,
                r.leLon!,
              );
              final distToHe = _calculateDistance(
                touchdownPoint.latitude,
                touchdownPoint.longitude,
                r.heLat!,
                r.heLon!,
              );
              remainingRunwayFt =
                  (distToLe < distToHe ? distToLe : distToHe) / 0.3048;

              if (r.lengthFt != null && remainingRunwayFt > r.lengthFt!) {
                remainingRunwayFt = r.lengthFt!.toDouble();
              }
            }
            break;
          }
        }
      }
    } catch (e) {
      AppLogger.error('计算降落剩余跑道长度失败', e);
    }

    final sequence = List<FlightPoint>.from(_recentPoints);

    final landingData = LandingData(
      latitude: touchdownPoint.latitude,
      longitude: touchdownPoint.longitude,
      gForce: touchdownPoint.gForce,
      verticalSpeed: touchdownPoint.verticalSpeed,
      airspeed: touchdownPoint.airspeed,
      groundSpeed: touchdownPoint.groundSpeed,
      pitch: touchdownPoint.pitch,
      roll: touchdownPoint.roll,
      rating: LandingRating.fromData(
        touchdownPoint.gForce,
        touchdownPoint.verticalSpeed,
      ),
      timestamp: touchdownPoint.timestamp,
      touchdownSequence: sequence,
      remainingRunwayFt: remainingRunwayFt,
      runway: runway,
    );

    _currentLog!.landingData = landingData;
    _currentLog!.endTime = touchdownPoint.timestamp; // Set end time on landing
    _landingController.add(landingData);

    AppLogger.info(
      '检测到着陆: ${landingData.rating.label}, G: ${landingData.gForce}, Rwy: $runway',
    );
  }

  /// 计算两点间距离（米）
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double r = 6371000; // 地球半径
    final double dLat = (lat2 - lat1) * pi / 180;
    final double dLon = (lon2 - lon1) * pi / 180;
    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  /// 设置当前机场详情（由 MapProvider 同步）
  void setCurrentAirportDetail(AirportDetailData? data) {
    _currentAirportDetail = data;
  }

  /// 重置开始时间（重新计时）
  void resetStartTime() {
    if (_currentLog != null) {
      _currentLog!.startTime = DateTime.now();
      _currentLog!.endTime = null;
      notifyListeners();
    }
  }

  /// 停止记录并保存
  Future<String?> stopRecording({
    String? arrivalAirport,
    bool? onGround,
  }) async {
    if (!_isRecording || _currentLog == null) return null;

    _isRecording = false;
    _currentLog!.endTime = DateTime.now();
    if (onGround != null) {
      _currentLog!.wasOnGroundAtEnd = onGround;
    }

    if (arrivalAirport != null) {
      _currentLog = FlightLog(
        id: _currentLog!.id,
        aircraftTitle: _currentLog!.aircraftTitle,
        aircraftType: _currentLog!.aircraftType,
        departureAirport: _currentLog!.departureAirport,
        arrivalAirport: arrivalAirport,
        startTime: _currentLog!.startTime,
        endTime: _currentLog!.endTime,
        points: _currentLog!.points,
        maxG: _currentLog!.maxG,
        minG: _currentLog!.minG,
        maxAltitude: _currentLog!.maxAltitude,
        maxAirspeed: _currentLog!.maxAirspeed,
        maxGroundSpeed: _currentLog!.maxGroundSpeed,
        wasOnGroundAtStart: _currentLog!.wasOnGroundAtStart,
        wasOnGroundAtEnd: _currentLog!.wasOnGroundAtEnd,
        takeoffData: _currentLog!.takeoffData,
        landingData: _currentLog!.landingData,
      );
    }

    // 计算燃油消耗
    if (_currentLog!.points.isNotEmpty) {
      final firstPoint = _currentLog!.points.first;
      final lastPoint = _currentLog!.points.last;
      _currentLog!.totalFuelUsed =
          firstPoint.fuelQuantity - lastPoint.fuelQuantity;
    }

    // 检查记录时长，太短的不予保存 (例如小于30秒)
    final duration = _currentLog!.endTime!.difference(_currentLog!.startTime);
    if (duration.inSeconds < 30) {
      AppLogger.info('飞行日志记录时间太短 (${duration.inSeconds}s)，已丢弃');
      _currentLog = null;
      notifyListeners();
      return null;
    }

    final filePath = await saveLog(_currentLog!);
    AppLogger.info('停止记录并保存飞行日志: ${_currentLog!.id}');

    notifyListeners();
    return filePath;
  }

  /// 保存日志到文件
  Future<String> saveLog(FlightLog log) async {
    final logDir = await AppStoragePaths.getFlightLogDirectory();
    final file = File(p.join(logDir.path, 'flight_${log.id}.json'));
    await file.writeAsString(jsonEncode(log.toJson()));
    return file.path;
  }

  /// 获取所有日志列表
  Future<List<FlightLog>> getLogs() async {
    AppLogger.info('读取飞行日志列表');
    final logDir = await AppStoragePaths.getFlightLogDirectory();

    final List<FlightLog> logs = [];
    final files = logDir.listSync().whereType<File>().toList();

    for (final file in files) {
      if (p.extension(file.path) == '.json') {
        try {
          final content = await file.readAsString();
          logs.add(FlightLog.fromJson(jsonDecode(content)));
        } catch (e) {
          AppLogger.error('读取飞行日志失败: ${file.path}', e);
        }
      }
    }

    // 按时间降序排序
    logs.sort((a, b) => b.startTime.compareTo(a.startTime));
    AppLogger.info('飞行日志加载完成: ${logs.length} 条');
    return logs;
  }

  /// 导出日志 (分享)
  Future<void> exportLog(FlightLog log) async {
    final logDir = await AppStoragePaths.getFlightLogDirectory();
    final filePath = p.join(logDir.path, 'flight_${log.id}.json');
    final file = File(filePath);

    // 如果文件不存在（可能尚未保存），先保存
    if (!await file.exists()) {
      await saveLog(log);
    }

    if (await file.exists()) {
      await Share.shareXFiles([
        XFile(filePath),
      ], subject: '飞行日志: ${log.aircraftTitle} 从 ${log.departureAirport}');
    }
  }

  /// 导入日志
  Future<bool> importLog() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null && result.files.single.path != null) {
      final sourceFile = File(result.files.single.path!);
      try {
        final content = await sourceFile.readAsString();
        final json = jsonDecode(content);
        final log = FlightLog.fromJson(json);

        await saveLog(log);
        notifyListeners();
        return true;
      } catch (e) {
        AppLogger.error('导入飞行日志失败', e);
      }
    }
    return false;
  }

  /// 删除日志
  Future<void> deleteLog(String id) async {
    final logDir = await AppStoragePaths.getFlightLogDirectory();
    final file = File(p.join(logDir.path, 'flight_$id.json'));
    if (await file.exists()) {
      await file.delete();
      notifyListeners();
    }
  }

  /// 导出当前正在记录或最近一次记录的日志
  Future<void> exportCurrentLog() async {
    if (_currentLog != null) {
      await exportLog(_currentLog!);
    }
  }
}
