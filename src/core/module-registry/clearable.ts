/** 可清空的注册表接口（对应 Flutter 版 clearable.dart） */
export interface Clearable {
  clear(): void;
}

/** 模块注册接口：每个模块实现此接口并在 register() 中注册其组件 */
export interface ModuleRegistrar {
  /** 模块名称 */
  readonly moduleName: string;
  /** 注册模块组件（向导步骤、设置页、导航项、Provider 等） */
  register(): void;
}
