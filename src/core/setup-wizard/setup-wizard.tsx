import { useMemo, useState } from 'react';
import { AppConstants } from '../constants/app-constants';
import { LocalizationKeys } from '../localization/localization-keys';
import { useTranslate } from '../localization/use-translate';
import { ModuleRegistry } from '../module-registry/module-registry';
import { Button, ProgressBar } from '../widgets/common/controls';
import { MaterialIcon } from '../widgets/common/icon';
import { LanguageStep } from './steps/language-step';
import { LogSettingsStep } from './steps/log-settings-step';
import { SummaryStep } from './steps/summary-step';
import type { WizardStep } from './wizard-step-registry';
import styles from './setup-wizard.module.css';

/**
 * 首次启动配置向导
 *
 * 对应 Flutter 版 `core/setup_wizard/setup_wizard.dart`（539 行）。
 *
 * ── Web 降级说明 ──
 * 桌面版 4 步：语言 → 存储路径 → 日志设置 → 配置确认。
 * 浏览器无法让用户选择磁盘目录，「存储路径」步骤已移除，
 * 数据固定落在 IndexedDB（在配置确认页与设置页中说明）。
 * 模块通过 WizardStepRegistry 注册的自定义步骤仍会被拼接进来。
 */
export interface SetupWizardProps {
  onCompleted: () => Promise<void> | void;
}

export function SetupWizard({ onCompleted }: SetupWizardProps) {
  const t = useTranslate();
  const [showWelcome, setShowWelcome] = useState(true);
  const [stepIndex, setStepIndex] = useState(0);
  const [submitting, setSubmitting] = useState(false);
  // 用于在步骤内部改动后强制重算 canGoNext
  const [revision, setRevision] = useState(0);
  const notifyChanged = () => setRevision((prev) => prev + 1);

  // 内置步骤 + 模块注册的自定义步骤，按 priority 排序
  const steps: WizardStep[] = useMemo(() => {
    const builtin: WizardStep[] = [
      LanguageStep({ onChanged: notifyChanged }),
      LogSettingsStep({ onChanged: notifyChanged }),
    ];
    const registered = ModuleRegistry.wizardSteps.getAllSteps();
    const all = [...builtin, ...registered].sort((a, b) => a.priority - b.priority);
    // 汇总步骤永远排在最后
    all.push(SummaryStep({ steps: all }));
    return all;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [revision]);

  const currentStep = steps[stepIndex];
  const isLastStep = stepIndex === steps.length - 1;
  const canGoNext = currentStep?.canGoNext() ?? false;
  const remaining = steps.length - stepIndex - 1;

  const goNext = async () => {
    if (!currentStep) return;
    await currentStep.onComplete?.();
    if (isLastStep) {
      setSubmitting(true);
      await onCompleted();
      return;
    }
    setStepIndex((prev) => prev + 1);
  };

  // ── 欢迎页 ──
  if (showWelcome) {
    return (
      <div className={styles.screen}>
        <div className={styles.welcomeCard}>
          <img src={AppConstants.assetIconPath} alt="" className={styles.welcomeLogo} />
          <h1 className={styles.welcomeTitle}>
            {t(LocalizationKeys.welcomeTitle, AppConstants.appName)}
          </h1>
          <p className={styles.welcomeDesc}>{t(LocalizationKeys.welcomeDesc)}</p>
          <Button
            variant="elevated"
            icon="rocket_launch"
            onClick={() => setShowWelcome(false)}
          >
            {t(LocalizationKeys.startConfig)}
          </Button>
          <span className={styles.welcomeHint}>{t(LocalizationKeys.letsStart)}</span>
        </div>
      </div>
    );
  }

  // ── 步骤页 ──
  return (
    <div className={styles.screen}>
      <div className={styles.wizardCard}>
        <header className={styles.header}>
          <div className={styles.headerTop}>
            <MaterialIcon name="tune" size={18} color="var(--color-primary)" />
            <span className={styles.headerTitle}>{t(LocalizationKeys.setupGuide)}</span>
            <span className={styles.headerCounter}>
              {remaining > 0
                ? t(LocalizationKeys.remainingItems, remaining)
                : t(LocalizationKeys.allReady)}
            </span>
          </div>
          <ProgressBar value={(stepIndex + 1) / steps.length} />
          <div className={styles.stepDots}>
            {steps.map((step, index) => (
              <span
                key={step.id}
                className={[
                  styles.stepDot,
                  index === stepIndex ? styles.stepDotActive : '',
                  index < stepIndex ? styles.stepDotDone : '',
                ]
                  .filter(Boolean)
                  .join(' ')}
                title={step.title}
              />
            ))}
          </div>
        </header>

        <div className={`${styles.body} scroll-area`}>
          <h2 className={styles.stepTitle}>{currentStep?.title}</h2>
          {currentStep?.render()}
        </div>

        <footer className={styles.footer}>
          <Button
            variant="text"
            icon="arrow_back"
            disabled={stepIndex === 0 || submitting}
            onClick={() => setStepIndex((prev) => Math.max(0, prev - 1))}
          >
            {t(LocalizationKeys.previousStep)}
          </Button>
          <Button
            variant="elevated"
            trailingIcon={isLastStep ? 'check' : 'arrow_forward'}
            disabled={!canGoNext}
            loading={submitting}
            onClick={() => void goNext()}
          >
            {isLastStep
              ? t(LocalizationKeys.finishInitialization)
              : t(LocalizationKeys.nextStep)}
          </Button>
        </footer>
      </div>
    </div>
  );
}
