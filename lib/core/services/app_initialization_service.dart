import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../modules/modules_register_entry.dart';
import '../module_registry/module_registry.dart';
import '../module_registry/navigation/navigation_item.dart';
import '../settings_pages/settings_page.dart';
import '../utils/logger.dart';
import '../localization/localization_keys.dart';
import 'bootstrap_service.dart';
import 'notification_service.dart';
import 'persistence_service.dart';
import 'localization_service.dart';

/// 应用初始化结果
sealed class AppInitResult {
  const AppInitResult();
}

/// 初始化成功
class AppInitSuccess extends AppInitResult {
  final bool isFirstLaunch;
  const AppInitSuccess({required this.isFirstLaunch});
}

/// 数据存储路径丢失，需要用户确认后重置
class AppInitPathMissing extends AppInitResult {
  final String path;
  final String? error;
  const AppInitPathMissing({required this.path, this.error});
}

/// 初始化失败
class AppInitFailure extends AppInitResult {
  final Object error;
  final StackTrace stackTrace;
  const AppInitFailure({required this.error, required this.stackTrace});
}

/// 应用初始化服务
///
/// 封装 Bootstrap → Persistence → Logger → ModuleRegistry → Notification → WindowManager
/// 的初始化编排逻辑，不依赖 BuildContext。
class AppInitializationService {
  /// 执行应用初始化流程
  Future<AppInitResult> run() async {
    try {
      // 1. 初始化引导配置（必须最先执行）
      final bootstrap = BootstrapService();
      await bootstrap.init();

      // 检查配置的数据存储路径是否存在且可访问（仅在非首次启动时检查）
      if (!bootstrap.isFirstLaunch()) {
        final configuredPath = bootstrap.getDataPath();
        if (configuredPath != null) {
          final dir = Directory(configuredPath);
          try {
            if (!await dir.exists()) {
              AppLogger.warning(
                'Storage path does not exist: $configuredPath, resetting boot flow...',
              );
              return AppInitPathMissing(path: configuredPath);
            }
          } catch (e) {
            AppLogger.error('Failed to check storage path permissions: $e');
            return AppInitPathMissing(path: configuredPath, error: '$e');
          }
        }
      }

      // 2. 初始化持久化服务
      final persistence = PersistenceService();
      final configuredPath = bootstrap.getDataPath();
      await persistence.init(customPath: configuredPath);

      // 3. 初始化日志
      await AppLogger.init();

      // 4. 初始化模块注册表
      final moduleRegistry = ModuleRegistry();
      if (!moduleRegistry.isInitialized) {
        ModulesRegisterEntry.registerAll();
        moduleRegistry.navigation.register(
          (context) => NavigationItem(
            id: 'settings',
            title: LocalizationKeys.settings.tr(context),
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            page: const SettingsPage(),
            priority: 9999,
            defaultEnabled: true,
          ),
        );
      }

      // 5. 初始化通知服务
      final notificationService = NotificationService();
      await notificationService.initialize();

      // 注册通知服务的清理回调
      moduleRegistry.registerCleanup(() async {
        AppLogger.info(
          '[Cleanup] Cleaning up notification service resources...',
        );
        await NotificationService().dispose();
      });

      // 6. 桌面端设置窗口关闭拦截
      if (!Platform.isIOS && !Platform.isAndroid) {
        await windowManager.setPreventClose(true);
      }

      return AppInitSuccess(isFirstLaunch: bootstrap.isFirstLaunch());
    } catch (e, s) {
      AppLogger.error('App Initialization failed', e, s);
      return AppInitFailure(error: e, stackTrace: s);
    }
  }

  /// 重置引导配置
  Future<void> resetBootstrap() async {
    await BootstrapService().reset();
  }
}
