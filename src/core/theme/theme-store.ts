import { create } from 'zustand';
import { PersistenceService } from '../services/persistence-service';
import { AppLogger } from '../utils/logger';
import {
  applyThemeTokens,
  generateThemeTokens,
  isSameTheme,
  presetThemes,
  themeFromJson,
  themeToJson,
  type AppThemeData,
  type ThemeMode,
} from './app-theme-data';
import { withAlpha } from './color-utils';

/**
 * 主题管理 store
 *
 * 对应 Flutter 版 `lib/core/theme/theme_provider.dart`（ChangeNotifier → Zustand）。
 * 状态变化后立即把 CSS 变量写入 :root，等价于 MaterialApp 重建 ThemeData。
 */

const THEME_MODE_KEY = 'theme_mode';
const CURRENT_THEME_KEY = 'current_theme';
const LIGHT_CONTRAST_KEY = 'light_contrast_adjustment';
const DARK_CONTRAST_KEY = 'dark_contrast_adjustment';

/** 跟随系统时监听的媒体查询 */
const darkMediaQuery =
  typeof window !== 'undefined' && typeof window.matchMedia === 'function'
    ? window.matchMedia('(prefers-color-scheme: dark)')
    : null;

interface ThemeState {
  themeMode: ThemeMode;
  currentTheme: AppThemeData;
  lightContrastAdjustment: number;
  darkContrastAdjustment: number;
  /** 系统当前是否为深色（仅在 themeMode === 'system' 时生效） */
  systemPrefersDark: boolean;

  load: () => Promise<void>;
  setTheme: (theme: AppThemeData) => Promise<void>;
  createCustomTheme: (
    primaryColor: string,
    name: string,
    options?: { secondaryColor?: string; accentColor?: string },
  ) => Promise<void>;
  setThemeMode: (mode: ThemeMode) => Promise<void>;
  toggleThemeMode: () => Promise<void>;
  toggleDarkMode: () => Promise<void>;
  setLightContrastAdjustment: (level: number) => Promise<void>;
  setDarkContrastAdjustment: (level: number) => Promise<void>;
  resetToDefault: () => Promise<void>;
  /** 内部：系统配色变化回调 */
  _setSystemPrefersDark: (isDark: boolean) => void;
}

