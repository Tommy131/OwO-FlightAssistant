import 'app_bar_action.dart';

/// App Bar 操作按钮注册表
class AppBarActionRegistry {
  static final AppBarActionRegistry _instance =
      AppBarActionRegistry._internal();
  factory AppBarActionRegistry() => _instance;
  AppBarActionRegistry._internal();

  final Map<String, AppBarAction Function()> _actionFactories = {};

  /// 注册操作按钮
  void register(String id, AppBarAction Function() factory) {
    _actionFactories[id] = factory;
  }

  /// 获取所有已注册的操作按钮（按优先级排序）
  List<AppBarAction> getAllActions() {
    final actions = _actionFactories.values
        .map((factory) => factory())
        .toList();
    actions.sort((a, b) => a.priority.compareTo(b.priority));
    return actions;
  }

  /// 清空所有注册
  void clear() {
    _actionFactories.clear();
  }
}
