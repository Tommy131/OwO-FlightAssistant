import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'settings_pages/settings_page.dart';
import 'theme/theme_provider.dart';
import 'constants/app_constants.dart';
import 'module_registry/navigation/navigation_item.dart';
import 'services/back_handler_service.dart';
import 'services/notification_service.dart';
import 'utils/logger.dart';
import 'utils/update_checker.dart';
import 'layouts/desktop_layout.dart';
import 'layouts/mobile_layout.dart';
import 'layouts/responsive.dart';
import 'widgets/common/dialog.dart';
import 'widgets/common/snack_bar.dart';
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
  DateTime? _lastPopTime;

  @override
  void initState() {
    super.initState();

    if (!Platform.isIOS && !Platform.isAndroid) {
      windowManager.addListener(this);
    }

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
              AppLogger.warning(
                'Storage path does not exist: $configuredPath, resetting boot flow...',
              );
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
            AppLogger.error('Failed to check storage path permissions: $e');
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

      // 6. 初始化通知服务
      final notificationService = NotificationService();
      await notificationService.initialize();

      if (!Platform.isIOS && !Platform.isAndroid) {
        // Add this line to override the default close handler
        await windowManager.setPreventClose(true);
      }

      // 模拟加载核心资源和数据（仅用于演示高级加载效果）
      // AppLogger.info('Simulating loading business data (5s)...');
      // await Future.delayed(const Duration(seconds: 5));
      // AppLogger.info('Business data loading completed');

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
      AppLogger.info('Starting app cleanup...');

      // 执行模块化注册的清理回调
      await ModuleRegistry().performCleanup();

      // 清理通知服务
      ModuleRegistry().registerCleanup(() async {
        AppLogger.info(
          '[Cleanup] Cleaning up notification service resources...',
        );
        await NotificationService().dispose();
      });

      AppLogger.info('App cleanup completed.');
    } catch (e) {
      AppLogger.error('Error during cleanup: $e');
    }
  }

  @override
  void dispose() {
    NavigationCommandBus().targetId.removeListener(
      _handleNavigationCommandChanged,
    );

    if (!Platform.isIOS && !Platform.isAndroid) {
      windowManager.removeListener(this);
    }
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

  /// 处理 Android 物理返回键
  void _handlePopInvoked(bool didPop, dynamic result) {
    if (didPop) return;

    // 优先执行模块注册的自定义返回回调
    if (BackHandlerService().handleBack()) {
      return;
    }

    // 如果 Navigator 还有可以返回的页面，则执行 Navigator 的 pop
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    // 如果在初始化引导模式下，直接进入退出提示逻辑
    if (_isSetupMode) {
      _showExitPrompt();
      return;
    }

    // 如果当前不在首页（第一个 Tab），则返回到首页
    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });
      return;
    }

    // 如果已经在首页，则提示再次操作以退出
    _showExitPrompt();
  }

  /// 显示“再次操作以退出”提示或执行退出
  void _showExitPrompt() {
    final now = DateTime.now();
    if (_lastPopTime == null ||
        now.difference(_lastPopTime!) > const Duration(seconds: 2)) {
      _lastPopTime = now;
      if (mounted) {
        SnackBarHelper.showInfo(
          context,
          LocalizationKeys.doubleBackExit.tr(context),
        );
      }
      return;
    }

    // 连续两次触发，退出程序
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else {
      exit(0);
    }
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

      Widget loadingScaffold = Scaffold(
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
      );

      // 针对 Android 设备在加载界面也提供返回键退出逻辑
      if (Platform.isAndroid || Platform.isIOS) {
        loadingScaffold = PopScope(
          canPop: false,
          onPopInvokedWithResult: _handlePopInvoked,
          child: loadingScaffold,
        );
      }

      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: loadingScaffold,
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
      child = MultiProvider(providers: moduleProviders, child: child);
    }

    // 针对 Android 设备增强返回键处理
    if (Platform.isAndroid || Platform.isIOS) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: _handlePopInvoked,
        child: child,
      );
    }

    return child;
  }

  @override
  void onWindowClose() async {
    if (!!Platform.isIOS && !Platform.isAndroid) {
      return;
    }
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
