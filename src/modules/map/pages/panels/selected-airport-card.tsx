/**
 * 选中机场底卡：ATIS/METAR、经纬度、跑道与进近设施
 */

import { useEffect, useRef, useState } from 'react';
import { useTranslate } from '../../../../core/localization/use-translate';
import { IconButton } from '../../../../core/widgets/common/controls';
import { MaterialIcon } from '../../../../core/widgets/common/icon';
import { InfoChip } from '../../../../core/widgets/common/surfaces';
import { MapLocalizationKeys as K } from '../../localization/map-localization';
import {
  type MapRunwayNavaid,
} from '../../models/map-models';
import { useMapStore } from '../../providers/map-store';
import { MarqueeText } from '../../widgets/marquee-text';
import styles from '../map-page.module.css';

/** 飞行等级配色，与桌面版 ApproachRuleBadge 一致 */
const APPROACH_RULE_STYLE: Record<string, { color: string; icon: string }> = {
  VFR: { color: '#35d07f', icon: 'wb_sunny' },
  MVFR: { color: '#4db7ff', icon: 'cloud_queue' },
  IFR: { color: '#ffa63d', icon: 'grain' },
  LIFR: { color: '#ff5c6a', icon: 'thunderstorm' },
};

/**
 * ILS 类别配色
 *
 * 类别越高、可用的决断高度越低，对天气的容忍度越强，
 * 所以按「能力递增」上色：CAT I 常规蓝，CAT II 提升，CAT III 最高。
 * 只有航向台（LOC，没有下滑道）单独一档灰，避免被误当成精密进近。
 */
const ILS_CATEGORY_COLOR: Record<string, string> = {
  'CAT I': '#4db7ff',
  'CAT II': '#35d07f',
  'CAT III': '#a78bfa',
  ILS: '#4db7ff',
  LOC: '#9aa4b2',
};

