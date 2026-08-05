import { useEffect, useRef, useState } from 'react';
import { useTranslate } from '../../../core/localization/use-translate';
import { useWindowWidth } from '../../../core/layouts/responsive';
import {
  Button,
  Checkbox,
  IconButton,
  PopupMenu,
  Select,
} from '../../../core/widgets/common/controls';
import { showAdvancedConfirmDialog } from '../../../core/widgets/common/dialog';
import { MaterialIcon } from '../../../core/widgets/common/icon';
import { SnackBarHelper } from '../../../core/widgets/common/snack-bar';
import { EmptyState } from '../../../core/widgets/common/surfaces';
import { ChecklistLocalizationKeys as K } from '../localization/checklist-localization';
import {
  CHECKLIST_PHASES,
  findSection,
  PHASE_ICON,
  PHASE_LABEL_KEY,
  type ChecklistItem,
  type ChecklistPhase,
} from '../models/flight-checklist';
import { refreshResultMessage, useChecklistStore } from '../providers/checklist-store';
import { isAutoCheckable } from '../services/checklist-auto-check';
import styles from './checklist-page.module.css';

/**
 * 检查单页面
 *
 * 对应 Flutter 版 `modules/checklist/pages/checklist_page.dart` 及 widgets/ 下 8 个组件：
 * 左侧阶段导航（<900px 时折叠为顶部横向步进条）+ 右侧检查单卡片（头/条目列表/底部操作）。
 */
