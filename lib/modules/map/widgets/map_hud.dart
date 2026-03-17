import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/map_models.dart';

class MapLoadingOverlay extends StatelessWidget {
  const MapLoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface.withValues(alpha: 0.6),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class VirtualHudPanel extends StatelessWidget {
  final double scale;
  final MapAircraftState aircraft;
  final double? verticalSpeed;

  const VirtualHudPanel({
    super.key,
    required this.scale,
    required this.aircraft,
    required this.verticalSpeed,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12 * scale),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 14 * scale,
            vertical: 8 * scale,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            border: Border.all(
              color: Colors.lightGreenAccent.withValues(alpha: 0.55),
            ),
            borderRadius: BorderRadius.circular(12 * scale),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              HudValue(
                label: 'GS',
                value: aircraft.groundSpeed != null
                    ? '${aircraft.groundSpeed!.round()}'
                    : '--',
                unit: 'kt',
                scale: scale,
              ),
              HudValue(
                label: 'ALT',
                value: aircraft.altitude != null
                    ? '${aircraft.altitude!.round()}'
                    : '--',
                unit: 'ft',
                scale: scale,
              ),
              HudValue(
                label: 'HDG',
                value: aircraft.heading != null
                    ? '${aircraft.heading!.round()}'
                    : '--',
                unit: '°',
                scale: scale,
              ),
              HudValue(
                label: 'VS',
                value: verticalSpeed != null
                    ? '${verticalSpeed!.round()}'
                    : '--',
                unit: 'fpm',
                scale: scale,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HudValue extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final double scale;

  const HudValue({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.lightGreenAccent.withValues(alpha: 0.9),
            fontSize: 10 * scale,
            fontWeight: FontWeight.w700,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                color: Colors.lightGreenAccent,
                fontSize: 14 * scale,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (unit.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(left: 4 * scale),
                child: Text(
                  unit,
                  style: TextStyle(
                    color: Colors.lightGreenAccent.withValues(alpha: 0.82),
                    fontSize: 10 * scale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

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
  late final AnimationController _controller;
  late final Animation<double> _opacity;

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
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 20),
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
                      shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                    ),
                  ),
                  Text(
                    widget.subMessage,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 24,
                      shadows: [Shadow(color: Colors.black, blurRadius: 5)],
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

class CrashOverlay extends StatelessWidget {
  final VoidCallback onDismiss;

  const CrashOverlay({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final quotes = [
      '飞机是挺硬的，但地面更硬点。',
      '你是在练习降落吗？还是在垂直钻井？',
      '至少你降落在地球上了。',
      '模拟器的好处就是：你还能再点一次重置。',
      '这次降落可以打 1 分，满分是 100 分。',
      '塔台问你是否需要地毯，你给了他们一个坑。',
      '航空公司可能会对你的续约表示担忧。',
      '这大概就是所谓的 一次性飞行器 吧。',
      'RIP (Really Interesting Pilot)',
      '由于你出色的飞行技巧，地面已经成功拦截了你。',
      '刚才那不是降落，那是受控坠毁。',
      '恭喜你，你已经成为了大地母亲的一部分。',
    ];
    final randomQuote = quotes[Random().nextInt(quotes.length)];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withValues(alpha: 0.9),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 80,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 20),
              const Text(
                '你 炸 了',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'CRITICAL MISSION FAILURE',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  '"$randomQuote"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 60),
              ElevatedButton(
                onPressed: onDismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('接受现实 (重置)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
