import { useEffect, useState } from 'react';
import { LocalizationKeys } from '../localization/localization-keys';
import { useTranslate } from '../localization/use-translate';
import { AppInitializationService } from '../services/app-initialization-service';
import { supportedLanguages, useLocalizationStore } from '../services/localization-service';
import { PersistenceService } from '../services/persistence-service';
import { isBackendSettingsReachable } from '../services/settings-sync';
import { AppLogger } from '../utils/logger';
import { Button, Slider, Switch } from '../widgets/common/controls';
import { showAdvancedConfirmDialog } from '../widgets/common/dialog';
import { MaterialIcon } from '../widgets/common/icon';
import { SnackBarHelper } from '../widgets/common/snack-bar';
import { InfoChip, SectionCard } from '../widgets/common/surfaces';
import styles from './settings-forms.module.css';

/**
 * 常规设置页
 *
 * 对应 Flutter 版 `core/settings_pages/general_settings_page.dart`。
 *
 * ── Web 降级说明 ──
 * 桌面版这里可以自选数据存储目录并迁移；浏览器没有这个能力，
 * 改为展示「设置存在中间件数据库 / 缓存存在 IndexedDB」的实际位置与用量。
 */
export function GeneralSettingsPage() {
  const t = useTranslate();
  const locale = useLocalizationStore((s) => s.locale);
  const setLocale = useLocalizationStore((s) => s.setLocale);

  const logSettings = AppLogger.loadSettings();
  const [logEnabled, setLogEnabled] = useState(logSettings.enabled);
  const [maxEntries, setMaxEntries] = useState(logSettings.maxEntries);
  const [cacheSize, setCacheSize] = useState<number | null>(null);

  useEffect(() => {
    void PersistenceService.getCacheSize().then(setCacheSize);
  }, []);

  const backendBacked = isBackendSettingsReachable();

  const handleClearCache = async () => {
    const confirmed = await showAdvancedConfirmDialog({
      title: t(LocalizationKeys.clearCacheConfirmTitle),
      content: t(LocalizationKeys.clearCacheConfirmContent),
      icon: 'cleaning_services',
      confirmText: t(LocalizationKeys.confirm),
      cancelText: t(LocalizationKeys.cancel),
    });
    if (confirmed !== true) return;
    await PersistenceService.clearCache();
    setCacheSize(await PersistenceService.getCacheSize());
    SnackBarHelper.showSuccess(t(LocalizationKeys.clearCacheSuccess));
  };

  const handleReset = async () => {
    const confirmed = await showAdvancedConfirmDialog({
      title: t(LocalizationKeys.resetAppConfirmTitle),
      content: t(LocalizationKeys.resetAppConfirmContent),
      icon: 'restart_alt',
      confirmColor: 'var(--color-danger)',
      confirmText: t(LocalizationKeys.confirm),
      cancelText: t(LocalizationKeys.cancel),
    });
    if (confirmed !== true) return;
    await AppInitializationService.resetApp();
    SnackBarHelper.showSuccess(t(LocalizationKeys.resetSuccess));
    // 重置后重新加载，走一遍首启向导
    setTimeout(() => window.location.reload(), 900);
  };

  return (
    <div className={styles.page}>
      {/* ── 语言 ── */}
      <SectionCard title={t(LocalizationKeys.language)} icon="language">
        <div className={styles.optionList}>
          {supportedLanguages.map((option) => {
            const selected = option.code === locale;
            return (
              <button
                key={option.code}
                type="button"
                onClick={() => void setLocale(option.code)}
                className={`${styles.optionTile}${selected ? ` ${styles.optionTileSelected}` : ''}`}
              >
                <span className={styles.optionFlag}>{option.flag}</span>
                <span className={styles.optionLabel}>{option.name}</span>
                {selected && (
                  <MaterialIcon
                    name="check_circle"
                    filled
                    size={18}
                    color="var(--color-primary)"
                  />
                )}
              </button>
            );
          })}
        </div>
      </SectionCard>

      {/* ── 日志 ── */}
      <SectionCard
        title={t(LocalizationKeys.logSettings)}
        icon="description"
        subtitle={t(LocalizationKeys.logSettingsDesc)}
      >
        <div className={styles.settingRow}>
          <div className={styles.settingText}>
            <span className={styles.settingLabel}>{t(LocalizationKeys.enableLogging)}</span>
            <span className={styles.settingHint}>{t(LocalizationKeys.enableLoggingDesc)}</span>
          </div>
          <Switch
            checked={logEnabled}
            onChange={(value) => {
              setLogEnabled(value);
              void AppLogger.updateSettings({ enabled: value });
            }}
            label={t(LocalizationKeys.enableLogging)}
          />
        </div>

        <div className={styles.settingBlock}>
          <span className={styles.settingLabel}>{t(LocalizationKeys.logMaxSize)}</span>
          <Slider
            value={maxEntries}
            min={500}
            max={20000}
            step={500}
            disabled={!logEnabled}
            label={t(LocalizationKeys.logMaxSize)}
            formatValue={(value) => `${value}`}
            onChange={(value) => {
              setMaxEntries(value);
              void AppLogger.updateSettings({ maxEntries: value });
            }}
          />
        </div>
      </SectionCard>

      {/* ── 存储位置 ── */}
      <SectionCard
        title={t(LocalizationKeys.storageLocation)}
        icon="storage"
        subtitle={t(LocalizationKeys.webStorageLocationDesc)}
      >
        <div className={styles.storageRows}>
          <div className={styles.storageRow}>
            <MaterialIcon
              name={backendBacked ? 'cloud_done' : 'cloud_off'}
              size={17}
              color={backendBacked ? 'var(--color-success)' : 'var(--color-warning)'}
            />
            <div className={styles.settingText}>
              <span className={styles.settingLabel}>
                {t(LocalizationKeys.webSettingsLabel)}
              </span>
              <span className={styles.settingHint}>
                {backendBacked
                  ? t(LocalizationKeys.webSettingsBackendBacked)
                  : t(LocalizationKeys.webSettingsLocalOnly)}
              </span>
            </div>
          </div>

          <div className={styles.storageRow}>
            <MaterialIcon name="database" size={17} color="var(--color-primary)" />
            <div className={styles.settingText}>
              <span className={styles.settingLabel}>{t(LocalizationKeys.webStorageLocation)}</span>
              <span className={styles.settingHint}>
                {t(LocalizationKeys.cacheSize, formatBytes(cacheSize))}
              </span>
            </div>
          </div>
        </div>

        <div className={styles.chipRow}>
          <InfoChip icon="folder" label={t(LocalizationKeys.webRecordStorageLabel)} />
        </div>

        <Button variant="outlined" icon="cleaning_services" onClick={() => void handleClearCache()}>
          {t(LocalizationKeys.clearCache)}
        </Button>
      </SectionCard>

      {/* ── 危险操作 ── */}
      <SectionCard
        title={t(LocalizationKeys.dangerZone)}
        icon="warning"
        subtitle={t(LocalizationKeys.resetAppDesc)}
      >
        <Button variant="danger" icon="restart_alt" onClick={() => void handleReset()}>
          {t(LocalizationKeys.resetApp)}
        </Button>
      </SectionCard>
    </div>
  );
}

function formatBytes(bytes: number | null): string {
  if (bytes === null) return '--';
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}
