import { useTranslate } from '../../../../core/localization/use-translate';
import { IconButton } from '../../../../core/widgets/common/controls';
import { MaterialIcon } from '../../../../core/widgets/common/icon';
import {
  DataCard,
  EmptyState,
  InfoChip,
  SectionCard,
} from '../../../../core/widgets/common/surfaces';
import type { FlightData, LiveMetarData } from '../../../common/models/common-models';
import { useFlightDataStore } from '../../../common/providers/flight-data-store';
import { HomeLocalizationKeys as K } from '../../localization/home-localization';
import styles from './flight-data-dashboard.module.css';

/**
 * 实时飞行数据仪表盘
 *
 * 对应 Flutter 版 `modules/home/pages/widgets/flight_data_dashboard.dart`
 * 及其 `dashboard/` 下的 5 个面板 + METAR 组件：
 *   primary_flight_data_panel / navigation_data_panel / environment_data_panel /
 *   engine_fuel_data_panel / system_status_panel / metar_display_widget
 */
export function FlightDataDashboard() {
  const t = useTranslate();
  const isConnected = useFlightDataStore((s) => s.snapshot.isConnected);

  if (!isConnected) {
    return (
      <SectionCard title={t(K.dashboardTitle)} icon="speed">
        <EmptyState
          icon="sensors_off"
          title={t(K.dashboardNoConnectionTitle)}
          description={t(K.dashboardNoConnectionSubtitle)}
        />
      </SectionCard>
    );
  }

  return (
    <div className={styles.dashboard}>
      <PrimaryFlightDataPanel />
      <div className={styles.panelGrid}>
        <NavigationDataPanel />
        <EnvironmentDataPanel />
        <EngineFuelDataPanel />
        <MetarDisplayPanel />
      </div>
      <SystemStatusPanel />
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 主飞行数据
// ──────────────────────────────────────────────────────────────────────────

function PrimaryFlightDataPanel() {
  const t = useTranslate();
  const data = useFlightDataStore((s) => s.snapshot.flightData);
  const isFuelSufficient = useFlightDataStore((s) => s.snapshot.isFuelSufficient);

  const fuelLabel =
    isFuelSufficient === undefined
      ? t(K.primaryFuelUnknown)
      : isFuelSufficient
        ? t(K.primaryFuelOk)
        : t(K.primaryFuelLow);
  const fuelColor =
    isFuelSufficient === undefined
      ? undefined
      : isFuelSufficient
        ? 'var(--color-success)'
        : 'var(--color-danger)';

  // 垂直速度上升为绿、下降为橙，与桌面版一致
  const vsColor =
    data.verticalSpeed === undefined
      ? undefined
      : data.verticalSpeed > 100
        ? 'var(--color-success)'
        : data.verticalSpeed < -100
          ? 'var(--color-warning)'
          : undefined;

  return (
    <SectionCard title={t(K.dashboardTitle)} icon="speed">
      <div className={styles.primaryGrid}>
        <DataCard
          label={t(K.primaryAirspeed)}
          value={fmt(data.airspeed, 0)}
          unit="kt"
          icon="air"
        />
        <DataCard
          label={t(K.primaryAltitude)}
          value={fmt(data.altitude, 0)}
          unit="ft"
          icon="height"
        />
        <DataCard
          label={t(K.primaryHeading)}
          value={fmt(data.heading, 0)}
          unit="°"
          icon="explore"
        />
        <DataCard
          label={t(K.primaryVerticalSpeed)}
          value={fmt(data.verticalSpeed, 0)}
          unit="fpm"
          icon="swap_vert"
          accentColor={vsColor}
        />
        <DataCard
          label={t(K.primaryFuelStatus)}
          value={fuelLabel}
          icon="local_gas_station"
          accentColor={fuelColor}
          hint={data.fuelQuantity !== undefined ? `${fmt(data.fuelQuantity, 0)} kg` : undefined}
        />
        {data.machNumber !== undefined && (
          <DataCard label="MACH" value={fmt(data.machNumber, 3)} icon="rocket_launch" />
        )}
      </div>
    </SectionCard>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 导航与位置
// ──────────────────────────────────────────────────────────────────────────

function NavigationDataPanel() {
  const t = useTranslate();
  const snapshot = useFlightDataStore((s) => s.snapshot);
  const data = snapshot.flightData;

  return (
    <SectionCard title={t(K.navTitle)} icon="explore">
      <div className={styles.panelGridInner}>
        <DataCard label={t(K.navGroundSpeed)} value={fmt(data.groundSpeed, 0)} unit="kt" />
        <DataCard label={t(K.navTrueAirspeed)} value={fmt(data.trueAirspeed, 0)} unit="kt" />
        <DataCard label={t(K.navLatitude)} value={fmt(data.latitude, 4)} unit="°" />
        <DataCard label={t(K.navLongitude)} value={fmt(data.longitude, 4)} unit="°" />
        <DataCard label={t(K.navAircraft)} value={data.aircraftDisplayName ?? '--'} />
        <DataCard label={t(K.navAircraftIcao)} value={data.aircraftIcao ?? '--'} />
        <DataCard
          label={t(K.navArrival)}
          value={snapshot.destinationAirport?.icaoCode ?? data.arrivalAirport ?? '--'}
        />
        <DataCard label={t(K.navCom1)} value={fmt(data.com1Frequency, 3)} unit="MHz" />
      </div>
    </SectionCard>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 环境数据
// ──────────────────────────────────────────────────────────────────────────

function EnvironmentDataPanel() {
  const t = useTranslate();
  const data = useFlightDataStore((s) => s.snapshot.flightData);

  const windText =
    data.windSpeed === undefined && data.windDirection === undefined
      ? '--'
      : `${fmt(data.windSpeed, 0)}kt / ${fmt(data.windDirection, 0)}°`;

  return (
    <SectionCard
      title={t(K.environmentTitle)}
      icon="thermostat"
      trailing={<WindDirectionIndicator data={data} />}
    >
      <div className={styles.panelGridInner}>
        <DataCard label={t(K.environmentOat)} value={fmt(data.outsideAirTemperature, 1)} unit="°C" />
        <DataCard label={t(K.environmentTat)} value={fmt(data.totalAirTemperature, 1)} unit="°C" />
        <DataCard label={t(K.environmentWind)} value={windText} />
        <DataCard
          label={t(K.environmentQnh)}
          value={fmt(data.baroPressure, 2)}
          unit={data.baroPressureUnit ?? 'inHg'}
        />
        <DataCard
          label={t(K.environmentVisibility)}
          value={formatVisibility(data.visibility)}
        />
        {data.crosswindComponent !== undefined && (
          <DataCard label="X-WIND" value={fmt(data.crosswindComponent, 0)} unit="kt" />
        )}
      </div>
    </SectionCard>
  );
}

/**
 * 风向指示器
 * 对应 Flutter 版 `modules/common/widgets/wind_direction_indicator.dart`
 */
function WindDirectionIndicator({ data }: { data: FlightData }) {
  if (data.windDirection === undefined) return null;
  // 风向为「风从哪来」，箭头指向风的去向，故 +180°；再减去机头朝向得到相对角
  const relative = data.windDirection + 180 - (data.heading ?? 0);
  return (
    <span className={styles.windIndicator} title={`${Math.round(data.windDirection)}°`}>
      <MaterialIcon
        name="navigation"
        filled
        size={16}
        color="var(--color-primary)"
        style={{ transform: `rotate(${relative}deg)` }}
      />
    </span>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 发动机与燃油
// ──────────────────────────────────────────────────────────────────────────

function EngineFuelDataPanel() {
  const t = useTranslate();
  const data = useFlightDataStore((s) => s.snapshot.flightData);

  return (
    <SectionCard title={t(K.engineTitle)} icon="local_gas_station">
      <div className={styles.panelGridInner}>
        <DataCard label={t(K.engineFob)} value={fmt(data.fuelQuantity, 0)} unit="kg" />
        <DataCard label={t(K.engineFf)} value={fmt(data.fuelFlow, 0)} unit="kg/h" />
        <DataCard
          label={t(K.engineEng1N1)}
          value={fmt(data.engine1N1, 1)}
          unit="%"
          accentColor={data.engine1Running ? 'var(--color-success)' : undefined}
        />
        <DataCard
          label={t(K.engineEng2N1)}
          value={fmt(data.engine2N1, 1)}
          unit="%"
          accentColor={data.engine2Running ? 'var(--color-success)' : undefined}
        />
        <DataCard label={t(K.engineEng1Egt)} value={fmt(data.engine1EGT, 0)} unit="°C" />
        <DataCard label={t(K.engineEng2Egt)} value={fmt(data.engine2EGT, 0)} unit="°C" />
      </div>
    </SectionCard>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// METAR
// ──────────────────────────────────────────────────────────────────────────

function MetarDisplayPanel() {
  const t = useTranslate();
  const snapshot = useFlightDataStore((s) => s.snapshot);
  const refreshMetar = useFlightDataStore((s) => s.refreshMetar);

  // 优先展示目的地，其次最近机场（与桌面版一致）
  const airport = snapshot.destinationAirport ?? snapshot.nearestAirport;
  const icao = airport?.icaoCode;
  const metar: LiveMetarData | undefined = icao ? snapshot.metarsByIcao[icao] : undefined;
  const error = icao ? snapshot.metarErrorsByIcao[icao] : undefined;
  const refreshing = icao ? snapshot.metarRefreshingIcaos.has(icao) : false;

  return (
    <SectionCard
      title={`${t(K.metarTitle)}${icao ? ` · ${icao}` : ''}`}
      icon="cloud"
      trailing={
        airport && (
          <IconButton
            icon="refresh"
            label={t(K.metarTitle)}
            disabled={refreshing}
            onClick={() => void refreshMetar(airport)}
          />
        )
      }
    >
      {!airport ? (
        <EmptyState icon="cloud_off" title="--" />
      ) : error ? (
        <div className={styles.metarError}>
          <MaterialIcon name="error" size={18} color="var(--color-error)" />
          <div>
            <div className={styles.metarErrorTitle}>{t(K.metarErrorTitle)}</div>
            <div className={styles.metarErrorText}>{error || t(K.metarErrorDefault)}</div>
          </div>
        </div>
      ) : !metar ? (
        <EmptyState icon="hourglass_empty" title={t(K.metarErrorDefault)} />
      ) : (
        <div className={styles.metarBody}>
          <p className={`${styles.metarRaw} text-mono`}>{metar.raw}</p>
          <div className={styles.metarChips}>
            <InfoChip icon="air" label={`${t(K.metarWind)} ${metar.displayWind}`} />
            <InfoChip icon="visibility" label={`${t(K.metarVisibility)} ${metar.displayVisibility}`} />
            <InfoChip icon="thermostat" label={`${t(K.metarTemperature)} ${metar.displayTemperature}`} />
            <InfoChip icon="compress" label={`${t(K.metarAltimeter)} ${metar.displayAltimeter}`} />
          </div>
          <span className={styles.metarUpdated}>
            {t(K.metarUpdatedAt, { time: formatTime(metar.timestamp) })}
          </span>
        </div>
      )}
    </SectionCard>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 系统状态
// ──────────────────────────────────────────────────────────────────────────

interface StatusItem {
  label: string;
  active: boolean | undefined;
  /** 激活即告警（火警/主警告等），用红色而非绿色 */
  danger?: boolean;
}

function SystemStatusPanel() {
  const t = useTranslate();
  const data = useFlightDataStore((s) => s.snapshot.flightData);

  const sections: { title: string; items: StatusItem[] }[] = [
    {
      title: t(K.systemSectionWarning),
      items: [
        { label: t(K.systemMasterWarning), active: data.masterWarning, danger: true },
        { label: t(K.systemMasterCaution), active: data.masterCaution, danger: true },
        { label: t(K.systemFireEngine1), active: data.fireWarningEngine1, danger: true },
        { label: t(K.systemFireEngine2), active: data.fireWarningEngine2, danger: true },
        { label: t(K.systemFireApu), active: data.fireWarningAPU, danger: true },
      ],
    },
    {
      title: t(K.systemSectionFlightControl),
      items: [
        { label: t(K.systemOnGround), active: data.onGround },
        { label: t(K.systemParkingBrake), active: data.parkingBrake },
        {
          label: t(K.systemSpeedBrake, { value: data.speedBrakeLabel ?? '' }).trim(),
          active: data.speedBrake,
        },
        { label: t(K.systemSpoilers), active: data.spoilersDeployed },
        {
          label: t(K.systemAutoBrake, { value: data.autoBrakeLabel ?? '' }).trim(),
          active: data.autoBrakeLabel !== undefined,
        },
      ],
    },
    {
      title: t(K.systemSectionGear),
      items: [
        { label: t(K.systemGear), active: data.gearDown },
        { label: t(K.systemNoseGear), active: gearRatioToBool(data.noseGearDown) },
        { label: t(K.systemLeftGear), active: gearRatioToBool(data.leftGearDown) },
        { label: t(K.systemRightGear), active: gearRatioToBool(data.rightGearDown) },
      ],
    },
    {
      title: t(K.systemSectionFlaps),
      items: [
        {
          label: t(K.systemFlaps, { value: data.flapsLabel ?? '' }).trim(),
          active: data.flapsDeployed,
        },
      ],
    },
    {
      title: t(K.systemSectionPower),
      items: [
        { label: t(K.systemApu), active: data.apuRunning },
        { label: t(K.systemEngineLeft), active: data.engine1Running },
        { label: t(K.systemEngineRight), active: data.engine2Running },
        { label: t(K.systemAutopilot), active: data.autopilotEngaged },
        { label: t(K.systemAutothrottle), active: data.autothrottleEngaged },
      ],
    },
    {
      title: t(K.systemSectionLights),
      items: [
        { label: t(K.systemBeacon), active: data.beacon },
        { label: t(K.systemStrobe), active: data.strobes },
        { label: t(K.systemNavLights), active: data.navLights },
        { label: t(K.systemLogoLights), active: data.logoLights },
        { label: t(K.systemWingLights), active: data.wingLights },
        { label: t(K.systemLandingLights), active: data.landingLights },
        { label: t(K.systemTaxiLights), active: data.taxiLights },
        { label: t(K.systemRunwayTurnoff), active: data.runwayTurnoffLights },
        { label: t(K.systemWheelWell), active: data.wheelWellLights },
      ],
    },
  ];

  return (
    <SectionCard title={t(K.systemTitle)} icon="settings_input_component">
      <div className={styles.systemSections}>
        {sections.map((section) => (
          <div key={section.title} className={styles.systemSection}>
            <span className={styles.systemSectionTitle}>{section.title}</span>
            <div className={styles.systemChips}>
              {section.items.map((item) => (
                <StatusPill key={item.label} item={item} />
              ))}
            </div>
          </div>
        ))}
      </div>
    </SectionCard>
  );
}

function StatusPill({ item }: { item: StatusItem }) {
  const isOn = item.active === true;
  const isUnknown = item.active === undefined;
  const color = isUnknown
    ? 'var(--color-text-secondary)'
    : isOn
      ? item.danger
        ? 'var(--color-danger)'
        : 'var(--color-success)'
      : 'var(--color-text-secondary)';

  return (
    <span
      className={[
        styles.statusPill,
        isOn ? styles.statusPillOn : '',
        isOn && item.danger ? styles.statusPillDanger : '',
      ]
        .filter(Boolean)
        .join(' ')}
      style={{ color }}
    >
      <span className={styles.statusPillDot} style={{ background: color }} />
      {item.label}
    </span>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 工具
// ──────────────────────────────────────────────────────────────────────────

/** 缺值统一渲染为 `--`（与桌面版一致） */
function fmt(value: number | undefined, digits: number): string {
  if (value === undefined || !Number.isFinite(value)) return '--';
  return value.toFixed(digits);
}

function formatVisibility(meters: number | undefined): string {
  if (meters === undefined) return '--';
  if (meters >= 10000) return '>10 km';
  if (meters >= 1000) return `${(meters / 1000).toFixed(1)} km`;
  return `${Math.round(meters)} m`;
}

function formatTime(date: Date): string {
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}

/** 起落架比例 → 布尔（≥0.5 视为放下） */
function gearRatioToBool(ratio: number | undefined): boolean | undefined {
  if (ratio === undefined) return undefined;
  const normalized = ratio > 1 && ratio <= 100 ? ratio / 100 : ratio;
  return normalized >= 0.5;
}
