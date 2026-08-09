/**
 * 地面滑行引导面板
 *
 * 两种用法：粘贴管制指令按编号规划，或直接点一条跑道让它自己算。
 * 规划失败时按原因给出具体说法 —— 「没有地面数据」和「指令走不通」
 * 用户要做的事完全不同，笼统一句「失败」等于没说。
 */

import { useTranslate } from '../../../../core/localization/use-translate';
import { Button, IconButton, TextField } from '../../../../core/widgets/common/controls';
import { MaterialIcon } from '../../../../core/widgets/common/icon';
import { MapLocalizationKeys as K } from '../../localization/map-localization';
import { useMapStore, type TaxiPlanError } from '../../providers/map-store';
import styles from '../map-page.module.css';

const ERROR_KEY: Record<TaxiPlanError, string> = {
  no_aeroway: K.taxiErrorNoAeroway,
  no_refs: K.taxiErrorNoRefs,
  no_start: K.taxiErrorNoStart,
  unreachable: K.taxiErrorUnreachable,
};

/** 滑行距离用米还是公里：一公里以内报米，更长报公里 */
function formatDistance(meters: number): string {
  return meters < 1000 ? `${Math.round(meters)} m` : `${(meters / 1000).toFixed(2)} km`;
}

export function TaxiGuidancePanel() {
  const t = useTranslate();
  const visible = useMapStore((s) => s.showTaxiGuidance);
  const text = useMapStore((s) => s.taxiClearanceText);
  const plan = useMapStore((s) => s.taxiPlan);
  const error = useMapStore((s) => s.taxiPlanError);
  const runways = useMapStore((s) => s.selectedAirport?.runwayGeometries);
  const setText = useMapStore((s) => s.setTaxiClearanceText);
  const planByClearance = useMapStore((s) => s.planTaxiByClearance);
  const planToRunway = useMapStore((s) => s.planTaxiToRunway);
  const clearPlan = useMapStore((s) => s.clearTaxiPlan);
  const toggle = useMapStore((s) => s.toggleTaxiGuidance);

  if (!visible) return null;

  return (
    <div className={styles.taxiPanel}>
      <div className={styles.taxiHead}>
        <MaterialIcon name="alt_route" size={16} color="#ff8c1a" />
        <span className={styles.taxiTitle}>{t(K.taxiTitle)}</span>
        <IconButton icon="close" label={t(K.clearSearch)} onClick={toggle} />
      </div>

      <div className={styles.taxiInputRow}>
        <TextField
          value={text}
          onChange={setText}
          icon="record_voice_over"
          placeholder={t(K.taxiClearanceHint)}
          onSubmit={planByClearance}
          className={styles.taxiInput}
        />
        <Button icon="route" onClick={planByClearance}>
          {t(K.taxiPlanAction)}
        </Button>
      </div>

      {/* 没有指令时的另一条路：直接点跑道 */}
      {runways && runways.length > 0 && (
        <div className={styles.taxiRunwayRow}>
          <span className={styles.taxiRunwayLabel}>{t(K.taxiToRunway)}</span>
          {runways.map((runway) => (
            <button
              key={runway.ident}
              type="button"
              className={`${styles.taxiRunwayChip} text-mono`}
              onClick={() => planToRunway(runway.ident)}
            >
              {runway.ident}
            </button>
          ))}
        </div>
      )}

      {error && (
        <div className={styles.taxiError}>
          <MaterialIcon name="error_outline" size={13} />
          {t(ERROR_KEY[error])}
        </div>
      )}

      {plan && (
        <>
          <div className={styles.taxiSummary}>
            <span className={styles.taxiTotalValue}>
              {t(K.taxiTotal)} {formatDistance(plan.distanceM)}
            </span>
            {plan.holdShort && (
              <span className={styles.taxiHoldShort}>
                <MaterialIcon name="pan_tool" size={11} />
                {t(K.taxiHoldShort)} {plan.holdShort}
              </span>
            )}
            <button type="button" className={styles.taxiClearButton} onClick={clearPlan}>
              {t(K.taxiClear)}
            </button>
          </div>

          <div className={`${styles.taxiSegments} scroll-area`}>
            {plan.segments.map((segment, index) => (
              // 分段没有稳定 id，但列表本身是只读的、整份替换，用下标做键是安全的
              <span key={index} className={styles.taxiSegment}>
                <span className={`${styles.taxiSegmentRef} text-mono`}>
                  {segment.ref ?? t(K.taxiUnnamed)}
                </span>
                <span className={styles.taxiSegmentDistance}>
                  {formatDistance(segment.distanceM)}
                </span>
              </span>
            ))}
          </div>
        </>
      )}
    </div>
  );
}
