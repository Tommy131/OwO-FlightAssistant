import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/logger.dart';

class UpdateService {
  static const String remoteVersionUrl =
      'https://raw.githubusercontent.com/Tommy131/OwO-FlightAssistant/master/version.txt';

  static const String projectPageUrl =
      'https://github.com/Tommy131/OwO-FlightAssistant';

  static const String releasePageUrl =
      'https://github.com/Tommy131/OwO-FlightAssistant/releases';

  /// 检查是否有更新
  /// 返回: { 'hasUpdate': bool, 'remoteVersion': String, 'error': String? }
  static Future<Map<String, dynamic>> checkUpdate() async {
    try {
      AppLogger.info('开始检查更新');
      final response = await http
          .get(Uri.parse(remoteVersionUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final lines = response.body
            .trim()
            .split('\n')
            .map((l) => l.trim())
            .toList();
        final remoteVersion = lines.isNotEmpty ? lines[0] : '';
        final downloadUrl = lines.length > 1 ? lines[1] : null;

        AppLogger.info(
          '更新检测: 远程版本为 $remoteVersion, 本地版本为 ${AppConstants.appVersion}',
        );

        return {
          'hasUpdate': _isNewer(remoteVersion, AppConstants.appVersion),
          'remoteVersion': remoteVersion,
          'downloadUrl': downloadUrl,
          'error': null,
        };
      } else {
        AppLogger.warning('更新检测: 获取远程版本失败 (HTTP ${response.statusCode})');
        return {
          'hasUpdate': false,
          'remoteVersion': '',
          'error': '获取远程版本失败 (HTTP ${response.statusCode})',
        };
      }
    } catch (e) {
      AppLogger.error('更新检测: 异常 $e');
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
}
