import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/monitor_localization_keys.dart';
import '../../models/monitor_data.dart';

/// 起落架状态卡片组件
///
/// 以航空仪表板风格展示三组起落架（前起、左主、右主）的收放状态，包含：
/// 1. 状态指示灯矩阵：每组两个灯（红灯 = 过渡中，绿灯 = 放下/过渡）
/// 2. 起落架手柄动画：圆形手柄沿中央轨道滑动，反映平均放下比例
/// 3. 速度限制铭牌：展示收放速度限制文字
class LandingGearCard extends StatelessWidget {
  /// 当前飞行数据快照（读取三组起落架收放比例）
  final MonitorData data;

  const LandingGearCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 仪表板面板深色背景
    const panelColor = Color(0xFF2A2A2A);
    const panelBorderColor = Color(0xFF1A1A1A);

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
          // 卡片标题
          Text(
            MonitorLocalizationKeys.landingGearTitle.tr(context),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),

          // 中央仿真面板容器（深色背景 + 阴影）
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
                  // 三组状态指示灯
                  _buildIndicators(context),
                  const SizedBox(height: 24),
                  // 手柄滑动动画
                  _buildGearHandle(context),
                  const SizedBox(height: 16),
                  // 速度限制铭牌
                  _buildLimitText(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建三组起落架状态指示灯（前起居中，左右主起并排）
  Widget _buildIndicators(BuildContext context) {
    /// 将收放比例转换为状态码
    /// - 0: 完全收起（< 2%）
    /// - 1: 过渡中（2%~98%，红灯亮）
    /// - 2: 完全放下（>= 98%，绿灯亮）
    int getStatus(double? ratio) {
      if (ratio == null) return 0;
      if (ratio <= 0.02) return 0;
      if (ratio >= 0.98) return 2;
      return 1;
    }

    return Column(
      children: [
        // 前起指示灯（居中）
        _buildLightBox(
          MonitorLocalizationKeys.gearNoseLabel.tr(context),
          getStatus(data.noseGearDown),
        ),
        const SizedBox(height: 12),
        // 左右主起指示灯（并排）
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLightBox(
              MonitorLocalizationKeys.gearLeftLabel.tr(context),
              getStatus(data.leftGearDown),
            ),
            const SizedBox(width: 24),
            _buildLightBox(
              MonitorLocalizationKeys.gearRightLabel.tr(context),
              getStatus(data.rightGearDown),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建单组指示灯盒（上方红灯 + 下方绿灯）
  ///
  /// [status] == 1 时红灯亮；[status] >= 1 时绿灯亮
  Widget _buildLightBox(String text, int status) {
    final showRed = status == 1;
    final showGreen = status == 1 || status == 2;

    return Column(
      children: [
        _buildSingleLight(text, Colors.redAccent, showRed),
        const SizedBox(height: 4),
        _buildSingleLight(text, const Color(0xFF4CAF50), showGreen),
      ],
    );
  }

  /// 构建单个指示灯（黑色底框 + 点亮/熄灭状态）
  ///
  /// [isLit] 为 true 时灯亮（带光晕投影），为 false 时熄灭（低透明度灰色）
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
          color: isLit ? color : Colors.grey.withValues(alpha: 0.3),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          height: 1.1,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  /// 构建起落架手柄滑块动画
  ///
  /// 取三组起落架收放比例的平均值，映射到 -1（UP）至 +1（DOWN）的位置，
  /// 由 [AnimatedAlign] 实现平滑过渡动画。
  Widget _buildGearHandle(BuildContext context) {
    // 三组平均收放比例（0.0=收起，1.0=放下）
    final avg =
        ((data.noseGearDown ?? 0) +
            (data.leftGearDown ?? 0) +
            (data.rightGearDown ?? 0)) /
        3.0;
    // 映射到 -1（顶部 UP）至 +1（底部 DOWN）
    final sliderValue = (avg * 2) - 1;

    return SizedBox(
      height: 200,
      width: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 中央轨道槽（黑色圆角矩形）
          Container(
            width: 40,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[800]!, width: 2),
            ),
          ),

          // 位置标签：UP（顶部）
          Positioned(
            top: 10,
            left: 0,
            child: Text(
              MonitorLocalizationKeys.gearPositionUp.tr(context),
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),

          // 位置标签：OFF（中部）
          Positioned(
            top: 95,
            left: 0,
            child: Text(
              MonitorLocalizationKeys.gearPositionOff.tr(context),
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),

          // 位置标签：DN（底部）
          Positioned(
            bottom: 10,
            left: 0,
            child: Text(
              MonitorLocalizationKeys.gearPositionDown.tr(context),
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),

          // 手柄圆钮（随平均收放比例平滑滑动）
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
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                    border: Border.all(color: Colors.grey[600]!, width: 2),
                  ),
                  child: const Icon(Icons.circle, color: Colors.grey, size: 30),
                ),
              ),
            ),
          ),

          // 手柄旁侧竖排标签文字（逆时针旋转 90°）
          Positioned(
            left: -25,
            top: 50,
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(
                MonitorLocalizationKeys.gearHandleLabel.tr(context),
                style: const TextStyle(
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

  /// 构建速度限制铭牌（显示收放速度限制文字）
  Widget _buildLimitText(BuildContext context) {
    return Column(
      children: [
        Text(
          MonitorLocalizationKeys.gearLimitTitle.tr(context),
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          MonitorLocalizationKeys.gearLimitContent.tr(context),
          style: const TextStyle(
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
