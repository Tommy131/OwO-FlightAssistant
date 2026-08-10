import { useEffect, useMemo } from 'react';

import { useTranslate } from '../../../core/localization/use-translate';
import { calculateDistanceNm } from '../../../core/utils/parse-utils';
import { Button } from '../../../core/widgets/common/controls';
import { MaterialIcon } from '../../../core/widgets/common/icon';
import {
  EmptyState,
  SectionCard,
  StatusBadge,
  type StatusTone,
} from '../../../core/widgets/common/surfaces';
import { CommonLocalizationKeys } from '../../common/localization/common-localization';
import { useAppModeStore } from '../../common/providers/app-mode-store';
import { useFlightDataStore } from '../../common/providers/flight-data-store';
import {
  EfbLocalizationKeys as K,
  GATE_LABEL_KEY,
  PHASE_ICON,
  PHASE_LABEL_KEY,
} from '../localization/efb-localization';
import { useEfbStore, type NearbyAirport } from '../providers/efb-store';
import {
  buildGates,
  computeFuelMargin,
  normalizePhase,
  type FlightGate,
  type FuelMargin,
  type GateStatus,
} from '../services/efb-gates';
import styles from './efb-page.module.css';

/**
 * EFB 单页飞行卡
 *
 * 把飞行中真正要盯的四件事挤进一屏：现在处于哪个阶段、这个阶段该盯哪些门限、
 * 附近能去哪儿、油还够不够。
 *
 * 页面本身只做展示编排：门限与油量的算法在 `services/efb-gates.ts`（纯函数、有单测），
 * 近场机场与批量气象在 `providers/efb-store.ts`。
 */
