import { ChecklistLocalizationKeys } from '../localization/checklist-localization';

/**
 * 检查单数据模型
 * 对应 Flutter 版 `modules/checklist/models/flight_checklist.dart`
 */

/** 飞机机型家族 */
export type AircraftFamily = 'generic' | 'a320' | 'b737';

/** 检查单飞行阶段（顺序即枚举顺序，阶段推进规则依赖此顺序） */
export type ChecklistPhase =
  | 'coldAndDark'
  | 'beforePushback'
  | 'beforeTaxi'
  | 'beforeTakeoff'
  | 'cruise'
  | 'beforeDescent'
  | 'beforeApproach'
  | 'afterLanding'
  | 'parking';

/** 全部阶段，按飞行流程排序 */
export const CHECKLIST_PHASES: ChecklistPhase[] = [
  'coldAndDark',
  'beforePushback',
  'beforeTaxi',
  'beforeTakeoff',
  'cruise',
  'beforeDescent',
  'beforeApproach',
  'afterLanding',
  'parking',
];

/** 各阶段的国际化 key */
export const PHASE_LABEL_KEY: Record<ChecklistPhase, string> = {
  coldAndDark: ChecklistLocalizationKeys.phaseColdAndDark,
  beforePushback: ChecklistLocalizationKeys.phaseBeforePushback,
  beforeTaxi: ChecklistLocalizationKeys.phaseBeforeTaxi,
  beforeTakeoff: ChecklistLocalizationKeys.phaseBeforeTakeoff,
  cruise: ChecklistLocalizationKeys.phaseCruise,
  beforeDescent: ChecklistLocalizationKeys.phaseBeforeDescent,
  beforeApproach: ChecklistLocalizationKeys.phaseBeforeApproach,
  afterLanding: ChecklistLocalizationKeys.phaseAfterLanding,
  parking: ChecklistLocalizationKeys.phaseParking,
};

/** 各阶段的 Material Symbols 图标名（与桌面版 IconData 一一对应） */
export const PHASE_ICON: Record<ChecklistPhase, string> = {
  coldAndDark: 'power_settings_new',
  beforePushback: 'airport_shuttle',
  beforeTaxi: 'directions',
  beforeTakeoff: 'flight_takeoff',
  cruise: 'flight',
  beforeDescent: 'trending_down',
  beforeApproach: 'radar',
  afterLanding: 'flight_land',
  parking: 'local_parking',
};

/** 单条检查单条目 */
export interface ChecklistItem {
  readonly id: string;
  /** 需要执行的操作/任务 */
  readonly task: string;
  /** 标准响应（期望状态） */
  readonly response: string;
  /** 是否已勾选完成 */
  isChecked: boolean;
  /** 可选的补充说明 */
  readonly detail?: string;
}

/** 检查单节段（对应单个飞行阶段） */
export interface ChecklistSection {
  readonly phase: ChecklistPhase;
  readonly items: ChecklistItem[];
}

/**
 * 适用模拟器标签
 *
 * `any` 表示不限。同一机型在 X-Plane 与 MSFS 里的座舱流程常有差别
 * （电门位置、APU 引气逻辑），所以模板要能按模拟器分开写。
 */
export type SimulatorTag = 'any' | 'xplane' | 'msfs';

/** 全部模拟器标签 */
export const SIMULATOR_TAGS: SimulatorTag[] = ['any', 'xplane', 'msfs'];

/** 单机型检查单 */
export interface AircraftChecklist {
  readonly id: string;
  readonly name: string;
  readonly family: AircraftFamily;
  readonly sections: ChecklistSection[];
  /** 模板版本号（用户自己维护，便于分发时区分修订） */
  readonly version?: string;
  /**
   * 适用的机型注册码（如 B-6075、D-AIBA），可多个。
   *
   * 注册码比机型名精确得多：同一个 A320 机队里，有的装了 CFM 有的装了 IAE，
   * 检查单里的发动机项并不一样。填了注册码的模板匹配优先级最高。
   */
  readonly registrations?: string[];
  /** 适用模拟器，可多选；空或含 any 表示不限 */
  readonly simulators?: SimulatorTag[];
}

/** 取指定阶段的节段 */
export function findSection(
  checklist: AircraftChecklist | null,
  phase: ChecklistPhase,
): ChecklistSection | undefined {
  return checklist?.sections.find((section) => section.phase === phase);
}

/** 指定阶段的完成进度 0–1（无该阶段返回 0，空阶段返回 1） */
export function phaseProgress(
  checklist: AircraftChecklist | null,
  phase: ChecklistPhase,
): number {
  const section = findSection(checklist, phase);
  if (!section) return 0;
  if (section.items.length === 0) return 1;
  const checked = section.items.filter((item) => item.isChecked).length;
  return checked / section.items.length;
}

/** 深拷贝检查单（勾选状态可变，需避免共享引用） */
export function cloneChecklist(checklist: AircraftChecklist): AircraftChecklist {
  return {
    ...checklist,
    sections: checklist.sections.map((section) => ({
      ...section,
      items: section.items.map((item) => ({ ...item })),
    })),
  };
}
