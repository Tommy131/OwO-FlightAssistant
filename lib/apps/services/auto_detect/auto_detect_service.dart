import 'dart:io';
import '../../../apps/services/airport_detail_service.dart';

class AutoDetectService {
  final AirportDetailService _airportService = AirportDetailService();

  Future<List<Map<String, String>>> detectPaths() async {
    final List<Map<String, String>> detectedDbs = [];

    Future<void> addDb(String path, AirportDataSource source) async {
      if (detectedDbs.any((db) => db['path'] == path)) return;
      try {
        final info = await _airportService.getDatabaseInfo(path, source);
        detectedDbs.add(info);
      } catch (e) {
        // 忽略单个文件的读取错误
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
}
