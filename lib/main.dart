import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:window_manager/window_manager.dart';

import 'core/app.dart';
import 'core/constants/app_constants.dart';
import 'core/services/bootstrap_service.dart';
import 'core/services/persistence_service.dart';
import 'core/utils/logger.dart';

class _DelegatingPathProvider extends PathProviderPlatform {
  _DelegatingPathProvider(this._delegate, this._cacheRootPathResolver);

  final PathProviderPlatform _delegate;
  final Future<String> Function() _cacheRootPathResolver;

  Future<String?> _ensureDir(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return path;
  }

  Future<String?> _ensureCacheSubdirectory([String? childPath]) async {
    final cacheRootPath = await _cacheRootPathResolver();
    final targetPath = childPath == null
        ? cacheRootPath
        : p.join(cacheRootPath, childPath);
    return _ensureDir(targetPath);
  }

  @override
  Future<String?> getTemporaryPath() => _ensureCacheSubdirectory('temp');

  @override
  Future<String?> getApplicationSupportPath() =>
      _ensureCacheSubdirectory('support');

  @override
  Future<String?> getLibraryPath() => _delegate.getLibraryPath();

  @override
  Future<String?> getApplicationDocumentsPath() =>
      _ensureCacheSubdirectory('documents');

  @override
  Future<String?> getApplicationCachePath() => _ensureCacheSubdirectory();

  @override
  Future<String?> getExternalStoragePath() =>
      _delegate.getExternalStoragePath();

  @override
  Future<List<String>?> getExternalCachePaths() =>
      _delegate.getExternalCachePaths();

  @override
  Future<List<String>?> getExternalStoragePaths({StorageDirectory? type}) =>
      _delegate.getExternalStoragePaths(type: type);

  @override
  Future<String?> getDownloadsPath() => _delegate.getDownloadsPath();
}

void main() async {
  try {
    // 必须在 path_provider 等平台插件使用前初始化绑定
    WidgetsFlutterBinding.ensureInitialized();

    // 初始化应用常量 (版本号等)
    await AppConstants.init();

    final bootstrap = BootstrapService();
    await bootstrap.init();
    final configuredDataPath = bootstrap.getDataPath();
    final appCacheRootPath = await PersistenceService.getAppCacheRootPath(
      rootPath: configuredDataPath,
    );

    final appCacheRootDir = Directory(appCacheRootPath);
    if (!await appCacheRootDir.exists()) {
      await appCacheRootDir.create(recursive: true);
    }

    final originalProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _DelegatingPathProvider(
      originalProvider,
      () => PersistenceService.getAppCacheRootPath(
        rootPath: PersistenceService().rootPath ?? configuredDataPath,
      ),
    );
    GoogleFonts.config.allowRuntimeFetching = true;

    if (!Platform.isIOS && !Platform.isAndroid) {
      await windowManager.ensureInitialized();

      WindowOptions windowOptions = const WindowOptions(
        size: Size(1266, 800),
        minimumSize: Size(816, 600),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
      );

      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }

    // 启动应用程序实例
    runApp(const MyApp());
  } catch (e, stackTrace) {
    AppLogger.error('Start application failed!', e, stackTrace);
  }
}
