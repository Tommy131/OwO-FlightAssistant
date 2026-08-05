import { useState } from 'react';
import { useTranslate } from '../../../core/localization/use-translate';
import { MaterialIcon } from '../../../core/widgets/common/icon';
import { MapLocalizationKeys as K } from '../localization/map-localization';
import {
  legendGradient,
  MAP_LEGENDS,
  type MapLegend,
  type MapLegendId,
} from '../models/map-legends';
import { useMapStore } from '../providers/map-store';
import styles from './map-legend.module.css';

/**
 * 图层图例
 *
 * 天气与空域图层原本只有颜色没有刻度，看到一片橙色也说不出大概是多少度、
 * 多少百帕。这里为每个开启的图层显示一条色标，把颜色对回数值。
 *
 * 只画当前开启的图层；一个都没开时整个组件不渲染。
 */
export function MapLegendStack() {
  const t = useTranslate();
  const [collapsed, setCollapsed] = useState(false);

  const active = useMapStore((s) => {
    const ids: MapLegendId[] = [];
    if (s.showWeather) ids.push('radar');
    if (s.showWeatherRainfall) ids.push('rain');
    if (s.showWeatherWind) ids.push('wind');
    if (s.showWeatherPressure) ids.push('pressure');
    if (s.showWeatherTemperature) ids.push('temp');
    if (s.showRestrictedAirspace) ids.push('airspace');
    if (s.showTerrainWarning) ids.push('terrain');
    // Zustand 默认用 Object.is 比较，每次都新建数组会让组件反复重渲染，
    // 这里返回拼好的字符串键，由下面再拆回数组。
    return ids.join(',');
  });

  if (active.length === 0) return null;
  const ids = active.split(',') as MapLegendId[];

  return (
    <div className={styles.legendStack}>
      {!collapsed &&
        ids.map((id) => <LegendCard key={id} legend={MAP_LEGENDS[id]} />)}
      <button
        type="button"
        className={styles.collapseButton}
        onClick={() => setCollapsed((value) => !value)}
        title={t(collapsed ? K.legendExpand : K.legendCollapse)}
        aria-label={t(collapsed ? K.legendExpand : K.legendCollapse)}
      >
        <MaterialIcon name={collapsed ? 'expand_less' : 'expand_more'} size={13} />
        {t(K.legendTitle)}
      </button>
    </div>
  );
}

function LegendCard({ legend }: { legend: MapLegend }) {
  const t = useTranslate();

  return (
    <div className={styles.card}>
      <div className={styles.title}>
        <span>{t(legend.titleKey)}</span>
        {legend.kind === 'ramp' && legend.unit ? (
          <span className={styles.unit}>{legend.unit}</span>
        ) : null}
      </div>

      {legend.kind === 'ramp' ? (
        <>
          <div
            className={styles.ramp}
            style={{ background: legendGradient(legend.colors) }}
          />
          <div className={styles.ticks}>
            {legend.ticks.map((tick) => (
              // 定性刻度存的是 i18n key，数值刻度存的是字面量；
              // t() 找不到 key 时会原样返回，所以两种都能直接过一遍。
              <span key={tick} className={styles.tick}>
                {t(tick)}
              </span>
            ))}
          </div>
        </>
      ) : (
        <div className={styles.swatchList}>
          {legend.items.map((item) => (
            <div key={item.labelKey} className={styles.swatchRow}>
              <span className={styles.swatch} style={{ background: item.color }} />
              {t(item.labelKey)}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
