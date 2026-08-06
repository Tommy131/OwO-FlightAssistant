import { useState } from 'react';
import { useTranslate } from '../../../../core/localization/use-translate';
import { Button, Select } from '../../../../core/widgets/common/controls';
import { SectionCard } from '../../../../core/widgets/common/surfaces';
import {
  extractLowestCeiling,
  extractWorstVisibility,
  parseCeilingFt,
  parseVisibilitySm,
  resolveRule,
} from '../../services/metar-decode';
import { ToolboxLocalizationKeys as K } from '../../localization/toolbox-localization';
import { ResultBlock } from './flight-calculators-tab';
import styles from './toolbox-tabs.module.css';

/**
 * 气象报文解码
 *
 * 对应 Flutter 版 `modules/toolbox/pages/widgets/weather_decode_tab.dart`：
 * METAR/TAF 解码、风险提示、SIGMET/AIRMET 摘要、雷达外链，正则与阈值逐条对齐。
 */
export function WeatherDecodeTab() {
  const t = useTranslate();
  const [metar, setMetar] = useState('');
  const [taf, setTaf] = useState('');
  const [sigmet, setSigmet] = useState('');
  const [airmet, setAirmet] = useState('');
  const [metarSummary, setMetarSummary] = useState<string | null>(null);
  const [tafSummary, setTafSummary] = useState<string | null>(null);
  const [riskSummary, setRiskSummary] = useState<string | null>(null);
  const [sigmetSummary, setSigmetSummary] = useState<string | null>(null);
  const [airmetSummary, setAirmetSummary] = useState<string | null>(null);
  const [radarRegion, setRadarRegion] = useState('global');

  const decode = () => {
    const metarText = metar.trim().toUpperCase();
    const tafText = taf.trim().toUpperCase();
    setMetarSummary(decodeMetar(metarText, t));
    setTafSummary(decodeTaf(tafText, t));
    setRiskSummary(buildRisk(metarText, tafText, t));
    setSigmetSummary(decodeAdvisory(sigmet.trim().toUpperCase(), t, K.weatherNoSigmetInput));
    setAirmetSummary(decodeAdvisory(airmet.trim().toUpperCase(), t, K.weatherNoAirmetInput));
  };

  const radarUrls: Record<string, string> = {
    global: 'https://www.rainviewer.com/map.html',
    eastAsia: 'https://www.rainviewer.com/map.html?loc=35,115,4',
    europe: 'https://www.rainviewer.com/map.html?loc=50,10,4',
    northAmerica: 'https://www.rainviewer.com/map.html?loc=40,-100,4',
  };

  return (
    <div className={styles.tab}>
      <SectionCard title={t(K.weatherSectionTitle)} icon="cloud">
        <div className={styles.textAreaGrid}>
          <RawTextArea
            label={t(K.weatherMetarLabel)}
            placeholder={t(K.weatherMetarHint)}
            value={metar}
            onChange={setMetar}
          />
          <RawTextArea
            label={t(K.weatherTafLabel)}
            placeholder={t(K.weatherTafHint)}
            value={taf}
            onChange={setTaf}
          />
          <RawTextArea
            label={t(K.weatherSigmetLabel)}
            placeholder={t(K.weatherSigmetHint)}
            value={sigmet}
            onChange={setSigmet}
          />
          <RawTextArea
            label={t(K.weatherAirmetLabel)}
            placeholder={t(K.weatherAirmetHint)}
            value={airmet}
            onChange={setAirmet}
          />
        </div>
        <Button variant="elevated" icon="travel_explore" onClick={decode}>
          {t(K.weatherDecodeButton)}
        </Button>

        <ResultBlock title={t(K.weatherMetarResultTitle)} text={metarSummary} />
        <ResultBlock title={t(K.weatherTafResultTitle)} text={tafSummary} />
        <ResultBlock title={t(K.weatherRiskResultTitle)} text={riskSummary} />
        <ResultBlock title={t(K.weatherSigmetResultTitle)} text={sigmetSummary} />
        <ResultBlock title={t(K.weatherAirmetResultTitle)} text={airmetSummary} />
      </SectionCard>

      <SectionCard title={t(K.weatherRadarSectionTitle)} icon="radar">
        <div className={styles.inlineRow}>
          <Select
            value={radarRegion}
            options={[
              { value: 'global', label: t(K.weatherRadarGlobal) },
              { value: 'eastAsia', label: t(K.weatherRadarEastAsia) },
              { value: 'europe', label: t(K.weatherRadarEurope) },
              { value: 'northAmerica', label: t(K.weatherRadarNorthAmerica) },
            ]}
            onChange={setRadarRegion}
            label={t(K.weatherRadarRegionLabel)}
            icon="public"
          />
          <Button
            variant="outlined"
            icon="open_in_new"
            onClick={() => window.open(radarUrls[radarRegion], '_blank', 'noopener')}
          >
            {t(K.weatherRadarOpenButton)}
          </Button>
        </div>
      </SectionCard>
    </div>
  );
}

