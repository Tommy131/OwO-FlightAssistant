import 'package:flutter/material.dart';
import '../../core/theme/app_theme_data.dart';
import 'widgets/unit_conversion_tab.dart';
import 'widgets/terms_translation_tab.dart';

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
    final theme = Theme.of(context);
    final selectedIndex = _selectedSection == ToolboxSection.unitConversion
        ? 0
        : 1;

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 100,
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
              minWidth: 100,
              minExtendedWidth: 100,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.calculate_outlined),
                  selectedIcon: Icon(Icons.calculate),
                  label: Text('单位换算'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.translate_outlined),
                  selectedIcon: Icon(Icons.translate),
                  label: Text('术语翻译'),
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