export const useThemeStore = create<ThemeState>((set, get) => {
  /** 依据当前状态计算生效亮度并注入 CSS 变量 */
  const applyCurrent = () => {
    const state = get();
    const brightness = resolveBrightness(state.themeMode, state.systemPrefersDark);
    const adjustment =
      brightness === 'dark' ? state.darkContrastAdjustment : state.lightContrastAdjustment;
    applyThemeTokens(
      generateThemeTokens(state.currentTheme, brightness, adjustment),
      brightness,
    );
    // 同步浏览器地址栏主题色
    document
      .querySelector('meta[name="theme-color"]')
      ?.setAttribute('content', state.currentTheme.primaryColor);
  };

  const persist = async () => {
    try {
      if (!PersistenceService.isInitialized) return;
      const state = get();
      await PersistenceService.setString(
        CURRENT_THEME_KEY,
        JSON.stringify(themeToJson(state.currentTheme)),
      );
      await PersistenceService.setString(THEME_MODE_KEY, state.themeMode);
      await PersistenceService.setDouble(LIGHT_CONTRAST_KEY, state.lightContrastAdjustment);
      await PersistenceService.setDouble(DARK_CONTRAST_KEY, state.darkContrastAdjustment);
    } catch (e) {
      AppLogger.warning(`Failed to save theme settings: ${String(e)}`);
    }
  };

  return {
    themeMode: 'system',
    currentTheme: presetThemes[0],
    lightContrastAdjustment: 0,
    darkContrastAdjustment: 0,
    systemPrefersDark: darkMediaQuery?.matches ?? false,

    async load() {
      try {
        await PersistenceService.ensureReady();

        const themeJson = PersistenceService.getString(CURRENT_THEME_KEY);
        if (themeJson) {
          set({ currentTheme: themeFromJson(JSON.parse(themeJson)) });
        }

        const savedMode = PersistenceService.getString(THEME_MODE_KEY);
        if (savedMode === 'system' || savedMode === 'light' || savedMode === 'dark') {
          set({ themeMode: savedMode });
        }

        set({
          lightContrastAdjustment: PersistenceService.getDouble(LIGHT_CONTRAST_KEY) ?? 0,
          darkContrastAdjustment: PersistenceService.getDouble(DARK_CONTRAST_KEY) ?? 0,
        });

        applyCurrent();
        AppLogger.info('ThemeProvider loaded settings from persistence');
      } catch (e) {
        AppLogger.warning(`加载主题设置失败: ${String(e)}`);
        set({
          currentTheme: presetThemes[0],
          themeMode: 'system',
          lightContrastAdjustment: 0,
          darkContrastAdjustment: 0,
        });
        applyCurrent();
      }
    },

    async setTheme(theme) {
      if (isSameTheme(get().currentTheme, theme)) return;
      set({ currentTheme: theme });
      applyCurrent();
      await persist();
    },

    async createCustomTheme(primaryColor, name, options = {}) {
      await get().setTheme({
        name,
        primaryColor,
        // 与桌面版一致：未指定时由主色按 0.7 / 0.5 透明度派生
        secondaryColor: options.secondaryColor ?? withAlpha(primaryColor, 0.7),
        accentColor: options.accentColor ?? withAlpha(primaryColor, 0.5),
        isCustom: true,
      });
    },

    async setThemeMode(mode) {
      if (get().themeMode === mode) return;
      set({ themeMode: mode });
      applyCurrent();
      await persist();
    },

    async toggleThemeMode() {
      const modes: ThemeMode[] = ['system', 'light', 'dark'];
      const nextIndex = (modes.indexOf(get().themeMode) + 1) % modes.length;
      await get().setThemeMode(modes[nextIndex]);
    },

    async toggleDarkMode() {
      const mode = get().themeMode;
      if (mode === 'system') {
        await get().setThemeMode('dark');
        return;
      }
      await get().setThemeMode(mode === 'light' ? 'dark' : 'light');
    },

    async setLightContrastAdjustment(level) {
      const clamped = Math.min(Math.max(level, 0), 1);
      if (get().lightContrastAdjustment === clamped) return;
      set({ lightContrastAdjustment: clamped });
      applyCurrent();
      await persist();
    },

    async setDarkContrastAdjustment(level) {
      const clamped = Math.min(Math.max(level, 0), 1);
      if (get().darkContrastAdjustment === clamped) return;
      set({ darkContrastAdjustment: clamped });
      applyCurrent();
      await persist();
    },

    async resetToDefault() {
      set({
        currentTheme: presetThemes[0],
        themeMode: 'system',
        lightContrastAdjustment: 0,
        darkContrastAdjustment: 0,
      });
      applyCurrent();
      await persist();
    },

    _setSystemPrefersDark(isDark) {
      if (get().systemPrefersDark === isDark) return;
      set({ systemPrefersDark: isDark });
      if (get().themeMode === 'system') applyCurrent();
    },
  };
});

/** 解析最终生效的亮度 */
export function resolveBrightness(
  mode: ThemeMode,
  systemPrefersDark: boolean,
): 'light' | 'dark' {
  if (mode === 'light') return 'light';
  if (mode === 'dark') return 'dark';
  return systemPrefersDark ? 'dark' : 'light';
}

/** 当前是否处于深色（组件内判断分支样式用） */
export function useIsDarkMode(): boolean {
  const themeMode = useThemeStore((s) => s.themeMode);
  const systemPrefersDark = useThemeStore((s) => s.systemPrefersDark);
  return resolveBrightness(themeMode, systemPrefersDark) === 'dark';
}

// 监听系统配色变化（themeMode === 'system' 时实时跟随）
darkMediaQuery?.addEventListener('change', (event) => {
  useThemeStore.getState()._setSystemPrefersDark(event.matches);
});
