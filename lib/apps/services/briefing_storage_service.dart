import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flight_briefing.dart';
import '../../core/utils/logger.dart';
import '../../core/services/persistence/app_storage_paths.dart';

/// 简报持久化存储服务
class BriefingStorageService {
  static const String _storageKey = 'flight_briefings_history';
  static const int _maxHistoryCount = 50; // 最多保存50条历史记录
  static const String _briefingsFileName = 'briefings.json';

  Future<File> _getBriefingsFile() async {
    final dir = await AppStoragePaths.getBriefingDirectory();
    return File(p.join(dir.path, _briefingsFileName));
  }

  /// 保存简报历史记录
  Future<bool> saveBriefings(List<FlightBriefing> briefings) async {
    try {
      // 限制保存数量
      final briefingsToSave = briefings.take(_maxHistoryCount).toList();

      // 转换为JSON
      final jsonList = briefingsToSave.map((b) => b.toJson()).toList();
      final jsonString = jsonEncode(jsonList);

      final file = await _getBriefingsFile();
      await file.writeAsString(jsonString);
      AppLogger.info('成功保存 ${briefingsToSave.length} 条简报记录');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('保存简报失败', e, stackTrace);
      return false;
    }
  }

  /// 加载简报历史记录
  Future<List<FlightBriefing>> loadBriefings() async {
    try {
      final file = await _getBriefingsFile();
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        if (jsonString.trim().isEmpty) {
          AppLogger.info('没有找到保存的简报记录');
          return [];
        }
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        final briefings = jsonList
            .map(
              (json) => FlightBriefing.fromJson(json as Map<String, dynamic>),
            )
            .toList();
        AppLogger.info('成功加载 ${briefings.length} 条简报记录');
        return briefings;
      }

      return await _migrateFromPreferences();
    } catch (e, stackTrace) {
      AppLogger.error('加载简报失败', e, stackTrace);
      return [];
    }
  }

  /// 清除所有简报记录
  Future<bool> clearBriefings() async {
    try {
      final file = await _getBriefingsFile();
      if (await file.exists()) {
        await file.delete();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      AppLogger.info('成功清除所有简报记录');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('清除简报失败', e, stackTrace);
      return false;
    }
  }

  /// 获取存储的简报数量
  Future<int> getBriefingCount() async {
    try {
      final briefings = await loadBriefings();
      return briefings.length;
    } catch (e) {
      return 0;
    }
  }

  Future<List<FlightBriefing>> _migrateFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString == null || jsonString.isEmpty) {
        AppLogger.info('没有找到保存的简报记录');
        return [];
      }
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      final briefings = jsonList
          .map((json) => FlightBriefing.fromJson(json as Map<String, dynamic>))
          .toList();
      await saveBriefings(briefings);
      await prefs.remove(_storageKey);
      AppLogger.info('简报历史已迁移到独立存储路径');
      return briefings;
    } catch (e, stackTrace) {
      AppLogger.error('迁移简报失败', e, stackTrace);
      return [];
    }
  }
}
