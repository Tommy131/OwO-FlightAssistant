import { create } from 'zustand';
import { useTranslate } from '../../../core/localization/use-translate';
import { useIsDesktopLayout } from '../../../core/layouts/responsive';
import { SegmentedControl } from '../../../core/widgets/common/controls';
import { ToolboxLocalizationKeys as K } from '../localization/toolbox-localization';
import type { ToolboxSection } from '../models/toolbox-models';
import { FlightCalculatorsTab } from './widgets/flight-calculators-tab';
import { OpsToolsTab } from './widgets/ops-tools-tab';
import { PerformanceToolsTab } from './widgets/performance-tools-tab';
import { TermsTranslationTab, UnitConversionTab } from './widgets/unit-and-terms-tabs';
import { WeatherDecodeTab } from './widgets/weather-decode-tab';
import styles from './toolbox-page.module.css';

/**
 * 工具箱页面
 *
 * 对应 Flutter 版 `modules/toolbox/pages/toolbox_page.dart`。
 * 6 个分区通过 AppBarActionRegistry 注册为侧边二级菜单（移动端为抽屉），
 * 桌面端在页面顶部另附一排分段控件方便直接切换。
 */

interface ToolboxSectionState {
  selectedSection: ToolboxSection;
  select: (section: ToolboxSection) => void;
}

/**
 * 分区选择器
 *
 * 对应桌面版的 `ToolboxSectionController.instance` 单例 —— 模块注册的
 * 侧边二级菜单项与页面本身都读写它，因此必须是模块级共享状态。
 */
export const useToolboxSectionStore = create<ToolboxSectionState>((set) => ({
  selectedSection: 'unitConversion',
  select: (section) => set({ selectedSection: section }),
}));

/** 各分区的图标与标题 key（模块注册二级菜单时复用） */
export const TOOLBOX_SECTION_META: Record<
  ToolboxSection,
  { icon: string; titleKey: string; priority: number }
> = {
  unitConversion: { icon: 'calculate', titleKey: K.unitTab, priority: 10 },
  termTranslation: { icon: 'translate', titleKey: K.termsTab, priority: 20 },
  flightCalculators: { icon: 'flight_takeoff', titleKey: K.calculatorsTab, priority: 30 },
  weatherDecode: { icon: 'cloud', titleKey: K.weatherTab, priority: 40 },
  performanceTools: { icon: 'speed', titleKey: K.performanceTab, priority: 50 },
  opsTools: { icon: 'warning', titleKey: K.opsTab, priority: 60 },
};

const SECTION_ORDER: ToolboxSection[] = [
  'unitConversion',
  'termTranslation',
  'flightCalculators',
  'weatherDecode',
  'performanceTools',
  'opsTools',
];

export function ToolboxPage() {
  const t = useTranslate();
  const isDesktop = useIsDesktopLayout();
  const selectedSection = useToolboxSectionStore((s) => s.selectedSection);
  const select = useToolboxSectionStore((s) => s.select);

  return (
    <div className={styles.page}>
      {isDesktop && (
        <div className={styles.sectionBar}>
          <SegmentedControl
            value={selectedSection}
            options={SECTION_ORDER.map((section) => ({
              value: section,
              label: t(TOOLBOX_SECTION_META[section].titleKey),
              icon: TOOLBOX_SECTION_META[section].icon,
            }))}
            onChange={select}
          />
        </div>
      )}

      <div className={`${styles.content} scroll-area`}>
        <SectionContent section={selectedSection} />
      </div>
    </div>
  );
}

function SectionContent({ section }: { section: ToolboxSection }) {
  switch (section) {
    case 'unitConversion':
      return <UnitConversionTab />;
    case 'termTranslation':
      return <TermsTranslationTab />;
    case 'flightCalculators':
      return <FlightCalculatorsTab />;
    case 'weatherDecode':
      return <WeatherDecodeTab />;
    case 'performanceTools':
      return <PerformanceToolsTab />;
    case 'opsTools':
      return <OpsToolsTab />;
  }
}
