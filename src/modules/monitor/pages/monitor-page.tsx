import { useEffect, useMemo } from 'react';
import { useTranslate } from '../../../core/localization/use-translate';
import { NavigationCommandBus } from '../../../core/module-registry/navigation/navigation-registry';
import { useIsDarkMode, useThemeStore } from '../../../core/theme/theme-store';
import {
  baseChartOption,
  chartColor,
  EChart,
  lineSeries,
} from '../../../core/widgets/common/echart';
import { Button } from '../../../core/widgets/common/controls';
import { MaterialIcon } from '../../../core/widgets/common/icon';
import { Card, SectionCard, StatusBadge } from '../../../core/widgets/common/surfaces';
import { MonitorLocalizationKeys as K } from '../localization/monitor-localization';
import type { ChartPoint, MonitorData } from '../models/monitor-models';
import { flushPendingMonitorData, useMonitorStore } from '../providers/monitor-store';
import styles from './monitor-page.module.css';

/**
 * 实时监控页面
 *
 * 对应 Flutter 版 `modules/monitor/pages/monitor_page.dart` 及 widgets/ 下 10 个组件：
 * 告警横幅 + 航向罗盘 + 系统状态 + 交互式起落架面板 + 三张趋势图。
 */
export function MonitorPage() {
  const data = useMonitorStore((s) => s.data);
  const loadPerformanceSettings = useMonitorStore((s) => s.loadPerformanceSettings);

  useEffect(() => {
    void loadPerformanceSettings();
    // 离开页面时把被限流挡下的最后一帧补上，避免图表停在旧窗口
    return () => flushPendingMonitorData();
  }, [loadPerformanceSettings]);

  if (!data.isConnected) return <NoConnectionView />;

  return (
    <div className={`${styles.page} scroll-area`}>
      <div className={styles.content}>
        <MonitorHeader data={data} />
        <WarningBanner data={data} />

        <div className={styles.topRow}>
          <CompassSection heading={data.heading} />
          <SystemsStatusCard data={data} />
        </div>

        <LandingGearCard data={data} />
        <MonitorCharts data={data} />
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 头部与告警
// ──────────────────────────────────────────────────────────────────────────

function MonitorHeader({ data }: { data: MonitorData }) {
  const t = useTranslate();
  return (
    <div className={styles.header}>
      <div className={styles.headerText}>
        <h2 className={styles.headerTitle}>{t(K.pageTitle)}</h2>
        <span className={styles.headerSubtitle}>
          {data.isConnected ? t(K.pageSubtitleConnected) : t(K.pageSubtitleDisconnected)}
        </span>
      </div>
      {data.isPaused === true && (
        <StatusBadge label={t(K.pausedLabel)} tone="warning" pulsing />
      )}
    </div>
  );
}

function WarningBanner({ data }: { data: MonitorData }) {
  const t = useTranslate();
  const warnings: { label: string; tone: 'danger' | 'warning' }[] = [];

  if (data.masterWarning === true) {
    warnings.push({ label: t(K.masterWarningMessage), tone: 'danger' });
  }
  if (data.masterCaution === true) {
    warnings.push({ label: t(K.masterCautionMessage), tone: 'warning' });
  }
  if (data.fireWarningEngine1 === true) {
    warnings.push({ label: `${t(K.fireEngine1)} ${t(K.fireSuffix)}`, tone: 'danger' });
  }
  if (data.fireWarningEngine2 === true) {
    warnings.push({ label: `${t(K.fireEngine2)} ${t(K.fireSuffix)}`, tone: 'danger' });
  }
  if (data.fireWarningAPU === true) {
    warnings.push({ label: `${t(K.fireApu)} ${t(K.fireSuffix)}`, tone: 'danger' });
  }

  if (warnings.length === 0) return null;

  return (
    <div className={styles.warningStack}>
      {warnings.map((warning) => (
        <div
          key={warning.label}
          className={`${styles.warningBanner} ${
            warning.tone === 'danger' ? styles.warningDanger : styles.warningCaution
          }`}
        >
          <MaterialIcon name="warning" filled size={19} />
          <span>{warning.label}</span>
        </div>
      ))}
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 航向罗盘
// ──────────────────────────────────────────────────────────────────────────

function CompassSection({ heading }: { heading?: number }) {
  const t = useTranslate();
  const value = heading ?? 0;
  // 刻度环反向旋转，使当前航向始终朝上
  const ringRotation = -value;

  return (
    <SectionCard title={t(K.compassTitle)} icon="explore">
      <div className={styles.compassWrap}>
        <div className={styles.compass}>
          <div className={styles.compassRing} style={{ transform: `rotate(${ringRotation}deg)` }}>
            {COMPASS_TICKS.map((tick) => (
              <div
                key={tick.deg}
                className={tick.major ? styles.compassTickMajor : styles.compassTick}
                style={{ transform: `rotate(${tick.deg}deg)` }}
              >
                {tick.label && (
                  <span
                    className={styles.compassLabel}
                    // 标签反向旋转保持水平可读
                    style={{ transform: `rotate(${-tick.deg - ringRotation}deg)` }}
                  >
                    {tick.label}
                  </span>
                )}
              </div>
            ))}
          </div>

          {/* 固定指针 + 中心读数 */}
          <div className={styles.compassNeedle} />
          <div className={styles.compassReadout}>
            <span className={`${styles.compassValue} text-mono`}>
              {String(Math.round(value) % 360).padStart(3, '0')}
            </span>
            <span className={styles.compassUnit}>°</span>
          </div>
        </div>
      </div>
    </SectionCard>
  );
}

/** 每 30° 一个刻度，四个基本方位带字母标签 */
const COMPASS_TICKS = Array.from({ length: 12 }, (_, index) => {
  const deg = index * 30;
  const labels: Record<number, string> = { 0: 'N', 90: 'E', 180: 'S', 270: 'W' };
  return { deg, major: deg % 90 === 0, label: labels[deg] };
});

// ──────────────────────────────────────────────────────────────────────────
// 系统状态
// ──────────────────────────────────────────────────────────────────────────

function SystemsStatusCard({ data }: { data: MonitorData }) {
  const t = useTranslate();

  const rows: { label: string; value: string; tone?: 'danger' | 'warning' | 'success' }[] = [
    {
      label: t(K.parkingBrakeLabel),
      value: data.parkingBrake === true ? t(K.parkingBrakeSet) : t(K.parkingBrakeReleased),
      tone: data.parkingBrake === true ? 'warning' : undefined,
    },
    {
      label: t(K.transponderLabel),
      value:
        data.transponderCode && data.transponderCode.length > 0
          ? `${data.transponderCode}${data.transponderState ? ` · ${data.transponderState}` : ''}`
          : t(K.transponderEmpty),
    },
    {
      label: t(K.flapsLabel),
      value: data.flapsLabel ?? t(K.flapsUp),
    },
    {
      label: t(K.speedBrakeLabel),
      value: data.speedBrakeLabel ?? t(K.speedBrakeUnknown),
      tone: data.speedBrake === true ? 'warning' : undefined,
    },
  ];

  return (
    <SectionCard title={t(K.systemsTitle)} icon="settings_input_component">
      <div className={styles.systemRows}>
        {rows.map((row) => (
          <div key={row.label} className={styles.systemRow}>
            <span className={styles.systemLabel}>{row.label}</span>
            <span
              className={`${styles.systemValue} text-mono`}
              style={row.tone ? { color: `var(--color-${row.tone})` } : undefined}
            >
              {row.value}
            </span>
          </div>
        ))}
      </div>
    </SectionCard>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 起落架面板
// ──────────────────────────────────────────────────────────────────────────

/** 0 = 收上；1 = 运动中（红+绿同亮）；2 = 放下锁定（绿亮） */
function gearStatus(ratio: number | undefined): 0 | 1 | 2 {
  if (ratio === undefined) return 0;
  const normalized = ratio > 1 && ratio <= 100 ? ratio / 100 : ratio;
  if (normalized <= 0.02) return 0;
  if (normalized >= 0.98) return 2;
  return 1;
}

function LandingGearCard({ data }: { data: MonitorData }) {
  const t = useTranslate();

  const gears = [
    { label: t(K.gearNoseLabel), status: gearStatus(data.noseGearDown) },
    { label: t(K.gearLeftLabel), status: gearStatus(data.leftGearDown) },
    { label: t(K.gearRightLabel), status: gearStatus(data.rightGearDown) },
  ];

  // 三个都放下锁定 → 手柄在 DOWN；都收上 → UP；否则 OFF（过渡）
  const allDown = gears.every((gear) => gear.status === 2);
  const allUp = gears.every((gear) => gear.status === 0);
  const handlePosition = allDown ? 'down' : allUp ? 'up' : 'off';
  const handleLabel = allDown
    ? t(K.gearPositionDown)
    : allUp
      ? t(K.gearPositionUp)
      : t(K.gearPositionOff);

  return (
    <SectionCard title={t(K.landingGearTitle)} icon="airline_seat_legroom_reduced">
      <div className={styles.gearPanel}>
        <div className={styles.gearLights}>
          {gears.map((gear) => (
            <div key={gear.label} className={styles.gearColumn}>
              <span className={styles.gearLabel}>{gear.label}</span>
              {/* status==1 红灯亮（运动中）；status>=1 绿灯亮 */}
              <div
                className={`${styles.gearLight} ${styles.gearLightRed}${
                  gear.status === 1 ? ` ${styles.gearLightOn}` : ''
                }`}
              >
                UNLK
              </div>
              <div
                className={`${styles.gearLight} ${styles.gearLightGreen}${
                  gear.status >= 1 ? ` ${styles.gearLightOn}` : ''
                }`}
              >
                DOWN
              </div>
            </div>
          ))}
        </div>

        <div className={styles.gearHandleWrap}>
          <span className={styles.gearHandleLabel}>{t(K.gearHandleLabel)}</span>
          <div className={`${styles.gearHandle} ${styles[`gearHandle_${handlePosition}`]}`}>
            <span className={styles.gearHandleKnob} />
          </div>
          <span className={styles.gearHandleValue}>{handleLabel}</span>
        </div>
      </div>
    </SectionCard>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 趋势图
// ──────────────────────────────────────────────────────────────────────────

function MonitorCharts({ data }: { data: MonitorData }) {
  const t = useTranslate();
  const isDark = useIsDarkMode();
  // 高度图沿用桌面版的 colorScheme.primary，随用户所选主题走
  const primaryColor = useThemeStore((s) => s.currentTheme.primaryColor);

  return (
    <div className={styles.chartGrid}>
      <MonitorChartCard
        title={t(K.chartGForceTitle)}
        value={data.gForce}
        unit={t(K.unitG)}
        digits={2}
        data={data.chartData.gForceSpots}
        color={chartColor('orange', isDark)}
        isDark={isDark}
      />
      <MonitorChartCard
        title={t(K.chartAltitudeTitle)}
        value={data.altitude}
        unit={t(K.unitFt)}
        digits={0}
        data={data.chartData.altitudeSpots}
        color={primaryColor}
        isDark={isDark}
      />
      <MonitorChartCard
        title={t(K.chartBaroTitle)}
        value={data.baroPressure}
        unit={t(K.unitInHg)}
        digits={2}
        data={data.chartData.pressureSpots}
        color={chartColor('aqua', isDark)}
        isDark={isDark}
      />
    </div>
  );
}

function MonitorChartCard({
  title,
  value,
  unit,
  digits,
  data,
  color,
  isDark,
}: {
  title: string;
  value?: number;
  unit: string;
  digits: number;
  data: ChartPoint[];
  color: string;
  isDark: boolean;
}) {
  // 单系列图表不需要图例：标题已经指明了系列身份
  const option = useMemo(
    () => ({
      ...baseChartOption({ isDark, showYAxisLabel: true, grid: { left: 42, right: 10 } }),
      series: lineSeries({ name: title, data, color }),
    }),
    [data, color, isDark, title],
  );

  return (
    <Card className={styles.chartCard} padding="0">
      <div className={styles.chartHead}>
        <span className={styles.chartTitle}>{title}</span>
        {/* 当前值徽章即为「relief」：颜色对比度不足的主题下仍有可读数值 */}
        <span
          className={`${styles.chartValue} text-mono`}
          style={{ color, background: `${color}1a` }}
        >
          {value === undefined ? '--' : value.toFixed(digits)} {unit}
        </span>
      </div>
      <EChart option={option} height={132} streaming />
    </Card>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 未连接占位
// ──────────────────────────────────────────────────────────────────────────

function NoConnectionView() {
  const t = useTranslate();
  const steps = [t(K.noConnectionStepHome), t(K.noConnectionStepConnect), t(K.noConnectionStepStart)];

  return (
    <div className={styles.emptyPage}>
      <div className={styles.emptyCard}>
        <MaterialIcon name="monitor_heart" size={44} color="var(--color-on-surface-a40)" />
        <h2 className={styles.emptyTitle}>{t(K.noConnectionTitle)}</h2>
        <p className={styles.emptySubtitle}>{t(K.noConnectionSubtitle)}</p>

        <ol className={styles.emptySteps}>
          {steps.map((step, index) => (
            <li key={step} className={styles.emptyStep}>
              <span className={styles.emptyStepIndex}>{index + 1}</span>
              {step}
            </li>
          ))}
        </ol>

        <Button
          variant="elevated"
          icon="home"
          onClick={() => NavigationCommandBus.goTo('home')}
        >
          {t(K.noConnectionStepHome)}
        </Button>
      </div>
    </div>
  );
}
