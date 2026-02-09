import 'package:flutter/material.dart';
import '../../../apps/models/airport_detail_data.dart';

/// 跑道选择器组件
class RunwaySelector extends StatelessWidget {
  final List<RunwayInfo> runways;
  final String? selectedRunway;
  final String label;
  final void Function(String?) onChanged;
  final bool enabled;
  final bool isDeparture; // 是否为起飞跑道

  const RunwaySelector({
    super.key,
    required this.runways,
    required this.selectedRunway,
    required this.label,
    required this.onChanged,
    this.enabled = true,
    this.isDeparture = true,
  });

  @override
  Widget build(BuildContext context) {
    // 根据是起飞还是降落选择不同的图标和颜色
    final icon = isDeparture ? Icons.flight_takeoff : Icons.flight_land;
    final color = isDeparture ? Colors.green : Colors.orange;

    if (runways.isEmpty) {
      return TextFormField(
        decoration: InputDecoration(
          labelText: label,
          hintText: '无可用跑道',
          prefixIcon: Icon(icon, color: color),
          border: const OutlineInputBorder(),
        ),
        enabled: false,
      );
    }

    // 提取所有跑道端点
    final runwayOptions = <String>[];
    for (final runway in runways) {
      if (runway.leIdent != null && !runwayOptions.contains(runway.leIdent)) {
        runwayOptions.add(runway.leIdent!);
      }
      if (runway.heIdent != null && !runwayOptions.contains(runway.heIdent)) {
        runwayOptions.add(runway.heIdent!);
      }
    }

    // 如果没有详细端点信息，使用ident
    if (runwayOptions.isEmpty) {
      for (final runway in runways) {
        final parts = runway.ident.split('/');
        for (final part in parts) {
          if (!runwayOptions.contains(part)) {
            runwayOptions.add(part);
          }
        }
      }
    }

    return DropdownButtonFormField<String>(
      initialValue: selectedRunway,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color),
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('自动选择')),
        ...runwayOptions.map((runway) {
          return DropdownMenuItem<String>(
            value: runway,
            child: Text('RWY $runway'),
          );
        }),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}
