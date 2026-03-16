import 'package:flutter/material.dart';
import '../../../modules/common/providers/home_provider.dart';

abstract class SidebarMiniCard {
  final String id;
  final int priority;

  SidebarMiniCard({required this.id, this.priority = 100});

  bool canDisplay(HomeProvider? home);

  Widget build(
    BuildContext context, {
    required ThemeData theme,
    required bool isCollapsed,
    required HomeProvider? home,
  });
}
