import 'package:flutter/material.dart';
import '../models/navigation_item.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/desktop/sidebar.dart';

/// 桌面端布局
/// 左侧：可展开/折叠的侧边栏
/// 右侧：AppBar + 主内容区
class DesktopLayout extends StatelessWidget {
  final List<NavigationItem> navigationItems;
  final int selectedIndex;
  final Function(int) onNavigationChanged;

  const DesktopLayout({
    super.key,
    required this.navigationItems,
    required this.selectedIndex,
    required this.onNavigationChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentItem = navigationItems[selectedIndex];

    return Scaffold(
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 1000, // 设置最小宽度为 1000px
          ),
          child: IntrinsicWidth(
            child: SizedBox(
              width: MediaQuery.of(context).size.width < 1000
                  ? 1000
                  : MediaQuery.of(context).size.width,
              child: Row(
                children: [
                  // 左侧边栏
                  DesktopSidebar(
                    items: navigationItems,
                    selectedIndex: selectedIndex,
                    onItemSelected: onNavigationChanged,
                  ),

                  // 右侧主内容区
                  Expanded(
                    child: Column(
                      children: [
                        // AppBar
                        CustomAppBar.build(currentItem, context),

                        // 主内容
                        Expanded(child: currentItem.page),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
