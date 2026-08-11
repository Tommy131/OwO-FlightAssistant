import { useEffect, useState } from 'react';
import { LocalizationKeys } from '../../../core/localization/localization-keys';
import { useTranslate } from '../../../core/localization/use-translate';
import type { SettingsPageItem } from '../../../core/module-registry/settings-page/settings-page-registry';
import { translate } from '../../../core/services/localization-service';
import { Button, Select, Switch, TextField } from '../../../core/widgets/common/controls';
import { MaterialIcon } from '../../../core/widgets/common/icon';
import { SnackBarHelper } from '../../../core/widgets/common/snack-bar';
import { InfoChip, SectionCard } from '../../../core/widgets/common/surfaces';
import { toDouble, toInt, toJsonMap, type JsonMap } from '../../../core/utils/parse-utils';
import { useFlightDataStore } from '../../common/providers/flight-data-store';
import {
  MAX_POLL_INTERVAL_MS,
  MIN_POLL_INTERVAL_MS,
} from '../../common/providers/middleware-flight-data-adapter';
import { useFlightLogsStore } from '../../flight_logs/providers/flight-logs-store';
import { useMonitorStore } from '../../monitor/providers/monitor-store';
import { HttpLocalizationKeys as K } from '../localization/http-localization';
import {
  DESKTOP_DEFAULT_BASE_URL,
  MiddlewareHttpService,
  PROXY_HTTP_PREFIX,
} from '../services/middleware-http-service';
import styles from './http-settings.module.css';

/**
 * 中间件设置页
 *
 * 对应 Flutter 版 `modules/http/pages/http_settings_page_item.dart` 及
 * widgets/ 下的 http_address_form / ws_address_form / runtime_settings_form / diagnosis_form。
 */
export function createHttpSettingsPageItem(): SettingsPageItem {
  return {
    id: 'http_backend_settings',
    icon: 'lan',
    priority: 20,
    getTitle: () => translate(K.settingsTitle),
    getDescription: () => translate(K.settingsDescription),
    render: () => <HttpSettingsPage />,
  };
}

