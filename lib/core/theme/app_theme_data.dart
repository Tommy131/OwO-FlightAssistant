// theme_model.dart
import 'package:flutter/material.dart';

/// 主题配置模型
class AppThemeData {
  final String name;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final bool isCustom;

  const AppThemeData({
    required this.name,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    this.isCustom = false,
  });

  // ============ 私有颜色常量 ============
  // 背景色
  static const Color _backgroundColor = Color(0xFFF7F8FA);
  static const Color _surfaceColor = Colors.white;
  static const Color _darkBackgroundColor = Color(0xFF0F172A);
  static const Color _darkSurfaceColor = Color(0xFF111827);

  // 文字颜色
  static const Color _textPrimaryColor = Color(0xFF1F2937);
  static const Color _textSecondaryColor = Color(0xFF4B5563);
  static const Color _textDarkPrimaryColor = Color(0xFFE5E7EB);
  static const Color _textDarkSecondaryColor = Color(0xFF9CA3AF);

  // 边框和分割线
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _darkBorderColor = Color(0xFF1F2937);

  // ============ 布局常量 ============
  // 圆角
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;

  // 间距
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;

  // 侧边栏宽度（紧凑型）
  static const double sidebarExpandedWidth = 200.0;
  static const double sidebarCollapsedWidth = 60.0;

  // 动画时长
  static const Duration animationDuration = Duration(milliseconds: 300);

  /// 预设主题列表（你原有的主题作为第一个）
  static final List<AppThemeData> presetThemes = [
    // 默认主题（保留你原有的设计）
    const AppThemeData(
      name: '默认紫',
      primaryColor: Color(0xFF6C5CE7),
      secondaryColor: Color(0xFFA29BFE),
      accentColor: Color(0xFF00B894),
    ),
    const AppThemeData(
      name: '圣诞红',
      primaryColor: Color(0xFFD32F2F),
      secondaryColor: Color(0xFFEF5350),
      accentColor: Color(0xFFFF9800),
    ),
    const AppThemeData(
      name: '海洋蓝',
      primaryColor: Color(0xFF0277BD),
      secondaryColor: Color(0xFF4FC3F7),
      accentColor: Color(0xFF00BCD4),
    ),
    const AppThemeData(
      name: '自然绿',
      primaryColor: Color(0xFF388E3C),
      secondaryColor: Color(0xFF66BB6A),
      accentColor: Color(0xFF8BC34A),
    ),
    const AppThemeData(
      name: '温暖橙',
      primaryColor: Color(0xFFE64A19),
      secondaryColor: Color(0xFFFF7043),
      accentColor: Color(0xFFFFB74D),
    ),
    const AppThemeData(
      name: '优雅紫',
      primaryColor: Color(0xFF7B1FA2),
      secondaryColor: Color(0xFFAB47BC),
      accentColor: Color(0xFFBA68C8),
    ),
  ];

