import 'package:flutter/material.dart';
import '../../settings/widgets/data_path_item.dart';
import '../../settings/widgets/settings_widgets.dart';

class SetupGuideDatabaseCards extends StatelessWidget {
  final String? lnmPath;
  final String? xplanePath;
  final Map<String, String>? lnmInfo;
  final Map<String, String>? xplaneInfo;
  final VoidCallback onSelectLnm;
  final VoidCallback onSelectXPlane;

  const SetupGuideDatabaseCards({
    super.key,
    required this.lnmPath,
    required this.xplanePath,
    required this.lnmInfo,
    required this.xplaneInfo,
    required this.onSelectLnm,
    required this.onSelectXPlane,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SettingsCard(
          title: 'Little Navmap 数据库 (必填)',
          subtitle: '提供全球机场、跑道和导航设备信息',
          icon: Icons.map_rounded,
          child: DataPathItem(
            label: '选择 .sqlite 数据库文件',
            path: lnmPath,
            airac: lnmInfo?['airac'],
            expiry: lnmInfo?['expiry'],
            isExpired: lnmInfo?['is_expired'] == 'true',
            onSelect: onSelectLnm,
          ),
        ),
        SettingsCard(
          title: 'X-Plane 导航数据 (可选)',
          subtitle: '配置后可获得更准确的 X-Plane 内部数据',
          icon: Icons.airplanemode_active_rounded,
          child: DataPathItem(
            label: '选择 earth_nav.dat 文件',
            path: xplanePath,
            airac: xplaneInfo?['airac'],
            expiry: xplaneInfo?['expiry'],
            isExpired: xplaneInfo?['is_expired'] == 'true',
            onSelect: onSelectXPlane,
          ),
        ),
      ],
    );
  }
}
