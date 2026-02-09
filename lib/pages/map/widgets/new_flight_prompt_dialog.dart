import 'package:flutter/material.dart';
import '../../../apps/providers/map_provider.dart';
import '../../../apps/services/flight_log_service.dart';

class NewFlightPromptDialog extends StatelessWidget {
  final MapProvider mapProvider;

  const NewFlightPromptDialog({
    super.key,
    required this.mapProvider,
  });

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

  static Future<void> show(BuildContext context, MapProvider mapProvider) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => NewFlightPromptDialog(mapProvider: mapProvider),
    );
  }
}
