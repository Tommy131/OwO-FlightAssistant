import 'package:flutter/material.dart';

import 'sidebar_title_badge.dart';

class SidebarTitleBadgeRegistry {
  static final SidebarTitleBadgeRegistry _instance =
      SidebarTitleBadgeRegistry._internal();
  factory SidebarTitleBadgeRegistry() => _instance;
  SidebarTitleBadgeRegistry._internal();

  final Map<String, SidebarTitleBadge Function()> _badgeFactories = {};

  void register(String id, SidebarTitleBadge Function() factory) {
    _badgeFactories[id] = factory;
  }

  SidebarTitleBadge? resolve(BuildContext context) {
    final badges = _badgeFactories.values.map((factory) => factory()).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    for (final badge in badges) {
      if (badge.canDisplay(context)) {
        return badge;
      }
    }
    return null;
  }

  void clear() {
    _badgeFactories.clear();
  }
}
