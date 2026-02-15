import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/theme/app_theme_data.dart';
import '../../../core/widgets/common/snack_bar.dart';
import '../localization/briefing_localization_keys.dart';
import '../providers/briefing_provider.dart';
import 'widgets/briefing_display_card.dart';
import 'widgets/briefing_history_page.dart';
import 'widgets/briefing_input_card.dart';

enum BriefingPageType { main, generate, history }

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

class BriefingPage extends StatefulWidget {
  const BriefingPage({super.key});

  @override
  State<BriefingPage> createState() => _BriefingPageState();
}

class _BriefingPageState extends State<BriefingPage> {
  BriefingPageType _currentPage = BriefingPageType.main;

  late final List<BriefingPageConfig> _briefingPages = [
    BriefingPageConfig(
      type: BriefingPageType.generate,
      title: BriefingLocalizationKeys.generateTitle.tr(context),
      subtitle: BriefingLocalizationKeys.generateSubtitle.tr(context),
      icon: Icons.add_circle_outline,
      builder: (onBack) => _BriefingGeneratePage(onBack: onBack),
    ),
    BriefingPageConfig(
      type: BriefingPageType.history,
      title: BriefingLocalizationKeys.historyTitle.tr(context),
      subtitle: BriefingLocalizationKeys.historySubtitle.tr(context),
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
                  BriefingLocalizationKeys.pageTitle.tr(context),
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
                  _SectionHeader(
                    title: BriefingLocalizationKeys.pageSubtitle.tr(context),
                  ),
                  const SizedBox(height: AppThemeData.spacingSmall),
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
        ),
      ),
    );
  }
}

class _BriefingGeneratePage extends StatelessWidget {
  final VoidCallback onBack;

  const _BriefingGeneratePage({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(BriefingLocalizationKeys.generateTitle.tr(context)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: onBack,
        ),
      ),
      body: SafeArea(
        child: Consumer<BriefingProvider>(
          builder: (context, provider, child) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 960;
                final content = isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Expanded(child: BriefingInputCard()),
                          SizedBox(width: AppThemeData.spacingMedium),
                          Expanded(child: BriefingDisplayCard()),
                        ],
                      )
                    : const Column(
                        children: [
                          BriefingInputCard(),
                          SizedBox(height: AppThemeData.spacingMedium),
                          BriefingDisplayCard(),
                        ],
                      );
                return ListView(
                  padding: const EdgeInsets.all(AppThemeData.spacingMedium),
                  children: [
                    content,
                    const SizedBox(height: AppThemeData.spacingMedium),
                    _BriefingActions(provider: provider),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _BriefingActions extends StatelessWidget {
  final BriefingProvider provider;

  const _BriefingActions({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppThemeData.spacingSmall,
      runSpacing: AppThemeData.spacingSmall,
      children: [
        TextButton.icon(
          onPressed: () async {
            try {
              final count = await provider.importFromFilePicker();
              if (count > 0) {
                SnackBarHelper.showSuccess(
                  context,
                  BriefingLocalizationKeys.importSuccess.tr(context),
                );
              } else {
                SnackBarHelper.showWarning(
                  context,
                  BriefingLocalizationKeys.importFailed.tr(context),
                );
              }
            } catch (_) {
              SnackBarHelper.showError(
                context,
                BriefingLocalizationKeys.importFailed.tr(context),
              );
            }
          },
          icon: const Icon(Icons.file_upload, size: 18),
          label: Text(BriefingLocalizationKeys.importFile.tr(context)),
        ),
        TextButton.icon(
          onPressed: () async {
            try {
              final result = await provider.exportToFilePicker();
              if (result == 1) {
                SnackBarHelper.showSuccess(
                  context,
                  BriefingLocalizationKeys.exportSuccess.tr(context),
                );
              } else if (result == -1) {
                SnackBarHelper.showWarning(
                  context,
                  BriefingLocalizationKeys.exportFailed.tr(context),
                );
              }
            } catch (_) {
              SnackBarHelper.showError(
                context,
                BriefingLocalizationKeys.exportFailed.tr(context),
              );
            }
          },
          icon: const Icon(Icons.file_download, size: 18),
          label: Text(BriefingLocalizationKeys.exportFile.tr(context)),
        ),
      ],
    );
  }
}
