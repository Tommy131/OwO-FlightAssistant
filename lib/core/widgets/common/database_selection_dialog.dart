import 'package:flutter/material.dart';
import '../../../pages/settings/widgets/airac_info_tag.dart';

class DatabaseSelectionDialog extends StatefulWidget {
  final List<Map<String, String>> detectedDbs;
  final String? currentLnmPath;
  final String? currentXPlanePath;
  final Function(String? lnmPath, String? xplanePath) onConfirm;

  const DatabaseSelectionDialog({
    super.key,
    required this.detectedDbs,
    this.currentLnmPath,
    this.currentXPlanePath,
    required this.onConfirm,
  });

  @override
  State<DatabaseSelectionDialog> createState() => _DatabaseSelectionDialogState();
}

class _DatabaseSelectionDialogState extends State<DatabaseSelectionDialog> {
  String? _selectedLnmPath;
  String? _selectedXPlanePath;

  @override
  void initState() {
    super.initState();
    _selectedLnmPath = widget.currentLnmPath;
    _selectedXPlanePath = widget.currentXPlanePath;

    final lnmDbs = widget.detectedDbs.where((db) => db['type']!.contains('Little Navmap')).toList();
    final xplaneDbs = widget.detectedDbs.where((db) => db['type']!.contains('X-Plane')).toList();

    if (_selectedLnmPath == null && lnmDbs.isNotEmpty) {
      _selectedLnmPath = lnmDbs.first['path'];
    }
    if (_selectedXPlanePath == null && xplaneDbs.isNotEmpty) {
      _selectedXPlanePath = xplaneDbs.first['path'];
    }
  }

  Widget _buildDatabaseCard({
    required ThemeData theme,
    required Map<String, String> db,
    required bool isSelected,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected ? theme.colorScheme.primaryContainer.withAlpha(50) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
        ),
        title: Row(
          children: [
            Text('AIRAC ${db['airac']}'),
            if (db['expiry'] != null && db['expiry']!.isNotEmpty) ...[
              const SizedBox(width: 8),
              AiracInfoTag(
                airac: db['airac'],
                expiry: db['expiry'],
                isExpired: db['is_expired'] == 'true',
                showAiracLabel: false,
              ),
            ],
          ],
        ),
        subtitle: Text(
          db['path']!,
          style: const TextStyle(fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lnmDbs = widget.detectedDbs.where((db) => db['type']!.contains('Little Navmap')).toList();
    final xplaneDbs = widget.detectedDbs.where((db) => db['type']!.contains('X-Plane')).toList();

    return AlertDialog(
      title: const Text('选择要使用的数据库'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lnmDbs.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Little Navmap 数据库',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...lnmDbs.map((db) => _buildDatabaseCard(
                      theme: theme,
                      db: db,
                      isSelected: _selectedLnmPath == db['path'],
                      icon: Icons.map_outlined,
                      onTap: () => setState(() => _selectedLnmPath = db['path']),
                    )),
                const Divider(height: 24),
              ],
              if (xplaneDbs.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'X-Plane 导航数据',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...xplaneDbs.map((db) => _buildDatabaseCard(
                      theme: theme,
                      db: db,
                      isSelected: _selectedXPlanePath == db['path'],
                      icon: Icons.flight_takeoff,
                      onTap: () => setState(() => _selectedXPlanePath = db['path']),
                    )),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
          onPressed: () => widget.onConfirm(_selectedLnmPath, _selectedXPlanePath),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
