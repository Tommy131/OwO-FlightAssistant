import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../models/airport_detail_data.dart';
import 'airports_database.dart';

/// X-Plane `apt.dat` 机场数据解析器
///
/// 负责从 X-Plane 的格式化文本文件中提取机场、跑道和频率信息。
class XPlaneAptDatParser {
  // --- X-Plane apt.dat 记录行代码常量 ---
  static const String rowAirport = '1';
  static const String rowSeaplaneBase = '16';
  static const String rowHeliport = '17';
  static const String rowRunway = '100';
  static const String rowWaterRunway = '101';
  static const String rowHelipad = '102';
  static const String rowFreqLegacyStart = '50';
  static const String rowFreqLegacyEnd = '56';
  static const String rowFreqModernStart = '1050';
  static const String rowFreqModernEnd = '1056';
  static const String rowMetadata = '1302';
  static const String rowTaxiwayPavement = '110';
  static const String rowTaxiwayPavementNode = '111';
  static const String rowTaxiwayPavementNodeCurve = '112';
  static const String rowRampStart = '1300';
  static const String rowEnd = '99';

  /// 根据 ICAO 代码加载机场详细数据
  ///
  /// [icaoCode] 机场的 ICAO 代码。
  /// [earthNavPath] 可选的 X-Plane 数据路径（如 earth_nav.dat 的位置），用于自动定位 apt.dat。
  static Future<AirportDetailData?> loadAirportByIcao({
    required String icaoCode,
    required String? earthNavPath,
  }) async {
    final aptPath = await resolveAptDatPath(earthNavPath);
    if (aptPath == null) return null;

    return _parseAptDatForAirport(File(aptPath), icaoCode.toUpperCase());
  }

  /// 直接从指定的 apt.dat 文件路径加载机场数据
  ///
  /// [icaoCode] 机场的 ICAO 代码。
  /// [aptPath] apt.dat 文件的绝对路径。
  static Future<AirportDetailData?> loadAirportFromAptPath({
    required String icaoCode,
    required String aptPath,
  }) async {
    final file = File(aptPath);
    if (!await file.exists()) return null;
    return _parseAptDatForAirport(file, icaoCode.toUpperCase());
  }

  /// 尝试解析输入路径以定位真实的 apt.dat 文件路径
  ///
  /// 支持输入文件夹、apt.dat 文件本身或 earth_nav.dat 文件。
  static Future<String?> resolveAptDatPath(String? inputPath) async {
    if (inputPath == null || inputPath.isEmpty) return null;
    final type = await FileSystemEntity.type(inputPath);

    // 如果是目录，尝试在目录下或子目录找 apt.dat
    if (type == FileSystemEntityType.directory) {
      final dir = Directory(inputPath);
      final direct = File('${dir.path}${Platform.pathSeparator}apt.dat');
      if (await direct.exists()) return direct.path;
      final found = await _findFileRecursively(dir, 'apt.dat', maxDepth: 4);
      return found?.path;
    }

    if (type != FileSystemEntityType.file) return null;

    final file = File(inputPath);
    if (!await file.exists()) return null;

    final lowerName = file.uri.pathSegments.isEmpty
        ? ''
        : file.uri.pathSegments.last.toLowerCase();

    if (lowerName == 'apt.dat') return file.path;

    // 如果是 earth_nav.dat 或其他文件，尝试通过相对位置定位 apt.dat
    return _locateAptDat(file.path);
  }

