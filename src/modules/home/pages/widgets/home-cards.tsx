import { useState } from 'react';
import { useTranslate } from '../../../../core/localization/use-translate';
import { Button, TextField } from '../../../../core/widgets/common/controls';
import {
  showAdvancedConfirmDialog,
  showLoadingDialog,
} from '../../../../core/widgets/common/dialog';
import { MaterialIcon } from '../../../../core/widgets/common/icon';
import { SnackBarHelper } from '../../../../core/widgets/common/snack-bar';
import { Card, StatusBadge } from '../../../../core/widgets/common/surfaces';
import { useFlightLogsStore } from '../../../flight_logs/providers/flight-logs-store';
import type { SimulatorType } from '../../../common/models/common-models';
import { useFlightDataStore } from '../../../common/providers/flight-data-store';
import { HomeLocalizationKeys as K } from '../../localization/home-localization';
import styles from './home-cards.module.css';

/**
 * 首页卡片组
 *
 * 对应 Flutter 版 `modules/home/pages/widgets/cards/*.dart`：
 *   - welcome_card.dart
 *   - transponder_status_widget.dart
 *   - flight_number_card.dart
 *   - simulator_connection_card.dart
 *   - checklist_phase_card.dart
 */

// ──────────────────────────────────────────────────────────────────────────
// 欢迎卡片
// ──────────────────────────────────────────────────────────────────────────

