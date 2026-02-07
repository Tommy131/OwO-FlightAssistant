import 'package:flutter/material.dart';
import '../../core/theme/app_theme_data.dart';
import 'theme_settings_page.dart';
import 'data_path_settings_page.dart';
import '../airport_info/airport_debug_page.dart';

/// 设置页面类型枚举
enum SettingsPageType { main, theme, dataPath, debug }

/// 设置页面配置类
class SettingsPageConfig {
  final SettingsPageType type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function(VoidCallback onBack) builder;

  const SettingsPageConfig({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });
}

/// 主设置页面 - 使用嵌套式导航
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  SettingsPageType _currentPage = SettingsPageType.main;

  // 集中管理所有子页面配置
  static final List<SettingsPageConfig> _settingsPages = [
    SettingsPageConfig(
      type: SettingsPageType.theme,
      title: '个性化',
      subtitle: '自定义应用主题、颜色和外观模式',
      icon: Icons.palette_rounded,
      builder: (onBack) => ThemeSettingsPage(onBack: onBack),
    ),
    SettingsPageConfig(
      type: SettingsPageType.dataPath,
      title: '数据源配置',
      subtitle: '配置本地模拟器数据路径与 API 令牌',
      icon: Icons.storage_rounded,
      builder: (onBack) => DataPathSettingsPage(onBack: onBack),
    ),
    SettingsPageConfig(
      type: SettingsPageType.debug,
      title: '机场数据诊断',
      subtitle: '查看当前加载的所有机场 ICAO 列表及状态',
      icon: Icons.bug_report_rounded,
      builder: (onBack) => AirportDebugPage(onBack: onBack),
    ),
  ];

  void _navigateToPage(SettingsPageType page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _navigateBack() {
    setState(() {
      _currentPage = SettingsPageType.main;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: _currentPage == SettingsPageType.main
          ? _buildMainSettings()
          : _buildSubPage(),
    );
  }

  Widget _buildSubPage() {
    final config = _settingsPages.firstWhere(
      (page) => page.type == _currentPage,
      orElse: () => _settingsPages.first,
    );
    return config.builder(_navigateBack);
  }

  /// 主设置页面
  Widget _buildMainSettings() {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 70.0,
              floating: false,
              pinned: true,
              backgroundColor: theme.scaffoldBackgroundColor,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.symmetric(
                  horizontal: AppThemeData.spacingMedium,
                  vertical: AppThemeData.spacingMedium,
                ),
                title: Text(
                  '设置',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                centerTitle: false,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(AppThemeData.spacingMedium),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // 功能分类标题
                  const _SectionHeader(title: '通用'),
                  const SizedBox(height: AppThemeData.spacingSmall),

                  // 遍历配置列表生成设置卡片
                  ..._settingsPages.map(
                    (config) => _buildSettingCard(
                      context,
                      config: config,
                      onTap: () => _navigateToPage(config.type),
                    ),
                  ),

                  const SizedBox(height: AppThemeData.spacingLarge),

                  // 应用信息分类
                  const _SectionHeader(title: '关于应用'),
                  const SizedBox(height: AppThemeData.spacingSmall),

                  _AboutCard(),

                  const SizedBox(height: AppThemeData.spacingLarge),

                  // 版权信息
                  Center(
                    child: Text(
                      '© 2025 OwO Team. All rights reserved.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline.withValues(alpha: 0.5),
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppThemeData.spacingLarge),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 设置项卡片
  Widget _buildSettingCard(
    BuildContext context, {
    required SettingsPageConfig config,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppThemeData.spacingSmall),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        child: Container(
          padding: const EdgeInsets.all(AppThemeData.spacingMedium),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(
              AppThemeData.borderRadiusMedium,
            ),
            border: Border.all(
              color: AppThemeData.getBorderColor(theme).withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppThemeData.borderRadiusSmall,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(config.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: AppThemeData.spacingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      config.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(
          color: AppThemeData.getBorderColor(theme).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          const _AboutItem(
            icon: Icons.info_outline_rounded,
            label: '应用名称',
            value: 'OwO Flight Assistant',
          ),
          Divider(
            height: 1,
            indent: 50,
            color: AppThemeData.getBorderColor(theme).withValues(alpha: 0.3),
          ),
          const _AboutItem(
            icon: Icons.vibration_rounded,
            label: '版本',
            value: 'v1.0.0-alpha',
          ),
          Divider(
            height: 1,
            indent: 50,
            color: AppThemeData.getBorderColor(theme).withValues(alpha: 0.3),
          ),
          const _AboutItem(
            icon: Icons.code_rounded,
            label: '开发者',
            value: 'Hanski Jay (OwO Team)',
          ),
        ],
      ),
    );
  }
}

class _AboutItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AboutItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppThemeData.spacingMedium,
        vertical: AppThemeData.spacingMedium,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 16),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
