import 'package:flutter/material.dart';

abstract class SidebarTitleBadge {
  final String id;
  final int priority;

  SidebarTitleBadge({required this.id, this.priority = 100});

  bool canDisplay(BuildContext context);

  Widget build(
    BuildContext context, {
    required ThemeData theme,
    required bool isCollapsed,
  });
}
