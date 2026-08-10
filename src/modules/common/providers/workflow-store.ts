import { create } from 'zustand';

import { NavigationCommandBus } from '../../../core/module-registry/navigation/navigation-registry';
import {
  evaluateWorkflow,
  WORKFLOW_NAVIGATION_ID,
  type WorkflowInput,
  type WorkflowStageId,
  type WorkflowState,
} from '../services/flight-workflow';

/**
 * 跨模块任务流状态
 *
 * 判定逻辑全在 `services/flight-workflow.ts`（纯函数、有单测），
 * 这里只负责收集各 store 的输入、缓存结果、提供跳转与手动确认。
 */

interface WorkflowStoreState {
  state: WorkflowState;
  /** 用户手动确认已完成的阶段 */
  acknowledged: ReadonlySet<WorkflowStageId>;

  /** 由 store 绑定按最新输入重算 */
  recompute: (input: Omit<WorkflowInput, 'acknowledged'>) => void;
  /** 手动把某一步标记为完成（用于「我不用简报，直接飞」） */
  acknowledge: (stage: WorkflowStageId) => void;
  /** 撤销手动确认 */
  unacknowledge: (stage: WorkflowStageId) => void;
  /** 跳到某一步对应的页面 */
  goToStage: (stage: WorkflowStageId) => void;
  /** 清空手动确认（新一段航程） */
  reset: () => void;
}

const EMPTY_ACK: ReadonlySet<WorkflowStageId> = new Set<WorkflowStageId>();

/** 上一次的输入，用来判断是否值得重算 */
let lastInputKey = '';

export const useWorkflowStore = create<WorkflowStoreState>((set, get) => ({
  state: evaluateWorkflow(emptyInput()),
  acknowledged: EMPTY_ACK,

  recompute(input) {
    const acknowledged = get().acknowledged;
    // 遥测每 500ms 来一帧，但任务流的输入基本不变；
    // 不比对就会让整棵订阅树跟着 2Hz 重渲染。
    const key = inputKey(input, acknowledged);
    if (key === lastInputKey) return;
    lastInputKey = key;
    set({ state: evaluateWorkflow({ ...input, acknowledged }) });
  },

  acknowledge(stage) {
    const next = new Set(get().acknowledged);
    if (next.has(stage)) return;
    next.add(stage);
    lastInputKey = '';
    set({ acknowledged: next });
  },

  unacknowledge(stage) {
    const next = new Set(get().acknowledged);
    if (!next.delete(stage)) return;
    lastInputKey = '';
    set({ acknowledged: next });
  },

  goToStage(stage) {
    NavigationCommandBus.goTo(WORKFLOW_NAVIGATION_ID[stage]);
  },

  reset() {
    lastInputKey = '';
    set({ acknowledged: EMPTY_ACK, state: evaluateWorkflow(emptyInput()) });
  },
}));

function emptyInput(): WorkflowInput {
  return {
    hasDestination: false,
    hasPlannedRoute: false,
    isConnected: false,
    hasPosition: false,
    checklistProgress: 0,
    isRecording: false,
    savedLogCount: 0,
    acknowledged: EMPTY_ACK,
  };
}

/** 把输入折成一个短字符串用于判等；连续量先离散化，免得每帧都变 */
function inputKey(
  input: Omit<WorkflowInput, 'acknowledged'>,
  acknowledged: ReadonlySet<WorkflowStageId>,
): string {
  return [
    input.hasDestination ? 1 : 0,
    input.hasPlannedRoute ? 1 : 0,
    input.isConnected ? 1 : 0,
    input.hasPosition ? 1 : 0,
    // 只有「是否已达 100%」影响判定，中间值不必逐帧比
    input.checklistProgress >= 1 ? 1 : 0,
    input.isRecording ? 1 : 0,
    input.savedLogCount > 0 ? 1 : 0,
    [...acknowledged].sort().join(','),
  ].join('|');
}
