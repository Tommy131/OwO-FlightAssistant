import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../common/models/common_models.dart';
import '../models/flight_checklist.dart';
import '../services/aircraft_resolver.dart';
import '../services/checklist_service.dart';
import '../services/flight_phase_deriver.dart';

/// 检查单状态管理器
///
/// 负责管理：
///   - 机型列表与已选机型
///   - 当前飞行阶段（含自动同步）
///   - 检查单条目的勾选状态
///   - 文件导入/导出/刷新操作
///
/// 飞行阶段推导委托给 [FlightPhaseDeriver]，
/// 机型匹配委托给 [AircraftResolver]。
class ChecklistProvider with ChangeNotifier {
  final ChecklistService _service = ChecklistService();
  final AircraftResolver _resolver = AircraftResolver();
  final FlightPhaseDeriver _phaseDeriver = FlightPhaseDeriver();

  List<AircraftChecklist> _aircraftList = [];
  AircraftChecklist? _selectedAircraft;
  ChecklistPhase _currentPhase = ChecklistPhase.coldAndDark;
  bool _isLoading = false;

  /// 保存上次请求匹配的标识符，用于加载完成后自动选中机型
  String? _pendingIdentifier;

  List<AircraftChecklist> get aircraftList => _aircraftList;
  AircraftChecklist? get selectedAircraft => _selectedAircraft;
  ChecklistPhase get currentPhase => _currentPhase;
  bool get isLoading => _isLoading;

  ChecklistProvider() {
    _init();
  }

