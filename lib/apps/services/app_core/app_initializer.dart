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
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../data/airports_database.dart';
import '../airport_detail_service.dart';
import '../../../core/utils/logger.dart';
import '../../../core/services/persistence/persistence_service.dart';

class AppInitializer {
  /// 初始化地图缓存，设置默认过期时间以消除警告
  static void initializeMapCache() {
    BuiltInMapCachingProvider.getOrCreateInstance(
      overrideFreshAge: const Duration(days: 7), // 强制缓存刷新周期为 7 天
    );
  }

  /// 检查是否需要显示启动引导
  static Future<bool> checkSetupNeeded() async {
    final persistence = PersistenceService();

    // 如果设置已完成标记不存在或为 false，则需要引导
    if (!(persistence.getBool('is_setup_complete') ?? false)) {
      return true;
    }

    // 同时检查关键数据路径是否有效
    final lnmPath = persistence.getString('lnm_nav_data_path');
    if (lnmPath == null || lnmPath.isEmpty || !await File(lnmPath).exists()) {
      return true;
    }

    return false;
  }

  static Future<void> preloadAirportData() async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (!AirportsDatabase.isEmpty) {
      return;
    }

    try {
      final detailService = AirportDetailService();
      final currentDataSource = await detailService.getDataSource();

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
    await windowManager.show();
    await windowManager.focus();
  }
}
