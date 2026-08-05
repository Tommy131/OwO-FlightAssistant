import { useState } from 'react';
import { LocalizationKeys } from '../../localization/localization-keys';
import { translate } from '../../services/localization-service';
import { AppLogger } from '../../utils/logger';
import { Slider, Switch } from '../../widgets/common/controls';
import { MaterialIcon } from '../../widgets/common/icon';
import type { WizardStep } from '../wizard-step-registry';
import styles from './steps.module.css';

/**
 * 日志设置步骤
 *
 * 对应 Flutter 版 `setup_wizard/steps/log_settings_step.dart`。
 * 桌面版设置的是「日志文件分割大小(MB)」；Web 版无文件系统，
 * 等价语义改为「内存日志缓冲区条数」，供 log_viewer 模块读取。
 */
export function LogSettingsStep({ onChanged }: { onChanged: () => void }): WizardStep {
  return {
    id: 'log_settings',
    title: translate(LocalizationKeys.logSettingsStep),
    priority: 30,
    canGoNext: () => true,
    getSummary: () => {
      const settings = AppLogger.loadSettings();
      return {
        [translate(LocalizationKeys.logging)]: settings.enabled
          ? translate(LocalizationKeys.enabled)
          : translate(LocalizationKeys.disabled),
        [translate(LocalizationKeys.logMaxSize)]: `${settings.maxEntries}`,
      };
    },
    render: () => <LogSettingsStepView onChanged={onChanged} />,
  };
}

function LogSettingsStepView({ onChanged }: { onChanged: () => void }) {
  const initial = AppLogger.loadSettings();
  const [enabled, setEnabled] = useState(initial.enabled);
  const [maxEntries, setMaxEntries] = useState(initial.maxEntries);

  const handleToggle = async (next: boolean) => {
    setEnabled(next);
    await AppLogger.updateSettings({ enabled: next });
    onChanged();
  };

  const handleMaxEntries = async (next: number) => {
    setMaxEntries(next);
    await AppLogger.updateSettings({ maxEntries: next });
    onChanged();
  };

  return (
    <div className={styles.stepBody}>
      <p className={styles.stepDesc}>{translate(LocalizationKeys.logSettingsHint)}</p>

      <div className={styles.settingRow}>
        <MaterialIcon name="description" size={18} color="var(--color-primary)" />
        <div className={styles.settingText}>
          <span className={styles.settingTitle}>{translate(LocalizationKeys.enableLogging)}</span>
          <span className={styles.settingDesc}>
            {translate(LocalizationKeys.enableLoggingDesc)}
          </span>
        </div>
        <Switch
          checked={enabled}
          onChange={(next) => void handleToggle(next)}
          label={translate(LocalizationKeys.enableLogging)}
        />
      </div>

      <div className={styles.settingBlock}>
        <div className={styles.settingText}>
          <span className={styles.settingTitle}>{translate(LocalizationKeys.logMaxSize)}</span>
        </div>
        <Slider
          value={maxEntries}
          min={500}
          max={20000}
          step={500}
          disabled={!enabled}
          label={translate(LocalizationKeys.logMaxSize)}
          formatValue={(value) => `${value}`}
          onChange={(next) => void handleMaxEntries(next)}
        />
      </div>
    </div>
  );
}