/** 单个跑道端的进近设施徽标 */
function RunwayNavaidChips({
  end,
  navaid,
  showGlideslope,
}: {
  end: string;
  navaid?: MapRunwayNavaid;
  showGlideslope: boolean;
}) {
  const t = useTranslate();

  // 没有 ILS 的跑道端也要标出来，否则会被误以为是数据没加载出来
  if (!navaid?.category) {
    return (
      <span className={styles.runwayEnd}>
        <span className={`${styles.runwayEndIdent} text-mono`}>{end}</span>
        <span className={styles.navaidNone}>{t(K.runwayNoIls)}</span>
      </span>
    );
  }

  const color = ILS_CATEGORY_COLOR[navaid.category] ?? 'var(--color-text-secondary)';

  return (
    <span className={styles.runwayEnd}>
      <span className={`${styles.runwayEndIdent} text-mono`}>{end}</span>
      <span
        className={styles.navaidCategory}
        style={{
          color,
          borderColor: `color-mix(in srgb, ${color} 60%, transparent)`,
          background: `color-mix(in srgb, ${color} 14%, transparent)`,
        }}
      >
        {navaid.category}
      </span>
      {navaid.locFrequency && (
        <span className={`${styles.navaidChip} text-mono`} title={t(K.runwayLocHint)}>
          {navaid.locIdent ? `${navaid.locIdent} ` : ''}
          {navaid.locFrequency}
          {navaid.locCourse !== undefined && ` · ${Math.round(navaid.locCourse)}°`}
        </span>
      )}
      {showGlideslope && navaid.glideslopeAngle !== undefined && (
        <span className={styles.navaidGlideslope} title={t(K.runwayGlideslopeHint)}>
          <MaterialIcon name="airline_stops" size={10} />
          GS {navaid.glideslopeAngle.toFixed(2)}°
        </span>
      )}
      {navaid.hasDme && (
        <span className={styles.navaidChip} title={t(K.runwayDmeHint)}>
          DME
        </span>
      )}
    </span>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 选中机场底卡
// ──────────────────────────────────────────────────────────────────────────




export function SelectedAirportCard() {
  const t = useTranslate();
  const detail = useMapStore((s) => s.selectedAirport);
  const homeAirport = useMapStore((s) => s.homeAirport);
  const setSelectedAirport = useMapStore((s) => s.setSelectedAirport);
  const setHomeAirport = useMapStore((s) => s.setHomeAirport);
  const clearHomeAirport = useMapStore((s) => s.clearHomeAirport);
  // 原文 / 解读切换；换机场时回到原文（与桌面版 didUpdateWidget 行为一致）
  const [showDecoded, setShowDecoded] = useState(false);
  // 下滑道开关放在 store 里：卡片和地图上的跑道标注共用同一个状态
  const showGlideslope = useMapStore((s) => s.showGlideslope);
  const toggleGlideslope = useMapStore((s) => s.toggleGlideslope);
  const shownCode = useRef<string | undefined>(undefined);

  const code = detail?.marker.code;
  useEffect(() => {
    if (shownCode.current === code) return;
    shownCode.current = code;
    setShowDecoded(false);
  }, [code]);

  if (!detail) return null;
  const isHome = homeAirport?.code === detail.marker.code;

  const rawMetar = (detail.rawMetar ?? detail.atis ?? '').trim();
  const decodedMetar = (detail.decodedMetar ?? '').trim();
  // 想看的那一种没有就退回另一种，两种都没有才显示「暂无数据」
  const weatherText = showDecoded
    ? decodedMetar || rawMetar || t(K.weatherNoData)
    : rawMetar || decodedMetar || t(K.weatherNoData);

  const rule = (detail.approachRule ?? 'UNK').toUpperCase();
  const ruleStyle = APPROACH_RULE_STYLE[rule];
  const { latitude, longitude } = detail.marker.position;

  return (
    <div className={styles.airportCard}>
      <div className={styles.airportHead}>
        <div className={styles.airportTitleWrap}>
          <span className={`${styles.airportCode} text-mono`}>{detail.marker.code}</span>
          {detail.marker.name && (
            // 机场全名经常放不下（"Muenchen Franz-Josef-Strauss"），滚动播完
            <MarqueeText text={detail.marker.name} className={styles.airportName} />
          )}
          {detail.source && (
            <span className={styles.airportSource}>{detail.source.toUpperCase()}</span>
          )}
        </div>

        <span className={styles.runwayCountBadge}>
          {detail.runwayGeometries.length} RWY
        </span>
        <span
          className={styles.approachBadge}
          style={{
            color: ruleStyle?.color ?? 'var(--color-text-secondary)',
            background: ruleStyle
              ? `color-mix(in srgb, ${ruleStyle.color} 14%, transparent)`
              : 'var(--color-on-surface-a04)',
            border: `1px solid ${
              ruleStyle
                ? `color-mix(in srgb, ${ruleStyle.color} 60%, transparent)`
                : 'var(--color-border)'
            }`,
          }}
          title={t(K.approachRuleHint)}
        >
          <MaterialIcon name={ruleStyle?.icon ?? 'help_outline'} size={12} />
          {rule}
        </span>

        <IconButton
          icon={isHome ? 'star' : 'star_border'}
          label={t(K.homeAirportSectionTitle)}
          filled={isHome}
          active={isHome}
          onClick={() => {
            if (isHome) void clearHomeAirport();
            else void setHomeAirport(detail.marker);
          }}
        />
        <IconButton
          icon="close"
          label={t(K.clearSearch)}
          onClick={() => setSelectedAirport(null)}
        />
      </div>

      <div className={`${styles.airportBody} scroll-area`}>
        <div className={styles.airportMetaRow}>
          <span className={styles.airportMetaItem}>
            <MaterialIcon name="straighten" size={12} />
            {detail.runwayGeometries.length} RWY
          </span>
          <span className={styles.airportMetaItem}>
            <MaterialIcon name="local_parking" size={12} />
            {detail.parkingSpots.length} SPOTS
          </span>
          <span className={styles.airportMetaItem}>
            <MaterialIcon name="location_on" size={12} />
            {latitude.toFixed(3)}, {longitude.toFixed(3)}
          </span>
        </div>

        {/* METAR：原文 / 中文解读切换 */}
        <div className={styles.metarBox}>
          <span className={`${styles.metarText} ${showDecoded ? '' : 'text-mono'}`}>
            {weatherText}
          </span>
          <span className={styles.metarToggleWrap}>
            <span className={styles.metarToggleLabel}>
              {t(showDecoded ? K.metarDecodedShort : K.metarRawShort)}
            </span>
            <button
              type="button"
              role="switch"
              aria-checked={showDecoded}
              aria-label={t(showDecoded ? K.metarDecodedShort : K.metarRawShort)}
              className={`${styles.metarToggle}${showDecoded ? ` ${styles.metarToggleOn}` : ''}`}
              onClick={() => setShowDecoded((value) => !value)}
            >
              <span className={styles.metarToggleKnob} />
            </button>
          </span>
        </div>

        {detail.runwayGeometries.length > 0 && (
          <div className={styles.airportSection}>
            <div className={styles.runwaySectionHead}>
              <span className={styles.airportSectionTitle}>{t(K.toggleRunways)}</span>
              {/* 下滑道信息单独开关：只关心航向台频率时可以收起来 */}
              <button
                type="button"
                className={`${styles.glideslopeToggle}${
                  showGlideslope ? ` ${styles.glideslopeToggleOn}` : ''
                }`}
                onClick={toggleGlideslope}
                title={t(K.runwayGlideslopeHint)}
              >
                <MaterialIcon name="airline_stops" size={11} />
                {t(K.runwayGlideslope)}
              </button>
            </div>

            {detail.runwayGeometries.map((runway) => (
              <div key={runway.ident} className={styles.runwayRow}>
                <span className={`${styles.runwayIdent} text-mono`}>{runway.ident}</span>
                {runway.lengthM !== undefined && (
                  <span className={styles.runwayLength}>
                    {Math.round(runway.lengthM)} m
                  </span>
                )}
                {runway.surface && (
                  <span className={styles.runwaySurface}>
                    {runway.surface.toUpperCase()}
                  </span>
                )}

                {/*
                  一条跑道有两端，进近设施各不相同（例如 ZBAA 36R 是 CAT III、
                  18L 只有 CAT I），所以按端分别列。
                */}
                <span className={styles.runwayEnds}>
                  {[runway.leIdent, runway.heIdent]
                    .filter((end): end is string => !!end)
                    .map((end) => (
                      <RunwayNavaidChips
                        key={end}
                        end={end}
                        navaid={detail.runwayNavaids?.[end.toUpperCase()]}
                        showGlideslope={showGlideslope}
                      />
                    ))}
                </span>
              </div>
            ))}
          </div>
        )}

        {detail.frequencyBadges.length > 0 && (
          <div className={styles.airportSection}>
            <span className={styles.airportSectionTitle}>COM</span>
            <div className={styles.airportChips}>
              {detail.frequencyBadges.map((badge) => (
                <InfoChip key={badge} icon="radio" label={badge} />
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
