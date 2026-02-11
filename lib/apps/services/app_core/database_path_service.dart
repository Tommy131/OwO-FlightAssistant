/*
 *        _____   _          __  _____   _____   _       _____   _____
 *      /  _  \ | |        / / /  _  \ |  _  \ | |     /  _  \ /  ___|
 *      | | | | | |  __   / /  | | | | | |_| | | |     | | | | | |
 *      | | | | | | /  | / /   | | | | |  _  { | |     | | | | | |   _
 *      | |_| | | |/   |/ /    | |_| | | |_| | | |___  | |_| | | |_| |
 *      \_____/ |___/|___/     \_____/ |_____/ |_____| \_____/ \_____/
 *
 *  Copyright (c) 2023 by OwOTeam-DGMT (OwOBlog).
 * @Date         : 2025-10-22
 * @Author       : HanskiJay
 * @LastEditors  : HanskiJay
 * @LastEditTime : 2025-10-22
 * @E-Mail       : support@owoblog.com
 * @Telegram     : https://t.me/HanskiJay
 * @GitHub       : https://github.com/Tommy131
 */

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../airport_detail_service.dart';
import 'auto_detect_service.dart';
import 'database_loader.dart';

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
  static const String _airportDbTokenKey = 'airportdb_token';
  static const String _tokenCountKey = 'token_consumption_count';
  static const String _aviationApiBase = 'https://airportdb.io/api/v1/airport';

  final AutoDetectService _autoDetectService;
  final DatabaseSettingsService _settings = DatabaseSettingsService();

  DatabasePathService({AutoDetectService? autoDetectService})
    : _autoDetectService = autoDetectService ?? AutoDetectService();

  Future<List<Map<String, String>>> detectDatabases() {
    return _autoDetectService.detectPaths();
  }

  Future<Map<String, String>> getDatabaseInfo(
    String path,
    AirportDataSource source,
  ) {
    return _autoDetectService.getDatabaseInfo(path, source);
  }

  Future<bool> validateLnmDatabase(String path) {
    return _autoDetectService.validateLnmDatabase(path);
  }

  Future<bool> validateXPlaneData(String path) {
    return _autoDetectService.validateXPlaneData(path);
  }

  Future<Map<String, String>?> saveLnmPath(String path) async {
    final isValid = await validateLnmDatabase(path);
    if (!isValid) return null;
    await _settings.setString(lnmPathKey, path);
    return getDatabaseInfo(path, AirportDataSource.lnmData);
  }

  Future<Map<String, String>?> saveXPlanePath(String path) async {
    final isValid = await validateXPlaneData(path);
    if (!isValid) return null;
    await _settings.setString(xplanePathKey, path);
    return getDatabaseInfo(path, AirportDataSource.xplaneData);
  }

  Future<DatabasePathSelectionResult> saveSelectedPaths({
    String? lnmPath,
    String? xplanePath,
  }) async {
    Map<String, String>? lnmInfo;
    Map<String, String>? xplaneInfo;

    if (lnmPath != null) {
      await _settings.setString(lnmPathKey, lnmPath);
      lnmInfo = await getDatabaseInfo(lnmPath, AirportDataSource.lnmData);
    }
    if (xplanePath != null) {
      await _settings.setString(xplanePathKey, xplanePath);
      xplaneInfo = await getDatabaseInfo(
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

  Future<bool> validateToken(String token) async {
    if (token.isEmpty) return false;
    try {
      final url = '$_aviationApiBase/ZSSS?apiToken=$token';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['error'] == null;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> resetTokenCount() async {
    await _settings.setInt(_tokenCountKey, 0);
  }

  Future<void> clearMetarCache() async {
    // Note: PersistenceService doesn't support getKeys yet, so we clear the whole settings
    // or we might need to implement a clear prefixed keys method.
    // For now, Metar cache is not critical for the Setup Wizard.
  }

  Future<void> saveToken(String token) async {
    await _settings.setString(_airportDbTokenKey, token);
  }
}
