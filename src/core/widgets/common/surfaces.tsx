import type { CSSProperties, ReactNode } from 'react';
import { MaterialIcon } from './icon';
import styles from './surfaces.module.css';

/**
 * 通用「面」类组件
 *
 * 对应 Flutter 版散落在各模块的 Card / Chip / Badge 封装：
 *   - core/theme 的 cardTheme（0 elevation + 1px 描边 + 12 圆角）
 *   - modules/home/pages/widgets/shared/{data_card,info_chip,status_badge}.dart
 *   - modules/toolbox/.../toolbox_section_card.dart
 *   - modules/map/.../settings/map_settings_section_card.dart
 */

// ──────────────────────────────────────────────────────────────────────────
// Card
// ──────────────────────────────────────────────────────────────────────────

export interface CardProps {
  children: ReactNode;
  /** 内边距，默认 16px */
  padding?: number | string;
  className?: string;
  style?: CSSProperties;
  /** 悬浮抬升效果 */
  interactive?: boolean;
  onClick?: () => void;
}

export function Card({
  children,
  padding = 'var(--space-md)',
  className,
  style,
  interactive = false,
  onClick,
}: CardProps) {
  const classNames = [styles.card, interactive ? styles.cardInteractive : '', className]
    .filter(Boolean)
    .join(' ');

  if (onClick) {
    return (
      <button type="button" className={classNames} style={{ padding, ...style }} onClick={onClick}>
        {children}
      </button>
    );
  }
  return (
    <div className={classNames} style={{ padding, ...style }}>
      {children}
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// SectionCard：带标题栏的分区卡片
// ──────────────────────────────────────────────────────────────────────────

export interface SectionCardProps {
  title: string;
  /** Material Symbols 图标名 */
  icon?: string;
  subtitle?: string;
  /** 标题行右侧的操作区 */
  trailing?: ReactNode;
  children: ReactNode;
  className?: string;
  style?: CSSProperties;
  /** 内容区去掉内边距（表格/地图等需要贴边的场景） */
  flush?: boolean;
}

export function SectionCard({
  title,
  icon,
  subtitle,
  trailing,
  children,
  className,
  style,
  flush = false,
}: SectionCardProps) {
  return (
    <section
      className={[styles.card, styles.sectionCard, className].filter(Boolean).join(' ')}
      style={style}
    >
      <header className={styles.sectionHeader}>
        {icon && <MaterialIcon name={icon} size={18} color="var(--color-primary)" />}
        <div className={styles.sectionTitles}>
          <h3 className={styles.sectionTitle}>{title}</h3>
          {subtitle && <p className={styles.sectionSubtitle}>{subtitle}</p>}
        </div>
        {trailing && <div className={styles.sectionTrailing}>{trailing}</div>}
      </header>
      <div className={flush ? undefined : styles.sectionBody}>{children}</div>
    </section>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// DataCard：仪表盘数值卡片（label + value + unit）
// ──────────────────────────────────────────────────────────────────────────

export interface DataCardProps {
  label: string;
  value: string;
  unit?: string;
  icon?: string;
  /** 强调色，用于告警态 */
  accentColor?: string;
  /** 次要说明 */
  hint?: string;
  className?: string;
}

export function DataCard({
  label,
  value,
  unit,
  icon,
  accentColor,
  hint,
  className,
}: DataCardProps) {
  return (
    <div className={[styles.dataCard, className].filter(Boolean).join(' ')}>
      <div className={styles.dataCardHead}>
        {icon && (
          <MaterialIcon
            name={icon}
            size={14}
            color={accentColor ?? 'var(--color-text-secondary)'}
          />
        )}
        <span className={styles.dataCardLabel}>{label}</span>
      </div>
      <div className={styles.dataCardValueRow}>
        <span
          className={`${styles.dataCardValue} text-mono`}
          style={accentColor ? { color: accentColor } : undefined}
        >
          {value}
        </span>
        {unit && <span className={styles.dataCardUnit}>{unit}</span>}
      </div>
      {hint && <span className={styles.dataCardHint}>{hint}</span>}
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// InfoChip：图标 + 文本的小胶囊
// ──────────────────────────────────────────────────────────────────────────

export interface InfoChipProps {
  label: string;
  icon?: string;
  color?: string;
  /** 实心背景（默认为半透明底 + 彩色文字） */
  solid?: boolean;
  onClick?: () => void;
  title?: string;
  className?: string;
}

export function InfoChip({
  label,
  icon,
  color = 'var(--color-primary)',
  solid = false,
  onClick,
  title,
  className,
}: InfoChipProps) {
  const content = (
    <>
      {icon && <MaterialIcon name={icon} size={13} color={solid ? '#fff' : color} />}
      <span>{label}</span>
    </>
  );
  const style: CSSProperties = solid
    ? { background: color, color: '#fff', borderColor: color }
    : { color, borderColor: color, background: 'color-mix(in srgb, currentColor 12%, transparent)' };

  if (onClick) {
    return (
      <button
        type="button"
        title={title}
        className={[styles.chip, styles.chipClickable, className].filter(Boolean).join(' ')}
        style={style}
        onClick={onClick}
      >
        {content}
      </button>
    );
  }
  return (
    <span
      title={title}
      className={[styles.chip, className].filter(Boolean).join(' ')}
      style={style}
    >
      {content}
    </span>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// StatusBadge：状态圆点 + 文案
// ──────────────────────────────────────────────────────────────────────────

export type StatusTone = 'neutral' | 'success' | 'warning' | 'danger' | 'info';

const STATUS_TONE_COLOR: Record<StatusTone, string> = {
  neutral: 'var(--color-text-secondary)',
  success: 'var(--color-success)',
  warning: 'var(--color-warning)',
  danger: 'var(--color-danger)',
  info: 'var(--color-primary)',
};

export interface StatusBadgeProps {
  label: string;
  tone?: StatusTone;
  /** 呼吸动画（用于「连接中」等进行态） */
  pulsing?: boolean;
  className?: string;
}

export function StatusBadge({
  label,
  tone = 'neutral',
  pulsing = false,
  className,
}: StatusBadgeProps) {
  const color = STATUS_TONE_COLOR[tone];
  return (
    <span
      className={[styles.statusBadge, className].filter(Boolean).join(' ')}
      style={{ color }}
    >
      <span
        className={`${styles.statusDot}${pulsing ? ` ${styles.statusDotPulsing}` : ''}`}
        style={{ background: color }}
      />
      {label}
    </span>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// EmptyState：空数据占位
// ──────────────────────────────────────────────────────────────────────────

export interface EmptyStateProps {
  icon?: string;
  title: string;
  description?: string;
  action?: ReactNode;
  className?: string;
}

export function EmptyState({
  icon = 'inbox',
  title,
  description,
  action,
  className,
}: EmptyStateProps) {
  return (
    <div className={[styles.emptyState, className].filter(Boolean).join(' ')}>
      <MaterialIcon name={icon} size={44} color="var(--color-on-surface-a40)" />
      <p className={styles.emptyTitle}>{title}</p>
      {description && <p className={styles.emptyDescription}>{description}</p>}
      {action}
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// Divider
// ──────────────────────────────────────────────────────────────────────────

export function Divider({ vertical = false, margin }: { vertical?: boolean; margin?: string }) {
  return (
    <div
      className={vertical ? styles.dividerVertical : styles.divider}
      style={margin ? { margin } : undefined}
      role="separator"
    />
  );
}
