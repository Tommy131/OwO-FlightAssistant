import '../models/flight_checklist.dart';

class GenericChecklist {
  static AircraftChecklist create(String name) {
    return AircraftChecklist(
      id: 'generic',
      name: name,
      family: AircraftFamily.generic,
      sections: [
        ChecklistSection(
          phase: ChecklistPhase.coldAndDark,
          items: [
            ChecklistItem(id: 'g1_1', task: '停留刹车', response: '设置 (SET)'),
            ChecklistItem(id: 'g1_2', task: '电瓶电源', response: '接通 (ON)'),
            ChecklistItem(id: 'g1_3', task: '航电设备', response: '检查 (CHECKED)'),
            ChecklistItem(id: 'g1_4', task: '飞行计划', response: '完成 (COMPLETED)'),
          ],
        ),
        ChecklistSection(
          phase: ChecklistPhase.beforeTaxi,
          items: [
            ChecklistItem(id: 'g2_1', task: '飞行操纵', response: '自由且正确'),
            ChecklistItem(id: 'g2_2', task: '襟翼', response: '按需设置 (SET)'),
            ChecklistItem(id: 'g2_3', task: '仪表检查', response: '完成 (COMPLETED)'),
          ],
        ),
        ChecklistSection(
          phase: ChecklistPhase.beforeTakeoff,
          items: [
            ChecklistItem(id: 'g3_1', task: '起飞简令', response: '完成 (BRIEFED)'),
            ChecklistItem(id: 'g3_2', task: '灯光', response: '起飞位 (SET)'),
            ChecklistItem(id: 'g3_3', task: '应答机', response: 'TA/RA'),
          ],
        ),
        ChecklistSection(
          phase: ChecklistPhase.cruise,
          items: [
            ChecklistItem(id: 'g4_1', task: '发动机参数', response: '正常 (NORMAL)'),
            ChecklistItem(id: 'g4_2', task: '航迹监控', response: '正常 (NORMAL)'),
          ],
        ),
        ChecklistSection(
          phase: ChecklistPhase.beforeApproach,
          items: [
            ChecklistItem(id: 'g5_1', task: '进近简令', response: '完成 (BRIEFED)'),
            ChecklistItem(id: 'g5_2', task: '着陆数据', response: '确认 (CONFIRMED)'),
          ],
        ),
        ChecklistSection(
          phase: ChecklistPhase.afterLanding,
          items: [
            ChecklistItem(id: 'g6_1', task: '襟翼', response: '收上 (UP)'),
            ChecklistItem(id: 'g6_2', task: '灯光', response: '滑行位 (TAXI)'),
          ],
        ),
      ],
    );
  }
}
