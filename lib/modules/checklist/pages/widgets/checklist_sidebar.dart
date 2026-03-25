import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../../../core/services/localization_service.dart';
import '../../models/flight_checklist.dart';
import '../../providers/checklist_provider.dart';
import '../../localization/checklist_localization_keys.dart';
import 'phase_nav_item.dart';

/// 检查单侧边栏
///
/// 显示所有飞行阶段列表，用户可通过点击切换当前阶段。
/// 每个阶段条目的渲染逻辑已拆分至 [PhaseNavItem]。
class ChecklistSidebar extends StatefulWidget {
  final ChecklistProvider provider;
  final bool isCompact;

  const ChecklistSidebar({
    super.key,
    required this.provider,
    this.isCompact = false,
  });

  @override
  State<ChecklistSidebar> createState() => _ChecklistSidebarState();
}

class _ChecklistSidebarState extends State<ChecklistSidebar> {
  void _focusPhase(int index) {
    if (index < 0 || index >= ChecklistPhase.values.length) return;
    final phase = ChecklistPhase.values[index];
    if (widget.provider.currentPhase != phase) {
      widget.provider.setPhase(phase);
    }
  }

  void _focusByDelta(int delta) {
    final currentIndex = ChecklistPhase.values.indexOf(
      widget.provider.currentPhase,
    );
    _focusPhase(currentIndex + delta);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.isCompact) {
      final currentIndex = ChecklistPhase.values.indexOf(
        widget.provider.currentPhase,
      );
      final prev = currentIndex > 0
          ? ChecklistPhase.values[currentIndex - 1]
          : null;
      final current = ChecklistPhase.values[currentIndex];
      final next = currentIndex < ChecklistPhase.values.length - 1
          ? ChecklistPhase.values[currentIndex + 1]
          : null;
      final prevProgress = prev == null
          ? 0.0
          : widget.provider.getPhaseProgress(prev);
      final currentProgress = widget.provider.getPhaseProgress(current);
      final nextProgress = next == null
          ? 0.0
          : widget.provider.getPhaseProgress(next);

      return Container(
        height: 120,
        padding: const EdgeInsets.symmetric(
          vertical: AppThemeData.spacingMedium,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppThemeData.getBorderColor(theme)),
          ),
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity <= -120) {
              _focusByDelta(1);
            } else if (velocity >= 120) {
              _focusByDelta(-1);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Expanded(
                  child: _StepCard(
                    phase: prev,
                    roleLabel: ChecklistLocalizationKeys.compactStepPrevious.tr(
                      context,
                    ),
                    isCurrent: false,
                    progress: prevProgress,
                    onTap: prev == null ? null : () => _focusByDelta(-1),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.keyboard_double_arrow_right,
                    color: theme.colorScheme.outline,
                  ),
                ),
                Expanded(
                  child: _StepCard(
                    phase: current,
                    roleLabel: ChecklistLocalizationKeys.compactStepCurrent.tr(
                      context,
                    ),
                    isCurrent: true,
                    progress: currentProgress,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.keyboard_double_arrow_right,
                    color: theme.colorScheme.outline,
                  ),
                ),
                Expanded(
                  child: _StepCard(
                    phase: next,
                    roleLabel: ChecklistLocalizationKeys.compactStepNext.tr(
                      context,
                    ),
                    isCurrent: false,
                    progress: nextProgress,
                    onTap: next == null ? null : () => _focusByDelta(1),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: 240,
      padding: const EdgeInsets.symmetric(vertical: AppThemeData.spacingLarge),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: AppThemeData.getBorderColor(theme)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 侧边栏标题
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppThemeData.spacingLarge,
            ),
            child: Text(
              ChecklistLocalizationKeys.sidebarTitle.tr(context),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: AppThemeData.spacingMedium),
          // 阶段列表
          Expanded(
            child: ListView.builder(
              itemCount: ChecklistPhase.values.length,
              itemBuilder: (context, index) {
                final phase = ChecklistPhase.values[index];
                return PhaseNavItem(
                  phase: phase,
                  isSelected: widget.provider.currentPhase == phase,
                  progress: widget.provider.getPhaseProgress(phase),
                  onTap: () => widget.provider.setPhase(phase),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final ChecklistPhase? phase;
  final String roleLabel;
  final bool isCurrent;
  final double progress;
  final VoidCallback? onTap;

  const _StepCard({
    required this.phase,
    required this.roleLabel,
    required this.isCurrent,
    required this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalizedProgress = progress.clamp(0.0, 1.0);
    final isCompleted = phase != null && normalizedProgress >= 1.0;
    final completedColor = const Color(0xFF22C55E);
    final baseColor = isCurrent
        ? (isCompleted ? Colors.white : theme.colorScheme.primary)
        : (isCompleted
              ? completedColor
              : theme.colorScheme.onSurface.withValues(alpha: 0.45));
    final bgColor = isCurrent
        ? (isCompleted
              ? completedColor.withValues(alpha: 0.3)
              : theme.colorScheme.primary.withValues(alpha: 0.12))
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);
    final title = phase == null ? '—' : phase!.labelKey.tr(context);
    final borderRadius = BorderRadius.circular(AppThemeData.borderRadiusMedium);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: CustomPaint(
          painter: _StepProgressBorderPainter(
            progress: normalizedProgress,
            radius: AppThemeData.borderRadiusMedium,
            trackColor: theme.colorScheme.outline.withValues(alpha: 0.16),
            progressColor: isCompleted
                ? completedColor
                : theme.colorScheme.primary,
            strokeWidth: 2.4,
          ),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: borderRadius,
              border: Border.all(color: Colors.transparent),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  roleLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: baseColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isCompleted) ...[
                      Icon(Icons.check, size: 14, color: completedColor),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: baseColor,
                          fontWeight: isCurrent
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepProgressBorderPainter extends CustomPainter {
  final double progress;
  final double radius;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  const _StepProgressBorderPainter({
    required this.progress,
    required this.radius,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final normalized = progress.clamp(0.0, 1.0);
    final rect = Offset.zero & size;
    final rRect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rRect);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawPath(path, trackPaint);

    if (normalized <= 0) return;
    final metric = path.computeMetrics().first;
    final progressPath = metric.extractPath(0, metric.length * normalized);
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = progressColor;
    canvas.drawPath(progressPath, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _StepProgressBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.radius != radius ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
