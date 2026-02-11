/*
 *        _____   _          __  _____   _____   _       _____   _____
 *      /  _  \ | |        / / /  _  \ |  _  \ | |     /  _  \ /  ___|
 *      | | | | | |  __   / /  | | | | | |_| | | |     | | | | | |
 *      | | | | | | /  | / /   | | | | |  _  { | |     | | | | | |   _
 *      | |_| | | |/   |/ /    | |_| | | |_| | | |___  | |_| | | |_| |
 *      \_____/ |___/|___/     \_____/ |_____/ |_____| \_____/ \_____/
 *
 *  Copyright (c) 2023 by OwOTeam-DGMT (OwOBlog).
 * @Date         : 2025-10-22
 * @Author       : HanskiJay
 * @LastEditors  : HanskiJay
 * @LastEditTime : 2025-10-22
 * @E-Mail       : support@owoblog.com
 * @Telegram     : https://t.me/HanskiJay
 * @GitHub       : https://github.com/Tommy131
 */

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../apps/services/airport_detail_service.dart';
import '../../../apps/services/app_core/database_loader.dart';
import '../../../apps/services/app_core/database_path_service.dart';
import '../../../core/services/persistence/app_storage_paths.dart';
import '../../../core/services/persistence/persistence_service.dart';
import '../../../core/widgets/common/database_selection_dialog.dart';
import '../../settings/widgets/settings_widgets.dart';
import '../widgets/setup_guide_database_cards.dart';
import '../widgets/wizard_step_view.dart';
import '../widgets/setup_guide_actions.dart';

class DatabaseStep extends StatefulWidget {
  final VoidCallback onNext;

  const DatabaseStep({super.key, required this.onNext});

  @override
  State<DatabaseStep> createState() => _DatabaseStepState();
}

