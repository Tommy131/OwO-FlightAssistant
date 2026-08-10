import { useTranslate } from '../../../core/localization/use-translate';
import type { AppBarAction } from '../../../core/module-registry/app-bar/app-bar-action';
import { PopupMenu } from '../../../core/widgets/common/controls';
import { CommonLocalizationKeys as K } from '../localization/common-localization';
import { useAppModeStore, type AppMode } from '../providers/app-mode-store';

/**
 * AppBar 上的模式切换器
 *
 * 放在顶栏而不是设置页里：它会实质改变每个页面的行为，用户需要随时看得见
 * 自己现在处于哪种模式 —— 藏进设置页的话，复盘时看到检查单不自动打勾，
 * 只会以为是坏了。
 */
export function createAppModeAction(): AppBarAction {
  return {
    id: 'app_mode_switch',
    priority: 5,
    render: () => <AppModeSwitch />,
  };
}

const MODE_ICON: Record<AppMode, string> = {
  live: 'flight_takeoff',
  review: 'history',
};

const MODE_LABEL_KEY: Record<AppMode, string> = {
  live: K.appModeLive,
  review: K.appModeReview,
};

function AppModeSwitch() {
  const t = useTranslate();
  const mode = useAppModeStore((state) => state.mode);
  const setMode = useAppModeStore((state) => state.setMode);

  return (
    <PopupMenu
      icon={MODE_ICON[mode]}
      // 命名占位符要传对象，传位置参数不会被替换（见 formatPlaceholders）
      label={t(K.appModeTooltip, { mode: t(MODE_LABEL_KEY[mode]) })}
      items={(['live', 'review'] as AppMode[]).map((candidate) => ({
        key: candidate,
        label: t(MODE_LABEL_KEY[candidate]),
        icon: MODE_ICON[candidate],
        selected: candidate === mode,
        onSelect: () => void setMode(candidate),
      }))}
    />
  );
}
