import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'theme/theme_provider.dart';
import 'constants/app_constants.dart';
import 'module_registry/navigation/navigation_item.dart';
import 'services/back_handler_service.dart';
import 'utils/logger.dart';
import 'utils/update_checker.dart';
import 'layouts/desktop_layout.dart';
import 'layouts/mobile_layout.dart';
import 'layouts/responsive.dart';
import 'widgets/common/dialog.dart';
import 'widgets/common/snack_bar.dart';
import 'widgets/desktop/custom_title_bar.dart';
import 'widgets/loading_screen.dart';
import 'module_registry/sidebar/sidebar_footer.dart';
import 'module_registry/sidebar/sidebar_footer_registry.dart';

import 'services/app_initialization_service.dart';
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
  Future<void> _initializeApp() async {
    final result = await AppInitializationService().run();
    if (!mounted) return;

    switch (result) {
      case AppInitPathMissing(:final path, :final error):
        await _showPathMissingDialog(path, error);
        await AppInitializationService().resetBootstrap();
        return _initializeApp();

      case AppInitSuccess(:final isFirstLaunch):
        context.read<ThemeProvider>().load();
        await LocalizationService().init();
        setState(() {
          _isSetupMode = isFirstLaunch;
          _isInitialized = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _consumeNavigationCommand();
        });
        if (!isFirstLaunch) {
          _scheduleUpdateCheck();
        }

      case AppInitFailure():
        setState(() {
          _isInitialized = true;
        });
    }
  }

  /// 显示数据路径丢失对话框
  Future<void> _showPathMissingDialog(String path, String? error) async {
    final errorSuffix = error != null ? '\n\nError: $error' : '';
    await showAdvancedConfirmDialog(
      context: context,
      title: LocalizationKeys.dataPathMissingTitle.tr(context),
      content:
          '${LocalizationKeys.dataPathMissingContent.tr(context)}$errorSuffix',
      confirmText: LocalizationKeys.confirm.tr(context),
      cancelText: '',
      icon: Icons.error_outline,
      confirmColor: Colors.redAccent,
    );
  }

  /// 延迟检查应用更新
  void _scheduleUpdateCheck() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        UpdateChecker.checkAndShowUpdate(
          context,
          showLoadingSnackBar: false,
          showNoUpdateSnackBar: false,
        );
      }
    });
  }

  /// 集中处理关闭前的清理工作
  Future<void> _handleAppCleanup() async {
    try {
      AppLogger.info('Starting app cleanup...');
      await ModuleRegistry().performCleanup();
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

    if (BackHandlerService().handleBack()) {
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    if (_isSetupMode) {
      _showExitPrompt();
      return;
    }

    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });
      return;
    }

    _showExitPrompt();
  }

  /// 显示"再次操作以退出"提示或执行退出
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

    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else {
      exit(0);
    }
  }

  @override
  void onWindowFocus() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      final themeProvider = context.watch<ThemeProvider>();
      Widget loadingScreen = LoadingScreen(themeProvider: themeProvider);

      if (Platform.isAndroid || Platform.isIOS) {
        loadingScreen = PopScope(
          canPop: false,
          onPopInvokedWithResult: _handlePopInvoked,
          child: loadingScreen,
        );
      }

      return loadingScreen;
    }

    context.watch<LocalizationService>();
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    final elements = NavigationRegistry().getNavigationElements(context);

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
                const CustomTitleBar(
                  title: Text(
                    AppConstants.appName,
                    style: TextStyle(fontFamily: 'MicrosoftYaHei'),
                  ),
                ),
                Divider(
                  height: 1,
                  color: Color(isDark ? 0xFF313131 : 0xFFD6D6D6),
                ),
              ],
              Expanded(
                child: Responsive(
                  mobile: MobileLayout(
                    navigationItems: flatItems,
                    selectedIndex: _selectedIndex,
                    onNavigationChanged: _onNavigationChanged,
                  ),
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

        await Future.delayed(const Duration(milliseconds: 300));
        await _handleAppCleanup();

        await windowManager.setPreventClose(false);
        await windowManager.close();
      }
    }
  }
}
