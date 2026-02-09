import 'package:flutter/material.dart';
import '../../theme/app_theme_data.dart';

class DataLinkPlaceholder extends StatelessWidget {
  final String title;
  final String description;

  const DataLinkPlaceholder({
    super.key,
    this.title = '数据链路未就绪',
    this.description = '该功能需要激活的模拟器连接。目前由于缺少数据流，系统已进入待机模式。',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppThemeData.spacingLarge * 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 顶部装饰性光晕效果
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.15),
                        theme.colorScheme.primary.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.sensors_off_rounded,
                    size: 60,
                    color: theme.colorScheme.primary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),

            // 标题
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
              ).createShader(bounds),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 描述
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 56),

            // 操作提示
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStep(context, '1', '前往首页', Icons.home_outlined),
                _buildArrow(theme),
                _buildStep(context, '2', '连接模拟器', Icons.link_rounded),
                _buildArrow(theme),
                _buildStep(
                  context,
                  '3',
                  '开始使用',
                  Icons.check_circle_outline_rounded,
                ),
              ],
            ),
            const SizedBox(height: 80),

            // 底部装饰
            Opacity(
              opacity: 0.3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatusDot(theme, 'MSFS 2020', true),
                  const SizedBox(width: 24),
                  _buildStatusDot(theme, 'X-Plane 12', true),
                  const SizedBox(width: 24),
                  _buildStatusDot(theme, 'MSFS 2024', true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(
    BuildContext context,
    String num,
    String label,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppThemeData.spacingMedium),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildArrow(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      margin: const EdgeInsets.only(bottom: 24),
      child: Icon(
        Icons.chevron_right_rounded,
        color: theme.colorScheme.primary.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildStatusDot(ThemeData theme, String label, bool supported) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: supported ? Colors.greenAccent : Colors.grey,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class TransponderStatusText extends StatelessWidget {
  final int? state;
  final String? code;
  final TextStyle? style;
  final String? prefix;
  final String? emptyLabel;
  final bool includeState;
  final bool includeMeaning;
  final String? meaningSeparator;

  const TransponderStatusText({
    super.key,
    this.state,
    this.code,
    this.style,
    this.prefix,
    this.emptyLabel,
    this.includeState = true,
    this.includeMeaning = false,
    this.meaningSeparator,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      format(
        state: state,
        code: code,
        prefix: prefix,
        emptyLabel: emptyLabel,
        includeState: includeState,
        includeMeaning: includeMeaning,
        meaningSeparator: meaningSeparator,
      ),
      style: style,
    );
  }

  static String format({
    int? state,
    String? code,
    String? prefix,
    String? emptyLabel,
    bool includeState = true,
    bool includeMeaning = false,
    String? meaningSeparator,
  }) {
    final normalizedCode = _normalizeCode(code);
    final stateLabel = includeState ? _stateLabel(state) : '';
    final hasState = stateLabel.isNotEmpty;
    final hasCode = normalizedCode.isNotEmpty;
    final base = prefix != null && prefix.isNotEmpty
        ? (hasState ? '$prefix $stateLabel' : prefix)
        : stateLabel;
    if (!hasState && !hasCode) {
      return emptyLabel ?? '';
    }
    if (!hasCode) {
      return base;
    }
    final content = base.isEmpty ? normalizedCode : '$base $normalizedCode';
    if (!includeMeaning) {
      return content;
    }
    final meaning = _specialMeaning(normalizedCode);
    if (meaning == null || meaning.isEmpty) {
      return content;
    }
    return '$content${meaningSeparator ?? ' '}$meaning';
  }

  static String? specialMeaning(String? code) {
    final normalized = _normalizeCode(code);
    return _specialMeaning(normalized);
  }

  static bool isSpecial(String? code) {
    return specialMeaning(code) != null;
  }

  static Color? specialColor(String? code) {
    final normalized = _normalizeCode(code);
    switch (normalized) {
      case '7500':
        return Colors.redAccent;
      case '7600':
        return Colors.orangeAccent;
      case '7700':
        return Colors.redAccent;
      default:
        return null;
    }
  }

  static String _stateLabel(int? state) {
    switch (state) {
      case 0:
        return 'OFF';
      case 1:
        return 'STBY';
      case 2:
        return 'ON';
      case 3:
        return 'ALT';
      case 4:
        return 'TEST';
      case 5:
        return 'GND';
      case 6:
        return 'TA';
      case 7:
        return 'TA/RA';
      default:
        return '';
    }
  }

  static String? _specialMeaning(String code) {
    switch (code) {
      case '7500':
        return '劫机';
      case '7600':
        return '通讯失效';
      case '7700':
        return '紧急情况';
      default:
        return null;
    }
  }

  static String _normalizeCode(String? code) {
    final raw = code?.trim() ?? '';
    if (raw.isEmpty) return '';
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return raw;
    if (digits.length <= 4) return digits.padLeft(4, '0');
    return digits.substring(digits.length - 4);
  }
}
