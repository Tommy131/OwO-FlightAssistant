import 'package:flutter/material.dart';

class DangerOverlay extends StatefulWidget {
  final String message;
  final String subMessage;

  const DangerOverlay({
    super.key,
    required this.message,
    required this.subMessage,
  });

  @override
  State<DangerOverlay> createState() => _DangerOverlayState();
}

class _DangerOverlayState extends State<DangerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 0.8).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _opacity,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.red.withValues(alpha: _opacity.value),
                width: 20,
              ),
              color: Colors.red.withValues(alpha: _opacity.value * 0.2),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 100,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    widget.subMessage,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 24,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
