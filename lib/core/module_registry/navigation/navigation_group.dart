import 'package:flutter/material.dart';

/// 导航分组模型
/// 用于对侧边栏导航项进行分组
class NavigationGroup {
  final String id;
  final String title;
  final IconData icon;
  final int priority; // 排序优先级，数值越小越靠前
  final bool initiallyExpanded; // 初始是否展开

  const NavigationGroup({
    required this.id,
    required this.title,
    required this.icon,
    this.priority = 100,
    this.initiallyExpanded = true,
  });

  /// 复制并更新
  NavigationGroup copyWith({
    String? id,
    String? title,
    IconData? icon,
    int? priority,
    bool? initiallyExpanded,
  }) {
    return NavigationGroup(
      id: id ?? this.id,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      priority: priority ?? this.priority,
      initiallyExpanded: initiallyExpanded ?? this.initiallyExpanded,
    );
  }
}
