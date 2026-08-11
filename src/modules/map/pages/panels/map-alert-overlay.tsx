/**
 * 告警浮层：把 store 里的 activeAlerts 按级别配色显示在地图上方
 */

import { useTranslate } from '../../../../core/localization/use-translate';
import { MaterialIcon } from '../../../../core/widgets/common/icon';
import {
  MAP_ALERT_LEVEL_COLOR,
  highestAlertLevel,
  type MapFlightAlertLevel,
} from '../../models/map-models';
import { useMapStore } from '../../providers/map-store';
import styles from '../map-page.module.css';

// ──────────────────────────────────────────────────────────────────────────
// 告警浮层
// ──────────────────────────────────────────────────────────────────────────

/**
 * 各级别的边框闪烁周期。
 *
 * 越紧急闪得越快，让人不用读字就知道事情有多急。
 *
 * ⚠️ 最快的一档也保持在 1.1s 一个来回（≈0.9Hz）。每秒 3 次以上的闪烁
 * 可能诱发光敏性癫痫（WCAG 2.3.1 就是卡这条），驾驶舱告警再急也不值得
 * 拿这个换 —— 何况屏幕这么大一圈边框，闪得太快只会让人眼花看不清仪表。
 */
const BORDER_FLASH_PERIOD_S: Record<MapFlightAlertLevel, number> = {
  caution: 1.9,
  warning: 1.5,
  danger: 1.1,
};

export function MapAlertOverlay() {
  const t = useTranslate();
  const alerts = useMapStore((s) => s.activeAlerts);
  if (alerts.length === 0) return null;

  // 同时多条时按最高级闪：边框只有一圈，不能把致命告警显示成黄色
  const level = highestAlertLevel(alerts);
  const borderColor = level ? MAP_ALERT_LEVEL_COLOR[level] : undefined;

  return (
    <>
      {/*
        姿态告警的边框闪烁 —— 复刻桌面版最显眼的那个提示。

        单独一层铺满地图、只画一圈内嵌边框，不吃指针事件：
        告警时飞行员多半正在操作，浮层挡住地图或拦掉拖动都是帮倒忙。
        放在横幅之下（z-index 更低），横幅始终压在边框上方可读。
      */}
      {level && (
        <div
          className={`${styles.alertBorderFlash} ${styles[`alertBorderFlash_${level}`]}`}
          // 只设 color：边框与内辉光都走 currentColor，一处定色两处生效。
          // 光设 borderColor 的话 box-shadow 的 currentColor 取不到它，
          // 辉光会落到继承来的文字色上
          style={{
            color: borderColor,
            animationDuration: `${BORDER_FLASH_PERIOD_S[level]}s`,
          }}
          aria-hidden="true"
        />
      )}

      <div className={styles.alertOverlay} role="alert" aria-live="assertive">
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
    </>
  );
}
