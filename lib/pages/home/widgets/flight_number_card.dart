import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../apps/providers/flight_provider.dart';
import '../../../core/theme/app_theme_data.dart';
import '../../../core/widgets/common/dialog.dart';

class FlightNumberCard extends StatelessWidget {
  const FlightNumberCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flightProvider = context.watch<FlightProvider>();

    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(
          color: AppThemeData.getBorderColor(theme).withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(
                AppThemeData.borderRadiusSmall,
              ),
            ),
            child: Icon(
              Icons.confirmation_number_outlined,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppThemeData.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '航班号',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  flightProvider.hasFlightNumber
                      ? flightProvider.flightNumber!
                      : '未设置航班号',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showEditDialog(context, flightProvider),
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: Text(flightProvider.hasFlightNumber ? '修改' : '设置'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    FlightProvider provider,
  ) async {
    final controller = TextEditingController(text: provider.flightNumber);

    // 如果已有航班号，修改时弹出提示
    if (provider.hasFlightNumber) {
      final confirm = await showAdvancedConfirmDialog(
        context: context,
        title: '修改航班号',
        content: '当前已配置航班号 ${provider.flightNumber}，确定要修改吗？',
        icon: Icons.info_outline_rounded,
        confirmText: '继续',
        cancelText: '取消',
      );
      if (confirm != true) return;
    }

    if (!context.mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: const Text('航班号设置'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('请输入当前航班号'),
                const Text(
                  '格式：2位航司代码 + 1-4位数字（如 CCA1234）',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '例: CCA1234',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.flight_outlined),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    if (!RegExp(
                      r'^[A-Z]{2,3}\d{1,4}[A-Z]?$',
                    ).hasMatch(value.trim().toUpperCase())) {
                      return '请输入正确的航班号格式';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      provider.setFlightNumber(result.isEmpty ? null : result);
    }
  }
}
