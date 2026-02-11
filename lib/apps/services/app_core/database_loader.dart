/*
 *        _____   _          __  _____   _____   _       _____   _____
 *      /  _  \ | |        / / /  _  \ |  _  \ | |     /  _  \ /  ___|
 *      | | | | | |  __   / /  | | | | | |_| | | |     | | | | | |
 *      | | | | | | /  | / /   | | | | |  _  { | |     | | | | | |   _
 *      | |_| | | |/   |/ /    | |_| | | |_| | | |___  | |_| | | |_| |
 *      \_____/ |___/|___/     \_____/ |_____/ |_____| \_____/ \_____/
 *
 *  Copyright (c) 2023 by OwOTeam-DGMT (OwOBlog).
 * @Date         : 2026-02-10
 * @Author       : HanskiJay
 * @LastEditors  : HanskiJay
 * @LastEditTime : 2026-02-10
 * @E-Mail       : support@owoblog.com
 * @Telegram     : https://t.me/HanskiJay
 * @GitHub       : https://github.com/Tommy131
 */

import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import '../../data/lnm_database_parser.dart';
import '../../data/xplane_apt_dat_parser.dart';
import '../../models/airport_detail_data.dart';
import '../../../core/utils/logger.dart';
import '../../../core/services/persistence/persistence_service.dart';

/// 数据库加载状态
enum LoadStatus {
  /// 加载成功
  success,

  /// 未配置路径
  notConfigured,

  /// 文件不存在
  fileNotFound,

  /// 数据库格式错误
  invalidFormat,

  /// 加载错误
  error,
}

class DatabaseSettingsService {
  static final DatabaseSettingsService _instance =
      DatabaseSettingsService._internal();
  factory DatabaseSettingsService() => _instance;
  DatabaseSettingsService._internal();

  static const String lnmPathKey = 'lnm_nav_data_path';
  static const String xplanePathKey = 'xplane_nav_data_path';
  static const String dataSourceKey = 'airport_data_source';
  static const String airportDbTokenKey = 'airportdb_token';
  static const String tokenThresholdKey = 'token_consumption_threshold';
  static const String tokenCountKey = 'token_consumption_count';
  static const String metarExpiryKey = 'metar_cache_expiry';
  static const String airportExpiryKey = 'airport_data_expiry';

  final PersistenceService _persistence = PersistenceService();
  bool _synced = false;

  Future<void> ensureSynced() async {
    if (_synced) return;
    final prefs = await SharedPreferences.getInstance();
    await _syncStringKey(prefs, lnmPathKey);
    await _syncStringKey(prefs, xplanePathKey);
    await _syncStringKey(prefs, dataSourceKey);
    await _syncStringKey(prefs, airportDbTokenKey);
    await _syncIntKey(prefs, tokenThresholdKey);
    await _syncIntKey(prefs, tokenCountKey);
    await _syncIntKey(prefs, metarExpiryKey);
    await _syncIntKey(prefs, airportExpiryKey);
    _synced = true;
  }

  Future<void> _syncStringKey(SharedPreferences prefs, String key) async {
    final current = _persistence.getString(key);
    if (current != null && current.isNotEmpty) return;
    final fromPrefs = prefs.getString(key);
    if (fromPrefs != null && fromPrefs.isNotEmpty) {
      await _persistence.setString(key, fromPrefs);
    }
  }

  Future<void> _syncIntKey(SharedPreferences prefs, String key) async {
    final current = _persistence.getInt(key);
    if (current != null) return;
    final fromPrefs = prefs.getInt(key);
    if (fromPrefs != null) {
      await _persistence.setInt(key, fromPrefs);
    }
  }

  Future<String?> getString(String key) async {
    await ensureSynced();
    return _persistence.getString(key);
  }

  Future<int?> getInt(String key) async {
    await ensureSynced();
    return _persistence.getInt(key);
  }

  Future<void> setString(String key, String value) async {
    await _persistence.setString(key, value);
  }

  Future<void> setInt(String key, int value) async {
    await _persistence.setInt(key, value);
  }
}

/// 数据库加载结果
class DatabaseLoadResult {
  LoadStatus lnmStatus = LoadStatus.notConfigured;
  LoadStatus xplaneStatus = LoadStatus.notConfigured;
  String? lnmPath;
  String? xplanePath;
  String? lnmError;
  String? xplaneError;

  /// 是否有任何可用的数据库
  bool get hasAnyDatabase =>
      lnmStatus == LoadStatus.success || xplaneStatus == LoadStatus.success;

  /// 是否有 LNM 数据库
  bool get hasLnmDatabase => lnmStatus == LoadStatus.success;

  /// 是否有 X-Plane 数据库
  bool get hasXPlaneDatabase => xplaneStatus == LoadStatus.success;

