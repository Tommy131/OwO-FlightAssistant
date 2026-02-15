import 'about_page_item.dart';

/// 关于页面卡片注册表
class AboutPageRegistry {
  static final AboutPageRegistry _instance = AboutPageRegistry._internal();
  factory AboutPageRegistry() => _instance;
  AboutPageRegistry._internal();

  final Map<String, AboutPageItem> _items = {};

  /// 注册一个关于页面卡片
  /// 如果 ID 已存在，则会覆盖原有内容
  void register(AboutPageItem item) {
    _items[item.id] = item;
  }

  /// 获取所有已注册的卡片并按优先级排序
  List<AboutPageItem> getAllItems() {
    final list = _items.values.toList();
    list.sort((a, b) => a.priority.compareTo(b.priority));
    return list;
  }

  /// 移除指定卡片
  void unregister(String id) {
    _items.remove(id);
  }

  /// 清空注册表
  void clear() {
    _items.clear();
  }
}
