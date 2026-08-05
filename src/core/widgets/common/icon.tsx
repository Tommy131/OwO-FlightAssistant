import type { CSSProperties } from 'react';

/**
 * Material Symbols 图标
 *
 * Flutter 版用 `Icon(Icons.home_outlined)` / `Icon(Icons.home)`；
 * Web 版统一用图标名 + `filled` 开关映射到 Material Symbols 的 FILL 轴，
 * 视觉上与桌面版的描边/实心两态一一对应。
 */
export interface MaterialIconProps {
  /** 图标名，例如 'home' / 'map' / 'checklist' */
  name: string;
  /** 是否使用填充态（对应 Flutter 的实心图标） */
  filled?: boolean;
  size?: number;
  color?: string;
  /** 字重 100–700，默认 400 */
  weight?: number;
  className?: string;
  style?: CSSProperties;
  /** 作为纯装饰时置 true（默认），会对屏幕阅读器隐藏 */
  decorative?: boolean;
  /** 语义标签，decorative 为 false 时生效 */
  label?: string;
}

export function MaterialIcon({
  name,
  filled = false,
  size = 20,
  color,
  weight = 400,
  className,
  style,
  decorative = true,
  label,
}: MaterialIconProps) {
  return (
    <span
      className={`mi${filled ? ' mi--filled' : ''}${className ? ` ${className}` : ''}`}
      style={{
        fontSize: size,
        width: size,
        height: size,
        color,
        fontVariationSettings: `'FILL' ${filled ? 1 : 0}, 'wght' ${weight}, 'GRAD' 0, 'opsz' ${size}`,
        ...style,
      }}
      aria-hidden={decorative ? true : undefined}
      role={decorative ? undefined : 'img'}
      aria-label={decorative ? undefined : label}
    >
      {name}
    </span>
  );
}
