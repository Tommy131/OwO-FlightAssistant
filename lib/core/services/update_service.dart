import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../utils/logger.dart';
import '../module_registry/update/update_config.dart';

/// 版本信息模型
class VersionInfo {
  final String version;
  final String description;
  final String downloadUrl;
  final String releasePageUrl;

  const VersionInfo({
    required this.version,
    required this.description,
    required this.downloadUrl,
    required this.releasePageUrl,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    final releasePageUrl =
        _readString(json, ['releasePageUrl', 'releaseUrl', 'html_url']) ??
        '${AppConstants.githubRepoUrl}/releases';

    return VersionInfo(
      version: _normalizeVersionTag(
        _readString(json, ['tag_name', 'version', 'name']) ?? '',
      ),
      description: _readString(json, ['description', 'body']) ?? '',
      downloadUrl:
          _readString(json, ['downloadUrl']) ??
          _resolveGithubDownloadUrl(json) ??
          '',
      releasePageUrl: releasePageUrl,
    );
  }

  static String? _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static String? _resolveGithubDownloadUrl(Map<String, dynamic> json) {
    final assetUrl = _resolveGithubAssetDownloadUrl(json['assets']);
    if (assetUrl != null) {
      return assetUrl;
    }

    final bodyText = json['body'];
    if (bodyText is String && bodyText.isNotEmpty) {
      final bodyUrl = _extractDownloadUrlFromText(bodyText);
      if (bodyUrl != null) {
        return bodyUrl;
      }
    }

    return null;
  }

  static String? _resolveGithubAssetDownloadUrl(dynamic assetsData) {
    if (assetsData is! List) {
      return null;
    }

    final assets = assetsData
        .whereType<Map>()
        .map((asset) => asset.cast<String, dynamic>())
        .toList();

    if (assets.isEmpty) {
      return null;
    }

    final preferredKeywords = _preferredAssetKeywords();

    Map<String, dynamic>? selectedAsset;
    for (final asset in assets) {
      final assetName = (asset['name'] as String? ?? '').toLowerCase();
      if (preferredKeywords.any(assetName.contains)) {
        selectedAsset = asset;
        break;
      }
    }

    selectedAsset ??= assets.first;

    final downloadUrl = selectedAsset['browser_download_url'];
    if (downloadUrl is String && downloadUrl.trim().isNotEmpty) {
      return downloadUrl.trim();
    }

    return null;
  }

  static List<String> _preferredAssetKeywords() {
    if (kIsWeb) {
      return const ['web', '.zip'];
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return const ['windows', 'win', '.msix', '.msi', '.exe', '.zip'];
      case TargetPlatform.android:
        return const ['android', '.apk', '.xapk', '.zip'];
      case TargetPlatform.iOS:
        return const ['ios', '.ipa', '.zip'];
      case TargetPlatform.macOS:
        return const ['macos', 'mac', '.dmg', '.pkg', '.zip'];
      case TargetPlatform.linux:
        return const ['linux', '.appimage', '.deb', '.rpm', '.tar.gz', '.zip'];
      case TargetPlatform.fuchsia:
        return const ['.zip'];
    }
  }

  static String? _extractDownloadUrlFromText(String text) {
    final urlMatches = RegExp(
      r'https?://[^\s)>\]"]+',
      caseSensitive: false,
    ).allMatches(text);

    final urls = urlMatches.map((match) => match.group(0)!).toList();
    if (urls.isEmpty) {
      return null;
    }

    const preferredMarkers = [
      'github.com/user-attachments/',
      '/releases/download/',
      '.msix',
      '.msi',
      '.exe',
      '.apk',
      '.ipa',
      '.dmg',
      '.pkg',
      '.appimage',
      '.deb',
      '.rpm',
      '.zip',
      '.tar.gz',
    ];

    for (final url in urls) {
      final normalizedUrl = url.toLowerCase();
      if (preferredMarkers.any(normalizedUrl.contains)) {
        return url;
      }
    }

    return urls.first;
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
  static final RegExp _internalBuildPrefix = RegExp(
    r'^(?:internal-build-|internal-built-)',
    caseSensitive: false,
  );
  factory UpdateService() => _instance;
  UpdateService._internal();

  /// 检查更新
  Future<UpdateCheckResult> checkForUpdates() async {
    final currentVersion = getCurrentVersionTag();
    try {
      if (UpdateConfig.current == null) {
        AppLogger.warning('Update configuration not initialized');
        return UpdateCheckResult(
          hasUpdate: false,
          currentVersion: currentVersion,
          error: 'update_config_not_initialized',
        );
      }

      final config = UpdateConfig.current!;

      AppLogger.info('Starting update check, current version: $currentVersion');

      final response = await http
          .get(Uri.parse(config.versionCheckUrl))
          .timeout(Duration(seconds: config.timeoutSeconds));

      if (response.statusCode != 200) {
        AppLogger.warning('Version check request failed: ${response.statusCode}');
        return UpdateCheckResult(
          hasUpdate: false,
          currentVersion: currentVersion,
          error: 'HTTP ${response.statusCode}',
        );
      }

      final jsonData = json.decode(utf8.decode(response.bodyBytes));
      final versionInfo = VersionInfo.fromJson(jsonData);

      final finalVersionInfo = VersionInfo(
        version: versionInfo.version,
        description: versionInfo.description,
        downloadUrl: versionInfo.downloadUrl.isEmpty
            ? (config.downloadUrl ?? '')
            : versionInfo.downloadUrl,
        releasePageUrl: versionInfo.releasePageUrl,
      );

      final hasUpdate = _compareVersions(
        currentVersion,
        finalVersionInfo.version,
      );

      AppLogger.info(
        'Version check completed: current=$currentVersion, latest=${finalVersionInfo.version}, has update=$hasUpdate',
      );

      return UpdateCheckResult(
        hasUpdate: hasUpdate,
        versionInfo: finalVersionInfo,
        currentVersion: currentVersion,
      );
    } on TimeoutException {
      AppLogger.warning('Version check timeout');
      return UpdateCheckResult(
        hasUpdate: false,
        currentVersion: currentVersion,
        error: 'timeout',
      );
    } catch (e, stackTrace) {
      AppLogger.error('Version check failed', e, stackTrace);
      return UpdateCheckResult(
        hasUpdate: false,
        currentVersion: currentVersion,
        error: e.toString(),
      );
    }
  }

  static String getCurrentVersionTag() {
    final normalizedVersion = _normalizeVersionTag(AppConstants.appVersion);
    final buildVersion = AppConstants.appBuildVersion
        .replaceFirst(_internalBuildPrefix, '')
        .trim();

    if (buildVersion.isEmpty) {
      return normalizedVersion;
    }

    return '${normalizedVersion}_$buildVersion';
  }

  bool _compareVersions(String current, String remote) {
    try {
      final versionComparison = _compareNormalizedVersions(remote, current);
      return versionComparison > 0;
    } catch (e) {
      AppLogger.warning('Version comparison failed: $e');
      return false;
    }
  }

  static int _compareNormalizedVersions(String left, String right) {
    final leftParsed = _ParsedVersion.tryParse(left);
    final rightParsed = _ParsedVersion.tryParse(right);

    if (leftParsed == null || rightParsed == null) {
      final normalizedLeft = _normalizeVersionTag(left);
      final normalizedRight = _normalizeVersionTag(right);
      return normalizedLeft.compareTo(normalizedRight);
    }

    for (int index = 0; index < 3; index++) {
      final coreComparison = leftParsed.core[index].compareTo(
        rightParsed.core[index],
      );
      if (coreComparison != 0) {
        return coreComparison;
      }
    }

    final preReleaseComparison = _comparePreRelease(
      leftParsed.preReleaseParts,
      rightParsed.preReleaseParts,
    );
    if (preReleaseComparison != 0) {
      return preReleaseComparison;
    }

    return _compareBuild(leftParsed.buildPart, rightParsed.buildPart);
  }

  static int _comparePreRelease(List<String> left, List<String> right) {
    if (left.isEmpty && right.isEmpty) {
      return 0;
    }
    if (left.isEmpty) {
      return 1;
    }
    if (right.isEmpty) {
      return -1;
    }

    final maxLength = left.length > right.length ? left.length : right.length;
    for (int index = 0; index < maxLength; index++) {
      if (index >= left.length) {
        return -1;
      }
      if (index >= right.length) {
        return 1;
      }

      final leftPart = left[index];
      final rightPart = right[index];
      final leftNumber = int.tryParse(leftPart);
      final rightNumber = int.tryParse(rightPart);

      if (leftNumber != null && rightNumber != null) {
        final comparison = leftNumber.compareTo(rightNumber);
        if (comparison != 0) {
          return comparison;
        }
        continue;
      }

      if (leftNumber != null && rightNumber == null) {
        return -1;
      }
      if (leftNumber == null && rightNumber != null) {
        return 1;
      }

      final comparison = leftPart.compareTo(rightPart);
      if (comparison != 0) {
        return comparison;
      }
    }

    return 0;
  }

  static int _compareBuild(String left, String right) {
    if (left.isEmpty && right.isEmpty) {
      return 0;
    }
    if (left.isEmpty) {
      return -1;
    }
    if (right.isEmpty) {
      return 1;
    }

    final leftNumber = int.tryParse(left);
    final rightNumber = int.tryParse(right);
    if (leftNumber != null && rightNumber != null) {
      return leftNumber.compareTo(rightNumber);
    }

    return left.compareTo(right);
  }
}

String _normalizeVersionTag(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '';
  }

  final withPrefix = trimmed.startsWith('v') ? trimmed : 'v$trimmed';
  return withPrefix.replaceFirst(
    RegExp(r'_(?:internal-build-|internal-built-)', caseSensitive: false),
    '_',
  );
}

class _ParsedVersion {
  final List<int> core;
  final List<String> preReleaseParts;
  final String buildPart;

  const _ParsedVersion({
    required this.core,
    required this.preReleaseParts,
    required this.buildPart,
  });

  static _ParsedVersion? tryParse(String source) {
    final normalized = _normalizeVersionTag(source);
    final match = RegExp(
      r'^v(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:_(.+))?$',
    ).firstMatch(normalized);

    if (match == null) {
      return null;
    }

    final preRelease = match.group(4) ?? '';

    return _ParsedVersion(
      core: [
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      ],
      preReleaseParts: preRelease
          .split(RegExp(r'[.-]'))
          .where((part) => part.isNotEmpty)
          .toList(),
      buildPart: (match.group(5) ?? '').trim(),
    );
  }
}
