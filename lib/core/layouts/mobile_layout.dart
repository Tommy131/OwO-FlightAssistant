import 'package:flutter/material.dart';
import '../models/navigation_item.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/mobile/bottom_navbar.dart';

/// 移动端布局
/// 上：AppBar
/// 中：主内容区
/// 下：BottomNavbar
class MobileLayout extends StatelessWidget {
  final List<NavigationItem> navigationItems;
  final int selectedIndex;
  final Function(int) onNavigationChanged;

  const MobileLayout({
    super.key,
    required this.navigationItems,
    required this.selectedIndex,
    required this.onNavigationChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentItem = navigationItems[selectedIndex];

    return Scaffold(
      appBar: CustomAppBar.build(currentItem, context),
      body: currentItem.page,
      bottomNavigationBar: MobileBottomNavbar(
        items: navigationItems,
        selectedIndex: selectedIndex,
        onItemSelected: onNavigationChanged,
      ),
    );
  }
}
