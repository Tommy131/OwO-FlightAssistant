import 'sidebar_footer.dart';
import '../clearable.dart';

/// 侧边栏页脚注册表
class SidebarFooterRegistry implements Clearable {
  static final SidebarFooterRegistry _instance =
      SidebarFooterRegistry._internal();
  factory SidebarFooterRegistry() => _instance;
  SidebarFooterRegistry._internal();

  final Map<String, SidebarFooter Function()> _footerFactories = {};

  /// 注册页脚组件
  void register(String id, SidebarFooter Function() factory) {
    _footerFactories[id] = factory;
  }

  /// 获取所有已注册的页脚组件（按优先级排序）
  List<SidebarFooter> getAllFooters() {
    final footers = _footerFactories.values
        .map((factory) => factory())
        .toList();
    footers.sort((a, b) => a.priority.compareTo(b.priority));
    return footers;
  }

  /// 清空所有注册
  @override
  void clear() {
    _footerFactories.clear();
  }
}
