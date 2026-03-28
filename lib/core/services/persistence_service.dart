import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'bootstrap_service.dart';
import '../constants/app_constants.dart';
import '../utils/logger.dart';

/// App 内置持久化存储系统
/// 用于替代 shared_preferences，支持自定义存储路径
class PersistenceService {
  static final PersistenceService _instance = PersistenceService._internal();
  factory PersistenceService() => _instance;
  PersistenceService._internal();

  String? _rootPath;
  File? _settingsFile;
  Map<String, dynamic> _data = {};
  bool _initialized = false;

  // 初始化状态管理器
  Completer<void>? _initCompleter;

  // 保存队列，确保文件写入不会冲突
  Future<void>? _activeSave;

  bool get isInitialized => _initialized;
  String? get rootPath => _rootPath;

  /// 等待初始化完成
  Future<void> ensureReady() async {
    if (_initialized) return;
    if (_initCompleter != null) return _initCompleter!.future;
    final bootstrap = BootstrapService();
    if (!bootstrap.isInitialized) {
      await bootstrap.init();
    }
    final configuredPath = bootstrap.getDataPath();
    await init(customPath: configuredPath);
  }

  static String getAppRootDir() {
    final exePath = Platform.resolvedExecutable;
    return p.dirname(exePath);
  }

  static String getDefaultDesktopCacheRootPath() {
    return p.join(getAppRootDir(), 'cache');
  }

  static Future<String> getDefaultDataBaseDir() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final bootstrap = BootstrapService();
      final configuredPath = bootstrap.getDataPath();
      if (configuredPath != null && configuredPath.trim().isNotEmpty) {
        return configuredPath;
      }

      final bootstrapFilePath = bootstrap.bootstrapFilePath;
      if (bootstrapFilePath != null && bootstrapFilePath.trim().isNotEmpty) {
        return p.dirname(bootstrapFilePath);
      }