  /// 获取状态消息
  String getStatusMessage() {
    final messages = <String>[];

    if (lnmStatus == LoadStatus.success) {
      messages.add('✓ Little Navmap 数据库已加载');
    } else if (lnmStatus != LoadStatus.notConfigured) {
      messages.add('✗ Little Navmap: ${_getErrorMessage(lnmStatus, lnmError)}');
    }

    if (xplaneStatus == LoadStatus.success) {
      messages.add('✓ X-Plane 数据库已加载');
    } else if (xplaneStatus != LoadStatus.notConfigured) {
      messages.add('✗ X-Plane: ${_getErrorMessage(xplaneStatus, xplaneError)}');
    }

    if (messages.isEmpty) {
      messages.add('⚠ 未配置任何数据库');
    }

    return messages.join('\n');
  }

  /// 获取简短状态消息
  String getShortStatusMessage() {
    if (hasLnmDatabase && hasXPlaneDatabase) {
      return '双数据库已加载';
    } else if (hasLnmDatabase) {
      return 'Little Navmap 已加载';
    } else if (hasXPlaneDatabase) {
      return 'X-Plane 已加载';
    } else {
      return '未配置数据库';
    }
  }

  String _getErrorMessage(LoadStatus status, String? error) {
    switch (status) {
      case LoadStatus.fileNotFound:
        return '文件不存在';
      case LoadStatus.invalidFormat:
        return '数据库格式错误';
      case LoadStatus.error:
        return error ?? '未知错误';
      default:
        return '未配置';
    }
  }
}

/// 数据库加载器
/// 负责验证和加载本地数据库配置
class DatabaseLoader {
  final DatabaseSettingsService _settings;

  String? _cachedXPlaneInput;
  String? _cachedAptPath;
  String? _cachedLnmInput;
  String? _cachedLnmPath;

  DatabaseLoader({PersistenceService? persistence})
    : _settings = DatabaseSettingsService();

  /// 加载并验证所有数据库
  Future<DatabaseLoadResult> loadAndValidate() async {
    await _settings.ensureSynced();
    final result = DatabaseLoadResult();

    // 并行验证两个数据库
    await Future.wait([
      _validateLnmDatabase(result),
      _validateXPlaneDatabase(result),
    ]);

    return result;
  }

  /// 验证 Little Navmap 数据库
  Future<void> _validateLnmDatabase(DatabaseLoadResult result) async {
    final lnmPath = await resolveLnmPath();

    if (lnmPath == null || lnmPath.isEmpty) {
      result.lnmStatus = LoadStatus.notConfigured;
      AppLogger.debug('LNM 数据库路径未配置');
      return;
    }

    final file = File(lnmPath);
    if (!await file.exists()) {
      result.lnmStatus = LoadStatus.fileNotFound;
      AppLogger.error('✗ LNM 数据库文件不存在: $lnmPath');
      return;
    }

    try {
      final db = sqlite3.open(lnmPath);
      try {
        final tables = db.select(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='airport'",
        );
        if (tables.isNotEmpty) {
          result.lnmStatus = LoadStatus.success;
          result.lnmPath = lnmPath;
          AppLogger.info('✓ LNM 数据库加载成功: $lnmPath');
        } else {
          result.lnmStatus = LoadStatus.invalidFormat;
          AppLogger.error('✗ LNM 数据库格式错误: 缺少 airport 表');
        }
      } finally {
        db.dispose();
      }
    } catch (e) {
      result.lnmStatus = LoadStatus.error;
      result.lnmError = e.toString();
      AppLogger.error('✗ LNM 数据库打开失败: $e');
    }
  }

  /// 验证 X-Plane 数据库
  Future<void> _validateXPlaneDatabase(DatabaseLoadResult result) async {
    final aptPath = await resolveXPlaneAptPath();

    if (aptPath == null || aptPath.isEmpty) {
      result.xplaneStatus = LoadStatus.notConfigured;
      AppLogger.debug('X-Plane 数据路径未配置');
      return;
    }

    final file = File(aptPath);
    if (!await file.exists()) {
      result.xplaneStatus = LoadStatus.fileNotFound;
      AppLogger.error('✗ X-Plane 数据文件不存在: $aptPath');
      return;
    }

    try {
      // 验证是否为有效的 X-Plane 数据文件
      final lines = await file
          .openRead(0, 1024)
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .take(1)
          .toList();

      if (lines.isNotEmpty &&
          (lines.first.trim() == 'I' || lines.first.trim() == '1000')) {
        result.xplaneStatus = LoadStatus.success;
        result.xplanePath = aptPath;
        AppLogger.info('✓ X-Plane 数据库加载成功: $aptPath');
      } else {
        result.xplaneStatus = LoadStatus.invalidFormat;
        AppLogger.error('✗ X-Plane 数据文件格式错误');
      }
    } catch (e) {
      result.xplaneStatus = LoadStatus.error;
      result.xplaneError = e.toString();
      AppLogger.error('✗ X-Plane 数据文件读取失败: $e');
    }
  }

