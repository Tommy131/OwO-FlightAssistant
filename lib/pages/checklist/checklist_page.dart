import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../apps/providers/checklist_provider.dart';
import '../../apps/providers/simulator/simulator_provider.dart';
import '../../core/theme/app_theme_data.dart';
import '../../core/widgets/common/data_link_placeholder.dart';
import 'widgets/checklist_header.dart';
import 'widgets/checklist_items_list.dart';
import 'widgets/checklist_sidebar.dart';
import 'widgets/checklist_footer.dart';

class ChecklistPage extends StatelessWidget {
  const ChecklistPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<ChecklistProvider>();
    final selectedAircraft = provider.selectedAircraft;

    return Consumer<SimulatorProvider>(
      builder: (context, simProvider, _) {
        if (!simProvider.isConnected) {
          return const DataLinkPlaceholder(
            title: '检查单系统未激活',
            description: '由于模拟器未连接，无法获取当前的飞行状态和机型信息，飞行检查单已自动挂起。',
          );
        }

        if (selectedAircraft == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Row(
            children: [
              // 左侧阶段导航
              ChecklistSidebar(provider: provider),

              // 右侧检查单内容
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(AppThemeData.spacingLarge),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(
                      AppThemeData.borderRadiusLarge,
                    ),
                    border: Border.all(
                      color: AppThemeData.getBorderColor(theme),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(0),
                        // The original had padding inside the helper method, but now it's in the widget.
                        // Wait, ChecklistHeader has padding inside.
                        // Let's verify layout.
                        child: ChecklistHeader(provider: provider),
                      ),
                      const Divider(height: 1),
                      Expanded(child: ChecklistItemsList(provider: provider)),
                      ChecklistFooter(provider: provider),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
