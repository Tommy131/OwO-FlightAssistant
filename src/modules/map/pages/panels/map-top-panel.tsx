/**
 * 顶部面板：机场搜索（带联想）与飞行状态条
 */

import { useEffect, useState } from 'react';
import { useTranslate } from '../../../../core/localization/use-translate';
import { IconButton, TextField } from '../../../../core/widgets/common/controls';
import { InfoChip } from '../../../../core/widgets/common/surfaces';
import { MapLocalizationKeys as K } from '../../localization/map-localization';
import { useMapStore } from '../../providers/map-store';
import styles from '../map-page.module.css';

/** 搜索联想候选项 */
export interface AirportSuggestion {
  icao: string;
  label: string;
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

  const [suggestions, setSuggestions] = useState<AirportSuggestion[]>([]);
  const [showSuggestions, setShowSuggestions] = useState(false);

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

  return (
    <div className={styles.topPanel}>
      <div className={styles.searchBar}>
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

        {showSuggestions && suggestions.length > 0 && (
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
      </div>

      <div className={styles.statusChips}>
        {isPaused && <InfoChip icon="pause" label="PAUSED" color="var(--color-warning)" solid />}
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
