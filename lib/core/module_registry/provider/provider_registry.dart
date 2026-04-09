import 'package:provider/single_child_widget.dart';

import '../clearable.dart';

/// Provider 注册管理器
/// 允许模块注册全局或局部的 Provider
class ProviderRegistry implements Clearable {
  static final ProviderRegistry _instance = ProviderRegistry._internal();
  factory ProviderRegistry() => _instance;
  ProviderRegistry._internal();

  final List<SingleChildWidget> _providers = [];

  /// 注册 Provider
  ///
  /// [provider] 必须是 SingleChildWidget 的子类，例如 ChangeNotifierProvider, Provider 等
  void register(SingleChildWidget provider) {
    if (!_providers.contains(provider)) {
      _providers.add(provider);
    }
  }

  /// 获取所有已注册的 Provider
  List<SingleChildWidget> getAll() {
    return List.unmodifiable(_providers);
  }

  /// 清空注册表（仅用于测试）
  @override
  void clear() {
    _providers.clear();
  }
}