  /// 基于 earth_nav.dat 的位置探索 X-Plane 标准目录结构以寻找 apt.dat
  static Future<String?> _locateAptDat(String? earthNavPath) async {
    if (earthNavPath == null) return null;
    try {
      final earthFile = File(earthNavPath);
      if (!await earthFile.exists()) return null;

      final sep = Platform.pathSeparator;
      final earthParent = earthFile.parent;
      final parentName = earthParent.path
          .split(Platform.pathSeparator)
          .last
          .toLowerCase();
      Directory resourcesDir;
      Directory xplaneRoot;
      if (parentName == 'default data') {
        resourcesDir = earthParent.parent;
        xplaneRoot = resourcesDir.parent;
      } else if (parentName == 'custom data') {
        xplaneRoot = earthParent.parent;
        resourcesDir = Directory('${xplaneRoot.path}${sep}Resources');
      } else {
        resourcesDir = earthParent.parent;
        if (!resourcesDir.path.toLowerCase().endsWith('resources')) {
          final probe = Directory('${resourcesDir.path}${sep}Resources');
          resourcesDir = probe;
        }
        xplaneRoot = resourcesDir.parent;
      }

      final candidates = <Directory>[
        Directory(
          '${resourcesDir.path}${sep}default scenery${sep}default apt dat${sep}Earth nav data',
        ),
        Directory(
          '${resourcesDir.path}${sep}default scenery${sep}Global Airports${sep}Earth nav data',
        ),
        Directory(
          '${xplaneRoot.path}${sep}Custom Scenery${sep}Global Airports${sep}Earth nav data',
        ),
        Directory(
          '${xplaneRoot.path}${sep}Global Scenery${sep}X-Plane 12 Global Airports${sep}Earth nav data',
        ),
      ];

      for (final dir in candidates) {
        final aptFile = File('${dir.path}${sep}apt.dat');
        if (await aptFile.exists()) {
          return aptFile.path;
        }
      }

      final rootDir = xplaneRoot;
      final found = await _findFileRecursively(rootDir, 'apt.dat', maxDepth: 8);
      return found?.path;
    } catch (_) {
      return null;
    }
  }