  /// 验证单个 LNM 数据库路径
  Future<bool> validateLnmPath(String path) async {
    if (path.isEmpty) return false;

    final resolvedPath = await resolveLnmPath(path);
    if (resolvedPath == null) return false;
    final file = File(resolvedPath);
    if (!await file.exists()) return false;

    try {
      final db = sqlite3.open(resolvedPath);
      try {
        final tables = db.select(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='airport'",
        );
        return tables.isNotEmpty;
      } finally {
        db.dispose();
      }
    } catch (e) {
      AppLogger.error('验证 LNM 数据库失败: $e');
      return false;
    }
  }

  /// 验证单个 X-Plane 数据路径
  Future<bool> validateXPlanePath(String path) async {
    if (path.isEmpty) return false;

    try {
      final aptPath = await resolveXPlaneAptPath(path);
      if (aptPath == null) return false;
      final file = File(aptPath);
      if (!await file.exists()) return false;

      final lines = await file
          .openRead(0, 1024)
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .take(1)
          .toList();

      return lines.isNotEmpty &&
          (lines.first.trim() == 'I' || lines.first.trim() == '1000');
    } catch (e) {
      AppLogger.error('验证 X-Plane 数据文件失败: $e');
      return false;
    }
  }

  Future<String?> resolveLnmPath([String? inputPath]) async {
    await _settings.ensureSynced();
    final raw =
        inputPath ??
        await _settings.getString(DatabaseSettingsService.lnmPathKey);
    if (raw == null || raw.isEmpty) return null;
    if (raw == _cachedLnmInput && _cachedLnmPath != null) {
      return _cachedLnmPath;
    }

    final type = await FileSystemEntity.type(raw);
    if (type == FileSystemEntityType.file) {
      _cachedLnmInput = raw;
      _cachedLnmPath = raw;
      return raw;
    }

    if (type == FileSystemEntityType.directory) {
      final dir = Directory(raw);
      if (!await dir.exists()) return null;
      final files = await dir.list().toList();
      final candidates = files.whereType<File>().where(
        (file) => file.path.toLowerCase().endsWith('.sqlite'),
      );
      File? target = candidates.firstWhere(
        (file) =>
            file.path.toLowerCase().contains('navdata') ||
            file.path.toLowerCase().contains('navigraph'),
        orElse: () => candidates.isNotEmpty ? candidates.first : File(''),
      );
      if (target.path.isEmpty) return null;
      _cachedLnmInput = raw;
      _cachedLnmPath = target.path;
      return target.path;
    }

    return null;
  }

  Future<String?> resolveXPlaneAptPath([String? inputPath]) async {
    await _settings.ensureSynced();
    final raw =
        inputPath ??
        await _settings.getString(DatabaseSettingsService.xplanePathKey);
    if (raw == null || raw.isEmpty) return null;
    if (raw == _cachedXPlaneInput && _cachedAptPath != null) {
      return _cachedAptPath;
    }
    final aptPath = await XPlaneAptDatParser.resolveAptDatPath(raw);
    if (aptPath == null) return null;
    _cachedXPlaneInput = raw;
    _cachedAptPath = aptPath;
    return aptPath;
  }

  Future<List<Map<String, dynamic>>> loadAllAirports(
    AirportDataSourceType source,
  ) async {
    if (source == AirportDataSourceType.lnmData) {
      final lnmPath = await resolveLnmPath();
      if (lnmPath != null) {
        final file = File(lnmPath);
        if (await file.exists()) {
          try {
            AppLogger.info('读取 LNM 机场数据库: $lnmPath');
            final airports = await LNMDatabaseParser.getAllAirports(file);
            if (airports.isNotEmpty) {
              AppLogger.info('LNM 机场数据库加载完成: ${airports.length} 条');
              return airports;
            }
          } catch (e) {
            AppLogger.error('Error loading airports from LNM: $e');
          }
        } else {
          AppLogger.error('LNM 数据库文件不存在: $lnmPath');
        }
      } else {
        AppLogger.warning('LNM 数据路径未配置');
      }
    }

    if (source == AirportDataSourceType.xplaneData) {
      final aptPath = await resolveXPlaneAptPath();
      if (aptPath != null) {
        final file = File(aptPath);
        if (await file.exists()) {
          try {
            AppLogger.info('读取 X-Plane 机场数据库: $aptPath');
            final airports = await XPlaneAptDatParser.getAllAirports(file);
            if (airports.isNotEmpty) {
              AppLogger.info('X-Plane 机场数据库加载完成: ${airports.length} 条');
              return airports;
            }
          } catch (e) {
            AppLogger.error('Error loading airports from X-Plane: $e');
          }
        } else {
          AppLogger.error('X-Plane apt.dat 文件不存在: $aptPath');
        }
      } else {
        AppLogger.warning('X-Plane 数据路径未配置');
      }
    }

    return [];
  }
}
