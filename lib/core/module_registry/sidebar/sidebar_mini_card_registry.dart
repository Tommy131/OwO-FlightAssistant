import 'package:flutter/material.dart';

import 'sidebar_mini_card.dart';
import '../clearable.dart';

class SidebarMiniCardRegistry implements Clearable {
  static final SidebarMiniCardRegistry _instance =
      SidebarMiniCardRegistry._internal();
  factory SidebarMiniCardRegistry() => _instance;
  SidebarMiniCardRegistry._internal();

  final Map<String, SidebarMiniCard Function()> _cardFactories = {};

  void register(String id, SidebarMiniCard Function() factory) {
    _cardFactories[id] = factory;
  }

  bool contains(String id) => _cardFactories.containsKey(id);

  SidebarMiniCard? resolve(BuildContext context) {
    final cards = _cardFactories.values.map((factory) => factory()).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    for (final card in cards) {
      if (card.canDisplay(context)) {
        return card;
      }
    }
    return null;
  }

  @override
  void clear() {
    _cardFactories.clear();
  }
}
