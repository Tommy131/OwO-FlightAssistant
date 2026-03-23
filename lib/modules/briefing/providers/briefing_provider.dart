import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/briefing_record.dart';
import '../services/briefing_service.dart';

/// 飞行简报模块的状态提供者 (Provider)
/// 负责 UI 状态维护（Loading、列表展示）、以及调用 Service 层执行具体的业务逻辑。
class BriefingProvider extends ChangeNotifier {
  final BriefingService _service = BriefingService();

  /// 全局加载状态
  bool _isLoading = false;

  /// 最新一次生成的简报记录
  BriefingRecord? _latest;

  /// 历史简报记录列表
  final List<BriefingRecord> _history = [];

  bool get isLoading => _isLoading;
  BriefingRecord? get latest => _latest;
  List<BriefingRecord> get history => List.unmodifiable(_history);

  BriefingProvider() {
    _init();
  }

  /// 模块启动时自动加载历史数据
  Future<void> _init() async {
    await reloadFromDirectory();
  }

  /// 生成单次飞行简报的核心入口流程
  Future<void> generateBriefing({
    required String departure,
    required String arrival,
    String? alternate,
    String? flightNumber,
    String? route,
    int? cruiseAltitude,
    String? departureRunway,
    String? arrivalRunway,
    String? alternateRunway,
  }) async {
    _isLoading = true;
    notifyListeners();

    final generatedAt = DateTime.now();
    final normalizedDeparture = departure.trim().toUpperCase();
    final normalizedArrival = arrival.trim().toUpperCase();
    final normalizedAlternate = alternate?.trim().toUpperCase() ?? '';
    final routeText = (route != null && route.trim().isNotEmpty)
        ? route.trim().toUpperCase()
        : 'DCT';
    final cruise = cruiseAltitude ?? 35000;
    final flightNo = (flightNumber != null && flightNumber.trim().isNotEmpty)
        ? flightNumber.trim().toUpperCase()
        : _generateFlightNumber();

    try {
      // 1. 获取起降及备降机场的打包数据 (含 METAR)
      final depBundle = await _service.fetchAirportBundle(normalizedDeparture);
      final arrBundle = await _service.fetchAirportBundle(normalizedArrival);
      final altBundle = normalizedAlternate.isEmpty
          ? null
          : await _service.fetchAirportBundle(normalizedAlternate);

      // 2. 算路: 计算大圆航段距离及预估飞行时间
      final distanceNm = _service.calculateDistanceNm(
        depBundle.airport.latitude,
        depBundle.airport.longitude,
        arrBundle.airport.latitude,
        arrBundle.airport.longitude,
      );
      final estimatedMinutes = distanceNm != null
          ? ((distanceNm / 450.0) * 60).round()
          : null;

      // 3. 构建油耗计划 (基于航程和备降选择)
      final fuel = _service.buildFuelPlan(
        distanceNm: distanceNm,
        hasAlternate: altBundle != null,
      );

      // 4. 跑道建议 (如果输入为空则自动根据气象风向筛选)
      final depRunway =
          (departureRunway != null && departureRunway.trim().isNotEmpty)
          ? departureRunway.trim().toUpperCase()
          : _service.selectBestRunway(depBundle.airport, depBundle.metar);
      final arrRunway =
          (arrivalRunway != null && arrivalRunway.trim().isNotEmpty)
          ? arrivalRunway.trim().toUpperCase()
          : _service.selectBestRunway(arrBundle.airport, arrBundle.metar);
      final altRunway = altBundle == null
          ? null
          : (alternateRunway != null && alternateRunway.trim().isNotEmpty)
          ? alternateRunway.trim().toUpperCase()
          : _service.selectBestRunway(altBundle.airport, altBundle.metar);

      // 5. 生成汇总文本
      final summary = _service.buildBriefingSummary(
        generatedAt: generatedAt,
        flightNo: flightNo,
        departure: depBundle,
        arrival: arrBundle,
        alternate: altBundle,
        route: routeText,
        cruiseAltitude: cruise,
        distanceNm: distanceNm,
        estimatedMinutes: estimatedMinutes,
        depRunway: depRunway,
        arrRunway: arrRunway,
        altRunway: altRunway,
        fuel: fuel,
      );

      // 6. 存储并通知 UI
      final record = BriefingRecord(
        title: '${depBundle.airport.icao} → ${arrBundle.airport.icao}',
        content: summary,
        createdAt: generatedAt,
      );
      final savedRecord = await _service.saveRecord(record);
      _latest = savedRecord;
      _history.insert(0, savedRecord);
    } catch (_) {
      // 降级逻辑: 如果网络环境恶劣导致无法构建完整简报，生成一份基础占位文本
      final fallbackRecord = BriefingRecord(
        title: '$normalizedDeparture → $normalizedArrival (FAILED)',
        content:
            'FAILED TO FETCH DETAILED WEATHER DATA FOR $flightNo\nGEN AT: $generatedAt',
        createdAt: generatedAt,
      );
      final savedRecord = await _service.saveRecord(fallbackRecord);
      _latest = savedRecord;
      _history.insert(0, savedRecord);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 删除简报
  Future<bool> deleteBriefing(BriefingRecord record) async {
    try {
      final success = await _service.deleteFromStorage(record);
      if (success) {
        _history.remove(record);
        if (_latest == record) {
          _latest = _history.isNotEmpty ? _history.first : null;
        }
        notifyListeners();
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  /// 通关磁盘扫描刷新列表
  Future<int> reloadFromDirectory() async {
    _isLoading = true;
    notifyListeners();
    try {
      final records = await _service.loadAllRecords();
      _history.clear();
      _history.addAll(records);
      _latest = _history.isNotEmpty ? _history.first : null;
      return records.length;
    } catch (_) {
      return 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 从外部 JSON 文件导入简报
  Future<int> importFromFilePicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final filePath = result?.files.single.path;
    if (filePath == null) return 0;

    try {
      final s = await File(filePath).readAsString();
      final decoded = jsonDecode(s);
      int count = 0;
      if (decoded is Map<String, dynamic>) {
        await _service.saveRecord(BriefingRecord.fromJson(decoded));
        count = 1;
      } else if (decoded is List) {
        for (var j in decoded.whereType<Map<String, dynamic>>()) {
          await _service.saveRecord(BriefingRecord.fromJson(j));
          count++;
        }
      }
      if (count > 0) await reloadFromDirectory();
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// 将历史记录批量导出到文件
  Future<int> exportToFilePicker() async {
    if (_history.isEmpty) return -1;
    final filePath = await FilePicker.platform.saveFile(
      fileName: 'flight_briefings_export.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (filePath == null) return 0;
    final payload = _history.map((r) => r.toJson()).toList();
    await File(
      filePath,
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    return 1;
  }

  /// 辅助: 随机生成航班号 (如 CA8213)
  String _generateFlightNumber() {
    final r = math.Random();
    return 'CA${1000 + r.nextInt(9000)}';
  }
}
