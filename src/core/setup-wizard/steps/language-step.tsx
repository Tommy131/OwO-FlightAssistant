import { LocalizationKeys } from '../../localization/localization-keys';
import {
  supportedLanguages,
  translate,
  useLocalizationStore,
  type LanguageCode,
} from '../../services/localization-service';
import { MaterialIcon } from '../../widgets/common/icon';
import type { WizardStep } from '../wizard-step-registry';
import styles from './steps.module.css';

/**
 * 语言选择步骤
 * 对应 Flutter 版 `setup_wizard/steps/language_step.dart`
 */
export function LanguageStep({ onChanged }: { onChanged: () => void }): WizardStep {
  return {
    id: 'language',
    title: translate(LocalizationKeys.languageStep),
    priority: 10,
    canGoNext: () => true,
    getSummary: () => {
      const locale = useLocalizationStore.getState().locale;
      const option = supportedLanguages.find((item) => item.code === locale);
      return { [translate(LocalizationKeys.language)]: option?.name ?? locale };
    },
    render: () => <LanguageStepView onChanged={onChanged} />,
  };
}

function LanguageStepView({ onChanged }: { onChanged: () => void }) {
  const locale = useLocalizationStore((state) => state.locale);
  const setLocale = useLocalizationStore((state) => state.setLocale);

  const handleSelect = async (code: LanguageCode) => {
    await setLocale(code);
    onChanged();
  };

  return (
    <div className={styles.stepBody}>
      <p className={styles.stepDesc}>{translate(LocalizationKeys.setupLanguageDesc)}</p>
      <div className={styles.optionList}>
        {supportedLanguages.map((option) => {
          const selected = option.code === locale;
          return (
            <button
              key={option.code}
              type="button"
              onClick={() => void handleSelect(option.code)}
              className={`${styles.optionTile}${selected ? ` ${styles.optionTileSelected}` : ''}`}
            >
              <span className={styles.optionFlag}>{option.flag}</span>
              <span className={styles.optionLabel}>{option.name}</span>
              {selected && (
                <MaterialIcon name="check_circle" filled size={18} color="var(--color-primary)" />
              )}
            </button>
          );
        })}
      </div>
    </div>
  );
}
