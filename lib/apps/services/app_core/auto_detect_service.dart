import 'dart:convert';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import '../../../core/utils/logger.dart';
import '../../data/xplane_apt_dat_parser.dart';
import '../airport_detail_service.dart';

class AutoDetectService {
  Future<List<Map<String, String>>> detectPaths() async {
    final List<Map<String, String>> detectedDbs = [];

    Future<void> addDb(String path, AirportDataSource source) async {
      if (detectedDbs.any((db) => db['path'] == path)) return;
      try {
        final info = await getDatabaseInfo(path, source);
        detectedDbs.add(info);
      } catch (_) {
        // Ignore errors during detection
      }
    }

    if (Platform.isWindows) {
      // 1. Little Navmap 路径检测
      final appData = Platform.environment['APPDATA'];
      final localAppData = Platform.environment['LOCALAPPDATA'];
      final username = Platform.environment['USERNAME'];

      final lnmSearchPaths = [
        "C:\\Program Files\\Little Navmap\\little_navmap_db",
        "C:\\Program Files (x86)\\Little Navmap\\little_navmap_db",
        if (appData != null) "$appData\\ABarthel\\little_navmap_db",
        if (localAppData != null) "$localAppData\\ABarthel\\little_navmap_db",
        if (username != null)
          "C:\\Users\\$username\\AppData\\Roaming\\ABarthel\\little_navmap_db",
      ];

      for (final dirPath in lnmSearchPaths) {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          final files = await dir.list().toList();
          for (final file in files) {
            if (file is File &&
                file.path.toLowerCase().endsWith('.sqlite') &&
                (file.path.toLowerCase().contains('navdata') ||
                    file.path.toLowerCase().contains('navigraph'))) {
              await addDb(file.path, AirportDataSource.lnmData);
            }
          }
        }
      }

      // 2. X-Plane 路径检测
      final drives = ['C:', 'D:', 'E:', 'F:', 'G:', 'H:'];
      for (final drive in drives) {
        final possibleDirs = [
          '$drive\\X-Plane 12',
          '$drive\\X-Plane 11',
          '$drive\\SteamLibrary\\steamapps\\common\\X-Plane 12',
          '$drive\\SteamLibrary\\steamapps\\common\\X-Plane 11',
          '$drive\\Program Files (x86)\\Steam\\steamapps\\common\\X-Plane 12',
          '$drive\\Program Files (x86)\\Steam\\steamapps\\common\\X-Plane 11',
        ];

        for (final dir in possibleDirs) {
          final defaultFile = File(
            '$dir\\Resources\\default data\\earth_nav.dat',
          );
          if (await defaultFile.exists()) {
            await addDb(defaultFile.path, AirportDataSource.xplaneData);
          }
          final customFile = File('$dir\\Custom Data\\earth_nav.dat');
          if (await customFile.exists()) {
            await addDb(customFile.path, AirportDataSource.xplaneData);
          }
        }
      }
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      final lnmSearchPaths = [
        "$home/Library/Application Support/ABarthel/little_navmap_db",
        "/Applications/Little Navmap/little_navmap_db",
      ];

      for (final dirPath in lnmSearchPaths) {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          final files = await dir.list().toList();
          for (final file in files) {
            if (file is File &&
                file.path.toLowerCase().endsWith('.sqlite') &&
                (file.path.toLowerCase().contains('navdata') ||
                    file.path.toLowerCase().contains('navigraph'))) {
              await addDb(file.path, AirportDataSource.lnmData);
            }
          }
        }
      }

      final possibleXPlaneDirs = [
        '/Applications/X-Plane 12',
        '/Applications/X-Plane 11',
        '$home/Library/Application Support/Steam/steamapps/common/X-Plane 12',
        '$home/Library/Application Support/Steam/steamapps/common/X-Plane 11',
      ];

