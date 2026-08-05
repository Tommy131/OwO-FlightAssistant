import { useEffect, useRef, useState } from 'react';
import { useTranslate } from '../../../core/localization/use-translate';
import { Button, IconButton, TextField } from '../../../core/widgets/common/controls';
import { MaterialIcon } from '../../../core/widgets/common/icon';
import {
  Card,
  DataCard,
  EmptyState,
  InfoChip,
  SectionCard,
} from '../../../core/widgets/common/surfaces';
import { AirportSearchLocalizationKeys as K } from '../localization/airport-search-localization';
import type { AirportQueryResult } from '../models/airport-search-models';
import {
  isValidIcaoPartial,
  useAirportSearchStore,
} from '../providers/airport-search-store';
import styles from './airport-search-page.module.css';

/**
 * 机场搜索页面
 *
 * 对应 Flutter 版 `modules/airport_search/pages/airport_search_page.dart`
 * 及 widgets/ 下的 6 个组件：ICAO 输入 + 联想建议 + 收藏列表 + 结果卡片
 * （概览 / 位置 / 跑道 / 频率 / METAR）。
 */
export function AirportSearchPage() {
  const t = useTranslate();
  const [input, setInput] = useState('');

  const isSearching = useAirportSearchStore((s) => s.isSearching);
  const isSuggesting = useAirportSearchStore((s) => s.isSuggesting);
  const errorKey = useAirportSearchStore((s) => s.errorKey);
  const latestResult = useAirportSearchStore((s) => s.latestResult);
  const suggestions = useAirportSearchStore((s) => s.suggestions);
  const favorites = useAirportSearchStore((s) => s.favorites);

  const init = useAirportSearchStore((s) => s.init);
  const queryAirport = useAirportSearchStore((s) => s.queryAirport);
  const updateSuggestions = useAirportSearchStore((s) => s.updateSuggestions);
  const clearSuggestions = useAirportSearchStore((s) => s.clearSuggestions);
  const toggleFavorite = useAirportSearchStore((s) => s.toggleFavorite);
  const removeFavorite = useAirportSearchStore((s) => s.removeFavorite);

  const initialized = useRef(false);
  const suggestTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (initialized.current) return;
    initialized.current = true;
    void init();
  }, [init]);

  // 输入联想：250ms 防抖，避免每个字符都打后端
  const handleInputChange = (value: string) => {
    const normalized = value.toUpperCase();
    setInput(normalized);

    if (suggestTimer.current !== null) clearTimeout(suggestTimer.current);
    if (!isValidIcaoPartial(normalized)) {
      clearSuggestions();
      return;
    }
    suggestTimer.current = setTimeout(() => void updateSuggestions(normalized), 250);
  };

  const search = (icao?: string) => {
    const target = icao ?? input;
    if (icao) setInput(icao);
    void queryAirport(target);
  };

  const isCurrentFavorite =
    latestResult !== null && favorites.some((item) => item.icao === latestResult.airport.icao);

  return (
    <div className={`${styles.page} scroll-area`}>
      <div className={styles.content}>
        {/* ── 搜索区 ── */}
        <SectionCard title={t(K.pageTitle)} icon="manage_search" subtitle={t(K.pageSubtitle)}>
          <div className={styles.searchRow}>
            <TextField
              value={input}
              onChange={handleInputChange}
              label={t(K.icaoLabel)}
              placeholder={t(K.icaoHint)}
              icon="flight"
              monospace
              hint={t(K.formatHint)}
              error={errorKey === 'invalidIcao' ? t(K.invalidIcao) : undefined}
              onSubmit={() => search()}
              className={styles.searchField}
            />
            <Button
              variant="elevated"
              icon="search"
              loading={isSearching}
              onClick={() => search()}
            >
              {t(K.searchButton)}
            </Button>
          </div>

          {suggestions.length > 0 && (
            <div className={styles.suggestions}>
              <span className={styles.blockLabel}>{t(K.suggestionsTitle)}</span>
              <div className={styles.suggestionList}>
                {suggestions.map((item) => (
                  <button
                    key={`${item.icao}-${item.name ?? ''}`}
                    type="button"
                    className={styles.suggestionItem}
                    onClick={() => search(item.icao)}
                  >
                    <span className={`${styles.suggestionIcao} text-mono`}>{item.icao}</span>
                    <span className={styles.suggestionName}>{item.name ?? '--'}</span>
                    {item.source && (
                      <span className={styles.suggestionSource}>{item.source}</span>
                    )}
                  </button>
                ))}
              </div>
            </div>
          )}

          {isSuggesting && suggestions.length === 0 && (
            <span className={styles.blockLabel}>{t(K.fuzzyHint)}</span>
          )}

          {errorKey === 'queryFailed' && (
            <div className={styles.errorBanner}>
              <MaterialIcon name="error" size={17} color="var(--color-error)" />
              <span>{t(K.queryFailed)}</span>
            </div>
          )}
        </SectionCard>

        {/* ── 收藏列表 ── */}
        <SectionCard
          title={t(K.favoritesTitle)}
          icon="star"
          trailing={<span className={styles.countBadge}>{favorites.length}</span>}
        >
          {favorites.length === 0 ? (
            <EmptyState icon="star_border" title={t(K.favoritesEmpty)} />
          ) : (
            <div className={styles.favoriteList}>
              {favorites.map((item) => (
                <div key={item.icao} className={styles.favoriteItem}>
                  <button
                    type="button"
                    className={styles.favoriteMain}
                    onClick={() => search(item.icao)}
                    title={t(K.favoriteOpen)}
                  >
                    <span className={`${styles.favoriteIcao} text-mono`}>{item.icao}</span>
                    <span className={styles.favoriteName}>{item.name ?? '--'}</span>
                  </button>
                  <IconButton
                    icon="close"
                    label={t(K.favoriteRemove)}
                    onClick={() => void removeFavorite(item.icao)}
                  />
                </div>
              ))}
            </div>
          )}
        </SectionCard>

        {/* ── 查询结果 ── */}
        {latestResult === null ? (
          <Card>
            <EmptyState icon="travel_explore" title={t(K.noResultHint)} />
          </Card>
        ) : (
          <AirportResultCard
            result={latestResult}
            isFavorite={isCurrentFavorite}
            onToggleFavorite={() => void toggleFavorite()}
          />
        )}
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 结果卡片
// ──────────────────────────────────────────────────────────────────────────

function AirportResultCard({
  result,
  isFavorite,
  onToggleFavorite,
}: {
  result: AirportQueryResult;
  isFavorite: boolean;
  onToggleFavorite: () => void;
}) {
  const t = useTranslate();
  const { airport, metar } = result;

  return (
    <div className={styles.resultStack}>
      {/* 概览 */}
      <SectionCard
        title={t(K.latestResultTitle)}
        icon="location_city"
        trailing={
          <IconButton
            icon={isFavorite ? 'star' : 'star_border'}
            filled={isFavorite}
            label={isFavorite ? t(K.favoriteRemove) : t(K.favoriteAdd)}
            active={isFavorite}
            onClick={onToggleFavorite}
          />
        }
      >
        <div className={styles.overviewHead}>
          <span className={`${styles.overviewIcao} text-mono`}>{airport.icao}</span>
          <div className={styles.overviewText}>
            <span className={styles.overviewName}>{airport.name ?? '--'}</span>
            <span className={styles.overviewSub}>
              {[airport.city, airport.country].filter(Boolean).join(' · ') || '--'}
            </span>
          </div>
        </div>

        <div className={styles.chipRow}>
          {airport.iata && <InfoChip icon="luggage" label={`IATA ${airport.iata}`} />}
          {airport.source && <InfoChip icon="database" label={airport.source} />}
          {airport.airac && <InfoChip icon="update" label={`AIRAC ${airport.airac}`} />}
        </div>
      </SectionCard>

      {/* 位置 */}
      <SectionCard title={t(K.positionSectionTitle)} icon="place">
        <div className={styles.dataGrid}>
          <DataCard label={t(K.airportIcaoLabel)} value={airport.icao} />
          <DataCard
            label={t(K.airportLatLonLabel)}
            value={
              airport.latitude !== undefined && airport.longitude !== undefined
                ? `${airport.latitude.toFixed(4)}, ${airport.longitude.toFixed(4)}`
                : '--'
            }
          />
          <DataCard
            label="ELEV"
            value={airport.elevationFt !== undefined ? String(airport.elevationFt) : '--'}
            unit="ft"
          />
          <DataCard label={t(K.airportNameLabel)} value={airport.name ?? '--'} />
        </div>
      </SectionCard>

      {/* 跑道 */}
      <SectionCard
        title={t(K.runwaysTitle)}
        icon="horizontal_rule"
        trailing={<span className={styles.countBadge}>{airport.runways.length}</span>}
      >
        {airport.runways.length === 0 ? (
          <EmptyState icon="do_not_disturb" title={t(K.runwaysEmpty)} />
        ) : (
          <div className={styles.tableWrap}>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th>{t(K.runwayNameLabel)}</th>
                  <th>{t(K.runwayLengthLabel)}</th>
                  <th>{t(K.runwayTypeLabel)}</th>
                </tr>
              </thead>
              <tbody>
                {airport.runways.map((runway, index) => (
                  <tr key={`${runway.ident}-${index}`}>
                    <td className="text-mono">
                      {runway.leIdent && runway.heIdent
                        ? `${runway.leIdent}/${runway.heIdent}`
                        : runway.ident}
                    </td>
                    <td className="text-mono">
                      {runway.lengthM !== undefined ? `${runway.lengthM.toFixed(0)} m` : '--'}
                    </td>
                    <td>{runway.surface ?? '--'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </SectionCard>

      {/* 频率 */}
      <SectionCard
        title={t(K.frequenciesTitle)}
        icon="radio"
        trailing={<span className={styles.countBadge}>{airport.frequencies.length}</span>}
      >
        {airport.frequencies.length === 0 ? (
          <EmptyState icon="do_not_disturb" title={t(K.frequenciesEmpty)} />
        ) : (
          <div className={styles.tableWrap}>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th>{t(K.frequencyTypeLabel)}</th>
                  <th>{t(K.frequencyValueLabel)}</th>
                </tr>
              </thead>
              <tbody>
                {airport.frequencies.map((frequency, index) => (
                  <tr key={`${frequency.type}-${index}`}>
                    <td>{frequency.type ?? '--'}</td>
                    <td className="text-mono">{frequency.value ?? '--'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </SectionCard>

      {/* METAR */}
      <SectionCard title={t(K.weatherSectionTitle)} icon="cloud">
        {!metar.raw && !metar.decoded ? (
          <EmptyState icon="cloud_off" title={t(K.metarEmpty)} />
        ) : (
          <div className={styles.metarBlock}>
            {metar.raw && (
              <>
                <span className={styles.blockLabel}>{t(K.metarRawLabel)}</span>
                <p className={`${styles.metarRaw} text-mono`}>{metar.raw}</p>
              </>
            )}
            {metar.decoded && (
              <>
                <span className={styles.blockLabel}>{t(K.metarDecodedLabel)}</span>
                <p className={styles.metarDecoded}>{metar.decoded}</p>
              </>
            )}
            <div className={styles.chipRow}>
              <InfoChip icon="air" label={`${t(K.metarWind)} ${metar.wind ?? '--'}`} />
              <InfoChip
                icon="visibility"
                label={`${t(K.metarVisibility)} ${metar.visibility ?? '--'}`}
              />
              <InfoChip
                icon="thermostat"
                label={`${t(K.metarTemperature)} ${metar.temperature ?? '--'}`}
              />
              <InfoChip
                icon="compress"
                label={`${t(K.metarAltimeter)} ${metar.altimeter ?? '--'}`}
              />
            </div>
          </div>
        )}
      </SectionCard>
    </div>
  );
}
