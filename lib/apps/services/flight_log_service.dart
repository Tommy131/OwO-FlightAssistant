import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:latlong2/latlong.dart';
import '../models/flight_log/flight_log.dart';
import '../models/simulator_data.dart';
import '../models/airport_detail_data.dart';
import '../../core/utils/logger.dart';

/// 飞行日志记录服务
class FlightLogService {
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

  /// 开始记录
  void startRecording(SimulatorData data) {
    if (_isRecording) return;

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _currentLog = FlightLog(
      id: id,
      aircraftTitle: data.aircraftTitle ?? 'Unknown Aircraft',
      departureAirport: data.departureAirport ?? 'Unknown',
      startTime: DateTime.now(),
      points: [],
      wasOnGroundAtStart: data.onGround ?? false,
    );
    _isRecording = true;
    _lastPointTime = null;

    // 记录初始点
    recordPoint(data);
    AppLogger.info('开始记录飞行日志: $id');
  }

  /// 记录一个点
  void recordPoint(SimulatorData data) {
    if (!_isRecording || _currentLog == null) return;

    final now = DateTime.now();

    // 检查时间间隔
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
      verticalSpeed: data.verticalSpeed ?? 0,
      heading: data.heading ?? 0,
      pitch: data.pitch ?? 0,
      roll: data.roll ?? 0,
      gForce: data.gForce ?? 1.0,
      fuelQuantity: data.fuelQuantity ?? 0,
      timestamp: now,
    );

    _currentLog!.points.add(point);
    _lastPointTime = now;

    // 维护最近点序列
    _recentPoints.add(point);
    if (_recentPoints.length > _maxRecentPoints) {
      _recentPoints.removeAt(0);
    }

    // 着陆检测逻辑
    final onGround = data.onGround ?? false;
    if (_wasInAir && onGround) {
      // 触发着陆
      _handleLanding(point);
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

    // 持续更新是否在地面
    _currentLog!.wasOnGroundAtEnd = data.onGround ?? false;

    // 起飞检测逻辑
    if (!_wasInAir && !onGround) {
      _handleTakeoff(point);
    }

    // 着陆检测逻辑
    if (_wasInAir && onGround) {
      // 触发着陆
      _handleLanding(point);
    }
    _wasInAir = !onGround;
  }

