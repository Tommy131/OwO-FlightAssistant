import { useState } from 'react';
import { useTranslate } from '../../../../core/localization/use-translate';
import { Button, TextField } from '../../../../core/widgets/common/controls';
import { SectionCard } from '../../../../core/widgets/common/surfaces';
import { ToolboxLocalizationKeys as K } from '../../localization/toolbox-localization';
import styles from './toolbox-tabs.module.css';

/**
 * 飞行计算器
 *
 * 对应 Flutter 版 `modules/toolbox/pages/widgets/flight_calculators_tab.dart`：
 * 侧风分解、下降顶点（TOD）、燃油计划三个计算器，公式逐行对齐。
 */
export function FlightCalculatorsTab() {
  return (
    <div className={styles.tab}>
      <WindCalculator />
      <DescentCalculator />
      <FuelCalculator />
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 侧风分解
// ──────────────────────────────────────────────────────────────────────────

function WindCalculator() {
  const t = useTranslate();
  const [runwayHeading, setRunwayHeading] = useState('360');
  const [windDirection, setWindDirection] = useState('030');
  const [windSpeed, setWindSpeed] = useState('15');
  const [result, setResult] = useState<string | null>(null);

  const calculate = () => {
    const heading = parseNumber(runwayHeading);
    const direction = parseNumber(windDirection);
    const speed = parseNumber(windSpeed);
    if (heading === null || direction === null || speed === null) {
      setResult(t(K.commonInvalidNumber));
      return;
    }

    // delta 为风向与跑道朝向的夹角，归一到 0–360
    const delta = (((direction - heading) % 360) + 360) % 360;
    const angle = delta > 180 ? 360 - delta : delta;
    const headwind = speed * Math.cos((angle * Math.PI) / 180);
    const crosswindRaw = speed * Math.sin((delta * Math.PI) / 180);
    const crosswind = Math.abs(crosswindRaw);

    const from = crosswindRaw >= 0 ? t(K.calcWindFromRight) : t(K.calcWindFromLeft);
    const level =
      crosswind <= 10
        ? t(K.calcWindRiskLow)
        : crosswind <= 20
          ? t(K.calcWindRiskMedium)
          : t(K.calcWindRiskHigh);

    setResult(
      `${t(K.calcWindHeadwind)} ${headwind.toFixed(1)} kt\n` +
        `${t(K.calcWindCrosswind)} ${crosswind.toFixed(1)} kt（${from}）\n` +
        `${t(K.calcWindRiskLevel)}：${level}`,
    );
  };

  return (
    <SectionCard title={t(K.calcWindSectionTitle)} icon="air">
      <div className={styles.formGrid}>
        <TextField
          value={runwayHeading}
          onChange={setRunwayHeading}
          label={t(K.calcWindRunwayHeading)}
          type="number"
          monospace
        />
        <TextField
          value={windDirection}
          onChange={setWindDirection}
          label={t(K.calcWindDirection)}
          type="number"
          monospace
        />
        <TextField
          value={windSpeed}
          onChange={setWindSpeed}
          label={t(K.calcWindSpeed)}
          type="number"
          monospace
        />
      </div>
      <Button variant="elevated" icon="calculate" onClick={calculate}>
        {t(K.calcWindButton)}
      </Button>
      <ResultBlock title={t(K.calcWindResultTitle)} text={result} />
    </SectionCard>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 下降顶点（TOD）
// ──────────────────────────────────────────────────────────────────────────

function DescentCalculator() {
  const t = useTranslate();
  const [currentAlt, setCurrentAlt] = useState('35000');
  const [targetAlt, setTargetAlt] = useState('3000');
  const [groundSpeed, setGroundSpeed] = useState('450');
  const [descentRate, setDescentRate] = useState('1800');
  const [distanceToGo, setDistanceToGo] = useState('');
  const [result, setResult] = useState<string | null>(null);

  const calculate = () => {
    const current = parseNumber(currentAlt);
    const target = parseNumber(targetAlt);
    const speed = parseNumber(groundSpeed);
    const rate = parseNumber(descentRate);
    const distance = parseNumber(distanceToGo);

    if (current === null || target === null || speed === null || rate === null) {
      setResult(t(K.commonInvalidNumber));
      return;
    }

    const altitudeToLose = Math.min(Math.max(current - target, 0), 50000);
    if (altitudeToLose <= 0 || rate <= 0 || speed <= 0) {
      setResult(t(K.commonInvalidRange));
      return;
    }

    const minutes = altitudeToLose / rate;
    const todDistance = speed * (minutes / 60);
    // 「3 倍规则」：每 1000ft 需要 3NM
    const ruleOf3Distance = (altitudeToLose / 1000) * 3;
    const requiredVs =
      distance === null || distance <= 0 ? null : altitudeToLose / ((distance / speed) * 60);

    setResult(
      `${t(K.calcDescentAltitudeToLose)} ${altitudeToLose.toFixed(0)} ft\n` +
        `${t(K.calcDescentTime)} ${minutes.toFixed(1)} min\n` +
        `${t(K.calcDescentTodDistance)} ${todDistance.toFixed(1)} NM\n` +
        `${t(K.calcDescentRuleDistance)} ${ruleOf3Distance.toFixed(1)} NM` +
        (requiredVs === null
          ? ''
          : `\n${t(K.calcDescentRequiredVs)} ${requiredVs.toFixed(0)} fpm`),
    );
  };

  return (
    <SectionCard title={t(K.calcDescentSectionTitle)} icon="trending_down">
      <div className={styles.formGrid}>
        <TextField
          value={currentAlt}
          onChange={setCurrentAlt}
          label={t(K.calcDescentCurrentAlt)}
          type="number"
          monospace
        />
        <TextField
          value={targetAlt}
          onChange={setTargetAlt}
          label={t(K.calcDescentTargetAlt)}
          type="number"
          monospace
        />
        <TextField
          value={groundSpeed}
          onChange={setGroundSpeed}
          label={t(K.calcDescentGroundSpeed)}
          type="number"
          monospace
        />
        <TextField
          value={descentRate}
          onChange={setDescentRate}
          label={t(K.calcDescentRate)}
          type="number"
          monospace
        />
        <TextField
          value={distanceToGo}
          onChange={setDistanceToGo}
          label={t(K.calcDescentDistanceToGo)}
          type="number"
          monospace
        />
      </div>
      <Button variant="elevated" icon="calculate" onClick={calculate}>
        {t(K.calcDescentButton)}
      </Button>
      <ResultBlock title={t(K.calcDescentResultTitle)} text={result} />
    </SectionCard>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 燃油计划
// ──────────────────────────────────────────────────────────────────────────

function FuelCalculator() {
  const t = useTranslate();
  const [distanceNm, setDistanceNm] = useState('600');
  const [cruiseSpeed, setCruiseSpeed] = useState('450');
  const [burnRate, setBurnRate] = useState('2400');
  const [reserveMin, setReserveMin] = useState('45');
  const [taxiFuel, setTaxiFuel] = useState('200');
  const [extraPct, setExtraPct] = useState('5');
  const [result, setResult] = useState<string | null>(null);

  const calculate = () => {
    const distance = parseNumber(distanceNm);
    const speed = parseNumber(cruiseSpeed);
    const burn = parseNumber(burnRate);
    const reserve = parseNumber(reserveMin);
    const taxi = parseNumber(taxiFuel);
    const extra = parseNumber(extraPct);

    if (
      distance === null ||
      speed === null ||
      burn === null ||
      reserve === null ||
      taxi === null ||
      extra === null
    ) {
      setResult(t(K.commonInvalidNumber));
      return;
    }
    if (distance <= 0 || speed <= 0 || burn <= 0) {
      setResult(t(K.commonInvalidRange));
      return;
    }

    const tripHours = distance / speed;
    const tripFuel = burn * tripHours;
    const reserveFuel = burn * (reserve / 60);
    const extraFuel = tripFuel * (extra / 100);
    const totalFuel = tripFuel + reserveFuel + taxi + extraFuel;

    setResult(
      `${t(K.calcFuelTrip)} ${tripFuel.toFixed(0)} kg\n` +
        `${t(K.calcFuelReserve)} ${reserveFuel.toFixed(0)} kg\n` +
        `${t(K.calcFuelTaxi)} ${taxi.toFixed(0)} kg\n` +
        `${t(K.calcFuelExtra)} ${extraFuel.toFixed(0)} kg\n` +
        `${t(K.calcFuelTotal)} ${totalFuel.toFixed(0)} kg`,
    );
  };

  return (
    <SectionCard title={t(K.calcFuelSectionTitle)} icon="local_gas_station">
      <div className={styles.formGrid}>
        <TextField
          value={distanceNm}
          onChange={setDistanceNm}
          label={t(K.calcFuelDistance)}
          type="number"
          monospace
        />
        <TextField
          value={cruiseSpeed}
          onChange={setCruiseSpeed}
          label={t(K.calcFuelCruiseSpeed)}
          type="number"
          monospace
        />
        <TextField
          value={burnRate}
          onChange={setBurnRate}
          label={t(K.calcFuelBurnRate)}
          type="number"
          monospace
        />
        <TextField
          value={reserveMin}
          onChange={setReserveMin}
          label={t(K.calcFuelReserveTime)}
          type="number"
          monospace
        />
        <TextField
          value={taxiFuel}
          onChange={setTaxiFuel}
          label={t(K.calcFuelTaxiFuel)}
          type="number"
          monospace
        />
        <TextField
          value={extraPct}
          onChange={setExtraPct}
          label={t(K.calcFuelExtraPct)}
          type="number"
          monospace
        />
      </div>
      <Button variant="elevated" icon="calculate" onClick={calculate}>
        {t(K.calcFuelButton)}
      </Button>
      <ResultBlock title={t(K.calcFuelResultTitle)} text={result} />
    </SectionCard>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 共用
// ──────────────────────────────────────────────────────────────────────────

export function ResultBlock({ title, text }: { title: string; text: string | null }) {
  if (!text) return null;
  return (
    <div className={styles.result}>
      <span className={styles.resultTitle}>{title}</span>
      <pre className={`${styles.resultText} text-mono`}>{text}</pre>
    </div>
  );
}

/** 解析数字输入，空串或非法值返回 null */
export function parseNumber(value: string): number | null {
  const trimmed = value.trim();
  if (trimmed.length === 0) return null;
  const parsed = Number.parseFloat(trimmed);
  return Number.isFinite(parsed) ? parsed : null;
}
