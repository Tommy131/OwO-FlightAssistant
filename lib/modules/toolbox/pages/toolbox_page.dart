import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme_data.dart';
import '../../../core/services/localization_service.dart';
import '../localization/toolbox_localization_keys.dart';
import 'widgets/flight_calculators_tab.dart';
import 'widgets/ops_tools_tab.dart';
import 'widgets/performance_tools_tab.dart';
import 'widgets/unit_conversion_tab.dart';
import 'widgets/weather_decode_tab.dart';
import 'widgets/terms_translation_tab.dart';

/// 工具箱模块 - 主页面
///
/// 作为一个实用工具集合，目前提供单位转换 (Unit Conversion) 和 航空术语翻译 (Term Translation) 两大核心功能。
/// 页面采用侧边侧滑栏 (NavigationRail) 的布局设计，适配大屏操作环境。
enum ToolboxSection {
  unitConversion,
  termTranslation,
  flightCalculators,
  weatherDecode,
  performanceTools,
  opsTools,
}

class ToolboxSectionController extends ChangeNotifier {
  static final ToolboxSectionController instance =
      ToolboxSectionController._internal();
  ToolboxSectionController._internal();

  ToolboxSection _selectedSection = ToolboxSection.unitConversion;
  ToolboxSection get selectedSection => _selectedSection;

  void select(ToolboxSection section) {
    if (_selectedSection == section) {
      return;
    }
    _selectedSection = section;
    notifyListeners();
  }
}

class ToolboxPage extends StatelessWidget {
  const ToolboxPage({super.key});

  static const List<ToolboxSection> _sections = [
    ToolboxSection.unitConversion,
    ToolboxSection.termTranslation,
    ToolboxSection.flightCalculators,
    ToolboxSection.weatherDecode,
    ToolboxSection.performanceTools,
    ToolboxSection.opsTools,
  ];

  static Widget _buildSectionView(ToolboxSection section) {
    switch (section) {
      case ToolboxSection.unitConversion:
        return const UnitConversionTab(key: ValueKey('unit'));
      case ToolboxSection.termTranslation:
        return const TermsTranslationTab(key: ValueKey('terms'));
      case ToolboxSection.flightCalculators:
        return const FlightCalculatorsTab(key: ValueKey('calc'));
      case ToolboxSection.weatherDecode:
        return const WeatherDecodeTab(key: ValueKey('weather'));
      case ToolboxSection.performanceTools:
        return const PerformanceToolsTab(key: ValueKey('performance'));
      case ToolboxSection.opsTools:
        return const OpsToolsTab(key: ValueKey('ops'));
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocalizationService>();
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: ToolboxSectionController.instance,
      builder: (context, _) {
        final selectedSection =
            ToolboxSectionController.instance.selectedSection;
        final selectedIndex = _sections.indexOf(selectedSection);
        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 900;
            if (isCompact) {
              return AnimatedSwitcher(
                duration: AppThemeData.animationDuration,
                child: _buildSectionView(selectedSection),
              );
            }
            return Row(
              children: [
                Container(
                  width: 120,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      right: BorderSide(
                        color: AppThemeData.getBorderColor(theme),
                        width: 1,
                      ),
                    ),
                  ),
                  child: NavigationRail(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (index) {
                      ToolboxSectionController.instance.select(
                        _sections[index],
                      );
                    },
                    labelType: NavigationRailLabelType.all,
                    minWidth: 110,
                    minExtendedWidth: 110,
                    destinations: [
                      NavigationRailDestination(
                        icon: const Icon(Icons.calculate_outlined),
                        selectedIcon: const Icon(Icons.calculate),
                        label: Text(
                          ToolboxLocalizationKeys.unitTab.tr(context),
                        ),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.translate_outlined),
                        selectedIcon: const Icon(Icons.translate),
                        label: Text(
                          ToolboxLocalizationKeys.termsTab.tr(context),
                        ),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.flight_takeoff_outlined),
                        selectedIcon: const Icon(Icons.flight_takeoff),
                        label: Text(
                          ToolboxLocalizationKeys.calculatorsTab.tr(context),
                        ),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.cloud_outlined),
                        selectedIcon: const Icon(Icons.cloud),
                        label: Text(
                          ToolboxLocalizationKeys.weatherTab.tr(context),
                        ),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.speed_outlined),
                        selectedIcon: const Icon(Icons.speed),
                        label: Text(
                          ToolboxLocalizationKeys.performanceTab.tr(context),
                        ),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.warning_amber_outlined),
                        selectedIcon: const Icon(Icons.warning_amber),
                        label: Text(ToolboxLocalizationKeys.opsTab.tr(context)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppThemeData.animationDuration,
                    child: _buildSectionView(selectedSection),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
