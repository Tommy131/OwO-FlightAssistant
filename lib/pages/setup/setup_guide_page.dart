import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme_data.dart';
import '../../apps/services/database_path_service.dart';
import '../../core/widgets/common/database_selection_dialog.dart';
import 'widgets/setup_guide_actions.dart';
import 'widgets/setup_guide_database_cards.dart';
import 'widgets/setup_guide_header.dart';

class SetupGuidePage extends StatefulWidget {
  final VoidCallback onSetupComplete;

  const SetupGuidePage({super.key, required this.onSetupComplete});

  @override
  State<SetupGuidePage> createState() => _SetupGuidePageState();
}

class _SetupGuidePageState extends State<SetupGuidePage> {
  String? _lnmPath;
  String? _xplanePath;
  Map<String, String>? _lnmInfo;
  Map<String, String>? _xplaneInfo;
  bool _isValidating = false;
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
            const SnackBar(
              content: Text('⚠️ 未找到模拟器或 Little Navmap 数据路径'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检测失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDetecting = false);
      }
    }
  }

  Future<void> _pickLNMPath() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择 Little Navmap 数据库文件 (little_navmap_navigraph.sqlite)',
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      setState(() => _isValidating = true);
      final info = await _databasePathService.saveLnmPath(path);
      setState(() => _isValidating = false);

      if (mounted) {
        if (info != null) {
          setState(() {
            _lnmPath = path;
            _lnmInfo = info;
          });
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('❌ 无效的 Little Navmap 数据库文件'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _pickXPlanePath() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择 X-Plane 导航数据文件 (earth_nav.dat)',
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      setState(() => _isValidating = true);
      final info = await _databasePathService.saveXPlanePath(path);
      setState(() => _isValidating = false);

      if (mounted) {
        if (info != null) {
          setState(() {
            _xplanePath = path;
            _xplaneInfo = info;
          });
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('❌ 无效的 X-Plane 导航数据文件'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _completeSetup() {
    if (_lnmPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ 请先配置 Little Navmap 数据库'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    widget.onSetupComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              padding: const EdgeInsets.all(AppThemeData.spacingLarge),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SetupGuideHeader(),
                  const SizedBox(height: 20),
                  SetupGuideAutoDetectButton(
                    isDetecting: _isDetecting,
                    onAutoDetect: _autoDetectPaths,
                  ),
                  const SizedBox(height: 30),
                  SetupGuideDatabaseCards(
                    lnmPath: _lnmPath,
                    xplanePath: _xplanePath,
                    lnmInfo: _lnmInfo,
                    xplaneInfo: _xplaneInfo,
                    onSelectLnm: _pickLNMPath,
                    onSelectXPlane: _pickXPlanePath,
                  ),
                  const SizedBox(height: 32),
                  SetupGuideActionBar(
                    isValidating: _isValidating,
                    onComplete: _completeSetup,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
