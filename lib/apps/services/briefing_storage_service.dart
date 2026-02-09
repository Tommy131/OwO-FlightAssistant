import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flight_briefing.dart';
import '../../core/utils/logger.dart';

/// 简报持久化存储服务
class BriefingStorageService {
  static const String _storageKey = 'flight_briefings_history';
  static const int _maxHistoryCount = 50; // 最多保存50条历史记录

  /// 保存简报历史记录
  Future<bool> saveBriefings(List<FlightBriefing> briefings) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 限制保存数量
      final briefingsToSave = briefings.take(_maxHistoryCount).toList();

      // 转换为JSON
      final jsonList = briefingsToSave.map((b) => b.toJson()).toList();
      final jsonString = jsonEncode(jsonList);

      // 保存到本地
      final success = await prefs.setString(_storageKey, jsonString);

      if (success) {
        AppLogger.info('成功保存 ${briefingsToSave.length} 条简报记录');
      }

      return success;
    } catch (e, stackTrace) {
      AppLogger.error('保存简报失败', e, stackTrace);
      return false;
    }
  }

  /// 加载简报历史记录
  Future<List<FlightBriefing>> loadBriefings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString == null || jsonString.isEmpty) {
        AppLogger.info('没有找到保存的简报记录');
        return [];
      }

      // 解析JSON
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      final briefings = jsonList
          .map((json) => FlightBriefing.fromJson(json as Map<String, dynamic>))
          .toList();

      AppLogger.info('成功加载 ${briefings.length} 条简报记录');
      return briefings;
    } catch (e, stackTrace) {
      AppLogger.error('加载简报失败', e, stackTrace);
      return [];
    }
  }

  /// 清除所有简报记录
  Future<bool> clearBriefings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.remove(_storageKey);

      if (success) {
        AppLogger.info('成功清除所有简报记录');
      }

      return success;
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
}