function HttpSettingsPage() {
  return (
    <div className={styles.page}>
      <AddressForm />
      <NavDataSourceForm />
      <RuntimeSettingsForm />
      <DiagnosisForm />
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 导航数据源
// ──────────────────────────────────────────────────────────────────────────

interface NavSourceOption {
  value: string;
  label: string;
}

/**
 * 导航数据源快速切换
 *
 * 这个设置本身住在中间件的配置文件里（`default_nav_source`），此前只能在
 * 中间件自己的 TUI 里改。可中间件常常不在手边 —— 平板上开着 EFB、
 * 中间件跑在主机上，为换个数据源要跑去另一台机器上敲键盘。
 * 这里读写的是同一个字段，两边看到的永远是同一份状态。
 */
function NavDataSourceForm() {
  const t = useTranslate();
  const [options, setOptions] = useState<NavSourceOption[]>([]);
  const [configured, setConfigured] = useState('');
  const [effective, setEffective] = useState('');
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);

  const load = async () => {
    try {
      await MiddlewareHttpService.init();
      const response = await MiddlewareHttpService.getNavDataSources();
      const body = response.objectBody;
      const raw = Array.isArray(body?.sources) ? body.sources : [];
      setOptions(
        raw
          .map((item) => toJsonMap(item))
          .filter((item): item is JsonMap => item !== null)
          .map((item) => ({
            value: typeof item.value === 'string' ? item.value : '',
            label: typeof item.label === 'string' ? item.label : '',
          }))
          .filter((item) => item.value.length > 0),
      );
      setConfigured(typeof body?.configured === 'string' ? body.configured : '');
      setEffective(typeof body?.effective === 'string' ? body.effective : '');
    } catch {
      setOptions([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load();
  }, []);

  const handleChange = async (value: string) => {
    setBusy(true);
    try {
      await MiddlewareHttpService.setNavDataSource(value);
      setConfigured(value);
      // 切完回读一次：生效的源未必等于选的那个（选「自动」时由中间件决定）
      await load();
      SnackBarHelper.showSuccess(t(K.navSourceSaved));
    } catch {
      SnackBarHelper.showError(t(K.navSourceSaveFailed));
    } finally {
      setBusy(false);
    }
  };

  const effectiveLabel =
    options.find((option) => option.value === effective)?.label || effective || '--';
  // 存着的源不为空却没能生效，说明它已经不可用了（模拟器卸载/路径变了）
  const fellBack = configured.length > 0 && configured !== effective;

  return (
    <SectionCard
      title={t(K.navSourceSectionTitle)}
      icon="storage"
      subtitle={t(K.navSourceSectionDescription)}
    >
      {!loading && options.length === 0 ? (
        <span className={styles.settingHint}>{t(K.navSourceEmpty)}</span>
      ) : (
        <>
          <Select
            value={configured}
            options={[
              { value: '', label: t(K.navSourceAuto) },
              ...options.map((option) => ({ value: option.value, label: option.label })),
            ]}
            onChange={(value) => void handleChange(value)}
            label={t(K.navSourceLabel)}
            icon="database"
            disabled={busy || loading}
          />

          <div className={styles.currentRow}>
            <InfoChip icon="check_circle" label={t(K.navSourceCurrent, { value: effectiveLabel })} />
          </div>

          {fellBack && (
            <span className={styles.settingHint}>{t(K.navSourceFallbackHint)}</span>
          )}
          <span className={styles.settingHint}>{t(K.navSourceReloadHint)}</span>
        </>
      )}
    </SectionCard>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 地址配置
// ──────────────────────────────────────────────────────────────────────────

function AddressForm() {
  const t = useTranslate();
  const [baseUrl, setBaseUrl] = useState(MiddlewareHttpService.baseUrl);
  const [wsUrl, setWsUrl] = useState(MiddlewareHttpService.webSocketBaseUrl);
  const [timeoutMs, setTimeoutMs] = useState(String(MiddlewareHttpService.timeout));
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    void MiddlewareHttpService.init().then(() => {
      setBaseUrl(MiddlewareHttpService.baseUrl);
      setWsUrl(MiddlewareHttpService.webSocketBaseUrl);
      setTimeoutMs(String(MiddlewareHttpService.timeout));
    });
  }, []);

  const usingProxy = MiddlewareHttpService.isUsingProxy();

  const handleSave = async () => {
    const timeout = Number.parseInt(timeoutMs, 10);
    if (!Number.isFinite(timeout) || timeout < 1000 || timeout > 120_000) {
      SnackBarHelper.showError(t(K.invalidPort));
      return;
    }
    setBusy(true);
    try {
      await MiddlewareHttpService.configure({
        baseUrl: baseUrl.trim(),
        webSocketBaseUrl: wsUrl.trim(),
        timeoutMs: timeout,
      });
      SnackBarHelper.showSuccess(t(K.saveSuccess));
    } finally {
      setBusy(false);
    }
  };

  return (
    <SectionCard
      title={t(K.backendSectionTitle)}
      icon="lan"
      subtitle={t(K.backendSectionDescription)}
    >
      {usingProxy && (
        <div className={styles.proxyBanner}>
          <MaterialIcon name="swap_horiz" size={17} color="var(--color-primary)" />
          <span>
            {t(LocalizationKeys.webProxyBanner, {
              proxy: PROXY_HTTP_PREFIX,
              direct: DESKTOP_DEFAULT_BASE_URL,
            })}
          </span>
        </div>
      )}

      <div className={styles.formGrid}>
        <TextField
          value={baseUrl}
          onChange={setBaseUrl}
          label={t(K.hostLabel)}
          placeholder={t(K.hostHint)}
          icon="http"
          monospace
        />
        <TextField
          value={wsUrl}
          onChange={setWsUrl}
          label={t(K.wsHostLabel)}
          placeholder={t(K.wsHostHint)}
          icon="cable"
          monospace
        />
        <TextField
          value={timeoutMs}
          onChange={setTimeoutMs}
          label="Timeout (ms)"
          type="number"
          icon="timer"
          monospace
        />
      </div>

      <div className={styles.currentRow}>
        <InfoChip
          icon="link"
          label={t(K.currentAddress, { address: MiddlewareHttpService.baseUrl })}
        />
        <InfoChip
          icon="cable"
          label={t(K.currentWsAddress, { address: MiddlewareHttpService.webSocketBaseUrl })}
        />
      </div>

      <Button variant="elevated" icon="save" loading={busy} onClick={() => void handleSave()}>
        {busy ? t(K.saving) : t(K.saveButton)}
      </Button>
    </SectionCard>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 运行时设置
// ──────────────────────────────────────────────────────────────────────────

function RuntimeSettingsForm() {
  const t = useTranslate();
  const getFlightDataIntervalMs = useFlightDataStore((s) => s.getFlightDataIntervalMs);
  const setFlightDataIntervalMs = useFlightDataStore((s) => s.setFlightDataIntervalMs);
  const sampleIntervalMs = useFlightLogsStore((s) => s.sampleIntervalMs);
  const setSampleIntervalMs = useFlightLogsStore((s) => s.setSampleIntervalMs);
  const lowPerformanceMode = useMonitorStore((s) => s.lowPerformanceMode);
  const setLowPerformanceMode = useMonitorStore((s) => s.setLowPerformanceMode);
  const uiRefreshIntervalMs = useMonitorStore((s) => s.uiRefreshIntervalMs);
  const setUiRefreshIntervalMs = useMonitorStore((s) => s.setUiRefreshIntervalMs);

  const [pollInterval, setPollInterval] = useState('300');
  const [logInterval, setLogInterval] = useState(String(sampleIntervalMs));
  const [uiInterval, setUiInterval] = useState(String(uiRefreshIntervalMs));

  useEffect(() => {
    void getFlightDataIntervalMs().then((value) => setPollInterval(String(value)));
  }, [getFlightDataIntervalMs]);

  const saveNumber = async (
    raw: string,
    min: number,
    max: number,
    apply: (value: number) => Promise<void>,
    invalidKey: string,
  ) => {
    const value = Number.parseInt(raw, 10);
    if (!Number.isFinite(value) || value < min || value > max) {
      SnackBarHelper.showError(t(invalidKey));
      return;
    }
    await apply(value);
    SnackBarHelper.showSuccess(t(K.flightDataIntervalSaved));
  };

  return (
    <SectionCard
      title={t(K.flightDataSectionTitle)}
      icon="tune"
      subtitle={t(K.flightDataSectionDescription)}
    >
      <div className={styles.settingRow}>
        <div className={styles.settingText}>
          <span className={styles.settingLabel}>{t(K.lowPerformanceModeLabel)}</span>
          <span className={styles.settingHint}>{t(K.lowPerformanceModeHint)}</span>
        </div>
        <Switch
          checked={lowPerformanceMode}
          onChange={(value) => void setLowPerformanceMode(value)}
          label={t(K.lowPerformanceModeLabel)}
        />
      </div>

      <div className={styles.formGrid}>
        <IntervalField
          label={t(K.flightDataIntervalLabel)}
          hint={t(K.flightDataIntervalHint)}
          value={pollInterval}
          onChange={setPollInterval}
          onSave={() =>
            void saveNumber(
              pollInterval,
              MIN_POLL_INTERVAL_MS,
              MAX_POLL_INTERVAL_MS,
              setFlightDataIntervalMs,
              K.invalidFlightDataInterval,
            )
          }
        />
        <IntervalField
          label={t(K.flightLogIntervalLabel)}
          hint={t(K.flightLogIntervalHint)}
          value={logInterval}
          onChange={setLogInterval}
          onSave={() =>
            void saveNumber(
              logInterval,
              100,
              2000,
              setSampleIntervalMs,
              K.invalidFlightLogInterval,
            )
          }
        />
        <IntervalField
          label={t(K.uiRefreshIntervalLabel)}
          hint={t(K.uiRefreshIntervalHint)}
          value={uiInterval}
          onChange={setUiInterval}
          onSave={() =>
            void saveNumber(
              uiInterval,
              60,
              2000,
              setUiRefreshIntervalMs,
              K.invalidUiRefreshInterval,
            )
          }
        />
      </div>
    </SectionCard>
  );
}

function IntervalField({
  label,
  hint,
  value,
  onChange,
  onSave,
}: {
  label: string;
  hint: string;
  value: string;
  onChange: (value: string) => void;
  onSave: () => void;
}) {
  return (
    <TextField
      value={value}
      onChange={onChange}
      label={label}
      hint={hint}
      type="number"
      monospace
      onSubmit={onSave}
      trailing={
        <Button variant="text" size="sm" icon="save" onClick={onSave}>
          ms
        </Button>
      }
    />
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 连通性诊断
// ──────────────────────────────────────────────────────────────────────────

interface DiagnosisStep {
  label: string;
  ok: boolean;
  detail?: string;
}

/** 一行「指标名 : 值」 */
interface QualityRow {
  label: string;
  value: string;
}

/** 诊断拿回来的数据质量快照 */
interface QualityReport {
  stalled: boolean;
  observed: boolean;
  upstream: QualityRow[];
  downstream: QualityRow[];
}

function DiagnosisForm() {
  const t = useTranslate();
  const [steps, setSteps] = useState<DiagnosisStep[]>([]);
  const [quality, setQuality] = useState<QualityReport | null>(null);
  const [busy, setBusy] = useState(false);

  const runDiagnosis = async () => {
    setBusy(true);
    setSteps([]);
    setQuality(null);
    const results: DiagnosisStep[] = [];

    // 1. 后端健康
    try {
      await MiddlewareHttpService.init();
      await MiddlewareHttpService.getHealth();
      results.push({ label: t(K.diagnoseBackendOk), ok: true });
    } catch (e) {
      results.push({ label: t(K.diagnoseBackendFail), ok: false, detail: String(e) });
      setSteps(results);
      setBusy(false);
      return;
    }

    // 2. WebSocket 地址可解析
    try {
      const info = await MiddlewareHttpService.getSimulatorWebSocketInfo();
      const address = info.objectBody?.ws_address;
      results.push({
        label: t(K.diagnoseWsOk),
        ok: true,
        detail: typeof address === 'string' ? address : undefined,
      });
    } catch (e) {
      results.push({ label: t(K.diagnoseWsFail), ok: false, detail: String(e) });
    }

    // 3. 模拟器状态（未连模拟器时失败属正常，如实标注）
    try {
      const state = await MiddlewareHttpService.getSimulatorState('msfs');
      results.push({
        label: t(K.diagnoseSimulatorOk),
        ok: true,
        detail: JSON.stringify(state.decodedBody).slice(0, 120),
      });
    } catch (e) {
      results.push({ label: t(K.diagnoseSimulatorFail), ok: false, detail: String(e) });
    }

    // 4. 数据质量指标：链路能连通不代表数据是新的。
    //    上游冻住时前面三步全绿，画面却是停的 —— 只有这一步能看出来。
    try {
      const response = await MiddlewareHttpService.getConnectionDiagnostics();
      const report = buildQualityReport(response.objectBody, t);
      setQuality(report);
      results.push({
        label: t(K.diagnoseQualityOk),
        ok: !report.stalled,
        detail: report.observed
          ? report.stalled
            ? t(K.qualityStalled)
            : t(K.qualityHealthy)
          : t(K.qualityNoSample),
      });
    } catch (e) {
      results.push({ label: t(K.diagnoseQualityFail), ok: false, detail: String(e) });
    }

    setSteps(results);
    setBusy(false);
  };

  return (
    <SectionCard
      title={t(K.diagnoseSectionTitle)}
      icon="troubleshoot"
      subtitle={t(K.diagnoseSectionDescription)}
    >
      <Button
        variant="elevated"
        icon="play_arrow"
        loading={busy}
        onClick={() => void runDiagnosis()}
      >
        {busy ? t(K.testing) : t(K.runDiagnosis)}
      </Button>

      {steps.length > 0 && (
        <div className={styles.diagnosisList}>
          {steps.map((step, index) => (
            <div key={index} className={styles.diagnosisRow}>
              <MaterialIcon
                name={step.ok ? 'check_circle' : 'cancel'}
                filled
                size={17}
                color={step.ok ? 'var(--color-success)' : 'var(--color-error)'}
              />
              <div className={styles.diagnosisText}>
                <span className={styles.diagnosisLabel}>{step.label}</span>
                {step.detail && (
                  <span className={`${styles.diagnosisDetail} text-mono`}>{step.detail}</span>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {quality && (
        <div className={styles.qualityGrid}>
          <QualityColumn title={t(K.qualityUpstream)} rows={quality.upstream} />
          <QualityColumn title={t(K.qualityDownstream)} rows={quality.downstream} />
        </div>
      )}
    </SectionCard>
  );
}

function QualityColumn({ title, rows }: { title: string; rows: QualityRow[] }) {
  return (
    <div className={styles.qualityColumn}>
      <span className={styles.qualityTitle}>{title}</span>
      {rows.map((row) => (
        <div key={row.label} className={styles.qualityRow}>
          <span className={styles.qualityLabel}>{row.label}</span>
          <span className={`${styles.qualityValue} text-mono`}>{row.value}</span>
        </div>
      ))}
    </div>
  );
}

/** 把 /diagnostics/connection 的响应整理成两列指标 */
function buildQualityReport(
  body: JsonMap | null,
  t: (key: string) => string,
): QualityReport {
  const upstream = toJsonMap(body?.upstream) ?? {};
  const downstream = toJsonMap(body?.downstream) ?? {};
  const websocket = toJsonMap(downstream.websocket) ?? {};
  const clients = Array.isArray(websocket.clients) ? websocket.clients : [];
  // 取最近连上的那条连接：诊断关心的是「我现在这条链路」。
  const client = toJsonMap(clients[0]) ?? {};

  const observed = upstream.observed === true;
  const upstreamRows: QualityRow[] = observed
    ? [
        { label: t(K.qualitySampleRate), value: `${fixed(upstream.sample_rate_hz, 1)} Hz` },
        { label: t(K.qualityRepeatRatio), value: `${fixed(pct(upstream.repeat_ratio), 1)} %` },
        { label: t(K.qualityStallCount), value: `${int(upstream.stall_count)}` },
        { label: t(K.qualityMaxGap), value: `${fixed(upstream.max_gap_ms, 0)} ms` },
      ]
    : [{ label: t(K.qualityNoSample), value: '—' }];

  const downstreamRows: QualityRow[] = [
    {
      label: t(K.qualityPushCount),
      value: `${int(client.snapshot_count)} / ${int(client.delta_count)} / ${int(client.skipped_count)}`,
    },
    {
      label: t(K.qualityLatency),
      value: `${fixed(client.avg_latency_ms, 1)} / ${fixed(client.max_latency_ms, 1)} ms`,
    },
    { label: t(K.qualityMaxGap), value: `${fixed(client.max_gap_ms, 0)} ms` },
    {
      label: t(K.qualityFailureCount),
      value: `${int(client.failure_count)} (${int(client.stall_count)})`,
    },
    { label: t(K.qualityBytesSent), value: formatBytes(int(client.bytes_sent)) },
  ];

  return {
    observed,
    stalled: upstream.stalled === true,
    upstream: upstreamRows,
    downstream: downstreamRows,
  };
}

function fixed(value: unknown, digits: number): string {
  return (toDouble(value) ?? 0).toFixed(digits);
}

function int(value: unknown): number {
  return toInt(value) ?? 0;
}

function pct(value: unknown): number {
  return (toDouble(value) ?? 0) * 100;
}

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(2)} MB`;
}
