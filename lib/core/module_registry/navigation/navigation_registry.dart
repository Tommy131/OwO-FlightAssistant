import 'package:flutter/material.dart';
import 'navigation_item.dart';
import 'navigation_group.dart';

class NavigationCommandBus {
  static final NavigationCommandBus _instance =
      NavigationCommandBus._internal();
  factory NavigationCommandBus() => _instance;
  NavigationCommandBus._internal();

  final ValueNotifier<String?> targetId = ValueNotifier<String?>(null);

  void goTo(String id) {
    targetId.value = id;
  }

  void clear() {
    targetId.value = null;
  }
}

typedef NavigationAvailabilityResolver =
    bool Function(BuildContext context, NavigationItem item);

class NavigationAvailabilityRegistry {
  static final NavigationAvailabilityRegistry _instance =
      NavigationAvailabilityRegistry._internal();
  factory NavigationAvailabilityRegistry() => _instance;
  NavigationAvailabilityRegistry._internal();

  final List<NavigationAvailabilityResolver> _resolvers = [];

  void register(NavigationAvailabilityResolver resolver) {
    _resolvers.add(resolver);
  }

  bool isEnabled(BuildContext context, NavigationItem item) {
    for (final resolver in _resolvers) {
      if (!resolver(context, item)) {
        return false;
      }
    }
    return true;
  }

  void clear() {
    _resolvers.clear();
  }
}

/// 导航注册项
/// 可以是单个导航项，也可以是一个分组
class NavigationElement {
  final NavigationItem? item;
  final NavigationGroup? group;
  final List<NavigationItem> children;

  NavigationElement.item(this.item)
      : group = null,
        children = [];
  NavigationElement.group(this.group, this.children) : item = null;

  bool get isGroup => group != null;
  int get priority => isGroup ? group!.priority : item!.priority;
}

/// 导航项注册表
class NavigationRegistry {
  static final NavigationRegistry _instance = NavigationRegistry._internal();
  factory NavigationRegistry() => _instance;
  NavigationRegistry._internal();

  final List<NavigationItem Function(BuildContext)> _itemFactories = [];
  final List<NavigationGroup Function(BuildContext)> _groupFactories = [];

  /// 注册导航项
  void register(NavigationItem Function(BuildContext) factory) {
    _itemFactories.add(factory);
  }

  /// 注册导航分组
  void registerGroup(NavigationGroup Function(BuildContext) factory) {
    _groupFactories.add(factory);
  }

  /// 获取所有已注册的导航项（按优先级排序）
  List<NavigationItem> getAllItems(BuildContext context) {
    final items = _itemFactories.map((factory) => factory(context)).toList();
    // 按优先级排序，数值越小越靠前
    items.sort((a, b) => a.priority.compareTo(b.priority));
    return items;
  }

  /// 获取所有导航元素（包含分组和孤立项）
  List<NavigationElement> getNavigationElements(BuildContext context) {
    final allItems = _itemFactories.map((factory) => factory(context)).toList();
    final allGroups = _groupFactories.map((factory) => factory(context)).toList();

    final List<NavigationElement> elements = [];
    final Set<String> processedItemIds = {};

    // 1. 处理分组
    for (final group in allGroups) {
      final children = allItems
          .where((item) => item.groupId == group.id)
          .toList()
        ..sort((a, b) => a.priority.compareTo(b.priority));

      elements.add(NavigationElement.group(group, children));
      processedItemIds.addAll(children.map((e) => e.id));
    }

    // 2. 处理不属于任何分组的孤立项
    final orphanItems = allItems.where((item) => !processedItemIds.contains(item.id));
    for (final item in orphanItems) {
      elements.add(NavigationElement.item(item));
    }

    // 3. 整体按优先级排序
    elements.sort((a, b) => a.priority.compareTo(b.priority));

    return elements;
  }

  /// 清空所有注册
  void clear() {
    _itemFactories.clear();
    _groupFactories.clear();
  }
}
