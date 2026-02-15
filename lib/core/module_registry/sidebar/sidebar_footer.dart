import 'package:flutter/material.dart';

/// 侧边栏页脚组件接口
abstract class SidebarFooter {
  final String id;
  final int priority;

  SidebarFooter({required this.id, this.priority = 100});

  /// 构建侧边栏展开时的组件
  Widget buildExpanded(BuildContext context);

  /// 构建侧边栏折叠时的组件
  Widget buildCollapsed(BuildContext context);
}