  /// 递归查找指定文件名的文件
  static Future<File?> _findFileRecursively(
    Directory startDir,
    String fileName, {
    int maxDepth = 4,
  }) async {
    Future<File?> walk(Directory dir, int depth) async {
      if (depth > maxDepth) return null;
      try {
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is File &&
              entity.path.toLowerCase().endsWith(fileName.toLowerCase())) {
            return entity;
          }
          if (entity is Directory) {
            final res = await walk(entity, depth + 1);
            if (res != null) return res;
          }
        }
      } catch (_) {
        // 忽略权限错误等异常
        return null;
      }
      return null;
    }

    return await walk(startDir, 0);
  }

  /// 获取文件中所有机场的简要列表（用于索引）
  static Future<List<Map<String, dynamic>>> getAllAirports(File aptFile) async {
    final airports = <Map<String, dynamic>>[];
    Map<String, dynamic>? currentAirport;

    final stream = aptFile
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in stream) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final parts = _splitTokens(trimmed);
      if (parts.isEmpty) continue;
      final code = parts[0];

      // 处理机场头部
      if (code == rowAirport ||
          code == rowSeaplaneBase ||
          code == rowHeliport) {
        if (currentAirport != null) {
          airports.add(currentAirport);
        }

        final name = _extractAirportNameFromHeader(trimmed);
        final icao = _extractAirportIcaoFromHeader(trimmed);

        if (icao != null && name != null) {
          currentAirport = {
            'icao': icao,
            'iata': '',
            'name': name,
            'lat': 0.0,
            'lon': 0.0,
          };
        } else {
          currentAirport = null;
        }
        continue;
      }

      if (currentAirport == null) continue;

      // 提取粗略坐标用于地图定位
      _extractCoordinatesToMap(currentAirport, code, parts);

      // 处理可选的扩展元数据
      if (code == rowMetadata && parts.length >= 3) {
        final key = parts[1].toLowerCase();
        final value = parts[2].toUpperCase();
        if (key == 'code') {
          currentAirport['icao'] = value;
        } else if (key == 'iata') {
          currentAirport['iata'] = value;
        }
      }
    }

    if (currentAirport != null) {
      airports.add(currentAirport);
    }

    return airports;
  }

  /// 为特定机场解析详细数据的主函数
  static Future<AirportDetailData?> _parseAptDatForAirport(
    File aptFile,
    String icao,
  ) async {
    String? currentName;
    String? currentIcao;
    double? currentLat;
    double? currentLon;
    final currentRunways = <RunwayInfo>[];
    final currentFreqs = <FrequencyInfo>[];
    final currentTaxiways = <TaxiwayInfo>[];
    final currentParkings = <ParkingInfo>[];
    bool matchTarget = false;
    TaxiwayInfo? activeTaxiway;

    // 使用系统编码（对于 apt.dat 通常是 UTF-8 或 MacRoman，后者在旧版中常见）
    final stream = aptFile
        .openRead()
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter());

    await for (final line in stream) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final parts = _splitTokens(trimmed);
      if (parts.isEmpty) continue;
      final code = parts[0];

      // 情况 1: 遇到新的机场定义
      if (code == rowAirport ||
          code == rowSeaplaneBase ||
          code == rowHeliport) {
        // 如果之前已经匹配到了目标机场，现在遇到了下一个机场，说明目标解析完成
        if (matchTarget && currentIcao == icao) {
          return _assembleAirportData(
            icao,
            currentName,
            currentLat,
            currentLon,
            currentRunways,
            currentFreqs,
            currentTaxiways,
            currentParkings,
          );
        }

        // 开始新机场的解析状态
        currentName = _extractAirportNameFromHeader(trimmed);
        currentIcao = _extractAirportIcaoFromHeader(trimmed);
        matchTarget = currentIcao == icao;
        currentLat = null;
        currentLon = null;
        currentRunways.clear();
        currentFreqs.clear();
        currentTaxiways.clear();
        currentParkings.clear();
        activeTaxiway = null;
        continue;
      }

      // 只有在匹配目标机场时才解析后续行
      if (!matchTarget) continue;

      // 100: 跑道定义
      if (code == rowRunway) {
        final runway = _parseRunwayRecord(parts);
        if (runway != null) {
          currentRunways.add(runway);
          // 尝试更新机场坐标（取自第一条跑道的中点）
          if (currentLat == null) {
            final coords = _extractRunwayCenter(parts);
            if (coords != null) {
              currentLat = coords.latitude;
              currentLon = coords.longitude;
            }
          }
        }
        activeTaxiway = null;
        continue;
      }

      // 110: 滑行道铺装开始
      if (code == rowTaxiwayPavement) {
        final name = parts.length > 3 ? parts.sublist(3).join(' ') : null;
        activeTaxiway = TaxiwayInfo(name: name, points: []);
        currentTaxiways.add(activeTaxiway);
        continue;
      }

      // 111/112: 滑行道节点
      if (code == rowTaxiwayPavementNode ||
          code == rowTaxiwayPavementNodeCurve) {
        if (activeTaxiway != null && parts.length >= 3) {
          final lat = double.tryParse(parts[1]);
          final lon = double.tryParse(parts[2]);
          if (lat != null && lon != null) {
            activeTaxiway.points.add(Coord(lat, lon));
          }
        }
        continue;
      }

      // 1300: 停机位 (Ramp Start)
      if (code == rowRampStart) {
        if (parts.length >= 5) {
          final lat = double.tryParse(parts[1]);
          final lon = double.tryParse(parts[2]);
          final heading = double.tryParse(parts[3]);

          // X-Plane 1300 格式: 1300 <lat> <lon> <hdg> <type> <plane_types> <name>
          // 通常名称从 index 6 开始，如果有更多零件的话
          String name = '';
          if (parts.length >= 7) {
            name = parts.sublist(6).join(' ');
          } else if (parts.length >= 5) {
            // 如果零件不足，至少取最后一个作为名称
            name = parts.last;
          }

          if (lat != null && lon != null) {
            currentParkings.add(
              ParkingInfo(
                name: name.trim(),
                latitude: lat,
                longitude: lon,
                heading: heading ?? 0.0,
              ),
            );
          }
        }
        activeTaxiway = null;
        continue;
      }

      // 101/102: 水上跑道或停机坪
      if (code == rowWaterRunway || code == rowHelipad) {
        if (currentLat == null) {
          final coords = _extractPointRecordCoords(code, parts);
          if (coords != null) {
            currentLat = coords.latitude;
            currentLon = coords.longitude;
          }
        }
        continue;
      }

      // 处理通信频率 (50-56 或 1050-1056)
      final freqCodeInt = int.tryParse(code);
      if (freqCodeInt != null &&
          ((freqCodeInt >= 50 && freqCodeInt <= 56) ||
              (freqCodeInt >= 1050 && freqCodeInt <= 1056))) {
        final freq = _parseFrequencyRecord(code, parts);
        if (freq != null) {
          currentFreqs.add(freq);
        }
        continue;
      }

      // 1302: 元数据扩展
      if (code == rowMetadata) {
        if (parts.length >= 3 && parts[1].toLowerCase() == 'code') {
          currentIcao = parts[2].toUpperCase();
          matchTarget = currentIcao == icao;
        }
        continue;
      }

      // 99: 文件或区域结束
      if (code == rowEnd) {
        if (matchTarget && currentIcao == icao) {
          return _assembleAirportData(
            icao,
            currentName,
            currentLat,
            currentLon,
            currentRunways,
            currentFreqs,
            currentTaxiways,
            currentParkings,
          );
        }
        break;
      }
    }

    return null;
  }

  // --- 内部辅助解析方法 ---

  /// 从列表记录中提取简易坐标
  static void _extractCoordinatesToMap(
    Map<String, dynamic> airport,
    String code,
    List<String> parts,
  ) {
    if (airport['lat'] != 0.0) return;

    if (code == rowRunway && parts.length >= 11) {
      airport['lat'] = double.tryParse(parts[9]) ?? 0.0;
      airport['lon'] = double.tryParse(parts[10]) ?? 0.0;
    } else if (code == rowWaterRunway && parts.length >= 5) {
      airport['lat'] = double.tryParse(parts[3]) ?? 0.0;
      airport['lon'] = double.tryParse(parts[4]) ?? 0.0;
    } else if (code == rowHelipad && parts.length >= 4) {
      airport['lat'] = double.tryParse(parts[2]) ?? 0.0;
      airport['lon'] = double.tryParse(parts[3]) ?? 0.0;
    }
  }

  /// 组装 AirportDetailData 对象
  static AirportDetailData _assembleAirportData(
    String icao,
    String? name,
    double? lat,
    double? lon,
    List<RunwayInfo> runways,
    List<FrequencyInfo> freqs,
    List<TaxiwayInfo> taxiways,
    List<ParkingInfo> parkings,
  ) {
    final fallback = AirportsDatabase.findByIcao(icao);
    return AirportDetailData(
      icaoCode: icao,
      iataCode: null,
      name: name ?? (fallback?.nameChinese ?? icao),
      city: null,
      country: null,
      latitude: lat ?? (fallback?.latitude ?? 0.0),
      longitude: lon ?? (fallback?.longitude ?? 0.0),
      elevation: null,
      runways: List.of(runways),
      frequencies: AirportFrequencies(all: List.of(freqs)),
      taxiways: List.of(taxiways),
      parkings: List.of(parkings),
      fetchedAt: DateTime.now(),
      dataSource: AirportDataSourceType.xplaneData,
    );
  }

  /// 解析 100 跑道记录
  static RunwayInfo? _parseRunwayRecord(List<String> parts) {
    if (parts.length < 9) return null;
    final le = parts[8];
    final he = parts.length >= 18 ? parts[17] : null;
    final ident = he != null ? '$le/$he' : le;
    final widthMeters = double.tryParse(parts[1]);
    final surfaceCode = parts.length >= 3 ? parts[2] : null;
    final lighted = parts.length >= 7
        ? (int.tryParse(parts[6]) ?? 0) > 0
        : null;
    final lengthFt = _estimateRunwayLengthFt(parts);

    double? leLat, leLon, heLat, heLon;
    if (parts.length >= 11) {
      leLat = double.tryParse(parts[9]);
      leLon = double.tryParse(parts[10]);
    }
    if (parts.length >= 20) {
      heLat = double.tryParse(parts[18]);
      heLon = double.tryParse(parts[19]);
    }

    return RunwayInfo(
      ident: ident,
      lengthFt: lengthFt,
      widthFt: widthMeters != null ? (widthMeters * 3.28084).round() : null,
      surface: _mapSurfaceCode(surfaceCode),
      lighted: lighted,
      leIdent: le,
      heIdent: he,
      leLat: leLat,
      leLon: leLon,
      heLat: heLat,
      heLon: heLon,
    );
  }

  /// 从 100 跑道记录中计算中点经纬度
  static ({double latitude, double longitude})? _extractRunwayCenter(
    List<String> parts,
  ) {
    if (parts.length < 11) return null;
    final lat1 = double.tryParse(parts[9]);
    final lon1 = double.tryParse(parts[10]);
    if (lat1 == null || lon1 == null) return null;

    if (parts.length >= 20) {
      final lat2 = double.tryParse(parts[18]);
      final lon2 = double.tryParse(parts[19]);
      if (lat2 != null && lon2 != null) {
        return (latitude: (lat1 + lat2) / 2.0, longitude: (lon1 + lon2) / 2.0);
      }
    }
    return (latitude: lat1, longitude: lon1);
  }

  /// 从 101/102 点记录中提取坐标
  static ({double latitude, double longitude})? _extractPointRecordCoords(
    String code,
    List<String> parts,
  ) {
    if (code == rowWaterRunway && parts.length >= 5) {
      final lat = double.tryParse(parts[3]);
      final lon = double.tryParse(parts[4]);
      if (lat != null && lon != null) return (latitude: lat, longitude: lon);
    } else if (code == rowHelipad && parts.length >= 4) {
      final lat = double.tryParse(parts[2]);
      final lon = double.tryParse(parts[3]);
      if (lat != null && lon != null) return (latitude: lat, longitude: lon);
    }
    return null;
  }

  /// 解析传统 (50-56) 或现代 (1050-1056) 频率记录
  static FrequencyInfo? _parseFrequencyRecord(String code, List<String> parts) {
    if (parts.length < 2) return null;
    final codeInt = int.tryParse(code);
    if (codeInt == null) return null;

    final freqVal = double.tryParse(parts[1]);
    if (freqVal == null) return null;

    if (codeInt >= 1050 && codeInt <= 1056) {
      return FrequencyInfo(
        type: _mapModernFreqType(codeInt),
        frequency: _normalizeModernFrequency(freqVal),
        description: parts.length > 2 ? parts.sublist(2).join(' ') : null,
      );
    }

    if (codeInt >= 50 && codeInt <= 56) {
      return FrequencyInfo(
        type: _mapLegacyFreqType(codeInt),
        frequency: _normalizeLegacyFrequency(freqVal),
        description: parts.length > 2 ? parts.sublist(2).join(' ') : null,
      );
    }

    return null;
  }

  static int? _estimateRunwayLengthFt(List<String> parts) {
    if (parts.length < 20) return null;
    final lat1 = double.tryParse(parts[9]);
    final lon1 = double.tryParse(parts[10]);
    final lat2 = double.tryParse(parts[18]);
    final lon2 = double.tryParse(parts[19]);
    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
      return null;
    }
    final meters = _haversineMeters(lat1, lon1, lat2, lon2);
    if (meters == null) return null;
    return (meters * 3.28084).round();
  }

  static double? _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    final lat1Rad = _degToRad(lat1);
    final lat2Rad = _degToRad(lat2);
    final deltaLat = _degToRad(lat2 - lat1);
    final deltaLon = _degToRad(lon2 - lon1);
    final a =
        (sin(deltaLat / 2) * sin(deltaLat / 2)) +
        (cos(lat1Rad) * cos(lat2Rad) * sin(deltaLon / 2) * sin(deltaLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _degToRad(double deg) => deg * (pi / 180.0);

  static String? _mapSurfaceCode(String? raw) {
    if (raw == null) return null;
    final code = int.tryParse(raw);
    if (code == null) return raw;
    switch (code) {
      case 1:
        return 'ASP';
      case 2:
        return 'CON';
      case 3:
        return 'GRS';
      case 4:
        return 'DIRT';
      case 5:
        return 'GRAVEL';
      case 12:
        return 'WATER';
      case 13:
        return 'SNOW';
      case 14:
        return 'ICE';
      case 15:
        return 'ASP';
      default:
        return raw;
    }
  }

  static double _normalizeLegacyFrequency(double raw) {
    if (raw >= 100000) return raw / 1000.0;
    return raw / 100.0;
  }

  static double _normalizeModernFrequency(double raw) => raw / 1000.0;

  /// 映射旧版 (50-56) 频率代码
  static String _mapLegacyFreqType(int freqCode) {
    switch (freqCode) {
      case 50:
        return 'ATIS';
      case 51:
        return 'UNICOM';
      case 52:
        return 'DEL';
      case 53:
        return 'GND';
      case 54:
        return 'TWR';
      case 55:
        return 'APP';
      case 56:
        return 'DEP';
      default:
        return 'UNKNOWN';
    }
  }

  static String _mapModernFreqType(int freqCode) {
    switch (freqCode) {
      case 1050:
        return 'ATIS';
      case 1051:
        return 'UNICOM';
      case 1052:
        return 'DEL';
      case 1053:
        return 'GND';
      case 1054:
        return 'TWR';
      case 1055:
        return 'APP';
      case 1056:
        return 'DEP';
      default:
        return 'UNKNOWN';
    }
  }

  /// 工具：按空白字符分割字符串
  static List<String> _splitTokens(String line) {
    return line.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  }

  /// 从机场定义行解析机场名称
  static String? _extractAirportNameFromHeader(String line) {
    final parts = _splitTokens(line);
    if (parts.isEmpty ||
        (parts[0] != rowAirport &&
            parts[0] != rowSeaplaneBase &&
            parts[0] != rowHeliport)) {
      return null;
    }
    // 跳过代码和数值参数
    int start = 1;
    while (start < parts.length &&
        RegExp(r'^[\d\-]+$').hasMatch(parts[start])) {
      start++;
    }
    if (start >= parts.length) return null;
    // 跳过可能的 ICAO/IATA 简码
    if (RegExp(r'^[A-Z0-9]{3,5}$').hasMatch(parts[start])) {
      start++;
    }
    if (start >= parts.length) return null;
    return parts.sublist(start).join(' ');
  }

  /// 从机场定义行解析 ICAO 代码
  static String? _extractAirportIcaoFromHeader(String line) {
    final parts = _splitTokens(line);
    if (parts.length < 5) return null;
    if (parts[0] != rowAirport &&
        parts[0] != rowSeaplaneBase &&
        parts[0] != rowHeliport) {
      return null;
    }

    // X-Plane 10+ 格式中，ICAO 通常在第 5 列
    for (int i = 4; i < parts.length && i < 7; i++) {
      final candidate = parts[i].toUpperCase();
      if (RegExp(r'^[A-Z0-9]{3,5}$').hasMatch(candidate)) {
        return candidate;
      }
    }
    return null;
  }
}
