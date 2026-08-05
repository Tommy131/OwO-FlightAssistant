import { translate } from '../../../core/services/localization-service';
import { ChecklistLocalizationKeys as K } from '../localization/checklist-localization';
import type { AircraftChecklist } from '../models/flight-checklist';

/**
 * 通用机型检查单
 *
 * 对应 Flutter 版 `modules/checklist/data/generic_checklist.dart`。
 * 与 A320/B737 不同，通用检查单的文案走国际化 key（而非内联中英文对照），
 * 因此切换语言后需要重新生成 —— 由 checklist-store 的重建逻辑处理。
 */
export function createGenericChecklist(name: string): AircraftChecklist {
  const t = translate;
  return {
    id: 'generic',
    name,
    family: 'generic',
    sections: [
      {
        phase: 'coldAndDark',
        items: [
          {
            id: 'g1_1',
            task: t(K.genericTaskParkingBrake),
            response: t(K.genericResponseSet),
            isChecked: false,
          },
          {
            id: 'g1_2',
            task: t(K.genericTaskBatteryPower),
            response: t(K.genericResponseOn),
            isChecked: false,
          },
          {
            id: 'g1_3',
            task: t(K.genericTaskAvionics),
            response: t(K.genericResponseChecked),
            isChecked: false,
          },
          {
            id: 'g1_4',
            task: t(K.genericTaskFlightPlan),
            response: t(K.genericResponseCompleted),
            isChecked: false,
          },
        ],
      },
      {
        phase: 'beforeTaxi',
        items: [
          {
            id: 'g2_1',
            task: t(K.genericTaskFlightControls),
            response: t(K.genericResponseFreeAndCorrect),
            isChecked: false,
          },
          {
            id: 'g2_2',
            task: t(K.genericTaskFlaps),
            response: t(K.genericResponseSetAsRequired),
            isChecked: false,
          },
          {
            id: 'g2_3',
            task: t(K.genericTaskInstrumentCheck),
            response: t(K.genericResponseCompleted),
            isChecked: false,
          },
        ],
      },
      {
        phase: 'beforeTakeoff',
        items: [
          {
            id: 'g3_1',
            task: t(K.genericTaskTakeoffBriefing),
            response: t(K.genericResponseBriefed),
            isChecked: false,
          },
          {
            id: 'g3_2',
            task: t(K.genericTaskLights),
            response: t(K.genericResponseTakeoff),
            isChecked: false,
          },
          {
            id: 'g3_3',
            task: t(K.genericTaskTransponder),
            response: t(K.genericResponseTaRa),
            isChecked: false,
          },
        ],
      },
      {
        phase: 'cruise',
        items: [
          {
            id: 'g4_1',
            task: t(K.genericTaskEngineParameters),
            response: t(K.genericResponseNormal),
            isChecked: false,
          },
          {
            id: 'g4_2',
            task: t(K.genericTaskRouteMonitoring),
            response: t(K.genericResponseNormal),
            isChecked: false,
          },
        ],
      },
      {
        phase: 'beforeApproach',
        items: [
          {
            id: 'g5_1',
            task: t(K.genericTaskApproachBriefing),
            response: t(K.genericResponseBriefed),
            isChecked: false,
          },
          {
            id: 'g5_2',
            task: t(K.genericTaskLandingData),
            response: t(K.genericResponseConfirmed),
            isChecked: false,
          },
        ],
      },
      {
        phase: 'afterLanding',
        items: [
          {
            id: 'g6_1',
            task: t(K.genericTaskFlaps),
            response: t(K.genericResponseUp),
            isChecked: false,
          },
          {
            id: 'g6_2',
            task: t(K.genericTaskLights),
            response: t(K.genericResponseTaxi),
            isChecked: false,
          },
        ],
      },
    ],
  };
}
