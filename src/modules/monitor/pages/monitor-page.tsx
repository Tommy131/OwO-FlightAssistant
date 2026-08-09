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
import { MonitorChartBuffer, type ChartPoint, type MonitorData } from '../models/monitor-models';
import {
  effectiveGearRatio,
  resolveGearLayout,
  wheelsPerStrut,
  type GearLayout,
} from '../services/gear-layout';
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

        {/*
          * 上半区左右两栏：左栏是「磁航向 + 系统状态」竖排，右栏是起落架。
          * 起落架图是纵向构图（机头在上、主轮在下），配一个同样高的左栏
          * 才不会在它旁边留出一大片空白。
          */}
        {/*
          * 与 Flutter 版 monitor_page.dart 一致：
          * 等宽两栏，左栏竖排（罗盘在上、系统状态在下），右栏起落架。
          * 窄屏由 CSS 收成单列并隐藏起落架卡（Flutter 的 isCompact 分支同样不渲染它）。
          */}
        <div className={styles.topRow}>
          <div className={styles.topLeft}>
            <CompassSection heading={data.heading} />
            <SystemsStatusCard data={data} />
          </div>
          <div className={styles.topRowGear}>
            <LandingGearCard data={data} />
          </div>
        </div>
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

/**
 * 起落架状态卡片
 *
 * 还原 Flutter 版 `landing_gear_card.dart` 的仪表板构图：
 * 深色仿真面板、**前起居中在上／左右主起并排在下**（不是三个平铺）、
 * 红上绿下的灯盒（亮时带光晕）、中央轨道上按平均收放比例滑动的圆钮、
 * 底部速度限制铭牌。
 *
 * 在此之上补了机型仿真：轮组按当前机型画（747 四支主起、777 六轮小车、
 * 737/A320 双轮、通航单轮），固定起落架恒为放下 —— 收上对它们是不存在的状态。
 */
function LandingGearCard({ data }: { data: MonitorData }) {
  const t = useTranslate();
  const layout = useMemo(
    () => resolveGearLayout(data.aircraftIcao, data.aircraftTitle),
    [data.aircraftIcao, data.aircraftTitle],
  );

  const ratios = {
    nose: effectiveGearRatio(layout, data.noseGearDown),
    left: effectiveGearRatio(layout, data.leftGearDown),
    right: effectiveGearRatio(layout, data.rightGearDown),
  };
  const gears = [
    { key: 'nose', label: t(K.gearNoseLabel), status: gearStatus(ratios.nose) },
    { key: 'left', label: t(K.gearLeftLabel), status: gearStatus(ratios.left) },
    { key: 'right', label: t(K.gearRightLabel), status: gearStatus(ratios.right) },
  ] as const;

  const allDown = gears.every((gear) => gear.status === 2);
  const allUp = gears.every((gear) => gear.status === 0);
  const handleLabel = allDown
    ? t(K.gearPositionDown)
    : allUp
      ? t(K.gearPositionUp)
      : t(K.gearPositionOff);
  // 手柄位置取三组平均：0=最上（UP），1=最下（DN），与 Flutter 版一致
  const average = (ratios.nose + ratios.left + ratios.right) / 3;

  return (
    <SectionCard title={t(K.landingGearTitle)} icon="airline_seat_legroom_reduced">
      <div className={styles.gearPanel}>
        {/* 机型示意：前起在上、主起在下，轮组数量按机型画 */}
        <GearDiagram layout={layout} ratios={ratios} />

        <div className={styles.gearLights}>
          {/* 前起居中在上 */}
          <GearLightBox label={gears[0].label} status={gears[0].status} />
          {/* 左右主起并排在下 */}
          <div className={styles.gearMainRow}>
            <GearLightBox label={gears[1].label} status={gears[1].status} />
            <GearLightBox label={gears[2].label} status={gears[2].status} />
          </div>
        </div>

        <div className={styles.gearHandleWrap}>
          <span className={styles.gearHandleLabel}>{t(K.gearHandleLabel)}</span>
          <div className={styles.gearTrack}>
            <span className={styles.gearTrackTop}>{t(K.gearPositionUp)}</span>
            <span className={styles.gearTrackMid}>{t(K.gearPositionOff)}</span>
            <span className={styles.gearTrackBottom}>{t(K.gearPositionDown)}</span>
            {/* 固定起落架的手柄钉在 DN 且不可动 —— 那不是一个可操作的控制器 */}
            <span
              className={`${styles.gearKnob}${layout.retractable ? '' : ` ${styles.gearKnobLocked}`}`}
              style={{ top: `calc(${(average * 100).toFixed(1)}% - 25px)` }}
            />
          </div>
          <span className={styles.gearHandleValue}>{handleLabel}</span>
        </div>

        <div className={styles.gearLimit}>
          <span className={styles.gearLimitTitle}>{t(K.gearLimitTitle)}</span>
          <span className={styles.gearLimitContent}>{t(K.gearLimitContent)}</span>
        </div>
      </div>
    </SectionCard>
  );
}

