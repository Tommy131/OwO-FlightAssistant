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

/** 外部输入：不含手动确认集合的那部分，由各业务 store 提供 */
type ExternalInput = Omit<WorkflowInput, 'acknowledged'>;

interface WorkflowStoreState {
  state: WorkflowState;
  /** 用户手动确认已完成的阶段 */
  acknowledged: ReadonlySet<WorkflowStageId>;

  /** 由 store 绑定按最新输入重算 */
  recompute: (input: ExternalInput) => void;
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

/**
 * 上一次外部输入的指纹，用来判断是否值得重算。
 *
 * 还要把输入本身留一份：手动确认/撤销只改 `acknowledged`，
 * 但重算需要完整输入 —— 没有它就只能干等下一次 `recompute()` 上门，
 * 那正是「点了跳过，箭头不动」的成因（详见 acknowledge 的注释）。
 */
let lastInputKey = '';
let lastInput: ExternalInput = emptyExternalInput();

export const useWorkflowStore = create<WorkflowStoreState>((set, get) => {
  /**
   * 改完手动确认集合后立刻重算派生状态。
   *
   * 必须在这里同步重算，不能只 `set({ acknowledged })` 就完事：
   * 界面读的是派生出来的 `state`（箭头位置、已完成计数），而 `recompute()`
   * 只由 flightData / flightLogs / plannedRoute 三个 store 的订阅驱动。
   * 没连模拟器时那三个 store 根本不动，于是「跳过当前步骤」点了没反应 ——
   * 内部标记确实记下了，可箭头和 0/4 一直停在原地。
   */
  const applyAcknowledged = (acknowledged: ReadonlySet<WorkflowStageId>) => {
    lastInputKey = inputKey(lastInput, acknowledged);
    set({ acknowledged, state: evaluateWorkflow({ ...lastInput, acknowledged }) });
  };

  return {
    state: evaluateWorkflow(emptyInput()),
    acknowledged: EMPTY_ACK,

    recompute(input) {
      lastInput = input;
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
      applyAcknowledged(next);
    },

    unacknowledge(stage) {
      const next = new Set(get().acknowledged);
      if (!next.delete(stage)) return;
      applyAcknowledged(next);
    },

    goToStage(stage) {
      NavigationCommandBus.goTo(WORKFLOW_NAVIGATION_ID[stage]);
    },

    reset() {
      // 只清手动确认，外部输入（连接状态、日志条数等）保持不变 ——
      // 新一段航程该重来的是「我手动跳过了哪几步」，不是模拟器的真实状态
      applyAcknowledged(EMPTY_ACK);
    },
  };
});

function emptyExternalInput(): ExternalInput {
  return {
    hasDestination: false,
    hasPlannedRoute: false,
    isConnected: false,
    hasPosition: false,
    checklistProgress: 0,
    isRecording: false,
    savedLogCount: 0,
  };
}

function emptyInput(): WorkflowInput {
  return { ...emptyExternalInput(), acknowledged: EMPTY_ACK };
}

/** 把输入折成一个短字符串用于判等；连续量先离散化，免得每帧都变 */
function inputKey(input: ExternalInput, acknowledged: ReadonlySet<WorkflowStageId>): string {
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
