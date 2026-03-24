enum MapTaxiwaySegmentLineType { straight, mapMatching }

extension MapTaxiwaySegmentLineTypeX on MapTaxiwaySegmentLineType {
  String get value {
    switch (this) {
      case MapTaxiwaySegmentLineType.straight:
        return 'straight';
      case MapTaxiwaySegmentLineType.mapMatching:
        return 'map_matching';
    }
  }

  static MapTaxiwaySegmentLineType fromValue(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'map_matching':
      case 'mapmatching':
      case 'curve':
        return MapTaxiwaySegmentLineType.mapMatching;
      default:
        return MapTaxiwaySegmentLineType.straight;
    }
  }
}

enum MapTaxiwaySegmentCurveDirection { left, right }

extension MapTaxiwaySegmentCurveDirectionX on MapTaxiwaySegmentCurveDirection {
  String get value {
    switch (this) {
      case MapTaxiwaySegmentCurveDirection.left:
        return 'left';
      case MapTaxiwaySegmentCurveDirection.right:
        return 'right';
    }
  }

  int get sign {
    switch (this) {
      case MapTaxiwaySegmentCurveDirection.left:
        return -1;
      case MapTaxiwaySegmentCurveDirection.right:
        return 1;
    }
  }

  static MapTaxiwaySegmentCurveDirection fromValue(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'right':
      case 'clockwise':
        return MapTaxiwaySegmentCurveDirection.right;
      default:
        return MapTaxiwaySegmentCurveDirection.left;
    }
  }
}

class MapTaxiwaySegment {
  final String? name;
  final String? colorHex;
  final String? note;
  final MapTaxiwaySegmentLineType lineType;
  final double curvature;
  final MapTaxiwaySegmentCurveDirection curveDirection;

  const MapTaxiwaySegment({
    this.name,
    this.colorHex,
    this.note,
    this.lineType = MapTaxiwaySegmentLineType.straight,
    this.curvature = 0.35,
    this.curveDirection = MapTaxiwaySegmentCurveDirection.left,
  });

  MapTaxiwaySegment copyWith({
    String? name,
    String? colorHex,
    String? note,
    MapTaxiwaySegmentLineType? lineType,
    double? curvature,
    MapTaxiwaySegmentCurveDirection? curveDirection,
    bool clearName = false,
    bool clearColorHex = false,
    bool clearNote = false,
  }) {
    return MapTaxiwaySegment(
      name: clearName ? null : (name ?? this.name),
      colorHex: clearColorHex ? null : (colorHex ?? this.colorHex),
      note: clearNote ? null : (note ?? this.note),
      lineType: lineType ?? this.lineType,
      curvature: curvature ?? this.curvature,
      curveDirection: curveDirection ?? this.curveDirection,
    );
  }
}
