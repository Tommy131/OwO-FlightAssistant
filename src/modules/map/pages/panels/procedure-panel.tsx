/**
 * 公布程序面板（SID / STAR / 进近）
 *
 * 一次只画一条程序：大机场动辄上百条（ZBAA 实测 154 条），
 * 全画出来就是一团麻，所以这里的核心是「挑一条」而不是「列全部」。
 */

import { useMemo, useState } from 'react';
import { useTranslate } from '../../../../core/localization/use-translate';
import { IconButton, SegmentedControl, TextField } from '../../../../core/widgets/common/controls';
import { MaterialIcon } from '../../../../core/widgets/common/icon';
import { MapLocalizationKeys as K } from '../../localization/map-localization';
import type { MapProcedure, MapProcedureKind } from '../../models/map-models';
import { useMapStore } from '../../providers/map-store';
import { procedureKey } from '../layers/procedure-layer';
import styles from '../map-page.module.css';

/** 与图层配色保持一致 —— 面板上选中哪条，地图上就是那个颜色 */
const KIND_COLOR: Record<MapProcedureKind, string> = {
  SID: '#4ade80',
  STAR: '#fbbf24',
  APPROACH: '#f87171',
};

const KIND_LABEL_KEY: Record<MapProcedureKind, string> = {
  SID: K.procedureKindSid,
  STAR: K.procedureKindStar,
  APPROACH: K.procedureKindApproach,
};

const KIND_ORDER: readonly MapProcedureKind[] = ['SID', 'STAR', 'APPROACH'];

/** 名称或转换命中即算命中；转换里带跑道号，所以「18R」能直接搜出来 */
function matchesQuery(procedure: MapProcedure, query: string): boolean {
  if (query.length === 0) return true;
  const upper = query.toUpperCase();
  return (
    procedure.name.toUpperCase().includes(upper) ||
    (procedure.transition ?? '').toUpperCase().includes(upper)
  );
}

export function ProcedurePanel() {
  const t = useTranslate();
  const visible = useMapStore((s) => s.showProcedures);
  const airport = useMapStore((s) => s.selectedAirport);
  const procedures = useMapStore((s) => s.procedures);
  const selectedKey = useMapStore((s) => s.selectedProcedureKey);
  const isLoading = useMapStore((s) => s.isLoadingProcedures);
  const selectProcedure = useMapStore((s) => s.selectProcedure);
  const toggleProcedures = useMapStore((s) => s.toggleProcedures);

  const [kind, setKind] = useState<MapProcedureKind>('SID');
  const [query, setQuery] = useState('');

  const counts = useMemo(() => {
    const result: Record<MapProcedureKind, number> = { SID: 0, STAR: 0, APPROACH: 0 };
    for (const procedure of procedures) result[procedure.kind] += 1;
    return result;
  }, [procedures]);

  const shown = useMemo(
    () =>
      procedures
        .filter((item) => item.kind === kind && matchesQuery(item, query))
        // 同名程序按转换（跑道）排在一起，找起来才顺手
        .sort((a, b) =>
          a.name === b.name
            ? (a.transition ?? '').localeCompare(b.transition ?? '')
            : a.name.localeCompare(b.name),
        ),
    [procedures, kind, query],
  );

  if (!visible) return null;

  return (
    <div className={styles.procedurePanel}>
      <div className={styles.procedureHead}>
        <MaterialIcon name="route" size={16} color={KIND_COLOR[kind]} />
        <span className={styles.procedureTitle}>{t(K.procedureTitle)}</span>
        {airport && (
          <span className={`${styles.procedureAirport} text-mono`}>{airport.marker.code}</span>
        )}
        <IconButton icon="close" label={t(K.clearSearch)} onClick={toggleProcedures} />
      </div>

      {!airport ? (
        <div className={styles.procedureHint}>{t(K.procedureNoAirport)}</div>
      ) : isLoading ? (
        <div className={styles.procedureHint}>{t(K.procedureLoading)}</div>
      ) : procedures.length === 0 ? (
        <div className={styles.procedureHint}>{t(K.procedureEmpty)}</div>
      ) : (
        <>
          <SegmentedControl<MapProcedureKind>
            value={kind}
            size="sm"
            block
            onChange={setKind}
            options={KIND_ORDER.map((item) => ({
              value: item,
              label: `${t(KIND_LABEL_KEY[item])} ${counts[item]}`,
            }))}
          />

          <TextField
            value={query}
            onChange={setQuery}
            icon="search"
            placeholder={t(K.procedureSearchHint)}
            className={styles.procedureSearch}
          />

          <div className={`${styles.procedureList} scroll-area`}>
            {shown.map((procedure) => {
              const key = procedureKey(procedure);
              const selected = key === selectedKey;
              const color = KIND_COLOR[procedure.kind];
              return (
                <button
                  key={key}
                  type="button"
                  className={`${styles.procedureRow}${
                    selected ? ` ${styles.procedureRowActive}` : ''
                  }`}
                  style={
                    selected
                      ? {
                          borderColor: `color-mix(in srgb, ${color} 60%, transparent)`,
                          background: `color-mix(in srgb, ${color} 12%, transparent)`,
                        }
                      : undefined
                  }
                  // 再点一次同一条就取消选择，与跑道波束的交互一致
                  onClick={() => selectProcedure(selected ? null : key)}
                >
                  <span className={`${styles.procedureName} text-mono`} style={{ color }}>
                    {procedure.name}
                  </span>
                  {procedure.transition && (
                    <span className={`${styles.procedureTransition} text-mono`}>
                      {procedure.transition}
                    </span>
                  )}
                  <span className={styles.procedureLegs}>
                    {procedure.legs.length} {t(K.procedureLegs)}
                  </span>
                </button>
              );
            })}
          </div>

          {selectedKey && (
            <button
              type="button"
              className={styles.procedureClear}
              onClick={() => selectProcedure(null)}
            >
              <MaterialIcon name="layers_clear" size={12} />
              {t(K.procedureClear)}
            </button>
          )}
        </>
      )}
    </div>
  );
}
