import '../data/checklists/a320_checklist.dart';
import '../data/checklists/b737_checklist.dart';
import '../models/flight_checklist.dart';

class ChecklistService {
  static final ChecklistService _instance = ChecklistService._internal();
  factory ChecklistService() => _instance;
  ChecklistService._internal();

  List<AircraftChecklist> getSupportedAircraft() {
    return [
      A320Checklist.create('A320-200 / A321 / A319'),
      B737Checklist.create('B737-800 / Max'),
    ];
  }
}
