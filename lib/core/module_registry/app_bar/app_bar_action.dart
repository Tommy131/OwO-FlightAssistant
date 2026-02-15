import 'package:flutter/material.dart';

/// App Bar 操作按钮接口
abstract class AppBarAction {
  final String id;
  final int priority;

  AppBarAction({required this.id, this.priority = 100});

  Widget build(BuildContext context);
}
