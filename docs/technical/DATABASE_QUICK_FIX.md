# 数据库加载问题快速修复指南

**问题**: 无法正确通过已配置的路径加载 X-Plane、LNM 数据库，导致整个 app 不能正常使用。

**根本原因**: PersistenceService 和 SharedPreferences 数据不同步

---

## 立即修复步骤

### 步骤 1: 创建数据库加载器

创建新文件 `lib/apps/services/app_core/database_loader.dart`:

```dart
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import '../../../core/utils/logger.dart';
import '../../../core/services/persistence/persistence_service.dart';

enum LoadStatus {
  success,
  notConfigured,
  fileNotFound,
  invalidFormat,
  error,
}

class DatabaseLoadResult {
  LoadStatus lnmStatus = LoadStatus.notConfigured;
  LoadStatus xplaneStatus = LoadStatus.notConfigured;
  String? lnmPath;
  String? xplanePath;
  String? lnmError;
  String? xplaneError;

  bool get hasAnyDatabase =>
      lnmStatus == LoadStatus.success ||
      xplaneStatus == LoadStatus.success;

  String getStatusMessage() {
    final messages = <String>[];

    if (lnmStatus == LoadStatus.success) {
      messages.add('✓ Little Navmap 数据库已加载');
    } else if (lnmStatus != LoadStatus.notConfigured) {
      messages.add('✗ Little Navmap: ${_getErrorMessage(lnmStatus, lnmError)}');
    }

    if (xplaneStatus == LoadStatus.success) {
      messages.add('✓ X-Plane 数据库已加载');
    } else if (xplaneStatus != LoadStatus.notConfigured) {
      messages.add('✗ X-Plane: ${_getErrorMessage(xplaneStatus, xplaneError)}');
    }

    if (messages.isEmpty) {
      messages.add('⚠ 未配置任何数据库');
    }

    return messages.join('\n');
  }

  String _getErrorMessage(LoadStatus status, String? error) {
    switch (status) {
      case LoadStatus.fileNotFound:
        return '文件不存在';
      case LoadStatus.invalidFormat:
        return '数据库格式错误';
      case LoadStatus.error:
        return error ?? '未知错误';
      default:
        return '未配置';
    }
  }
}

class DatabaseLoader {
  static Future<DatabaseLoadResult> loadAndValidate() async {
    final persistence = PersistenceService();
    final result = DatabaseLoadResult();

    // 1. 加载 LNM 路径
    final lnmPath = persistence.getString('lnm_nav_data_path');
    if (lnmPath != null && lnmPath.isNotEmpty) {
      final file = File(lnmPath);
      if (await file.exists()) {
        try {
          final db = sqlite3.open(lnmPath);
          try {
            final tables = db.select(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='airport'",
            );
            if (tables.isNotEmpty) {
              result.lnmStatus = LoadStatus.success;
              result.lnmPath = lnmPath;
              AppLogger.info('✓ LNM 数据库加载成功: $lnmPath');
            } else {
              result.lnmStatus = LoadStatus.invalidFormat;
              AppLogger.error('✗ LNM 数据库格式错误: 缺少 airport 表');
            }
          } finally {
            db.dispose();
          }
        } catch (e) {
          result.lnmStatus = LoadStatus.error;
          result.lnmError = e.toString();
          AppLogger.error('✗ LNM 数据库打开失败: $e');
        }
      } else {
        result.lnmStatus = LoadStatus.fileNotFound;
        AppLogger.error('✗ LNM 数据库文件不存在: $lnmPath');
      }
    } else {
      result.lnmStatus = LoadStatus.notConfigured;
      AppLogger.warning('⚠ LNM 数据库路径未配置');
    }

    // 2. 加载 X-Plane 路径
    final xplanePath = persistence.getString('xplane_nav_data_path');
    if (xplanePath != null && xplanePath.isNotEmpty) {
      final file = File(xplanePath);
      if (await file.exists()) {
        try {
          // 验证是否为有效的 X-Plane 数据文件
          final lines = await file
              .openRead(0, 1024)
              .transform(const SystemEncoding().decoder)
              .transform(const LineSplitter())
              .take(1)
              .toList();

          if (lines.isNotEmpty &&
              (lines.first.trim() == 'I' || lines.first.trim() == '1000')) {
            result.xplaneStatus = LoadStatus.success;
            result.xplanePath = xplanePath;
            AppLogger.info('✓ X-Plane 数据库加载成功: $xplanePath');
          } else {
            result.xplaneStatus = LoadStatus.invalidFormat;
            AppLogger.error('✗ X-Plane 数据文件格式错误');
          }
        } catch (e) {
          result.xplaneStatus = LoadStatus.error;
          result.xplaneError = e.toString();
          AppLogger.error('✗ X-Plane 数据文件读取失败: $e');
        }
      } else {
        result.xplaneStatus = LoadStatus.fileNotFound;
        AppLogger.error('✗ X-Plane 数据文件不存在: $xplanePath');
      }
    } else {
      result.xplaneStatus = LoadStatus.notConfigured;
      AppLogger.warning('⚠ X-Plane 数据路径未配置');
    }

    return result;
  }
}
```