      return p.join(
        Directory.systemTemp.path,
        sanitizeDirectoryName(AppConstants.appName),
      );
    }
    return getDefaultDesktopCacheRootPath();
  }

  static Future<String> getDefaultRootPath() async {
    final baseDir = await getDefaultDataBaseDir();
    return getProcessedRootPath(baseDir);
  }

  static Future<String> getAppCacheRootPath({String? rootPath}) async {
    final effectiveRootPath = rootPath?.trim();
    final defaultRootPath = await getDefaultRootPath();
    if (effectiveRootPath != null &&
        effectiveRootPath.isNotEmpty &&
        !_isSamePath(effectiveRootPath, defaultRootPath)) {
      return p.join(effectiveRootPath, 'cache');
    }
    return p.join(defaultRootPath, 'cache');
  }

  static bool _isSamePath(String firstPath, String secondPath) {
    final normalizedFirstPath = p.normalize(firstPath);
    final normalizedSecondPath = p.normalize(secondPath);
    if (Platform.isWindows) {
      return normalizedFirstPath.toLowerCase() ==
          normalizedSecondPath.toLowerCase();
    }
    return normalizedFirstPath == normalizedSecondPath;
  }

  /// 清洗路径名称，去除特殊字符
  static String sanitizeDirectoryName(String name) {
    // 允许字母、数字、空格、下划线、连字符、点
    // 过滤掉 Windows/Linux 不允许的字符: < > : " / \ | ? *
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').trim();
  }

  /// 获取处理后的存储根路径（追加 AppName）
  static String getProcessedRootPath(String baseDir) {
    final sanitizedAppName = sanitizeDirectoryName(AppConstants.appName);
    // 如果 baseDir 已经是以 sanitizedAppName 结尾，则不再追加
    if (p.basename(baseDir) == sanitizedAppName) {
      return baseDir;
    }
    return p.join(baseDir, sanitizedAppName);
  }

  /// 初始化存储系统
  Future<void> init({String? customPath}) async {
    // 处理默认路径
    String baseDir = customPath ?? await getDefaultDataBaseDir();

    final targetPath = getProcessedRootPath(baseDir);
    final previousRootPath = _rootPath;

    // 避免重复初始化
    if (_initialized && _rootPath == targetPath) {
      return;
    }

    _initCompleter = Completer<void>();
    _initialized = false;
    _rootPath = targetPath;

    final bootstrap = BootstrapService();

    try {
      final directory = Directory(_rootPath!);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      if (previousRootPath != null &&
          !_isSamePath(previousRootPath, _rootPath!)) {
        try {
          await _migrateCacheDirectory(previousRootPath, _rootPath!);
        } catch (e) {
          AppLogger.warning('Failed to migrate cache directory: $e');
        }
      }

      // 同步路径到引导文件
      if (bootstrap.isInitialized) {
        await bootstrap.setDataPath(_rootPath!);
      }

      _settingsFile = File(p.join(_rootPath!, 'settings.json'));
      await _load();
      _initialized = true;
      _initCompleter?.complete();
      AppLogger.info(
        'PersistenceService successfully initialized at: $_rootPath',
      );
    } catch (e) {
      AppLogger.error('PersistenceService initialization failed: $e');
      _initialized = true; // 即使初始化失败也标记为已初始化，防止重复尝试
      _initCompleter?.completeError(e);
    } finally {
      _initCompleter = null;
    }
  }

  /// 加载数据
  Future<void> _load() async {
    if (_settingsFile == null || !await _settingsFile!.exists()) {
      _data = {};
      return;
    }

    try {
      final content = await _settingsFile!.readAsString();
      if (content.isNotEmpty) {
        _data = json.decode(content);
      }
    } catch (e) {
      AppLogger.warning('Error loading persistence data: $e');
      _data = {};
    }
  }

  /// 保存数据（带队列机制）
  Future<void> _save() async {
    if (_settingsFile == null) return;

    // 等待上一个保存任务完成
    final currentSave = _activeSave;
    final completer = Completer<void>();
    _activeSave = completer.future;

    if (currentSave != null) {
      try {
        await currentSave;
      } catch (_) {
        // 忽略上一个保存的错误，继续执行当前的
      }
    }

    try {
      final content = const JsonEncoder.withIndent('  ').convert(_data);
      // 使用 flush: true 确保物理写入
      await _settingsFile!.writeAsString(content, flush: true);
    } catch (e) {
      AppLogger.warning('Error saving persistence data: $e');
    } finally {
      completer.complete();
      if (_activeSave == completer.future) {
        _activeSave = null;
      }
    }
  }

  // ============ 通用操作 ============

  T? get<T>(String key, {T? defaultValue}) {
    final value = _data[key];
    if (value == null) return defaultValue;

    // 处理类型转换，例如 json 解码后 int 可能会变成 double (在某些情况下)
    if (T == int && value is num) return value.toInt() as T;
    if (T == double && value is num) return value.toDouble() as T;

    return value as T?;
  }

  String? getString(String key) => get<String>(key);
  int? getInt(String key) => get<int>(key);
  double? getDouble(String key) => get<double>(key);
  bool? getBool(String key) => get<bool>(key);
  List<String>? getStringList(String key) {
    final list = get<List<dynamic>>(key);
    return list?.map((e) => e.toString()).toList();
  }

  Future<void> set(String key, dynamic value) async {
    _data[key] = value;
    await _save();
  }

  Future<void> setString(String key, String value) => set(key, value);
  Future<void> setInt(String key, int value) => set(key, value);
  Future<void> setDouble(String key, double value) => set(key, value);
  Future<void> setBool(String key, bool value) => set(key, value);
  Future<void> setStringList(String key, List<String> value) => set(key, value);

  // ============ 模块化/命名空间支持 ============

  /// 获取模块专属数据
  T? getModuleData<T>(String moduleName, String key, {T? defaultValue}) {
    final modules = _data['modules'] as Map<String, dynamic>?;
    final moduleData = modules?[moduleName] as Map<String, dynamic>?;
    final value = moduleData?[key];

    if (value == null) return defaultValue;
    if (T == int && value is num) return value.toInt() as T;
    if (T == double && value is num) return value.toDouble() as T;

    return value as T?;
  }

  /// 设置模块专属数据
  Future<void> setModuleData(
    String moduleName,
    String key,
    dynamic value,
  ) async {
    final modules = Map<String, dynamic>.from(_data['modules'] as Map? ?? {});
    final moduleData = Map<String, dynamic>.from(
      modules[moduleName] as Map? ?? {},
    );

    moduleData[key] = value;
    modules[moduleName] = moduleData;
    _data['modules'] = modules;

    await _save();
  }

  Future<void> remove(String key) async {
    _data.remove(key);
    await _save();
  }

  Future<void> clear() async {
    _data.clear();
    await _save();
  }

  bool containsKey(String key) => _data.containsKey(key);

  /// 获取缓存大小（字节）
  Future<int> getCacheSize() async {
    int totalSize = 0;
    try {
      final cacheDir = Directory(
        await getAppCacheRootPath(rootPath: _rootPath),
      );
      if (await cacheDir.exists()) {
        await for (final entity in cacheDir.list(recursive: true)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
    } catch (e) {
      AppLogger.warning('Failed to calculate cache size: $e');
    }
    return totalSize;
  }

  /// 清除缓存
  Future<void> clearCache() async {
    try {
      final cacheDir = Directory(
        await getAppCacheRootPath(rootPath: _rootPath),
      );
      if (await cacheDir.exists()) {
        await for (final entity in cacheDir.list(recursive: false)) {
          try {
            if (entity is File) {
              await entity.delete();
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
            }
          } catch (e) {
            AppLogger.warning('Failed to clear cache item: ${entity.path}, $e');
          }
        }
      }
      // 重新初始化日志（因为日志文件夹可能也被删了）
      await AppLogger.init(force: true);
      AppLogger.info('App cache cleared');
    } catch (e) {
      AppLogger.error('Failed to clear cache: $e');
      rethrow;
    }
  }

  /// 重新定位存储路径（用于迁移数据）
  Future<void> migrateTo(String newPath) async {
    final oldPath = _rootPath;
    final targetPath = getProcessedRootPath(newPath);
    if (oldPath == null || _isSamePath(oldPath, targetPath)) return;

    await init(customPath: newPath);
  }

  /// 重置应用（清除所有配置和缓存）
  Future<void> resetApp() async {
    try {
      // 1. 清除所有持久化数据
      _data.clear();
      if (_settingsFile != null && await _settingsFile!.exists()) {
        try {
          await _settingsFile!.delete();
        } catch (e) {
          AppLogger.warning('Failed to delete settings file: $e');
        }
      }

      // 2. 清除应用数据目录（如果存在）
      if (_rootPath != null) {
        final rootDir = Directory(_rootPath!);
        if (await rootDir.exists()) {
          try {
            // 尝试删除目录内容
            await for (final entity in rootDir.list(recursive: false)) {
              try {
                if (entity is File) {
                  await entity.delete();
                } else if (entity is Directory) {
                  await entity.delete(recursive: true);
                }
              } catch (e) {
                // 静默处理单个文件/目录删除失败
                AppLogger.warning('Failed to delete: ${entity.path}');
              }
            }
            // 尝试删除目录本身
            try {
              await rootDir.delete();
            } catch (e) {
              AppLogger.warning(
                'Failed to delete data directory (may contain synchronized files): $_rootPath',
              );
            }
          } catch (e) {
            AppLogger.warning('Failed to clear data directory: $e');
          }
        }
      }

      // 3. 清除应用专属的临时缓存（仅限 Flutter 应用缓存）
      try {
        final appCacheDir = Directory(
          await getAppCacheRootPath(rootPath: _rootPath),
        );
        if (await appCacheDir.exists()) {
          try {
            await appCacheDir.delete(recursive: true);
            AppLogger.info('App cache cleared');
          } catch (e) {
            AppLogger.warning('Failed to clear app cache: $e');
          }
        }
      } catch (e) {
        AppLogger.warning('Failed to access temporary directory: $e');
      }

      // 4. 重置初始化状态
      _initialized = false;
      _rootPath = null;
      _settingsFile = null;

      // 5. 重置引导配置
      await BootstrapService().reset();

      AppLogger.info('App has been reset');
    } catch (e) {
      AppLogger.error('Failed to reset app: $e');
      rethrow;
    }
  }

  Future<void> _migrateCacheDirectory(
    String? previousRootPath,
    String targetRootPath,
  ) async {
    final sourceCachePath = await getAppCacheRootPath(
      rootPath: previousRootPath,
    );
    final targetCachePath = await getAppCacheRootPath(rootPath: targetRootPath);

    if (_isSamePath(sourceCachePath, targetCachePath)) {
      return;
    }

    final sourceDirectory = Directory(sourceCachePath);
    if (!await sourceDirectory.exists()) {
      return;
    }

    final targetDirectory = Directory(targetCachePath);
    if (!await targetDirectory.exists()) {
      await targetDirectory.create(recursive: true);
    }

    await _moveDirectoryContents(sourceDirectory, targetDirectory);

    if (await sourceDirectory.exists()) {
      final hasRemainingItems = await _directoryHasChildren(sourceDirectory);
      if (!hasRemainingItems) {
        try {
          await sourceDirectory.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _moveDirectoryContents(
    Directory sourceDirectory,
    Directory targetDirectory,
  ) async {
    await for (final entity in sourceDirectory.list(recursive: false)) {
      final targetEntityPath = p.join(
        targetDirectory.path,
        p.basename(entity.path),
      );
      if (entity is File) {
        await _moveFile(entity, File(targetEntityPath));
        continue;
      }

      if (entity is Directory) {
        final targetSubDirectory = Directory(targetEntityPath);
        if (!await targetSubDirectory.exists()) {
          await targetSubDirectory.create(recursive: true);
        }
        await _moveDirectoryContents(entity, targetSubDirectory);
        if (await entity.exists()) {
          final hasRemainingItems = await _directoryHasChildren(entity);
          if (!hasRemainingItems) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }
    }
  }

  Future<void> _moveFile(File sourceFile, File targetFile) async {
    if (await targetFile.exists()) {
      await targetFile.delete();
    } else {
      final parentDirectory = targetFile.parent;
      if (!await parentDirectory.exists()) {
        await parentDirectory.create(recursive: true);
      }
    }

    try {
      await sourceFile.rename(targetFile.path);
    } catch (_) {
      await sourceFile.copy(targetFile.path);
      if (await sourceFile.exists()) {
        await sourceFile.delete();
      }
    }
  }

  Future<bool> _directoryHasChildren(Directory directory) async {
    await for (final _ in directory.list(recursive: false)) {
      return true;
    }
    return false;
  }
}
