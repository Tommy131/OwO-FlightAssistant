import '../models/flight_checklist.dart';
import '../localization/checklist_localization_keys.dart';
import '../../../core/services/localization_service.dart';

class GenericChecklist {
  static AircraftChecklist create(String name) {
    final t = LocalizationService().translate;
    return AircraftChecklist(
      id: 'generic',
      name: name,
      family: AircraftFamily.generic,
      sections: [
        ChecklistSection(
          phase: ChecklistPhase.coldAndDark,
          items: [
            ChecklistItem(
              id: 'g1_1',
              task: t(ChecklistLocalizationKeys.genericTaskParkingBrake),
              response: t(ChecklistLocalizationKeys.genericResponseSet),
            ),
            ChecklistItem(
              id: 'g1_2',
              task: t(ChecklistLocalizationKeys.genericTaskBatteryPower),
              response: t(ChecklistLocalizationKeys.genericResponseOn),
            ),
            ChecklistItem(
              id: 'g1_3',
              task: t(ChecklistLocalizationKeys.genericTaskAvionics),
              response: t(ChecklistLocalizationKeys.genericResponseChecked),
            ),
            ChecklistItem(
              id: 'g1_4',
              task: t(ChecklistLocalizationKeys.genericTaskFlightPlan),
              response: t(ChecklistLocalizationKeys.genericResponseCompleted),
            ),
          ],
        ),
        ChecklistSection(
          phase: ChecklistPhase.beforeTaxi,
          items: [
            ChecklistItem(
              id: 'g2_1',
              task: t(ChecklistLocalizationKeys.genericTaskFlightControls),
              response: t(
                ChecklistLocalizationKeys.genericResponseFreeAndCorrect,
              ),
            ),
            ChecklistItem(
              id: 'g2_2',
              task: t(ChecklistLocalizationKeys.genericTaskFlaps),
              response: t(
                ChecklistLocalizationKeys.genericResponseSetAsRequired,
              ),
            ),
            ChecklistItem(
              id: 'g2_3',
              task: t(ChecklistLocalizationKeys.genericTaskInstrumentCheck),
              response: t(ChecklistLocalizationKeys.genericResponseCompleted),
            ),
          ],
        ),
        ChecklistSection(
          phase: ChecklistPhase.beforeTakeoff,
          items: [
            ChecklistItem(
              id: 'g3_1',
              task: t(ChecklistLocalizationKeys.genericTaskTakeoffBriefing),
              response: t(ChecklistLocalizationKeys.genericResponseBriefed),
            ),
            ChecklistItem(
              id: 'g3_2',
              task: t(ChecklistLocalizationKeys.genericTaskLights),
              response: t(ChecklistLocalizationKeys.genericResponseTakeoff),
            ),
            ChecklistItem(
              id: 'g3_3',
              task: t(ChecklistLocalizationKeys.genericTaskTransponder),
              response: t(ChecklistLocalizationKeys.genericResponseTaRa),
            ),
          ],
        ),
        ChecklistSection(
          phase: ChecklistPhase.cruise,
          items: [
            ChecklistItem(
              id: 'g4_1',
              task: t(ChecklistLocalizationKeys.genericTaskEngineParameters),
              response: t(ChecklistLocalizationKeys.genericResponseNormal),
            ),
            ChecklistItem(
              id: 'g4_2',
              task: t(ChecklistLocalizationKeys.genericTaskRouteMonitoring),
              response: t(ChecklistLocalizationKeys.genericResponseNormal),
            ),
          ],
        ),
        ChecklistSection(
          phase: ChecklistPhase.beforeApproach,
          items: [
            ChecklistItem(
              id: 'g5_1',
              task: t(ChecklistLocalizationKeys.genericTaskApproachBriefing),
              response: t(ChecklistLocalizationKeys.genericResponseBriefed),
            ),
            ChecklistItem(
              id: 'g5_2',
              task: t(ChecklistLocalizationKeys.genericTaskLandingData),
              response: t(ChecklistLocalizationKeys.genericResponseConfirmed),
            ),
          ],
        ),
        ChecklistSection(
          phase: ChecklistPhase.afterLanding,
          items: [
            ChecklistItem(
              id: 'g6_1',
              task: t(ChecklistLocalizationKeys.genericTaskFlaps),
              response: t(ChecklistLocalizationKeys.genericResponseUp),
            ),
            ChecklistItem(
              id: 'g6_2',
              task: t(ChecklistLocalizationKeys.genericTaskLights),
              response: t(ChecklistLocalizationKeys.genericResponseTaxi),
            ),
          ],
        ),
      ],
    );
  }
}
