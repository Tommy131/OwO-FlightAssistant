import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'settings_pages/settings_page.dart';
import 'theme/theme_provider.dart';
import 'constants/app_constants.dart';
import 'module_registry/navigation/navigation_item.dart';
import 'services/notification_service.dart';
import 'utils/logger.dart';
import 'utils/update_checker.dart';
import 'layouts/desktop_layout.dart';
import 'layouts/mobile_layout.dart';
import 'layouts/responsive.dart';
import 'widgets/common/dialog.dart';
import 'widgets/desktop/custom_title_bar.dart';
import 'module_registry/sidebar/sidebar_footer.dart';
import 'module_registry/sidebar/sidebar_footer_registry.dart';

import '../modules/modules_register_entry.dart';

import 'services/persistence_service.dart';
import 'services/bootstrap_service.dart';
import 'services/localization_service.dart';
import 'localization/localization_keys.dart';
import 'setup_wizard/setup_wizard.dart';

import 'module_registry/module_registry.dart';
import 'module_registry/navigation/navigation_registry.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocalizationService()),
      ],
      child: Consumer2<ThemeProvider, LocalizationService>(
        builder: (context, themeProvider, localizationService, child) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            locale: localizationService.currentLocale,
            theme: themeProvider.currentTheme.generateLightTheme(
              adjustment: themeProvider.lightContrastAdjustment,
            ),
            darkTheme: themeProvider.currentTheme.generateDarkTheme(
              adjustment: themeProvider.darkContrastAdjustment,
            ),
            themeMode: themeProvider.themeMode,
            home: const MainScreen(),
          );
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  /// 注册导航页面自定义注册方法
  /// 允许用户在 modules 自定义注册导航页面
  static void registerNavigation(
    NavigationItem Function(BuildContext) factory,
  ) {
    NavigationRegistry().register(factory);
  }

  /// 注册侧边栏页脚自定义注册方法
  static void registerSidebarFooter(SidebarFooter Function() factory) {
    SidebarFooterRegistry().register(factory.call().id, factory);
  }

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WindowListener {
  bool _isSetupMode = true;
  bool _isInitialized = false;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    NavigationCommandBus().targetId.addListener(
      _handleNavigationCommandChanged,
    );

    _initializeApp();
  }

  /// 初始化应用程序入口
  ///
  /// 在应用启动时调用此函数以初始化应用程序
  Future<void> _initializeApp() async {
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
              AppLogger.warning('存储路径不存在: $configuredPath，准备重置引导流程...');
              if (mounted) {
                await showAdvancedConfirmDialog(
                  context: context,
                  title: LocalizationKeys.dataPathMissingTitle.tr(context),
                  content: LocalizationKeys.dataPathMissingContent.tr(context),
                  confirmText: LocalizationKeys.confirm.tr(context),
                  cancelText: '', // 隐藏取消按钮，强制点击确认
                  icon: Icons.error_outline,
                  confirmColor: Colors.redAccent,
                );
              }
              await bootstrap.reset(); // 删除 bootstrap.json 并重置
            }
          } catch (e) {
            AppLogger.error('检查存储路径访问权限失败: $e');
            if (mounted) {
              await showAdvancedConfirmDialog(
                context: context,
                title: LocalizationKeys.dataPathMissingTitle.tr(context),
                content:
                    '${LocalizationKeys.dataPathMissingContent.tr(context)}\n\nError: $e',
                confirmText: LocalizationKeys.confirm.tr(context),
                cancelText: '',
                icon: Icons.error_outline,
                confirmColor: Colors.redAccent,
              );
            }
            await bootstrap.reset();
          }
        }
      }

      // 2. 初始化持久化服务
      final persistence = PersistenceService();
      final configuredPath = bootstrap.getDataPath();
      await persistence.init(customPath: configuredPath);

      // 3. 触发 Provider 重新加载已保存的设置
      if (mounted) {
        context.read<ThemeProvider>().load();
        await LocalizationService().init();
      }

      await AppLogger.init();

      // 4. 初始化所有业务模块（通过统一入口）
      ModulesRegisterEntry.registerAll();

      // 5. 注册核心基础导航项 (如：设置)
      ModuleRegistry().navigation.register(
        (context) => NavigationItem(
          id: 'settings',
          title: LocalizationKeys.settings.tr(context),
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings,
          page: const SettingsPage(),
          priority: 9999, // 设置页面通常放在最后
        ),
      );

      // 6. 初始化通知服务
      final notificationService = NotificationService();
      await notificationService.initialize();

      // Add this line to override the default close handler
      await windowManager.setPreventClose(true);

      // 模拟加载核心资源和数据（仅用于演示高级加载效果）
      // AppLogger.info('正在模拟加载业务数据 (5s)...');
      // await Future.delayed(const Duration(seconds: 5));
      // AppLogger.info('业务数据加载完成');

      if (mounted) {
        setState(() {
          _isSetupMode = bootstrap.isFirstLaunch();
          _isInitialized = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _consumeNavigationCommand();
        });

        if (!_isSetupMode) {
          // 应用启动后自动检查更新
          // 延迟执行，确保UI已完全加载
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              UpdateChecker.checkAndShowUpdate(
                context,
                showLoadingSnackBar: false, // 自动检测时不显示"正在检查"提示
                showNoUpdateSnackBar: false, // 自动检测时没有更新不提示
              );
            }
          });
        }
      }
    } catch (e, s) {
      AppLogger.error('App Initialization failed', e, s);
      // Fallback or show error? For now proceed to allow retry or debug
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  /// 集中处理关闭前的清理工作
  Future<void> _handleAppCleanup() async {
    try {
      // 在这里集中处理所有需要最后保存或清理的操作
      AppLogger.info('开始执行应用清理操作...');

      // 执行模块化注册的清理回调
      await ModuleRegistry().performCleanup();

      // 清理通知服务
      ModuleRegistry().registerCleanup(() async {
        AppLogger.info('[Cleanup] 正在清理通知服务资源...');
        await NotificationService().dispose();
      });

      AppLogger.info('应用清理完成。');
    } catch (e) {
      AppLogger.error('清理过程中出错: $e');
    }
  }

  @override
  void dispose() {
    NavigationCommandBus().targetId.removeListener(
      _handleNavigationCommandChanged,
    );
    windowManager.removeListener(this);
    super.dispose();
  }

  void _handleNavigationCommandChanged() {
    _consumeNavigationCommand();
  }

  void _consumeNavigationCommand() {
    final targetId = NavigationCommandBus().targetId.value;
    if (targetId == null || targetId.isEmpty || !_isInitialized || !mounted) {
      return;
    }
    final elements = NavigationRegistry().getNavigationElements(context);
    final List<NavigationItem> flatItems = [];
    for (final element in elements) {
      if (element.isGroup) {
        flatItems.addAll(element.children);
      } else if (element.item != null) {
        flatItems.add(element.item!);
      }
    }

    final targetIndex = flatItems.indexWhere((item) => item.id == targetId);
    NavigationCommandBus().clear();
    if (targetIndex < 0 || targetIndex == _selectedIndex) {
      return;
    }
    setState(() {
      _selectedIndex = targetIndex;
    });
  }

  void _onNavigationChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void onWindowFocus() {
    // Make sure to call once.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      final themeProvider = context.watch<ThemeProvider>();
      final isDark =
          themeProvider.themeMode == ThemeMode.dark ||
          (themeProvider.themeMode == ThemeMode.system &&
              View.of(context).platformDispatcher.platformBrightness ==
                  Brightness.dark);

      // 如果尚未初始化完成，默认使用深色模式配色以获得更好的视觉体验
      final theme = isDark
          ? themeProvider.currentTheme.generateDarkTheme(
              adjustment: themeProvider.darkContrastAdjustment,
            )
          : themeProvider.currentTheme.generateLightTheme(
              adjustment: themeProvider.lightContrastAdjustment,
            );

      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF121212)
              : theme.scaffoldBackgroundColor,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo with subtle glow
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      AppConstants.assetIconPath,
                      width: 100,
                      height: 100,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.apps, size: 80, color: theme.primaryColor),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // App Name with professional styling
                Text(
                  AppConstants.appName,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontFamily: 'MicrosoftYaHei',
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 48),
                // Premium Progress Indicator
                SizedBox(
                  width: 240,
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          backgroundColor: theme.primaryColor.withValues(
                            alpha: 0.1,
                          ),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        LocalizationKeys.loading.tr(context),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: (isDark ? Colors.white70 : Colors.black54)
                              .withValues(alpha: 0.8),
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    context.watch<LocalizationService>();
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    // 从注册表获取所有导航项
    final elements = NavigationRegistry().getNavigationElements(context);

    // 扁平化所有项目，用于索引匹配和页面切换
    final List<NavigationItem> flatItems = [];
    for (final element in elements) {
      if (element.isGroup) {
        flatItems.addAll(element.children);
      } else if (element.item != null) {
        flatItems.add(element.item!);
      }
    }

    final moduleProviders = ModuleRegistry().providers.getAll();

    Widget child = _isSetupMode
        ? SetupWizard(
            key: ValueKey(_isSetupMode),
            onCompleted: () async {
              await _initializeApp();
              setState(() => _isSetupMode = false);
            },
          )
        : Column(
            children: [
              if (!Platform.isAndroid && !Platform.isIOS) ...[
                CustomTitleBar(
                  title: Text(
                    AppConstants.appName,
                    style: const TextStyle(fontFamily: 'MicrosoftYaHei'),
                  ),
                ),
                Divider(
                  height: 1,
                  color: Color(isDark ? 0xFF313131 : 0xFFD6D6D6),
                ),
              ],
              Expanded(
                child: Responsive(
                  // 移动端布局
                  mobile: MobileLayout(
                    navigationItems: flatItems,
                    selectedIndex: _selectedIndex,
                    onNavigationChanged: _onNavigationChanged,
                  ),
                  // 桌面端布局
                  desktop: DesktopLayout(
                    navigationElements: elements,
                    selectedIndex: _selectedIndex,
                    onNavigationChanged: _onNavigationChanged,
                  ),
                ),
              ),
            ],
          );

    if (moduleProviders.isNotEmpty) {
      return MultiProvider(providers: moduleProviders, child: child);
    }

    return child;
  }

  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose && mounted) {
      final result = await showAdvancedConfirmDialog(
        context: context,
        title: LocalizationKeys.confirmExitTitle.tr(context),
        content: LocalizationKeys.confirmExitContent.tr(context),
        icon: Icons.warning_amber_rounded,
        confirmColor: Colors.redAccent,
        confirmText: LocalizationKeys.confirm.tr(context),
        cancelText: LocalizationKeys.cancel.tr(context),
      );

      if (result == true && mounted) {
        showLoadingDialog(
          context: context,
          style: ConfirmDialogStyle.material,
          title: LocalizationKeys.savingAndExiting.tr(context),
          content: '',
        );

        // 延迟一小段时间让弹窗显示出来
        await Future.delayed(const Duration(milliseconds: 300));

        // 执行清理操作
        await _handleAppCleanup();

        // 销毁窗口
        await windowManager.setPreventClose(false);
        await windowManager.close();
      }
    }
  }
}
