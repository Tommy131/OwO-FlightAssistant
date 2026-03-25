import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme_data.dart';
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
    'TWY',
    'NAV',
    'OBST',
    'WIP',
    'FUEL',
    'LIGHT',
    'CLSD',
  ];

  static const List<_QuickRefItem> _quickRefs = [
    _QuickRefItem(
      title: '失速警告',
      trigger: 'Airspeed 下降并触发失速告警',
      actions: [
        '减小迎角，解除抬头趋势',
        '平稳加油门并保持机翼水平',
        '按程序逐步收回减阻构型',
      ],
    ),
    _QuickRefItem(
      title: '风切变逃逸',
      trigger: '近地面风速或垂直速度突变',
      actions: [
        '按风切变口令执行最大持续推力',
        '保持机翼水平，目标姿态约 15°',
        '除非撞地风险，不要改变构型',
      ],
    ),
    _QuickRefItem(
      title: '复飞程序',
      trigger: '进近不稳定或跑道条件不满足',
      actions: [
        '执行 TOGA 推力并建立正爬升',
        '按标准复飞高度和航向执行',
        '确认构型并完成复飞检查单',
      ],
    ),
    _QuickRefItem(
      title: '发动机失效（起飞后）',
      trigger: '起飞后出现推力不对称',
      actions: [
        '方向舵保持航向并控制姿态',
        '维持安全速度并确认单发程序',
        '根据场景决定继续爬升或返航',
      ],
    ),
  ];

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
    if (upper.contains('CLSD') ||
        upper.contains('CLOSED') ||
        upper.contains('UNSERVICEABLE')) {
      return '高';
    }
    if (upper.contains('WIP') ||
        upper.contains('WORK') ||
        upper.contains('LIMITED')) {
      return '中';
    }
    return '低';
  }

  Color _severityColor(String level, ThemeData theme) {
    switch (level) {
      case '高':
        return theme.colorScheme.error;
      case '中':
        return Colors.orange;
      default:
        return theme.colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      child: Column(
        children: [
          ToolboxSectionCard(
            title: 'NOTAM 关键筛选',
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
                  decoration: const InputDecoration(
                    labelText: 'NOTAM 文本',
                    hintText: '粘贴多行 NOTAM 文本',
                    prefixIcon: Icon(Icons.paste),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppThemeData.spacingMedium),
                ElevatedButton.icon(
                  onPressed: _filterNotam,
                  icon: const Icon(Icons.filter_alt),
                  label: const Text('筛选关键项'),
                ),
                const SizedBox(height: AppThemeData.spacingMedium),
                Text(
                  '匹配结果：${_notamMatches.length} 条',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppThemeData.spacingSmall),
                ..._notamMatches.map((line) {
                  final level = _severity(line);
                  final color = _severityColor(level, theme);
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
            title: '应急速查卡',
            icon: Icons.local_hospital,
            child: Column(
              children: _quickRefs
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
