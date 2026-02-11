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

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../data/airports_database.dart';
import '../airport_detail_service.dart';
import '../../../core/utils/logger.dart';
import '../../../core/services/persistence/persistence_service.dart';
import 'database_loader.dart';

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
    final settings = DatabaseSettingsService();
    final loader = DatabaseLoader();
    await settings.ensureSynced();

    // 如果设置已完成标记不存在或为 false，则需要引导
    if (!(persistence.getBool('is_setup_complete') ?? false)) {
      return true;
    }

    // 同时检查关键数据路径是否有效
    final lnmPath = await loader.resolveLnmPath();
    final aptPath = await loader.resolveXPlaneAptPath();
    if ((lnmPath == null || lnmPath.isEmpty) &&
        (aptPath == null || aptPath.isEmpty)) {
      return true;
    }

    return false;
  }

  static Future<void> preloadAirportData() async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (!AirportsDatabase.isEmpty) {
      AppLogger.debug('机场数据库已加载，跳过预加载');
      return;
    }

    try {
      // 1. 验证数据库加载状态
      final loader = DatabaseLoader();
      final loadResult = await loader.loadAndValidate();

      AppLogger.info('数据库状态:\n${loadResult.getStatusMessage()}');

      if (!loadResult.hasAnyDatabase) {
        AppLogger.error('无可用数据库，请在设置中配置数据源');
        return;
      }

      // 2. 加载机场数据
      final detailService = AirportDetailService();
      final currentDataSource = await detailService.getDataSource();

      AppLogger.info('当前数据源: ${currentDataSource.displayName}');

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
        AppLogger.info('✓ 成功预加载 ${airports.length} 个机场数据');
      } else {
        AppLogger.warning(
          '⚠ 未能预加载机场数据 (数据源: ${currentDataSource.displayName})',
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('✗ 预加载机场数据失败: $e\n$stackTrace');
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
