import { describe, expect, it } from 'vitest';

import {
  WORKFLOW_STAGE_IDS,
  evaluateWorkflow,
  isStageAutoComplete,
  type WorkflowInput,
  type WorkflowStageId,
} from './flight-workflow';

function input(overrides: Partial<WorkflowInput> = {}): WorkflowInput {
  return {
    hasDestination: false,
    hasPlannedRoute: false,
    isConnected: false,
    hasPosition: false,
    checklistProgress: 0,
    isRecording: false,
    savedLogCount: 0,
    acknowledged: new Set<WorkflowStageId>(),
    ...overrides,
  };
}

describe('isStageAutoComplete', () => {
  it('定了目的地就算简报做完', () => {
    expect(isStageAutoComplete('briefing', input({ hasDestination: true }))).toBe(true);
  });

  it('导入了航路也算简报做完', () => {
    expect(isStageAutoComplete('briefing', input({ hasPlannedRoute: true }))).toBe(true);
  });

  it('连上但没位置时地图这步不算完', () => {
    expect(isStageAutoComplete('map', input({ isConnected: true, hasPosition: false }))).toBe(false);
    expect(isStageAutoComplete('map', input({ isConnected: true, hasPosition: true }))).toBe(true);
  });

  it('检查单勾了一半不算完', () => {
    expect(isStageAutoComplete('checklist', input({ checklistProgress: 0.9 }))).toBe(false);
    expect(isStageAutoComplete('checklist', input({ checklistProgress: 1 }))).toBe(true);
  });

  it('正在录制或已有存档都算日志这步完成', () => {
    expect(isStageAutoComplete('flight_logs', input({ isRecording: true }))).toBe(true);
    expect(isStageAutoComplete('flight_logs', input({ savedLogCount: 3 }))).toBe(true);
    expect(isStageAutoComplete('flight_logs', input())).toBe(false);
  });
});

describe('evaluateWorkflow', () => {
  it('什么都没做时第一步是待办、其余待定', () => {
    const state = evaluateWorkflow(input());
    expect(state.activeStage).toBe('briefing');
    expect(state.completedCount).toBe(0);
    expect(state.totalCount).toBe(WORKFLOW_STAGE_IDS.length);
    expect(state.stages.map((s) => s.status)).toEqual(['active', 'pending', 'pending', 'pending']);
  });

  it('第一步完成后当前步推进到第二步', () => {
    const state = evaluateWorkflow(input({ hasDestination: true }));
    expect(state.activeStage).toBe('map');
    expect(state.stages[0].status).toBe('done');
    expect(state.stages[1].status).toBe('active');
  });

  it('全部完成时没有当前步', () => {
    const state = evaluateWorkflow(
      input({
        hasDestination: true,
        isConnected: true,
        hasPosition: true,
        checklistProgress: 1,
        isRecording: true,
      }),
    );
    expect(state.activeStage).toBeUndefined();
    expect(state.completedCount).toBe(4);
  });

  // 用户可能先开录制再回头做简报，这时两步都该算完成，
  // 不能因为「顺序不对」把后面那步判回未完成。
  it('乱序完成时按实际状态判定，不强制顺序', () => {
    const state = evaluateWorkflow(input({ isRecording: true }));
    expect(state.stages[3].status).toBe('done');
    expect(state.activeStage).toBe('briefing');
    expect(state.completedCount).toBe(1);
  });

  it('手动确认可以跳过某一步', () => {
    const state = evaluateWorkflow(input({ acknowledged: new Set<WorkflowStageId>(['briefing']) }));
    expect(state.stages[0].status).toBe('done');
    expect(state.stages[0].autoCompleted).toBe(false);
    expect(state.activeStage).toBe('map');
  });

  it('自动完成的阶段带 autoCompleted 标记，手动跳过的不带', () => {
    const state = evaluateWorkflow(
      input({ hasDestination: true, acknowledged: new Set<WorkflowStageId>(['map']) }),
    );
    expect(state.stages[0].autoCompleted).toBe(true);
    expect(state.stages[1].autoCompleted).toBe(false);
    expect(state.stages[1].status).toBe('done');
  });

  it('每个阶段都带上可跳转的导航项 id', () => {
    const state = evaluateWorkflow(input());
    expect(state.stages.map((s) => s.navigationId)).toEqual([
      'briefing',
      'map',
      'checklist',
      'flight_logs',
    ]);
  });

  it('自动完成会覆盖掉之前的手动跳过标记（状态仍是完成）', () => {
    const state = evaluateWorkflow(
      input({ hasDestination: true, acknowledged: new Set<WorkflowStageId>(['briefing']) }),
    );
    expect(state.stages[0].status).toBe('done');
    expect(state.stages[0].autoCompleted).toBe(true);
  });
});
