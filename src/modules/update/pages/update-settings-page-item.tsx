import { useEffect } from 'react';

import { useTranslate } from '../../../core/localization/use-translate';
import type { SettingsPageItem } from '../../../core/module-registry/settings-page/settings-page-registry';
import { translate } from '../../../core/services/localization-service';
import { Button } from '../../../core/widgets/common/controls';
import { MaterialIcon } from '../../../core/widgets/common/icon';
import { InfoChip, SectionCard } from '../../../core/widgets/common/surfaces';
import { UpdateLocalizationKeys as K } from '../localization/update-localization';
import { useUpdateStore } from '../providers/update-store';
import { blockedReasonText, openReleasePage } from '../services/update-dialog';
import { offerUpdate, runInstall } from '../services/update-flow';
import { formatBytes, resolveUpdateStatus, type UpdateStatusKind } from '../services/update-model';
import styles from './update-settings.module.css';

/** 软件更新设置页 */
export function createUpdateSettingsPageItem(): SettingsPageItem {
  return {
    id: 'software_update_settings',
    icon: 'system_update',
    priority: 15,
    getTitle: () => translate(K.settingsTitle),
    getDescription: () => translate(K.settingsDescription),
    render: () => <UpdateSettingsPage />,
  };
}

/** 各状态对应的文案键与配色 */
const STATUS_META: Record<UpdateStatusKind, { key: string; icon: string; tone: string }> = {
  unknown: { key: K.statusUnknown, icon: 'help', tone: 'neutral' },
  checking: { key: K.statusChecking, icon: 'sync', tone: 'neutral' },
  available: { key: K.statusAvailable, icon: 'new_releases', tone: 'accent' },
  ignored: { key: K.statusIgnored, icon: 'notifications_off', tone: 'muted' },
  upToDate: { key: K.statusUpToDate, icon: 'check_circle', tone: 'ok' },
  failed: { key: K.statusFailed, icon: 'error', tone: 'warn' },
};

function UpdateSettingsPage() {
  const t = useTranslate();
  const state = useUpdateStore((s) => s.state);
  const checking = useUpdateStore((s) => s.checking);
  const check = useUpdateStore((s) => s.check);
  const unignore = useUpdateStore((s) => s.unignore);

  // 打开设置页时若还没查过就查一次（走缓存，不强制回源）
  useEffect(() => {
    if (!state && !checking) void check(false);
    // 只在挂载时跑一次；后续由用户手动触发
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const status = resolveUpdateStatus(state, checking);
  const meta = STATUS_META[status];
  const result = state?.result;

  return (
    <div className={styles.page}>
      <SectionCard title={t(K.settingsTitle)}>
        <div className={styles.statusRow}>
          <span className={`${styles.statusBadge} ${styles[meta.tone] ?? ''}`}>
            <MaterialIcon name={meta.icon} size={16} />
            {t(meta.key)}
          </span>
          {result?.isPrerelease && status !== 'upToDate' ? (
            <InfoChip label={t(K.prereleaseBadge)} />
          ) : null}
        </div>

        <div className={styles.versionRow}>
          <span className={styles.versionItem}>
            <span className={styles.versionLabel}>{t(K.currentVersion)}</span>
            <span className={`${styles.versionValue} text-mono`}>
              {result?.current ?? '--'}
            </span>
          </span>
          <span className={styles.versionItem}>
            <span className={styles.versionLabel}>{t(K.latestVersion)}</span>
            <span className={`${styles.versionValue} text-mono`}>
              {result?.latest || '--'}
            </span>
          </span>
          {result?.assetSize ? (
            <span className={styles.versionItem}>
              <span className={styles.versionLabel}>{t(K.downloadSize)}</span>
              <span className={styles.versionValue}>{formatBytes(result.assetSize)}</span>
            </span>
          ) : null}
        </div>

        {/* 查失败时把上游给的原因摊开，别让用户对着「检查失败」四个字猜 */}
        {status === 'failed' && state?.errorDetail ? (
          <p className={styles.detail}>{state.errorDetail}</p>
        ) : null}

        {/* 有更新但装不了（平台不支持 / 没有资产 / 目录不可写）时如实说明 */}
        {result?.available && !result.canSelfInstall ? (
          <p className={styles.detail}>
            {blockedReasonText(result.selfInstallBlockedReason)} {t(K.blockedHint)}
          </p>
        ) : null}

        <div className={styles.actions}>
          <Button
            icon="refresh"
            disabled={checking}
            loading={checking}
            // 手动检查强制回源：点了按钮却拿到半小时前的缓存会以为按钮坏了
            onClick={() => void check(true)}
          >
            {checking ? t(K.checkingButton) : t(K.checkButton)}
          </Button>

          {result?.available && !state?.ignored ? (
            <Button
              icon={result.canSelfInstall ? 'system_update' : 'open_in_new'}
              variant="tonal"
              onClick={() => {
                if (!result.canSelfInstall) {
                  openReleasePage(result.htmlUrl);
                  return;
                }
                void runInstall(result);
              }}
            >
              {result.canSelfInstall ? t(K.installButton) : t(K.openReleaseButton)}
            </Button>
          ) : null}

          {result?.available && !state?.ignored ? (
            <Button
              icon="notifications_off"
              variant="outlined"
              onClick={() => void useUpdateStore.getState().ignore(result.tag)}
            >
              {t(K.ignoreButton)}
            </Button>
          ) : null}

          {/* 已忽略时给一条回头路，否则忽略了就再也装不上这一版 */}
          {status === 'ignored' ? (
            <>
              <Button icon="notifications_active" variant="outlined" onClick={() => void unignore()}>
                {t(K.unignoreButton)}
              </Button>
              <Button
                icon="system_update"
                variant="tonal"
                onClick={() => {
                  if (result) void offerUpdate(result);
                }}
              >
                {t(K.installButton)}
              </Button>
            </>
          ) : null}

          {result?.htmlUrl ? (
            <Button
              icon="open_in_new"
              variant="text"
              onClick={() => openReleasePage(result.htmlUrl)}
            >
              {t(K.openReleaseButton)}
            </Button>
          ) : null}
        </div>
      </SectionCard>
    </div>
  );
}
