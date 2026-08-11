import { beforeEach, describe, expect, it } from 'vitest';

import { useWorkflowStore } from './workflow-store';

/**
 * 任务流 store 的行为测试
 *
 * 判定逻辑本身在 `services/flight-workflow.test.ts`（纯函数）。
 * 这里只盯 store 这一层：**改了输入之后，界面读的那份派生状态有没有跟着变**。
 * 之前就是这一层漏了重算 —— 纯函数全绿，界面却是死的。
 */

const EXTERNAL_INPUT = {
  hasDestination: false,
  hasPlannedRoute: false,
  isConnected: false,
  hasPosition: false,
  checklistProgress: 0,
  isRecording: false,
  savedLogCount: 0,
};

describe('useWorkflowStore', () => {
  beforeEach(() => {
    useWorkflowStore.getState().reset();
    useWorkflowStore.getState().recompute(EXTERNAL_INPUT);
  });

  it('什么都没做时停在第一步', () => {
    const { state } = useWorkflowStore.getState();
    expect(state.activeStage).toBe('briefing');
    expect(state.completedCount).toBe(0);
  });

  /*
   * 这条是那个 bug 的回归测试。
   *
   * 原实现里 acknowledge 只 set 了 acknowledged，派生的 state 要等
   * recompute() 被外部 store 的订阅驱动才更新。没连模拟器时那几个 store
   * 根本不动，于是「跳过当前步骤」点下去箭头和 0/4 纹丝不动。
   * 判据必须落在 state 上，只断言 acknowledged 是抓不到这个 bug 的。
   */
  it('手动跳过后立刻推进当前步，不必等外部 store 再来一次 recompute', () => {
    useWorkflowStore.getState().acknowledge('briefing');

    const { state } = useWorkflowStore.getState();
    expect(state.stages[0].status).toBe('done');
    expect(state.activeStage).toBe('map');
    expect(state.completedCount).toBe(1);
  });

  it('连跳两步时计数与当前步同步累加', () => {
    useWorkflowStore.getState().acknowledge('briefing');
    useWorkflowStore.getState().acknowledge('map');

    const { state } = useWorkflowStore.getState();
    expect(state.activeStage).toBe('checklist');
    expect(state.completedCount).toBe(2);
  });

  it('撤销手动跳过同样立刻回退当前步', () => {
    useWorkflowStore.getState().acknowledge('briefing');
    useWorkflowStore.getState().unacknowledge('briefing');

    const { state } = useWorkflowStore.getState();
    expect(state.activeStage).toBe('briefing');
    expect(state.completedCount).toBe(0);
  });

  it('重复跳过同一步不会把计数加两次', () => {
    useWorkflowStore.getState().acknowledge('briefing');
    useWorkflowStore.getState().acknowledge('briefing');

    expect(useWorkflowStore.getState().state.completedCount).toBe(1);
  });

  /*
   * 手动跳过之后紧接着来一帧遥测：不能因为「输入指纹和上次一样」
   * 就把手动跳过的结果判成无需重算而丢掉。
   */
  it('跳过后再来一次相同输入的 recompute，不会把跳过结果抹掉', () => {
    useWorkflowStore.getState().acknowledge('briefing');
    useWorkflowStore.getState().recompute(EXTERNAL_INPUT);

    const { state } = useWorkflowStore.getState();
    expect(state.activeStage).toBe('map');
    expect(state.completedCount).toBe(1);
  });

  it('外部输入变化仍能自动推进（自动判定没被破坏）', () => {
    useWorkflowStore.getState().recompute({ ...EXTERNAL_INPUT, hasDestination: true });

    const { state } = useWorkflowStore.getState();
    expect(state.stages[0].status).toBe('done');
    expect(state.stages[0].autoCompleted).toBe(true);
    expect(state.activeStage).toBe('map');
  });

  /*
   * reset 清的是「我手动跳过了哪几步」，不该顺手把模拟器的真实状态也忘掉 ——
   * 否则新一段航程开始时，明明还连着模拟器，地图那步却回退成未完成。
   */
  it('reset 只清手动跳过，自动判定的完成状态保留', () => {
    useWorkflowStore.getState().recompute({
      ...EXTERNAL_INPUT,
      isConnected: true,
      hasPosition: true,
    });
    useWorkflowStore.getState().acknowledge('briefing');
    expect(useWorkflowStore.getState().state.completedCount).toBe(2);

    useWorkflowStore.getState().reset();

    const { state } = useWorkflowStore.getState();
    expect(state.stages[0].status).toBe('active'); // 手动跳过被清掉
    expect(state.stages[1].status).toBe('done'); // 自动判定的地图仍算完成
    expect(state.completedCount).toBe(1);
  });
});
