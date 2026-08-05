import { LocalizationKeys } from '../../localization/localization-keys';
import { useTranslate } from '../../localization/use-translate';
import { AppBarActionRegistry } from '../../module-registry/app-bar/app-bar-action';
import type { NavigationItem } from '../../module-registry/navigation/navigation-item';
import {
  THEME_MODES,
  themeModeIcon,
  themeModeLocalizationKey,
} from '../../theme/app-theme-data';
import { useThemeStore } from '../../theme/theme-store';
import { IconButton, PopupMenu } from './controls';
import { MaterialIcon } from './icon';
import styles from './custom-app-bar.module.css';

/**
 * 顶部应用栏
 *
 * 对应 Flutter 版 `core/widgets/common/custom_app_bar.dart`：
 * 左侧为当前页图标 + 标题（有二级菜单时换成汉堡按钮），
 * 右侧依次是模块注册的动作按钮与主题模式选择器。
 */
export interface CustomAppBarProps {
  currentItem: NavigationItem;
  /** 当前页是否存在二级侧边菜单 */
  hasSideMenu?: boolean;
  onOpenSideMenu?: () => void;
}

export function CustomAppBar({
  currentItem,
  hasSideMenu = false,
  onOpenSideMenu,
}: CustomAppBarProps) {
  const t = useTranslate();
  const themeMode = useThemeStore((state) => state.themeMode);
  const setThemeMode = useThemeStore((state) => state.setThemeMode);

  // 工厂在 render 期间调用，内部可用 hooks（见 app-bar-action.ts 的约束说明）
  const actions = AppBarActionRegistry.getAllActions();

  return (
    <header className={styles.appBar}>
      {hasSideMenu ? (
        <IconButton
          icon="menu"
          label={currentItem.title}
          onClick={onOpenSideMenu}
          size={22}
        />
      ) : (
        <MaterialIcon
          name={currentItem.activeIcon ?? currentItem.icon}
          filled
          size={26}
          color="var(--color-primary)"
        />
      )}

      <h1 className={styles.title}>{currentItem.title}</h1>

      <div className={styles.actions}>
        {actions.map((action) => (
          <span key={action.id} className={styles.actionSlot}>
            {action.render()}
          </span>
        ))}

        <PopupMenu
          icon={themeModeIcon(themeMode)}
          label={t(LocalizationKeys.themeSettingsTooltip)}
          items={THEME_MODES.map((mode) => ({
            key: mode,
            label: t(themeModeLocalizationKey(mode)),
            icon: themeModeIcon(mode),
            selected: themeMode === mode,
            onSelect: () => void setThemeMode(mode),
          }))}
        />
      </div>
    </header>
  );
}
