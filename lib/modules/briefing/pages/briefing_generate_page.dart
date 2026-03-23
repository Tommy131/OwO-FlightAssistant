import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/theme/app_theme_data.dart';
import '../localization/briefing_localization_keys.dart';
import '../providers/briefing_provider.dart';
import 'widgets/briefing_display_card.dart';
import 'widgets/briefing_input_card.dart';
import 'widgets/briefing_actions.dart';

/// 简报生成子页面
/// 负责组合输入表单、实时预览卡片以及操作按钮组
class BriefingGeneratePage extends StatelessWidget {
  final VoidCallback onBack;

  const BriefingGeneratePage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(BriefingLocalizationKeys.generateTitle.tr(context)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: onBack,
        ),
      ),
      body: SafeArea(
        child: Consumer<BriefingProvider>(
          builder: (context, provider, child) {
            return LayoutBuilder(
              builder: (context, constraints) {
                // 根据屏幕宽度决定左右并排还是上下堆叠
                final isWide = constraints.maxWidth >= 960;

                final content = isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Expanded(child: BriefingInputCard()),
                          SizedBox(width: AppThemeData.spacingMedium),
                          Expanded(child: BriefingDisplayCard()),
                        ],
                      )
                    : const Column(
                        children: [
                          BriefingInputCard(),
                          SizedBox(height: AppThemeData.spacingMedium),
                          BriefingDisplayCard(),
                        ],
                      );

                return ListView(
                  padding: const EdgeInsets.all(AppThemeData.spacingMedium),
                  children: [
                    content,
                    const SizedBox(height: AppThemeData.spacingMedium),
                    BriefingActions(provider: provider),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
