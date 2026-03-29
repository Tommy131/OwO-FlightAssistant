import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/back_handler_service.dart';
import '../theme/app_theme_data.dart';
import '../localization/localization_keys.dart';
import '../services/localization_service.dart';
import 'theme_settings_page.dart';
import 'about_page.dart';
import 'general_settings_page.dart';
import '../module_registry/settings_page/settings_page_registry.dart';

/// 设置项配置模型
class SettingsItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function(VoidCallback onBack) builder;
  final String routeKey;

  const SettingsItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
    required this.routeKey,
  });
}

/// 设置页面的主入口，支持智能子页面注册和过渡动画
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // 当前子页面路由 Key：'main' 表示主菜单
  String _currentRoute = 'main';

  // 智能注册子页面列表
  List<SettingsItem> _settingsItems = [];

  List<SettingsItem> _buildSettingsItems(BuildContext context) {
    final items = <SettingsItem>[
      // 核心设置页面
      SettingsItem(
        title: LocalizationKeys.generalSettings.tr(context),
        subtitle: LocalizationKeys.storageLocationDesc.tr(context),
        icon: Icons.settings_applications_outlined,
        routeKey: 'general',
        builder: (onBack) => GeneralSettingsPage(onBack: onBack),
      ),
      SettingsItem(
        title: LocalizationKeys.themeSettings.tr(context),
        subtitle: LocalizationKeys.themeSettingsDesc.tr(context),
        icon: Icons.palette_outlined,
        routeKey: 'theme',
        builder: (onBack) => ThemeSettingsPage(onBack: onBack),
      ),
      SettingsItem(
        title: LocalizationKeys.aboutApp.tr(context),
        subtitle: LocalizationKeys.aboutAppDesc.tr(context),
        icon: Icons.info_outline,
        routeKey: 'about',
        builder: (onBack) => AboutPage(onBack: onBack),
      ),
    ];

    // 从注册表加载自定义设置页面
    final registry = SettingsPageRegistry();
    final customPages = registry.getAllPages();

    for (final page in customPages) {
      items.add(
        SettingsItem(
          title: page.getTitle(context),
          subtitle: page.getDescription(context) ?? '',
          icon: page.icon,
          routeKey: page.id,
          builder: (onBack) => _CustomPageWrapper(page: page, onBack: onBack),
        ),
      );
    }

    return items;
  }

  void _navigateTo(String route) {
    setState(() {
      _currentRoute = route;
    });
  }

  void _goBack() {
    setState(() {
      _currentRoute = 'main';
    });
  }

  @override
  void initState() {
    super.initState();
    BackHandlerService().register(_onBack);
  }

  @override
  void dispose() {
    BackHandlerService().unregister(_onBack);
    super.dispose();
  }

  bool _onBack() {
    if (!mounted) return false;
    if (_currentRoute != 'main') {
      _goBack();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocalizationService>();
    _settingsItems = _buildSettingsItems(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        // 使用更加平滑的水平移动 + 渐变效果
        final offsetAnimation =
            Tween<Offset>(
              begin: const Offset(0.05, 0.0), // 稍微偏移即可，避免过大位移感
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offsetAnimation, child: child),
        );
      },
      child: _buildCurrentPage(),
    );
  }

  Widget _buildCurrentPage() {
    if (_currentRoute == 'main') {
      return _buildMainMenu();
    }

    // 根据 routeKey 自动匹配并构建子页面
    final item = _settingsItems.firstWhere(
      (element) => element.routeKey == _currentRoute,
      orElse: () => _settingsItems.first,
    );

    return KeyedSubtree(
      key: ValueKey(item.routeKey),
      child: item.builder(_goBack),
    );
  }

  Widget _buildMainMenu() {
    Theme.of(context);
    return Scaffold(
      key: const ValueKey('main_menu'),
      body: ListView(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        children: [
          // 根据注册列表自动生成菜单卡片
          ..._settingsItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppThemeData.spacingSmall),
              child: _SettingsMenuCard(
                item: item,
                onTap: () => _navigateTo(item.routeKey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsMenuCard extends StatelessWidget {
  final SettingsItem item;
  final VoidCallback onTap;

  const _SettingsMenuCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Semantics(
        button: true,
        label: '${item.title}. ${item.subtitle}',
        child: ExcludeSemantics(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(
              AppThemeData.borderRadiusMedium,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppThemeData.spacingMedium),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.icon,
                      size: 28,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.subtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 自定义页面包装器，提供返回按钮支持
class _CustomPageWrapper extends StatelessWidget {
  final dynamic page;
  final VoidCallback onBack;

  const _CustomPageWrapper({required this.page, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: LocalizationKeys.back.tr(context),
              onPressed: onBack,
            ),
            const SizedBox(width: AppThemeData.spacingSmall),
            Text(page.getTitle(context), style: theme.textTheme.headlineMedium),
          ],
        ),
        const SizedBox(height: AppThemeData.spacingLarge),
        page.build(context),
      ],
    );
  }
}
