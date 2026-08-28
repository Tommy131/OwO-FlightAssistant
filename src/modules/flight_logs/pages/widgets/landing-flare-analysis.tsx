import { useMemo, useState } from 'react';

import { useTranslate } from '../../../../core/localization/use-translate';
import { Switch } from '../../../../core/widgets/common/controls';
import { MaterialIcon } from '../../../../core/widgets/common/icon';
import { EmptyState } from '../../../../core/widgets/common/surfaces';
import { FlightLogsLocalizationKeys as K } from '../../localization/flight-logs-localization';
import type { FlightLog } from '../../models/flight-log-models';
import {
  buildLandingFlareProfile,
  type LandingFlareSample,
} from '../../services/landing-flare-profile';
import styles from './landing-flare-analysis.module.css';

const CHART_WIDTH = 1000;
const CHART_HEIGHT = 240;
const PLOT = { left: 72, right: 22, top: 20, bottom: 38 } as const;

export function LandingFlareAnalysis({ log }: { log: FlightLog }) {
  const t = useTranslate();
  const samples = useMemo(() => buildLandingFlareProfile(log), [log]);
  const [zeroAtBottom, setZeroAtBottom] = useState(false);

  if (samples.length === 0) {
    return (
      <div className={styles.emptyCard}>
        <EmptyState
          icon="flight_land"
          title={t(K.flareNoLandingTitle)}
          description={t(K.flareNoLandingDescription)}
        />
      </div>
    );
  }

  const touchdown = samples[samples.length - 1];
  const start = samples.find((sample) => sample.verticalSpeed !== undefined);
  const reduction =
    start?.verticalSpeed !== undefined && touchdown.verticalSpeed !== undefined
      ? touchdown.verticalSpeed - start.verticalSpeed
      : undefined;

  return (
    <section className={styles.panel} aria-labelledby="landing-flare-title">
      <header className={styles.header}>
        <div className={styles.titleIcon} aria-hidden="true">
          <MaterialIcon name="airline_stops" size={22} filled />
        </div>
        <div className={styles.heading}>
          <span className={styles.eyebrow}>-10s / TD</span>
          <h2 id="landing-flare-title">{t(K.flareTitle)}</h2>
          <p>{t(K.flareSubtitle)}</p>
        </div>
        <div className={styles.readouts}>
          <Readout
            label={t(K.flareTouchdown)}
            value={formatNumber(touchdown.verticalSpeed, 0)}
            unit="fpm"
            accent
          />
          <Readout
            label={t(K.flareSinkReduction)}
            value={formatSigned(reduction)}
            unit="fpm"
          />
        </div>
      </header>

      <div className={styles.chartWrap}>
        <div className={styles.chartControls}>
          <span>{t(K.flareAxisZeroAtBottom)}</span>
          <Switch
            checked={zeroAtBottom}
            onChange={setZeroAtBottom}
            label={t(K.flareAxisZeroAtBottom)}
          />
        </div>
        <FlareCurve samples={samples} zeroAtBottom={zeroAtBottom} />
      </div>

      <div className={styles.recorderStrip} aria-hidden="true">
        <span>FDR // FINAL APPROACH</span>
        <span>-10S / TD</span>
      </div>

      <div className={styles.tableWrap}>
        <table className={styles.table}>
          <caption className="sr-only">{t(K.flareTitle)}</caption>
          <thead>
            <tr>
              <th scope="col"><abbr title={t(K.flareSecondsBeforeTouchdown)}>T-</abbr></th>
              <th scope="col"><abbr title={t(K.heading)}>HDG</abbr></th>
              <th scope="col"><abbr title={t(K.flareRadioAltitude)}>RALT</abbr></th>
              <th scope="col"><abbr title={t(K.pitch)}>PITCH</abbr></th>
              <th scope="col"><abbr title={t(K.flareRoll)}>ROLL</abbr></th>
              <th scope="col"><abbr title={t(K.verticalSpeed)}>IVV</abbr></th>
              <th scope="col"><abbr title={t(K.flareVerticalAcceleration)}>VACC</abbr></th>
              <th scope="col"><abbr title={t(K.flareCalibratedAirspeed)}>CAS</abbr></th>
              <th scope="col"><abbr title={`${t(K.flareEngineN1)} 1`}>N1 L</abbr></th>
              <th scope="col"><abbr title={`${t(K.flareEngineN1)} 2`}>N1 R</abbr></th>
              <th scope="col"><abbr title={t(K.flareGroundAir)}>GND/AIR</abbr></th>
            </tr>
          </thead>
          <tbody>
            {samples.map((sample) => (
              <tr
                key={sample.secondsBeforeTouchdown}
                className={sample.secondsBeforeTouchdown === 0 ? styles.touchdownRow : undefined}
              >
                <td className={styles.timeCell}>
                  {sample.secondsBeforeTouchdown === 0
                    ? 'TD'
                    : `-${sample.secondsBeforeTouchdown}s`}
                </td>
                <td className="text-mono">{formatHeading(sample.heading)}</td>
                <td className="text-mono">{formatNumber(sample.radioAltitude, 0)}</td>
                <td className="text-mono">{formatNumber(sample.pitch, 1)}</td>
                <td className="text-mono">{formatNumber(sample.roll, 1)}</td>
                <td className={`${styles.sinkCell} text-mono`}>
                  <span>{formatNumber(sample.verticalSpeed, 0)}</span>
                </td>
                <td className="text-mono">{formatNumber(sample.gForce, 2)}</td>
                <td className="text-mono">{formatNumber(sample.airspeed, 0)}</td>
                <td className="text-mono">{formatNumber(sample.engine1N1, 1)}</td>
                <td className="text-mono">{formatNumber(sample.engine2N1, 1)}</td>
                <td className={`${styles.stateCell} text-mono`}>
                  {formatGroundState(sample.onGround)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <dl className={styles.legend} aria-label={t(K.flareLegend)}>
        <div><dt>HDG</dt><dd>{t(K.heading)}</dd></div>
        <div><dt>RALT</dt><dd>{t(K.flareRadioAltitude)}</dd></div>
        <div><dt>IVV</dt><dd>{t(K.verticalSpeed)}</dd></div>
        <div><dt>VACC</dt><dd>{t(K.flareVerticalAcceleration)}</dd></div>
        <div><dt>CAS</dt><dd>{t(K.flareCalibratedAirspeed)}</dd></div>
        <div><dt>N1</dt><dd>{t(K.flareEngineN1)}</dd></div>
        <div><dt>GND/AIR</dt><dd>{t(K.flareGroundAir)}</dd></div>
      </dl>
    </section>
  );
}

function FlareCurve({
  samples,
  zeroAtBottom,
}: {
  samples: readonly LandingFlareSample[];
  zeroAtBottom: boolean;
}) {
  const t = useTranslate();
  const [activeIndex, setActiveIndex] = useState<number>();
  const values = samples
    .map((sample) => sample.verticalSpeed)
    .filter((value): value is number => value !== undefined && Number.isFinite(value));

  if (values.length === 0) {
    return <EmptyState icon="show_chart" title={t(K.chartNoData)} />;
  }

  const minimum = Math.min(...values, -100);
  const maximum = Math.max(...values, 0);
  const range = Math.max(1, maximum - minimum);
  const plotWidth = CHART_WIDTH - PLOT.left - PLOT.right;
  const plotHeight = CHART_HEIGHT - PLOT.top - PLOT.bottom;
  const xAt = (index: number) => PLOT.left + (index / (samples.length - 1)) * plotWidth;
  const yAt = (value: number) => zeroAtBottom
    ? PLOT.top + ((value - minimum) / range) * plotHeight
    : PLOT.top + ((maximum - value) / range) * plotHeight;
  const gridValues = Array.from({ length: 5 }, (_, index) => maximum - (range * index) / 4);
  const activeSample = activeIndex === undefined ? undefined : samples[activeIndex];
  const activeValue = activeSample?.verticalSpeed;
  const activeX = activeIndex === undefined ? undefined : xAt(activeIndex);
  const activeY = activeValue === undefined ? undefined : yAt(activeValue);

  const selectNearestSample = (clientX: number, chart: SVGSVGElement) => {
    const bounds = chart.getBoundingClientRect();
    if (!Number.isFinite(clientX) || bounds.width <= 0) return;

    const scale = Math.min(bounds.width / CHART_WIDTH, bounds.height / CHART_HEIGHT);
    if (!Number.isFinite(scale) || scale <= 0) return;
    const horizontalOffset = (bounds.width - CHART_WIDTH * scale) / 2;
    const chartX = (clientX - bounds.left - horizontalOffset) / scale;
    let nearestIndex: number | undefined;
    let nearestDistance = Number.POSITIVE_INFINITY;

    samples.forEach((sample, index) => {
      if (sample.verticalSpeed === undefined || !Number.isFinite(sample.verticalSpeed)) return;
      const distance = Math.abs(chartX - xAt(index));
      if (distance < nearestDistance) {
        nearestIndex = index;
        nearestDistance = distance;
      }
    });

    setActiveIndex(nearestIndex);
  };

  let path = '';
  samples.forEach((sample, index) => {
    const value = sample.verticalSpeed;
    if (value === undefined || !Number.isFinite(value)) return;
    const command = index > 0 && samples[index - 1].verticalSpeed !== undefined ? 'L' : 'M';
    path += `${command}${xAt(index).toFixed(1)},${yAt(value).toFixed(1)} `;
  });

  return (
    <svg
      className={styles.chart}
      viewBox={`0 0 ${CHART_WIDTH} ${CHART_HEIGHT}`}
      preserveAspectRatio="xMidYMid meet"
      role="img"
      aria-label={t(K.flareTitle)}
      onPointerMove={(event) => selectNearestSample(event.clientX, event.currentTarget)}
      onClick={(event) => selectNearestSample(event.clientX, event.currentTarget)}
      onPointerLeave={() => setActiveIndex(undefined)}
    >
      {gridValues.map((value) => (
        <g key={value}>
          <line
            x1={PLOT.left}
            x2={CHART_WIDTH - PLOT.right}
            y1={yAt(value)}
            y2={yAt(value)}
            className={styles.gridLine}
          />
          <text x={PLOT.left - 12} y={yAt(value) + 4} className={styles.axisLabel}>
            {Math.round(value)}
          </text>
        </g>
      ))}
      <path d={path} className={styles.curveGlow} />
      <path d={path} className={styles.curve} />
      {samples.map((sample, index) => {
        const value = sample.verticalSpeed;
        if (value === undefined) return null;
        const touchdown = sample.secondsBeforeTouchdown === 0;
        return (
          <g key={sample.secondsBeforeTouchdown}>
            <circle
              cx={xAt(index)}
              cy={yAt(value)}
              r={touchdown ? 6 : 3.5}
              className={touchdown ? styles.touchdownPoint : styles.curvePoint}
            />
            <text x={xAt(index)} y={CHART_HEIGHT - 12} className={styles.xLabel}>
              {touchdown ? 'TD' : `-${sample.secondsBeforeTouchdown}`}
            </text>
          </g>
        );
      })}
      {activeSample && activeValue !== undefined && activeX !== undefined && activeY !== undefined && (
        <g className={styles.cursorReadout} data-testid="flare-cursor-readout">
          <line
            x1={activeX}
            x2={activeX}
            y1={PLOT.top}
            y2={CHART_HEIGHT - PLOT.bottom}
            className={styles.cursorLine}
          />
          <circle cx={activeX} cy={activeY} r={6.5} className={styles.cursorPoint} />
          <g
            transform={`translate(${tooltipX(activeX)}, ${tooltipY(activeY)})`}
            className={styles.cursorTooltip}
          >
            <rect width={142} height={42} rx={5} />
            <text x={10} y={16} className={styles.cursorTime}>
              {formatCursorTime(activeSample.secondsBeforeTouchdown)}
            </text>
            <text x={10} y={31} className={styles.cursorValue}>
              IVV {formatNumber(activeValue, 0)} fpm
            </text>
          </g>
        </g>
      )}
      <text x={14} y={18} className={styles.unitLabel}>fpm</text>
    </svg>
  );
}

function tooltipX(pointX: number): number {
  return pointX > CHART_WIDTH - PLOT.right - 156 ? pointX - 154 : pointX + 12;
}

function tooltipY(pointY: number): number {
  return pointY < PLOT.top + 54 ? pointY + 12 : pointY - 52;
}

function formatCursorTime(secondsBeforeTouchdown: number): string {
  return secondsBeforeTouchdown === 0 ? 'TD' : `T-${secondsBeforeTouchdown}s`;
}

function Readout({
  label,
  value,
  unit,
  accent = false,
}: {
  label: string;
  value: string;
  unit: string;
  accent?: boolean;
}) {
  return (
    <div className={`${styles.readout}${accent ? ` ${styles.readoutAccent}` : ''}`}>
      <span>{label}</span>
      <strong className="text-mono">{value}</strong>
      <small>{unit}</small>
    </div>
  );
}

function formatNumber(value: number | undefined, digits: number): string {
  return value !== undefined && Number.isFinite(value) ? value.toFixed(digits) : '--';
}

function formatSigned(value: number | undefined): string {
  if (value === undefined || !Number.isFinite(value)) return '--';
  return `${value >= 0 ? '+' : ''}${value.toFixed(0)}`;
}

function formatHeading(value: number | undefined): string {
  if (value === undefined || !Number.isFinite(value)) return '--';
  const normalized = ((value % 360) + 360) % 360;
  return Math.round(normalized).toString().padStart(3, '0');
}

function formatGroundState(value: boolean | undefined): string {
  if (value === undefined) return '--';
  return value ? 'GND' : 'AIR';
}
