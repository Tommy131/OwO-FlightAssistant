import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/services/localization_service.dart';
import '../../../../common/localization/common_localization.dart';
import '../../../../common/providers/common_provider.dart';
import '../../../localization/home_localization_keys.dart';
import 'airport_search_bar.dart';

/// 机场选择器对话框入口按钮组（出发/目的地/备降）
///
/// 包含三个紧凑型按钮，点击后弹出含搜索框的机场选择对话框
class AirportPickerButtonGroup extends StatelessWidget {
  const AirportPickerButtonGroup({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<LocalizationService>();
    final provider = context.watch<HomeProvider>();
    final dep = provider.departureAirport;
    final dest = provider.destinationAirport;
    final alt = provider.alternateAirport;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPickerButton(
          context,
          label: dep != null
              ? '${CommonLocalizationKeys.navDeparture.tr(context)}: ${dep.icaoCode}'
              : HomeLocalizationKeys.navSetDeparture.tr(context),
          icon: dep != null ? Icons.flight_takeoff : Icons.add_location_alt,
          onPressed: () => _showAirportPickerDialog(
            context,
            isDeparture: true,
            isAlternate: false,
          ),
        ),
        const SizedBox(width: 8),
        _buildPickerButton(
          context,
          label: dest != null
              ? '${CommonLocalizationKeys.navDestination.tr(context)}: ${dest.icaoCode}'
              : HomeLocalizationKeys.navSetDestination.tr(context),
          icon: dest != null ? Icons.location_on : Icons.add_location,
          onPressed: () =>
              _showAirportPickerDialog(context, isAlternate: false),
        ),
        const SizedBox(width: 8),
        _buildPickerButton(
          context,
          label: alt != null
              ? '${CommonLocalizationKeys.navAlternate.tr(context)}: ${alt.icaoCode}'
              : HomeLocalizationKeys.navSetAlternate.tr(context),
          icon: alt != null ? Icons.alt_route : Icons.add_road,
          onPressed: () => _showAirportPickerDialog(context, isAlternate: true),
        ),
      ],
    );
  }

  /// 构建单个紧凑型机场选择文字按钮
  Widget _buildPickerButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  /// 显示机场搜索/选择对话框
  ///
  /// [isDeparture] 为 true 时操作出发机场，[isAlternate] 为 true 时操作备降机场，
  /// 两者均为 false 则操作目的地机场
  void _showAirportPickerDialog(
    BuildContext context, {
    bool isDeparture = false,
    bool isAlternate = false,
  }) {
    final provider = context.read<HomeProvider>();
    showDialog(
      context: context,
      builder: (context) {
        // 根据类型决定对话框标题
        final title = isDeparture
            ? HomeLocalizationKeys.navPickDepartureTitle.tr(context)
            : (isAlternate
                  ? HomeLocalizationKeys.navPickAlternateTitle.tr(context)
                  : HomeLocalizationKeys.navPickDestinationTitle.tr(context));

        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AirportSearchBar(
                  onSearch: provider.searchAirports,
                  onSelect: (airport) async {
                    if (isDeparture) {
                      await provider.setDeparture(airport);
                    } else if (isAlternate) {
                      await provider.setAlternate(airport);
                    } else {
                      await provider.setDestination(airport);
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  suggestedAirports: provider.suggestedAirports,
                ),
              ],
            ),
          ),
          actions: [
            // 清除选择按钮
            TextButton(
              onPressed: () async {
                if (isDeparture) {
                  await provider.setDeparture(null);
                } else if (isAlternate) {
                  await provider.setAlternate(null);
                } else {
                  await provider.setDestination(null);
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(
                HomeLocalizationKeys.navClearSelection.tr(context),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(HomeLocalizationKeys.navCancel.tr(context)),
            ),
          ],
        );
      },
    );
  }
}
