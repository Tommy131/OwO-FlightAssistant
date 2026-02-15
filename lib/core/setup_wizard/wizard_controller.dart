import 'package:flutter/material.dart';
import '../services/persistence_service.dart';
import '../services/bootstrap_service.dart';
import '../utils/logger.dart';
import 'wizard_step.dart';

class WizardController extends ChangeNotifier {
  int _currentStep = 0;
  final List<WizardStep> _steps;

  String? _selectedPath;
  String _languageCode = 'zh_CN';
  bool _logEnabled = true;
  bool _isCompleted = false;
  VoidCallback? onCompleted;

  WizardController({required List<WizardStep> steps}) : _steps = steps {
    if (_steps.isNotEmpty) {
      _steps[0].onInit();
    }
    // 获取当前保存的语言
    final savedLanguage = PersistenceService().getString('language_code');
    if (savedLanguage != null) {
      _languageCode = savedLanguage;
    }
  }

  int get currentStep => _currentStep;
  int get totalSteps => _steps.length;
  String? get selectedPath => _selectedPath;
  String get languageCode => _languageCode;

  /// 获取处理后的预览路径（追加 AppName）
  String? get previewPath {
    if (_selectedPath == null) return null;
    return PersistenceService.getProcessedRootPath(_selectedPath!);
  }

  bool get logEnabled => _logEnabled;
  bool get isCompleted => _isCompleted;

  // 进度计算
  double get progress => (_currentStep + 1) / totalSteps;

  int get remainingItems => totalSteps - (_currentStep + 1);

  String get currentStepTitle => _steps[_currentStep].title;

  WizardStep get currentStepInstance => _steps[_currentStep];

  /// 根据索引获取步骤实例
  WizardStep getStepAt(int index) {
    if (index < 0 || index >= _steps.length) {
      throw RangeError('Step index out of range: $index');
    }
    return _steps[index];
  }

  void setSelectedPath(String path) {
    _selectedPath = path;
    notifyListeners();
  }

  void setLanguageCode(String code) {
    _languageCode = code;
    notifyListeners();
  }

  void setLogEnabled(bool value) {
    _logEnabled = value;
    notifyListeners();
  }

  bool get canGoNext {
    // 存储路径步骤必须选择路径
    // 我们检查步骤 ID 而不是索引，因为增加了语言步骤
    final currentStepId = _steps[_currentStep].id;
    if (currentStepId == 'storage_path' && _selectedPath == null) {
      return false;
    }
    return _steps[_currentStep].canGoNext();
  }

  void nextStep() {
    if (canGoNext) {
      if (_currentStep < totalSteps - 1) {
        _steps[_currentStep].onComplete();
        _currentStep++;
        _steps[_currentStep].onInit();
        notifyListeners();
      } else {
        _complete();
      }
    }
  }

  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      _steps[_currentStep].onInit();
      notifyListeners();
    }
  }

  Future<void> _complete() async {
    if (_selectedPath != null) {
      await _steps[_currentStep].onComplete();

      // 1. 初始化持久化服务（内部会自动处理追加 AppName 和清洗）
      await PersistenceService().init(customPath: _selectedPath);

      // 2. 获取最终生效的完整路径
      final finalRootPath = PersistenceService().rootPath!;

      // 3. 保存配置
      await PersistenceService().setString('language_code', _languageCode);
      await PersistenceService().setBool('log_enabled', _logEnabled);
      // 同时保存到引导文件（核心：确保下次启动能找到路径）
      final bootstrap = BootstrapService();
      await bootstrap.setDataPath(finalRootPath);
      await bootstrap.setFirstLaunch(false);

      // 4. 重构：不再在 PersistenceService 中独立存储 is_first_launch 和 data_root_path
      // 因为它们现在的权威版本在 bootstrap.json 中

      // 4. 初始化日志
      await AppLogger.init();

      _isCompleted = true;
      notifyListeners();
      onCompleted?.call();
    }
  }
}
