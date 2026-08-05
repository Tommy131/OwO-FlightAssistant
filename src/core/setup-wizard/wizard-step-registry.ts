import type { ReactNode } from 'react';
import type { Clearable } from '../module-registry/clearable';

/**
 * 首启向导步骤与注册表
 *
 * 对应 Flutter 版 `setup_wizard/wizard_step.dart` + `wizard_step_registry.dart`。
 *
 * ── Web 降级说明 ──
 * 桌面版共 4 步：语言 → 存储路径 → 日志设置 → 配置确认。
 * 浏览器不能选择磁盘目录，「存储路径」步骤被移除，
 * 由 general-settings 页的「浏览器本地存储」信息卡替代。
 */

export interface WizardStep {
  readonly id: string;
  /** 步骤标题（render 期间调用，可读 translate） */
  readonly title: string;
  /** 优先级，数字越小越靠前 */
  readonly priority: number;
  /** 是否允许进入下一步 */
  canGoNext(): boolean;
  render(): ReactNode;
  /** 步骤完成时的回调 */
  onComplete?(): Promise<void>;
  /** 步骤初始化时的回调 */
  onInit?(): void;
  /** 配置摘要（用于最后一步的汇总展示） */
  getSummary?(): Record<string, string> | null;
}

class WizardStepRegistryImpl implements Clearable {
  private factories = new Map<string, () => WizardStep>();

  register(id: string, factory: () => WizardStep): void {
    this.factories.set(id, factory);
  }

  getAllSteps(): WizardStep[] {
    return [...this.factories.values()]
      .map((factory) => factory())
      .sort((a, b) => a.priority - b.priority);
  }

  clear(): void {
    this.factories.clear();
  }
}

export const WizardStepRegistry = new WizardStepRegistryImpl();
