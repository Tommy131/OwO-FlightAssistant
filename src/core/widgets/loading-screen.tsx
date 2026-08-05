import { AppConstants } from '../constants/app-constants';
import { LocalizationKeys } from '../localization/localization-keys';
import { useTranslate } from '../localization/use-translate';
import { useThemeStore } from '../theme/theme-store';
import styles from './loading-screen.module.css';

/**
 * 应用启动加载页
 *
 * 对应 Flutter 版 `core/widgets/loading_screen.dart`：
 * 初始化完成前显示，配色跟随当前主题的主色。
 */
export function LoadingScreen({ message }: { message?: string }) {
  const t = useTranslate();
  const primaryColor = useThemeStore((state) => state.currentTheme.primaryColor);

  return (
    <div className={styles.screen} role="status" aria-live="polite">
      <div className={styles.logoWrap}>
        <img src={AppConstants.assetIconPath} alt="" className={styles.logo} />
        <div
          className={styles.ring}
          style={{
            borderColor: `color-mix(in srgb, ${primaryColor} 25%, transparent)`,
            borderTopColor: primaryColor,
          }}
        />
      </div>
      <h1 className={styles.title}>{AppConstants.appName}</h1>
      <p className={styles.message}>{message ?? t(LocalizationKeys.loading)}</p>
    </div>
  );
}
