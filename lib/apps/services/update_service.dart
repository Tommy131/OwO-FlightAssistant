import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';

class UpdateService {
  static const String remoteVersionUrl =
      'https://raw.githubusercontent.com/Tommy131/OwO-FlightAssistant/master/version.txt';

  /// 根据版本号构建下载链接 (使用 GitHub Release 标签)
  static String _getReleaseUrl(String version) {
    // 确保版本号符合标签格式 (如 v1.0.0)
    final tag = version.startsWith('v') ? version : 'v$version';
    return 'https://github.com/Tommy131/OwO-FlightAssistant/archive/refs/tags/$tag.zip';
  }

  /// 检查是否有更新
  /// 返回: { 'hasUpdate': bool, 'remoteVersion': String, 'error': String? }
  static Future<Map<String, dynamic>> checkUpdate() async {
    try {
      final response = await http
          .get(Uri.parse(remoteVersionUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final remoteVersion = response.body.trim();

        return {
          'hasUpdate': _isNewer(remoteVersion, AppConstants.appVersion),
          'remoteVersion': remoteVersion,
          'error': null,
        };
      } else {
        return {
          'hasUpdate': false,
          'remoteVersion': '',
          'error': '获取远程版本失败 (HTTP ${response.statusCode})',
        };
      }
    } catch (e) {
      return {'hasUpdate': false, 'remoteVersion': '', 'error': '版本检测异常: $e'};
    }
  }

  /// 比较版本号 (语义化版本比较)
  static bool _isNewer(String remote, String local) {
    try {
      // 移除可能存在的前缀 'v'
      final rStr = remote.startsWith('v') ? remote.substring(1) : remote;
      final lStr = local.startsWith('v') ? local.substring(1) : local;

      if (rStr == lStr) return false;

      // 分割主版本号与预发布标签 (如 1.0.0-beta)
      final rParts = rStr.split('-');
      final lParts = lStr.split('-');

      final rNums = rParts[0].split('.');
      final lNums = lParts[0].split('.');

      // 比较数字部分
      for (int i = 0; i < 3; i++) {
        final rVal = i < rNums.length ? int.tryParse(rNums[i]) ?? 0 : 0;
        final lVal = i < lNums.length ? int.tryParse(lNums[i]) ?? 0 : 0;

        if (rVal > lVal) return true;
        if (rVal < lVal) return false;
      }

      // 如果数字部分完全一致，且远程没有标签而本地有标签，远程更新 (1.0.0 > 1.0.0-beta)
      if (rParts.length == 1 && lParts.length > 1) return true;
      if (rParts.length > 1 && lParts.length == 1) return false;

      // 如果都有标签或都没有标签，则回退到字符串比较
      return rStr.compareTo(lStr) > 0;
    } catch (e) {
      // 容错：如果是无法解析的格式，则简单字符串比较
      return remote != local && remote.compareTo(local) > 0;
    }
  }

  /// 下载更新
  static Future<bool> downloadUpdate({
    required String version,
    required Function(double progress) onProgress,
  }) async {
    try {
      final client = http.Client();
      final url = _getReleaseUrl(version);
      final request = http.Request('GET', Uri.parse(url));
      final response = await client
          .send(request)
          .timeout(const Duration(minutes: 5));

      if (response.statusCode != 200) {
        throw '下载失败: HTTP ${response.statusCode}';
      }

      final contentLength = response.contentLength ?? 0;
      int downloaded = 0;

      final savePath = p.join(Directory.current.path, 'update.zip');
      final file = File(savePath);
      final sink = file.openWrite();

      await response.stream.forEach((chunk) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (contentLength > 0) {
          onProgress(downloaded / contentLength);
        }
      });

      await sink.close();
      return true;
    } catch (e) {
      AppLogger.error('下载更新失败: $e');
      return false;
    }
  }
}
