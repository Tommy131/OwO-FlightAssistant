import 'package:flutter/material.dart';

/// 飞行警告遮罩层
///
/// 当检测到失速或超速时，显示全屏闪烁红框和警告文字
/// 应放置在 Stack 的顶层
class WarningOverlay extends StatefulWidget {
  final bool isStall;
  final bool isOverspeed;

  const WarningOverlay({
    super.key,
    required this.isStall,
    required this.isOverspeed,
  });

  @override
  State<WarningOverlay> createState() => _WarningOverlayState();
}

class _WarningOverlayState extends State<WarningOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isStall && !widget.isOverspeed) {
      return const SizedBox.shrink();
    }

    String text = '';
    if (widget.isStall) text = 'STALL';
    if (widget.isOverspeed) {
      text = widget.isStall ? 'STALL / OVERSPEED' : 'OVERSPEED';
    }

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // 使用 withValues 替代 withOpacity (Flutter 3.27+ 推荐)
          final opacity = _controller.value;
          return Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.red.withValues(alpha: opacity),
                width: 8,
              ),
            ),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.8 * opacity),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      offset: Offset(2, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
