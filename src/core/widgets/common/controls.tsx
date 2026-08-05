import {
  useId,
  useState,
  type ChangeEvent,
  type CSSProperties,
  type ReactNode,
} from 'react';
import { MaterialIcon } from './icon';
import styles from './controls.module.css';

/**
 * 通用交互控件
 *
 * 复刻 Flutter 主题里定义的按钮/开关/滑块外观：
 *   - ElevatedButton：0 elevation，主色底，24×12 内边距，8 圆角
 *   - OutlinedButton：surface 底，1.8px 次色描边，16 圆角
 *   - Switch / Slider / TextField 沿用 Material 3 视觉
 */

// ──────────────────────────────────────────────────────────────────────────
// Button
// ──────────────────────────────────────────────────────────────────────────

export type ButtonVariant = 'elevated' | 'outlined' | 'text' | 'tonal' | 'danger';

export interface ButtonProps {
  children: ReactNode;
  onClick?: () => void;
  variant?: ButtonVariant;
  /** 前置图标名 */
  icon?: string;
  /** 后置图标名 */
  trailingIcon?: string;
  disabled?: boolean;
  loading?: boolean;
  /** 占满容器宽度 */
  block?: boolean;
  size?: 'sm' | 'md';
  type?: 'button' | 'submit';
  title?: string;
  className?: string;
  style?: CSSProperties;
}

