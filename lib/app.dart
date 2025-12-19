import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'core/theme/theme_provider.dart';
import 'core/constants/app_constants.dart';
import 'core/layouts/desktop_layout.dart';
import 'core/layouts/mobile_layout.dart';
import 'core/layouts/responsive.dart';
import 'core/models/navigation_item.dart';
import 'core/widgets/common/dialog.dart';
import 'core/widgets/desktop/custom_title_bar.dart';
import 'pages/explore/explore_page.dart';
import 'pages/home/home_page.dart';
import 'pages/messages/messages_page.dart';
import 'pages/notifications/notification_demo_page.dart';
import 'pages/notifications/notifications_page.dart';
import 'pages/profile/profile_page.dart';
import 'pages/settings/theme_settings_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ThemeProvider())],
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
      id: 'explore',
      title: '探索',
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore,
      page: ExplorePage(),
    ),
    NavigationItem(
      id: 'messages',
      title: '消息',
      icon: Icons.message_outlined,
      activeIcon: Icons.message,
      page: MessagesPage(),
      badge: '3', // 示例徽章
    ),
    NavigationItem(
      id: 'notifications',
      title: '通知',
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications,
      page: NotificationsPage(),
      badge: '12', // 示例徽章
    ),
    NavigationItem(
      id: 'notifications_demo',
      title: '通知测试页',
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications,
      page: NotificationDemoPage(),
    ),
    NavigationItem(
      id: 'profile',
      title: '我的',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      page: ProfilePage(),
    ),
    NavigationItem(
      id: 'settings',
      title: '主题设置',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      page: ThemeSettingsPage(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _init();
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
