import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:path/path.dart' as p;
import '../../../core/services/persistence_service.dart';
import '../../../core/utils/logger.dart';
import '../../airport_search/models/airport_search_models.dart';
import '../../airport_search/services/airport_search_service.dart';
import '../models/briefing_record.dart';
import '../models/briefing_airport_bundle.dart';
import '../models/briefing_fuel_plan.dart';

/// 飞行简报核心服务类 (Service)
/// 负责简报内容的自动生成 (含油量测算、跑道筛选、气象解析)
/// 以及历史记录的本地磁盘 I/O 管理。
class BriefingService {
  final AirportSearchService _airportService = AirportSearchService();
  final PersistenceService _persistence = PersistenceService();

  /// 异步获取机场详情及其 METAR 气象打包数据
  Future<BriefingAirportBundle> fetchAirportBundle(String icao) async {
    try {
      AppLogger.info('Fetching airport bundle for $icao');
      final result = await _airportService.queryAirportAndMetar(icao);
      return BriefingAirportBundle(
        airport: result.airport,
        metar: result.metar,
      );
    } catch (e) {
      AppLogger.warning('Failed to fetch METAR for $icao, falling back to static data: $e');
      // 网络请求失败时回退到纯静态详情加载
      final airport = await _airportService.fetchAirport(icao);
      return BriefingAirportBundle(airport: airport, metar: null);
    }
  }

  /// 简报核心生成算法：基于多源数据（机场、气象、航向、燃油模型）生成纯文本总结
  String buildBriefingSummary({
    required DateTime generatedAt,
    required String flightNo,
    required BriefingAirportBundle departure,
    required BriefingAirportBundle arrival,
    required BriefingAirportBundle? alternate,
    required String route,
    required int cruiseAltitude,
    required double? distanceNm,
    required int? estimatedMinutes,
    required String? depRunway,
    required String? arrRunway,
    required String? altRunway,
    required BriefingFuelPlan fuel,
  }) {
    final buffer = StringBuffer()
      ..writeln('FLT: $flightNo')
      ..writeln('GEN: ${_formatDateTime(generatedAt)}')
      ..writeln('DEP: ${_formatAirportLine(departure.airport)}')
      ..writeln('ARR: ${_formatAirportLine(arrival.airport)}')
      ..writeln(
        'ALT: ${alternate == null ? "--" : _formatAirportLine(alternate.airport)}',
      )
      ..writeln('RTE: $route')
      ..writeln('CRZ: FL${(cruiseAltitude / 100).round()}')
      ..writeln(
        'DIST: ${distanceNm != null ? "${distanceNm.toStringAsFixed(0)} NM" : "--"}',
      )
      ..writeln(
        'EET: ${estimatedMinutes != null ? _formatDuration(estimatedMinutes) : "--"}',
      )
      ..writeln('DEP RWY: ${depRunway ?? "--"}')
      ..writeln('ARR RWY: ${arrRunway ?? "--"}')
      ..writeln('ALT RWY: ${altRunway ?? "--"}')
      ..writeln('DEP WX: ${_formatWeatherLine(departure.metar)}')
      ..writeln('ARR WX: ${_formatWeatherLine(arrival.metar)}')
      ..writeln(
        'ALT WX: ${alternate == null ? "--" : _formatWeatherLine(alternate.metar)}',
      )
      ..writeln('TRIP FUEL: ${fuel.trip.toStringAsFixed(0)} KG')
      ..writeln('ALTN FUEL: ${fuel.alternate.toStringAsFixed(0)} KG')
      ..writeln('RESV FUEL: ${fuel.reserve.toStringAsFixed(0)} KG')
      ..writeln('TAXI FUEL: ${fuel.taxi.toStringAsFixed(0)} KG')
      ..writeln('EXTRA FUEL: ${fuel.extra.toStringAsFixed(0)} KG')
      ..writeln('TOTAL FUEL: ${fuel.total.toStringAsFixed(0)} KG')
      ..writeln('AVG FLOW: ${fuel.avgFlow.toStringAsFixed(0)} KG/H')
      ..writeln('ETA FUEL: ${fuel.estimatedArrivalFuel.toStringAsFixed(0)} KG');
    return buffer.toString();
  }

