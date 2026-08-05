import { useEffect, useRef, useState } from 'react';
import { useTranslate } from '../../../core/localization/use-translate';
import {
  Button,
  IconButton,
  SegmentedControl,
  Select,
  TextField,
} from '../../../core/widgets/common/controls';
import { showAdvancedConfirmDialog } from '../../../core/widgets/common/dialog';
import { MaterialIcon } from '../../../core/widgets/common/icon';
import { SnackBarHelper } from '../../../core/widgets/common/snack-bar';
import { EmptyState, SectionCard } from '../../../core/widgets/common/surfaces';
import { BriefingLocalizationKeys as K } from '../localization/briefing-localization';
import type { BriefingRecord } from '../models/briefing-models';
import { useBriefingStore } from '../providers/briefing-store';
import {
  ICAO_PATTERN,
  runwayEndOptions,
  useAirportResolution,
  type AirportResolution,
} from '../services/airport-resolver';
import styles from './briefing-page.module.css';

/**
 * 飞行简报页面
 *
 * 对应 Flutter 版 `modules/briefing/pages/{briefing_page,briefing_generate_page,briefing_history_page}.dart`：
 * 生成 / 历史 两个视图，通过顶部分段控件切换。
 */
type BriefingView = 'generate' | 'history';

/** 航班号：2–3 位字母 + 1–4 位数字 */
const FLIGHT_NUMBER_PATTERN = /^[A-Z]{2,3}\d{1,4}$/;

