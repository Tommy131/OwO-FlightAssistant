import 'package:flutter/material.dart';
import '../../../apps/providers/map_provider.dart';
import '../../../apps/services/flight_log_service.dart';

class NewFlightPromptDialog extends StatelessWidget {
  final MapProvider mapProvider;

  const NewFlightPromptDialog({super.key, required this.mapProvider});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('检测到新的飞行'),
      content: const Text('地图上存在之前的飞行轨迹数据。在开始新的飞行前，您想如何处理这些数据？'),
      actions: [
        TextButton(
          onPressed: () {
            FlightLogService().exportCurrentLog();
            Navigator.pop(context);
          },
          child: const Text('导出数据'),
        ),
        TextButton(
          onPressed: () {
            mapProvider.clearFlightData();
            Navigator.pop(context);
          },
          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
          child: const Text('清除数据'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('保留并继续'),
        ),
      ],
    );
  }

  static void show(BuildContext context, MapProvider mapProvider) {
    // 检查是否已经在飞行中，且有一定长度的轨迹。
    // 如果是 Tab 切换导致的重新 build，不应该重复弹出。
    // 我们已经在 MapPage 逻辑中处理了 _hasPromptedNewFlight，但这里可以增加一个安全检查
    if (mapProvider.path.length < 50)
      return; // 轨迹太短不提示，通常意味着刚刚开始记录，或者是静止状态下的漂移点

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => NewFlightPromptDialog(provider: mapProvider),
    );
  }
}
