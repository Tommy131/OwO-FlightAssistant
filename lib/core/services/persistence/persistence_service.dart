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
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'app_storage_paths.dart';

/// 全局持久化存储服务
/// 使用 JSON 文件替代 SharedPreferences，确保存储路径在程序同目录下 (便携模式)
class PersistenceService {
  static final PersistenceService _instance = PersistenceService._internal();
  factory PersistenceService() => _instance;
  PersistenceService._internal();

  Map<String, dynamic> _data = {};
  File? _file;
  bool _initialized = false;

  /// 初始化服务
  Future<void> initialize() async {
    if (_initialized) return;

    final baseDir = await AppStoragePaths.getBaseDirectory();
    _file = File(p.join(baseDir.path, 'settings.json'));
    await _loadFromFile();

    _initialized = true;
  }

  Future<void> switchBaseDirectory(Directory baseDir) async {
    _file = File(p.join(baseDir.path, 'settings.json'));
    await _loadFromFile();
    _initialized = true;
  }

  Future<void> _loadFromFile() async {
    if (_file == null) return;
    if (await _file!.exists()) {
      try {
        final content = await _file!.readAsString();
        _data = json.decode(content);
      } catch (e) {
        debugPrint('读取持久化存储失败: $e');
        _data = {};
      }
      return;
    }
    _data = {};
  }

  /// 保存数据到文件
  Future<void> _save() async {
    if (_file == null) return;
    try {
      await _file!.writeAsString(json.encode(_data));
    } catch (e) {
      debugPrint('写入持久化存储失败: $e');
    }
  }

  // ============ Getters ============

  String? getString(String key) => _data[key] as String?;
  int? getInt(String key) => _data[key] as int?;
  double? getDouble(String key) => _data[key] as double?;
  bool? getBool(String key) => _data[key] as bool?;
  List<String>? getStringList(String key) {
    final list = _data[key] as List?;
    return list?.map((e) => e.toString()).toList();
  }

  // ============ Setters ============

  Future<void> setString(String key, String value) async {
    _data[key] = value;
    await _save();
  }

  Future<void> setInt(String key, int value) async {
    _data[key] = value;
    await _save();
  }

  Future<void> setDouble(String key, double value) async {
    _data[key] = value;
    await _save();
  }

  Future<void> setBool(String key, bool value) async {
    _data[key] = value;
    await _save();
  }

  Future<void> setStringList(String key, List<String> value) async {
    _data[key] = value;
    await _save();
  }

  Future<void> remove(String key) async {
    _data.remove(key);
    await _save();
  }

  Future<void> clear() async {
    _data.clear();
    await _save();
  }
}
