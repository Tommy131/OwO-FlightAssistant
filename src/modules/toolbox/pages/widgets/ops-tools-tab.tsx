import { useState } from 'react';
import { useTranslate } from '../../../../core/localization/use-translate';
import { Button } from '../../../../core/widgets/common/controls';
import { MaterialIcon } from '../../../../core/widgets/common/icon';
import { EmptyState, InfoChip, SectionCard } from '../../../../core/widgets/common/surfaces';
import { ToolboxLocalizationKeys as K } from '../../localization/toolbox-localization';
import styles from './toolbox-tabs.module.css';

/**
 * 运行工具
 *
 * 对应 Flutter 版 `modules/toolbox/pages/widgets/ops_tools_tab.dart`：
 * NOTAM 关键字筛选 + 严重度分级，以及 4 张应急处置速查卡。
 */

/** NOTAM 筛选标签（与桌面版顺序一致） */
const NOTAM_TAGS = [
  'RWY',
  'ILS',
  'TWY',
  'NAV',
  'OBST',
  'WIP',
  'FUEL',
  'LIGHT',
  'CLSD',
  'CLOSED',
];

type Severity = 'high' | 'medium' | 'low';

const SEVERITY_COLOR: Record<Severity, string> = {
  high: 'var(--color-error)',
  medium: '#FF9800',
  low: 'var(--color-primary)',
};

export function OpsToolsTab() {
  return (
    <div className={styles.tab}>
      <NotamFilterCard />
      <QuickReferenceCard />
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// NOTAM 筛选
// ──────────────────────────────────────────────────────────────────────────

function NotamFilterCard() {
  const t = useTranslate();
  const [text, setText] = useState('');
  const [selectedTags, setSelectedTags] = useState<string[]>([]);
  const [matches, setMatches] = useState<string[] | null>(null);

  const toggleTag = (tag: string) => {
    setSelectedTags((prev) =>
      prev.includes(tag) ? prev.filter((item) => item !== tag) : [...prev, tag],
    );
  };

  const filter = () => {
    const lines = text
      .split('\n')
      .map((line) => line.trim())
      .filter((line) => line.length > 0);

    if (lines.length === 0) {
      setMatches([]);
      return;
    }
    // 未勾选任何标签时按全部标签匹配（与桌面版一致）
    const selected = selectedTags.length === 0 ? NOTAM_TAGS : selectedTags;
    setMatches(lines.filter((line) => selected.some((tag) => line.toUpperCase().includes(tag))));
  };

  return (
    <SectionCard title={t(K.opsNotamSectionTitle)} icon="filter_alt">
      <label className={styles.textAreaWrap}>
        <span className={styles.textAreaLabel}>{t(K.opsNotamTextLabel)}</span>
        <textarea
          className={`${styles.textArea} text-mono`}
          value={text}
          placeholder={t(K.opsNotamTextHint)}
          rows={6}
          onChange={(event) => setText(event.target.value)}
        />
      </label>

      <div className={styles.tagRow}>
        {NOTAM_TAGS.map((tag) => (
          <InfoChip
            key={tag}
            label={tag}
            solid={selectedTags.includes(tag)}
            onClick={() => toggleTag(tag)}
          />
        ))}
      </div>

      <Button variant="elevated" icon="search" onClick={filter}>
        {t(K.opsNotamFilterButton)}
      </Button>

      {matches !== null &&
        (matches.length === 0 ? (
          <EmptyState icon="search_off" title={t(K.opsNotamMatchCount, 0)} />
        ) : (
          <div className={styles.notamResult}>
            <span className={styles.resultTitle}>{t(K.opsNotamMatchCount, matches.length)}</span>
            {matches.map((line, index) => {
              const level = resolveSeverity(line);
              const color = SEVERITY_COLOR[level];
              const levelLabel =
                level === 'high'
                  ? t(K.opsSeverityHigh)
                  : level === 'medium'
                    ? t(K.opsSeverityMedium)
                    : t(K.opsSeverityLow);
              return (
                <div
                  key={`${index}-${line.slice(0, 12)}`}
                  className={styles.notamLine}
                  style={{ borderLeftColor: color }}
                >
                  <span className={styles.notamSeverity} style={{ color }}>
                    {levelLabel}
                  </span>
                  <span className={`${styles.notamText} text-mono`}>{line}</span>
                </div>
              );
            })}
          </div>
        ))}
    </SectionCard>
  );
}

/** NOTAM 严重度判定（关键字规则与桌面版逐条一致） */
function resolveSeverity(line: string): Severity {
  const upper = line.toUpperCase();

  if (upper.includes('RWY') && (upper.includes('CLSD') || upper.includes('CLOSED'))) {
    return 'high';
  }
  if (
    upper.includes('ILS') &&
    (upper.includes('U/S') ||
      upper.includes('UNSERVICEABLE') ||
      upper.includes('OUT OF SERVICE'))
  ) {
    return 'high';
  }
  if (upper.includes('CLSD') || upper.includes('CLOSED') || upper.includes('UNSERVICEABLE')) {
    return 'high';
  }
  if (upper.includes('WIP') || upper.includes('WORK') || upper.includes('LIMITED')) {
    return 'medium';
  }
  return 'low';
}

// ──────────────────────────────────────────────────────────────────────────
// 应急处置速查
// ──────────────────────────────────────────────────────────────────────────

function QuickReferenceCard() {
  const t = useTranslate();

  const cards = [
    {
      icon: 'warning',
      title: t(K.opsQuickRefStallTitle),
      trigger: t(K.opsQuickRefStallTrigger),
      actions: [
        t(K.opsQuickRefStallAction1),
        t(K.opsQuickRefStallAction2),
        t(K.opsQuickRefStallAction3),
      ],
    },
    {
      icon: 'storm',
      title: t(K.opsQuickRefWindshearTitle),
      trigger: t(K.opsQuickRefWindshearTrigger),
      actions: [
        t(K.opsQuickRefWindshearAction1),
        t(K.opsQuickRefWindshearAction2),
        t(K.opsQuickRefWindshearAction3),
      ],
    },
    {
      icon: 'flight_takeoff',
      title: t(K.opsQuickRefGoAroundTitle),
      trigger: t(K.opsQuickRefGoAroundTrigger),
      actions: [
        t(K.opsQuickRefGoAroundAction1),
        t(K.opsQuickRefGoAroundAction2),
        t(K.opsQuickRefGoAroundAction3),
      ],
    },
    {
      icon: 'local_fire_department',
      title: t(K.opsQuickRefEngineFailTitle),
      trigger: t(K.opsQuickRefEngineFailTrigger),
      actions: [
        t(K.opsQuickRefEngineFailAction1),
        t(K.opsQuickRefEngineFailAction2),
        t(K.opsQuickRefEngineFailAction3),
      ],
    },
  ];

  return (
    <SectionCard title={t(K.opsQuickRefSectionTitle)} icon="emergency">
      <div className={styles.quickRefGrid}>
        {cards.map((card) => (
          <div key={card.title} className={styles.quickRefCard}>
            <div className={styles.quickRefHead}>
              <MaterialIcon name={card.icon} filled size={18} color="var(--color-danger)" />
              <span className={styles.quickRefTitle}>{card.title}</span>
            </div>
            <span className={styles.quickRefTrigger}>{card.trigger}</span>
            <ol className={styles.quickRefActions}>
              {card.actions.map((action, index) => (
                <li key={action} className={styles.quickRefAction}>
                  <span className={styles.quickRefIndex}>{index + 1}</span>
                  {action}
                </li>
              ))}
            </ol>
          </div>
        ))}
      </div>
    </SectionCard>
  );
}
