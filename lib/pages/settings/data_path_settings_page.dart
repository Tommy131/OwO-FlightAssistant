import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme_data.dart';
import 'widgets/settings_widgets.dart';
import 'widgets/data_path_item.dart';

import '../../apps/services/airport_detail_service.dart';
import '../../apps/services/app_core/database_path_service.dart';
import '../../core/utils/logger.dart';
import '../../core/widgets/common/database_selection_dialog.dart';
import '../../core/services/persistence/app_storage_paths.dart';
import '../../core/services/persistence/persistence_service.dart';
import '../../apps/services/app_core/database_loader.dart';

/// 数据路径设置页面
class DataPathSettingsPage extends StatefulWidget {
  final VoidCallback? onBack;

  const DataPathSettingsPage({super.key, this.onBack});

  @override
  State<DataPathSettingsPage> createState() => _DataPathSettingsPageState();
}

class _DataPathSettingsPageState extends State<DataPathSettingsPage> {
  String? _xplanePath;
  String? _lnmPath;
  Map<String, String>? _xplaneInfo;
  Map<String, String>? _lnmInfo;
  String? _airportDbToken;
  String? _appDataPath;
  int _metarCacheExpiry = 60; // 默认 60 分钟
  int _airportDataExpiry = 30; // 默认 30 天
  int _tokenThreshold = 5000;
  int _tokenCount = 0;
  bool _fileLoggingEnabled = false;
  int _logRotationThresholdMb = 2; // 默认 2MB

  bool _clearMetarCache = true;
  bool _clearAirportCache = true;

  bool _isLoading = true;
  bool _isDetecting = false;
  bool _isValidating = false;
  bool _needsResetConfirmation = false;
  bool _needsClearConfirmation = false;

  final TextEditingController _tokenController = TextEditingController();
  final AirportDetailService _airportService = AirportDetailService();
  final DatabasePathService _databasePathService = DatabasePathService();
  final PersistenceService _persistence = PersistenceService();

  static const String _airportDbTokenKey = 'airportdb_token';
  static const String _metarExpiryKey = 'metar_cache_expiry';
  static const String _airportExpiryKey = 'airport_data_expiry';
  static const String _tokenThresholdKey = 'token_consumption_threshold';
  static const String _tokenCountKey = 'token_consumption_count';

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
    await DatabaseSettingsService().ensureSynced();

    // Updated to use _persistence
    final baseDir = await AppStoragePaths.getBaseDirectory();

    final xplanePath = _persistence.getString(
      DatabasePathService.xplanePathKey,
    );
    final lnmPath = _persistence.getString(DatabasePathService.lnmPathKey);

    Map<String, String>? xplaneInfo;
    Map<String, String>? lnmInfo;

    if (xplanePath != null && await File(xplanePath).exists()) {
      xplaneInfo = await _databasePathService.getDatabaseInfo(
        xplanePath,
        AirportDataSource.xplaneData,
      );
    }

    if (lnmPath != null && await File(lnmPath).exists()) {
      lnmInfo = await _databasePathService.getDatabaseInfo(
        lnmPath,
        AirportDataSource.lnmData,
      );
    }

    final fileLoggingEnabled = await AppLogger.isFileLoggingEnabled();
    final logRotationThreshold = await AppLogger.getLogRotationThreshold();

