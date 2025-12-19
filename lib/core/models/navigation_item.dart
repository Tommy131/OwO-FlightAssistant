import 'package:flutter/material.dart';

/// 导航项模型
/// 用于定义侧边栏和底部导航栏的导航项
class NavigationItem {
  final String id;
  final String title;
  final IconData icon;
  final IconData? activeIcon;
  final Widget page;
  final String? badge; // 可选的徽章文本（如消息数量）

  const NavigationItem({
    required this.id,
    required this.title,
    required this.icon,
    this.activeIcon,
    required this.page,
    this.badge,
  });

  /// 复制并更新徽章
  NavigationItem copyWith({
    String? id,
    String? title,
    IconData? icon,
    IconData? activeIcon,
    Widget? page,
    String? badge,
  }) {
    return NavigationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      activeIcon: activeIcon ?? this.activeIcon,
      page: page ?? this.page,
      badge: badge ?? this.badge,
    );
  }
}
