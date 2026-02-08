import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../data/airports_database.dart';
import 'airport_detail_service.dart';
import '../../core/utils/logger.dart';

class AppInitializer {
  static Future<bool> checkSetupNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final lnmPath = prefs.getString('lnm_nav_data_path');
    if (lnmPath == null || lnmPath.isEmpty || !await File(lnmPath).exists()) {
      return true;
    }
    return false;
  }

  static Future<void> preloadAirportData() async {
    // 延迟一小段时间，确保 SplashScreen 能够被用户看见
    await Future.delayed(const Duration(milliseconds: 800));

    // 如果数据库已经有数据，不需要重复加载
    if (!AirportsDatabase.isEmpty) {
      return;
    }

    try {
      final detailService = AirportDetailService();
      final currentDataSource = await detailService.getDataSource();

      // 异步加载机场列表，不阻塞 UI 线程
      final airports = await detailService.loadAllAirports(
        source: currentDataSource,
      );

      if (airports.isNotEmpty) {
        AirportsDatabase.updateAirports(
          airports.map((a) {
            return AirportInfo(
              icaoCode: a['icao'] ?? '',
              iataCode: a['iata'] ?? '',
              nameChinese: a['name'] ?? '',
              latitude: (a['lat'] as num?)?.toDouble() ?? 0.0,
              longitude: (a['lon'] as num?)?.toDouble() ?? 0.0,
            );
          }).toList(),
        );
        AppLogger.info('App 启动: 成功预加载 ${airports.length} 个机场数据');
      } else {
        AppLogger.warning(
          'App 启动: 未能预加载机场数据 (数据源: ${currentDataSource.displayName})',
        );
      }
    } catch (e) {
      AppLogger.error('App 启动: 预加载机场数据失败: $e');
    }
  }

  static Future<void> setupWindow() async {
    await windowManager.setSize(const Size(1266, 800));
    await windowManager.setMinimumSize(const Size(816, 600));
    await windowManager.center();
  }
}
