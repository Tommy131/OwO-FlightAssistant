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
                  _buildGearHandle(
                    context,
                    data.gearHandlePosition ?? 1,
                  ), // Default to DN
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
    // Status logic: 0=Off/Up, 1=Red/Transit, 2=Green/Down

    // Logic refinement for "High Simulation":
    // 1. Nose Gear
    // 2. Left Gear
    // 3. Right Gear
    // Each has two lights: Top (Red/Transit) and Bottom (Green/Down).

    final handle = data.gearHandlePosition ?? 1; // Default Off
    final isHandleDown = handle == 0;
    final isHandleUp = handle == 2;

    // Helper to determine status
    // Returns: 0=Off, 1=Red, 2=Green
    int getStatus(bool? isGearDownBool) {
      bool gearDown = isGearDownBool ?? false;

      if (isHandleDown) {
        return gearDown
            ? 2
            : 1; // Handle DN: Gear Down -> Green. Not Down -> Red (Transit).
      } else if (isHandleUp) {
        return gearDown
            ? 1
            : 0; // Handle UP: Gear Down -> Red (Unsafe). Gear Up -> Off.
      } else {
        // OFF position (1)
        // Used for depressurization.
        // If gear is locked down, it stays Green.
        // If gear is locked up, it stays Off.
        // If in transit... usually Red.
        return gearDown ? 2 : 1;
      }
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
    // status: 0=Off, 1=Red (Transit), 2=Green (Down)

    return Column(
      children: [
        // Red Light Box (Top) - Indicates Transit/Unsafe
        _buildSingleLight(
          text,
          Colors.redAccent,
          status == 1 ? true : status == 0,
        ),
        const SizedBox(height: 4),
        // Green Light Box (Bottom) - Indicates Down & Locked
        _buildSingleLight(
          text,
          const Color(0xFF4CAF50),
          status == 1 ? true : status == 2,
        ),
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

  Widget _buildGearHandle(BuildContext context, int position) {
    // Position: 2=UP, 1=OFF, 0=DN
    double sliderValue = 0;
    if (position == 2) sliderValue = -1; // Top
    if (position == 1) sliderValue = 0; // Middle
    if (position == 0) sliderValue = 1; // Bottom

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
