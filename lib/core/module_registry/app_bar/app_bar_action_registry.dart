import 'app_bar_action.dart';
import '../clearable.dart';

/// App Bar 操作按钮注册表
class AppBarActionRegistry implements Clearable {
  static final AppBarActionRegistry _instance =
      AppBarActionRegistry._internal();
  factory AppBarActionRegistry() => _instance;
  AppBarActionRegistry._internal();

  final Map<String, AppBarAction Function()> _actionFactories = {};
  final Map<String, AppBarSideMenuEntry Function()> _sideMenuFactories = {};

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

  void registerSideMenu(String id, AppBarSideMenuEntry Function() factory) {
    _sideMenuFactories[id] = factory;
  }

  List<AppBarSideMenuEntry> getSideMenus(String navigationId) {
    final menus = _sideMenuFactories.values
        .map((factory) => factory())
        .where((entry) => entry.navigationId == navigationId)
        .toList();
    menus.sort((a, b) => a.priority.compareTo(b.priority));
    return menus;
  }

  /// 清空所有注册
  @override
  void clear() {
    _actionFactories.clear();
    _sideMenuFactories.clear();
  }
}