export function ChecklistPage() {
  const t = useTranslate();
  const width = useWindowWidth();
  const isCompact = width < 900;

  const isLoading = useChecklistStore((s) => s.isLoading);
  const selectedAircraft = useChecklistStore((s) => s.selectedAircraft);
  const init = useChecklistStore((s) => s.init);
  const initialized = useRef(false);

  useEffect(() => {
    if (initialized.current) return;
    initialized.current = true;
    void init();
  }, [init]);

  if (isLoading) {
    return (
      <div className={styles.centered}>
        <div className={styles.spinner} />
      </div>
    );
  }

  if (!selectedAircraft) {
    return (
      <div className={styles.centered}>
        <EmptyState icon="checklist" title={t(K.emptyState)} />
      </div>
    );
  }

  return (
    <div className={`${styles.page}${isCompact ? ` ${styles.pageCompact}` : ''}`}>
      <ChecklistSidebar isCompact={isCompact} />
      <div className={styles.card}>
        <ChecklistHeader />
        <ChecklistItemsList />
        <ChecklistFooter />
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 阶段导航（侧栏 / 折叠态横向步进条）
// ──────────────────────────────────────────────────────────────────────────

function ChecklistSidebar({ isCompact }: { isCompact: boolean }) {
  const t = useTranslate();
  const currentPhase = useChecklistStore((s) => s.currentPhase);
  const selectedAircraft = useChecklistStore((s) => s.selectedAircraft);
  const setPhase = useChecklistStore((s) => s.setPhase);
  const getPhaseProgress = useChecklistStore((s) => s.getPhaseProgress);

  // 只展示当前机型实际拥有的阶段
  const phases = CHECKLIST_PHASES.filter((phase) => findSection(selectedAircraft, phase));
  const currentIndex = phases.indexOf(currentPhase);

  if (isCompact) {
    // 折叠态：上一步 / 当前 / 下一步 三段式步进条
    const previous = currentIndex > 0 ? phases[currentIndex - 1] : null;
    const next = currentIndex >= 0 && currentIndex < phases.length - 1 ? phases[currentIndex + 1] : null;

    return (
      <div className={styles.compactStepper}>
        <button
          type="button"
          className={styles.stepperSide}
          disabled={!previous}
          onClick={() => previous && setPhase(previous)}
        >
          <MaterialIcon name="chevron_left" size={18} />
          <span className={styles.stepperSideLabel}>
            {previous ? t(PHASE_LABEL_KEY[previous]) : t(K.compactStepPrevious)}
          </span>
        </button>

        <div className={styles.stepperCurrent}>
          <MaterialIcon
            name={PHASE_ICON[currentPhase]}
            filled
            size={18}
            color="var(--color-primary)"
          />
          <span className={styles.stepperCurrentLabel}>{t(PHASE_LABEL_KEY[currentPhase])}</span>
          <span className={styles.stepperProgress}>
            {Math.round(getPhaseProgress(currentPhase) * 100)}%
          </span>
        </div>

        <button
          type="button"
          className={styles.stepperSide}
          disabled={!next}
          onClick={() => next && setPhase(next)}
        >
          <span className={styles.stepperSideLabel}>
            {next ? t(PHASE_LABEL_KEY[next]) : t(K.compactStepNext)}
          </span>
          <MaterialIcon name="chevron_right" size={18} />
        </button>
      </div>
    );
  }

  return (
    <nav className={styles.sidebar} aria-label={t(K.sidebarTitle)}>
      <div className={styles.sidebarTitle}>{t(K.sidebarTitle)}</div>
      <div className={`${styles.phaseList} scroll-area`}>
        {phases.map((phase) => (
          <PhaseNavItem
            key={phase}
            phase={phase}
            isSelected={phase === currentPhase}
            progress={getPhaseProgress(phase)}
            onSelect={() => setPhase(phase)}
          />
        ))}
      </div>
    </nav>
  );
}

function PhaseNavItem({
  phase,
  isSelected,
  progress,
  onSelect,
}: {
  phase: ChecklistPhase;
  isSelected: boolean;
  progress: number;
  onSelect: () => void;
}) {
  const t = useTranslate();
  const isComplete = progress >= 1;
  const percent = Math.round(progress * 100);

  return (
    <button
      type="button"
      onClick={onSelect}
      aria-current={isSelected ? 'true' : undefined}
      className={`${styles.phaseItem}${isSelected ? ` ${styles.phaseItemSelected}` : ''}`}
    >
      <span className={styles.phaseIconWrap}>
        <MaterialIcon
          name={isComplete ? 'check_circle' : PHASE_ICON[phase]}
          filled={isSelected || isComplete}
          size={18}
          color={isComplete ? 'var(--color-success)' : undefined}
        />
      </span>
      <span className={styles.phaseLabel}>{t(PHASE_LABEL_KEY[phase])}</span>
      <span className={styles.phasePercent}>{percent}%</span>
      <span className={styles.phaseProgressTrack}>
        <span
          className={styles.phaseProgressFill}
          style={{
            width: `${percent}%`,
            background: isComplete ? 'var(--color-success)' : 'var(--color-primary)',
          }}
        />
      </span>
    </button>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 头部：机型选择 + 当前阶段
// ──────────────────────────────────────────────────────────────────────────

function ChecklistHeader() {
  const t = useTranslate();
  const aircraftList = useChecklistStore((s) => s.aircraftList);
  const selectedAircraft = useChecklistStore((s) => s.selectedAircraft);
  const currentPhase = useChecklistStore((s) => s.currentPhase);
  const selectAircraft = useChecklistStore((s) => s.selectAircraft);
  const getPhaseProgress = useChecklistStore((s) => s.getPhaseProgress);

  const progress = getPhaseProgress(currentPhase);

  return (
    <header className={styles.header}>
      <div className={styles.headerPhase}>
        <MaterialIcon
          name={PHASE_ICON[currentPhase]}
          filled
          size={22}
          color="var(--color-primary)"
        />
        <div className={styles.headerPhaseText}>
          <span className={styles.headerPhaseLabel}>{t(K.currentPhase)}</span>
          <span className={styles.headerPhaseName}>{t(PHASE_LABEL_KEY[currentPhase])}</span>
        </div>
      </div>

      <div className={styles.headerProgress}>
        <span className={styles.headerProgressValue}>{Math.round(progress * 100)}%</span>
        <span className={styles.headerProgressTrack}>
          <span
            className={styles.headerProgressFill}
            style={{ width: `${Math.round(progress * 100)}%` }}
          />
        </span>
      </div>

      <Select
        value={selectedAircraft?.id ?? ''}
        options={aircraftList.map((aircraft) => ({
          value: aircraft.id,
          label: aircraft.name,
        }))}
        onChange={selectAircraft}
        icon="flight"
        label={t(K.selectAircraft)}
        className={styles.headerSelect}
      />
    </header>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 条目列表
// ──────────────────────────────────────────────────────────────────────────

function ChecklistItemsList() {
  const t = useTranslate();
  const selectedAircraft = useChecklistStore((s) => s.selectedAircraft);
  const currentPhase = useChecklistStore((s) => s.currentPhase);
  const toggleItem = useChecklistStore((s) => s.toggleItem);
  const autoCheckedIds = useChecklistStore((s) => s.autoCheckedIds);
  const manualOverrideIds = useChecklistStore((s) => s.manualOverrideIds);
  const releaseManualOverride = useChecklistStore((s) => s.releaseManualOverride);

  const section = findSection(selectedAircraft, currentPhase);

  if (!section || section.items.length === 0) {
    return (
      <div className={styles.itemsEmpty}>
        <EmptyState icon="playlist_remove" title={t(K.emptyPhase)} />
      </div>
    );
  }

  return (
    <div className={`${styles.items} scroll-area`}>
      {section.items.map((item, index) => (
        <ChecklistItemTile
          key={item.id}
          item={item}
          index={index + 1}
          isAutoChecked={autoCheckedIds.has(item.id)}
          // 遥测能管、但用户手动改过 → 显示「手动」，点一下交还给遥测
          isManualOverride={isAutoCheckable(item.id) && manualOverrideIds.has(item.id)}
          onToggle={() => toggleItem(item.id)}
          onReleaseOverride={() => releaseManualOverride(item.id)}
        />
      ))}
    </div>
  );
}

function ChecklistItemTile({
  item,
  index,
  isAutoChecked,
  isManualOverride,
  onToggle,
  onReleaseOverride,
}: {
  item: ChecklistItem;
  index: number;
  isAutoChecked: boolean;
  isManualOverride: boolean;
  onToggle: () => void;
  onReleaseOverride: () => void;
}) {
  const t = useTranslate();

  return (
    <div className={`${styles.itemTile}${item.isChecked ? ` ${styles.itemTileChecked}` : ''}`}>
      <span className={styles.itemIndex}>{String(index).padStart(2, '0')}</span>
      <Checkbox checked={item.isChecked} onChange={onToggle} />
      <button type="button" className={styles.itemBody} onClick={onToggle}>
        <span className={styles.itemTask}>
          {item.task}
          {/* 让飞行员一眼分清哪些是模拟器同步来的、哪些是自己勾的 */}
          {isAutoChecked && (
            <span className={styles.autoBadge} title={t(K.autoCheckedHint)}>
              <MaterialIcon name="sensors" size={11} />
              {t(K.autoChecked)}
            </span>
          )}
        </span>
        {item.detail && <span className={styles.itemDetail}>{item.detail}</span>}
      </button>
      {/*
        末列固定宽度保证各行右边缘对齐，所以角标和响应值要共用这一格，
        不能各占一列 —— 多一列会把栅格撑成 5 列。
      */}
      <span className={styles.itemTrailing}>
        {/*
          手动接管的条目给一个可点的角标：一旦手动点过，这条就永远脱离
          遥测同步，不给入口就只能整份重置才拿得回来。
          放在 itemBody 外面，避免嵌套 button，也避免点它顺带切换条目。
        */}
        {isManualOverride && (
          <button
            type="button"
            className={styles.manualBadge}
            onClick={onReleaseOverride}
            title={t(K.manualOverrideHint)}
          >
            <MaterialIcon name="back_hand" size={11} />
            {t(K.manualOverride)}
          </button>
        )}
        <span className={styles.itemResponse}>{item.response}</span>
      </span>
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 底部操作栏：重置 + 文件操作
// ──────────────────────────────────────────────────────────────────────────

function ChecklistFooter() {
  const t = useTranslate();
  const resetCurrentPhase = useChecklistStore((s) => s.resetCurrentPhase);
  const resetAll = useChecklistStore((s) => s.resetAll);
  const reload = useChecklistStore((s) => s.reload);
  const importFromFile = useChecklistStore((s) => s.importFromFile);
  const exportToFile = useChecklistStore((s) => s.exportToFile);
  const [busy, setBusy] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleResetPhase = async () => {
    const confirmed = await showAdvancedConfirmDialog({
      title: t(K.resetPhaseConfirmTitle),
      content: t(K.resetPhaseConfirmContent),
      icon: 'restart_alt',
      confirmText: t(K.resetPhase),
      cancelText: t(K.more),
    });
    if (confirmed !== true) return;
    resetCurrentPhase();
    SnackBarHelper.showSuccess(t(K.resetPhaseSuccess));
  };

  const handleResetAll = async () => {
    const confirmed = await showAdvancedConfirmDialog({
      title: t(K.resetAllConfirmTitle),
      content: t(K.resetAllConfirmContent),
      icon: 'restart_alt',
      confirmColor: 'var(--color-danger)',
      confirmText: t(K.resetAll),
      cancelText: t(K.more),
    });
    if (confirmed !== true) return;
    resetAll();
    SnackBarHelper.showSuccess(t(K.resetAllSuccess));
  };

  const handleRefresh = async () => {
    setBusy(true);
    try {
      const count = await reload(true);
      SnackBarHelper.showInfo(refreshResultMessage(count));
    } catch {
      SnackBarHelper.showError(t(K.refreshFailed));
    } finally {
      setBusy(false);
    }
  };

  const handleImport = async (file: File) => {
    setBusy(true);
    try {
      const count = await importFromFile(file);
      if (count > 0) SnackBarHelper.showSuccess(t(K.importSuccess));
      else SnackBarHelper.showError(t(K.importFailed));
    } catch {
      SnackBarHelper.showError(t(K.importFailed));
    } finally {
      setBusy(false);
    }
  };

  const handleExport = () => {
    const result = exportToFile();
    if (result === 1) SnackBarHelper.showSuccess(t(K.exportSuccess));
    else SnackBarHelper.showError(t(K.exportFailed));
  };

  return (
    <footer className={styles.footer}>
      <Button variant="text" size="sm" icon="restart_alt" onClick={() => void handleResetPhase()}>
        {t(K.resetPhase)}
      </Button>
      <Button variant="text" size="sm" icon="delete_sweep" onClick={() => void handleResetAll()}>
        {t(K.resetAll)}
      </Button>

      <div className={styles.footerSpacer} />

      <IconButton
        icon="refresh"
        label={t(K.refresh)}
        disabled={busy}
        onClick={() => void handleRefresh()}
      />
      <PopupMenu
        icon="more_vert"
        label={t(K.more)}
        items={[
          {
            key: 'import',
            label: t(K.importFile),
            icon: 'upload_file',
            onSelect: () => fileInputRef.current?.click(),
          },
          {
            key: 'export',
            label: t(K.exportFile),
            icon: 'download',
            onSelect: handleExport,
          },
        ]}
      />

      {/* 浏览器无 file_picker，用隐藏 input 承接导入 */}
      <input
        ref={fileInputRef}
        type="file"
        accept=".json,.txt,.csv"
        className="sr-only"
        onChange={(event) => {
          const file = event.target.files?.[0];
          event.target.value = '';
          if (file) void handleImport(file);
        }}
      />
    </footer>
  );
}
