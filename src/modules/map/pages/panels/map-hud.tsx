/**
 * 左下 HUD：高度/速度/航向与计时器
 */

import { useTranslate } from '../../../../core/localization/use-translate';
import { IconButton } from '../../../../core/widgets/common/controls';
import { showAdvancedConfirmDialog } from '../../../../core/widgets/common/dialog';
import { MaterialIcon } from '../../../../core/widgets/common/icon';
import { MapLocalizationKeys as K } from '../../localization/map-localization';
import { useMapStore } from '../../providers/map-store';
import styles from '../map-page.module.css';

// ──────────────────────────────────────────────────────────────────────────
// HUD：计时器 + 航迹点数
// ──────────────────────────────────────────────────────────────────────────

export function MapHud() {
  const t = useTranslate();
  const hudElapsedMs = useMapStore((s) => s.hudElapsedMs);
  const isRunning = useMapStore((s) => s.isHudTimerRunning);
  const routeCount = useMapStore((s) => s.route.length);
  const toggleHudTimer = useMapStore((s) => s.toggleHudTimer);
  const resetHudTimer = useMapStore((s) => s.resetHudTimer);
  const clearRoute = useMapStore((s) => s.clearRoute);

  const handleClearRoute = async () => {
    const confirmed = await showAdvancedConfirmDialog({
      title: t(K.clearRouteConfirmTitle),
      content: t(K.clearRouteConfirmContent),
      icon: 'delete_sweep',
      confirmColor: 'var(--color-danger)',
      confirmText: t(K.clearButton),
      cancelText: t(K.taxiwayAutoLoadSkip),
    });
    if (confirmed === true) clearRoute();
  };

  return (
    <div className={styles.hud}>
      <div className={styles.hudTimer}>
        <span className={`${styles.hudTime} text-mono`}>{formatElapsed(hudElapsedMs)}</span>
        <div className={styles.hudTimerActions}>
          <IconButton
            icon={isRunning ? 'pause' : 'play_arrow'}
            label={t(K.timerSectionTitle)}
            onClick={toggleHudTimer}
            active={isRunning}
          />
          <IconButton icon="restart_alt" label={t(K.clearButton)} onClick={resetHudTimer} />
        </div>
      </div>

      <div className={styles.hudRow}>
        <MaterialIcon name="timeline" size={14} color="var(--color-text-secondary)" />
        <span className={styles.hudLabel}>
          {routeCount} {t(K.routePoints)}
        </span>
        {routeCount > 0 && (
          <IconButton
            icon="delete_sweep"
            label={t(K.clearRoute)}
            size={16}
            onClick={() => void handleClearRoute()}
          />
        )}
      </div>
    </div>
  );
}

function formatElapsed(ms: number): string {
  const totalSeconds = Math.floor(ms / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`;
}
