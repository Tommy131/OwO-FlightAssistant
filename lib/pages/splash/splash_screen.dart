import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class SplashScreen extends StatelessWidget {
  final String message;
  final ThemeData? theme;

  const SplashScreen({
    super.key,
    this.message = '正在加载机场数据库，请稍候...',
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? Theme.of(context);
    final isDark = effectiveTheme.brightness == Brightness.dark;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: effectiveTheme,
      home: Scaffold(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo or Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: effectiveTheme.colorScheme.primary.withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.flight_takeoff_rounded,
                  size: 40,
                  color: effectiveTheme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              // App Name
              Text(
                AppConstants.appName,
                style: effectiveTheme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 32),
              // Loading Indicator
              SizedBox(
                width: 200,
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      backgroundColor: effectiveTheme.colorScheme.primary
                          .withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        effectiveTheme.colorScheme.primary,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: effectiveTheme.textTheme.bodyMedium?.copyWith(
                        color: effectiveTheme.textTheme.bodyMedium?.color
                            ?.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
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
