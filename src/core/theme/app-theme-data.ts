import { LocalizationKeys } from '../localization/localization-keys';
import { getContrastColor, lerpColor, withAlpha } from './color-utils';

/**
 * 主题配置模型
 *
 * 对应 Flutter 版 `lib/core/theme/app_theme_data.dart`。
 * 桌面版通过 `generateLightTheme/generateDarkTheme` 产出 `ThemeData`；
 * Web 版改为产出一组 CSS 自定义属性（design tokens），由 `applyThemeTokens` 注入 :root。
 */
export interface AppThemeData {
  /** 主题名称（自定义主题用） */
  name: string;
  /** 预设主题的国际化 key，存在时优先用于展示 */
  localizationKey?: string;
  primaryColor: string;
  secondaryColor: string;
  accentColor: string;
  isCustom: boolean;
}

// ============ 私有颜色常量（与 Flutter 版逐值对齐）============
const BACKGROUND_COLOR = '#F5F6FA';
const SURFACE_COLOR = '#FFFFFF';
const DARK_BACKGROUND_COLOR = '#1A1A2E';
const DARK_SURFACE_COLOR = '#16213E';

const TEXT_PRIMARY_COLOR = '#2D3436';
const TEXT_SECONDARY_COLOR = '#636E72';
const TEXT_DARK_PRIMARY_COLOR = '#DFE6E9';
const TEXT_DARK_SECONDARY_COLOR = '#B2BEC3';

const BORDER_COLOR = '#DFE6E9';
const DARK_BORDER_COLOR = '#2D3436';

// ============ 布局常量 ============
export const ThemeMetrics = {
  borderRadiusSmall: 8,
  borderRadiusMedium: 12,
  borderRadiusLarge: 16,

  spacingSmall: 8,
  spacingMedium: 16,
  spacingLarge: 24,
  spacingXLarge: 32,

  sidebarExpandedWidth: 200,
  sidebarCollapsedWidth: 60,

  /** 动画时长（毫秒） */
  animationDuration: 300,

  /** 桌面布局最小内容宽度，低于此值横向滚动 */
  desktopMinContentWidth: 1000,
} as const;

/** 主题模式，等价于 Flutter 的 ThemeMode */
export type ThemeMode = 'system' | 'light' | 'dark';
export const THEME_MODES: ThemeMode[] = ['system', 'light', 'dark'];

/** 预设主题列表 */
export const presetThemes: AppThemeData[] = [
  {
    name: '默认紫',
    localizationKey: LocalizationKeys.themeDefaultPurple,
    primaryColor: '#6C5CE7',
    secondaryColor: '#A29BFE',
    accentColor: '#00B894',
    isCustom: false,
  },
  {
    name: '圣诞红',
    localizationKey: LocalizationKeys.themeChristmasRed,
    primaryColor: '#D32F2F',
    secondaryColor: '#EF5350',
    accentColor: '#FF9800',
    isCustom: false,
  },
  {
    name: '海洋蓝',
    localizationKey: LocalizationKeys.themeOceanBlue,
    primaryColor: '#0277BD',
    secondaryColor: '#4FC3F7',
    accentColor: '#00BCD4',
    isCustom: false,
  },
  {
    name: '自然绿',
    localizationKey: LocalizationKeys.themeNaturalGreen,
    primaryColor: '#388E3C',
    secondaryColor: '#66BB6A',
    accentColor: '#8BC34A',
    isCustom: false,
  },
  {
    name: '温暖橙',
    localizationKey: LocalizationKeys.themeWarmOrange,
    primaryColor: '#E64A19',
    secondaryColor: '#FF7043',
    accentColor: '#FFB74D',
    isCustom: false,
  },
  {
    name: '优雅紫',
    localizationKey: LocalizationKeys.themeElegantPurple,
    primaryColor: '#7B1FA2',
    secondaryColor: '#AB47BC',
    accentColor: '#BA68C8',
    isCustom: false,
  },
];

/** 主题相等判断（对应 Flutter 的 operator ==） */
export function isSameTheme(a: AppThemeData, b: AppThemeData): boolean {
  return (
    a.name === b.name &&
    a.primaryColor === b.primaryColor &&
    a.secondaryColor === b.secondaryColor &&
    a.accentColor === b.accentColor &&
    a.isCustom === b.isCustom
  );
}

/** 生成的一套完整令牌 */
export type ThemeTokens = Record<string, string>;

/**
 * 生成主题令牌
 *
 * @param theme      配色方案
 * @param brightness 明/暗
 * @param adjustment 对比度调整 0.0–1.0
 *                   - light: 背景/表面向黑色插值（数值越大越暗）
 *                   - dark : 背景向 #050505、表面向 #0A0A15 插值
 */
