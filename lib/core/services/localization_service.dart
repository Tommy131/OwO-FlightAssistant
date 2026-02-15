import 'package:flutter/material.dart';
import '../localization/languages/zh_cn.dart';
import '../localization/languages/en_us.dart';
import 'persistence_service.dart';

class LocalizationService extends ChangeNotifier {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  Locale _currentLocale = const Locale('zh', 'CN');

  final Map<String, Map<String, String>> _coreLocalizedValues = {
    'zh_CN': zhCN,
    'en_US': enUS,
  };
  final Map<String, Map<String, String>> _moduleLocalizedValues = {};

  Locale get currentLocale => _currentLocale;

  String get currentLanguageCode =>
      '${_currentLocale.languageCode}_${_currentLocale.countryCode}';

  List<Map<String, String>> get supportedLanguages => [
    {'code': 'zh_CN', 'name': '简体中文'},
    {'code': 'en_US', 'name': 'English'},
  ];

  Future<void> init() async {
    final persistence = PersistenceService();
    final savedLocale = persistence.getString('language_code');
    if (savedLocale != null) {
      final parts = savedLocale.split('_');
      if (parts.length == 2) {
        _currentLocale = Locale(parts[0], parts[parts.length - 1]);
      }
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _currentLocale = locale;
    final persistence = PersistenceService();
    await persistence.setString(
      'language_code',
      '${locale.languageCode}_${locale.countryCode}',
    );
    notifyListeners();
  }

  void registerModuleTranslations(
    Map<String, Map<String, String>> translations,
  ) {
    translations.forEach((language, values) {
      final target = _moduleLocalizedValues.putIfAbsent(language, () => {});
      target.addAll(values);
    });
    notifyListeners();
  }

  String translate(String key) {
    final languageCode = currentLanguageCode;
    final moduleValue = _moduleLocalizedValues[languageCode]?[key];
    if (moduleValue != null) return moduleValue;
    return _coreLocalizedValues[languageCode]?[key] ?? key;
  }
}

// Extension to make it easier to use in widgets
extension LocalizationExtension on String {
  String tr(BuildContext context) {
    return LocalizationService().translate(this);
  }
}
