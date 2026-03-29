import 'package:flutter/foundation.dart';

/// 返回操作回调接口
typedef BackHandler = bool Function();

/// 统一管理模块内部返回操作的回调服务
class BackHandlerService extends ChangeNotifier {
  static final BackHandlerService _instance = BackHandlerService._internal();
  factory BackHandlerService() => _instance;
  BackHandlerService._internal();

  /// 维护一个回调函数栈，后注册的优先执行
  final List<BackHandler> _handlers = [];

  /// 注册返回操作回调
  void register(BackHandler handler) {
    _handlers.add(handler);
  }

  /// 注销返回操作回调
  void unregister(BackHandler handler) {
    _handlers.remove(handler);
  }

  /// 执行返回操作处理
  /// 返回 true 表示已被处理，不再继续向上传递
  /// 返回 false 表示未被处理，需由上层（如 app.dart）继续处理
  bool handleBack() {
    // 逆序遍历，确保嵌套组件的回调先执行
    for (var i = _handlers.length - 1; i >= 0; i--) {
      try {
        if (_handlers[i]()) {
          return true;
        }
      } catch (e) {
        // 忽略处理过程中可能发生的异常
        debugPrint('Error handling back: $e');
      }
    }
    return false;
  }
}
