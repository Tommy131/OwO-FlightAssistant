import { useState } from 'react';
import { useLocalizationStore } from '../../services/localization-service';
import { ModuleRegistry } from '../../module-registry/module-registry';
import type { NavigationItem } from '../../module-registry/navigation/navigation-item';
import { useWindowWidth } from '../../layouts/responsive';
import { MaterialIcon } from '../common/icon';
import { MarqueeText } from '../common/marquee-text';
import styles from './bottom-navbar.module.css';

/**
 * 移动端底部导航栏
 *
 * 对应 Flutter 版 `core/widgets/mobile/bottom_navbar.dart`：
 * 窄屏 4 个槽位、宽屏 5 个；超出部分收进「更多」抽屉。
 */
export interface MobileBottomNavbarProps {
  items: NavigationItem[];
  selectedIndex: number;
  onItemSelected: (index: number) => void;
}

export function MobileBottomNavbar({
  items,
  selectedIndex,
  onItemSelected,
}: MobileBottomNavbarProps) {
  const width = useWindowWidth();
  const locale = useLocalizationStore((state) => state.locale);
  const [moreOpen, setMoreOpen] = useState(false);

  const maxSlots = width < 360 ? 4 : 5;
  const hasOverflow = items.length > maxSlots;
  const primaryCount = hasOverflow ? maxSlots - 1 : items.length;
  const primaryItems = items.slice(0, primaryCount);
  const overflowItems = hasOverflow ? items.slice(primaryCount) : [];
  const isMoreSelected = hasOverflow && selectedIndex >= primaryCount;

  const moreLabel = locale === 'zh_CN' ? '更多' : locale === 'de_DE' ? 'Mehr' : 'More';

  return (
    <>
      {moreOpen && (
        <div className={styles.moreSheetScrim} onClick={() => setMoreOpen(false)}>
          <div
            className={styles.moreSheet}
            onClick={(event) => event.stopPropagation()}
            role="menu"
          >
            <div className={styles.moreHandle} />
            <div className={styles.moreGrid}>
              {overflowItems.map((item, offset) => {
                const index = primaryCount + offset;
                return (
                  <OverflowItem
                    key={item.id}
                    item={item}
                    isSelected={selectedIndex === index}
                    onSelect={() => {
                      setMoreOpen(false);
                      onItemSelected(index);
                    }}
                  />
                );
              })}
            </div>
          </div>
        </div>
      )}

      <nav className={styles.navbar} aria-label={moreLabel}>
        {primaryItems.map((item, index) => (
          <NavSlot
            key={item.id}
            item={item}
            isSelected={selectedIndex === index}
            onSelect={() => onItemSelected(index)}
          />
        ))}

        {hasOverflow && (
          <button
            type="button"
            className={`${styles.slot}${isMoreSelected ? ` ${styles.slotSelected}` : ''}`}
            onClick={() => setMoreOpen(true)}
            aria-label={moreLabel}
          >
            <MaterialIcon name="more_horiz" filled={isMoreSelected} size={22} />
            <MarqueeText text={moreLabel} className={styles.slotLabel} />
          </button>
        )}
      </nav>
    </>
  );
}

function NavSlot({
  item,
  isSelected,
  onSelect,
}: {
  item: NavigationItem;
  isSelected: boolean;
  onSelect: () => void;
}) {
  const isEnabled = ModuleRegistry.navigationAvailability.isEnabled(item);
  return (
    <button
      type="button"
      onClick={isEnabled ? onSelect : undefined}
      disabled={!isEnabled}
      aria-current={isSelected ? 'page' : undefined}
      className={[
        styles.slot,
        isSelected ? styles.slotSelected : '',
        !isEnabled ? styles.slotDisabled : '',
      ]
        .filter(Boolean)
        .join(' ')}
    >
      <span className={styles.slotIconWrap}>
        <MaterialIcon
          name={isSelected && item.activeIcon ? item.activeIcon : item.icon}
          filled={isSelected}
          size={22}
        />
        {item.badge && <span className={styles.slotBadge}>{item.badge}</span>}
      </span>
      <MarqueeText text={item.title} className={styles.slotLabel} />
    </button>
  );
}

function OverflowItem({
  item,
  isSelected,
  onSelect,
}: {
  item: NavigationItem;
  isSelected: boolean;
  onSelect: () => void;
}) {
  const isEnabled = ModuleRegistry.navigationAvailability.isEnabled(item);
  return (
    <button
      type="button"
      role="menuitem"
      onClick={isEnabled ? onSelect : undefined}
      disabled={!isEnabled}
      className={[
        styles.moreItem,
        isSelected ? styles.moreItemSelected : '',
        !isEnabled ? styles.slotDisabled : '',
      ]
        .filter(Boolean)
        .join(' ')}
    >
      <MaterialIcon
        name={isSelected && item.activeIcon ? item.activeIcon : item.icon}
        filled={isSelected}
        size={24}
      />
      <MarqueeText text={item.title} className={styles.moreItemLabel} />
    </button>
  );
}
