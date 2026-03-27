// theme_provider.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'app_theme_data.dart';
import '../services/persistence_service.dart';
import '../utils/logger.dart';
import '../localization/localization_keys.dart';
import '../services/localization_service.dart';

/// 主题管理器（整合版）
/// 管理应用的主题配色和主题模式（跟随系统、亮色、暗色）
class ThemeProvider extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _currentThemeKey = 'current_theme';
  static const String _lightContrastKey = 'light_contrast_adjustment';
  static const String _darkContrastKey = 'dark_contrast_adjustment';

  ThemeMode _themeMode = ThemeMode.system;
  AppThemeData _currentTheme;
  double _lightContrastAdjustment = 0.0;
  double _darkContrastAdjustment = 0.0;

  ThemeProvider({
    AppThemeData? initialTheme,
    ThemeMode initialMode = ThemeMode.system,
  }) : _currentTheme = initialTheme ?? AppThemeData.presetThemes.first,
       _themeMode = initialMode {
    load();
  }

  // ============ Getters ============
  ThemeMode get themeMode => _themeMode;
  AppThemeData get currentTheme => _currentTheme;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isSystemMode => _themeMode == ThemeMode.system;
  double get lightContrastAdjustment => _lightContrastAdjustment;
  double get darkContrastAdjustment => _darkContrastAdjustment;

  /// 获取当前活跃模式下的对比度调整值
  double get currentContrastAdjustment {
    if (_themeMode == ThemeMode.light) return _lightContrastAdjustment;
    if (_themeMode == ThemeMode.dark) return _darkContrastAdjustment;
    // 如果是跟随系统，则根据当前系统亮度返回
    return _darkContrastAdjustment; // 默认深色
  }

  // ============ 主题配色切换（新增功能）============

  /// 切换主题配色
  Future<void> setTheme(AppThemeData theme) async {
    if (_currentTheme == theme) return;

    _currentTheme = theme;
    notifyListeners();
    await _saveToPersistence();
  }

  /// 创建自定义主题
  Future<void> createCustomTheme(
    Color primaryColor,
    String name, {
    Color? secondaryColor,
    Color? accentColor,
  }) async {
    final customTheme = AppThemeData(
      name: name,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor ?? primaryColor.withValues(alpha: 0.7),
      accentColor: accentColor ?? primaryColor.withValues(alpha: 0.5),
      isCustom: true,
    );
    await setTheme(customTheme);
  }

  // ============ 主题模式切换（保留原有功能）============

  /// 设置主题模式（system/light/dark）
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();
    await _saveToPersistence();
  }

  /// 切换到下一个主题模式（循环切换）
  Future<void> toggleThemeMode() async {
    final modes = ThemeMode.values;
    final currentIndex = modes.indexOf(_themeMode);
    final nextIndex = (currentIndex + 1) % modes.length;
    await setThemeMode(modes[nextIndex]);
  }

  /// 切换深色模式开关（仅在 light 和 dark 之间切换）
  Future<void> toggleDarkMode() async {
    if (_themeMode == ThemeMode.system) {
      await setThemeMode(ThemeMode.dark);
    } else {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
      notifyListeners();
      await _saveToPersistence();
    }
  }

  /// 设置亮色模式对比度调整
  Future<void> setLightContrastAdjustment(double level) async {
    if (_lightContrastAdjustment == level) return;
    _lightContrastAdjustment = level.clamp(0.0, 1.0);
    notifyListeners();
    await _saveToPersistence();
  }

  /// 设置深色模式对比度调整
  Future<void> setDarkContrastAdjustment(double level) async {
    if (_darkContrastAdjustment == level) return;
    _darkContrastAdjustment = level.clamp(0.0, 1.0);
    notifyListeners();
    await _saveToPersistence();
  }

  /// 获取主题模式的显示名称
  String getThemeModeName(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return LocalizationKeys.themeModeSystem.tr(context);
      case ThemeMode.light:
        return LocalizationKeys.themeModeLight.tr(context);
      case ThemeMode.dark:
        return LocalizationKeys.themeModeDark.tr(context);
    }
  }

  /// 获取主题模式的图标
  IconData getThemeModeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.brightness_auto;
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
    }
  }

  // ============ 持久化存储 ============

  /// 保存到本地存储
  Future<void> _saveToPersistence() async {
    try {
      final persistence = PersistenceService();
      if (!persistence.isInitialized) return;

      // 保存主题配色
      await persistence.setString(
        _currentThemeKey,
        json.encode(_currentTheme.toJson()),
      );

      // 保存主题模式
      await persistence.setInt(_themeModeKey, _themeMode.index);

      // 保存设置
      await persistence.setDouble(_lightContrastKey, _lightContrastAdjustment);
      await persistence.setDouble(_darkContrastKey, _darkContrastAdjustment);
    } catch (e) {
      AppLogger.warning('Failed to save theme settings: $e');
    }
  }

  /// 从本地存储加载
  Future<void> load() async {
    try {
      final persistence = PersistenceService();
      // 如果服务尚未初始化，延迟加载或等待
      // 在应用的主流程中应该保证初始化完成后再使用 ThemeProvider
      if (!persistence.isInitialized) return;

      // 加载主题配色
      final themeJson = persistence.getString(_currentThemeKey);
      if (themeJson != null) {
        _currentTheme = AppThemeData.fromJson(json.decode(themeJson));
      }

      // 加载主题模式
      final themeModeIndex = persistence.getInt(_themeModeKey);
      if (themeModeIndex != null && themeModeIndex < ThemeMode.values.length) {
        _themeMode = ThemeMode.values[themeModeIndex];
      }

      // 加载设置
      _lightContrastAdjustment =
          persistence.getDouble(_lightContrastKey) ?? 0.0;
      _darkContrastAdjustment = persistence.getDouble(_darkContrastKey) ?? 0.0;

      notifyListeners();
      AppLogger.info('ThemeProvider loaded settings from persistence');
    } catch (e) {
      AppLogger.warning('加载主题设置失败: $e');
      // 使用默认值
      _currentTheme = AppThemeData.presetThemes.first;
      _themeMode = ThemeMode.system;
      notifyListeners();
    }
  }

  /// 重置为默认主题
  Future<void> resetToDefault() async {
    _currentTheme = AppThemeData.presetThemes.first;
    _themeMode = ThemeMode.system;
    _lightContrastAdjustment = 0.0;
    _darkContrastAdjustment = 0.0;
    notifyListeners();
    await _saveToPersistence();
  }
}
