import 'package:flutter/material.dart';
import '../models/map_types.dart';

/// 底图选择器弹层
class MapLayerPicker {
  static void show(
    BuildContext context, {
    required MapLayerType current,
    required ValueChanged<MapLayerType> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择地图图层',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildOption(context, current, MapLayerType.dark, '暗色', Icons.dark_mode, onSelected),
                  const SizedBox(width: 16),
                  _buildOption(context, current, MapLayerType.satellite, '卫星', Icons.satellite_alt, onSelected),
                  const SizedBox(width: 16),
                  _buildOption(context, current, MapLayerType.street, '街道', Icons.map, onSelected),
                  const SizedBox(width: 16),
                  _buildOption(context, current, MapLayerType.terrain, '地形', Icons.landscape, onSelected),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  static Widget _buildOption(
    BuildContext context,
    MapLayerType current,
    MapLayerType type,
    String label,
    IconData icon,
    ValueChanged<MapLayerType> onSelected,
  ) {
    final isSelected = current == type;
    return GestureDetector(
      onTap: () {
        onSelected(type);
        Navigator.pop(context);
      },
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isSelected ? Colors.orangeAccent : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? Colors.white : Colors.white12, width: 2),
            ),
            child: Icon(icon, color: isSelected ? Colors.black : Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.orangeAccent : Colors.white70,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
