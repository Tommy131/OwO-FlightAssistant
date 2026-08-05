import { useEffect, useState } from 'react';
import { LocalizationKeys } from '../../../core/localization/localization-keys';
import { useTranslate } from '../../../core/localization/use-translate';
import type { SettingsPageItem } from '../../../core/module-registry/settings-page/settings-page-registry';
import { translate } from '../../../core/services/localization-service';
import { Button, Switch, TextField } from '../../../core/widgets/common/controls';
import { MaterialIcon } from '../../../core/widgets/common/icon';
import { SnackBarHelper } from '../../../core/widgets/common/snack-bar';
import { InfoChip, SectionCard } from '../../../core/widgets/common/surfaces';
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
      <RuntimeSettingsForm />
      <DiagnosisForm />
    </div>
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
        <InfoChip icon="link" label={`${t(K.currentAddress)}: ${MiddlewareHttpService.baseUrl}`} />
        <InfoChip
          icon="cable"
          label={`${t(K.currentWsAddress)}: ${MiddlewareHttpService.webSocketBaseUrl}`}
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

function DiagnosisForm() {
  const t = useTranslate();
  const [steps, setSteps] = useState<DiagnosisStep[]>([]);
  const [busy, setBusy] = useState(false);

  const runDiagnosis = async () => {
    setBusy(true);
    setSteps([]);
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
    </SectionCard>
  );
}