### 步骤 2: 修改 AirportDetailService

修改 `lib/apps/services/airport_detail_service.dart`，将所有 SharedPreferences 调用替换为 PersistenceService:

```dart
class AirportDetailService {
  // 删除这些常量
  // static const String _xplanePathKey = 'xplane_nav_data_path';
  // static const String _lnmPathKey = 'lnm_nav_data_path';

  // 添加
  final PersistenceService _persistence = PersistenceService();

  // 修改所有使用 SharedPreferences 的方法
  Future<bool> isDataSourceAvailable(AirportDataSource source) async {
    switch (source) {
      case AirportDataSource.aviationApi:
        final token = _persistence.getString('airportdb_token');
        if (token == null || token.isEmpty) return false;
        final threshold = _persistence.getInt('token_consumption_threshold') ?? 5000;
        final count = _persistence.getInt('token_consumption_count') ?? 0;
        return count < threshold;
      case AirportDataSource.xplaneData:
        final path = _persistence.getString('xplane_nav_data_path');
        if (path == null || path.isEmpty) return false;
        return await File(path).exists();
      case AirportDataSource.lnmData:
        final path = _persistence.getString('lnm_nav_data_path');
        if (path == null || path.isEmpty) return false;
        return await File(path).exists();
    }
  }

  Future<AirportDataSource> getDataSource() async {
    final sourceStr = _persistence.getString('airport_data_source');
    AirportDataSource source = AirportDataSource.aviationApi;
    if (sourceStr != null) {
      source = AirportDataSource.values.firstWhere(
        (s) => s.name == sourceStr,
        orElse: () => AirportDataSource.aviationApi,
      );
    }
    final isAvailable = await isDataSourceAvailable(source);
    if (!isAvailable) {
      final available = await getAvailableDataSources();
      if (available.isNotEmpty) return available.first;
      return AirportDataSource.aviationApi;
    }
    return source;
  }

  Future<void> setDataSource(AirportDataSource source) async {
    await _persistence.setString('airport_data_source', source.name);
  }

  // 修改 _fetchFromXPlane
  Future<AirportDetailData?> _fetchFromXPlane(String icaoCode) async {
    try {
      final earthNavPath = _persistence.getString('xplane_nav_data_path');
      if (earthNavPath == null) {
        AppLogger.warning('X-Plane 数据路径未配置');
        return null;
      }

      AppLogger.debug('从 X-Plane 加载机场: $icaoCode (路径: $earthNavPath)');
      return await XPlaneAptDatParser.loadAirportByIcao(
        icaoCode: icaoCode,
        earthNavPath: earthNavPath,
      );
    } catch (e) {
      AppLogger.error('X-Plane data parse error: $e');
      return null;
    }
  }

  // 修改 _fetchFromLNM
  Future<AirportDetailData?> _fetchFromLNM(String icaoCode) async {
    try {
      final lnmPath = _persistence.getString('lnm_nav_data_path');
      if (lnmPath == null) {
        AppLogger.warning('LNM 数据路径未配置');
        return null;
      }

      final dbFile = File(lnmPath);
      if (!await dbFile.exists()) {
        AppLogger.error('LNM 数据库文件不存在: $lnmPath');
        return null;
      }

      AppLogger.debug('从 LNM 加载机场: $icaoCode (路径: $lnmPath)');
      return await LNMDatabaseParser.parseAirport(dbFile, icaoCode);
    } catch (e) {
      AppLogger.error('LNM data parse error: $e');
      return null;
    }
  }

  // 修改 loadAllAirports
  Future<List<Map<String, dynamic>>> loadAllAirports({
    AirportDataSource? source,
  }) async {
    final targetSource = source ?? await getDataSource();

    if (targetSource == AirportDataSource.lnmData) {
      final lnmPath = _persistence.getString('lnm_nav_data_path');
      if (lnmPath != null && lnmPath.isNotEmpty) {
        final file = File(lnmPath);
        if (await file.exists()) {
          try {
            AppLogger.info('读取 LNM 机场数据库: $lnmPath');
            final airports = await LNMDatabaseParser.getAllAirports(file);
            if (airports.isNotEmpty) {
              AppLogger.info('LNM 机场数据库加载完成: ${airports.length} 条');
              return airports;
            }
          } catch (e) {
            AppLogger.error('Error loading airports from LNM: $e');
          }
        } else {
          AppLogger.error('LNM 数据库文件不存在: $lnmPath');
        }
      } else {
        AppLogger.warning('LNM 数据路径未配置');
      }
    }

    if (targetSource == AirportDataSource.xplaneData ||
        targetSource == AirportDataSource.lnmData) {
      final xplanePath = _persistence.getString('xplane_nav_data_path');
      if (xplanePath != null && xplanePath.isNotEmpty) {
        try {
          final aptPath = await XPlaneAptDatParser.resolveAptDatPath(
            xplanePath,
          );
          if (aptPath != null) {
            final file = File(aptPath);
            if (await file.exists()) {
              AppLogger.info('读取 X-Plane 机场数据库: $aptPath');
              final airports = await XPlaneAptDatParser.getAllAirports(file);
              if (airports.isNotEmpty) {
                AppLogger.info('X-Plane 机场数据库加载完成: ${airports.length} 条');
                return airports;
              }
            } else {
              AppLogger.error('X-Plane apt.dat 文件不存在: $aptPath');
            }
          } else {
            AppLogger.error('无法解析 X-Plane apt.dat 路径: $xplanePath');
          }
        } catch (e) {
          AppLogger.error('Error loading airports from X-Plane: $e');
        }
      } else {
        AppLogger.warning('X-Plane 数据路径未配置');
      }
    }

    return [];
  }
}
```