  void _handleTakeoff(FlightPoint takeoffPoint) async {
    if (_currentLog == null) return;

    // 获取当前最近的机场跑道信息，用于计算剩余跑道长度
    double? remainingRunwayFt;
    try {
      // 优先使用当前已加载的机场详情
      final airport = _currentAirportDetail;
      if (airport != null) {
        for (final r in airport.runways) {
          if (r.isPointOnRunway(
            takeoffPoint.latitude,
            takeoffPoint.longitude,
          )) {
            // 简单计算到跑道末端的距离（高端或低端，取决于起飞方向）
            // 这里使用简化的逻辑：计算到 le 和 he 的距离，取较大的那个作为剩余（因为起飞是向前的）
            // 实际起飞时，飞机通常是从一端滑跑，所以剩余长度应该是 跑道全长 - 已滑跑长度
            // 我们通过计算点到 he (High End) 和 le (Low End) 的距离来估算
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
              // 剩余长度通常是较长的那个方向（假设飞行员不会往短的那头飞）
              remainingRunwayFt =
                  (distToLe > distToHe ? distToLe : distToHe) / 0.3048;

              // 修正：如果计算出的剩余长度大于跑道总长，则取跑道总长
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
      verticalSpeed: takeoffPoint.verticalSpeed,
      pitch: takeoffPoint.pitch,
      heading: takeoffPoint.heading,
      timestamp: takeoffPoint.timestamp,
      remainingRunwayFt: remainingRunwayFt,
    );

    _currentLog!.takeoffData = takeoffData;
    _takeoffController.add(takeoffData);

    AppLogger.info(
      '检测到起飞: Spd: ${takeoffData.airspeed.toStringAsFixed(1)}, RemRwy: ${remainingRunwayFt?.toStringAsFixed(0)}ft',
    );
  }

  void _handleLanding(FlightPoint touchdownPoint) async {
    if (_currentLog == null) return;

    // 获取当前最近的机场跑道信息，用于计算剩余跑道长度
    double? remainingRunwayFt;
    try {
      final airport = _currentAirportDetail;
      if (airport != null) {
        for (final r in airport.runways) {
          if (r.isPointOnRunway(
            touchdownPoint.latitude,
            touchdownPoint.longitude,
          )) {
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
              // 落地后剩余长度是较短的那个方向（假设飞机是朝跑道另一头落地的）
              // 或者更准确：计算投影点到两端的距离
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

    // 获取着陆前后的序列（最近的序列包含着陆瞬间）
    final sequence = List<FlightPoint>.from(_recentPoints);

    final landingData = LandingData(
      gForce: touchdownPoint.gForce,
      verticalSpeed: touchdownPoint.verticalSpeed,
      airspeed: touchdownPoint.airspeed,
      pitch: touchdownPoint.pitch,
      roll: touchdownPoint.roll,
      rating: LandingRating.fromData(
        touchdownPoint.gForce,
        touchdownPoint.verticalSpeed,
      ),
      touchdownSequence: sequence,
      remainingRunwayFt: remainingRunwayFt,
    );

    _currentLog!.landingData = landingData;
    _landingController.add(landingData);

    AppLogger.info(
      '检测到着陆: ${landingData.rating.label}, G: ${landingData.gForce}, RemRwy: ${remainingRunwayFt?.toStringAsFixed(0)}ft',
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

    _currentLog = FlightLog(
      id: _currentLog!.id,
      aircraftTitle: _currentLog!.aircraftTitle,
      departureAirport: _currentLog!.departureAirport,
      arrivalAirport: arrivalAirport ?? _currentLog!.arrivalAirport,
      startTime: _currentLog!.startTime,
      endTime: _currentLog!.endTime,
      points: _currentLog!.points,
      maxG: _currentLog!.maxG,
      minG: _currentLog!.minG,
      maxAltitude: _currentLog!.maxAltitude,
      maxAirspeed: _currentLog!.maxAirspeed,
      wasOnGroundAtStart: _currentLog!.wasOnGroundAtStart,
      wasOnGroundAtEnd: _currentLog!.wasOnGroundAtEnd,
    );

    final filePath = await saveLog(_currentLog!);
    AppLogger.info('停止记录并保存飞行日志: ${_currentLog!.id}');

    return filePath;
  }

  /// 保存日志到文件
  Future<String> saveLog(FlightLog log) async {
    final directory = await getApplicationDocumentsDirectory();
    final logDir = Directory(p.join(directory.path, 'flight_logs'));
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    final file = File(p.join(logDir.path, 'flight_${log.id}.json'));
    await file.writeAsString(jsonEncode(log.toJson()));
    return file.path;
  }

  /// 获取所有日志列表
  Future<List<FlightLog>> getLogs() async {
    final directory = await getApplicationDocumentsDirectory();
    final logDir = Directory(p.join(directory.path, 'flight_logs'));
    if (!await logDir.exists()) return [];

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
    return logs;
  }

  /// 导出日志 (分享)
  Future<void> exportLog(FlightLog log) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = p.join(
      directory.path,
      'flight_logs',
      'flight_${log.id}.json',
    );
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

  /// 导出当前正在记录或最近一次记录的日志
  Future<void> exportCurrentLog() async {
    if (_currentLog != null) {
      await exportLog(_currentLog!);
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
        return true;
      } catch (e) {
        AppLogger.error('导入飞行日志失败', e);
      }
    }
    return false;
  }

  /// 删除日志
  Future<void> deleteLog(String id) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'flight_logs', 'flight_$id.json'));
    if (await file.exists()) {
      await file.delete();
    }
  }
}
