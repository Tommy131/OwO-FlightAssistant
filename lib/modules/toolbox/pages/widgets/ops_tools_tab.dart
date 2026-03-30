import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/toolbox_localization_keys.dart';
import 'toolbox_section_card.dart';

class OpsToolsTab extends StatefulWidget {
  const OpsToolsTab({super.key});

  @override
  State<OpsToolsTab> createState() => _OpsToolsTabState();
}

class _OpsToolsTabState extends State<OpsToolsTab> {
  final TextEditingController _notamController = TextEditingController();
  final Set<String> _selectedTags = {'RWY', 'TWY', 'NAV', 'OBST', 'WIP'};
  List<String> _notamMatches = [];

  static const List<String> _tags = [
    'RWY',
    'ILS',
    'TWY',
    'NAV',
    'OBST',
    'WIP',
    'FUEL',
    'LIGHT',
    'CLSD',
    'CLOSED',
  ];

  List<_QuickRefItem> _quickRefs(BuildContext context) {
    return [
      _QuickRefItem(
        title: ToolboxLocalizationKeys.opsQuickRefStallTitle.tr(context),
        trigger: ToolboxLocalizationKeys.opsQuickRefStallTrigger.tr(context),
        actions: [
          ToolboxLocalizationKeys.opsQuickRefStallAction1.tr(context),
          ToolboxLocalizationKeys.opsQuickRefStallAction2.tr(context),
          ToolboxLocalizationKeys.opsQuickRefStallAction3.tr(context),
        ],
      ),
      _QuickRefItem(
        title: ToolboxLocalizationKeys.opsQuickRefWindshearTitle.tr(context),
        trigger: ToolboxLocalizationKeys.opsQuickRefWindshearTrigger.tr(
          context,
        ),
        actions: [
          ToolboxLocalizationKeys.opsQuickRefWindshearAction1.tr(context),
          ToolboxLocalizationKeys.opsQuickRefWindshearAction2.tr(context),
          ToolboxLocalizationKeys.opsQuickRefWindshearAction3.tr(context),
        ],
      ),
      _QuickRefItem(
        title: ToolboxLocalizationKeys.opsQuickRefGoAroundTitle.tr(context),
        trigger: ToolboxLocalizationKeys.opsQuickRefGoAroundTrigger.tr(context),
        actions: [
          ToolboxLocalizationKeys.opsQuickRefGoAroundAction1.tr(context),
          ToolboxLocalizationKeys.opsQuickRefGoAroundAction2.tr(context),
          ToolboxLocalizationKeys.opsQuickRefGoAroundAction3.tr(context),
        ],
      ),
      _QuickRefItem(
        title: ToolboxLocalizationKeys.opsQuickRefEngineFailTitle.tr(context),
        trigger: ToolboxLocalizationKeys.opsQuickRefEngineFailTrigger.tr(
          context,
        ),
        actions: [
          ToolboxLocalizationKeys.opsQuickRefEngineFailAction1.tr(context),
          ToolboxLocalizationKeys.opsQuickRefEngineFailAction2.tr(context),
          ToolboxLocalizationKeys.opsQuickRefEngineFailAction3.tr(context),
        ],
      ),
    ];
  }

  @override
  void dispose() {
    _notamController.dispose();
    super.dispose();
  }

  void _filterNotam() {
    final lines = _notamController.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      setState(() => _notamMatches = []);
      return;
    }
    final selected = _selectedTags.isEmpty ? _tags : _selectedTags.toList();
    final matches = lines.where((line) {
      final upper = line.toUpperCase();
      return selected.any(upper.contains);
    }).toList();
    setState(() => _notamMatches = matches);
  }

  String _severity(String line) {
    final upper = line.toUpperCase();
    if (upper.contains('RWY') &&
        (upper.contains('CLSD') || upper.contains('CLOSED'))) {
      return 'high';
    }
    if (upper.contains('ILS') &&
        (upper.contains('U/S') ||
            upper.contains('UNSERVICEABLE') ||
            upper.contains('OUT OF SERVICE'))) {
      return 'high';
    }
    if (upper.contains('CLSD') ||
        upper.contains('CLOSED') ||
        upper.contains('UNSERVICEABLE')) {
      return 'high';
    }
    if (upper.contains('WIP') ||
        upper.contains('WORK') ||
        upper.contains('LIMITED')) {
      return 'medium';
    }
    return 'low';
  }

  Color _severityColor(String level, ThemeData theme) {
    switch (level) {
      case 'high':
        return theme.colorScheme.error;
      case 'medium':
        return Colors.orange;
      default:
        return theme.colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocalizationService>();
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      child: Column(
        children: [
          ToolboxSectionCard(
            title: ToolboxLocalizationKeys.opsNotamSectionTitle.tr(context),
            icon: Icons.fact_check,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tags.map((tag) {
                    final selected = _selectedTags.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: selected,
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _selectedTags.add(tag);
                          } else {
                            _selectedTags.remove(tag);
                          }
                        });
                        _filterNotam();
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppThemeData.spacingMedium),
                TextField(
                  controller: _notamController,
                  minLines: 4,
                  maxLines: 8,
                  decoration: InputDecoration(
                    labelText: ToolboxLocalizationKeys.opsNotamTextLabel.tr(
                      context,
                    ),
                    hintText: ToolboxLocalizationKeys.opsNotamTextHint.tr(
                      context,
                    ),
                    prefixIcon: const Icon(Icons.paste),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppThemeData.spacingMedium),
                ElevatedButton.icon(
                  onPressed: _filterNotam,
                  icon: const Icon(Icons.filter_alt),
                  label: Text(
                    ToolboxLocalizationKeys.opsNotamFilterButton.tr(context),
                  ),
                ),
                const SizedBox(height: AppThemeData.spacingMedium),
                Text(
                  '${ToolboxLocalizationKeys.opsNotamMatchCount.tr(context)}：${_notamMatches.length}',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                ..._notamMatches.map((line) {
                  final severity = _severity(line);
                  final color = _severityColor(severity, theme);
                  final level = switch (severity) {
                    'high' => ToolboxLocalizationKeys.opsSeverityHigh.tr(
                      context,
                    ),
                    'medium' => ToolboxLocalizationKeys.opsSeverityMedium.tr(
                      context,
                    ),
                    _ => ToolboxLocalizationKeys.opsSeverityLow.tr(context),
                  };
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppThemeData.borderRadiusSmall,
                      ),
                      border: Border.all(color: color.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(level),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(line)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: AppThemeData.spacingLarge),
          ToolboxSectionCard(
            title: ToolboxLocalizationKeys.opsQuickRefSectionTitle.tr(context),
            icon: Icons.local_hospital,
            child: Column(
              children: _quickRefs(context)
                  .map(
                    (item) => ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(
                        left: AppThemeData.spacingSmall,
                        right: AppThemeData.spacingSmall,
                        bottom: AppThemeData.spacingSmall,
                      ),
                      title: Text(item.title),
                      subtitle: Text(item.trigger),
                      children: item.actions
                          .map(
                            (action) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• '),
                                  Expanded(child: Text(action)),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickRefItem {
  final String title;
  final String trigger;
  final List<String> actions;

  const _QuickRefItem({
    required this.title,
    required this.trigger,
    required this.actions,
  });
}
