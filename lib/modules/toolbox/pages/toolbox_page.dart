import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme_data.dart';
import '../../../core/services/localization_service.dart';
import '../localization/toolbox_localization_keys.dart';
import 'widgets/unit_conversion_tab.dart';
import 'widgets/terms_translation_tab.dart';

/// 工具箱模块 - 主页面
///
/// 作为一个实用工具集合，目前提供单位转换 (Unit Conversion) 和 航空术语翻译 (Term Translation) 两大核心功能。
/// 页面采用侧边侧滑栏 (NavigationRail) 的布局设计，适配大屏操作环境。
enum ToolboxSection { unitConversion, termTranslation }

class ToolboxPage extends StatefulWidget {
  const ToolboxPage({super.key});

  @override
  State<ToolboxPage> createState() => _ToolboxPageState();
}

class _ToolboxPageState extends State<ToolboxPage> {
  ToolboxSection _selectedSection = ToolboxSection.unitConversion;

  @override
  Widget build(BuildContext context) {
    context.watch<LocalizationService>();
    final theme = Theme.of(context);
    final selectedIndex = _selectedSection == ToolboxSection.unitConversion
        ? 0
        : 1;

    return Scaffold(
      body: Row(
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
                setState(() {
                  _selectedSection = index == 0
                      ? ToolboxSection.unitConversion
                      : ToolboxSection.termTranslation;
                });
              },
              labelType: NavigationRailLabelType.all,
              minWidth: 110,
              minExtendedWidth: 110,
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.calculate_outlined),
                  selectedIcon: const Icon(Icons.calculate),
                  label: Text(ToolboxLocalizationKeys.unitTab.tr(context)),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.translate_outlined),
                  selectedIcon: const Icon(Icons.translate),
                  label: Text(ToolboxLocalizationKeys.termsTab.tr(context)),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppThemeData.animationDuration,
              child: _selectedSection == ToolboxSection.unitConversion
                  ? const UnitConversionTab(key: ValueKey('unit'))
                  : const TermsTranslationTab(key: ValueKey('terms')),
            ),
          ),
        ],
      ),
    );
  }
}
