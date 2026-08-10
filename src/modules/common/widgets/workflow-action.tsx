import { useTranslate } from '../../../core/localization/use-translate';
import type { AppBarAction } from '../../../core/module-registry/app-bar/app-bar-action';
import { PopupMenu } from '../../../core/widgets/common/controls';
import { CommonLocalizationKeys as K } from '../localization/common-localization';
import { useWorkflowStore } from '../providers/workflow-store';
import { WORKFLOW_STAGE_ICON, type WorkflowStageId } from '../services/flight-workflow';

/**
 * AppBar 上的任务流入口
 *
 * 显示「已完成/总数」，点开是四个阶段的清单：绿勾＝已完成、当前步高亮，
 * 点任一项直接跳到对应页面。
 *
 * 做成顶栏常驻而不是首页卡片，是因为它的用途正是「我现在在别的页面，
 * 下一步该去哪儿」—— 要求用户先回首页才能看到进度，等于没做。
 */
export function createWorkflowAction(): AppBarAction {
  return {
    id: 'flight_workflow',
    priority: 6,
    render: () => <WorkflowMenu />,
  };
}

const STAGE_LABEL_KEY: Record<WorkflowStageId, string> = {
  briefing: K.workflowStageBriefing,
  map: K.workflowStageMap,
  checklist: K.workflowStageChecklist,
  flight_logs: K.workflowStageFlightLogs,
};

function WorkflowMenu() {
  const t = useTranslate();
  const state = useWorkflowStore((store) => store.state);
  const goToStage = useWorkflowStore((store) => store.goToStage);
  const acknowledge = useWorkflowStore((store) => store.acknowledge);

  const allDone = state.activeStage === undefined;

  return (
    <PopupMenu
      icon={allDone ? 'task_alt' : 'route'}
      label={t(K.workflowTooltip, state.completedCount, state.totalCount)}
      items={[
        ...state.stages.map((stage) => ({
          key: stage.id,
          // 完成的打勾，当前步带箭头，其余留空 —— 一眼看出停在哪儿
          label: `${stagePrefix(stage.status)} ${t(STAGE_LABEL_KEY[stage.id])}`,
          icon: stage.status === 'done' ? 'check_circle' : WORKFLOW_STAGE_ICON[stage.id],
          selected: stage.status === 'active',
          onSelect: () => goToStage(stage.id),
        })),
        // 当前步允许手动跳过：有人就是不用简报直接飞，卡着不让走只会让人弃用
        ...(state.activeStage
          ? [
              {
                key: 'skip',
                label: t(K.workflowSkipStage),
                icon: 'skip_next',
                onSelect: () => {
                  if (state.activeStage) acknowledge(state.activeStage);
                },
              },
            ]
          : []),
      ]}
    />
  );
}

function stagePrefix(status: 'done' | 'active' | 'pending'): string {
  if (status === 'done') return '✓';
  if (status === 'active') return '▸';
  return '　';
}
