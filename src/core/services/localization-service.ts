import { create } from 'zustand';
import { deDE } from '../localization/languages/de-de';
import { enUS } from '../localization/languages/en-us';
import { zhCN } from '../localization/languages/zh-cn';
import { PersistenceService } from './persistence-service';

/**
 * 国际化服务
 *
 * 对应 Flutter 版 `lib/core/services/localization_service.dart`。
 * 保持同样的两层查表结构：模块词条优先于核心词条，模块在 register() 时注入自己的翻译。
 *
 * ── 相对桌面版的一处改进 ──
 * 桌面版 `translate()` 查不到就直接返回 key 本身；由于业务模块只提供 zh_CN / en_US，
 * 选德语时模块文案会整片显示成 `map.nav_title` 这类原始 key。
 * 这里补了一条回退链：当前语言 → en_US → key，德语界面因此退化为英文而非乱码。
 */

export type LanguageCode = 'zh_CN' | 'en_US' | 'de_DE';

export interface LanguageOption {
  code: LanguageCode;
  name: string;
  /** 国旗 emoji，用于语言选择器 */
  flag: string;
}

const LANGUAGE_KEY = 'language_code';
const FALLBACK_LANGUAGE: LanguageCode = 'en_US';

export const supportedLanguages: LanguageOption[] = [
  { code: 'zh_CN', name: '简体中文', flag: '🇨🇳' },
  { code: 'en_US', name: 'English', flag: '🇺🇸' },
  { code: 'de_DE', name: 'Deutsch', flag: '🇩🇪' },
];

/** 核心层词条表 */
const coreLocalizedValues: Record<LanguageCode, Record<string, string>> = {
  zh_CN: zhCN,
  en_US: enUS,
  de_DE: deDE,
};

/** 模块词条表（由各模块 register() 时合并写入） */
const moduleLocalizedValues: Partial<Record<LanguageCode, Record<string, string>>> = {};

/**
 * 模块翻译包的形状：`{ zh_CN: {...}, en_US: {...} }`
 * 与桌面版 `Map<String, Map<String, String>>` 一一对应。
 */
export type ModuleTranslations = Partial<Record<LanguageCode, Record<string, string>>>;

interface LocalizationState {
  locale: LanguageCode;
  /** 词条版本号：模块注册新翻译时自增，用于触发依赖组件重渲染 */
  revision: number;
  setLocale: (locale: LanguageCode) => Promise<void>;
  init: () => Promise<void>;
}

export const useLocalizationStore = create<LocalizationState>((set) => ({
  locale: 'zh_CN',
  revision: 0,

  async init() {
    await PersistenceService.ensureReady();
    const saved = PersistenceService.getString(LANGUAGE_KEY);
    if (saved && isSupportedLanguage(saved)) {
      set({ locale: saved });
      document.documentElement.lang = toHtmlLang(saved);
    }
  },

  async setLocale(locale: LanguageCode) {
    set({ locale });
    document.documentElement.lang = toHtmlLang(locale);
    await PersistenceService.setString(LANGUAGE_KEY, locale);
  },
}));

/** 注册模块翻译（在 ModuleRegistrar.register() 中调用） */
export function registerModuleTranslations(translations: ModuleTranslations): void {
  for (const [language, values] of Object.entries(translations)) {
    if (!isSupportedLanguage(language) || !values) continue;
    moduleLocalizedValues[language] = { ...(moduleLocalizedValues[language] ?? {}), ...values };
  }
  useLocalizationStore.setState((state) => ({ revision: state.revision + 1 }));
}

/** 命名占位符参数，例如 `{ aircraft: 'A320' }` 对应文案里的 `{aircraft}` */
export type NamedArgs = Record<string, string | number>;
export type TranslateArg = string | number | NamedArgs;

/**
 * 翻译（非 React 环境也可调用，等价于桌面版的 `LocalizationService().translate`）
 *
 * 两种占位符都支持，与桌面版各页面的写法一一对应：
 *   - 位置占位 `{}`  → `translate(key, a, b)`
 *   - 命名占位 `{x}` → `translate(key, { x: 1 })`
 */
export function translate(key: string, ...args: TranslateArg[]): string {
  const locale = useLocalizationStore.getState().locale;
  const resolved =
    moduleLocalizedValues[locale]?.[key] ??
    coreLocalizedValues[locale]?.[key] ??
    moduleLocalizedValues[FALLBACK_LANGUAGE]?.[key] ??
    coreLocalizedValues[FALLBACK_LANGUAGE]?.[key] ??
    key;
  return args.length > 0 ? formatPlaceholders(resolved, args) : resolved;
}

/** 依次替换 `{}` 位置占位与 `{name}` 命名占位 */
export function formatPlaceholders(template: string, args: TranslateArg[]): string {
  // 先合并所有命名参数
  const named: NamedArgs = {};
  const positional: (string | number)[] = [];
  for (const arg of args) {
    if (typeof arg === 'object' && arg !== null) {
      Object.assign(named, arg);
    } else {
      positional.push(arg);
    }
  }

  let index = 0;
  return template.replace(/\{(\w*)\}/g, (match, name: string) => {
    if (name.length === 0) {
      const value = positional[index++];
      return value === undefined ? match : String(value);
    }
    const value = named[name];
    return value === undefined ? match : String(value);
  });
}

/** 当前语言码 */
export function currentLanguageCode(): LanguageCode {
  return useLocalizationStore.getState().locale;
}

function isSupportedLanguage(value: string): value is LanguageCode {
  return value === 'zh_CN' || value === 'en_US' || value === 'de_DE';
}

function toHtmlLang(locale: LanguageCode): string {
  return locale.replace('_', '-');
}
