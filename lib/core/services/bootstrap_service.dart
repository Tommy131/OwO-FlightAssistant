import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';

/// 引导配置文件服务
/// 存储于应用可执行文件所在目录，用于引导应用找到正确的数据存储路径
class BootstrapService {
  static final BootstrapService _instance = BootstrapService._internal();
  factory BootstrapService() => _instance;
  BootstrapService._internal();

  static const String _bootstrapFileName = 'bootstrap.json';

  File? _bootstrapFile;
  Map<String, dynamic> _config = {};
  bool _initialized = false;

  bool get isInitialized => _initialized;
  String? get bootstrapFilePath => _bootstrapFile?.path;

  /// 获取应用的可执行文件所在目录
  String _getAppRootDir() {
    // Platform.resolvedExecutable 获取的是 exe 的完整路径
    final exePath = Platform.resolvedExecutable;
    return p.dirname(exePath);
  }

  /// 初始化引导配置
  Future<void> init() async {
    try {
      if (kIsWeb) {
        _initialized = true;
        return;
      }
      final rootDir = await _resolveBootstrapRootDir();
      _bootstrapFile = File(p.join(rootDir, _bootstrapFileName));
      await _bootstrapFile!.parent.create(recursive: true);

      if (await _bootstrapFile!.exists()) {
        final content = await _bootstrapFile!.readAsString();
        if (content.isNotEmpty) {
          _config = json.decode(content);
        }
      }
      _initialized = true;
      AppLogger.info(
        'BootstrapService initialized at: ${_bootstrapFile?.path}',
      );
    } catch (e) {
      AppLogger.error('BootstrapService initialization failed: $e');
      // 即使失败也要标记为初始化，防止后续报错，但配置为空
      _initialized = true;
    }
  }

  /// 获取配置项
  T? get<T>(String key, {T? defaultValue}) {
    final value = _config[key];
    if (value == null) return defaultValue;
    return value as T?;
  }

  /// 设置配置项
  Future<void> set(String key, dynamic value) async {
    _config[key] = value;
    await _save();
  }

  /// 保存配置到文件
  Future<void> _save() async {
    if (_bootstrapFile == null) return;
    try {
      final content = const JsonEncoder.withIndent('  ').convert(_config);
      await _bootstrapFile!.writeAsString(content, flush: true);
    } catch (e) {
      AppLogger.error('Error saving bootstrap config: $e');
    }
  }

  Future<String> _resolveBootstrapRootDir() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final supportDir = await getApplicationSupportDirectory();
      return supportDir.path;
    }
    return _getAppRootDir();
  }

  /// 获取存储路径
  String? getDataPath() => get<String>('data_path');

  /// 设置存储路径
  Future<void> setDataPath(String path) => set('data_path', path);

  /// 获取是否是首次启动
  bool isFirstLaunch() => get<bool>('is_first_launch', defaultValue: true)!;

  /// 设置是否是首次启动
  Future<void> setFirstLaunch(bool value) => set('is_first_launch', value);

  /// 重置引导配置
  Future<void> reset() async {
    _config.clear();
    if (_bootstrapFile != null && await _bootstrapFile!.exists()) {
      try {
        await _bootstrapFile!.delete();
        AppLogger.info('Bootstrap file deleted');
      } catch (e) {
        AppLogger.warning('Failed to delete bootstrap file: $e');
      }
    }
    // 重新创建一个默认的（空的或带有初始值的）
    await _save();
  }
}
