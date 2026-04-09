import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../localization/localization_keys.dart';
import '../services/localization_service.dart';
import '../theme/theme_provider.dart';

/// 应用加载屏幕
class LoadingScreen extends StatelessWidget {
  final ThemeProvider themeProvider;

  const LoadingScreen({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    final isDark =
        themeProvider.themeMode == ThemeMode.dark ||
        (themeProvider.themeMode == ThemeMode.system &&
            View.of(context).platformDispatcher.platformBrightness ==
                Brightness.dark);

    final theme = isDark
        ? themeProvider.currentTheme.generateDarkTheme(
            adjustment: themeProvider.darkContrastAdjustment,
          )
        : themeProvider.currentTheme.generateLightTheme(
            adjustment: themeProvider.lightContrastAdjustment,
          );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF121212)
            : theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo with subtle glow
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    AppConstants.assetIconPath,
                    width: 100,
                    height: 100,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(Icons.apps, size: 80, color: theme.primaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // App Name
              Text(
                AppConstants.appName,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontFamily: 'MicrosoftYaHei',
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 48),
              // Progress Indicator
              SizedBox(
                width: 240,
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        backgroundColor: theme.primaryColor.withValues(
                          alpha: 0.1,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      LocalizationKeys.loading.tr(context),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: (isDark ? Colors.white70 : Colors.black54)
                            .withValues(alpha: 0.8),
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