export function EfbPage() {
  const t = useTranslate();
  const snapshot = useFlightDataStore((s) => s.snapshot);
  const reviewMode = useAppModeStore((s) => s.mode) === 'review';
  const airports = useEfbStore((s) => s.airports);
  const loading = useEfbStore((s) => s.loading);
  const lastUpdatedAt = useEfbStore((s) => s.lastUpdatedAt);
  const refresh = useEfbStore((s) => s.refresh);

  const flightData = snapshot.flightData;
  const phase = normalizePhase(flightData.flightPhase);
  const gates = useMemo(() => buildGates(phase, flightData), [phase, flightData]);

  const destination = snapshot.destinationAirport;
  const distanceToDestinationNm = useMemo(() => {
    if (!destination || flightData.latitude === undefined || flightData.longitude === undefined) {
      return undefined;
    }
    if (destination.latitude === 0 && destination.longitude === 0) return undefined;
    return calculateDistanceNm(
      flightData.latitude,
      flightData.longitude,
      destination.latitude,
      destination.longitude,
    );
  }, [destination, flightData.latitude, flightData.longitude]);

  const fuel = useMemo(
    () =>
      computeFuelMargin({
        fuelQuantityKg: flightData.fuelQuantity,
        fuelFlowKgh: flightData.fuelFlow,
        distanceToDestinationNm,
        groundSpeedKt: flightData.groundSpeed,
        hasAlternate: snapshot.alternateAirport !== undefined,
      }),
    [
      flightData.fuelQuantity,
      flightData.fuelFlow,
      flightData.groundSpeed,
      distanceToDestinationNm,
      snapshot.alternateAirport,
    ],
  );

  // 位置一变就尝试刷新，节流交给 store（60s / 25NM 才真正发请求）。
  const latitude = flightData.latitude;
  const longitude = flightData.longitude;
  useEffect(() => {
    // 复盘模式下不自动拉网络：用户在看历史，没必要每分钟去打一次 NOAA。
    if (reviewMode) return;
    if (!snapshot.isConnected || latitude === undefined || longitude === undefined) return;
    const extras = [
      snapshot.departureAirport?.icaoCode,
      snapshot.destinationAirport?.icaoCode,
      snapshot.alternateAirport?.icaoCode,
    ].filter((value): value is string => typeof value === 'string' && value.length > 0);
    void refresh({ latitude, longitude, extraIcaos: extras });
  }, [
    reviewMode,
    snapshot.isConnected,
    latitude,
    longitude,
    snapshot.departureAirport,
    snapshot.destinationAirport,
    snapshot.alternateAirport,
    refresh,
  ]);

  // 复盘模式下仍允许手动点刷新 —— 关掉的是自动轮询，不是这个功能本身。
  const canRefresh = latitude !== undefined && longitude !== undefined;

  return (
    <div className={styles.page}>
      <header className={styles.pageHeader}>
        <div>
          <h2 className={styles.pageTitle}>{t(K.pageTitle)}</h2>
          <p className={styles.pageSubtitle}>{t(K.pageSubtitle)}</p>
        </div>
        <Button
          variant="elevated"
          icon="refresh"
          loading={loading}
          disabled={!canRefresh}
          onClick={() => {
            if (latitude === undefined || longitude === undefined) return;
            void refresh({ latitude, longitude, force: true });
          }}
        >
          {loading ? t(K.loading) : t(K.refresh)}
        </Button>
      </header>

      {reviewMode && (
        <div className={styles.reviewBanner}>
          <MaterialIcon name="history" size={16} color="var(--color-warning)" />
          <span>{t(CommonLocalizationKeys.appModeReviewBanner)}</span>
        </div>
      )}

      {!snapshot.isConnected && !reviewMode && (
        <EmptyState icon="flight" title={t(K.disconnected)} />
      )}

      <div className={styles.grid}>
        <SectionCard
          title={t(K.sectionPhase)}
          icon={PHASE_ICON[phase] ?? 'help'}
          className={styles.phaseCard}
        >
          <div className={styles.phaseRow}>
            <MaterialIcon
              name={PHASE_ICON[phase] ?? 'help'}
              size={34}
              color="var(--color-primary)"
            />
            <span className={styles.phaseName}>{t(PHASE_LABEL_KEY[phase] ?? K.phaseUnknown)}</span>
          </div>
          <div className={styles.phaseMetrics}>
            <PhaseMetric label="ALT" value={formatValue(flightData.altitude, 0, 'ft')} />
            <PhaseMetric label="IAS" value={formatValue(flightData.airspeed, 0, 'kt')} />
            <PhaseMetric label="GS" value={formatValue(flightData.groundSpeed, 0, 'kt')} />
            <PhaseMetric label="V/S" value={formatValue(flightData.verticalSpeed, 0, 'fpm')} />
          </div>
        </SectionCard>

        <SectionCard title={t(K.sectionGates)} icon="rule">
          {gates.length === 0 ? (
            <p className={styles.mutedText}>{t(K.noGates)}</p>
          ) : (
            <div className={styles.gateList}>
              {gates.map((gate) => (
                <GateRow key={gate.id} gate={gate} label={t(GATE_LABEL_KEY[gate.id] ?? gate.id)} />
              ))}
            </div>
          )}
        </SectionCard>

        <SectionCard
          title={t(K.sectionFuel)}
          icon="local_gas_station"
          trailing={<StatusBadge label={t(fuelStatusKey(fuel))} tone={fuelStatusTone(fuel)} />}
        >
          <div className={styles.fuelGrid}>
            <FuelRow label={t(K.fuelOnboard)} value={formatValue(flightData.fuelQuantity, 0, 'kg')} />
            <FuelRow label={t(K.fuelFlow)} value={formatValue(flightData.fuelFlow, 0, 'kg/h')} />
            <FuelRow label={t(K.fuelEndurance)} value={formatHours(fuel.enduranceHours)} />
            <FuelRow
              label={t(K.fuelBurnToDest)}
              value={formatValue(fuel.burnToDestinationKg, 0, 'kg')}
            />
            <FuelRow label={t(K.fuelAtDest)} value={formatValue(fuel.fuelAtDestinationKg, 0, 'kg')} />
            <FuelRow label={t(K.fuelReserve)} value={formatValue(fuel.requiredReserveKg, 0, 'kg')} />
            <FuelRow
              label={t(K.fuelMargin)}
              value={formatValue(fuel.marginKg, 0, 'kg')}
              tone={fuelStatusTone(fuel)}
            />
          </div>
        </SectionCard>

        <SectionCard
          title={t(K.sectionNearby)}
          icon="near_me"
          subtitle={lastUpdatedAt ? t(K.lastUpdated, formatClock(lastUpdatedAt)) : undefined}
          className={styles.nearbyCard}
        >
          {airports.length === 0 ? (
            <p className={styles.mutedText}>{t(K.nearbyEmpty)}</p>
          ) : (
            <div className={styles.airportList}>
              {airports.map((airport) => (
                <AirportRow key={airport.icao} airport={airport} t={t} />
              ))}
            </div>
          )}
        </SectionCard>
      </div>
    </div>
  );
}

function PhaseMetric({ label, value }: { label: string; value: string }) {
  return (
    <div className={styles.phaseMetric}>
      <span className={styles.phaseMetricLabel}>{label}</span>
      <span className={`${styles.phaseMetricValue} text-mono`}>{value}</span>
    </div>
  );
}

