import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme_data.dart';
import '../../../apps/services/airport_detail_service.dart';
import '../settings/widgets/data_path_item.dart';
import '../settings/widgets/settings_widgets.dart';
import '../../apps/services/auto_detect/auto_detect_service.dart';
import '../../core/widgets/common/database_selection_dialog.dart';

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
  final AirportDetailService _airportService = AirportDetailService();
  final AutoDetectService _autoDetectService = AutoDetectService();

  static const String _lnmPathKey = 'lnm_nav_data_path';
  static const String _xplanePathKey = 'xplane_nav_data_path';

  Future<void> _autoDetectPaths() async {
    setState(() => _isDetecting = true);
    try {
      final detectedDbs = await _autoDetectService.detectPaths();
      if (detectedDbs.isNotEmpty) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => DatabaseSelectionDialog(
              detectedDbs: detectedDbs,
              currentLnmPath: _lnmPath,
              currentXPlanePath: _xplanePath,
              onConfirm: (lnmPath, xplanePath) async {
                final prefs = await SharedPreferences.getInstance();
                if (lnmPath != null) {
                  await prefs.setString(_lnmPathKey, lnmPath);
                  final info = await _airportService.getDatabaseInfo(
                    lnmPath,
                    AirportDataSource.lnmData,
                  );
                  setState(() {
                    _lnmPath = lnmPath;
                    _lnmInfo = info;
                  });
                }
                if (xplanePath != null) {
                  await prefs.setString(_xplanePathKey, xplanePath);
                  final info = await _airportService.getDatabaseInfo(
                    xplanePath,
                    AirportDataSource.xplaneData,
                  );
                  setState(() {
                    _xplanePath = xplanePath;
                    _xplaneInfo = info;
                  });
                }
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
      final isValid = await _airportService.validateLnmDatabase(path);
      setState(() => _isValidating = false);

      if (mounted) {
        if (isValid) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_lnmPathKey, path);
          final info = await _airportService.getDatabaseInfo(
            path,
            AirportDataSource.lnmData,
          );
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
      final isValid = await _airportService.validateXPlaneData(path);
      setState(() => _isValidating = false);

      if (mounted) {
        if (isValid) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_xplanePathKey, path);
          final info = await _airportService.getDatabaseInfo(
            path,
            AirportDataSource.xplaneData,
          );
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
    final theme = Theme.of(context);
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
                  Icon(
                    Icons.flight_takeoff_rounded,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '欢迎使用 OwO Flight Assistant',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '首次启动需要配置导航数据库以获取机场信息',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 20),

                  OutlinedButton.icon(
                    onPressed: _isDetecting ? null : _autoDetectPaths,
                    icon: _isDetecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search_rounded),
                    label: Text(_isDetecting ? '正在自动识别中...' : '自动识别本地已安装的数据库'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  SettingsCard(
                    title: 'Little Navmap 数据库 (必填)',
                    subtitle: '提供全球机场、跑道和导航设备信息',
                    icon: Icons.map_rounded,
                    child: DataPathItem(
                      label: '选择 .sqlite 数据库文件',
                      path: _lnmPath,
                      airac: _lnmInfo?['airac'],
                      expiry: _lnmInfo?['expiry'],
                      isExpired: _lnmInfo?['is_expired'] == 'true',
                      onSelect: _pickLNMPath,
                    ),
                  ),

                  SettingsCard(
                    title: 'X-Plane 导航数据 (可选)',
                    subtitle: '配置后可获得更准确的 X-Plane 内部数据',
                    icon: Icons.airplanemode_active_rounded,
                    child: DataPathItem(
                      label: '选择 earth_nav.dat 文件',
                      path: _xplanePath,
                      airac: _xplaneInfo?['airac'],
                      expiry: _xplaneInfo?['expiry'],
                      isExpired: _xplaneInfo?['is_expired'] == 'true',
                      onSelect: _pickXPlanePath,
                    ),
                  ),

                  const SizedBox(height: 32),
                  if (_isValidating)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: CircularProgressIndicator(),
                    ),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _completeSetup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '完成配置并进入应用',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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
