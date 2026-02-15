/// 模块注册接口
///
/// 每个模块应实现此接口并在 register() 方法中注册其组件
abstract class ModuleRegistrar {
  /// 模块名称
  String get moduleName;

  /// 注册模块组件
  ///
  /// 在此方法中注册向导步骤、设置页面等组件到对应的注册表
  void register();
}
