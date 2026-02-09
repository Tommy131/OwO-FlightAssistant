import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../models/flight_log/flight_log.dart';
import '../models/simulator_data.dart';
import '../../core/utils/logger.dart';

/// 飞行日志记录服务
class FlightLogService {
  static final FlightLogService _instance = FlightLogService._internal();
  factory FlightLogService() => _instance;
  FlightLogService._internal();

  FlightLog? _currentLog;
  bool _isRecording = false;
  DateTime? _lastPointTime;

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
      final distSq = (last.latitude - lat) * (last.latitude - lat) +
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
  }

  /// 停止记录并保存
  Future<String?> stopRecording({String? arrivalAirport, bool? onGround}) async {
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
