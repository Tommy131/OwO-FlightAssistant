/**
 * 右侧控制栏：按类型分组的图层开关
 *
 * 悬停展开该组、点击常驻、点空白处收起。分组本身是数据驱动的，
 * 加一个开关＝往对应组的数组里加一项。
 */

import { useEffect, useState } from 'react';
import { useTranslate } from '../../../../core/localization/use-translate';
import { IconButton } from '../../../../core/widgets/common/controls';
import { MapLocalizationKeys as K } from '../../localization/map-localization';
import { useMapStore } from '../../providers/map-store';
import styles from '../map-page.module.css';

// ──────────────────────────────────────────────────────────────────────────
// 右侧控制栏
// ──────────────────────────────────────────────────────────────────────────

interface ControlToggle {
  icon: string;
  label: string;
  active: boolean;
  onClick: () => void;
}

interface ControlGroup {
  id: string;
  icon: string;
  label: string;
  items: ControlToggle[];
}

/**
 * 右侧控制栏
 *
 * 十七八个开关平铺一列会占掉半个屏幕，所以按用途归成几组：
 * 平时只显示组图标，鼠标移上去自动展开该组，点一下则固定展开（不随移出收起）。
 * 组图标在任一子开关打开时高亮，收起状态下也能看出这组里有东西开着。
 */
