import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme_data.dart';
import 'widgets/settings_widgets.dart';
import 'widgets/data_path_item.dart';

/// 数据路径设置页面
class DataPathSettingsPage extends StatefulWidget {
  final VoidCallback? onBack;

  const DataPathSettingsPage({super.key, this.onBack});

  @override
  State<DataPathSettingsPage> createState() => _DataPathSettingsPageState();
}

class _DataPathSettingsPageState extends State<DataPathSettingsPage> {
  String? _xplanePath;
  String? _msfsPath;
  String? _airportDbToken;
  String? _appDataPath;
  int _metarCacheExpiry = 60; // 默认 60 分钟

  bool _isLoading = true;
  bool _isDetecting = false;

  final TextEditingController _tokenController = TextEditingController();

  static const String _xplanePathKey = 'xplane_nav_data_path';
  static const String _msfsPathKey = 'msfs_nav_data_path';
  static const String _airportDbTokenKey = 'airportdb_token';
  static const String _metarExpiryKey = 'metar_cache_expiry';

  @override
  void initState() {
    super.initState();
    _loadSavedPaths();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPaths() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final appDocDir = await getApplicationDocumentsDirectory();

    setState(() {
      _xplanePath = prefs.getString(_xplanePathKey);
      _msfsPath = prefs.getString(_msfsPathKey);
      _airportDbToken = prefs.getString(_airportDbTokenKey);
      _tokenController.text = _airportDbToken ?? '';
      _metarCacheExpiry = prefs.getInt(_metarExpiryKey) ?? 60;
      _appDataPath = appDocDir.path;
      _isLoading = false;
    });
  }

  Future<void> _autoDetectPaths() async {
    setState(() => _isDetecting = true);

    try {
      String? xplanePath;
      String? msfsPath;

      if (Platform.isWindows) {
        final possibleXPlanePaths = [
          r'C:\X-Plane 12\Resources\default data\earth_nav.dat',
          r'C:\X-Plane 11\Resources\default data\earth_nav.dat',
          r'D:\X-Plane 12\Resources\default data\earth_nav.dat',
          r'D:\X-Plane 11\Resources\default data\earth_nav.dat',
        ];

        for (final path in possibleXPlanePaths) {
          if (await File(path).exists()) {
            xplanePath = path;
            break;
          }
        }

        final username = Platform.environment['USERNAME'] ?? 'User';
        final possibleMSFSPaths = [
          'C:\\Users\\$username\\AppData\\Local\\Packages\\Microsoft.FlightSimulator_8wekyb3d8bbwe\\LocalCache',
          'C:\\Users\\$username\\AppData\\Roaming\\Microsoft Flight Simulator',
        ];

        for (final path in possibleMSFSPaths) {
          if (await Directory(path).exists()) {
            msfsPath = path;
            break;
          }
        }
      } else if (Platform.isMacOS) {
        final possibleXPlanePaths = [
          '/Applications/X-Plane 12/Resources/default data/earth_nav.dat',
          '/Applications/X-Plane 11/Resources/default data/earth_nav.dat',
        ];

        for (final path in possibleXPlanePaths) {
          if (await File(path).exists()) {
            xplanePath = path;
            break;
          }
        }
      }

      if (xplanePath != null || msfsPath != null) {
        final prefs = await SharedPreferences.getInstance();
        if (xplanePath != null)
          await prefs.setString(_xplanePathKey, xplanePath);
        if (msfsPath != null) await prefs.setString(_msfsPathKey, msfsPath);

        setState(() {
          if (xplanePath != null) _xplanePath = xplanePath;
          if (msfsPath != null) _msfsPath = msfsPath;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ 自动检测成功！'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ 未找到模拟器数据路径，请手动选择'),
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
      setState(() => _isDetecting = false);
    }
  }

  Future<void> _pickXPlanePath() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择 X-Plane 导航数据文件 (earth_nav.dat)',
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_xplanePathKey, path);
      setState(() => _xplanePath = path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('X-Plane 路径已保存'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _pickMSFSPath() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择 MSFS 数据目录',
    );
    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_msfsPathKey, result);
      setState(() => _msfsPath = result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('MSFS 路径已保存'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_airportDbTokenKey, token);
    setState(() => _airportDbToken = token);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Token 已保存'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _updateMetarExpiry(double value) async {
    final expiry = value.toInt();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_metarExpiryKey, expiry);
    setState(() => _metarCacheExpiry = expiry);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('数据源配置'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBack,
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        children: [
          _buildAutoDetectSection(),
          _buildNavDataSection(),
          _buildApiSection(),
          _buildCacheSection(theme),
          _buildStorageSection(theme),
        ],
      ),
    );
  }

  Widget _buildAutoDetectSection() {
    return SettingsCard(
      title: '快速设置',
      subtitle: '尝试自动检测系统中已安装的模拟器数据路径',
      icon: Icons.auto_awesome_rounded,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isDetecting ? null : _autoDetectPaths,
          icon: _isDetecting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.search_rounded),
          label: Text(_isDetecting ? '检测中...' : '自动检测路径'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                AppThemeData.borderRadiusSmall,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavDataSection() {
    return SettingsCard(
      title: '导航数据',
      subtitle: '本地导航数据库文件路径',
      icon: Icons.map_rounded,
      child: Column(
        children: [
          DataPathItem(
            label: 'X-Plane 11/12 (earth_nav.dat)',
            path: _xplanePath,
            onSelect: _pickXPlanePath,
          ),
          const SizedBox(height: AppThemeData.spacingMedium),
          DataPathItem(
            label: 'MSFS 2020/2024 (LocalCache)',
            path: _msfsPath,
            onSelect: _pickMSFSPath,
          ),
        ],
      ),
    );
  }

  Widget _buildApiSection() {
    return SettingsCard(
      title: 'API 配置',
      subtitle: '用于获取在线数据的 API 令牌',
      icon: Icons.api_rounded,
      child: SettingsInputField(
        label: 'AirportDB API Token',
        hint: '输入您的 API Token',
        controller: _tokenController,
        icon: Icons.key_rounded,
        obscureText: true,
        onSave: () => _saveToken(_tokenController.text),
        helperText: '用于访问 airportdb.io (可选)',
      ),
    );
  }

  Widget _buildCacheSection(ThemeData theme) {
    return SettingsCard(
      title: '缓存设置',
      subtitle: '配置实时数据的自动更新频率',
      icon: Icons.history_toggle_off_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '气象报文过期时间',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_metarCacheExpiry 分钟',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '当报文时间超过该值时，系统将自动重新获取最新的 METAR 报文。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          Slider(
            value: _metarCacheExpiry.toDouble(),
            min: 5,
            max: 180,
            divisions: 35,
            label: '$_metarCacheExpiry 分钟',
            onChanged: _updateMetarExpiry,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('5 分钟', style: theme.textTheme.labelSmall),
              Text('180 分钟', style: theme.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStorageSection(ThemeData theme) {
    return SettingsCard(
      title: '应用存储',
      subtitle: '应用程序内部数据存储路径',
      icon: Icons.folder_shared_rounded,
      child: InkWell(
        onTap: () async {
          if (_appDataPath != null) {
            final uri = Uri.directory(_appDataPath!);
            if (await canLaunchUrl(uri)) await launchUrl(uri);
          }
        },
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.1,
            ),
            borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
            border: Border.all(
              color: AppThemeData.getBorderColor(theme).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _appDataPath ?? '正在获取...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '点击在文件管理器中打开',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
