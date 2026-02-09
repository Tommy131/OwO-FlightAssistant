import 'package:flutter/material.dart';
import '../../apps/providers/simulator/simulator_provider.dart';
import '../../apps/models/airport_info.dart';

/// 模拟器自动填充辅助类
/// 提供从模拟器自动填充机场信息的通用功能
class SimulatorAutoFillHelper {
  /// 自动填充结果
  static AutoFillResult autoFillAirports(SimulatorProvider simProvider) {
    if (!simProvider.isConnected) {
      return AutoFillResult.empty();
    }

    return AutoFillResult(
      departureAirport: simProvider.nearestAirport,
      arrivalAirport: simProvider.destinationAirport,
      alternateAirport: simProvider.alternateAirport,
      hasData:
          simProvider.nearestAirport != null ||
          simProvider.destinationAirport != null ||
          simProvider.alternateAirport != null,
    );
  }

  /// 显示自动填充提示
  static void showAutoFillSnackBar(
    BuildContext context,
    AutoFillResult result,
  ) {
    if (!result.hasData) return;

    final filledFields = <String>[];
    if (result.departureAirport != null) filledFields.add('起飞机场');
    if (result.arrivalAirport != null) filledFields.add('到达机场');
    if (result.alternateAirport != null) filledFields.add('备降机场');

    if (filledFields.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✈️ 已自动填充: ${filledFields.join('、')}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 构建模拟器状态横幅
  static Widget buildStatusBanner(
    BuildContext context,
    SimulatorProvider simProvider,
  ) {
    if (!simProvider.isConnected) {
      return const SizedBox.shrink();
    }

    final hasNearestAirport = simProvider.nearestAirport != null;
    final hasDestination = simProvider.destinationAirport != null;
    final hasAlternate = simProvider.alternateAirport != null;

    // 获取重量信息
    final totalWeight = simProvider.simulatorData.totalWeight;
    final emptyWeight = simProvider.simulatorData.emptyWeight;
    final payloadWeight = simProvider.simulatorData.payloadWeight;
    final fuelWeight = simProvider.simulatorData.fuelQuantity;

    if (!hasNearestAirport && !hasDestination && !hasAlternate) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.orange, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '模拟器已连接，但未检测到机场信息',
                style: TextStyle(color: Colors.orange[800], fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flight, color: Colors.green[700], size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '模拟器已连接',
                  style: TextStyle(
                    color: Colors.green[800],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (hasNearestAirport || hasDestination || hasAlternate) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (hasNearestAirport)
                  '当前: ${simProvider.nearestAirport!.icaoCode}',
                if (hasDestination)
                  '目的地: ${simProvider.destinationAirport!.icaoCode}',
                if (hasAlternate)
                  '备降: ${simProvider.alternateAirport!.icaoCode}',
              ].join(' | '),
              style: TextStyle(color: Colors.green[700], fontSize: 11),
            ),
          ],
          // 显示重量信息
          if (totalWeight != null ||
              emptyWeight != null ||
              payloadWeight != null ||
              fuelWeight != null) ...[
            const SizedBox(height: 4),
            Text(
              _formatWeightInfo(
                totalWeight,
                emptyWeight,
                payloadWeight,
                fuelWeight,
              ),
              style: TextStyle(color: Colors.green[700], fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  /// 格式化重量信息
  static String _formatWeightInfo(
    double? totalWeight,
    double? emptyWeight,
    double? payloadWeight,
    double? fuelWeight,
  ) {
    final parts = <String>[];

    if (totalWeight != null) {
      parts.add('总重: ${(totalWeight / 1000).toStringAsFixed(1)}t');
    }

    if (fuelWeight != null) {
      parts.add('燃油: ${(fuelWeight / 1000).toStringAsFixed(1)}t');
    }

    if (payloadWeight != null) {
      parts.add('载荷: ${(payloadWeight / 1000).toStringAsFixed(1)}t');
    }

    if (emptyWeight != null && parts.isEmpty) {
      parts.add('空重: ${(emptyWeight / 1000).toStringAsFixed(1)}t');
    }

    return parts.isNotEmpty ? parts.join(' | ') : '重量信息不可用';
  }
}

/// 自动填充结果
class AutoFillResult {
  final AirportInfo? departureAirport;
  final AirportInfo? arrivalAirport;
  final AirportInfo? alternateAirport;
  final bool hasData;

  const AutoFillResult({
    this.departureAirport,
    this.arrivalAirport,
    this.alternateAirport,
    required this.hasData,
  });

  factory AutoFillResult.empty() {
    return const AutoFillResult(hasData: false);
  }
}
