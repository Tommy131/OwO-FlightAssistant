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

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class AppStoragePaths {
  static bool? _isPortableMode;
  static const String _customBaseDirKey = 'custom_base_dir';

  /// 检查是否为便携模式（数据存储在程序目录下）
  static Future<bool> isPortableMode() async {
    if (_isPortableMode != null) return _isPortableMode!;
    final customPath = await _getCustomBaseDirPath();
    if (customPath != null && customPath.isNotEmpty) {
      _isPortableMode = false;
      return _isPortableMode!;
    }
    final portableDir = await _getPortableDirectory();
    _isPortableMode = await portableDir.exists();
    return _isPortableMode!;
  }

  static Future<String?> _getCustomBaseDirPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customBaseDirKey);
  }

  static Future<void> setCustomBaseDirectory(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null || path.trim().isEmpty) {
      await prefs.remove(_customBaseDirKey);
    } else {
      await prefs.setString(_customBaseDirKey, path.trim());
    }
    _isPortableMode = null;
  }

  /// 获取便携模式下的根目录
  static Future<Directory> _getPortableDirectory() async {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    return Directory(p.join(exeDir, 'data'));
  }

  /// 获取基础数据存储目录
  static Future<Directory> getBaseDirectory() async {
    final customPath = await _getCustomBaseDirPath();
    if (customPath != null && customPath.isNotEmpty) {
      final customDir = Directory(customPath);
      if (!await customDir.exists()) {
        await customDir.create(recursive: true);
      }
      return customDir;
    }

    final portableDir = await _getPortableDirectory();
    if (await portableDir.exists()) {
      return portableDir;
    }

    final exeDir = p.dirname(Platform.resolvedExecutable);
    return Directory(exeDir);
  }

  static Future<void> migrateBaseDirectory(
    Directory source,
    Directory target,
  ) async {
    if (p.equals(source.path, target.path)) return;
    if (!await source.exists()) return;
    if (!await target.exists()) {
      await target.create(recursive: true);
    }

    await for (final entity in source.list(recursive: true)) {
      final relative = p.relative(entity.path, from: source.path);
      final targetPath = p.join(target.path, relative);
      if (entity is File) {
        await File(targetPath).parent.create(recursive: true);
        await entity.copy(targetPath);
      } else if (entity is Directory) {
        await Directory(targetPath).create(recursive: true);
      }
    }
  }

  static Future<Directory> getLogDirectory() async {
    final baseDir = await getBaseDirectory();
    final logDir = Directory(p.join(baseDir.path, 'logs'));
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    return logDir;
  }

  static Future<Directory> getFlightLogDirectory() async {
    final baseDir = await getBaseDirectory();
    final flightDir = Directory(p.join(baseDir.path, 'flight_logs'));
    if (!await flightDir.exists()) {
      await flightDir.create(recursive: true);
    }
    return flightDir;
  }

  static Future<Directory> getBriefingDirectory() async {
    final baseDir = await getBaseDirectory();
    final briefingDir = Directory(p.join(baseDir.path, 'flight_briefings'));
    if (!await briefingDir.exists()) {
      await briefingDir.create(recursive: true);
    }
    return briefingDir;
  }
}
