import { useCallback } from 'react';
import {
  translate,
  useLocalizationStore,
  type TranslateArg,
} from '../services/localization-service';

/**
 * 翻译 hook
 *
 * 等价于 Flutter 版的 `'key'.tr(context)` 扩展方法：
 * 组件订阅 locale 与词条 revision，语言切换或模块注册新翻译时自动重渲染。
 *
 * ```tsx
 * const t = useTranslate();
 * <span>{t(LocalizationKeys.settings)}</span>
 * <span>{t(LocalizationKeys.themeChangedTo, themeName)}</span>
 * ```
 */
export function useTranslate() {
  const locale = useLocalizationStore((state) => state.locale);
  const revision = useLocalizationStore((state) => state.revision);

  return useCallback(
    (key: string, ...args: TranslateArg[]) => translate(key, ...args),
    // locale / revision 变化时重建闭包，驱动依赖此函数的组件更新
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [locale, revision],
  );
}