      for (final dir in possibleXPlaneDirs) {
        final defaultFile = File('$dir/Resources/default data/earth_nav.dat');
        if (await defaultFile.exists()) {
          await addDb(defaultFile.path, AirportDataSource.xplaneData);
        }
        final customFile = File('$dir/Custom Data/earth_nav.dat');
        if (await customFile.exists()) {
          await addDb(customFile.path, AirportDataSource.xplaneData);
        }
      }
    }

    return detectedDbs;
  }

  Future<bool> validateLnmDatabase(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;
    try {
      final db = sqlite3.open(path);
      try {
        final tables = db.select(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='airport'",
        );
        return tables.isNotEmpty;
      } finally {
        db.dispose();
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> validateXPlaneData(String path) async {
    try {
      final aptPath = await XPlaneAptDatParser.resolveAptDatPath(path);
      if (aptPath == null) return false;
      final file = File(aptPath);
      if (!await file.exists()) return false;
      final lines = await file
          .openRead(0, 1024)
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .take(1)
          .toList();
      if (lines.isEmpty) return false;
      return lines.first.trim() == 'I' || lines.first.trim() == '1000';
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, String>> getDatabaseInfo(
    String path,
    AirportDataSource source,
  ) async {
    final info = <String, String>{
      'path': path,
      'type': source.displayName,
      'airac': '未知',
      'expiry': '',
      'is_expired': 'false',
    };

    try {
      final file = File(path);
      final parentDir = file.parent;

      final possibleCycleFiles = [
        File('${parentDir.path}/cycle_info.txt'),
        if (source == AirportDataSource.xplaneData)
          File('${parentDir.parent.path}/cycle_info.txt'),
      ];

      for (final cycleFile in possibleCycleFiles) {
        if (await cycleFile.exists()) {
          final content = await cycleFile.readAsString();

          final cycleMatch = RegExp(
            r'AIRAC cycle\s*:\s*(\d+)',
            caseSensitive: false,
          ).firstMatch(content);
          if (cycleMatch != null) {
            info['airac'] = cycleMatch.group(1) ?? '未知';
          }

          final validityMatch = RegExp(
            r'Valid\s*\(from/to\):\s*[^-\n]+-\s*(\d{1,2}/[A-Z]{3}/\d{4})',
            caseSensitive: false,
          ).firstMatch(content);

          if (validityMatch != null) {
            final expiryStr = validityMatch.group(1)!;
            info['expiry'] = expiryStr;

            try {
              final months = {
                'JAN': 1,
                'FEB': 2,
                'MAR': 3,
                'APR': 4,
                'MAY': 5,
                'JUN': 6,
                'JUL': 7,
                'AUG': 8,
                'SEP': 9,
                'OCT': 10,
                'NOV': 11,
                'DEC': 12,
              };
              final parts = expiryStr.split('/');
              if (parts.length == 3) {
                final day = int.parse(parts[0]);
                final month = months[parts[1].toUpperCase()] ?? 1;
                final year = int.parse(parts[2]);
                final expiryDate = DateTime(year, month, day);
                if (DateTime.now().isAfter(
                  expiryDate.add(const Duration(days: 1)),
                )) {
                  info['is_expired'] = 'true';
                }
              }
            } catch (_) {}
          } else {
            final oldExpiryMatch = RegExp(
              r'to\s+(\d{1,2}\s+[A-Z]{3}\s+\d{4})',
              caseSensitive: false,
            ).firstMatch(content);
            if (oldExpiryMatch != null) {
              final expiryStr = oldExpiryMatch.group(1)!;
              info['expiry'] = expiryStr;

              try {
                final months = {
                  'JAN': 1,
                  'FEB': 2,
                  'MAR': 3,
                  'APR': 4,
                  'MAY': 5,
                  'JUN': 6,
                  'JUL': 7,
                  'AUG': 8,
                  'SEP': 9,
                  'OCT': 10,
                  'NOV': 11,
                  'DEC': 12,
                };
                final parts = expiryStr.split(RegExp(r'\s+'));
                if (parts.length == 3) {
                  final day = int.parse(parts[0]);
                  final month = months[parts[1].toUpperCase()] ?? 1;
                  final year = int.parse(parts[2]);
                  final expiryDate = DateTime(year, month, day);
                  if (DateTime.now().isAfter(
                    expiryDate.add(const Duration(days: 1)),
                  )) {
                    info['is_expired'] = 'true';
                  }
                }
              } catch (_) {}
            }
          }

          if (info['airac'] != '未知') break;
        }
      }

      if (source == AirportDataSource.lnmData && info['airac'] == '未知') {
        final db = sqlite3.open(path);
        try {
          final metadataTables = db.select(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='metadata'",
          );
          if (metadataTables.isNotEmpty) {
            final columns = db
                .select("PRAGMA table_info(metadata)")
                .map((row) => row['name'].toString().toLowerCase())
                .toList();
            final keyCol = columns.contains('key')
                ? 'key'
                : (columns.contains('name') ? 'name' : null);
            final valueCol = columns.contains('value') ? 'value' : null;
            if (keyCol != null && valueCol != null) {
              final result = db.select(
                "SELECT $valueCol FROM metadata WHERE $keyCol = 'NavDataCycle'",
              );
              if (result.isNotEmpty) {
                info['airac'] = result.first[valueCol].toString();
              }
            }
          }
        } catch (e) {
          AppLogger.error('Error reading LNM metadata: $e');
        } finally {
          db.dispose();
        }
      } else if (source == AirportDataSource.xplaneData &&
          info['airac'] == '未知') {
        final lines = await file
            .openRead(0, 2048)
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .take(10)
            .toList();
        for (final line in lines) {
          if (line.contains('Cycle')) {
            final match = RegExp(r'Cycle\s+(\d+)').firstMatch(line);
            if (match != null) {
              info['airac'] = match.group(1)!;
              break;
            }
          }
        }
      }
    } catch (e) {
      AppLogger.error('Error getting database info: $e');
    }

    return info;
  }
}
