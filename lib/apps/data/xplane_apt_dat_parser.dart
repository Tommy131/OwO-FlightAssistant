import 'dart:convert';
import 'dart:io';

import '../models/airport_detail_data.dart';
import 'airports_database.dart';

class XPlaneAptDatParser {
  static Future<AirportDetailData?> loadAirportByIcao({
    required String icaoCode,
    required String? earthNavPath,
  }) async {
    final aptPath = await resolveAptDatPath(earthNavPath);
    if (aptPath == null) return null;

    return _parseAptDatForAirport(File(aptPath), icaoCode.toUpperCase());
  }

  static Future<AirportDetailData?> loadAirportFromAptPath({
    required String icaoCode,
    required String aptPath,
  }) async {
    final file = File(aptPath);
    if (!await file.exists()) return null;
    return _parseAptDatForAirport(file, icaoCode.toUpperCase());
  }

  static Future<String?> resolveAptDatPath(String? inputPath) async {
    if (inputPath == null || inputPath.isEmpty) return null;
    final type = await FileSystemEntity.type(inputPath);
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
    if (lowerName == 'earth_nav.dat') {
      return _locateAptDat(file.path);
    }
    return _locateAptDat(file.path);
  }

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
        return null;
      }
      return null;
    }

    return await walk(startDir, 0);
  }

  static Future<List<Map<String, dynamic>>> getAllAirports(File aptFile) async {
    final airports = <Map<String, dynamic>>[];
    String? currentName;
    String? currentIcao;
    final stream = aptFile
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final line in stream) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('1 ') ||
          trimmed.startsWith('16 ') ||
          trimmed.startsWith('17 ')) {
        currentName = _extractAirportNameFromHeader(trimmed);
        currentIcao = _extractAirportIcaoFromHeader(trimmed);
        if (currentName != null && currentIcao != null) {
          airports.add({
            'icao': currentIcao,
            'name': currentName,
            'lat': 0.0,
            'lon': 0.0,
          });
          currentName = null;
          currentIcao = null;
        }
        continue;
      }
      if (currentName == null) continue;
      if (trimmed.startsWith('1302 ')) {
        final parts = _splitTokens(trimmed);
        if (parts.length >= 3 && parts[1].toLowerCase() == 'code') {
          currentIcao = parts[2].toUpperCase();
          if (currentIcao.isNotEmpty) {
            airports.add({
              'icao': currentIcao,
              'name': currentName,
              'lat': 0.0,
              'lon': 0.0,
            });
            currentName = null;
            currentIcao = null;
          }
        }
      }
    }
    return airports;
  }

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
    bool matchTarget = false;

    final stream = aptFile
        .openRead()
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter());

    await for (final line in stream) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('1 ') ||
          trimmed.startsWith('16 ') ||
          trimmed.startsWith('17 ')) {
        if (matchTarget && currentIcao == icao) {
          final fallback = AirportsDatabase.findByIcao(icao);
          final lat = currentLat ?? fallback?.latitude ?? 0.0;
          final lon = currentLon ?? fallback?.longitude ?? 0.0;
          return AirportDetailData(
            icaoCode: icao,
            iataCode: null,
            name: currentName ?? (fallback?.nameChinese ?? icao),
            city: null,
            country: null,
            latitude: lat,
            longitude: lon,
            elevation: null,
            runways: List.of(currentRunways),
            frequencies: AirportFrequencies(all: List.of(currentFreqs)),
            fetchedAt: DateTime.now(),
            dataSource: AirportDataSourceType.xplaneData,
          );
        }

        currentName = _extractAirportNameFromHeader(trimmed);
        currentIcao = _extractAirportIcaoFromHeader(trimmed);
        matchTarget = currentIcao == icao;
        currentLat = null;
        currentLon = null;
        currentRunways.clear();
        currentFreqs.clear();
        continue;
      }

      if (currentName == null) continue;

      if (trimmed.startsWith('100 ')) {
        final parts = _splitTokens(trimmed);
        if (parts.length >= 2) {
          final le = parts[parts.length - 2];
          final he = parts[parts.length - 1];
          currentRunways.add(RunwayInfo(ident: '$le/$he'));
        }

        if (currentLat == null || currentLon == null) {
          final nums = _extractAllNumbers(trimmed);
          if (nums.length >= 4) {
            final lat1 = nums[nums.length - 4];
            final lon1 = nums[nums.length - 3];
            final lat2 = nums[nums.length - 2];
            final lon2 = nums[nums.length - 1];
            currentLat = (lat1 + lat2) / 2.0;
            currentLon = (lon1 + lon2) / 2.0;
          }
        }
        continue;
      }

      if (trimmed.startsWith('1300 ')) {
        final parts = _splitTokens(trimmed);
        if (parts.length >= 3) {
          final freqStr = parts[1];
          final type = parts[2].toUpperCase();
          final desc = parts.length > 3 ? parts.sublist(3).join(' ') : null;
          final freq = double.tryParse(freqStr);
          if (freq != null) {
            currentFreqs.add(
              FrequencyInfo(type: type, frequency: freq, description: desc),
            );
          }
        }
        continue;
      }

      if (trimmed.startsWith('1302 ')) {
        final parts = _splitTokens(trimmed);
        if (parts.length >= 3 && parts[1].toLowerCase() == 'code') {
          currentIcao = parts[2].toUpperCase();
          matchTarget = currentIcao == icao;
        }
        continue;
      }

      if (trimmed.startsWith('99 ') || trimmed == '99') {
        if (matchTarget && currentIcao == icao) {
          final fallback = AirportsDatabase.findByIcao(icao);
          final lat = currentLat ?? fallback?.latitude ?? 0.0;
          final lon = currentLon ?? fallback?.longitude ?? 0.0;
          return AirportDetailData(
            icaoCode: icao,
            iataCode: null,
            name: currentName,
            city: null,
            country: null,
            latitude: lat,
            longitude: lon,
            elevation: null,
            runways: List.of(currentRunways),
            frequencies: AirportFrequencies(all: List.of(currentFreqs)),
            fetchedAt: DateTime.now(),
            dataSource: AirportDataSourceType.xplaneData,
          );
        }
        break;
      }
    }

    return null;
  }

  static List<String> _splitTokens(String line) {
    return line.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  }

  static List<double> _extractAllNumbers(String line) {
    final matches = RegExp(r'[-+]?\d+(\.\d+)?').allMatches(line);
    return matches
        .map((m) => double.tryParse(m.group(0)!) ?? double.nan)
        .where((v) => v.isFinite)
        .toList();
  }

  static String? _extractAirportNameFromHeader(String line) {
    final parts = _splitTokens(line);
    if (parts.isEmpty ||
        (parts[0] != '1' && parts[0] != '16' && parts[0] != '17')) {
      return null;
    }
    int start = 1;
    while (start < parts.length &&
        RegExp(r'^[\d\-]+$').hasMatch(parts[start])) {
      start++;
    }
    if (start >= parts.length) return null;
    if (RegExp(r'^[A-Z0-9]{3,5}$').hasMatch(parts[start])) {
      start++;
    }
    if (start >= parts.length) return null;
    return parts.sublist(start).join(' ');
  }

  static String? _extractAirportIcaoFromHeader(String line) {
    final parts = _splitTokens(line);
    if (parts.length < 5) return null;
    if (parts[0] != '1' && parts[0] != '16' && parts[0] != '17') return null;
    final icao = parts[4].toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{3,5}$').hasMatch(icao)) return null;
    return icao;
  }
}
