import 'package:flutter/material.dart';

typedef SidebarTitleResolver = String? Function(BuildContext context);

class SidebarTitleRegistry {
  static final SidebarTitleRegistry _instance = SidebarTitleRegistry._internal();
  factory SidebarTitleRegistry() => _instance;
  SidebarTitleRegistry._internal();

  final Map<String, SidebarTitleResolver> _resolvers = {};

  void register(String id, SidebarTitleResolver resolver) {
    _resolvers[id] = resolver;
  }

  String resolve(BuildContext context, String fallbackTitle) {
    final entries = _resolvers.entries.toList();
    for (var i = entries.length - 1; i >= 0; i--) {
      final title = entries[i].value(context);
      if (title != null && title.trim().isNotEmpty) {
        return title;
      }
    }
    return fallbackTitle;
  }

  void clear() {
    _resolvers.clear();
  }
}
