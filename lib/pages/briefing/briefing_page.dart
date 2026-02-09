import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../apps/providers/briefing_provider.dart';
import '../../core/theme/app_theme_data.dart';
import 'widgets/briefing_input_card.dart';
import 'widgets/briefing_display_card.dart';
import 'widgets/briefing_history_page.dart';

/// 简报页面类型枚举
enum BriefingPageType { main, generate, history }

/// 简报页面配置类
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

/// 飞行简报主页面 - 使用嵌套式导航
class BriefingPage extends StatefulWidget {
  const BriefingPage({super.key});

  @override
  State<BriefingPage> createState() => _BriefingPageState();
}

class _BriefingPageState extends State<BriefingPage> {
  BriefingPageType _currentPage = BriefingPageType.main;

  // 集中管理所有子页面配置
  static final List<BriefingPageConfig> _briefingPages = [
    BriefingPageConfig(
      type: BriefingPageType.generate,
      title: '生成简报',
      subtitle: '输入航班信息，生成专业飞行简报',
      icon: Icons.add_circle_outline,
      builder: (onBack) => _BriefingGeneratePage(onBack: onBack),
    ),
    BriefingPageConfig(
      type: BriefingPageType.history,
      title: '历史简报',
      subtitle: '查看和管理历史简报记录',
      icon: Icons.history,
      builder: (onBack) => BriefingHistoryPage(onBack: onBack),
    ),
  ];

  void _navigateToPage(BriefingPageType page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _navigateBack() {
    setState(() {
      _currentPage = BriefingPageType.main;
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
      child: _currentPage == BriefingPageType.main
          ? _buildMainPage()
          : _buildSubPage(),
    );
  }

  Widget _buildSubPage() {
    final config = _briefingPages.firstWhere(
      (page) => page.type == _currentPage,
      orElse: () => _briefingPages.first,
    );
    return config.builder(_navigateBack);
  }

  /// 主页面 - 选择功能
  Widget _buildMainPage() {
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
                  '飞行简报',
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
                  const _SectionHeader(title: '功能'),
                  const SizedBox(height: AppThemeData.spacingSmall),

                  // 遍历配置列表生成功能卡片
                  ..._briefingPages.map(
                    (config) => _buildFunctionCard(
                      context,
                      config: config,
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

  /// 功能卡片
  Widget _buildFunctionCard(
    BuildContext context, {
    required BriefingPageConfig config,
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

/// 生成简报子页面
class _BriefingGeneratePage extends StatelessWidget {
  final VoidCallback onBack;

  const _BriefingGeneratePage({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<BriefingProvider>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // 返回按钮
          Container(
            padding: const EdgeInsets.all(AppThemeData.spacingMedium),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: theme.dividerColor, width: 1),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBack,
                ),
                const SizedBox(width: AppThemeData.spacingSmall),
                Text(
                  '生成简报',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // 内容区域
          Expanded(
            child: Row(
              children: [
                // 左侧：输入区域（无卡片，直接嵌入背景）
                Container(
                  width: 420,
                  color: theme.colorScheme.surface.withValues(alpha: 0.3),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppThemeData.spacingLarge),
                    child: const BriefingInputCard(),
                  ),
                ),

                // 分隔线
                VerticalDivider(width: 1, color: theme.dividerColor),

                // 右侧：简报显示区域（无卡片，直接嵌入背景）
                Expanded(
                  child: Container(
                    color: theme.scaffoldBackgroundColor,
                    child: provider.currentBriefing != null
                        ? BriefingDisplayCard(
                            briefing: provider.currentBriefing!,
                          )
                        : _buildEmptyState(theme),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 80,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppThemeData.spacingLarge),
          Text(
            '暂无简报',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppThemeData.spacingSmall),
          Text(
            '请在左侧输入航班信息生成简报',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
