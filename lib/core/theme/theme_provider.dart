// theme_provider.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'app_theme_data.dart';
import '../services/persistence/persistence_service.dart';

/// 主题管理器（整合版）
/// 管理应用的主题配色和主题模式（跟随系统、亮色、暗色）
class ThemeProvider extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _currentThemeKey = 'current_theme';

  ThemeMode _themeMode = ThemeMode.system;
  AppThemeData _currentTheme;

  ThemeProvider({
    AppThemeData? initialTheme,
    ThemeMode initialMode = ThemeMode.system,
  }) : _currentTheme = initialTheme ?? AppThemeData.presetThemes.first,
       _themeMode = initialMode {
    _loadFromPreferences();
  }

  // ============ Getters ============
  ThemeMode get themeMode => _themeMode;
  AppThemeData get currentTheme => _currentTheme;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  // ============ 主题配色切换 ============

  /// 切换主题配色
  Future<void> setTheme(AppThemeData theme) async {
    if (_currentTheme == theme) return;

    _currentTheme = theme;
    notifyListeners();
    await _saveToPreferences();
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

  // ============ 主题模式切换 ============

  /// 设置主题模式（system/light/dark）
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();
    await _saveToPreferences();
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
      await _saveToPreferences();
    }
  }

  /// 获取主题模式的显示名称
  String getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.light:
        return '亮色模式';
      case ThemeMode.dark:
        return '暗色模式';
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
  Future<void> _saveToPreferences() async {
    try {
      final persistence = PersistenceService();

      // 保存主题配色
      await persistence.setString(
        _currentThemeKey,
        json.encode(_currentTheme.toJson()),
      );

      // 保存主题模式
      await persistence.setInt(_themeModeKey, _themeMode.index);
    } catch (e) {
      debugPrint('保存主题设置失败: $e');
    }
  }

  /// 从本地存储加载
  Future<void> _loadFromPreferences() async {
    try {
      final persistence = PersistenceService();

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

      notifyListeners();
    } catch (e) {
      debugPrint('加载主题设置失败: $e');
      // 使用默认值
      _currentTheme = AppThemeData.presetThemes.first;
      _themeMode = ThemeMode.system;
    }
  }

  /// 重置为默认主题
  Future<void> resetToDefault() async {
    _currentTheme = AppThemeData.presetThemes.first;
    _themeMode = ThemeMode.system;
    notifyListeners();
    await _saveToPreferences();
  }
}