export function MapRightControls({ onOpenLayerPicker }: { onOpenLayerPicker: () => void }) {
  const t = useTranslate();
  const state = useMapStore();

  // 悬停展开的组；点击固定的组单独记，两者取并集显示
  const [hoveredGroup, setHoveredGroup] = useState<string | null>(null);
  const [pinnedGroup, setPinnedGroup] = useState<string | null>(null);

  const groups: ControlGroup[] = [
    {
      id: 'flight',
      icon: 'flight',
      label: t(K.controlGroupFlight),
      items: [
        {
          icon: 'my_location',
          label: t(K.tooltipFollow),
          active: state.followAircraft,
          onClick: state.toggleFollowAircraft,
        },
        {
          icon: 'timeline',
          label: t(K.toggleRoute),
          active: state.showRoute,
          onClick: state.toggleRoute,
        },
        {
          // 计划航路（SimBrief 导入）—— 与「航迹」区分：那是飞过的，这是要飞的
          icon: 'route',
          label: t(K.tooltipPlannedRoute),
          active: state.showPlannedRoute,
          onClick: state.togglePlannedRoute,
        },
        {
          icon: 'explore',
          label: t(K.toggleCompass),
          active: state.showCompass,
          onClick: state.toggleCompass,
        },
      ],
    },
    {
      id: 'airport',
      icon: 'connecting_airports',
      label: t(K.controlGroupAirport),
      items: [
        {
          icon: 'local_airport',
          label: t(K.toggleAirports),
          active: state.showAirports,
          onClick: state.toggleAirports,
        },
        {
          icon: 'horizontal_rule',
          label: t(K.toggleRunways),
          active: state.showRunways,
          onClick: state.toggleRunways,
        },
        {
          icon: 'local_parking',
          label: t(K.toggleParkings),
          active: state.showParkings,
          onClick: state.toggleParkings,
        },
        {
          icon: 'alt_route',
          label: t(K.toggleAeroway),
          active: state.showAeroway,
          onClick: state.toggleAeroway,
        },
      ],
    },
    {
      id: 'procedure',
      icon: 'flight_land',
      label: t(K.controlGroupProcedure),
      items: [
        {
          icon: 'cell_tower',
          label: t(K.toggleRunwayNavaids),
          active: state.showRunwayNavaids,
          onClick: state.toggleRunwayNavaids,
        },
        {
          icon: 'loop',
          label: t(K.toggleHoldings),
          active: state.showHoldings,
          onClick: state.toggleHoldings,
        },
        {
          icon: 'trending_down',
          label: t(K.runwayGlideslope),
          active: state.showGlideslope,
          onClick: state.toggleGlideslope,
        },
      ],
    },
    {
      id: 'weather',
      icon: 'cloud',
      label: t(K.controlGroupWeather),
      items: [
        {
          icon: 'radar',
          label: t(K.toggleWeather),
          active: state.showWeather,
          onClick: state.toggleWeather,
        },
        {
          icon: 'water_drop',
          label: t(K.toggleWeatherRainfall),
          active: state.showWeatherRainfall,
          onClick: state.toggleWeatherRainfall,
        },
        {
          icon: 'air',
          label: t(K.toggleWeatherWind),
          active: state.showWeatherWind,
          onClick: state.toggleWeatherWind,
        },
        {
          icon: 'compress',
          label: t(K.toggleWeatherPressure),
          active: state.showWeatherPressure,
          onClick: state.toggleWeatherPressure,
        },
        {
          icon: 'thermostat',
          label: t(K.toggleWeatherTemperature),
          active: state.showWeatherTemperature,
          onClick: state.toggleWeatherTemperature,
        },
      ],
    },
    {
      id: 'hazard',
      icon: 'warning',
      label: t(K.controlGroupHazard),
      items: [
        {
          icon: 'block',
          label: t(K.toggleRestrictedAirspace),
          active: state.showRestrictedAirspace,
          onClick: state.toggleRestrictedAirspace,
        },
        {
          icon: 'terrain',
          label: t(K.toggleTerrainWarning),
          active: state.showTerrainWarning,
          onClick: state.toggleTerrainWarning,
        },
      ],
    },
    {
      id: 'taxiway',
      icon: 'edit_road',
      label: t(K.controlGroupTaxiway),
      items: [
        {
          icon: 'polyline',
          label: t(K.toggleCustomTaxiway),
          active: state.showCustomTaxiwayRoute,
          onClick: state.toggleCustomTaxiway,
        },
        {
          icon: 'draw',
          label: t(K.toggleTaxiwayDrawing),
          active: state.isTaxiwayDrawingActive,
          onClick: state.toggleTaxiwayDrawing,
        },
      ],
    },
  ];

  // 点击地图空白处收起固定展开的组
  useEffect(() => {
    if (!pinnedGroup) return;
    const close = (event: MouseEvent) => {
      // target 不一定是元素（可能是 document 本身），closest 只有 Element 才有
      const target = event.target;
      if (target instanceof Element && target.closest(`.${styles.rightControls}`)) {
        // 点在控制栏自己身上不算「点空白」
        return;
      }
      setPinnedGroup(null);
    };
    document.addEventListener('mousedown', close);
    return () => document.removeEventListener('mousedown', close);
  }, [pinnedGroup]);

  return (
    <div
      // 不能带 scroll-area：那个工具类会设 overflow，把向左弹出的子面板裁掉
      className={styles.rightControls}
      onMouseLeave={() => setHoveredGroup(null)}
    >
      <IconButton icon="layers" label={t(K.layerTitle)} onClick={onOpenLayerPicker} />
      <span className={styles.controlDivider} />

      {groups.map((group) => {
        const expanded = hoveredGroup === group.id || pinnedGroup === group.id;
        const anyActive = group.items.some((item) => item.active);
        return (
          <div
            key={group.id}
            className={styles.controlGroup}
            onMouseEnter={() => setHoveredGroup(group.id)}
          >
            <IconButton
              icon={group.icon}
              label={group.label}
              active={anyActive}
              onClick={() => setPinnedGroup((current) => (current === group.id ? null : group.id))}
            />
            {/* 常驻展开时给个小圆点，跟单纯悬停展开区分开 */}
            {pinnedGroup === group.id && <span className={styles.groupPinnedDot} />}

            {expanded && (
              <div className={styles.groupFlyout}>
                {group.items.map((item) => (
                  <IconButton
                    key={item.label}
                    icon={item.icon}
                    label={item.label}
                    active={item.active}
                    onClick={item.onClick}
                  />
                ))}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}
