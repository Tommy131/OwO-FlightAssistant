/**
 * 跨模块飞行任务流
 *
 * 把散在四个模块里的准备工作串成一条有顺序的线：
 *
 *   Briefing ──> Map ──> Checklist ──> Flight Logs
 *   订好航段     看清航路   逐项检查      录下这趟飞行
 *
 * ── 为什么需要它 ──
 * 这四件事本来就有先后：没定目的地就没法看航路，没看航路就不知道该盯哪段，
 * 检查单没走完不该起飞，起飞了才有日志可录。但界面上它们是四个平级的导航项，
 * 新用户根本看不出顺序，老用户也会漏掉其中一步（最常见的是忘了开录制，
 * 落地才发现这趟没留下任何数据）。
 *
 * ── 完成判定 ──
 * 每一步都能从已有状态**自动**判定完成，不需要用户手动打勾；
 * 同时允许手动跳过（acknowledged）—— 有人就是不用简报直接飞，
 * 强制卡着不让往下走只会让人关掉这个功能。
 *
 * 纯计算：不 import React / store / IO，可被直接单测。
 */

/** 任务流阶段 */
export type WorkflowStageId = 'briefing' | 'map' | 'checklist' | 'flight_logs';

/** 阶段完成状态 */
export type WorkflowStageStatus = 'done' | 'active' | 'pending';

/** 判定任务流所需的外部状态 */
export interface WorkflowInput {
  /** 是否已设定目的地机场 */
  hasDestination: boolean;
  /** 是否已导入航路计划 */
  hasPlannedRoute: boolean;
  /** 是否已连接模拟器 */
  isConnected: boolean;
  /** 是否已拿到本机位置 */
  hasPosition: boolean;
  /** 当前检查单阶段的完成度 0–1 */
  checklistProgress: number;
  /** 是否正在录制飞行日志 */
  isRecording: boolean;
  /** 已保存的飞行日志条数 */
  savedLogCount: number;
  /** 用户手动确认已完成的阶段 */
  acknowledged: ReadonlySet<WorkflowStageId>;
}

/** 单个阶段的判定结果 */
export interface WorkflowStage {
  id: WorkflowStageId;
  /** 对应的导航项 id，点「前往」时跳过去 */
  navigationId: string;
  status: WorkflowStageStatus;
  /** 该阶段自动判定为完成的原因；手动确认时为 undefined */
  autoCompleted: boolean;
}

/** 整条任务流的状态 */
export interface WorkflowState {
  stages: WorkflowStage[];
  /** 当前该做的那一步；全部完成时为 undefined */
  activeStage?: WorkflowStageId;
  completedCount: number;
  totalCount: number;
}

/** 阶段顺序即执行顺序 */
export const WORKFLOW_STAGE_IDS: WorkflowStageId[] = [
  'briefing',
  'map',
  'checklist',
  'flight_logs',
];

/** 阶段 → 导航项 id */
export const WORKFLOW_NAVIGATION_ID: Record<WorkflowStageId, string> = {
  briefing: 'briefing',
  map: 'map',
  checklist: 'checklist',
  flight_logs: 'flight_logs',
};

/** 阶段 → Material 图标 */
export const WORKFLOW_STAGE_ICON: Record<WorkflowStageId, string> = {
  briefing: 'description',
  map: 'map',
  checklist: 'checklist',
  flight_logs: 'flight_takeoff',
};

/** 判定单个阶段是否已自动完成 */
export function isStageAutoComplete(stage: WorkflowStageId, input: WorkflowInput): boolean {
  switch (stage) {
    case 'briefing':
      // 定了目的地或导入了航路，都算简报做完了
      return input.hasDestination || input.hasPlannedRoute;
    case 'map':
      // 连上模拟器并拿到位置，说明地图已经能用了
      return input.isConnected && input.hasPosition;
    case 'checklist':
      // 当前阶段全部勾完才算过；勾了一半不算
      return input.checklistProgress >= 1;
    case 'flight_logs':
      // 正在录，或者这趟已经存下过日志
      return input.isRecording || input.savedLogCount > 0;
  }
}

/**
 * 计算整条任务流的状态。
 *
 * 「当前该做的那一步」= 第一个未完成的阶段。不做「必须按顺序完成」的强制 ——
 * 用户可能先开了录制再去看简报，那两步都该显示为已完成。
 */
export function evaluateWorkflow(input: WorkflowInput): WorkflowState {
  const stages: WorkflowStage[] = WORKFLOW_STAGE_IDS.map((id) => {
    const auto = isStageAutoComplete(id, input);
    const done = auto || input.acknowledged.has(id);
    return {
      id,
      navigationId: WORKFLOW_NAVIGATION_ID[id],
      status: done ? 'done' : 'pending',
      autoCompleted: auto,
    };
  });

  const activeIndex = stages.findIndex((stage) => stage.status === 'pending');
  if (activeIndex >= 0) {
    stages[activeIndex].status = 'active';
  }

  return {
    stages,
    activeStage: activeIndex >= 0 ? stages[activeIndex].id : undefined,
    completedCount: stages.filter((stage) => stage.status === 'done').length,
    totalCount: stages.length,
  };
}
