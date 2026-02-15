/// 版本更新配置类
/// 允许开发者在core文件夹外自定义更新检测的URL配置
class UpdateConfig {
  /// 获取最新版本信息的API地址
  /// 期望返回JSON格式: {"version": "1.0.0", "description": "更新内容", "downloadUrl": "下载地址"}
  final String versionCheckUrl;

  /// 下载地址（可选，如果versionCheckUrl返回的JSON中包含downloadUrl则使用JSON中的）
  final String? downloadUrl;

  /// 请求超时时间（秒）
  final int timeoutSeconds;

  const UpdateConfig({
    required this.versionCheckUrl,
    this.downloadUrl,
    this.timeoutSeconds = 10,
  });

  /// 默认配置（开发者可以覆盖此配置）
  static UpdateConfig? _customConfig;

  /// 设置自定义配置
  static void setCustomConfig(UpdateConfig config) {
    _customConfig = config;
  }

  /// 获取当前配置
  static UpdateConfig? get current {
    return _customConfig;
  }

  /// 检查是否已配置有效的更新服务
  /// 返回true表示已配置，false表示使用默认示例地址
  static bool get isConfigured {
    return _customConfig != null;
  }

  /// 重置为默认配置
  static void resetToDefault() {
    _customConfig = null;
  }
}
