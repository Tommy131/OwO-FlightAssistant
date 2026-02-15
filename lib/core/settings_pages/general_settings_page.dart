import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../services/persistence_service.dart';
import '../services/bootstrap_service.dart';
import '../services/localization_service.dart';
import '../localization/localization_keys.dart';
import '../theme/app_theme_data.dart';
import '../utils/logger.dart';
import '../utils/update_checker.dart';
import '../widgets/common/snack_bar.dart';
import '../widgets/common/storage_path_tile.dart';
import '../widgets/common/dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class GeneralSettingsPage extends StatefulWidget {
  final VoidCallback onBack;
  const GeneralSettingsPage({super.key, required this.onBack});

  @override
  State<GeneralSettingsPage> createState() => _GeneralSettingsPageState();
}

class _GeneralSettingsPageState extends State<GeneralSettingsPage> {
  String? _currentPath;
  bool _logEnabled = true;
  double _logMaxSizeMb = 5;

  @override
  void initState() {
    super.initState();
    _currentPath = PersistenceService().rootPath;
    final settings = AppLogger.loadSettings();
    _logEnabled = settings.enabled;
    _logMaxSizeMb = settings.maxFileSizeMb.toDouble();
  }

  Future<void> _updatePath(String newPath) async {
    if (_currentPath == newPath) return;

    final result = await showAdvancedConfirmDialog(
      context: context,
      title: LocalizationKeys.storageLocation.tr(context),
      content: LocalizationKeys.storageLocationChangeConfirm.tr(context),
      icon: Icons.warning_amber_rounded,
      confirmText: LocalizationKeys.confirm.tr(context),
      cancelText: LocalizationKeys.cancel.tr(context),
    );

    if (result == true) {
      await PersistenceService().init(customPath: newPath);
      final finalPath = PersistenceService().rootPath!;

      await PersistenceService().set('data_root_path', finalPath);
      await AppLogger.init();

      setState(() {
        _currentPath = finalPath;
      });

      if (mounted) {
        SnackBarHelper.showSuccess(
          context,
          LocalizationKeys.storageLocationChangeSuccess.tr(context),
        );
      }
    }
  }

  Future<void> _updateLogEnabled(bool value) async {
    setState(() {
      _logEnabled = value;
    });
    await AppLogger.updateSettings(enabled: value);
  }

