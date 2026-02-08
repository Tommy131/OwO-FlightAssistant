import 'package:shared_preferences/shared_preferences.dart';
import 'airport_detail_service.dart';
import 'auto_detect/auto_detect_service.dart';

class DatabasePathSelectionResult {
  final String? lnmPath;
  final String? xplanePath;
  final Map<String, String>? lnmInfo;
  final Map<String, String>? xplaneInfo;

  const DatabasePathSelectionResult({
    this.lnmPath,
    this.xplanePath,
    this.lnmInfo,
    this.xplaneInfo,
  });
}

class DatabasePathService {
  static const String lnmPathKey = 'lnm_nav_data_path';
  static const String xplanePathKey = 'xplane_nav_data_path';

  final AirportDetailService _airportService;
  final AutoDetectService _autoDetectService;

  DatabasePathService({
    AirportDetailService? airportService,
    AutoDetectService? autoDetectService,
  }) : _airportService = airportService ?? AirportDetailService(),
       _autoDetectService = autoDetectService ?? AutoDetectService();

  Future<List<Map<String, String>>> detectDatabases() {
    return _autoDetectService.detectPaths();
  }

  Future<Map<String, String>?> saveLnmPath(String path) async {
    final isValid = await _airportService.validateLnmDatabase(path);
    if (!isValid) return null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lnmPathKey, path);
    return _airportService.getDatabaseInfo(path, AirportDataSource.lnmData);
  }

  Future<Map<String, String>?> saveXPlanePath(String path) async {
    final isValid = await _airportService.validateXPlaneData(path);
    if (!isValid) return null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(xplanePathKey, path);
    return _airportService.getDatabaseInfo(path, AirportDataSource.xplaneData);
  }

  Future<DatabasePathSelectionResult> saveSelectedPaths({
    String? lnmPath,
    String? xplanePath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, String>? lnmInfo;
    Map<String, String>? xplaneInfo;

    if (lnmPath != null) {
      await prefs.setString(lnmPathKey, lnmPath);
      lnmInfo = await _airportService.getDatabaseInfo(
        lnmPath,
        AirportDataSource.lnmData,
      );
    }
    if (xplanePath != null) {
      await prefs.setString(xplanePathKey, xplanePath);
      xplaneInfo = await _airportService.getDatabaseInfo(
        xplanePath,
        AirportDataSource.xplaneData,
      );
    }

    return DatabasePathSelectionResult(
      lnmPath: lnmPath,
      xplanePath: xplanePath,
      lnmInfo: lnmInfo,
      xplaneInfo: xplaneInfo,
    );
  }
}
