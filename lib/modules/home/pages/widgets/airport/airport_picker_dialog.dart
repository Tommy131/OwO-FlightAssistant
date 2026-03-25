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
  final Axis direction;

  const AirportPickerButtonGroup({super.key, this.direction = Axis.horizontal});

  @override
  Widget build(BuildContext context) {
    context.watch<LocalizationService>();
    final provider = context.watch<HomeProvider>();
    final dep = provider.departureAirport;
    final dest = provider.destinationAirport;
    final alt = provider.alternateAirport;
    final isVertical = direction == Axis.vertical;

    return Flex(
      direction: direction,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isVertical
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.center,
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
        SizedBox(width: isVertical ? 0 : 8, height: isVertical ? 6 : 0),
        _buildPickerButton(
          context,
          label: dest != null
              ? '${CommonLocalizationKeys.navDestination.tr(context)}: ${dest.icaoCode}'
              : HomeLocalizationKeys.navSetDestination.tr(context),
          icon: dest != null ? Icons.location_on : Icons.add_location,
          onPressed: () =>
              _showAirportPickerDialog(context, isAlternate: false),
        ),
        SizedBox(width: isVertical ? 0 : 8, height: isVertical ? 6 : 0),
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
        final media = MediaQuery.of(context);
        final bodyMaxHeight = media.size.height - media.viewInsets.bottom - 180;
        final bodyHeight = bodyMaxHeight <= 0
            ? media.size.height * 0.3
            : (bodyMaxHeight > 520 ? 520.0 : bodyMaxHeight);
        // 根据类型决定对话框标题
        final title = isDeparture
            ? HomeLocalizationKeys.navPickDepartureTitle.tr(context)
            : (isAlternate
                  ? HomeLocalizationKeys.navPickAlternateTitle.tr(context)
                  : HomeLocalizationKeys.navPickDestinationTitle.tr(context));

        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Text(title),
          content: SizedBox(
            width: 420,
            height: bodyHeight,
            child: AirportSearchBar(
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
              child: Text(HomeLocalizationKeys.navClearSelection.tr(context)),
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
