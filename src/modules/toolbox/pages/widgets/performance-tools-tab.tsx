import { useEffect, useState } from 'react';
import { useTranslate } from '../../../../core/localization/use-translate';
import { AppLogger } from '../../../../core/utils/logger';
import { toDouble, toJsonMap, type JsonMap } from '../../../../core/utils/parse-utils';
import { Button, Checkbox, Select, TextField } from '../../../../core/widgets/common/controls';
import { SectionCard } from '../../../../core/widgets/common/surfaces';
import {
  extractErrorMessage,
  MiddlewareHttpException,
} from '../../../http/models/http-models';
import { MiddlewareHttpService } from '../../../http/services/middleware-http-service';
import { ToolboxLocalizationKeys as K } from '../../localization/toolbox-localization';
import { parseNumber, ResultBlock } from './flight-calculators-tab';
import styles from './toolbox-tabs.module.css';

/**
 * 性能工具
 *
 * 对应 Flutter 版 `modules/toolbox/pages/widgets/performance_tools_tab.dart`：
 * 载重平衡（本地计算）+ 跑道性能（调后端 `/api/v1/performance/calculate`）。
 */
export function PerformanceToolsTab() {
  return (
    <div className={styles.tab}>
      <WeightAndBalanceCard />
      <RunwayPerformanceCard />
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 载重平衡
// ──────────────────────────────────────────────────────────────────────────

function WeightAndBalanceCard() {
  const t = useTranslate();
  const [fields, setFields] = useState({
    bew: '42500',
    bewArm: '16.5',
    frontWeight: '3600',
    frontArm: '12.0',
    rearWeight: '4200',
    rearArm: '20.0',
    cargoWeight: '2500',
    cargoArm: '22.0',
    fuelWeight: '9000',
    fuelArm: '17.0',
    mtow: '73500',
    cgForward: '14.0',
    cgAft: '20.5',
  });
  const [result, setResult] = useState<string | null>(null);

  const update = (key: keyof typeof fields) => (value: string) =>
    setFields((prev) => ({ ...prev, [key]: value }));

  const calculate = () => {
    const values = Object.fromEntries(
      Object.entries(fields).map(([key, value]) => [key, parseNumber(value)]),
    ) as Record<keyof typeof fields, number | null>;

    if (Object.values(values).some((value) => value === null)) {
      setResult(t(K.commonInvalidNumber));
      return;
    }

    const totalWeight =
      values.bew! + values.frontWeight! + values.rearWeight! + values.cargoWeight! + values.fuelWeight!;
    const totalMoment =
      values.bew! * values.bewArm! +
      values.frontWeight! * values.frontArm! +
      values.rearWeight! * values.rearArm! +
      values.cargoWeight! * values.cargoArm! +
      values.fuelWeight! * values.fuelArm!;
    const cg = totalMoment / totalWeight;

    const withinWeight = totalWeight <= values.mtow!;
    const withinCg = cg >= values.cgForward! && cg <= values.cgAft!;
    const satisfied = t(K.perfSatisfied);
    const exceeded = t(K.perfExceeded);

    setResult(
      `${t(K.perfWbTotalWeight)} ${totalWeight.toFixed(0)} kg\n` +
        `${t(K.perfWbCgPosition)} ${cg.toFixed(2)}\n` +
        `${t(K.perfWbWeightLimit)} ${withinWeight ? satisfied : exceeded}\n` +
        `${t(K.perfWbCgLimit)} ${withinCg ? satisfied : exceeded}\n` +
        `${t(K.perfWbStatus)}：${
          withinWeight && withinCg ? t(K.perfDispatchable) : t(K.perfOutOfLimit)
        }`,
    );
  };

  const numberField = (key: keyof typeof fields, labelKey: string) => (
    <TextField
      key={key}
      value={fields[key]}
      onChange={update(key)}
      label={t(labelKey)}
      type="number"
      monospace
    />
  );

  return (
    <SectionCard title={t(K.perfWbSectionTitle)} icon="balance">
      <div className={styles.formGrid}>
        {numberField('bew', K.perfBew)}
        {numberField('bewArm', K.perfBewArm)}
        {numberField('frontWeight', K.perfFrontWeight)}
        {numberField('frontArm', K.perfFrontArm)}
        {numberField('rearWeight', K.perfRearWeight)}
        {numberField('rearArm', K.perfRearArm)}
        {numberField('cargoWeight', K.perfCargoWeight)}
        {numberField('cargoArm', K.perfCargoArm)}
        {numberField('fuelWeight', K.perfFuelWeight)}
        {numberField('fuelArm', K.perfFuelArm)}
        {numberField('mtow', K.perfMtow)}
        {numberField('cgForward', K.perfCgForward)}
        {numberField('cgAft', K.perfCgAft)}
      </div>
      <Button variant="elevated" icon="calculate" onClick={calculate}>
        {t(K.perfWbButton)}
      </Button>
      <ResultBlock title={t(K.perfWbResultTitle)} text={result} />
    </SectionCard>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 跑道性能（后端计算）
// ──────────────────────────────────────────────────────────────────────────

interface AircraftProfile {
  id: string;
  manufacturer: string;
  family: string;
  model: string;
  minWeight: number;
  maxWeight: number;
  referenceWeight: number;
}

function RunwayPerformanceCard() {
  const t = useTranslate();
  const [profiles, setProfiles] = useState<AircraftProfile[]>([]);
  const [profilesLoading, setProfilesLoading] = useState(false);
  const [profilesError, setProfilesError] = useState('');
  const [selectedId, setSelectedId] = useState('');

  const [runwayLength, setRunwayLength] = useState('3200');
  const [pressureAltitude, setPressureAltitude] = useState('0');
  const [oat, setOat] = useState('15');
  const [headwind, setHeadwind] = useState('5');
  const [aircraftWeight, setAircraftWeight] = useState('65000');
  const [wetRunway, setWetRunway] = useState(false);

  const [calculating, setCalculating] = useState(false);
  const [result, setResult] = useState<string | null>(null);

  // 载入后端提供的机型性能档案
  useEffect(() => {
    let cancelled = false;
    void (async () => {
      setProfilesLoading(true);
      setProfilesError('');
      try {
        await MiddlewareHttpService.init();
        const response = await MiddlewareHttpService.getPerformanceAircraftProfiles();
        const body = response.objectBody;
        const rawList = Array.isArray(body?.profiles) ? body.profiles : [];
        const parsed = rawList
          .map((item) => toJsonMap(item))
          .filter((item): item is JsonMap => item !== null)
          .map(parseProfile);

        if (cancelled) return;
        setProfiles(parsed);
        if (parsed.length > 0) {
          setSelectedId(parsed[0].id);
          setAircraftWeight(String(Math.round(parsed[0].referenceWeight)));
        }
      } catch (e) {
        if (cancelled) return;
        AppLogger.warning(`[Toolbox] load aircraft profiles failed: ${extractErrorMessage(e)}`);
        setProfilesError(extractErrorMessage(e));
      } finally {
        if (!cancelled) setProfilesLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const selectedProfile = profiles.find((profile) => profile.id === selectedId);

  const calculate = async () => {
    if (!selectedProfile) return;
    const length = parseNumber(runwayLength);
    const altitude = parseNumber(pressureAltitude);
    const temperature = parseNumber(oat);
    const wind = parseNumber(headwind);
    const weight = parseNumber(aircraftWeight);

    if (
      length === null ||
      altitude === null ||
      temperature === null ||
      wind === null ||
      weight === null
    ) {
      setResult(t(K.commonInvalidNumber));
      return;
    }

    setCalculating(true);
    try {
      const response = await MiddlewareHttpService.calculatePerformance({
        aircraftId: selectedProfile.id,
        runwayLength: length,
        pressureAltitude: altitude,
        oat: temperature,
        headwind: wind,
        aircraftWeight: weight,
        wetRunway,
      });
      const body = response.objectBody;
      if (!body) throw new Error('Invalid performance response');

      const flexRecommended = body.flex_recommended === true;
      const flexTemperature = toDouble(body.flex_temperature) ?? 0;
      const flexText = flexRecommended
        ? `${flexTemperature.toFixed(0)}°C`
        : t(K.perfFlexNotRecommended);

      setResult(
        `${t(K.perfAircraftType)} ${aircraftName(selectedProfile)}\n` +
          `${t(K.perfV1)} ${(toDouble(body.v1) ?? 0).toFixed(0)} kt\n` +
          `${t(K.perfVr)} ${(toDouble(body.vr) ?? 0).toFixed(0)} kt\n` +
          `${t(K.perfV2)} ${(toDouble(body.v2) ?? 0).toFixed(0)} kt\n` +
          `${t(K.perfFlexTemp)} ${flexText}\n` +
          `${t(K.perfTakeoffRequired)} ${(toDouble(body.takeoff_required) ?? 0).toFixed(0)} m\n` +
          `${t(K.perfLandingRequired)} ${(toDouble(body.landing_required) ?? 0).toFixed(0)} m\n` +
          `${t(K.perfTakeoffMargin)} ${(toDouble(body.takeoff_margin) ?? 0).toFixed(0)} m\n` +
          `${t(K.perfLandingMargin)} ${(toDouble(body.landing_margin) ?? 0).toFixed(0)} m\n` +
          `${t(K.perfRunwayLevel)}：${runwayLevelText(String(body.runway_level_code ?? ''), t)}`,
      );
    } catch (e) {
      // 重量超限时给出该机型的允许区间，而不是原始错误码
      if (e instanceof MiddlewareHttpException) {
        const data = toJsonMap(e.data);
        const errorCode = String(data?.error ?? '').trim();
        if (errorCode === 'weight_out_of_range') {
          setResult(
            `${t(K.perfWeightRangeHint)} ${selectedProfile.minWeight.toFixed(0)}-${selectedProfile.maxWeight.toFixed(0)} kg`,
          );
          return;
        }
      }
      setResult(extractErrorMessage(e));
    } finally {
      setCalculating(false);
    }
  };

  return (
    <SectionCard title={t(K.perfRunwaySectionTitle)} icon="straighten">
      {profilesLoading && <div className={styles.inlineHint}>{t(K.perfAircraftType)}...</div>}
      {profilesError.length > 0 && (
        <div className={styles.errorHint}>{profilesError}</div>
      )}

      <div className={styles.formGrid}>
        <Select
          value={selectedId}
          options={profiles.map((profile) => ({
            value: profile.id,
            label: aircraftName(profile),
          }))}
          onChange={(value) => {
            setSelectedId(value);
            const profile = profiles.find((item) => item.id === value);
            if (profile) setAircraftWeight(String(Math.round(profile.referenceWeight)));
          }}
          label={t(K.perfAircraftType)}
          icon="flight"
          disabled={profiles.length === 0}
        />
        <TextField
          value={runwayLength}
          onChange={setRunwayLength}
          label={t(K.perfRunwayLength)}
          type="number"
          monospace
        />
        <TextField
          value={pressureAltitude}
          onChange={setPressureAltitude}
          label={t(K.perfPressureAltitude)}
          type="number"
          monospace
        />
        <TextField value={oat} onChange={setOat} label={t(K.perfOat)} type="number" monospace />
        <TextField
          value={headwind}
          onChange={setHeadwind}
          label={t(K.perfHeadwind)}
          type="number"
          monospace
        />
        <TextField
          value={aircraftWeight}
          onChange={setAircraftWeight}
          label={t(K.perfAircraftWeight)}
          type="number"
          monospace
          hint={
            selectedProfile
              ? `${selectedProfile.minWeight.toFixed(0)}–${selectedProfile.maxWeight.toFixed(0)} kg`
              : undefined
          }
        />
      </div>

      <Checkbox checked={wetRunway} onChange={setWetRunway} label={t(K.perfWetRunway)} />

      <Button
        variant="elevated"
        icon="calculate"
        loading={calculating}
        disabled={profilesLoading || profiles.length === 0}
        onClick={() => void calculate()}
      >
        {t(K.perfRunwayButton)}
      </Button>
      <ResultBlock title={t(K.perfRunwayResultTitle)} text={result} />
    </SectionCard>
  );
}

function parseProfile(map: JsonMap): AircraftProfile {
  return {
    id: String(map.id ?? '').trim(),
    manufacturer: String(map.manufacturer ?? '').trim(),
    family: String(map.family ?? '').trim(),
    model: String(map.model ?? '').trim(),
    minWeight: toDouble(map.min_weight) ?? 0,
    maxWeight: toDouble(map.max_weight) ?? 0,
    referenceWeight: toDouble(map.reference_weight) ?? 0,
  };
}

function aircraftName(profile: AircraftProfile): string {
  return [profile.manufacturer, profile.family, profile.model]
    .filter((part) => part.length > 0)
    .join(' ');
}

function runwayLevelText(code: string, t: (key: string) => string): string {
  if (code === 'high') return t(K.perfMarginHigh);
  if (code === 'acceptable') return t(K.perfAcceptable);
  return t(K.perfNotMet);
}
