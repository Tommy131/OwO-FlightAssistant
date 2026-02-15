// theme_model.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../localization/localization_keys.dart';
import '../services/localization_service.dart';

/// 主题配置模型
class AppThemeData {
  final String name;
  final String? localizationKey;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final bool isCustom;

  const AppThemeData({
    required this.name,
    this.localizationKey,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    this.isCustom = false,
  });

  String getLocalizedName(BuildContext context) {
    if (localizationKey != null) {
      return localizationKey!.tr(context);
    }
    return name;
  }

  // ============ 私有颜色常量 ============
  // 背景色
  static const Color _backgroundColor = Color(0xFFF5F6FA);
  static const Color _surfaceColor = Colors.white;
  static const Color _darkBackgroundColor = Color(0xFF1A1A2E);
  static const Color _darkSurfaceColor = Color(0xFF16213E);

  // 文字颜色
  static const Color _textPrimaryColor = Color(0xFF2D3436);
  static const Color _textSecondaryColor = Color(0xFF636E72);
  static const Color _textDarkPrimaryColor = Color(0xFFDFE6E9);
  static const Color _textDarkSecondaryColor = Color(0xFFB2BEC3);

  // 边框和分割线
  static const Color _borderColor = Color(0xFFDFE6E9);
  static const Color _darkBorderColor = Color(0xFF2D3436);

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

  /// 预设主题列表
  static final List<AppThemeData> presetThemes = [
    // 默认主题
    const AppThemeData(
      name: '默认紫',
      localizationKey: LocalizationKeys.themeDefaultPurple,
      primaryColor: Color(0xFF6C5CE7),
      secondaryColor: Color(0xFFA29BFE),
      accentColor: Color(0xFF00B894),
    ),
    const AppThemeData(
      name: '圣诞红',
      localizationKey: LocalizationKeys.themeChristmasRed,
      primaryColor: Color(0xFFD32F2F),
      secondaryColor: Color(0xFFEF5350),
      accentColor: Color(0xFFFF9800),
    ),
    const AppThemeData(
      name: '海洋蓝',
      localizationKey: LocalizationKeys.themeOceanBlue,
      primaryColor: Color(0xFF0277BD),
      secondaryColor: Color(0xFF4FC3F7),
      accentColor: Color(0xFF00BCD4),
    ),
    const AppThemeData(
      name: '自然绿',
      localizationKey: LocalizationKeys.themeNaturalGreen,
      primaryColor: Color(0xFF388E3C),
      secondaryColor: Color(0xFF66BB6A),
      accentColor: Color(0xFF8BC34A),
    ),
    const AppThemeData(
      name: '温暖橙',
      localizationKey: LocalizationKeys.themeWarmOrange,
      primaryColor: Color(0xFFE64A19),
      secondaryColor: Color(0xFFFF7043),
      accentColor: Color(0xFFFFB74D),
    ),
    const AppThemeData(
      name: '优雅紫',
      localizationKey: LocalizationKeys.themeElegantPurple,
      primaryColor: Color(0xFF7B1FA2),
      secondaryColor: Color(0xFFAB47BC),
      accentColor: Color(0xFFBA68C8),
    ),
  ];

  /// 生成浅色主题
  /// [adjustment] 对比度/亮度调整，范围 0.0 到 1.0
  /// 生成浅色主题
  /// [adjustment] 对比度/亮度调整，范围 0.0 到 1.0
  ThemeData generateLightTheme({double adjustment = 0.0}) {
    // 浅色模式下调整背景，数值越大越暗（趋向黑色）
    final bgColor =
        Color.lerp(_backgroundColor, Colors.black, adjustment) ??
        _backgroundColor;
    final surfaceColor =
        Color.lerp(_surfaceColor, Colors.black, adjustment) ?? _surfaceColor;

    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: bgColor,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: Colors.red,
        onPrimary: getContrastColor(primaryColor),
        onSecondary: getContrastColor(secondaryColor),
        onSurface: Colors.black87,
        onError: Colors.white,
        surfaceContainerHighest: Colors.grey.shade100,
        outline: primaryColor.withValues(alpha: 0.3),
      ),
    );
    return _applyCommonTheme(
      baseTheme,
      Brightness.light,
      surfaceColor: surfaceColor,
    );
  }

  /// 生成深色主题
  /// 生成深色主题
  /// [adjustment] 昏暗程度/对比度调整，范围 0.0 到 1.0
  ThemeData generateDarkTheme({double adjustment = 0.0}) {
    final bgColor =
        Color.lerp(_darkBackgroundColor, const Color(0xFF050505), adjustment) ??
        _darkBackgroundColor;
    final surfaceColor =
        Color.lerp(_darkSurfaceColor, const Color(0xFF0A0A15), adjustment) ??
        _darkSurfaceColor;

    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgColor,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: Colors.redAccent,
        onPrimary: getContrastColor(primaryColor),
        onSecondary: getContrastColor(secondaryColor),
        onSurface: Colors.white,
        onError: Colors.white,
        surfaceContainerHighest: const Color(0xFF2C2C2C),
        outline: primaryColor.withValues(alpha: 0.4),
      ),
    );

    return _applyCommonTheme(
      baseTheme,
      Brightness.dark,
      surfaceColor: surfaceColor,
    );
  }

  ThemeData _applyCommonTheme(
    ThemeData base,
    Brightness brightness, {
    Color? surfaceColor,
  }) {
    final isDark = brightness == Brightness.dark;
    final primaryTxt = isDark ? _textDarkPrimaryColor : _textPrimaryColor;
    final secondaryTxt = isDark ? _textDarkSecondaryColor : _textSecondaryColor;
    final surf = surfaceColor ?? (isDark ? _darkSurfaceColor : _surfaceColor);
    final border = isDark ? _darkBorderColor : _borderColor;

    return base.copyWith(
      primaryColor: primaryColor,
      textTheme: GoogleFonts.notoSansScTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.notoSansSc(
          textStyle: base.textTheme.displayLarge?.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: primaryTxt,
          ),
        ),
        displayMedium: GoogleFonts.notoSansSc(
          textStyle: base.textTheme.displayMedium?.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: primaryTxt,
          ),
        ),
        displaySmall: GoogleFonts.notoSansSc(
          textStyle: base.textTheme.displaySmall?.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: primaryTxt,
          ),
        ),
        headlineMedium: GoogleFonts.notoSansSc(
          textStyle: base.textTheme.headlineMedium?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: primaryTxt,
          ),
        ),
        titleSmall: TextStyle(
          fontFamily: 'MicrosoftYaHei',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: primaryTxt,
        ),
        bodyLarge: GoogleFonts.notoSansSc(
          textStyle: base.textTheme.bodyLarge?.copyWith(
            fontSize: 16,
            color: primaryTxt,
          ),
        ),
        bodyMedium: GoogleFonts.notoSansSc(
          textStyle: base.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            color: secondaryTxt,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: surf,
        foregroundColor: primaryTxt,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'MicrosoftYaHei',
          color: primaryTxt,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surf,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
          side: BorderSide(color: border, width: 0.5),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
          side: BorderSide(color: border, width: 1),
        ),
        color: surf,
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
          backgroundColor: surf,
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          side: BorderSide(color: secondaryColor, width: 1.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusLarge),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: getContrastColor(primaryColor),
      ),
      colorScheme: base.colorScheme.copyWith(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surf,
      ),
    );
  }

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

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'primaryColor': primaryColor.toARGB32(),
      'secondaryColor': secondaryColor.toARGB32(),
      'accentColor': accentColor.toARGB32(),
      'isCustom': isCustom,
    };
  }

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