export function BriefingPage() {
  const t = useTranslate();
  const [view, setView] = useState<BriefingView>('generate');
  const init = useBriefingStore((s) => s.init);
  const importRecords = useBriefingStore((s) => s.importRecords);
  const initialized = useRef(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (initialized.current) return;
    initialized.current = true;
    void init();
  }, [init]);

  const handleImport = async (file: File) => {
    try {
      const count = await importRecords(file);
      if (count > 0) SnackBarHelper.showSuccess(t(K.importSuccess));
      else SnackBarHelper.showError(t(K.importFailed));
    } catch {
      SnackBarHelper.showError(t(K.importFailed));
    }
  };

  return (
    <div className={styles.page}>
      <div className={styles.viewBar}>
        <SegmentedControl
          value={view}
          options={[
            { value: 'generate', label: t(K.generateTitle), icon: 'auto_awesome' },
            { value: 'history', label: t(K.historyTitle), icon: 'history' },
          ]}
          onChange={setView}
        />
        <div className={styles.viewBarSpacer} />
        <IconButton
          icon="upload_file"
          label={t(K.importFile)}
          onClick={() => fileInputRef.current?.click()}
        />
        <input
          ref={fileInputRef}
          type="file"
          accept=".json,.txt"
          className="sr-only"
          onChange={(event) => {
            const file = event.target.files?.[0];
            event.target.value = '';
            if (file) void handleImport(file);
          }}
        />
      </div>

      <div className={`${styles.content} scroll-area`}>
        {view === 'generate' ? <GenerateView /> : <HistoryView />}
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 生成视图
// ──────────────────────────────────────────────────────────────────────────

function GenerateView() {
  const t = useTranslate();
  const isLoading = useBriefingStore((s) => s.isLoading);
  const latest = useBriefingStore((s) => s.latest);
  const errorMessage = useBriefingStore((s) => s.errorMessage);
  const generateBriefing = useBriefingStore((s) => s.generateBriefing);
  const exportRecord = useBriefingStore((s) => s.exportRecord);
  const exportRecordJson = useBriefingStore((s) => s.exportRecordJson);

  const [form, setForm] = useState({
    departure: '',
    arrival: '',
    alternate: '',
    flightNumber: '',
    route: '',
    cruiseAltitude: '35000',
    departureRunway: '',
    arrivalRunway: '',
    alternateRunway: '',
  });
  const [errors, setErrors] = useState<Partial<Record<keyof typeof form, string>>>({});

  // 三个机场各自实时解析：拿到名称供核对，拿到跑道供下拉选择
  const departureAirport = useAirportResolution(form.departure);
  const arrivalAirport = useAirportResolution(form.arrival);
  const alternateAirport = useAirportResolution(form.alternate);

  const update = (key: keyof typeof form) => (value: string) => {
    // ICAO/航班号/跑道统一转大写，与桌面版输入行为一致
    const upperKeys: (keyof typeof form)[] = [
      'departure',
      'arrival',
      'alternate',
      'flightNumber',
      'route',
      'departureRunway',
      'arrivalRunway',
      'alternateRunway',
    ];
    setForm((prev) => {
      const next = {
        ...prev,
        [key]: upperKeys.includes(key) ? value.toUpperCase() : value,
      };
      // 换了机场，原来选的跑道就不属于这个机场了，必须清掉
      if (key === 'departure') next.departureRunway = '';
      if (key === 'arrival') next.arrivalRunway = '';
      if (key === 'alternate') next.alternateRunway = '';
      return next;
    });
    setErrors((prev) => ({ ...prev, [key]: undefined }));
  };

  const validate = (): boolean => {
    const next: Partial<Record<keyof typeof form, string>> = {};

    // 格式对还不够，还得在机场库里真的查得到 ——
    // 否则要等生成时才报一个笼统的失败，用户不知道是哪个码有问题。
    // requiredField / invalidIcao 的文案里带一个 {} 占位符，要把字段名填进去
    const airportError = (
      value: string,
      resolution: AirportResolution,
      required: boolean,
      fieldLabel: string,
    ): string | undefined => {
      if (value.length === 0) return required ? t(K.requiredField, fieldLabel) : undefined;
      if (!ICAO_PATTERN.test(value)) return t(K.invalidIcao, fieldLabel);
      if (resolution.status === 'notFound') return t(K.airportNotFound);
      if (resolution.status === 'loading') return t(K.airportResolving);
      // 后端不可达时不拦着生成：机场库只是用来帮忙核对的，
      // 拿不到就退回纯格式校验，不能因为中间件掉线就没法出简报。
      return undefined;
    };

    next.departure = airportError(form.departure, departureAirport, true, t(K.fieldDeparture));
    next.arrival = airportError(form.arrival, arrivalAirport, true, t(K.fieldArrival));
    next.alternate = airportError(form.alternate, alternateAirport, false, t(K.fieldAlternate));
    if (form.flightNumber.length > 0 && !FLIGHT_NUMBER_PATTERN.test(form.flightNumber)) {
      next.flightNumber = t(K.invalidFlightNumber);
    }

    const cruise = Number.parseInt(form.cruiseAltitude, 10);
    if (!Number.isFinite(cruise) || cruise < 1000 || cruise > 60000) {
      next.cruiseAltitude = t(K.invalidCruiseAltitude);
    }

    setErrors(next);
    return Object.values(next).every((message) => message === undefined);
  };

  const submit = async () => {
    if (!validate()) return;
    const ok = await generateBriefing({
      departure: form.departure,
      arrival: form.arrival,
      alternate: form.alternate.length > 0 ? form.alternate : undefined,
      flightNumber: form.flightNumber.length > 0 ? form.flightNumber : undefined,
      route: form.route.length > 0 ? form.route : undefined,
      cruiseAltitude: Number.parseInt(form.cruiseAltitude, 10),
      departureRunway: form.departureRunway.length > 0 ? form.departureRunway : undefined,
      arrivalRunway: form.arrivalRunway.length > 0 ? form.arrivalRunway : undefined,
      alternateRunway: form.alternateRunway.length > 0 ? form.alternateRunway : undefined,
    });
    if (!ok) SnackBarHelper.showError(t(K.airportValidateFailed));
  };

  const copyContent = async () => {
    if (!latest) return;
    await navigator.clipboard.writeText(latest.content);
    SnackBarHelper.showSuccess(t(K.copySuccess));
  };

  return (
    <div className={styles.generateGrid}>
      <SectionCard title={t(K.inputTitle)} icon="edit_note" subtitle={t(K.generateSubtitle)}>
        <div className={styles.formGrid}>
          <AirportField
            value={form.departure}
            onChange={update('departure')}
            label={t(K.fieldDeparture)}
            error={errors.departure}
            resolution={departureAirport}
          />
          <AirportField
            value={form.arrival}
            onChange={update('arrival')}
            label={t(K.fieldArrival)}
            error={errors.arrival}
            resolution={arrivalAirport}
          />
          <AirportField
            value={form.alternate}
            onChange={update('alternate')}
            label={t(K.fieldAlternate)}
            error={errors.alternate}
            resolution={alternateAirport}
          />
          <TextField
            value={form.flightNumber}
            onChange={update('flightNumber')}
            label={t(K.fieldFlightNumber)}
            placeholder={t(K.fieldFlightNumberHint)}
            error={errors.flightNumber}
            monospace
          />
          <TextField
            value={form.route}
            onChange={update('route')}
            label={t(K.fieldRoute)}
            placeholder={t(K.fieldRouteHint)}
            monospace
          />
          <TextField
            value={form.cruiseAltitude}
            onChange={update('cruiseAltitude')}
            label={t(K.fieldCruiseAltitude)}
            placeholder={t(K.fieldCruiseAltitudeHint)}
            type="number"
            error={errors.cruiseAltitude}
            monospace
          />
          <RunwayField
            value={form.departureRunway}
            onChange={update('departureRunway')}
            label={t(K.fieldDepartureRunway)}
            resolution={departureAirport}
          />
          <RunwayField
            value={form.arrivalRunway}
            onChange={update('arrivalRunway')}
            label={t(K.fieldArrivalRunway)}
            resolution={arrivalAirport}
          />
          <RunwayField
            value={form.alternateRunway}
            onChange={update('alternateRunway')}
            label={t(K.fieldAlternateRunway)}
            resolution={alternateAirport}
          />
        </div>

        <Button
          variant="elevated"
          icon="auto_awesome"
          block
          loading={isLoading}
          onClick={() => void submit()}
        >
          {t(K.generateAction)}
        </Button>

        {errorMessage && (
          <div className={styles.errorBanner}>
            <MaterialIcon name="error" size={17} color="var(--color-error)" />
            <span>{errorMessage}</span>
          </div>
        )}
      </SectionCard>


      <SectionCard
        title={t(K.outputTitle)}
        icon="description"
        trailing={
          latest && (
            <div className={styles.outputActions}>
              <IconButton
                icon="content_copy"
                label={t(K.copySuccess)}
                onClick={() => void copyContent()}
              />
              <IconButton
                icon="description"
                label={`${t(K.exportFile)} (TXT)`}
                onClick={() => exportRecord(latest)}
              />
              <IconButton
                icon="download"
                label={`${t(K.exportFile)} (JSON)`}
                onClick={() => exportRecordJson(latest)}
              />
            </div>
          )
        }
      >
        {latest ? (
          <>
            <span className={styles.outputTitle}>{latest.title}</span>
            <pre className={`${styles.outputContent} text-mono`}>{latest.content}</pre>
          </>
        ) : (
          <EmptyState icon="description" title={t(K.outputEmpty)} />
        )}
      </SectionCard>
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 机场 / 跑道输入
// ──────────────────────────────────────────────────────────────────────────

/**
 * 机场 ICAO 输入框
 *
 * 边输边查后端机场库：查到了在下方显示机场名供核对，
 * 查不到当场标红 —— 不用等到点「生成」才发现码打错了。
 */
function AirportField({
  value,
  onChange,
  label,
  error,
  resolution,
}: {
  value: string;
  onChange: (value: string) => void;
  label: string;
  error?: string;
  resolution: AirportResolution;
}) {
  const t = useTranslate();

  const hint = (() => {
    if (error) return undefined; // 有错误时错误信息优先
    switch (resolution.status) {
      case 'loading':
        return t(K.airportResolving);
      case 'found':
        return resolution.airport?.name;
      case 'notFound':
        return t(K.airportNotFound);
      case 'error':
        return t(K.airportLookupFailed);
      default:
        return undefined;
    }
  })();

  return (
    <TextField
      value={value}
      onChange={onChange}
      label={label}
      placeholder={t(K.fieldIcaoHint)}
      error={error}
      hint={hint}
      icon="flight_takeoff"
      monospace
    />
  );
}

/**
 * 跑道选择
 *
 * 选项来自上面那个输入框刚解析出来的机场，机场没落实之前是禁用的 ——
 * 这样跑道号不可能填成一个该机场根本没有的方向。
 */
function RunwayField({
  value,
  onChange,
  label,
  resolution,
}: {
  value: string;
  onChange: (value: string) => void;
  label: string;
  resolution: AirportResolution;
}) {
  const t = useTranslate();
  const ends = runwayEndOptions(resolution.airport);
  const ready = resolution.status === 'found' && ends.length > 0;

  const placeholder = (() => {
    if (resolution.status === 'found') return t(K.runwayNoData);
    return t(K.runwayNeedAirport);
  })();

  return (
    <Select
      value={value}
      onChange={onChange}
      label={label}
      icon="signpost"
      disabled={!ready}
      options={[
        // 空值＝不指定跑道，交给简报生成时自行推荐
        { value: '', label: ready ? t(K.runwayAutoOption) : placeholder },
        ...ends.map((end) => ({
          value: end.ident,
          label: end.detail ? `${end.ident} · ${end.detail}` : end.ident,
        })),
      ]}
    />
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 历史视图
// ──────────────────────────────────────────────────────────────────────────

function HistoryView() {
  const t = useTranslate();
  const history = useBriefingStore((s) => s.history);
  const latest = useBriefingStore((s) => s.latest);
  const selectRecord = useBriefingStore((s) => s.selectRecord);
  const deleteRecord = useBriefingStore((s) => s.deleteRecord);
  const exportRecord = useBriefingStore((s) => s.exportRecord);

  const handleDelete = async (record: BriefingRecord) => {
    const confirmed = await showAdvancedConfirmDialog({
      title: t(K.deleteConfirmTitle),
      content: t(K.deleteConfirmContent),
      icon: 'delete',
      confirmColor: 'var(--color-danger)',
      confirmText: t(K.deleteAction),
      cancelText: t(K.refresh),
    });
    if (confirmed !== true) return;
    await deleteRecord(record.createdAt);
    SnackBarHelper.showSuccess(t(K.deleteSuccess));
  };

  if (history.length === 0) {
    return (
      <SectionCard title={t(K.historyTitle)} icon="history" subtitle={t(K.historySubtitle)}>
        <EmptyState icon="inbox" title={t(K.historyEmpty)} />
      </SectionCard>
    );
  }

  return (
    <div className={styles.historyGrid}>
      <SectionCard
        title={t(K.historyTitle)}
        icon="history"
        subtitle={t(K.historySubtitle)}
        trailing={<span className={styles.countBadge}>{history.length}</span>}
      >
        <div className={styles.historyList}>
          {history.map((record) => {
            const selected = latest?.createdAt.getTime() === record.createdAt.getTime();
            return (
              <div
                key={record.createdAt.toISOString()}
                className={`${styles.historyItem}${selected ? ` ${styles.historyItemSelected}` : ''}`}
              >
                <button
                  type="button"
                  className={styles.historyMain}
                  onClick={() => selectRecord(record)}
                >
                  <span className={styles.historyTitle}>{record.title}</span>
                  <span className={styles.historyTime}>{formatDateTime(record.createdAt)}</span>
                </button>
                <IconButton
                  icon="download"
                  label={t(K.exportFile)}
                  onClick={() => exportRecord(record)}
                />
                <IconButton
                  icon="delete"
                  label={t(K.deleteAction)}
                  onClick={() => void handleDelete(record)}
                />
              </div>
            );
          })}
        </div>
      </SectionCard>

      <SectionCard title={t(K.outputTitle)} icon="description">
        {latest ? (
          <pre className={`${styles.outputContent} text-mono`}>{latest.content}</pre>
        ) : (
          <EmptyState icon="description" title={t(K.outputEmpty)} />
        )}
      </SectionCard>
    </div>
  );
}

function formatDateTime(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
}
