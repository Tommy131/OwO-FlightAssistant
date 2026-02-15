import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:window_manager/window_manager.dart';

import 'core/app.dart';
import 'core/services/persistence_service.dart';
import 'core/utils/logger.dart';

class _DelegatingPathProvider extends PathProviderPlatform {
  _DelegatingPathProvider(this._delegate, this._cacheRootPath);

  final PathProviderPlatform _delegate;
  final String _cacheRootPath;

  Future<String?> _ensureDir(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return path;
  }

  @override
  Future<String?> getTemporaryPath() =>
      _ensureDir(p.join(_cacheRootPath, 'temp'));

  @override
  Future<String?> getApplicationSupportPath() =>
      _ensureDir(p.join(_cacheRootPath, 'support'));

  @override
  Future<String?> getLibraryPath() => _delegate.getLibraryPath();

  @override
  Future<String?> getApplicationDocumentsPath() =>
      _ensureDir(p.join(_cacheRootPath, 'documents'));

  @override
  Future<String?> getApplicationCachePath() => _ensureDir(_cacheRootPath);

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
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();

    final appCacheRootPath = PersistenceService.getAppCacheRootPath();
    final appCacheRootDir = Directory(appCacheRootPath);
    if (!await appCacheRootDir.exists()) {
      await appCacheRootDir.create(recursive: true);
    }

    final originalProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _DelegatingPathProvider(
      originalProvider,
      appCacheRootPath,
    );
    GoogleFonts.config.allowRuntimeFetching = true;

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

    // 启动应用程序实例
    runApp(const MyApp());
  } catch (e, stackTrace) {
    AppLogger.error('Start application failed!', e, stackTrace);
  }
}
