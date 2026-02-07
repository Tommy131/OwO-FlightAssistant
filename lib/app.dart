import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'apps/data/airports_database.dart';
import 'apps/services/airport_detail_service.dart';
import 'core/theme/theme_provider.dart';
import 'apps/providers/checklist_provider.dart';
import 'apps/providers/simulator/simulator_provider.dart';
import 'core/constants/app_constants.dart';
import 'core/layouts/desktop_layout.dart';
import 'core/layouts/mobile_layout.dart';
import 'core/layouts/responsive.dart';
import 'core/models/navigation_item.dart';
import 'core/utils/logger.dart';
import 'core/widgets/common/dialog.dart';
import 'core/widgets/desktop/custom_title_bar.dart';
import 'pages/home/home_page.dart';
import 'pages/checklist/checklist_page.dart';
import 'pages/settings/settings_page.dart';
import 'pages/monitor/monitor_page.dart';
import 'pages/airport_info/airport_info_page.dart';
import 'pages/splash/splash_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ChecklistProvider()),
        ChangeNotifierProvider(create: (_) => SimulatorProvider()),
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

  // 定义导航项
  final List<NavigationItem> _navigationItems = const [
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
      id: 'monitor',
      title: '飞行仪表盘',
      icon: Icons.speed_outlined,
      activeIcon: Icons.speed,
      page: MonitorPage(),
    ),
    NavigationItem(
      id: 'checklist',
      title: '飞行检查单',
      icon: Icons.checklist_outlined,
      activeIcon: Icons.checklist,
      page: ChecklistPage(),
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

        simProvider.setAircraftDetectionCallback((aircraftId) {
          if (mounted) {
            checklistProvider.selectAircraft(aircraftId);
          }
        });

        // 在这里启动预加载，确保在 UI 渲染出 SplashScreen 后开始
        _preloadAirportData();
      }
    });

    _init();
  }

  Future<void> _preloadAirportData() async {
    // 延迟一小段时间，确保 SplashScreen 能够被用户看见
    await Future.delayed(const Duration(milliseconds: 800));

    // 如果数据库已经有数据，不需要重复加载
    if (!AirportsDatabase.isEmpty) {
      setState(() => _isPreloading = false);
      _switchToMainWindow();
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
          airports
              .map(
                (a) => AirportInfo(
                  icaoCode: a['icao'] ?? '',
                  iataCode: a['iata'] ?? '',
                  nameChinese: a['name'] ?? '',
                  latitude: (a['lat'] as num?)?.toDouble() ?? 0.0,
                  longitude: (a['lon'] as num?)?.toDouble() ?? 0.0,
                ),
              )
              .toList(),
        );
        AppLogger.info('App 启动: 成功预加载 ${airports.length} 个机场数据');
      } else {
        AppLogger.warning(
          'App 启动: 未能预加载机场数据 (数据源: ${currentDataSource.displayName})',
        );
      }
    } catch (e) {
      AppLogger.error('App 启动: 预加载机场数据失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isPreloading = false);
        _switchToMainWindow();
      }
    }
  }

  Future<void> _switchToMainWindow() async {
    await windowManager.setSize(const Size(1266, 800));
    await windowManager.setMinimumSize(const Size(816, 600));
    await windowManager.center();
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
