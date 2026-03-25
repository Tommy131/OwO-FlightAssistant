import 'package:flutter/material.dart';

/// App Bar 操作按钮接口
abstract class AppBarAction {
  final String id;
  final int priority;

  AppBarAction({required this.id, this.priority = 100});

  Widget build(BuildContext context);
}

class AppBarSideMenuEntry {
  final String id;
  final String navigationId;
  final IconData icon;
  final int priority;
  final String Function(BuildContext) titleBuilder;
  final bool Function(BuildContext)? isSelected;
  final Listenable? stateListenable;
  final void Function(BuildContext) onTap;

  const AppBarSideMenuEntry({
    required this.id,
    required this.navigationId,
    required this.icon,
    required this.titleBuilder,
    required this.onTap,
    this.isSelected,
    this.stateListenable,
    this.priority = 100,
  });
}
