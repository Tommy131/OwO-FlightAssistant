import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../utils/logger.dart';
import '../module_registry/update/update_config.dart';

/// 版本信息模型
class VersionInfo {
  final String version;
  final String description;
  final String downloadUrl;

  const VersionInfo({
    required this.version,
    required this.description,
    required this.downloadUrl,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    return VersionInfo(
      version: json['version'] as String? ?? '',
      description: json['description'] as String? ?? '',
      downloadUrl: json['downloadUrl'] as String? ?? '',
    );
  }
}

/// 更新检测结果
class UpdateCheckResult {
  final bool hasUpdate;
  final VersionInfo? versionInfo;
  final String? error;
  final String currentVersion;

  const UpdateCheckResult({
    required this.hasUpdate,
    this.versionInfo,
    this.error,
    required this.currentVersion,
  });

  bool get isError => error != null;
  bool get isSuccess => error == null;
}

/// 版本更新检测服务
class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  /// 检查更新
  Future<UpdateCheckResult> checkForUpdates() async {
    // 获取当前应用版本
    final currentVersion = AppConstants.appVersion;
    try {
      // 检查配置是否存在
      if (UpdateConfig.current == null) {
        AppLogger.warning('更新配置未初始化');
        return UpdateCheckResult(
          hasUpdate: false,
          currentVersion: currentVersion,
          error: 'update_config_not_initialized',
        );
      }

      // 获取配置
      final config = UpdateConfig.current!;

      AppLogger.info('开始检查更新，当前版本: $currentVersion');

      // 发起HTTP请求
      final response = await http
          .get(Uri.parse(config.versionCheckUrl))
          .timeout(Duration(seconds: config.timeoutSeconds));

      if (response.statusCode != 200) {
        AppLogger.warning('版本检查请求失败: ${response.statusCode}');
        return UpdateCheckResult(
          hasUpdate: false,
          currentVersion: currentVersion,
          error: 'HTTP ${response.statusCode}',
        );
      }

      // 解析响应
      final jsonData = json.decode(utf8.decode(response.bodyBytes));
      final versionInfo = VersionInfo.fromJson(jsonData);

      // 使用配置中的下载地址（如果JSON中没有提供）
      final finalVersionInfo = VersionInfo(
        version: versionInfo.version,
        description: versionInfo.description,
        downloadUrl: versionInfo.downloadUrl.isEmpty
            ? (config.downloadUrl ?? '')
            : versionInfo.downloadUrl,
      );

      // 比较版本号
      final hasUpdate = _compareVersions(
        currentVersion,
        finalVersionInfo.version,
      );

      AppLogger.info(
        '版本检查完成: 当前=$currentVersion, 最新=${finalVersionInfo.version}, 有更新=$hasUpdate',
      );

      return UpdateCheckResult(
        hasUpdate: hasUpdate,
        versionInfo: finalVersionInfo,
        currentVersion: currentVersion,
      );
    } on TimeoutException {
      AppLogger.warning('版本检查超时');
      return UpdateCheckResult(
        hasUpdate: false,
        currentVersion: currentVersion,
        error: 'timeout',
      );
    } catch (e, stackTrace) {
      AppLogger.error('版本检查失败', e, stackTrace);
      return UpdateCheckResult(
        hasUpdate: false,
        currentVersion: currentVersion,
        error: e.toString(),
      );
    }
  }

  /// 比较版本号
  /// 返回true表示remoteVersion > currentVersion
  bool _compareVersions(String current, String remote) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final remoteParts = remote.split('.').map(int.parse).toList();

      final maxLength = currentParts.length > remoteParts.length
          ? currentParts.length
          : remoteParts.length;

      for (int i = 0; i < maxLength; i++) {
        final currentPart = i < currentParts.length ? currentParts[i] : 0;
        final remotePart = i < remoteParts.length ? remoteParts[i] : 0;

        if (remotePart > currentPart) return true;
        if (remotePart < currentPart) return false;
      }

      return false; // 版本相同
    } catch (e) {
      AppLogger.warning('版本号比较失败: $e');
      return false;
    }
  }
}