export function Button({
  children,
  onClick,
  variant = 'elevated',
  icon,
  trailingIcon,
  disabled = false,
  loading = false,
  block = false,
  size = 'md',
  type = 'button',
  title,
  className,
  style,
}: ButtonProps) {
  return (
    <button
      type={type}
      title={title}
      disabled={disabled || loading}
      onClick={onClick}
      style={style}
      className={[
        styles.button,
        styles[`button_${variant}`],
        size === 'sm' ? styles.buttonSm : '',
        block ? styles.buttonBlock : '',
        className,
      ]
        .filter(Boolean)
        .join(' ')}
    >
      {loading ? (
        <span className={styles.spinner} aria-hidden />
      ) : (
        icon && <MaterialIcon name={icon} size={size === 'sm' ? 15 : 17} />
      )}
      <span className={styles.buttonLabel}>{children}</span>
      {trailingIcon && !loading && (
        <MaterialIcon name={trailingIcon} size={size === 'sm' ? 15 : 17} />
      )}
    </button>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// IconButton
// ──────────────────────────────────────────────────────────────────────────

export interface IconButtonProps {
  icon: string;
  onClick?: () => void;
  /** 无障碍标签，同时作为 tooltip */
  label: string;
  filled?: boolean;
  size?: number;
  color?: string;
  disabled?: boolean;
  active?: boolean;
  className?: string;
}

export function IconButton({
  icon,
  onClick,
  label,
  filled = false,
  size = 20,
  color,
  disabled = false,
  active = false,
  className,
}: IconButtonProps) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      title={label}
      aria-label={label}
      aria-pressed={active || undefined}
      className={[styles.iconButton, active ? styles.iconButtonActive : '', className]
        .filter(Boolean)
        .join(' ')}
    >
      <MaterialIcon name={icon} filled={filled || active} size={size} color={color} />
    </button>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// Switch
// ──────────────────────────────────────────────────────────────────────────

export interface SwitchProps {
  checked: boolean;
  onChange: (checked: boolean) => void;
  label?: string;
  disabled?: boolean;
}

export function Switch({ checked, onChange, label, disabled = false }: SwitchProps) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      disabled={disabled}
      onClick={() => onChange(!checked)}
      className={[styles.switch, checked ? styles.switchOn : ''].filter(Boolean).join(' ')}
    >
      <span className={styles.switchThumb} />
    </button>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// Slider
// ──────────────────────────────────────────────────────────────────────────

export interface SliderProps {
  value: number;
  onChange: (value: number) => void;
  min?: number;
  max?: number;
  step?: number;
  label?: string;
  /** 值的展示格式化 */
  formatValue?: (value: number) => string;
  disabled?: boolean;
}

export function Slider({
  value,
  onChange,
  min = 0,
  max = 1,
  step = 0.01,
  label,
  formatValue,
  disabled = false,
}: SliderProps) {
  const percent = max > min ? ((value - min) / (max - min)) * 100 : 0;
  return (
    <div className={styles.sliderWrap}>
      <input
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        disabled={disabled}
        aria-label={label}
        onChange={(event: ChangeEvent<HTMLInputElement>) =>
          onChange(Number.parseFloat(event.target.value))
        }
        className={styles.slider}
        // 已填充轨道用渐变绘制，避免额外 DOM
        style={{
          background: `linear-gradient(to right, var(--color-primary) ${percent}%, var(--color-on-surface-a08) ${percent}%)`,
        }}
      />
      {formatValue && <span className={styles.sliderValue}>{formatValue(value)}</span>}
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// TextField
// ──────────────────────────────────────────────────────────────────────────

export interface TextFieldProps {
  value: string;
  onChange: (value: string) => void;
  label?: string;
  placeholder?: string;
  /** 前置图标名 */
  icon?: string;
  /** 后置内容（清除按钮、单位等） */
  trailing?: ReactNode;
  type?: 'text' | 'number' | 'password' | 'search';
  disabled?: boolean;
  /** 错误提示，非空时显示为错误态 */
  error?: string;
  hint?: string;
  onSubmit?: () => void;
  onFocus?: () => void;
  onBlur?: () => void;
  monospace?: boolean;
  autoFocus?: boolean;
  className?: string;
}

export function TextField({
  value,
  onChange,
  label,
  placeholder,
  icon,
  trailing,
  type = 'text',
  disabled = false,
  error,
  hint,
  onSubmit,
  onFocus,
  onBlur,
  monospace = false,
  autoFocus = false,
  className,
}: TextFieldProps) {
  const id = useId();
  return (
    <div className={[styles.fieldWrap, className].filter(Boolean).join(' ')}>
      {label && (
        <label className={styles.fieldLabel} htmlFor={id}>
          {label}
        </label>
      )}
      <div
        className={[styles.field, error ? styles.fieldError : '', disabled ? styles.fieldDisabled : '']
          .filter(Boolean)
          .join(' ')}
      >
        {icon && <MaterialIcon name={icon} size={17} color="var(--color-text-secondary)" />}
        <input
          id={id}
          type={type}
          value={value}
          placeholder={placeholder}
          disabled={disabled}
          autoFocus={autoFocus}
          onChange={(event) => onChange(event.target.value)}
          onFocus={onFocus}
          onBlur={onBlur}
          onKeyDown={(event) => {
            if (event.key === 'Enter' && onSubmit) onSubmit();
          }}
          className={`${styles.fieldInput}${monospace ? ' text-mono' : ''}`}
        />
        {trailing}
      </div>
      {(error || hint) && (
        <span className={error ? styles.fieldErrorText : styles.fieldHint}>{error ?? hint}</span>
      )}
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// Select
// ──────────────────────────────────────────────────────────────────────────

export interface SelectOption<T extends string = string> {
  value: T;
  label: string;
}

export interface SelectProps<T extends string = string> {
  value: T;
  options: SelectOption<T>[];
  onChange: (value: T) => void;
  label?: string;
  icon?: string;
  disabled?: boolean;
  className?: string;
}

export function Select<T extends string = string>({
  value,
  options,
  onChange,
  label,
  icon,
  disabled = false,
  className,
}: SelectProps<T>) {
  const id = useId();
  return (
    <div className={[styles.fieldWrap, className].filter(Boolean).join(' ')}>
      {label && (
        <label className={styles.fieldLabel} htmlFor={id}>
          {label}
        </label>
      )}
      <div className={[styles.field, disabled ? styles.fieldDisabled : ''].filter(Boolean).join(' ')}>
        {icon && <MaterialIcon name={icon} size={17} color="var(--color-text-secondary)" />}
        <select
          id={id}
          value={value}
          disabled={disabled}
          onChange={(event) => onChange(event.target.value as T)}
          className={styles.select}
        >
          {options.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
        <MaterialIcon name="expand_more" size={17} color="var(--color-text-secondary)" />
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// SegmentedControl：一排互斥的分段按钮（toolbox tab / 图层切换等）
// ──────────────────────────────────────────────────────────────────────────

export interface SegmentedControlProps<T extends string = string> {
  value: T;
  options: { value: T; label: string; icon?: string }[];
  onChange: (value: T) => void;
  /** 占满容器宽度并均分 */
  block?: boolean;
  size?: 'sm' | 'md';
  className?: string;
}

export function SegmentedControl<T extends string = string>({
  value,
  options,
  onChange,
  block = false,
  size = 'md',
  className,
}: SegmentedControlProps<T>) {
  return (
    <div
      role="tablist"
      className={[styles.segmented, block ? styles.segmentedBlock : '', className]
        .filter(Boolean)
        .join(' ')}
    >
      {options.map((option) => {
        const selected = option.value === value;
        return (
          <button
            key={option.value}
            type="button"
            role="tab"
            aria-selected={selected}
            onClick={() => onChange(option.value)}
            className={[
              styles.segmentedItem,
              selected ? styles.segmentedItemActive : '',
              size === 'sm' ? styles.segmentedItemSm : '',
            ]
              .filter(Boolean)
              .join(' ')}
          >
            {option.icon && <MaterialIcon name={option.icon} size={15} filled={selected} />}
            {option.label}
          </button>
        );
      })}
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// Checkbox
// ──────────────────────────────────────────────────────────────────────────

export interface CheckboxProps {
  checked: boolean;
  onChange: (checked: boolean) => void;
  label?: ReactNode;
  disabled?: boolean;
  /** 勾选色，默认主色 */
  color?: string;
}

export function Checkbox({ checked, onChange, label, disabled = false, color }: CheckboxProps) {
  return (
    <label className={[styles.checkbox, disabled ? styles.checkboxDisabled : ''].filter(Boolean).join(' ')}>
      <input
        type="checkbox"
        checked={checked}
        disabled={disabled}
        onChange={(event) => onChange(event.target.checked)}
        className={styles.checkboxInput}
      />
      <span
        className={styles.checkboxBox}
        style={checked ? { background: color ?? 'var(--color-primary)', borderColor: color ?? 'var(--color-primary)' } : undefined}
      >
        {checked && <MaterialIcon name="check" size={13} color="#fff" weight={700} />}
      </span>
      {label && <span className={styles.checkboxLabel}>{label}</span>}
    </label>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// Popover Menu：轻量下拉菜单（对应 Flutter PopupMenuButton）
// ──────────────────────────────────────────────────────────────────────────

export interface MenuItemSpec {
  key: string;
  label: string;
  icon?: string;
  selected?: boolean;
  danger?: boolean;
  onSelect: () => void;
}

export interface PopupMenuProps {
  /** 触发按钮的图标 */
  icon: string;
  label: string;
  items: MenuItemSpec[];
  align?: 'left' | 'right';
}

export function PopupMenu({ icon, label, items, align = 'right' }: PopupMenuProps) {
  const [open, setOpen] = useState(false);

  return (
    <div className={styles.popupWrap}>
      <IconButton icon={icon} label={label} onClick={() => setOpen((prev) => !prev)} />
      {open && (
        <>
          {/* 点击遮罩关闭，覆盖全屏但完全透明 */}
          <div className={styles.popupScrim} onClick={() => setOpen(false)} />
          <div
            className={[styles.popupMenu, align === 'left' ? styles.popupMenuLeft : '']
              .filter(Boolean)
              .join(' ')}
            role="menu"
          >
            {items.map((item) => (
              <button
                key={item.key}
                type="button"
                role="menuitem"
                className={[
                  styles.popupItem,
                  item.selected ? styles.popupItemSelected : '',
                  item.danger ? styles.popupItemDanger : '',
                ]
                  .filter(Boolean)
                  .join(' ')}
                onClick={() => {
                  setOpen(false);
                  item.onSelect();
                }}
              >
                {item.icon && <MaterialIcon name={item.icon} size={17} />}
                <span className={styles.popupItemLabel}>{item.label}</span>
                {item.selected && <MaterialIcon name="check" size={16} />}
              </button>
            ))}
          </div>
        </>
      )}
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// ProgressBar
// ──────────────────────────────────────────────────────────────────────────

export function ProgressBar({
  value,
  color,
  height = 6,
}: {
  /** 0–1；传 undefined 表示不确定进度 */
  value?: number;
  color?: string;
  height?: number;
}) {
  const indeterminate = value === undefined;
  return (
    <div className={styles.progressTrack} style={{ height }}>
      <div
        className={indeterminate ? styles.progressIndeterminate : styles.progressFill}
        style={{
          width: indeterminate ? undefined : `${Math.min(Math.max(value, 0), 1) * 100}%`,
          background: color ?? 'var(--color-primary)',
        }}
      />
    </div>
  );
}
