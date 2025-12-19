import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/utils/logger.dart';

void main() async {
  try {
    AppLogger.info('Application started');
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1266, 800),
      minimumSize: Size(816, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
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
