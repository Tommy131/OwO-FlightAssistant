/**
 * 顶部面板：机场搜索（带联想）与飞行状态条
 */

import { useEffect, useRef, useState } from 'react';
import { useTranslate } from '../../../../core/localization/use-translate';
import { IconButton, TextField } from '../../../../core/widgets/common/controls';
import { MaterialIcon } from '../../../../core/widgets/common/icon';
import { MarqueeText } from '../../../../core/widgets/common/marquee-text';
import { InfoChip } from '../../../../core/widgets/common/surfaces';
import { useAirportFavoritesStore } from '../../../common/providers/airport-favorites-store';
import { MapLocalizationKeys as K } from '../../localization/map-localization';
import { useMapStore } from '../../providers/map-store';
import styles from '../map-page.module.css';

/** 搜索联想候选项 */
export interface AirportSuggestion {
  icao: string;
  label: string;
}

/** 徽标上的滑行距离：一公里以内报米，更长报公里（与面板一致） */
function formatTaxiDistance(meters: number): string {
  return meters < 1000 ? `${Math.round(meters)} m` : `${(meters / 1000).toFixed(2)} km`;
}

// ──────────────────────────────────────────────────────────────────────────
// 顶部面板：搜索 + 飞行状态
// ──────────────────────────────────────────────────────────────────────────

export function MapTopPanel({
  searchValue,
  onSearchChange,
  onSearchSubmit,
  onFetchSuggestions,
  onSelectSuggestion,
}: {
  searchValue: string;
  onSearchChange: (value: string) => void;
  onSearchSubmit: () => void;
  onFetchSuggestions: (keyword: string) => Promise<AirportSuggestion[]>;
  onSelectSuggestion: (icao: string) => void;
}) {
  const t = useTranslate();
  const aircraft = useMapStore((s) => s.aircraft);
  const isConnected = useMapStore((s) => s.isConnected);
  const isPaused = useMapStore((s) => s.isPaused);
  const nearestIcao = useMapStore((s) => s.currentNearestAirportIcao);
  // 收起后的滑行路线在状态栏留一个可点的徽标，用来把面板唤回来
  const taxiPlan = useMapStore((s) => s.taxiPlan);
  const taxiCollapsed = useMapStore((s) => s.taxiPanelCollapsed);
  const setTaxiCollapsed = useMapStore((s) => s.setTaxiPanelCollapsed);

  const [suggestions, setSuggestions] = useState<AirportSuggestion[]>([]);
  const [showSuggestions, setShowSuggestions] = useState(false);

  /*
   * 收藏机场：与机场查询页共用 common 里的同一个 store，
   * 那边点星标这边立刻就有，不需要任何同步代码。
   */
  const favorites = useAirportFavoritesStore((s) => s.favorites);
  const hydrateFavorites = useAirportFavoritesStore((s) => s.hydrate);
  useEffect(() => {
    void hydrateFavorites();
  }, [hydrateFavorites]);

  // 输入防抖 250ms，避免每敲一个字母打一次接口
  useEffect(() => {
    const query = searchValue.trim();
    if (query.length < 2) {
      setSuggestions([]);
      return;
    }
    let cancelled = false;
    const timer = setTimeout(() => {
      void onFetchSuggestions(query).then((result) => {
        if (!cancelled) setSuggestions(result);
      });
    }, 250);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchValue]);

  /*
   * 点击面板外关闭浮层。
   *
   * 没有这一层的话，收藏列表在还没输入任何东西时就会展开，
   * 而且点地图也关不掉 —— 它正好压在地图左上角一片可点区域上。
   */
  const searchBarRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!showSuggestions) return;
    const onPointerDown = (event: PointerEvent) => {
      const node = searchBarRef.current;
      if (node && !node.contains(event.target as Node)) setShowSuggestions(false);
    };
    document.addEventListener('pointerdown', onPointerDown);
    return () => document.removeEventListener('pointerdown', onPointerDown);
  }, [showSuggestions]);

  // 还没输入时给收藏列表；输入了就让位给联想结果
  const isEmptyQuery = searchValue.trim().length === 0;
  const showFavorites = showSuggestions && isEmptyQuery && favorites.length > 0;

  return (
    <div className={styles.topPanel}>
      <div className={styles.searchBar} ref={searchBarRef}>
        <TextField
          value={searchValue}
          onChange={(value) => {
            onSearchChange(value.toUpperCase());
            setShowSuggestions(true);
          }}
          placeholder={t(K.searchHint)}
          icon="search"
          monospace
          onSubmit={() => {
            setShowSuggestions(false);
            onSearchSubmit();
          }}
          onFocus={() => setShowSuggestions(true)}
          trailing={
            searchValue.length > 0 ? (
              <IconButton
                icon="close"
                label={t(K.clearSearch)}
                size={16}
                onClick={() => {
                  onSearchChange('');
                  setSuggestions([]);
                }}
              />
            ) : undefined
          }
        />

        {showSuggestions && !isEmptyQuery && suggestions.length > 0 && (
          <div className={styles.suggestionList}>
            {suggestions.map((suggestion) => (
              <button
                key={suggestion.icao}
                type="button"
                className={styles.suggestionItem}
                onClick={() => {
                  setShowSuggestions(false);
                  onSelectSuggestion(suggestion.icao);
                }}
              >
                <span className={`${styles.suggestionIcao} text-mono`}>{suggestion.icao}</span>
                <span className={styles.suggestionLabel}>{suggestion.label}</span>
              </button>
            ))}
          </div>
        )}

        {/* 还没输入：直接把收藏过的机场摆出来，省得再敲一遍 ICAO */}
        {showFavorites && (
          <div className={styles.suggestionList}>
            <span className={styles.suggestionGroupTitle}>
              <MaterialIcon name="star" filled size={12} color="#fab219" />
              {t(K.favoritesSectionTitle)}
            </span>
            {favorites.map((favorite) => (
              <button
                key={favorite.icao}
                type="button"
                className={styles.suggestionItem}
                onClick={() => {
                  setShowSuggestions(false);
                  onSelectSuggestion(favorite.icao);
                }}
              >
                <span className={`${styles.suggestionIcao} text-mono`}>{favorite.icao}</span>
                <MarqueeText
                  text={favorite.name ?? '--'}
                  className={styles.suggestionLabel}
                />
              </button>
            ))}
          </div>
        )}
      </div>

      <div className={styles.statusChips}>
        {isPaused && <InfoChip icon="pause" label="PAUSED" color="var(--color-warning)" solid />}
        {/*
          收起后的滑行路线在这里留个入口：显示全程距离，点一下把面板唤回来。
          没有这个徽标的话，面板一收就再也找不回来了 —— 只能关掉整个图层重开，
          那样连规划好的路线也一并丢了。
        */}
        {taxiPlan && taxiCollapsed && (
          <InfoChip
            icon="alt_route"
            color="#ff8c1a"
            label={`${t(K.taxiTitle)} · ${formatTaxiDistance(taxiPlan.distanceM)}`}
            title={t(K.taxiExpand)}
            onClick={() => setTaxiCollapsed(false)}
          />
        )}
        {nearestIcao && <InfoChip icon="local_airport" label={nearestIcao} />}
        {isConnected && aircraft && (
          <>
            <InfoChip icon="height" label={`${(aircraft.altitude ?? 0).toFixed(0)} ft`} />
            <InfoChip icon="speed" label={`${(aircraft.groundSpeed ?? 0).toFixed(0)} kt`} />
            <InfoChip icon="explore" label={`${(aircraft.heading ?? 0).toFixed(0)}°`} />
          </>
        )}
      </div>
    </div>
  );
}