  Future<void> _updateLogMaxSize(double value) async {
    final rounded = value.round().clamp(1, 1024);
    setState(() {
      _logMaxSizeMb = rounded.toDouble();
    });
    await AppLogger.updateSettings(maxFileSizeMb: rounded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: LocalizationKeys.back.tr(context),
                onPressed: widget.onBack,
              ),
              const SizedBox(width: AppThemeData.spacingSmall),
              Text(
                LocalizationKeys.generalSettings.tr(context),
                style: theme.textTheme.headlineMedium,
              ),
            ],
          ),
          const SizedBox(height: AppThemeData.spacingMedium),

          _buildLanguageSection(theme),
          const SizedBox(height: AppThemeData.spacingSmall),

          _buildStorageSection(theme),
          const SizedBox(height: AppThemeData.spacingSmall),

          _buildLogSection(theme),
          const SizedBox(height: AppThemeData.spacingSmall),

          _buildUpdateCheckSection(theme),
          const SizedBox(height: AppThemeData.spacingSmall),
          _buildDangerSection(context, theme),

          if (kDebugMode) ...[
            const SizedBox(height: AppThemeData.spacingSmall),

            const Padding(
              padding: EdgeInsets.symmetric(
                vertical: AppThemeData.spacingSmall,
              ),
              child: Text(
                'Debug Mode',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildBootstrapSection(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildLanguageSection(ThemeData theme) {
    final localizationService = context.watch<LocalizationService>();
    final languages = localizationService.supportedLanguages;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppThemeData.borderRadiusSmall,
                    ),
                  ),
                  child: Icon(
                    Icons.language,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppThemeData.spacingSmall),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocalizationKeys.language.tr(context),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        LocalizationKeys.selectLanguage.tr(context),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: languages.map((lang) {
                final isSelected =
                    localizationService.currentLanguageCode == lang['code'];
                return ChoiceChip(
                  label: Text(lang['name']!),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      final parts = lang['code']!.split('_');
                      localizationService.setLocale(Locale(parts[0], parts[1]));
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateCheckSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppThemeData.borderRadiusSmall,
                    ),
                  ),
                  child: Icon(
                    Icons.system_update_outlined,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppThemeData.spacingSmall),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocalizationKeys.updateCheck.tr(context),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        LocalizationKeys.updateCheckDesc.tr(context),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => UpdateChecker.checkAndShowUpdate(context),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(LocalizationKeys.checkForUpdates.tr(context)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppThemeData.borderRadiusSmall,
                    ),
                  ),
                  child: Icon(
                    Icons.folder_open,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppThemeData.spacingSmall),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocalizationKeys.storageLocation.tr(context),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        LocalizationKeys.storageLocationDesc.tr(context),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            StoragePathTile(
              currentPath: _currentPath,
              onPathSelected: _updatePath,
              showHeader: false,
              contentPadding: EdgeInsets.zero,
              enableTap: false,
              showChangeButton: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppThemeData.borderRadiusSmall,
                    ),
                  ),
                  child: Icon(
                    Icons.description_outlined,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppThemeData.spacingSmall),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocalizationKeys.logSettings.tr(context),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        LocalizationKeys.logSettingsDesc.tr(context),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Switch(value: _logEnabled, onChanged: _updateLogEnabled),
              ],
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            Row(
              children: [
                Expanded(
                  child: Text(
                    LocalizationKeys.logMaxSize.tr(context),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_logMaxSizeMb.toInt()} MB',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: _logMaxSizeMb,
              min: 1,
              max: 50,
              divisions: 49,
              label: '${_logMaxSizeMb.toInt()} MB',
              onChanged: _logEnabled
                  ? (value) => setState(() => _logMaxSizeMb = value)
                  : null,
              onChangeEnd: _logEnabled ? _updateLogMaxSize : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerSection(BuildContext context, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(
                      AppThemeData.borderRadiusSmall,
                    ),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppThemeData.spacingSmall),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocalizationKeys.dangerZone.tr(context),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        LocalizationKeys.resetAppDesc.tr(context),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            _buildResetButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildResetButton(BuildContext context) {
    final label =
        '${LocalizationKeys.resetApp.tr(context)}. ${LocalizationKeys.resetAppDesc.tr(context)}';
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => _handleResetApp(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
              color: Colors.red.withValues(alpha: 0.05),
            ),
            child: Row(
              children: [
                Icon(Icons.restore, color: Colors.red.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocalizationKeys.resetApp.tr(context),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        LocalizationKeys.resetAppDesc.tr(context),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: Colors.red.shade700,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleResetApp(BuildContext context) async {
    final firstConfirm = await showAdvancedConfirmDialog(
      context: context,
      title: LocalizationKeys.resetAppConfirmTitle.tr(context),
      content: LocalizationKeys.resetAppConfirmContent.tr(context),
      icon: Icons.warning_amber_rounded,
      confirmColor: Colors.orange,
      confirmText: LocalizationKeys.confirm.tr(context),
      cancelText: LocalizationKeys.cancel.tr(context),
    );

    if (firstConfirm != true) return;

    final secondConfirm = await showAdvancedConfirmDialog(
      context: context,
      title: LocalizationKeys.confirm.tr(context),
      content: LocalizationKeys.resetAppConfirmContent.tr(context),
      icon: Icons.error_outline,
      confirmColor: Colors.red,
      confirmText: LocalizationKeys.confirm.tr(context),
      cancelText: LocalizationKeys.cancel.tr(context),
    );

    if (secondConfirm != true) return;

    try {
      if (!mounted) return;

      showLoadingDialog(
        context: context,
        title: '${LocalizationKeys.resetApp.tr(context)}...',
        content: LocalizationKeys.loading.tr(context),
      );

      await PersistenceService().resetApp();

      if (!mounted) return;

      Navigator.of(context).pop();

      await showAdvancedConfirmDialog(
        context: context,
        title: LocalizationKeys.success.tr(context),
        content: LocalizationKeys.resetSuccess.tr(context),
        icon: Icons.check_circle_outline,
        confirmColor: Colors.green,
        confirmText: LocalizationKeys.confirm.tr(context),
        cancelText: '',
      );

      if (mounted) {
        final executable = Platform.resolvedExecutable;
        await Process.start(executable, []);
        await windowManager.setPreventClose(false);
        await windowManager.close();
      }
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).pop();
      SnackBarHelper.showError(context, '重置失败: $e');
    }
  }

  Widget _buildBootstrapSection(ThemeData theme) {
    final bootstrap = BootstrapService();
    final bootstrapPath = bootstrap.bootstrapFilePath;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppThemeData.borderRadiusSmall,
                    ),
                  ),
                  child: const Icon(
                    Icons.settings_suggest,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppThemeData.spacingSmall),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocalizationKeys.bootstrapConfig.tr(context),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        LocalizationKeys.bootstrapConfigDesc.tr(context),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.file_present,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          bootstrapPath ?? 'Unknown',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openBootstrapDirectory(bootstrapPath),
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: Text(LocalizationKeys.openDirectory.tr(context)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBootstrapDirectory(String? filePath) async {
    if (filePath == null) return;
    final directory = p.dirname(filePath);
    if (await Directory(directory).exists()) {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [directory]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [directory]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [directory]);
      }
    }
  }
}