    setState(() {
      _xplanePath = xplanePath;
      _lnmPath = lnmPath;
      _xplaneInfo = xplaneInfo;
      _lnmInfo = lnmInfo;
      _airportDbToken = _persistence.getString(_airportDbTokenKey);
      _tokenController.text = _airportDbToken ?? '';
      _metarCacheExpiry = _persistence.getInt(_metarExpiryKey) ?? 60;
      _airportDataExpiry = _persistence.getInt(_airportExpiryKey) ?? 30;
      _tokenThreshold = _persistence.getInt(_tokenThresholdKey) ?? 5000;
      _tokenCount = _persistence.getInt(_tokenCountKey) ?? 0;
      _appDataPath = baseDir.path;
      _fileLoggingEnabled = fileLoggingEnabled;
      _logRotationThresholdMb = logRotationThreshold;
      _isLoading = false;
    });
  }

  Future<String?> _resolveInitialDirectory(String? path) async {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (await file.exists()) {
      final parentDir = Directory(p.dirname(path));
      if (await parentDir.exists()) return parentDir.path;
    }

    final dir = Directory(path);
    if (await dir.exists()) return dir.path;

    final parentDir = Directory(p.dirname(path));
    if (await parentDir.exists()) return parentDir.path;

    return null;
  }

  Future<void> _updateFileLogging(bool enabled) async {
    setState(() => _fileLoggingEnabled = enabled);
    await AppLogger.setFileLoggingEnabled(enabled);
  }

  Future<void> _updateLogRotationThreshold(double value) async {
    final threshold = value.toInt();
    await AppLogger.setLogRotationThreshold(threshold);
    setState(() => _logRotationThresholdMb = threshold);
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
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ 数据库路径已更新'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ 未找到模拟器或 Little Navmap 数据路径，请手动选择'),
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

  Future<void> _pickXPlanePath() async {
    final messenger = ScaffoldMessenger.of(context);
    final initialDir = await _resolveInitialDirectory(_xplanePath);
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择 X-Plane 导航数据文件 (earth_nav.dat)',
      type: FileType.any,
      initialDirectory: initialDir,
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
          messenger.showSnackBar(
            const SnackBar(
              content: Text('✅ X-Plane 路径验证通过并已保存'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('❌ 无效的 X-Plane 导航数据文件，请重新选择'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _pickLNMPath() async {
    final messenger = ScaffoldMessenger.of(context);
    final initialDir = await _resolveInitialDirectory(_lnmPath);
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择 Little Navmap 数据库文件 (little_navmap_navigraph.sqlite)',
      type: FileType.any,
      initialDirectory: initialDir,
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
          messenger.showSnackBar(
            const SnackBar(
              content: Text('✅ Little Navmap 数据库验证通过并已保存'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('❌ 无效的 Little Navmap 数据库文件，请重新选择'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _openAppDataPath() async {
    if (_appDataPath == null) return;
    final uri = Uri.directory(_appDataPath!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _pickAppDataPath() async {
    final messenger = ScaffoldMessenger.of(context);
    final initialDir = await _resolveInitialDirectory(_appDataPath);
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择应用数据存储目录',
      initialDirectory: initialDir,
    );
    if (selected == null) return;

    setState(() => _isValidating = true);
    try {
      final oldBase = await AppStoragePaths.getBaseDirectory();
      await AppStoragePaths.setCustomBaseDirectory(selected);
      final newBase = await AppStoragePaths.getBaseDirectory();
      await AppStoragePaths.migrateBaseDirectory(oldBase, newBase);
      await _persistence.switchBaseDirectory(newBase);

      if (mounted) {
        setState(() => _appDataPath = newBase.path);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('✅ 应用数据存储路径已更新'),
            backgroundColor: Colors.green,
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
      if (mounted) {
        setState(() => _isValidating = false);
      }
    }
  }

  Future<void> _saveToken(String token) async {
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ 请输入 Token'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isValidating = true);
    final isValid = await _databasePathService.validateToken(token);
    setState(() => _isValidating = false);

    if (isValid && mounted) {
      await _databasePathService.saveToken(token);
      setState(() => _airportDbToken = token);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('✅ API Token 验证成功并已保存'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('❌ API Token 验证失败'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateMetarExpiry(double value) async {
    final expiry = value.toInt();
    // Updated to use _persistence
    await _persistence.setInt(_metarExpiryKey, expiry);
    setState(() => _metarCacheExpiry = expiry);
  }

  Future<void> _updateAirportExpiry(double value) async {
    final expiry = value.toInt();
    // Updated to use _persistence
    await _persistence.setInt(_airportExpiryKey, expiry);
    setState(() => _airportDataExpiry = expiry);
  }

  Future<void> _updateTokenThreshold(double value) async {
    final threshold = value.toInt();
    // Simplified logic using _persistence
    await _persistence.setInt(_tokenThresholdKey, threshold);
    setState(() => _tokenThreshold = threshold);
  }

  Future<void> _resetTokenCount() async {
    if (!_needsResetConfirmation) {
      setState(() {
        _needsResetConfirmation = true;
      });

      // 3秒后自动取消确认状态
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _needsResetConfirmation) {
          setState(() {
            _needsResetConfirmation = false;
          });
        }
      });
      return;
    }

    await _databasePathService.resetTokenCount();
    setState(() {
      _tokenCount = 0;
      _needsResetConfirmation = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ 已重置 API 消耗计数')));
    }
  }

  Future<void> _clearSelectedCache() async {
    if (!_needsClearConfirmation) {
      setState(() {
        _needsClearConfirmation = true;
      });

      // 3秒后自动取消确认状态
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _needsClearConfirmation) {
          setState(() {
            _needsClearConfirmation = false;
          });
        }
      });
      return;
    }

    if (_clearMetarCache) {
      await _databasePathService.clearMetarCache();
    }
    if (_clearAirportCache) {
      await _airportService.clearAirportCache(all: true);
    }
    setState(() {
      _needsClearConfirmation = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ 已清除选中的缓存数据')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
          _buildCacheManagementSection(theme),
          _buildLoggingSection(theme),
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
            airac: _xplaneInfo?['airac'],
            expiry: _xplaneInfo?['expiry'],
            isExpired: _xplaneInfo?['is_expired'] == 'true',
            onSelect: _pickXPlanePath,
          ),
          const SizedBox(height: AppThemeData.spacingMedium),
          DataPathItem(
            label: 'Little Navmap 数据库',
            path: _lnmPath,
            airac: _lnmInfo?['airac'],
            expiry: _lnmInfo?['expiry'],
            isExpired: _lnmInfo?['is_expired'] == 'true',
            onSelect: _pickLNMPath,
          ),
          if (_isValidating)
            Padding(
              padding: const EdgeInsets.only(top: AppThemeData.spacingMedium),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '正在验证路径...',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
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
      child: Column(
        children: [
          SettingsInputField(
            label: 'AirportDB API Token',
            hint: '输入您的 API Token',
            controller: _tokenController,
            icon: Icons.key_rounded,
            obscureText: true,
            onSave: () => _saveToken(_tokenController.text),
            helperText: '用于访问 airportdb.io',
          ),
          if (_isValidating)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: LinearProgressIndicator(),
            ),
          if (_airportDbToken != null && _airportDbToken!.isNotEmpty) ...[
            const SizedBox(height: AppThemeData.spacingLarge),
            _buildTokenThresholdSection(Theme.of(context)),
          ],
        ],
      ),
    );
  }

  Widget _buildTokenThresholdSection(ThemeData theme) {
    bool isExceeded = _tokenCount >= _tokenThreshold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'API 消耗阈值',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                Text(
                  '当前消耗: $_tokenCount',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isExceeded
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                ),
                const Text(' / '),
                Text(
                  '$_tokenThreshold',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          isExceeded
              ? '⚠️ 已达到或超过消耗阈值，在线 API 已被自动禁止使用。'
              : '当消耗值达到此阈值时，系统将禁止选中或使用在线 API。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: isExceeded
                ? theme.colorScheme.error
                : theme.colorScheme.outline,
          ),
        ),
        Slider(
          value: _tokenThreshold.toDouble(),
          min: 10,
          max: 5000,
          divisions: 499,
          label: '$_tokenThreshold',
          onChanged: _updateTokenThreshold,
          activeColor: isExceeded
              ? theme.colorScheme.error
              : theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _resetTokenCount,
            icon: Icon(
              _needsResetConfirmation
                  ? Icons.warning_amber_rounded
                  : Icons.refresh_rounded,
              size: 18,
            ),
            label: Text(_needsResetConfirmation ? '再次点击确认重置' : '重置消耗计数'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _needsResetConfirmation
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
              side: BorderSide(
                color: _needsResetConfirmation
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCacheManagementSection(ThemeData theme) {
    return SettingsCard(
      title: '缓存管理',
      subtitle: '手动清理已缓存的航行数据',
      icon: Icons.delete_sweep_rounded,
      child: Column(
        children: [
          CheckboxListTile(
            title: const Text('气象报文 (METAR) 缓存'),
            value: _clearMetarCache,
            onChanged: (v) => setState(() => _clearMetarCache = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),
          CheckboxListTile(
            title: const Text('机场详细信息缓存'),
            value: _clearAirportCache,
            onChanged: (v) => setState(() => _clearAirportCache = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_clearMetarCache || _clearAirportCache)
                  ? _clearSelectedCache
                  : null,
              icon: Icon(
                _needsClearConfirmation
                    ? Icons.warning_amber_rounded
                    : Icons.cleaning_services_rounded,
                size: 18,
              ),
              label: Text(_needsClearConfirmation ? '再次点击确认清除' : '执行清除'),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
            ),
          ),
        ],
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
          const SizedBox(height: AppThemeData.spacingLarge),
          Divider(color: Colors.grey.withValues(alpha: 0.2)),
          const SizedBox(height: AppThemeData.spacingLarge),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '机场详细信息过期时间',
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
                  '$_airportDataExpiry 天',
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
            '当数据缓存时间超过该值时，系统将允许强制刷新或在获取数据时强制更新。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          Slider(
            value: _airportDataExpiry.toDouble(),
            min: 1,
            max: 90,
            divisions: 89,
            label: '$_airportDataExpiry 天',
            onChanged: _updateAirportExpiry,
            activeColor: theme.colorScheme.primary,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1 天', style: theme.textTheme.labelSmall),
              Text('90 天', style: theme.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoggingSection(ThemeData theme) {
    return SettingsCard(
      title: '日志记录',
      subtitle: '在生产环境中写入本地日志文件',
      icon: Icons.receipt_long_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fileLoggingEnabled ? '已开启' : '已关闭',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Switch(
                value: _fileLoggingEnabled,
                onChanged: _updateFileLogging,
                activeThumbColor: theme.colorScheme.primary,
              ),
            ],
          ),
          if (_fileLoggingEnabled) ...[
            const SizedBox(height: AppThemeData.spacingMedium),
            Divider(color: Colors.grey.withValues(alpha: 0.2)),
            const SizedBox(height: AppThemeData.spacingMedium),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '日志自动分割阈值',
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
                    '$_logRotationThresholdMb MB',
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
              '当日志文件体积超过该值时，系统将自动对日志进行分割存档。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            Slider(
              value: _logRotationThresholdMb.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              label: '$_logRotationThresholdMb MB',
              onChanged: _updateLogRotationThreshold,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1 MB', style: theme.textTheme.labelSmall),
                Text('20 MB', style: theme.textTheme.labelSmall),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStorageSection(ThemeData theme) {
    return SettingsCard(
      title: '应用存储',
      subtitle: '应用程序内部数据存储路径 (包含配置与缓存)',
      icon: Icons.folder_shared_rounded,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                        '点击右侧按钮在文件管理器中打开',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _openAppDataPath,
                  icon: Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  tooltip: '打开目录',
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickAppDataPath,
              icon: const Icon(Icons.drive_folder_upload_rounded, size: 18),
              label: const Text('选择存储目录'),
            ),
          ],
        ),
      ),
    );
  }
}
