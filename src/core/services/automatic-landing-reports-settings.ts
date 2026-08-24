/**
 * 自动落地报告设置端口（Port）
 *
 * General Settings 属于 core，不能反向依赖 flight_logs 模块。模块注册时注入
 * landing store 的适配器；未注入时保持默认启用，便于模块被裁剪时安全降级。
 */
export interface AutomaticLandingReportsSettings {
  getEnabled: () => boolean;
  setEnabled: (enabled: boolean) => Promise<void>;
  subscribe: (listener: () => void) => () => void;
}

let settings: AutomaticLandingReportsSettings | null = null;

/** 由 flight_logs 模块注册 landing store 适配器；传 null 用于测试或模块卸载。 */
export function setAutomaticLandingReportsSettings(
  implementation: AutomaticLandingReportsSettings | null,
): void {
  settings = implementation;
}

/** 未安装业务模块时仍保持产品默认值：自动记录已启用。 */
export function getAutomaticLandingReportsEnabled(): boolean {
  return settings?.getEnabled() ?? true;
}

export function updateAutomaticLandingReportsEnabled(enabled: boolean): Promise<void> {
  return settings?.setEnabled(enabled) ?? Promise.resolve();
}

export function subscribeToAutomaticLandingReportsSettings(listener: () => void): () => void {
  return settings?.subscribe(listener) ?? (() => {});
}
