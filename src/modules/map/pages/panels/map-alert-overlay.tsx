/**
 * 告警浮层：把 store 里的 activeAlerts 按级别配色显示在地图上方
 */

import { useTranslate } from '../../../../core/localization/use-translate';
import { MaterialIcon } from '../../../../core/widgets/common/icon';
import {
  MAP_ALERT_LEVEL_COLOR,
} from '../../models/map-models';
import { useMapStore } from '../../providers/map-store';
import styles from '../map-page.module.css';

// ──────────────────────────────────────────────────────────────────────────
// 告警浮层
// ──────────────────────────────────────────────────────────────────────────

export function MapAlertOverlay() {
  const t = useTranslate();
  const alerts = useMapStore((s) => s.activeAlerts);
  if (alerts.length === 0) return null;

  return (
    <div className={styles.alertOverlay}>
      {alerts.map((alert) => (
        <div
          key={alert.id}
          className={styles.alertBanner}
          style={{
            color: MAP_ALERT_LEVEL_COLOR[alert.level],
            borderColor: MAP_ALERT_LEVEL_COLOR[alert.level],
          }}
        >
          <MaterialIcon name="warning" filled size={18} />
          {/* message 里是 i18n key，不是文案 —— 见 flight-alerts.ts */}
          {t(alert.message)}
        </div>
      ))}
    </div>
  );
}