/** 单组灯盒：上红（过渡中）下绿（放下），亮时带光晕 */
function GearLightBox({ label, status }: { label: string; status: 0 | 1 | 2 }) {
  return (
    <div className={styles.gearColumn}>
      <div
        className={`${styles.gearLight} ${styles.gearLightRed}${
          status === 1 ? ` ${styles.gearLightOn}` : ''
        }`}
      >
        {label}
      </div>
      <div
        className={`${styles.gearLight} ${styles.gearLightGreen}${
          status >= 1 ? ` ${styles.gearLightOn}` : ''
        }`}
      >
        {label}
      </div>
    </div>
  );
}

/**
 * 机型起落架示意图
 *
 * 俯视构图：机头朝上，前起在中轴线上，主起对称分列两侧。
 * 支柱随收放比例上抬/落下，收上后轮组淡出 —— 让"正在收放"这个过程看得见，
 * 而不是只有灯在闪。
 */
function GearDiagram({
  layout,
  ratios,
}: {
  layout: GearLayout;
  ratios: { nose: number; left: number; right: number };
}) {
  const wheels = wheelsPerStrut(layout.bogie);
  // 747/A380 的四支主起：机身两支在内、机翼两支在外
  const mainSides = layout.mainStruts >= 4 ? ['outer', 'inner', 'inner', 'outer'] : ['x', 'x'];

  return (
    <div className={styles.gearDiagram}>
      <div className={styles.gearDiagramBody} />

      <GearStrut wheels={layout.noseWheels} ratio={ratios.nose} className={styles.gearStrutNose} />

      <div className={styles.gearMainStruts}>
        {mainSides.map((side, index) => {
          const isLeft = index < mainSides.length / 2;
          return (
            <GearStrut
              key={`${side}-${index}`}
              wheels={wheels}
              ratio={isLeft ? ratios.left : ratios.right}
              className={side === 'inner' ? styles.gearStrutInner : undefined}
            />
          );
        })}
      </div>

      <span className={styles.gearDiagramSource}>{layout.source}</span>
    </div>
  );
}

/** 一支起落架：支柱 + 机轮，随收放比例改变高度与不透明度 */
function GearStrut({
  wheels,
  ratio,
  className,
}: {
  wheels: number;
  ratio: number;
  className?: string;
}) {
  return (
    <div
      className={`${styles.gearStrut}${className ? ` ${className}` : ''}`}
      style={{ opacity: 0.25 + ratio * 0.75 }}
    >
      {/* 支柱长度随收放比例伸缩：收上时缩进机身 */}
      <span className={styles.gearLeg} style={{ height: `${6 + ratio * 14}px` }} />
      <span className={styles.gearWheels}>
        {Array.from({ length: wheels }, (_, index) => (
          <span key={index} className={styles.gearWheel} />
        ))}
      </span>
    </div>
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
        currentTime={data.chartData.currentTime}
        data={data.chartData.gForceSpots}
        color={chartColor('orange', isDark)}
        isDark={isDark}
      />
      <MonitorChartCard
        title={t(K.chartAltitudeTitle)}
        value={data.altitude}
        unit={t(K.unitFt)}
        digits={0}
        currentTime={data.chartData.currentTime}
        data={data.chartData.altitudeSpots}
        color={primaryColor}
        isDark={isDark}
      />
      <MonitorChartCard
        title={t(K.chartBaroTitle)}
        value={data.baroPressure}
        unit={t(K.unitInHg)}
        digits={2}
        currentTime={data.chartData.currentTime}
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
  currentTime,
  color,
  isDark,
}: {
  title: string;
  value?: number;
  unit: string;
  digits: number;
  data: ChartPoint[];
  currentTime: number;
  color: string;
  isDark: boolean;
}) {
  // 单系列图表不需要图例：标题已经指明了系列身份
  const option = useMemo(
    () => {
      const base = baseChartOption({
        isDark,
        showYAxisLabel: true,
        grid: { left: 42, right: 10 },
      });
      return {
        ...base,
        /*
         * x 轴必须**显式锁成固定宽度的时间窗**。
         *
         * 缓冲区攒满前只有几个点，ECharts 按数据范围自适应轴：
         * 每来一个新点，轴的跨度就变一次，已经画好的那截波形跟着被重新
         * 映射到别的位置 —— 看上去就是整条曲线在往右挪，而不是新数据
         * 从右边进、旧数据从左边出。
         * 把窗口钉死在 [当前时刻 - 缓冲长度, 当前时刻] 之后，
         * 横轴的物理含义恒定，曲线才会像纸带记录仪那样向左滚。
         */
        xAxis: {
          ...(base.xAxis as object),
          min: currentTime - MonitorChartBuffer.maxPoints,
          max: currentTime,
        },
        series: lineSeries({ name: title, data, color }),
      };
    },
    [data, currentTime, color, isDark, title],
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