  /// 生成浅色主题（保留你的设计风格）
  ThemeData generateLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: _backgroundColor,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: _surfaceColor,
        error: Colors.red,
        onPrimary: getContrastColor(primaryColor),
        onSecondary: getContrastColor(secondaryColor),
        onSurface: _textPrimaryColor,
        onError: Colors.white,
        surfaceContainerHighest: const Color(0xFFF1F5F9),
        outline: const Color(0xFF94A3B8),
        outlineVariant: _borderColor,
        onSurfaceVariant: _textSecondaryColor,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: _surfaceColor,
        foregroundColor: _textPrimaryColor,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: _textPrimaryColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
          side: const BorderSide(color: _borderColor, width: 1),
        ),
        color: _surfaceColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryColor,
          foregroundColor: getContrastColor(primaryColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusSmall),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          backgroundColor: _surfaceColor,
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          side: const BorderSide(color: _borderColor, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusLarge),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusSmall),
          borderSide: const BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusSmall),
          borderSide: const BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusSmall),
          borderSide: BorderSide(color: primaryColor, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusSmall),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusSmall),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        labelStyle: const TextStyle(color: _textSecondaryColor),
        hintStyle: const TextStyle(color: _textSecondaryColor),
      ),
      dividerTheme: const DividerThemeData(
        color: _borderColor,
        thickness: 1,
      ),
      iconTheme: const IconThemeData(color: _textSecondaryColor),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: getContrastColor(primaryColor),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: _textPrimaryColor,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: _textPrimaryColor,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: _textPrimaryColor,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _textPrimaryColor,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: _textPrimaryColor),
        bodyMedium: TextStyle(fontSize: 14, color: _textSecondaryColor),
        bodySmall: TextStyle(fontSize: 12, color: _textSecondaryColor),
        labelLarge: TextStyle(fontSize: 14, color: _textSecondaryColor),
        labelMedium: TextStyle(fontSize: 12, color: _textSecondaryColor),
        labelSmall: TextStyle(fontSize: 11, color: _textSecondaryColor),
      ),
    );
  }

  /// 生成深色主题（保留你的设计风格）
  ThemeData generateDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: _darkBackgroundColor,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: _darkSurfaceColor,
        error: Colors.redAccent,
        onPrimary: getContrastColor(primaryColor), // 智能对比色
        onSecondary: getContrastColor(secondaryColor),
        onSurface: _textDarkPrimaryColor,
        onError: Colors.white,
        surfaceContainerHighest: const Color(0xFF1F2937),
        outline: const Color(0xFF475569),
        outlineVariant: _darkBorderColor,
        onSurfaceVariant: _textDarkSecondaryColor,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: _darkSurfaceColor,
        foregroundColor: _textDarkPrimaryColor,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: _textDarkPrimaryColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
          side: const BorderSide(color: _darkBorderColor, width: 1),
        ),
        color: _darkSurfaceColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryColor,
          foregroundColor: getContrastColor(primaryColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusSmall),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          backgroundColor: _darkSurfaceColor,
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          side: const BorderSide(color: _darkBorderColor, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusLarge),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF111827),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusSmall),
          borderSide: const BorderSide(color: _darkBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusSmall),
          borderSide: const BorderSide(color: _darkBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusSmall),
          borderSide: BorderSide(color: primaryColor, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusSmall),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusSmall),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        labelStyle: const TextStyle(color: _textDarkSecondaryColor),
        hintStyle: const TextStyle(color: _textDarkSecondaryColor),
      ),
      dividerTheme: const DividerThemeData(
        color: _darkBorderColor,
        thickness: 1,
      ),
      iconTheme: const IconThemeData(color: _textDarkSecondaryColor),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: getContrastColor(primaryColor),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: _textDarkPrimaryColor,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: _textDarkPrimaryColor,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: _textDarkPrimaryColor,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _textDarkPrimaryColor,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: _textDarkPrimaryColor),
        bodyMedium: TextStyle(fontSize: 14, color: _textDarkSecondaryColor),
        bodySmall: TextStyle(fontSize: 12, color: _textDarkSecondaryColor),
        labelLarge: TextStyle(fontSize: 14, color: _textDarkSecondaryColor),
        labelMedium: TextStyle(fontSize: 12, color: _textDarkSecondaryColor),
        labelSmall: TextStyle(fontSize: 11, color: _textDarkSecondaryColor),
      ),
    );
  }

  /// 计算对比色（确保按钮文字可见）
  static Color getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  static Color getBorderColor(ThemeData theme) {
    return theme.brightness == Brightness.light
        ? _borderColor
        : _darkBorderColor;
  }

  static Color getTextColor(ThemeData theme, {bool isPrimary = true}) {
    return theme.brightness == Brightness.light
        ? (isPrimary ? _textPrimaryColor : _textSecondaryColor)
        : (isPrimary ? _textDarkPrimaryColor : _textDarkSecondaryColor);
  }

  /// 转换为Map（用于持久化存储）
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'primaryColor': primaryColor.toARGB32(),
      'secondaryColor': secondaryColor.toARGB32(),
      'accentColor': accentColor.toARGB32(),
      'isCustom': isCustom,
    };
  }

  /// 从Map创建（用于持久化存储）
  factory AppThemeData.fromJson(Map<String, dynamic> json) {
    return AppThemeData(
      name: json['name'] as String,
      primaryColor: Color(json['primaryColor'] as int),
      secondaryColor: Color(json['secondaryColor'] as int),
      accentColor: Color(json['accentColor'] as int),
      isCustom: json['isCustom'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppThemeData &&
        other.name == name &&
        other.primaryColor == primaryColor &&
        other.secondaryColor == secondaryColor &&
        other.accentColor == accentColor &&
        other.isCustom == isCustom;
  }

  @override
  int get hashCode =>
      Object.hash(name, primaryColor, secondaryColor, accentColor, isCustom);
}
