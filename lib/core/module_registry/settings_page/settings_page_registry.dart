import 'settings_page_item.dart';
import '../clearable.dart';

/// 设置页面注册表
class SettingsPageRegistry implements Clearable {
  static final SettingsPageRegistry _instance =
      SettingsPageRegistry._internal();
  factory SettingsPageRegistry() => _instance;
  SettingsPageRegistry._internal();

  final Map<String, SettingsPageItem Function()> _pageFactories = {};

  /// 注册设置页面
  void register(String id, SettingsPageItem Function() factory) {
    _pageFactories[id] = factory;
  }

  /// 获取所有已注册的页面（按优先级排序）
  List<SettingsPageItem> getAllPages() {
    final pages = _pageFactories.values.map((factory) => factory()).toList();
    pages.sort((a, b) => a.priority.compareTo(b.priority));
    return pages;
  }

  /// 根据ID获取页面
  SettingsPageItem? getPage(String id) {
    final factory = _pageFactories[id];
    return factory?.call();
  }

  /// 清空所有注册
  @override
  void clear() {
    _pageFactories.clear();
  }
}