class _DatabaseStepState extends State<DatabaseStep>
    with AutomaticKeepAliveClientMixin {
  String? _appDataPath;
  String? _lnmPath;
  String? _xplanePath;
  Map<String, String>? _lnmInfo;
  Map<String, String>? _xplaneInfo;
  bool _isDetecting = false;
  bool _isUpdatingPath = false;
  bool _isAppDataPathConfirmed = false;
  final DatabasePathService _databasePathService = DatabasePathService();
  final PersistenceService _persistence = PersistenceService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadAppDataPath();
    await _loadSavedDatabasePaths();
    if (mounted) {
      setState(() {
        _isAppDataPathConfirmed =
            _persistence.getBool('app_data_path_confirmed') ?? false;
      });
    }
  }

  Future<void> _loadSavedDatabasePaths() async {
    final settings = DatabaseSettingsService();
    final lnmPath = await settings.getString(
      DatabaseSettingsService.lnmPathKey,
    );
    final xplanePath = await settings.getString(
      DatabaseSettingsService.xplanePathKey,
    );

    if (lnmPath != null) {
      final info = await _databasePathService.getDatabaseInfo(
        lnmPath,
        AirportDataSource.lnmData,
      );
      if (mounted) {
        setState(() {
          _lnmPath = lnmPath;
          _lnmInfo = info;
        });
      }
    }

    if (xplanePath != null) {
      final info = await _databasePathService.getDatabaseInfo(
        xplanePath,
        AirportDataSource.xplaneData,
      );
      if (mounted) {
        setState(() {
          _xplanePath = xplanePath;
          _xplaneInfo = info;
        });
      }
    }
  }

  Future<void> _loadAppDataPath() async {
    final baseDir = await AppStoragePaths.getBaseDirectory(
      createIfMissing: false,
    );
    if (mounted) {
      setState(() => _appDataPath = baseDir.path);
    }
  }

  Future<void> _autoDetectPaths() async {
    setState(() => _isDetecting = true);
    try {
      final detectedDbs = await _databasePathService.detectDatabases();
      if (detectedDbs.isNotEmpty) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => DatabaseSelectionDialog(
              detectedDbs: detectedDbs,
              currentLnmPath: _lnmPath,
              currentXPlanePath: _xplanePath,
              onConfirm: (lnmPath, xplanePath) async {
                final result = await _databasePathService.saveSelectedPaths(
                  lnmPath: lnmPath,
                  xplanePath: xplanePath,
                );
                setState(() {
                  if (result.lnmPath != null) {
                    _lnmPath = result.lnmPath;
                    _lnmInfo = result.lnmInfo;
                  }
                  if (result.xplanePath != null) {
                    _xplanePath = result.xplanePath;
                    _xplaneInfo = result.xplaneInfo;
                  }
                });
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠️ 未找到模拟器或 Little Navmap 数据路径')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('检测失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isDetecting = false);
    }
  }

  Future<void> _pickLNMPath() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择 Little Navmap 数据库文件',
      type: FileType.any,
    );
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final info = await _databasePathService.saveLnmPath(path);
      if (mounted && info != null) {
        setState(() {
          _lnmPath = path;
          _lnmInfo = info;
        });
      }
    }
  }

  Future<void> _pickXPlanePath() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择 X-Plane 导航数据文件',
      type: FileType.any,
    );
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final info = await _databasePathService.saveXPlanePath(path);
      if (mounted && info != null) {
        setState(() {
          _xplanePath = path;
          _xplaneInfo = info;
        });
      }
    }
  }

  Future<void> _pickAppDataPath() async {
    final messenger = ScaffoldMessenger.of(context);
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择应用数据存储目录',
      initialDirectory: _appDataPath,
    );
    if (selected == null) return;

    setState(() {
      _isUpdatingPath = true;
      _isAppDataPathConfirmed = false;
    });
    try {
      final oldBase = await AppStoragePaths.getBaseDirectory();
      await AppStoragePaths.setCustomBaseDirectory(selected);
      final newBase = await AppStoragePaths.getBaseDirectory();
      await AppStoragePaths.migrateBaseDirectory(oldBase, newBase);
      await _persistence.switchBaseDirectory(newBase);
      await _persistence.setBool('app_data_path_confirmed', false);
      if (mounted) {
        setState(() => _appDataPath = newBase.path);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('✅ 应用数据存储路径已更新，请点击确认'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('修改失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingPath = false);
    }
  }

  Future<void> _confirmAppDataPath() async {
    await _persistence.setBool('app_data_path_confirmed', true);
    if (mounted) {
      setState(() => _isAppDataPathConfirmed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 应用数据存储目录已确认'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return WizardStepView(
      title: '配置数据源',
      subtitle: '我们需要 Little Navmap 或 X-Plane 的导航数据库来显示机场与航路点。',
      content: Column(
        children: [
          // 首先配置应用数据存储目录
          SettingsCard(
            title: '应用数据存储目录',
            subtitle: '默认使用应用根目录，可按需更改',
            icon: Icons.folder_shared_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isAppDataPathConfirmed
                          ? Colors.green.withValues(alpha: 0.5)
                          : Colors.orange.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    _appDataPath ?? '正在获取...',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: _isAppDataPathConfirmed
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_isAppDataPathConfirmed)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isUpdatingPath ? null : _pickAppDataPath,
                      icon: _isUpdatingPath
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.drive_folder_upload_rounded,
                              size: 18,
                            ),
                      label: Text(_isUpdatingPath ? '更新中...' : '选择存储目录'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isUpdatingPath ? null : _pickAppDataPath,
                          icon: _isUpdatingPath
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.drive_folder_upload_rounded,
                                  size: 18,
                                ),
                          label: Text(_isUpdatingPath ? '更新中...' : '选择存储目录'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _confirmAppDataPath,
                        icon: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                        ),
                        label: const Text('确认路径'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.withValues(alpha: 0.1),
                          foregroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // 限制后续配置
          Opacity(
            opacity: _isAppDataPathConfirmed ? 1.0 : 0.5,
            child: IgnorePointer(
              ignoring: !_isAppDataPathConfirmed,
              child: Column(
                children: [
                  SetupGuideAutoDetectButton(
                    isDetecting: _isDetecting,
                    onAutoDetect: _autoDetectPaths,
                  ),
                  const SizedBox(height: 24),
                  SetupGuideDatabaseCards(
                    lnmPath: _lnmPath,
                    xplanePath: _xplanePath,
                    lnmInfo: _lnmInfo,
                    xplaneInfo: _xplaneInfo,
                    onSelectLnm: _pickLNMPath,
                    onSelectXPlane: _pickXPlanePath,
                  ),
                ],
              ),
            ),
          ),
          if (!_isAppDataPathConfirmed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '请先确认应用数据存储目录，再进行后续配置',
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed:
              !_isAppDataPathConfirmed ||
                  (_lnmPath == null && _xplanePath == null)
              ? null
              : widget.onNext,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('下一步'),
        ),
      ],
    );
  }
}
