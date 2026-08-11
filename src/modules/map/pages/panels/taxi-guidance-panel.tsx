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
import { runwayEnds } from '../../models/map-models';
import { useMapStore, type TaxiPlanError } from '../../providers/map-store';
import styles from '../map-page.module.css';

/** 机位选择最多列几个；大机场几百个机位全铺出来面板就没法看了 */
const MAX_SPOT_CHIPS = 12;

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

/**
 * 滑行时间取整到分钟。
 *
 * 不报秒：这是个按速度模型算出来的估计，写成「4 分 37 秒」是假精确 ——
 * 实际还要等放行、等穿越跑道，那些不在模型里。
 */
function formatEta(seconds: number): string {
  const minutes = Math.max(1, Math.round(seconds / 60));
  return `${minutes} min`;
}

export function TaxiGuidancePanel() {
  const t = useTranslate();
  const visible = useMapStore((s) => s.showTaxiGuidance);
  const text = useMapStore((s) => s.taxiClearanceText);
  const plan = useMapStore((s) => s.taxiPlan);
  const error = useMapStore((s) => s.taxiPlanError);
  const runways = useMapStore((s) => s.selectedAirport?.runwayGeometries);
  const spots = useMapStore((s) => s.selectedAirport?.parkingSpots);
  const startSpotIndex = useMapStore((s) => s.taxiStartSpotIndex);
  const setStartSpot = useMapStore((s) => s.setTaxiStartSpot);
  const setText = useMapStore((s) => s.setTaxiClearanceText);
  const planByClearance = useMapStore((s) => s.planTaxiByClearance);
  const planToRunway = useMapStore((s) => s.planTaxiToRunway);
  const clearPlan = useMapStore((s) => s.clearTaxiPlan);
  const toggle = useMapStore((s) => s.toggleTaxiGuidance);
  const collapsed = useMapStore((s) => s.taxiPanelCollapsed);
  const setCollapsed = useMapStore((s) => s.setTaxiPanelCollapsed);

  /*
   * 收起后整块面板不渲染，改由顶栏的路线徽标唤回（见 MapTopPanel）。
   * 这个面板压在地图正上方，规划完还杵在那儿正好挡住刚画出来的路线 ——
   * 而那条线才是用户接下来要照着滑的东西。
   */
  if (!visible || collapsed) return null;

  return (
    <div className={styles.taxiPanel}>
      <div className={styles.taxiHead}>
        <MaterialIcon name="alt_route" size={16} color="#ff8c1a" />
        <span className={styles.taxiTitle}>{t(K.taxiTitle)}</span>
        {/* 有路线才给「收起」：没路线时收起等于把面板弄丢 */}
        {plan && (
          <IconButton
            icon="unfold_less"
            label={t(K.taxiCollapse)}
            onClick={() => setCollapsed(true)}
          />
        )}
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

      {/* 起点：默认跟着本机走，也可以指定机位（推出前先看路线） */}
      {spots && spots.length > 0 && (
        <div className={styles.taxiRunwayRow}>
          <span className={styles.taxiRunwayLabel}>{t(K.taxiStartFrom)}</span>
          <button
            type="button"
            className={`${styles.taxiRunwayChip}${
              startSpotIndex === null ? ` ${styles.taxiChipActive}` : ''
            }`}
            onClick={() => setStartSpot(null)}
          >
            {t(K.taxiStartAircraft)}
          </button>
          {/* 机位动辄几百个，全列出来会把面板撑爆；只给前若干个 */}
          {spots.slice(0, MAX_SPOT_CHIPS).map((spot, index) => (
            <button
              key={`${spot.name ?? ''}-${index}`}
              type="button"
              className={`${styles.taxiRunwayChip} text-mono${
                startSpotIndex === index ? ` ${styles.taxiChipActive}` : ''
              }`}
              onClick={() => setStartSpot(index)}
            >
              {spot.name ?? `${t(K.taxiStand)} ${index + 1}`}
            </button>
          ))}
        </div>
      )}

      {/*
        没有指令时的另一条路：直接点跑道。

        按**端点**列而不是整条跑道：一条跑道两个方向是两件事，
        从 34L 走还是从 16R 走，滑到的位置在场地相反两端。
        只给合并编号的话用户没法指定，只能由程序挑近的那头，
        而近的未必是管制给的那头。
      */}
      {runways && runways.length > 0 && (
        <div className={styles.taxiRunwayRow}>
          <span className={styles.taxiRunwayLabel}>{t(K.taxiToRunway)}</span>
          {runways.flatMap((runway) =>
            runwayEnds(runway).map((end) => (
              <button
                key={`${runway.ident}-${end.ident}`}
                type="button"
                className={`${styles.taxiRunwayChip} text-mono`}
                title={runway.ident}
                onClick={() => planToRunway(runway.ident, end.ident)}
              >
                {end.ident}
              </button>
            )),
          )}
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
            <span className={styles.taxiEta}>
              <MaterialIcon name="schedule" size={11} />
              {t(K.taxiEta)} {formatEta(plan.etaSeconds)}
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