export function WelcomeCard() {
  const t = useTranslate();
  const snapshot = useFlightDataStore((s) => s.snapshot);

  const aircraft =
    snapshot.aircraftTitle ?? snapshot.flightData.aircraftDisplayName ?? undefined;

  let title: string;
  let subtitle: string;
  let icon: string;
  let tone: 'idle' | 'paused' | 'ready';

  if (!snapshot.isConnected) {
    title = t(K.welcomeNotConnectedTitle);
    subtitle = t(K.welcomeNotConnectedSubtitle);
    icon = 'link_off';
    tone = 'idle';
  } else if (snapshot.isPaused === true) {
    title = t(K.welcomePausedTitle);
    subtitle = t(K.welcomePausedSubtitle, { aircraft: aircraft ?? '--' });
    icon = 'pause_circle';
    tone = 'paused';
  } else {
    title = t(K.welcomeReadyTitle);
    subtitle = aircraft
      ? t(K.welcomeReadySubtitle, { aircraft })
      : t(K.welcomeReadySubtitleWaiting);
    icon = 'flight_takeoff';
    tone = 'ready';
  }

  return (
    <Card className={`${styles.welcomeCard} ${styles[`welcome_${tone}`]}`} padding="var(--space-lg)">
      <div className={styles.welcomeIcon}>
        <MaterialIcon name={icon} filled size={30} />
      </div>
      <div className={styles.welcomeText}>
        <h2 className={styles.welcomeTitle}>{title}</h2>
        <p className={styles.welcomeSubtitle}>{subtitle}</p>
        <span className={styles.welcomeHint}>{t(K.welcomeSupportSims)}</span>
      </div>
      <TransponderStatus />
    </Card>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 应答机状态（7700/7500/7600 紧急码高亮）
// ──────────────────────────────────────────────────────────────────────────

export function TransponderStatus() {
  const t = useTranslate();
  const code = useFlightDataStore((s) => s.snapshot.transponderCode);
  const state = useFlightDataStore((s) => s.snapshot.transponderState);
  if (!code && !state) return null;

  const normalized = (code ?? '').trim();
  let emergencyLabel: string | null = null;
  if (normalized === '7700') emergencyLabel = t(K.transponderEmergency);
  else if (normalized === '7500') emergencyLabel = t(K.transponderHijack);
  else if (normalized === '7600') emergencyLabel = t(K.transponderRadioFailure);

  return (
    <div
      className={`${styles.transponder}${emergencyLabel ? ` ${styles.transponderEmergency}` : ''}`}
      title={state}
    >
      <span className={styles.transponderPrefix}>{t(K.transponderPrefix)}</span>
      <span className={`${styles.transponderCode} text-mono`}>{normalized || '----'}</span>
      {emergencyLabel && <span className={styles.transponderLabel}>{emergencyLabel}</span>}
      {!emergencyLabel && state && <span className={styles.transponderState}>{state}</span>}
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 航班号卡片
// ──────────────────────────────────────────────────────────────────────────

/** 航班号格式：2–3 位字母航司代码 + 1–4 位数字（如 CCA1234） */
const FLIGHT_NUMBER_PATTERN = /^[A-Z]{2,3}\d{1,4}$/;

export function FlightNumberCard() {
  const t = useTranslate();
  const flightNumber = useFlightDataStore((s) => s.snapshot.flightNumber);
  const setFlightNumber = useFlightDataStore((s) => s.setFlightNumber);
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState('');
  const [error, setError] = useState<string | undefined>();

  const openEditor = async () => {
    // 已有航班号时先确认再修改（与桌面版一致）
    if (flightNumber) {
      const confirmed = await showAdvancedConfirmDialog({
        title: t(K.flightNumberDialogEditTitle),
        content: t(K.flightNumberDialogEditContent, { number: flightNumber }),
        icon: 'edit',
        confirmText: t(K.flightNumberDialogContinue),
        cancelText: t(K.flightNumberDialogCancel),
      });
      if (confirmed !== true) return;
    }
    setDraft(flightNumber ?? '');
    setError(undefined);
    setEditing(true);
  };

  const submit = async () => {
    const value = draft.trim().toUpperCase();
    if (!FLIGHT_NUMBER_PATTERN.test(value)) {
      setError(t(K.flightNumberDialogInvalid));
      return;
    }
    await setFlightNumber(value);
    setEditing(false);
    SnackBarHelper.showSuccess(value);
  };

  return (
    <Card className={styles.flightNumberCard}>
      <div className={styles.cardHead}>
        <MaterialIcon name="confirmation_number" size={17} color="var(--color-primary)" />
        <span className={styles.cardTitle}>{t(K.flightNumberTitle)}</span>
      </div>

      {editing ? (
        <div className={styles.flightNumberEditor}>
          <TextField
            value={draft}
            onChange={(value) => {
              setDraft(value.toUpperCase());
              setError(undefined);
            }}
            placeholder={t(K.flightNumberDialogInputHint)}
            hint={t(K.flightNumberDialogFormat)}
            error={error}
            monospace
            autoFocus
            onSubmit={() => void submit()}
          />
          <div className={styles.flightNumberActions}>
            <Button variant="text" size="sm" onClick={() => setEditing(false)}>
              {t(K.flightNumberDialogCancel)}
            </Button>
            <Button variant="elevated" size="sm" onClick={() => void submit()}>
              {t(K.flightNumberDialogConfirm)}
            </Button>
          </div>
        </div>
      ) : (
        <div className={styles.flightNumberBody}>
          <span
            className={
              flightNumber
                ? `${styles.flightNumberValue} text-mono`
                : styles.flightNumberPlaceholder
            }
          >
            {flightNumber ?? t(K.flightNumberEmpty)}
          </span>
          <Button
            variant="tonal"
            size="sm"
            icon={flightNumber ? 'edit' : 'add'}
            onClick={() => void openEditor()}
          >
            {flightNumber ? t(K.flightNumberEdit) : t(K.flightNumberSet)}
          </Button>
        </div>
      )}
    </Card>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 模拟器连接卡片
// ──────────────────────────────────────────────────────────────────────────

export function SimulatorConnectionCard() {
  const t = useTranslate();
  const snapshot = useFlightDataStore((s) => s.snapshot);
  const connect = useFlightDataStore((s) => s.connect);
  const disconnect = useFlightDataStore((s) => s.disconnect);
  const isRecording = useFlightLogsStore((s) => s.isRecording);
  const [connecting, setConnecting] = useState<SimulatorType | null>(null);

  const simLabel = snapshot.simulatorType === 'msfs' ? 'MSFS' : 'X-Plane';

  const handleConnect = async (type: SimulatorType) => {
    setConnecting(type);
    const loading = showLoadingDialog({
      title: t(K.simConnectingTitle, { sim: type === 'msfs' ? 'MSFS' : 'X-Plane' }),
      content: t(K.simConnectingSubtitle),
    });
    try {
      const ok = await connect(type);
      if (!ok) {
        await showAdvancedConfirmDialog({
          title: t(K.simConnectFailedTitle),
          content: snapshot.errorMessage ?? t(K.simConnectFailedContent),
          icon: 'error',
          confirmColor: 'var(--color-error)',
          confirmText: t(K.flightNumberDialogConfirm),
          cancelText: '',
        });
      }
    } finally {
      loading.close();
      setConnecting(null);
    }
  };

  return (
    <Card className={styles.simCard}>
      <div className={styles.cardHead}>
        <MaterialIcon name="cable" size={17} color="var(--color-primary)" />
        <span className={styles.cardTitle}>{t(K.simTitle)}</span>
        {isRecording && (
          <span className={styles.recordingChip}>
            <span className={styles.recordingDot} />
            {t(K.simRecording)}
          </span>
        )}
      </div>

      <div className={styles.simStatusRow}>
        <StatusBadge
          label={snapshot.isConnected ? t(K.simConnected, { sim: simLabel }) : t(K.simDisconnected)}
          tone={snapshot.isConnected ? 'success' : 'neutral'}
          pulsing={connecting !== null}
        />
      </div>

      {snapshot.isConnected ? (
        <Button variant="outlined" icon="link_off" block onClick={() => void disconnect()}>
          {t(K.simDisconnect)}
        </Button>
      ) : (
        <div className={styles.simButtons}>
          <Button
            variant="elevated"
            icon="flight"
            block
            loading={connecting === 'xplane'}
            disabled={connecting !== null}
            onClick={() => void handleConnect('xplane')}
          >
            {t(K.simConnectXplane)}
          </Button>
          <Button
            variant="outlined"
            icon="flight"
            block
            loading={connecting === 'msfs'}
            disabled={connecting !== null}
            onClick={() => void handleConnect('msfs')}
          >
            {t(K.simConnectMsfs)}
          </Button>
        </div>
      )}
    </Card>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 检查单阶段卡片
// ──────────────────────────────────────────────────────────────────────────

export function ChecklistPhaseCard() {
  const t = useTranslate();
  const phase = useFlightDataStore((s) => s.snapshot.checklistPhase);
  const progress = useFlightDataStore((s) => s.snapshot.checklistProgress ?? 0);

  return (
    <Card className={styles.checklistCard}>
      <div className={styles.cardHead}>
        <MaterialIcon name="checklist" size={17} color="var(--color-primary)" />
        <span className={styles.cardTitle}>{t(K.checklistTitle)}</span>
      </div>

      {phase ? (
        <>
          <div className={styles.checklistPhase}>
            <MaterialIcon name={phase.icon} filled size={22} color="var(--color-primary)" />
            <span className={styles.checklistPhaseLabel}>{t(phase.labelKey)}</span>
          </div>
          <div className={styles.checklistProgressRow}>
            <div className={styles.checklistProgressTrack}>
              <div
                className={styles.checklistProgressFill}
                style={{ width: `${Math.round(progress * 100)}%` }}
              />
            </div>
            <span className={styles.checklistProgressValue}>
              {Math.round(progress * 100)}%
            </span>
          </div>
        </>
      ) : (
        <div className={styles.checklistEmpty}>
          <MaterialIcon name="pending" size={22} color="var(--color-on-surface-a40)" />
          <span>{t(K.checklistEmpty)}</span>
        </div>
      )}
    </Card>
  );
}
