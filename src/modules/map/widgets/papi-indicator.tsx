import { useTranslate } from '../../../core/localization/use-translate';
import { MapLocalizationKeys as K } from '../localization/map-localization';
import { useMapStore } from '../providers/map-store';
import { computePapiGuidance, type PapiVerdict } from '../services/papi-guidance';
import styles from './papi-indicator.module.css';

/**
 * PAPI 目视坡度指示器
 *
 * 只有在**已连接模拟器且确实处于某条跑道的进近条件**下才出现：
 * 离入口 10 海里内、入口以上 3000 英尺内、且大致对正跑道方向。
 * 不满足就整个不渲染 —— 巡航途中挂一个常亮的进近指示器毫无意义。
 */

const VERDICT_STYLE: Record<PapiVerdict, { key: string; color: string }> = {
  high: { key: K.papiHigh, color: 'var(--color-warning)' },
  slightlyHigh: { key: K.papiSlightlyHigh, color: 'var(--color-warning)' },
  onSlope: { key: K.papiOnSlope, color: 'var(--color-success)' },
  slightlyLow: { key: K.papiSlightlyLow, color: 'var(--color-warning)' },
  low: { key: K.papiLow, color: 'var(--color-danger)' },
};

export function PapiIndicator() {
  const t = useTranslate();
  const aircraft = useMapStore((s) => s.aircraft);
  const detail = useMapStore((s) => s.selectedAirport);

  const guidance = computePapiGuidance(aircraft, detail);
  if (!guidance) return null;

  const style = VERDICT_STYLE[guidance.verdict];

  return (
    <div
      className={`${styles.papi}${guidance.verdict === 'low' ? ` ${styles.papiLow}` : ''}`}
      role="status"
    >
      <div className={styles.head}>
        <span className={`${styles.runway} text-mono`}>{guidance.runway}</span>
        <span>PAPI</span>
      </div>

      <div className={styles.lights} aria-label={t(style.key)}>
        {guidance.lights.map((light, index) => (
          <span
            // 灯位固定四盏、顺序固定，用下标作 key 是安全的
            key={index}
            className={`${styles.light} ${
              light === 'white' ? styles.lightWhite : styles.lightRed
            }`}
          />
        ))}
      </div>

      <span className={styles.verdict} style={{ color: style.color }}>
        {t(style.key)}
      </span>

      <div className={`${styles.detail} text-mono`}>
        <span>
          {guidance.currentAngle.toFixed(2)}° / {guidance.targetAngle.toFixed(2)}°
        </span>
        <span>{guidance.distanceNm.toFixed(1)} NM</span>
        <span>{Math.round(guidance.heightFt)} ft</span>
      </div>
    </div>
  );
}
