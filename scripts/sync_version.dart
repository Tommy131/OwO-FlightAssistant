// ignore_for_file: avoid_print

import 'dart:io';

/// OwO! Flight Assistant 版本同步工具 (极优版)
///
/// 该脚本将 [pubspec.yaml] 作为版本号的唯一源头，同步至：
/// 1. iOS (Info.plist)
/// 2. Windows (Runner.rc)
///
/// 注意：Android (build.gradle.kts) 现已配置为动态读取 flutter.versionName，
/// 因此不再需要通过此脚本强制写入，以避免潜在的构建冲突。
///
/// 优化点：
/// - 以 pubspec.yaml 为单一事实来源 (Single Source of Truth)
/// - 自动解析 version+build 格式
/// - 增强正则鲁棒性 (不依赖特定空格/换行)
/// - 自动执行 flutter pub get (可选)
void main(List<String> args) async {
  print('🚀 开始版本同步任务...');

  final pubspecFile = File('pubspec.yaml');
  if (!await pubspecFile.exists()) {
    _error('未找到 pubspec.yaml，请确保在项目根目录运行。');
    return;
  }

  // 1. 解析 pubspec.yaml 中的版本信息
  final content = await pubspecFile.readAsString();
  final fullVersion = _getMatch(content, r'^version: (.+)$', multiLine: true);

  if (fullVersion == null || !fullVersion.contains('+')) {
    _error('无法从 pubspec.yaml 解析版本号。请确保格式为: version: x.y.z+build');
    return;
  }

  final parts = fullVersion.split('+');
  final version = parts[0];
  final buildNumber = parts[1];
  // 保持与之前逻辑兼容，buildVersion 在这里直接用 buildNumber
  final buildVersion = buildNumber;

  print('📦 目标版本: $version');
  print('🛠️ 编译版本: $buildNumber');

  final results = await Future.wait([
    _updateIOS(version, buildVersion, buildNumber),
    _updateWindows(version, buildVersion),
  ]);

  if (results.every((r) => r)) {
    print('\n✨ 所有平台版本同步成功！');

    // 自动运行 flutter pub get
    if (!args.contains('--no-pub-get')) {
      await _runPubGet();
    } else {
      print('💡 请记得运行 "flutter pub get" 以确保配置生效。');
    }
  } else {
    print('\n⚠️ 部分平台同步失败，请检查上方日志。');
    exit(1);
  }
}

String? _getMatch(String content, String pattern, {bool multiLine = false}) {
  final match = RegExp(pattern, multiLine: multiLine).firstMatch(content);
  return match?.group(1);
}

void _error(String msg) => print('❌ 错误: $msg');
void _success(String msg) => print('  [✓] $msg');
void _info(String msg) => print('  [i] $msg');

Future<void> _runPubGet() async {
  print('\n📦 正在自动执行 "flutter pub get"...');
  try {
    final result = await Process.run('flutter', [
      'pub',
      'get',
    ], runInShell: true);
    if (result.exitCode == 0) {
      _success('flutter pub get 执行成功');
    } else {
      _error('flutter pub get 执行失败: ${result.stderr}');
    }
  } catch (e) {
    _error('无法运行 flutter 命令: $e');
  }
}

Future<bool> _updateIOS(
  String version,
  String buildVersion,
  String buildNumber,
) async {
  try {
    final file = File('ios/Runner/Info.plist');
    if (!await file.exists()) {
      _info('跳过 iOS 配置 (文件不存在)');
      return true;
    }

    var content = await file.readAsString();
    final oldContent = content;

    // CFBundleShortVersionString -> Marketing Version
    content = content.replaceFirstMapped(
      RegExp(
        r'(<key>CFBundleShortVersionString</key>\s*<string>).*?(</string>)',
        dotAll: true,
      ),
      (m) => '${m[1]}${version}_$buildVersion${m[2]}',
    );

    // CFBundleVersion -> Build Number
    content = content.replaceFirstMapped(
      RegExp(
        r'(<key>CFBundleVersion</key>\s*<string>).*?(</string>)',
        dotAll: true,
      ),
      (m) => '${m[1]}$buildNumber${m[2]}',
    );

    if (oldContent == content) {
      _info('iOS 配置已是最新版本');
    } else {
      await file.writeAsString(content);
      _success('iOS Info.plist -> ${version}_$buildVersion');
    }
    return true;
  } catch (e) {
    _error('更新 iOS 配置失败: $e');
    return false;
  }
}

Future<bool> _updateWindows(String version, String buildVersion) async {
  try {
    final file = File('windows/runner/Runner.rc');
    if (!await file.exists()) {
      _info('跳过 Windows 配置 (文件不存在)');
      return true;
    }

    final content = await file.readAsString();
    final fullVersion = '${version}_$buildVersion';

    // 匹配 Windows RC 文件中的 VERSION_AS_STRING 定义
    final regex = RegExp(
      r'(#if defined\(FLUTTER_VERSION\)\s+#define VERSION_AS_STRING\s+").*?("\s+#else\s+#define VERSION_AS_STRING\s+").*?("\s+#endif)',
      dotAll: true,
    );

    if (!regex.hasMatch(content)) {
      _info('Windows Runner.rc 中未找到版本定义，跳过');
      return true;
    }

    final updatedContent = content.replaceFirstMapped(regex, (m) {
      return '${m[1]}$fullVersion${m[2]}$fullVersion${m[3]}';
    });

    if (content == updatedContent) {
      _info('Windows 配置已是最新版本');
    } else {
      await file.writeAsString(updatedContent);
      _success('Windows Runner.rc -> $fullVersion');
    }
    return true;
  } catch (e) {
    _error('更新 Windows 配置失败: $e');
    return false;
  }
}
