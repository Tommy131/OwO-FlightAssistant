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

/** 单机型检查单 */
export interface AircraftChecklist {
  readonly id: string;
  readonly name: string;
  readonly family: AircraftFamily;
  readonly sections: ChecklistSection[];
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