  Future<void> _init() async {
    await reloadFromDirectory(fallbackToBuiltIn: true);
    updateAircraftByIdentifier(_pendingIdentifier);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 机型选择
  // ──────────────────────────────────────────────────────────────────────────

  /// 根据 ID 手动选择机型，并将阶段重置为初始阶段
  void selectAircraft(String id) {
    for (final aircraft in _aircraftList) {
      if (aircraft.id == id) {
        _selectedAircraft = aircraft;
        _currentPhase = ChecklistPhase.coldAndDark;
        notifyListeners();
        return;
      }
    }
  }

  /// 根据机型标识符字符串自动匹配并选中机型
  /// 返回 true 表示成功切换，false 表示未变更
  Future<bool> updateAircraftByIdentifier(String? identifier) async {
    _pendingIdentifier = identifier;
    if (_isLoading || _aircraftList.isEmpty) return false;

    final selected = _resolver.resolve(
      identifier: identifier,
      aircraftList: _aircraftList,
    );
    if (selected == null) return false;
    if (_selectedAircraft?.id == selected.id) return true;

    _selectedAircraft = selected;
    _currentPhase = ChecklistPhase.coldAndDark;
    notifyListeners();
    return true;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 飞行阶段
  // ──────────────────────────────────────────────────────────────────────────

  /// 手动设置当前飞行阶段
  void setPhase(ChecklistPhase phase) {
    _currentPhase = phase;
    notifyListeners();
  }

  /// 根据实时飞行数据同步飞行阶段（自动推导，仅在满足阶段推进规则时生效）
  void syncWithFlightData(HomeFlightData flightData) {
    if (_selectedAircraft == null) return;
    final next = _phaseDeriver.derive(flightData);
    if (next == null || next == _currentPhase) return;
    if (!_phaseDeriver.shouldApply(current: _currentPhase, next: next)) return;
    _currentPhase = next;
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 检查单条目操作
  // ──────────────────────────────────────────────────────────────────────────

  /// 切换指定条目的勾选状态
  void toggleItem(String itemId) {
    if (_selectedAircraft == null) return;
    for (final section in _selectedAircraft!.sections) {
      for (final item in section.items) {
        if (item.id == itemId) {
          item.isChecked = !item.isChecked;
          notifyListeners();
          return;
        }
      }
    }
  }

  /// 重置当前飞行阶段下所有条目的勾选状态
  void resetCurrentPhase() {
    if (_selectedAircraft == null) return;
    ChecklistSection? target;
    for (final section in _selectedAircraft!.sections) {
      if (section.phase == _currentPhase) {
        target = section;
        break;
      }
    }
    if (target == null) return;
    for (final item in target.items) {
      item.isChecked = false;
    }
    notifyListeners();
  }

  /// 重置所有阶段的勾选状态，并回到初始阶段
  void resetAll() {
    if (_selectedAircraft == null) return;
    for (final section in _selectedAircraft!.sections) {
      for (final item in section.items) {
        item.isChecked = false;
      }
    }
    _currentPhase = ChecklistPhase.coldAndDark;
    notifyListeners();
  }

  /// 获取指定阶段的完成进度（0.0 ~ 1.0）
  double getPhaseProgress(ChecklistPhase phase) {
    if (_selectedAircraft == null) return 0;
    ChecklistSection? target;
    for (final section in _selectedAircraft!.sections) {
      if (section.phase == phase) {
        target = section;
        break;
      }
    }
    if (target == null) return 0.0;
    if (target.items.isEmpty) return 1.0;
    final checked = target.items.where((i) => i.isChecked).length;
    return checked / target.items.length;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 文件操作
  // ──────────────────────────────────────────────────────────────────────────

  /// 从用户检查单目录重新加载配置
  /// [fallbackToBuiltIn] 为 true 时，若目录为空则回退至内建检查单
  /// 返回加载的外部机型数量（0 表示使用内建，>0 表示已加载外部）
  Future<int> reloadFromDirectory({bool fallbackToBuiltIn = true}) async {
    _isLoading = true;
    _selectedAircraft = null;
    notifyListeners();

    final loaded = await _service.loadFromDirectory();
    if (loaded.isEmpty && fallbackToBuiltIn) {
      _applyAircraftList(_service.getBuiltInChecklists());
      _isLoading = false;
      notifyListeners();
      return 0;
    }
    if (loaded.isNotEmpty) _applyAircraftList(loaded);

    _isLoading = false;
    updateAircraftByIdentifier(_pendingIdentifier);
    notifyListeners();
    return loaded.length;
  }

  /// 通过文件选择器导入检查单（支持 json / txt / csv）
  /// 返回值：>0 成功导入条数，0 解析失败，-1 用户取消
  Future<int> importFromFilePicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'txt', 'csv'],
    );
    final filePath = result?.files.single.path;
    if (filePath == null) return -1;

    final loaded = await _service.loadFromFile(File(filePath));
    if (loaded.isEmpty) return 0;

    _mergeAircraftList(loaded);
    final sourceName = result?.files.single.name;
    if (sourceName != null && sourceName.trim().isNotEmpty) {
      final hint = sourceName.replaceAll(RegExp(r'\.[^.]+$'), '');
      _selectedAircraft =
          _resolver.resolve(identifier: hint, aircraftList: _aircraftList) ??
          _selectedAircraft;
    }
    notifyListeners();
    return loaded.length;
  }

  /// 通过文件选择器将当前检查单导出为 JSON 文件
  /// 返回值：1 成功，0 用户取消，-1 无数据可导出
  Future<int> exportToFilePicker() async {
    if (_aircraftList.isEmpty) return -1;
    final filePath = await FilePicker.platform.saveFile(
      fileName: 'checklist_export.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (filePath == null) return 0;
    await _service.exportToFile(_aircraftList, filePath);
    return 1;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 内部列表管理
  // ──────────────────────────────────────────────────────────────────────────

  /// 直接替换机型列表，尽量保留当前已选机型
  void _applyAircraftList(List<AircraftChecklist> list) {
    _aircraftList = list;
    if (_aircraftList.isEmpty) {
      _selectedAircraft = null;
      return;
    }
    final selectedId = _selectedAircraft?.id;
    if (selectedId != null) {
      for (final aircraft in _aircraftList) {
        if (aircraft.id == selectedId) {
          _selectedAircraft = aircraft;
          _currentPhase = ChecklistPhase.coldAndDark;
          return;
        }
      }
    }
    _selectedAircraft = _aircraftList.first;
    _currentPhase = ChecklistPhase.coldAndDark;
  }

  /// 将导入的机型并入现有列表（按 ID 去重，同 ID 则覆盖）
  void _mergeAircraftList(List<AircraftChecklist> imported) {
    final byId = <String, AircraftChecklist>{
      for (final a in _aircraftList) a.id: a,
    };
    for (final a in imported) {
      byId[a.id] = a;
    }
    _aircraftList = byId.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (_selectedAircraft == null && _aircraftList.isNotEmpty) {
      _selectedAircraft = _aircraftList.first;
      _currentPhase = ChecklistPhase.coldAndDark;
    }
  }
}
