import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/utils/logger.dart';
import 'core/services/persistence/persistence_service.dart';
import 'apps/services/app_core/app_initializer.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    // 初始化地图内置缓存配置
    AppInitializer.initializeMapCache();

    // 首先初始化持久化存储服务
    await PersistenceService().initialize();

    // 初始化日志和窗口管理
    await AppLogger.initialize();
    AppLogger.info('Application started');
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(450, 350),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    // 启动应用程序实例
    runApp(const MyApp());
  } catch (e, stackTrace) {
    AppLogger.error('Start application failed!', e, stackTrace);
  }
}
