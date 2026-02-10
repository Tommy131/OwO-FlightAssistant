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
import '../../../apps/services/app_core/database_path_service.dart';
import '../../../core/widgets/common/database_selection_dialog.dart';
import '../widgets/setup_guide_database_cards.dart';
import '../widgets/wizard_step_view.dart';
import '../widgets/setup_guide_actions.dart';

class DatabaseStep extends StatefulWidget {
  final VoidCallback onNext;

  const DatabaseStep({super.key, required this.onNext});

  @override
  State<DatabaseStep> createState() => _DatabaseStepState();
}

class _DatabaseStepState extends State<DatabaseStep> {
  String? _lnmPath;
  String? _xplanePath;
  Map<String, String>? _lnmInfo;
  Map<String, String>? _xplaneInfo;
  bool _isDetecting = false;
  final DatabasePathService _databasePathService = DatabasePathService();

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

  @override
  Widget build(BuildContext context) {
    return WizardStepView(
      title: '配置数据源',
      subtitle: '我们需要 Little Navmap 或 X-Plane 的导航数据库来显示机场与航路点。',
      content: Column(
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
      actions: [
        ElevatedButton(
          onPressed: _lnmPath == null && _xplanePath == null
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
