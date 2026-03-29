import 'package:flutter/material.dart';
import '../../../core/services/back_handler_service.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/theme/app_theme_data.dart';
import '../localization/briefing_localization_keys.dart';
import 'briefing_generate_page.dart';
import 'briefing_history_page.dart';
import 'widgets/briefing_function_card.dart';

/// 简报模块页面类型定义
enum BriefingPageType { main, generate, history }

/// 简报模块路由配置项模型
class BriefingPageConfig {
  final BriefingPageType type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function(VoidCallback onBack) builder;

  const BriefingPageConfig({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });
}

/// 飞行简报总控页面 (Hub)
/// 负责在“模块入口”、“简报生成”和“历史记录”三个视图间切换
class BriefingPage extends StatefulWidget {
  const BriefingPage({super.key});

  @override
  State<BriefingPage> createState() => _BriefingPageState();
}

class _BriefingPageState extends State<BriefingPage> {
  /// 当前显示的子视图页面
  BriefingPageType _currentPage = BriefingPageType.main;

  /// 按业务划分的页面路由数组
  late final List<BriefingPageConfig> _briefingPages = [
    BriefingPageConfig(
      type: BriefingPageType.generate,
      title: BriefingLocalizationKeys.generateTitle.tr(context),
      subtitle: BriefingLocalizationKeys.generateSubtitle.tr(context),
      icon: Icons.add_circle_outline,
      builder: (onBack) => BriefingGeneratePage(onBack: onBack),
    ),
    BriefingPageConfig(
      type: BriefingPageType.history,
      title: BriefingLocalizationKeys.historyTitle.tr(context),
      subtitle: BriefingLocalizationKeys.historySubtitle.tr(context),
      icon: Icons.history,
      builder: (onBack) => BriefingHistoryPage(onBack: onBack),
    ),
  ];

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
    if (_currentPage != BriefingPageType.main) {
      _navigateBack();
      return true;
    }
    return false;
  }

  /// 导航至指定子视图
  void _navigateToPage(BriefingPageType page) =>
      setState(() => _currentPage = page);

  /// 返回主视图入口
  void _navigateBack() => setState(() => _currentPage = BriefingPageType.main);

  @override
  Widget build(BuildContext context) {
    // 采用 AnimatedSwitcher 实现平滑的页面切换效果
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: _currentPage == BriefingPageType.main
          ? _buildMainHub()
          : _buildSubView(),
    );
  }

  /// 构建当前选中的具体业务子页面 (生成或历史)
  Widget _buildSubView() {
    final config = _briefingPages.firstWhere(
      (page) => page.type == _currentPage,
      orElse: () => _briefingPages.first,
    );
    return config.builder(_navigateBack);
  }

  /// 构建简报模块的主功能入口页面
  Widget _buildMainHub() {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 自定义大标题 AppBar
            SliverAppBar(
              expandedHeight: 70.0,
              pinned: true,
              backgroundColor: theme.scaffoldBackgroundColor,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.symmetric(
                  horizontal: AppThemeData.spacingMedium,
                  vertical: AppThemeData.spacingMedium,
                ),
                title: Text(
                  BriefingLocalizationKeys.pageTitle.tr(context),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                centerTitle: false,
              ),
            ),
            // 功能入口列表
            SliverPadding(
              padding: const EdgeInsets.all(AppThemeData.spacingMedium),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSectionLabel(
                    BriefingLocalizationKeys.pageSubtitle.tr(context),
                  ),
                  const SizedBox(height: AppThemeData.spacingSmall),
                  ..._briefingPages.map(
                    (config) => BriefingFunctionCard(
                      title: config.title,
                      subtitle: config.subtitle,
                      icon: config.icon,
                      onTap: () => _navigateToPage(config.type),
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

  /// 辅助构建分组标签组件
  Widget _buildSectionLabel(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
