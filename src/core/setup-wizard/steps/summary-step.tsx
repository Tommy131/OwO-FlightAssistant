import { LocalizationKeys } from '../../localization/localization-keys';
import { translate } from '../../services/localization-service';
import { MaterialIcon } from '../../widgets/common/icon';
import type { WizardStep } from '../wizard-step-registry';
import styles from './steps.module.css';

/**
 * 配置确认步骤
 *
 * 对应 Flutter 版 `setup_wizard/steps/summary_step.dart`：
 * 汇总前置各步骤 `getSummary()` 返回的键值对。
 * Web 版额外说明数据存放位置（IndexedDB），替代桌面版的「最终存储路径」条目。
 */
export function SummaryStep({ steps }: { steps: WizardStep[] }): WizardStep {
  return {
    id: 'summary',
    title: translate(LocalizationKeys.summaryStep),
    // 恒定最大值，保证排在所有模块自定义步骤之后
    priority: Number.MAX_SAFE_INTEGER,
    canGoNext: () => true,
    render: () => <SummaryStepView steps={steps} />,
  };
}

function SummaryStepView({ steps }: { steps: WizardStep[] }) {
  // 收集除自身外所有步骤的摘要
  const entries: [string, string][] = [];
  for (const step of steps) {
    if (step.id === 'summary') continue;
    const summary = step.getSummary?.();
    if (!summary) continue;
    entries.push(...Object.entries(summary));
  }

  return (
    <div className={styles.stepBody}>
      <p className={styles.stepDesc}>{translate(LocalizationKeys.finishSetupHint)}</p>

      <div className={styles.summaryCard}>
        <div className={styles.summaryHeader}>
          <MaterialIcon name="fact_check" size={17} color="var(--color-primary)" />
          <span>{translate(LocalizationKeys.configSummary)}</span>
          <span className={styles.summaryCount}>
            {translate(LocalizationKeys.configCompleted, steps.length - 1)}
          </span>
        </div>

        <dl className={styles.summaryList}>
          {entries.map(([key, value]) => (
            <div key={key} className={styles.summaryRow}>
              <dt className={styles.summaryKey}>{key}</dt>
              <dd className={styles.summaryValue}>{value}</dd>
            </div>
          ))}
          {/* Web 版特有：说明数据落在浏览器 IndexedDB */}
          <div className={styles.summaryRow}>
            <dt className={styles.summaryKey}>{translate(LocalizationKeys.finalStorage)}</dt>
            <dd className={styles.summaryValue}>
              {translate(LocalizationKeys.webStorageLocation)}
            </dd>
          </div>
        </dl>
      </div>

      <div className={styles.readyBanner}>
        <MaterialIcon name="check_circle" filled size={18} color="var(--color-success)" />
        <span>{translate(LocalizationKeys.allReady)}</span>
      </div>
    </div>
  );
}