function RawTextArea({
  label,
  placeholder,
  value,
  onChange,
}: {
  label: string;
  placeholder: string;
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <label className={styles.textAreaWrap}>
      <span className={styles.textAreaLabel}>{label}</span>
      <textarea
        className={`${styles.textArea} text-mono`}
        value={value}
        placeholder={placeholder}
        rows={3}
        onChange={(event) => onChange(event.target.value)}
      />
    </label>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 解码逻辑
// ──────────────────────────────────────────────────────────────────────────

type Translate = (key: string, ...args: (string | number)[]) => string;

function decodeMetar(metar: string, t: Translate): string {
  if (metar.length === 0) return t(K.weatherNoMetarInput);

  const windMatch = metar.match(/(\d{3}|VRB)(\d{2,3})(G(\d{2,3}))?KT/);
  const visMatch = metar.match(/\b(\d{4}|P?\d+\/\d+SM|P?\d+SM)\b/);
  const qnhMatch = metar.match(/\b(Q\d{4}|A\d{4})\b/);
  const tempMatch = metar.match(/\b(M?\d{2})\/(M?\d{2})\b/);
  const cloudMatches = [...metar.matchAll(/\b(FEW|SCT|BKN|OVC|VV)\d{3}\b/g)].map((m) => m[0]);

  const visibilitySm = parseVisibilitySm(visMatch?.[1]);
  const ceilingFt = parseCeilingFt(cloudMatches.join(' '));
  const rule = resolveRule(visibilitySm, ceilingFt);

  return [
    `${t(K.weatherFieldWind)}：${windMatch?.[0] ?? '--'}`,
    `${t(K.weatherFieldVisibility)}：${visMatch?.[1] ?? '--'}${
      visibilitySm === undefined ? '' : ` (${visibilitySm.toFixed(1)}SM)`
    }`,
    `${t(K.weatherFieldCloud)}：${cloudMatches.length === 0 ? '--' : cloudMatches.join(' ')}`,
    `${t(K.weatherFieldCeiling)}：${ceilingFt === undefined ? '--' : `${ceilingFt.toFixed(0)} ft`}`,
    `${t(K.weatherFieldTempDew)}：${tempMatch === null ? '--' : `${tempMatch[1]}/${tempMatch[2]}`}`,
    `${t(K.weatherFieldQnh)}：${qnhMatch?.[1] ?? '--'}`,
    `${t(K.weatherFieldRule)}：${rule}`,
  ].join('\n');
}

function decodeTaf(taf: string, t: Translate): string {
  if (taf.length === 0) return t(K.weatherNoTafInput);

  const tokens: string[] = [];
  if (taf.includes('TEMPO')) tokens.push(t(K.weatherTafTempo));
  if (taf.includes('BECMG')) tokens.push(t(K.weatherTafBecmg));
  if (taf.includes('PROB30') || taf.includes('PROB40')) tokens.push(t(K.weatherTafProb));
  if (taf.includes('TS') || taf.includes('CB')) tokens.push(t(K.weatherTafTsCb));

  const worstVis = extractWorstVisibility(taf);
  const lowestCeiling = extractLowestCeiling(taf);

  return [
    ...(tokens.length === 0 ? [t(K.weatherTafNormal)] : []),
    ...tokens,
    `${t(K.weatherWorstVisibility)}：${worstVis === undefined ? '--' : `${worstVis.toFixed(1)} SM`}`,
    `${t(K.weatherLowestCeiling)}：${
      lowestCeiling === undefined ? '--' : `${lowestCeiling.toFixed(0)} ft`
    }`,
  ].join('\n');
}

/** 综合 METAR + TAF 给出风险清单 */
function buildRisk(metar: string, taf: string, t: Translate): string {
  const risks: string[] = [];
  const metarVis = extractWorstVisibility(metar);
  const metarCeiling = extractLowestCeiling(metar);

  if (metarVis !== undefined && metarVis < 3) risks.push(t(K.weatherRiskLowVis));
  if (metarCeiling !== undefined && metarCeiling < 1000) risks.push(t(K.weatherRiskLowCeiling));
  if (metar.includes('WS') || taf.includes('WS')) risks.push(t(K.weatherRiskWindShear));
  if (metar.includes('TS') || taf.includes('TS')) risks.push(t(K.weatherRiskThunder));
  if (metar.includes('FZ') || taf.includes('FZ')) risks.push(t(K.weatherRiskIcing));
  if (metar.includes('G') || taf.includes('G')) risks.push(t(K.weatherRiskGust));

  if (risks.length === 0) return t(K.weatherRiskNone);
  return risks.map((risk) => `• ${risk}`).join('\n');
}

/** SIGMET / AIRMET 摘要：时段、区域、高度层、危险天气类型 */
function decodeAdvisory(raw: string, t: Translate, emptyKey: string): string {
  if (raw.length === 0) return t(emptyKey);

  const period = raw.match(/(\d{6})\/(\d{6})/);
  const flightLevel = raw.match(/FL(\d{3})\/(\d{3})|FL(\d{3})/);
  const area = raw.match(/(WI|WTN)\s+([A-Z0-9\s-]{6,60})/);

  const hazards: string[] = [];
  if (raw.includes('TS')) hazards.push(t(K.weatherAdvisoryThunder));
  if (raw.includes('TURB')) hazards.push(t(K.weatherAdvisoryTurb));
  if (raw.includes('ICE') || raw.includes('FZ')) hazards.push(t(K.weatherAdvisoryIcing));
  if (raw.includes('MTW')) hazards.push(t(K.weatherAdvisoryMountainWave));
  if (raw.includes('VA')) hazards.push(t(K.weatherAdvisoryVolcanic));
  if (raw.includes('TC')) hazards.push(t(K.weatherAdvisoryCyclone));

  return [
    `${t(K.weatherAdvisoryPeriod)}：${period ? `${period[1]} / ${period[2]}` : '--'}`,
    `${t(K.weatherAdvisoryArea)}：${area?.[2]?.trim() ?? '--'}`,
    `${t(K.weatherAdvisoryFlightLevel)}：${flightLevel?.[0] ?? '--'}`,
    `${t(K.weatherAdvisoryHazards)}：${hazards.length === 0 ? '--' : hazards.join('、')}`,
  ].join('\n');
}
