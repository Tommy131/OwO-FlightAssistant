import 'package:flutter/material.dart';
import '../../../apps/models/simulator_data.dart';
import '../../../core/theme/app_theme_data.dart';

class LandingGearCard extends StatelessWidget {
  final SimulatorData data;

  const LandingGearCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Dark panel background similar to the cockpit
    final panelColor = const Color(0xFF2A2A2A);
    final panelBorderColor = const Color(0xFF1A1A1A);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusLarge),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '起落架状态 (Landing Gear)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: panelBorderColor, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Indicator Lights Area
                  _buildIndicators(data),
                  const SizedBox(height: 24),
                  // Gear Handle Area
                  _buildGearHandle(context, data),
                  const SizedBox(height: 16),
                  // Limit Text (Decorative)
                  _buildLimitText(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicators(SimulatorData data) {
    // Status logic based on raw deployment ratio:
    // 0: Fully retracted (Off)
    // 0 < v < 1: Transit (Red + Green)
    // 1: Fully extended (Green only)

    // Helper to determine status
    // Returns: 0=Off, 1=Red+Green (Transit), 2=Green Only (Locked Down)
    int getStatus(double? ratio) {
      if (ratio == null) return 0;
      if (ratio <= 0.02) return 0; // Fully UP
      if (ratio >= 0.98) return 2; // Fully DOWN
      return 1; // Transit
    }

    return Column(
      children: [
        // Nose Gear (Top Center)
        _buildLightBox("NOSE\nGEAR", getStatus(data.noseGearDown)),
        const SizedBox(height: 12),
        // Main Gears (Row)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLightBox("LEFT\nGEAR", getStatus(data.leftGearDown)),
            const SizedBox(width: 24),
            _buildLightBox("RIGHT\nGEAR", getStatus(data.rightGearDown)),
          ],
        ),
      ],
    );
  }

  Widget _buildLightBox(String text, int status) {
    // status: 0=Off, 1=Transit (Red+Green), 2=Down (Green Only)
    bool showRed = status == 1;
    bool showGreen = status == 1 || status == 2;

    return Column(
      children: [
        // Red Light Box (Top) - Indicates Transit/Unsafe
        _buildSingleLight(text, Colors.redAccent, showRed),
        const SizedBox(height: 4),
        // Green Light Box (Bottom) - Indicates Down & Locked
        _buildSingleLight(text, const Color(0xFF4CAF50), showGreen),
      ],
    );
  }

  Widget _buildSingleLight(String text, Color color, bool isLit) {
    return Container(
      width: 60,
      height: 40,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.grey[800]!, width: 2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: isLit
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          // If lit, use the color. If not lit, use a very dim text color (simulating text etched on glass)
          color: isLit ? color : Colors.grey.withValues(alpha: 0.3),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          height: 1.1,
          fontFamily:
              'monospace', // Use a monospaced-like font if available, or default
        ),
      ),
    );
  }

  Widget _buildGearHandle(BuildContext context, SimulatorData data) {
    // 计算平均展开比例 (0 to 1)
    final avg =
        ((data.noseGearDown ?? 0) +
            (data.leftGearDown ?? 0) +
            (data.rightGearDown ?? 0)) /
        3.0;

    // 将 0..1 映射到 sliderValue -1..1
    // avg = 0.0 -> sliderValue = -1 (UP)
    // avg = 0.5 -> sliderValue = 0  (OFF)
    // avg = 1.0 -> sliderValue = 1  (DN)
    final sliderValue = (avg * 2) - 1;

    return SizedBox(
      height: 200,
      width: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Track
          Container(
            width: 40,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[800]!, width: 2),
            ),
          ),
          // Labels
          const Positioned(
            top: 10,
            left: 0,
            child: Text(
              "UP",
              style: TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
          const Positioned(
            top: 95,
            left: 0,
            child: Text(
              "OFF",
              style: TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
          const Positioned(
            bottom: 10,
            left: 0,
            child: Text(
              "DN",
              style: TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),

          // The Handle (Animated)
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            alignment: Alignment(0, sliderValue),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[300],
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.grey[400]!],
                ),
              ),
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, // Wheel shape?
                    color: Colors.transparent,
                    border: Border.all(color: Colors.grey[600]!, width: 2),
                  ),
                  child: const Icon(Icons.circle, color: Colors.grey, size: 30),
                ),
              ),
            ),
          ),

          // Gear text label vertical
          const Positioned(
            left: -25,
            top: 50,
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(
                "LANDING GEAR",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitText() {
    return Column(
      children: const [
        Text(
          "LANDING GEAR LIMIT (IAS)",
          style: TextStyle(
            color: Colors.grey,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 4),
        Text(
          "OPERATING EXTEND 270K - 82M\nRETRACT 235K\nEXTENDED 320K - 82M",
          style: TextStyle(
            color: Colors.grey,
            fontSize: 8,
            fontFamily: 'Monospace',
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
