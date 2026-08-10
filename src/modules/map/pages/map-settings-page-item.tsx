import { useState } from 'react';
import type { SettingsPageItem } from '../../../core/module-registry/settings-page/settings-page-registry';
import { useTranslate } from '../../../core/localization/use-translate';
import { translate } from '../../../core/services/localization-service';
import { Button, Select, Switch, TextField } from '../../../core/widgets/common/controls';
import { MaterialIcon } from '../../../core/widgets/common/icon';
import { SnackBarHelper } from '../../../core/widgets/common/snack-bar';
import { SectionCard } from '../../../core/widgets/common/surfaces';
import { MiddlewareHttpService } from '../../http/services/middleware-http-service';
import { MapLocalizationKeys as K } from '../localization/map-localization';
import {
  MAP_AUTO_TIMER_START_MODES,
  MAP_AUTO_TIMER_STOP_MODES,
  type MapAutoTimerStartMode,
  type MapAutoTimerStopMode,
} from '../models/map-models';
import { CONFIGURABLE_ALERT_IDS, useMapStore } from '../providers/map-store';
import { ALERT_MESSAGE_KEY } from '../services/flight-alerts';
import { parseAirportDetail } from '../services/map-airport-parser';
import styles from './map-settings.module.css';

/**
 * 地图模块设置页
 *
 * 对应 Flutter 版 `modules/map/pages/map_settings_page_item.dart` 与
 * `widgets/settings/` 下的三个 section：本场机场 / 计时器 / 告警。
 */
export function createMapSettingsPageItem(): SettingsPageItem {
  return {
    id: 'map_module_settings',
    icon: 'map',
    priority: 30,
    getTitle: () => translate(K.navTitle),
    getDescription: () => translate(K.panelSubtitle),
    render: () => <MapSettingsPage />,
  };
}

