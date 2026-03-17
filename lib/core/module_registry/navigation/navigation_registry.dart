import 'package:flutter/material.dart';
import 'navigation_item.dart';

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

/// 导航项注册表
class NavigationRegistry {
  static final NavigationRegistry _instance = NavigationRegistry._internal();
  factory NavigationRegistry() => _instance;
  NavigationRegistry._internal();

  final List<NavigationItem Function(BuildContext)> _itemFactories = [];

  /// 注册导航项
  void register(NavigationItem Function(BuildContext) factory) {
    _itemFactories.add(factory);
  }

  /// 获取所有已注册的导航项（按优先级排序）
  List<NavigationItem> getAllItems(BuildContext context) {
    final items = _itemFactories.map((factory) => factory(context)).toList();
    // 按优先级排序，数值越小越靠前
    items.sort((a, b) => a.priority.compareTo(b.priority));
    return items;
  }

  /// 清空所有注册
  void clear() {
    _itemFactories.clear();
  }
}