export function generateThemeTokens(
  theme: AppThemeData,
  brightness: 'light' | 'dark',
  adjustment = 0,
): ThemeTokens {
  const isDark = brightness === 'dark';

  const bgColor = isDark
    ? lerpColor(DARK_BACKGROUND_COLOR, '#050505', adjustment)
    : lerpColor(BACKGROUND_COLOR, '#000000', adjustment);
  const surfaceColor = isDark
    ? lerpColor(DARK_SURFACE_COLOR, '#0A0A15', adjustment)
    : lerpColor(SURFACE_COLOR, '#000000', adjustment);

  const textPrimary = isDark ? TEXT_DARK_PRIMARY_COLOR : TEXT_PRIMARY_COLOR;
  const textSecondary = isDark ? TEXT_DARK_SECONDARY_COLOR : TEXT_SECONDARY_COLOR;
  const border = isDark ? DARK_BORDER_COLOR : BORDER_COLOR;

  const { primaryColor, secondaryColor, accentColor } = theme;

  return {
    // ── 配色方案 ──
    '--color-primary': primaryColor,
    '--color-secondary': secondaryColor,
    '--color-accent': accentColor,
    '--color-on-primary': getContrastColor(primaryColor),
    '--color-on-secondary': getContrastColor(secondaryColor),

    '--color-background': bgColor,
    '--color-surface': surfaceColor,
    '--color-on-surface': isDark ? '#FFFFFF' : 'rgba(0, 0, 0, 0.87)',
    '--color-surface-container-highest': isDark ? '#2C2C2C' : '#F5F5F5',
    '--color-outline': withAlpha(primaryColor, isDark ? 0.4 : 0.3),

    '--color-error': isDark ? '#FF5252' : '#F44336',
    '--color-on-error': '#FFFFFF',
    '--color-success': '#00B894',
    '--color-warning': '#FF9800',
    '--color-danger': '#E53935',
    '--color-caution': '#FDD835',

    // ── 文字 ──
    '--color-text-primary': textPrimary,
    '--color-text-secondary': textSecondary,

    // ── 边框 ──
    '--color-border': border,

    // ── 常用透明度衍生（避免组件里反复算）──
    '--color-primary-a10': withAlpha(primaryColor, 0.1),
    '--color-primary-a20': withAlpha(primaryColor, 0.2),
    '--color-primary-a30': withAlpha(primaryColor, 0.3),
    '--color-on-surface-a04': withAlpha(isDark ? '#FFFFFF' : '#000000', 0.04),
    '--color-on-surface-a08': withAlpha(isDark ? '#FFFFFF' : '#000000', 0.08),
    '--color-on-surface-a40': withAlpha(isDark ? '#FFFFFF' : '#000000', 0.4),
    '--color-on-surface-a60': withAlpha(isDark ? '#FFFFFF' : '#000000', 0.6),

    // ── 阴影 ──
    '--shadow-sm': isDark
      ? '0 1px 4px rgba(0, 0, 0, 0.45)'
      : '0 1px 4px rgba(0, 0, 0, 0.1)',
    '--shadow-md': isDark
      ? '0 4px 16px rgba(0, 0, 0, 0.5)'
      : '0 4px 16px rgba(0, 0, 0, 0.12)',
    '--shadow-lg': isDark
      ? '0 8px 32px rgba(0, 0, 0, 0.6)'
      : '0 8px 32px rgba(0, 0, 0, 0.16)',

    // ── 布局令牌 ──
    '--radius-sm': `${ThemeMetrics.borderRadiusSmall}px`,
    '--radius-md': `${ThemeMetrics.borderRadiusMedium}px`,
    '--radius-lg': `${ThemeMetrics.borderRadiusLarge}px`,
    '--space-sm': `${ThemeMetrics.spacingSmall}px`,
    '--space-md': `${ThemeMetrics.spacingMedium}px`,
    '--space-lg': `${ThemeMetrics.spacingLarge}px`,
    '--space-xl': `${ThemeMetrics.spacingXLarge}px`,
    '--sidebar-expanded': `${ThemeMetrics.sidebarExpandedWidth}px`,
    '--sidebar-collapsed': `${ThemeMetrics.sidebarCollapsedWidth}px`,
    '--anim-duration': `${ThemeMetrics.animationDuration}ms`,
  };
}

/** 把令牌写入 <html> 的 style，并打上 data-brightness 标记 */
export function applyThemeTokens(tokens: ThemeTokens, brightness: 'light' | 'dark'): void {
  const root = document.documentElement;
  for (const [key, value] of Object.entries(tokens)) {
    root.style.setProperty(key, value);
  }
  root.dataset.brightness = brightness;
  root.style.colorScheme = brightness;
}

/** 序列化（持久化用），对应 Flutter 的 toJson */
export function themeToJson(theme: AppThemeData): Record<string, unknown> {
  return {
    name: theme.name,
    localizationKey: theme.localizationKey,
    primaryColor: theme.primaryColor,
    secondaryColor: theme.secondaryColor,
    accentColor: theme.accentColor,
    isCustom: theme.isCustom,
  };
}

/** 反序列化，容错回退到默认主题 */
export function themeFromJson(json: unknown): AppThemeData {
  const fallback = presetThemes[0];
  if (!json || typeof json !== 'object') return fallback;
  const raw = json as Record<string, unknown>;
  const pick = (key: string, def: string) =>
    typeof raw[key] === 'string' ? (raw[key] as string) : def;
  return {
    name: pick('name', fallback.name),
    localizationKey:
      typeof raw.localizationKey === 'string' ? raw.localizationKey : undefined,
    primaryColor: pick('primaryColor', fallback.primaryColor),
    secondaryColor: pick('secondaryColor', fallback.secondaryColor),
    accentColor: pick('accentColor', fallback.accentColor),
    isCustom: raw.isCustom === true,
  };
}

/** 主题模式对应的 Material Symbols 图标名 */
export function themeModeIcon(mode: ThemeMode): string {
  switch (mode) {
    case 'system':
      return 'brightness_auto';
    case 'light':
      return 'light_mode';
    case 'dark':
      return 'dark_mode';
  }
}

/** 主题模式对应的国际化 key */
export function themeModeLocalizationKey(mode: ThemeMode): string {
  switch (mode) {
    case 'system':
      return LocalizationKeys.themeModeSystem;
    case 'light':
      return LocalizationKeys.themeModeLight;
    case 'dark':
      return LocalizationKeys.themeModeDark;
  }
}