  /// 智能油耗测算模型 (简化版)
  /// 基于航程距离、是否有备降场等因素进行自动配载
  BriefingFuelPlan buildFuelPlan({
    required double? distanceNm,
    required bool hasAlternate,
  }) {
    final trip = (distanceNm ?? 0) * 2.5; // 每海里预设油耗系数
    final alternate = hasAlternate ? 200 * 2.5 : 0.0;
    const reserve = 1500.0;
    const taxi = 200.0;
    final extra = trip * 0.05; // 5% 裕量
    final total = trip + alternate + reserve + taxi + extra;
    final estimatedArrivalFuel = reserve + alternate;

    // 计算估算平均小时油耗 (KG/H), 限制在标准区间内
    final avgFlow = distanceNm == null || distanceNm <= 0
        ? 2600.0
        : (trip / (distanceNm / 450.0)).clamp(1800.0, 3400.0);

    return BriefingFuelPlan(
      trip: trip,
      alternate: alternate,
      reserve: reserve,
      taxi: taxi,
      extra: extra,
      total: total,
      avgFlow: avgFlow,
      estimatedArrivalFuel: estimatedArrivalFuel,
    );
  }

  /// 经纬度航段距离计算 (大圆法, 单位: NM)
  double? calculateDistanceNm(
    double? lat1,
    double? lon1,
    double? lat2,
    double? lon2,
  ) {
    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
      return null;
    }
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final km = earthRadiusKm * c;
    return km * 0.539957; // KM -> NM
  }

  /// 智能跑道推荐算法
  /// 根据机场跑道配置及实时 METAR 风向进行逆风筛选
  String? selectBestRunway(AirportDetailData airport, MetarData? metar) {
    if (airport.runways.isEmpty) return null;
    final windDirection = _parseWindDirection(
      metar?.raw ?? metar?.decoded ?? '',
    );
    if (windDirection == null) return airport.runways.first.ident;

    String? best;
    var minDiff = 180;
    for (final runway in airport.runways) {
      final parts = runway.ident
          .split('/')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty);
      for (final part in parts) {
        final heading = _parseRunwayHeading(part);
        if (heading == null) continue;
        final diff = (windDirection - heading).abs();
        final normalized = diff > 180 ? 360 - diff : diff;
        if (normalized < minDiff) {
          minDiff = normalized;
          best = part;
        }
      }
    }
    return best ?? airport.runways.first.ident;
  }

  /// 持久化: 加载所有本地简报记录
  Future<List<BriefingRecord>> loadAllRecords() async {
    final dir = await _ensureDirectory();
    if (dir == null) return [];
    final entries = await dir
        .list()
        .where((e) => e is File)
        .cast<File>()
        .where((f) => p.extension(f.path).toLowerCase() == '.json')
        .toList();

    final List<BriefingRecord> loaded = [];
    for (final file in entries) {
      final records = await _loadRecordsFromFile(file);
      loaded.addAll(records);
    }
    loaded.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return loaded;
  }

  /// 磁盘写入: 保存单条简报项
  Future<BriefingRecord> saveRecord(BriefingRecord record) async {
    final dir = await _ensureDirectory();
    if (dir == null) return record;
    final fileName = 'briefing_${record.createdAt.millisecondsSinceEpoch}.json';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(record.toJson()),
    );
    return record.copyWith(sourceFilePath: file.path);
  }

  /// 磁盘删除: 清理单条简报记录
  Future<bool> deleteFromStorage(BriefingRecord record) async {
    final filePath = record.sourceFilePath;
    if (filePath == null || filePath.isEmpty) return false;
    final file = File(filePath);
    if (!await file.exists()) return false;

    // 如果文件是单条记录形式 (新版本格式)
    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      await file.delete();
      return true;
    }
    final decoded = jsonDecode(content);
    if (decoded is Map<String, dynamic> && _isSame(decoded, record)) {
      await file.delete();
      return true;
    }

    // 处理旧版本或批量导出后的文件 (文件内包含数组)
    if (decoded is List) {
      final remaining = decoded
          .whereType<Map<String, dynamic>>()
          .where((j) => !_isSame(j, record))
          .toList();
      if (remaining.length == decoded.length) return false;
      if (remaining.isEmpty) {
        await file.delete();
      } else {
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(remaining),
        );
      }
      return true;
    }
    return false;
  }

  /// --- 内部私有辅助域 ---

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, "0")}-${dt.day.toString().padLeft(2, "0")} '
        '${dt.hour.toString().padLeft(2, "0")}:${dt.minute.toString().padLeft(2, "0")}';
  }

  String _formatDuration(int minutes) {
    return '${minutes ~/ 60}H ${(minutes % 60).toString().padLeft(2, "0")}M';
  }

  String _formatAirportLine(AirportDetailData a) {
    return [
      a.icao,
      a.name,
      a.city,
    ].where((s) => s != null && s.isNotEmpty).join(' | ');
  }

  String _formatWeatherLine(MetarData? m) {
    if (m == null || (m.raw ?? '').isEmpty) return 'NO METAR';
    final source = (m.raw ?? m.decoded ?? '').trim();
    // 简单正则提取关键气象徽章 (风、能见、温/露、QNH)
    final wind = RegExp(
      r'\b(\d{3}|VRB)(\d{2,3})G?(\d{2,3})?KT\b',
    ).firstMatch(source);
    final vis = RegExp(r'\b(\d{4})\b').firstMatch(source);
    final temp = RegExp(r'\b(M?\d{2})/(M?\d{2})\b').firstMatch(source);
    final qnh = RegExp(r'\bQ(\d{4})\b').firstMatch(source);

    final pieces = <String>[
      if (wind != null) 'WIND ${wind.group(1)}${wind.group(2)}KT',
      if (vis != null) 'VIS ${vis.group(1)}m',
      if (temp != null) 'TEMP ${temp.group(1)}/${temp.group(2)}',
      if (qnh != null) 'QNH ${qnh.group(1)}',
    ];
    return pieces.isNotEmpty ? pieces.join(' · ') : source;
  }

  int? _parseWindDirection(String s) {
    final m = RegExp(r'\b(\d{3}|VRB)\d{2,3}(?:G\d{2,3})?KT\b').firstMatch(s);
    if (m == null) return null;
    final g = m.group(1);
    return (g == null || g == 'VRB') ? null : int.tryParse(g);
  }

  int? _parseRunwayHeading(String rw) {
    final v = rw.toUpperCase().replaceAll(RegExp(r'[^0-9]'), '');
    final n = int.tryParse(v);
    return n == null ? null : (n % 36) * 10;
  }

  Future<Directory?> _ensureDirectory() async {
    await _persistence.ensureReady();
    final root = _persistence.rootPath;
    if (root == null) return null;
    final d = Directory(p.join(root, 'flight_briefings'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  bool _isSame(Map<String, dynamic> json, BriefingRecord r) {
    final c = BriefingRecord.fromJson(json);
    return c.title == r.title &&
        c.content == r.content &&
        c.createdAt.toIso8601String() == r.createdAt.toIso8601String();
  }

  Future<List<BriefingRecord>> _loadRecordsFromFile(File f) async {
    try {
      final s = await f.readAsString();
      if (s.trim().isEmpty) return [];
      final d = jsonDecode(s);
      if (d is Map<String, dynamic>) {
        return [BriefingRecord.fromJson(d).copyWith(sourceFilePath: f.path)];
      }
      if (d is List) {
        return d
            .whereType<Map<String, dynamic>>()
            .map(BriefingRecord.fromJson)
            .map((rr) => rr.copyWith(sourceFilePath: f.path))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
