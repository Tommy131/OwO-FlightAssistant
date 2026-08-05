import type { ModuleRegistrar } from '../../core/module-registry/clearable';
import { ModuleRegistry } from '../../core/module-registry/module-registry';
import { createNavigationItem } from '../../core/module-registry/navigation/navigation-item';
import { registerModuleTranslations, translate } from '../../core/services/localization-service';
import { useFlightDataStore } from '../common/providers/flight-data-store';
import {
  ChecklistLocalizationKeys,
  checklistTranslations,
} from './localization/checklist-localization';
import { PHASE_ICON, PHASE_LABEL_KEY } from './models/flight-checklist';
import { ChecklistPage } from './pages/checklist-page';
import { useChecklistStore } from './providers/checklist-store';

/**
 * Checklist 模块注册器
 *
 * 对应 Flutter 版 `modules/checklist/checklist_module.dart`。
 * 桌面版用 `ChangeNotifierProxyProvider<HomeProvider, ChecklistProvider>`
 * 监听机型字段与飞行数据；Web 版等价实现为 store 订阅绑定。
 */
export class ChecklistModule implements ModuleRegistrar {
  readonly moduleName = 'checklist';

  register(): void {
    registerModuleTranslations(checklistTranslations);

    ModuleRegistry.navigation.register(() =>
      createNavigationItem({
        id: 'checklist',
        title: translate(ChecklistLocalizationKeys.navTitle),
        icon: 'checklist',
        activeIcon: 'checklist',
        page: <ChecklistPage />,
        priority: 20,
        groupId: 'flight',
      }),
    );

    // ── 飞行数据 → 检查单：机型自动匹配 + 阶段自动推导 ──
    ModuleRegistry.providers.register({
      id: 'checklist_from_flight_data',
      setup: () =>
        useFlightDataStore.subscribe((state, previous) => {
          if (state.snapshot === previous.snapshot) return;
          const snapshot = state.snapshot;
          const flightData = snapshot.flightData;

          // 把所有机型线索拼成一个标识符串（与桌面版字段顺序一致）
          const identifier = [
            snapshot.aircraftTitle,
            flightData.aircraftDisplayName,
            flightData.aircraftManufacturer,
            flightData.aircraftFamily,
            flightData.aircraftModel,
            flightData.aircraftIcao,
            flightData.aircraftProfile,
            flightData.aircraftId,
          ]
            .filter((value): value is string => typeof value === 'string' && value.trim().length > 0)
            .join(' ');

          const checklist = useChecklistStore.getState();
          checklist.updateAircraftByIdentifier(identifier);
          checklist.syncWithFlightData(flightData);
        }),
    });

    // ── 检查单 → 飞行快照：把当前阶段与进度回填给首页的 ChecklistPhaseCard ──
    //
    // 注：桌面版的 `MiddlewareFlightDataAdapter` 声明了 `_checklistPhase` /
    // `_checklistProgress` 却从未赋值，导致首页那张卡片恒为空。这里补上回填，
    // 让卡片按设计生效。
    ModuleRegistry.providers.register({
      id: 'flight_snapshot_from_checklist',
      setup: () =>
        useChecklistStore.subscribe((state, previous) => {
          if (
            state.currentPhase === previous.currentPhase &&
            state.selectedAircraft === previous.selectedAircraft
          ) {
            return;
          }
          const phase = state.currentPhase;
          const progress = state.getPhaseProgress(phase);

          useFlightDataStore.setState((flightState) => {
            const snapshot = flightState.snapshot;
            // 值未变则不重建快照对象 —— 否则会反向触发
            // flight → checklist 绑定，形成回环。
            if (
              snapshot.checklistPhase?.labelKey === PHASE_LABEL_KEY[phase] &&
              snapshot.checklistProgress === progress
            ) {
              return flightState;
            }
            return {
              snapshot: {
                ...snapshot,
                checklistPhase: {
                  labelKey: PHASE_LABEL_KEY[phase],
                  icon: PHASE_ICON[phase],
                },
                checklistProgress: progress,
              },
            };
          });
        }),
    });
  }
}
