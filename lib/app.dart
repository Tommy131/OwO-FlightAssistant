import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'apps/providers/checklist_provider.dart';
import 'apps/providers/flight_provider.dart';
import 'apps/providers/simulator/simulator_provider.dart';
import 'apps/providers/briefing_provider.dart';
import 'apps/providers/map_provider.dart';
import 'apps/providers/airport_info_provider.dart';
import 'core/constants/app_constants.dart';
import 'core/layouts/desktop_layout.dart';
import 'core/layouts/mobile_layout.dart';
import 'core/layouts/responsive.dart';
import 'core/models/navigation_item.dart';
import 'apps/services/app_core/app_initializer.dart';
import 'core/theme/theme_provider.dart';
import 'core/widgets/common/dialog.dart';
import 'apps/services/app_core/update_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/widgets/desktop/custom_title_bar.dart';
import 'pages/airport_info/airport_info_page.dart';
import 'pages/checklist/checklist_page.dart';
import 'pages/home/home_page.dart';
import 'pages/monitor/monitor_page.dart';
import 'pages/map/map_page.dart';
import 'pages/briefing/briefing_page.dart';
import 'pages/settings/settings_page.dart';
import 'pages/toolbox/toolbox_page.dart';
import 'pages/setup/setup_wizard_page.dart';
import 'pages/splash/splash_screen.dart';
import 'pages/flight_logs/flight_logs_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => FlightProvider()),
        ChangeNotifierProvider(create: (_) => ChecklistProvider()),
        ChangeNotifierProvider(create: (_) => SimulatorProvider()),
        ChangeNotifierProvider(create: (_) => AirportInfoProvider()),
        ChangeNotifierProvider(create: (_) => BriefingProvider()),
        ChangeNotifierProvider(
          create: (context) => MapProvider(
            context.read<SimulatorProvider>(),
            context.read<AirportInfoProvider>(),
          ),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: themeProvider.currentTheme.generateLightTheme(),
            darkTheme: themeProvider.currentTheme.generateDarkTheme(),
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

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WindowListener {
  int _selectedIndex = 0;
  bool _isPreloading = true;
  bool _needsSetup = false;

  // 定义导航项
  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      id: 'home',
      title: '首页',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      page: HomePage(),
    ),
    NavigationItem(
      id: 'airport',
      title: '机场信息',
      icon: Icons.flight_outlined,
      activeIcon: Icons.flight,
      page: AirportInfoPage(),
    ),
    NavigationItem(
      id: 'briefing',
      title: '飞行简报',
      icon: Icons.description_outlined,
      activeIcon: Icons.description,
      page: BriefingPage(),
    ),
    NavigationItem(
      id: 'monitor',
      title: '飞行仪表盘',
      icon: Icons.speed_outlined,
      activeIcon: Icons.speed,
      page: MonitorPage(),
    ),
    NavigationItem(
      id: 'map',
      title: '地图与进近',
      icon: Icons.map_outlined,
      activeIcon: Icons.map,
      page: MapPage(),
    ),
    NavigationItem(
      id: 'checklist',
      title: '飞行检查单',
      icon: Icons.checklist_outlined,
      activeIcon: Icons.checklist,
      page: ChecklistPage(),
    ),
    NavigationItem(
      id: 'flight_logs',
      title: '飞行日志',
      icon: Icons.history_edu_outlined,
      activeIcon: Icons.history_edu,
      page: FlightLogsPage(),
    ),
    NavigationItem(
      id: 'toolbox',
      title: '工具箱',
      icon: Icons.construction_outlined,
      activeIcon: Icons.construction,
      page: ToolboxPage(),
    ),
    NavigationItem(
      id: 'settings',
      title: '设置',
      icon: Icons.settings_rounded,
      activeIcon: Icons.settings,
      page: SettingsPage(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);

    // 在下一帧之后设置回调，确保 Provider 已经完全就绪
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final simProvider = context.read<SimulatorProvider>();
        final checklistProvider = context.read<ChecklistProvider>();
        final briefingProvider = context.read<BriefingProvider>();

        simProvider.setAircraftDetectionCallback((aircraftId) {
          if (mounted) {
            checklistProvider.selectAircraft(aircraftId);
          }
        });

        // 初始化简报提供者，加载历史记录
        briefingProvider.initialize();

        // 在这里启动预加载，确保在 UI 渲染出 SplashScreen 后开始
        _initializeApp();
      }
    });

    _init();
  }

  Future<void> _initializeApp() async {
    // 1. 检查是否需要初次设置
    final needsSetup = await AppInitializer.checkSetupNeeded();

    if (needsSetup) {
      if (mounted) {
        setState(() {
          _needsSetup = true;
          _isPreloading = false;
        });
        await AppInitializer.setupWindow();
      }
      return;
    }

    // 2. 预加载机场数据 (导航中心加载)
    await AppInitializer.preloadAirportData();

    if (mounted) {
      setState(() => _isPreloading = false);
      await AppInitializer.setupWindow();

      // 3. 应用完全启动后，异步执行更新检测
      _checkUpdateTask();
    }
  }

  Future<void> _checkUpdateTask() async {
    if (!mounted) return;

    // 延迟一秒执行，确保 UI 已经完全切换并稳定显示
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    // 显示正在检测更新的轻量提示 (面包条/Snackbar)
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('正在检查应用更新...'),
          ],
        ),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final updateInfo = await UpdateService.checkUpdate();

      // 确保提示至少显示 1.5 秒，避免网络太快导致一闪而过
      await Future.delayed(const Duration(milliseconds: 1500));

      // 检查结束后移除当前 Snackbar
      messenger.hideCurrentSnackBar();

      if (updateInfo['error'] != null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('❌ 更新检测失败'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (mounted) {
          await showAdvancedConfirmDialog(
            context: context,
            title: '更新检测失败',
            content: '无法连接到更新服务器：${updateInfo['error']}',
            icon: Icons.error_outline_rounded,
            confirmColor: Colors.orange,
            confirmText: '好的',
            cancelText: '',
          );
        }
      } else if (updateInfo['hasUpdate'] == true) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('🚀 发现新版本！'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (mounted) {
          final shouldUpdate = await showAdvancedConfirmDialog(
            context: context,
            title: '发现新版本',
            content:
                '发现最新版本 ${updateInfo['remoteVersion']} (当前: ${AppConstants.appVersion})。是否跳转至 GitHub 下载更新？',
            icon: Icons.system_update_rounded,
            confirmText: '去下载',
            cancelText: '暂不更新',
          );

          if (shouldUpdate == true && mounted) {
            final downloadUrl = updateInfo['downloadUrl'] as String?;
            final uri = Uri.parse(downloadUrl ?? UpdateService.releasePageUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        }
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('✅ 已是最新版本'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('⚠️ 更新检测异常'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (mounted) {
        await showAdvancedConfirmDialog(
          context: context,
          title: '更新检测异常',
          content: '在检查更新时发生了错误：$e',
          icon: Icons.warning_amber_rounded,
          confirmColor: Colors.redAccent,
          confirmText: '好的',
          cancelText: '',
        );
      }
    }
  }

  void _init() async {
    // Add this line to override the default close handler
    await windowManager.setPreventClose(true);
    setState(() {});
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
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
    if (_isPreloading) {
      final themeProvider = context.watch<ThemeProvider>();
      return SplashScreen(
        theme: themeProvider.currentTheme.generateDarkTheme(),
      );
    }

    if (_needsSetup) {
      return SetupWizardPage(
        onSetupComplete: () {
          setState(() {
            _needsSetup = false;
            _isPreloading = true; // 重新进入预加载流程
          });
          _initializeApp();
        },
      );
    }

    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        if (!Platform.isAndroid && !Platform.isIOS) ...[
          CustomTitleBar(title: Text(AppConstants.appName)),
          Divider(height: 1, color: Color(isDark ? 0xFF313131 : 0xFFD6D6D6)),
        ],
        Expanded(
          child: Responsive(
            // 移动端布局
            mobile: MobileLayout(
              navigationItems: _navigationItems,
              selectedIndex: _selectedIndex,
              onNavigationChanged: _onNavigationChanged,
            ),
            // 桌面端布局
            desktop: DesktopLayout(
              navigationItems: _navigationItems,
              selectedIndex: _selectedIndex,
              onNavigationChanged: _onNavigationChanged,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose && mounted) {
      final result = await showAdvancedConfirmDialog(
        context: context,
        // style: ConfirmDialogStyle.glass,
        title: '确认退出程序吗?',
        content: '',
        icon: Icons.warning_amber_rounded,
        confirmColor: Colors.redAccent,
        confirmText: '确认',
        cancelText: '取消',
      );

      if (result == true && mounted) {
        await windowManager.destroy();
      }
    }
  }
}