function MapSettingsPage() {
  return (
    <div className={styles.page}>
      <HomeAirportSection />
      <TimerSection />
      <AlertSettingsSection />
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 本场机场
// ──────────────────────────────────────────────────────────────────────────

function HomeAirportSection() {
  const t = useTranslate();
  const homeAirport = useMapStore((s) => s.homeAirport);
  const setHomeAirport = useMapStore((s) => s.setHomeAirport);
  const clearHomeAirport = useMapStore((s) => s.clearHomeAirport);
  const [icao, setIcao] = useState('');
  const [busy, setBusy] = useState(false);

  const handleSave = async () => {
    const code = icao.trim().toUpperCase();
    if (code.length !== 4) {
      SnackBarHelper.showWarning(t(K.homeAirportNotFound));
      return;
    }
    setBusy(true);
    try {
      await MiddlewareHttpService.init();
      const response = await MiddlewareHttpService.getAirportByIcao(code);
      const body = response.objectBody;
      const detail = body ? parseAirportDetail(body, code) : null;
      if (!detail) {
        SnackBarHelper.showError(t(K.homeAirportNotFound));
        return;
      }
      await setHomeAirport(detail.marker);
      setIcao('');
      SnackBarHelper.showSuccess(t(K.homeAirportSaved));
    } catch {
      SnackBarHelper.showError(t(K.homeAirportServiceUnavailableHint));
    } finally {
      setBusy(false);
    }
  };

  return (
    <SectionCard
      title={t(K.homeAirportSectionTitle)}
      icon="home_work"
      subtitle={t(K.homeAirportSectionDesc)}
    >
      {homeAirport && (
        <div className={styles.currentHome}>
          <MaterialIcon name="star" filled size={17} color="#fab219" />
          <span className={styles.currentHomeText}>
            {t(K.homeAirportCurrent)}: <strong>{homeAirport.code}</strong>
            {homeAirport.name ? ` · ${homeAirport.name}` : ''}
          </span>
          <Button
            variant="text"
            size="sm"
            icon="close"
            onClick={() => {
              void clearHomeAirport();
              SnackBarHelper.showInfo(t(K.homeAirportCleared));
            }}
          >
            {t(K.clearButton)}
          </Button>
        </div>
      )}

      <div className={styles.inlineForm}>
        <TextField
          value={icao}
          onChange={(value) => setIcao(value.toUpperCase())}
          label={t(K.homeAirportIcaoLabel)}
          placeholder={t(K.homeAirportIcaoHint)}
          monospace
          onSubmit={() => void handleSave()}
          className={styles.inlineField}
        />
        <Button variant="elevated" icon="save" loading={busy} onClick={() => void handleSave()}>
          {t(K.homeAirportSaved)}
        </Button>
      </div>
    </SectionCard>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 计时器
// ──────────────────────────────────────────────────────────────────────────

const START_MODE_LABEL: Record<MapAutoTimerStartMode, string> = {
  runwayMovement: K.timerStartRunwayMovement,
  pushback: K.timerStartPushback,
  anyMovement: K.timerStartAnyMovement,
};

const STOP_MODE_LABEL: Record<MapAutoTimerStopMode, string> = {
  stableLanding: K.timerStopStableLanding,
  runwayExitAfterLanding: K.timerStopRunwayExit,
  parkingArrival: K.timerStopParkingArrival,
};

function TimerSection() {
  const t = useTranslate();
  const enabled = useMapStore((s) => s.autoHudTimerEnabled);
  const startMode = useMapStore((s) => s.autoTimerStartMode);
  const stopMode = useMapStore((s) => s.autoTimerStopMode);
  const setEnabled = useMapStore((s) => s.setAutoHudTimerEnabled);
  const setStartMode = useMapStore((s) => s.setAutoTimerStartMode);
  const setStopMode = useMapStore((s) => s.setAutoTimerStopMode);

  return (
    <SectionCard
      title={t(K.timerSectionTitle)}
      icon="timer"
      subtitle={t(K.timerSectionDesc)}
    >
      <div className={styles.settingRow}>
        <span className={styles.settingLabel}>{t(K.timerAutoEnable)}</span>
        <Switch
          checked={enabled}
          onChange={(value) => {
            void setEnabled(value);
            SnackBarHelper.showSuccess(t(K.timerSettingsSaved));
          }}
          label={t(K.timerAutoEnable)}
        />
      </div>

      <div className={styles.selectGrid}>
        <Select
          value={startMode}
          options={MAP_AUTO_TIMER_START_MODES.map((mode) => ({
            value: mode,
            label: t(START_MODE_LABEL[mode]),
          }))}
          onChange={(value) => void setStartMode(value)}
          label={t(K.timerStartCondition)}
          icon="play_arrow"
          disabled={!enabled}
        />
        <Select
          value={stopMode}
          options={MAP_AUTO_TIMER_STOP_MODES.map((mode) => ({
            value: mode,
            label: t(STOP_MODE_LABEL[mode]),
          }))}
          onChange={(value) => void setStopMode(value)}
          label={t(K.timerStopCondition)}
          icon="stop"
          disabled={!enabled}
        />
      </div>
    </SectionCard>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 告警设置
// ──────────────────────────────────────────────────────────────────────────


function AlertSettingsSection() {
  const t = useTranslate();
  const alertsEnabled = useMapStore((s) => s.alertsEnabled);
  const setAlertsEnabled = useMapStore((s) => s.setAlertsEnabled);
  const setAlertEnabled = useMapStore((s) => s.setAlertEnabled);
  const isAlertEnabled = useMapStore((s) => s.isAlertEnabled);
  const disabledIds = useMapStore((s) => s.disabledAlertIds);
  const setThresholds = useMapStore((s) => s.setVerticalRateThresholds);

  const climbWarning = useMapStore((s) => s.climbRateWarningFpm);
  const climbDanger = useMapStore((s) => s.climbRateDangerFpm);
  const descentWarning = useMapStore((s) => s.descentRateWarningFpm);
  const descentDanger = useMapStore((s) => s.descentRateDangerFpm);

  const [draft, setDraft] = useState({
    climbWarning: String(climbWarning),
    climbDanger: String(climbDanger),
    descentWarning: String(descentWarning),
    descentDanger: String(descentDanger),
  });

  const handleSaveThresholds = async () => {
    const parse = (value: string) => {
      const parsed = Number.parseInt(value, 10);
      return Number.isFinite(parsed) ? parsed : undefined;
    };
    await setThresholds({
      climbWarning: parse(draft.climbWarning),
      climbDanger: parse(draft.climbDanger),
      descentWarning: parse(draft.descentWarning),
      descentDanger: parse(draft.descentDanger),
    });
    SnackBarHelper.showSuccess(t(K.alertSettingsSaved));
  };

  return (
    <SectionCard
      title={t(K.alertSettingsSectionTitle)}
      icon="notifications_active"
      subtitle={t(K.alertSettingsSectionDesc)}
    >
      <div className={styles.settingRow}>
        <span className={styles.settingLabel}>{t(K.alertSettingsEnableAll)}</span>
        <Switch
          checked={alertsEnabled}
          onChange={(value) => void setAlertsEnabled(value)}
          label={t(K.alertSettingsEnableAll)}
        />
      </div>

      <div className={styles.alertList}>
        <span className={styles.subsectionTitle}>{t(K.alertSettingsSelectAlerts)}</span>
        {CONFIGURABLE_ALERT_IDS.map((alertId) => (
          <label key={alertId} className={styles.alertRow}>
            {/* 开关名直接用告警自己的文案，两处叫法就不会对不上 */}
            <span className={styles.alertName}>{alertLabel(alertId, t)}</span>
            <Switch
              checked={isAlertEnabled(alertId)}
              onChange={(value) => void setAlertEnabled(alertId, value)}
              disabled={!alertsEnabled}
              label={alertId}
            />
          </label>
        ))}
        {disabledIds.length > 0 && (
          <span className={styles.disabledHint}>
            {disabledIds.length} disabled
          </span>
        )}
      </div>

      <div className={styles.thresholdBlock}>
        <span className={styles.subsectionTitle}>{t(K.alertSettingsThresholdTitle)}</span>
        <span className={styles.thresholdHint}>{t(K.alertThresholdHint)}</span>

        <div className={styles.thresholdGrid}>
          <TextField
            value={draft.climbWarning}
            onChange={(value) => setDraft((prev) => ({ ...prev, climbWarning: value }))}
            label={t(K.alertThresholdClimbWarningLabel)}
            type="number"
            monospace
            disabled={!alertsEnabled}
          />
          <TextField
            value={draft.climbDanger}
            onChange={(value) => setDraft((prev) => ({ ...prev, climbDanger: value }))}
            label={t(K.alertThresholdClimbDangerLabel)}
            type="number"
            monospace
            disabled={!alertsEnabled}
          />
          <TextField
            value={draft.descentWarning}
            onChange={(value) => setDraft((prev) => ({ ...prev, descentWarning: value }))}
            label={t(K.alertThresholdDescentWarningLabel)}
            type="number"
            monospace
            disabled={!alertsEnabled}
          />
          <TextField
            value={draft.descentDanger}
            onChange={(value) => setDraft((prev) => ({ ...prev, descentDanger: value }))}
            label={t(K.alertThresholdDescentDangerLabel)}
            type="number"
            monospace
            disabled={!alertsEnabled}
          />
        </div>

        <Button
          variant="elevated"
          icon="save"
          disabled={!alertsEnabled}
          onClick={() => void handleSaveThresholds()}
        >
          {t(K.alertSettingsSaved)}
        </Button>
      </div>
    </SectionCard>
  );
}

/**
 * 告警开关的显示名。
 *
 * 复用规则引擎那张 id→i18n key 的总表（后端告警 + 前端自判的地形告警）：
 * 开关名与地图上真正弹出的告警用同一份文案，用户才对得上「我关的是哪一条」。
 * 表里查不到就退回 id 本身。
 */
function alertLabel(alertId: string, translate: (key: string) => string): string {
  const key = ALERT_MESSAGE_KEY[alertId];
  return key === undefined ? alertId : translate(key);
}
