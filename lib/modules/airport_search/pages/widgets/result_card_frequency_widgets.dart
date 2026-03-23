import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../localization/airport_search_localization_keys.dart';
import '../../models/airport_search_models.dart';

/// 机场通讯频率表格
class ResultFrequencyTable extends StatelessWidget {
  /// 经过合并的数据行列表
  final List<List<String>> rows;

  const ResultFrequencyTable({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final borderColor = primary.withValues(alpha: 0.28);
    final headerColor = primary.withValues(alpha: 0.2);
    final rowColor = primary.withValues(alpha: 0.1);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder(
              horizontalInside: BorderSide(color: borderColor),
              verticalInside: BorderSide(color: borderColor),
            ),
            children: [
              // 表头
              TableRow(
                decoration: BoxDecoration(color: headerColor),
                children: [
                  _buildHeaderCell(
                    context,
                    AirportSearchLocalizationKeys.frequencyTypeLabel.tr(
                      context,
                    ),
                  ),
                  _buildHeaderCell(
                    context,
                    AirportSearchLocalizationKeys.frequencyValueLabel.tr(
                      context,
                    ),
                  ),
                ],
              ),
              // 数据行
              ...rows.map(
                (row) => TableRow(
                  decoration: BoxDecoration(color: rowColor),
                  children: [
                    _buildDataCell(context, row[0], isBold: true),
                    _buildDataCell(context, row[1], family: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildDataCell(
    BuildContext context,
    String text, {
    bool isBold = false,
    bool family = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: isBold ? FontWeight.w600 : null,
          fontFeatures: family ? const [FontFeature.tabularFigures()] : null,
        ),
      ),
    );
  }
}

/// 频率合并助手: 将同类型的多个频率合并显示 (e.g. 118.1 / 118.2)
List<List<String>> mergeFrequencyRows(List<AirportFrequencyData> items) {
  final grouped = <String, List<String>>{};
  for (final item in items) {
    final type = (item.type ?? '').trim().isEmpty ? '-' : item.type!.trim();
    final value = (item.value ?? '').trim().isEmpty ? '-' : item.value!.trim();
    final currentValues = grouped.putIfAbsent(type, () => <String>[]);
    if (!currentValues.contains(value)) {
      currentValues.add(value);
    }
  }
  return grouped.entries
      .map((entry) => [entry.key, entry.value.join(' / ')])
      .toList();
}