### 步骤 3: 修改 AppInitializer

修改 `lib/apps/services/app_core/app_initializer.dart`:

```dart
import 'database_loader.dart'; // 添加导入

class AppInitializer {
  // ... 其他代码 ...

  static Future<void> preloadAirportData() async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (!AirportsDatabase.isEmpty) {
      return;
    }

    try {
      // 1. 验证数据库加载状态
      final loadResult = await DatabaseLoader.loadAndValidate();

      AppLogger.info('数据库状态:\n${loadResult.getStatusMessage()}');

      if (!loadResult.hasAnyDatabase) {
        AppLogger.error('无可用数据库，请在设置中配置数据源');
        return;
      }

      // 2. 加载机场数据
      final detailService = AirportDetailService();
      final currentDataSource = await detailService.getDataSource();

      AppLogger.info('当前数据源: ${currentDataSource.displayName}');

      final airports = await detailService.loadAllAirports(
        source: currentDataSource,
      );

      if (airports.isNotEmpty) {
        AirportsDatabase.updateAirports(
          airports.map((a) {
            return AirportInfo(
              icaoCode: a['icao'] ?? '',
              iataCode: a['iata'] ?? '',
              nameChinese: a['name'] ?? '',
              latitude: (a['lat'] as num?)?.toDouble() ?? 0.0,
              longitude: (a['lon'] as num?)?.toDouble() ?? 0.0,
            );
          }).toList(),
        );
        AppLogger.info('✓ 成功预加载 ${airports.length} 个机场数据');
      } else {
        AppLogger.warning(
          '⚠ 未能预加载机场数据 (数据源: ${currentDataSource.displayName})',
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('✗ 预加载机场数据失败: $e\n$stackTrace');
    }
  }
}
```

### 步骤 4: 验证修复

1. 运行应用
2. 检查日志输出，应该看到:
   ```
   数据库状态:
   ✓ Little Navmap 数据库已加载
   ✓ X-Plane 数据库已加载
   ```
   或者
   ```
   数据库状态:
   ✗ Little Navmap: 文件不存在
   ✗ X-Plane: 未配置
   ```

3. 如果看到错误，根据错误信息:
   - `文件不存在`: 检查配置的路径是否正确
   - `数据库格式错误`: 检查文件是否损坏
   - `未配置`: 在设置向导中配置数据库路径

---

## 调试技巧

### 查看当前配置

在应用中添加调试代码:

```dart
void debugPrintConfig() async {
  final persistence = PersistenceService();
  AppLogger.debug('=== 当前配置 ===');
  AppLogger.debug('LNM 路径: ${persistence.getString("lnm_nav_data_path")}');
  AppLogger.debug('X-Plane 路径: ${persistence.getString("xplane_nav_data_path")}');
  AppLogger.debug('数据源: ${persistence.getString("airport_data_source")}');
}
```

### 手动验证数据库

```dart
void manualValidate() async {
  final lnmPath = 'C:\\path\\to\\your\\database.sqlite';
  final db = sqlite3.open(lnmPath);

  try {
    final tables = db.select(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    AppLogger.debug('数据库表: ${tables.map((t) => t['name']).join(', ')}');

    final airports = db.select('SELECT COUNT(*) as count FROM airport');
    AppLogger.debug('机场数量: ${airports.first['count']}');
  } finally {
    db.dispose();
  }
}
```

---

## 常见问题

### Q: 修改后仍然无法加载数据库

A: 检查以下几点:
1. 确保 `PersistenceService` 已初始化
2. 检查 `settings.json` 文件内容
3. 验证数据库文件路径是否正确
4. 查看完整的错误日志

### Q: 如何重置配置?

A: 删除 `settings.json` 文件，重新启动应用

### Q: 数据库路径包含中文怎么办?

A: 确保使用 UTF-8 编码，路径应该正常工作

---

## 下一步

修复完成后，建议:
1. 添加单元测试
2. 实施性能优化 (参见 DATABASE_PERFORMANCE_REPORT.md)
3. 添加用户友好的错误提示界面