function GateRow({ gate, label }: { gate: FlightGate; label: string }) {
  return (
    <div className={styles.gateRow} data-status={gate.status}>
      <MaterialIcon
        name={GATE_STATUS_ICON[gate.status]}
        filled
        size={16}
        color={GATE_STATUS_COLOR[gate.status]}
      />
      <span className={styles.gateLabel}>{label}</span>
      <span className={`${styles.gateValue} text-mono`} style={{ color: GATE_STATUS_COLOR[gate.status] }}>
        {gate.value}
      </span>
      <span className={`${styles.gateLimit} text-mono`}>{gate.limit}</span>
    </div>
  );
}

function FuelRow({ label, value, tone }: { label: string; value: string; tone?: StatusTone }) {
  return (
    <div className={styles.fuelRow}>
      <span className={styles.fuelLabel}>{label}</span>
      <span
        className={`${styles.fuelValue} text-mono`}
        style={tone ? { color: TONE_COLOR[tone] } : undefined}
      >
        {value}
      </span>
    </div>
  );
}

function AirportRow({
  airport,
  t,
}: {
  airport: NearbyAirport;
  t: (key: string, ...args: (string | number)[]) => string;
}) {
  return (
    <div className={styles.airportRow}>
      <div className={styles.airportHead}>
        <span className={`${styles.airportIcao} text-mono`}>{airport.icao}</span>
        <span className={styles.airportName}>{airport.name}</span>
        <span className={`${styles.airportDistance} text-mono`}>
          {airport.distanceNm.toFixed(0)} NM
        </span>
      </div>
      {airport.rawMetar ? (
        <>
          <div className={styles.metarChips}>
            <MetarChip icon="air" text={airport.windText} />
            <MetarChip icon="visibility" text={airport.visibilityText} />
            <MetarChip icon="thermostat" text={airport.temperatureText} />
            <MetarChip icon="compress" text={airport.altimeterText} />
          </div>
          {airport.freshness === 'stale' && (
            <span className={styles.staleHint}>{t(K.nearbyStale)}</span>
          )}
        </>
      ) : (
        <span className={styles.mutedText}>{t(K.nearbyNoMetar)}</span>
      )}
    </div>
  );
}

function MetarChip({ icon, text }: { icon: string; text?: string }) {
  if (!text || text === 'N/A') return null;
  return (
    <span className={styles.metarChip}>
      <MaterialIcon name={icon} size={13} color="var(--color-text-secondary)" />
      <span className="text-mono">{text}</span>
    </span>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 展示辅助
// ──────────────────────────────────────────────────────────────────────────

const GATE_STATUS_ICON: Record<GateStatus, string> = {
  ok: 'check_circle',
  watch: 'error',
  exceeded: 'cancel',
  unknown: 'help',
};

const GATE_STATUS_COLOR: Record<GateStatus, string> = {
  ok: 'var(--color-success)',
  watch: 'var(--color-warning)',
  exceeded: 'var(--color-error)',
  unknown: 'var(--color-text-secondary)',
};

const TONE_COLOR: Record<StatusTone, string> = {
  neutral: 'var(--color-text-secondary)',
  success: 'var(--color-success)',
  warning: 'var(--color-warning)',
  danger: 'var(--color-danger)',
  info: 'var(--color-primary)',
};

function fuelStatusTone(fuel: FuelMargin): StatusTone {
  switch (fuel.status) {
    case 'ok':
      return 'success';
    case 'watch':
      return 'warning';
    case 'critical':
      return 'danger';
    default:
      return 'neutral';
  }
}

function fuelStatusKey(fuel: FuelMargin): string {
  switch (fuel.status) {
    case 'ok':
      return K.fuelStatusOk;
    case 'watch':
      return K.fuelStatusWatch;
    case 'critical':
      return K.fuelStatusCritical;
    default:
      return K.fuelStatusUnknown;
  }
}

/** 数值缺失时显示占位符，绝不显示 0 —— 0 会被当成真实读数 */
function formatValue(value: number | undefined, digits: number, unit: string): string {
  if (value === undefined || !Number.isFinite(value)) return '—';
  return `${value.toFixed(digits)} ${unit}`;
}

function formatHours(hours: number | undefined): string {
  if (hours === undefined || !Number.isFinite(hours) || hours < 0) return '—';
  const whole = Math.floor(hours);
  const minutes = Math.round((hours - whole) * 60);
  // 59.6 分会进位成 60，得往小时上退一位，否则显示 "2:60"
  if (minutes === 60) return `${whole + 1}:00`;
  return `${whole}:${minutes.toString().padStart(2, '0')}`;
}

function formatClock(timestamp: number): string {
  return new Date(timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}
