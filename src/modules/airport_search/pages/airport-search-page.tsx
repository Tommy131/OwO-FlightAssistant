import { useEffect, useRef, useState } from 'react';
import { useTranslate } from '../../../core/localization/use-translate';
import { Button, IconButton, TextField } from '../../../core/widgets/common/controls';
import { MaterialIcon } from '../../../core/widgets/common/icon';
import {
  Card,
  EmptyState,
  InfoChip,
  SectionCard,
} from '../../../core/widgets/common/surfaces';
import { useAirportFavoritesStore } from '../../common/providers/airport-favorites-store';
import {
  FREQUENCY_CATEGORY_COLOR,
  formatFrequencyValues,
  groupFrequencies,
} from '../../common/services/airport-frequencies';
import { AirportSearchLocalizationKeys as K } from '../localization/airport-search-localization';
import type { AirportQueryResult } from '../models/airport-search-models';
import {
  isValidIcaoPartial,
  useAirportSearchStore,
} from '../providers/airport-search-store';
import { parseMetarWind } from '../services/metar-wind';
import { WindIndicator } from './widgets/wind-indicator';
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
  // 收藏来自 common 的共享 store —— 地图搜索框读的是同一份
  const favorites = useAirportFavoritesStore((s) => s.favorites);

  const init = useAirportSearchStore((s) => s.init);
  const queryAirport = useAirportSearchStore((s) => s.queryAirport);
  const updateSuggestions = useAirportSearchStore((s) => s.updateSuggestions);
  const clearSuggestions = useAirportSearchStore((s) => s.clearSuggestions);
  const toggleFavorite = useAirportSearchStore((s) => s.toggleFavorite);
  const removeFavorite = useAirportFavoritesStore((s) => s.remove);

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

  // 风向要的是数值（指针角度），后端给的 display_wind 是给人看的串，
  // 单位还可能是 m/s —— 直接解原始报文见 services/metar-wind.ts
  const wind = parseMetarWind(metar.raw);
  const frequencyGroups = groupFrequencies(airport.frequencies);

  const latLonText =
    airport.latitude !== undefined && airport.longitude !== undefined
      ? `LAT: ${airport.latitude.toFixed(5)}   LON: ${airport.longitude.toFixed(5)}`
      : 'LAT: --   LON: --';
  const elevText = airport.elevationFt !== undefined ? `${airport.elevationFt}` : '-';

  return (
    <div className={styles.resultCard}>
      {/* ── 标题行：ICAO + 名称 + 数据源 + 收藏 ── */}
      <header className={styles.resultHead}>
        <span className={`${styles.resultIcao} text-mono`}>{airport.icao}</span>
        <span className={styles.resultName}>{airport.name ?? '--'}</span>
        {airport.source && <span className={styles.sourceTag}>{airport.source}</span>}
        <span className={styles.headSpacer} />
        <IconButton
          icon={isFavorite ? 'star' : 'star_border'}
          filled={isFavorite}
          label={isFavorite ? t(K.favoriteRemove) : t(K.favoriteAdd)}
          active={isFavorite}
          onClick={onToggleFavorite}
        />
      </header>

      {/* ── 主体：左侧风向罗盘，右侧位置/气象/跑道 ── */}
      <div className={styles.resultBody}>
        <WindIndicator wind={wind} />

        <div className={styles.resultDetails}>
          <section className={styles.detailBlock}>
            <span className={styles.detailTitle}>
              <MaterialIcon name="place" size={15} color="var(--color-primary)" />
              {t(K.positionSectionTitle)}
            </span>
            <span className={`${styles.detailValue} text-mono`}>
              {latLonText}   ELEV: {elevText}
            </span>
          </section>

          <section className={styles.detailBlock}>
            <span className={styles.detailTitle}>
              <MaterialIcon name="cloud" size={15} color="var(--color-primary)" />
              {t(K.weatherSectionTitle)}
            </span>
            {metar.raw ? (
              <span className={`${styles.detailValue} text-mono`}>{metar.raw}</span>
            ) : (
              <span className={styles.detailMuted}>{t(K.metarEmpty)}</span>
            )}
            <div className={styles.chipRow}>
              <InfoChip label={`${t(K.metarWind)}: ${metar.wind ?? '--'}`} />
              <InfoChip label={`${t(K.metarVisibility)}: ${metar.visibility ?? 'N/A'}`} />
              <InfoChip label={`${t(K.metarTemperature)}: ${metar.temperature ?? '--'}`} />
              <InfoChip label={`${t(K.metarAltimeter)}: ${metar.altimeter ?? '--'}`} />
            </div>
            {metar.decoded && <span className={styles.detailMuted}>{metar.decoded}</span>}
          </section>

          <section className={styles.detailBlock}>
            <span className={styles.detailTitle}>
              <MaterialIcon name="flight_land" size={15} color="var(--color-primary)" />
              {t(K.runwaySectionTitle)}
            </span>
            {airport.runways.length === 0 ? (
              <span className={styles.detailMuted}>{t(K.runwaysEmpty)}</span>
            ) : (
              <div className={styles.runwayGrid}>
                {airport.runways.map((runway, index) => (
                  <div key={`${runway.ident}-${index}`} className={styles.runwayCard}>
                    <span className={`${styles.runwayIdent} text-mono`}>
                      {runway.leIdent && runway.heIdent
                        ? `${runway.leIdent}/${runway.heIdent}`
                        : runway.ident}
                    </span>
                    <span className={`${styles.runwayLength} text-mono`}>
                      {runway.lengthM !== undefined ? `${runway.lengthM.toFixed(0)} m` : '--'}
                    </span>
                    <span className={styles.runwaySurface}>{runway.surface ?? '--'}</span>
                  </div>
                ))}
              </div>
            )}
          </section>
        </div>
      </div>

      {/* ── 通讯频率：同类合并成一行，按类别配色 ── */}
      <section className={styles.freqSection}>
        <span className={styles.detailTitle}>
          <MaterialIcon name="wifi_tethering" size={15} color="var(--color-primary)" />
          {t(K.frequenciesTitle)}
        </span>
        {frequencyGroups.length === 0 ? (
          <span className={styles.detailMuted}>{t(K.frequenciesEmpty)}</span>
        ) : (
          <div className={styles.tableWrap}>
            <table className={styles.freqTable}>
              <thead>
                <tr>
                  <th>{t(K.frequencyTypeLabel)}</th>
                  <th>{t(K.frequencyValueLabel)}</th>
                </tr>
              </thead>
              <tbody>
                {frequencyGroups.map((group) => (
                  <tr key={group.category}>
                    <td>
                      <span
                        className={styles.freqLabel}
                        style={{ color: FREQUENCY_CATEGORY_COLOR[group.category] }}
                      >
                        {group.label}
                      </span>
                    </td>
                    <td className="text-mono">{formatFrequencyValues(group.values)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
