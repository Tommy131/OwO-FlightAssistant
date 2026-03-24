class MapTaxiwayNode {
  final double latitude;
  final double longitude;
  final String? name;
  final String? colorHex;
  final String? note;

  const MapTaxiwayNode({
    required this.latitude,
    required this.longitude,
    this.name,
    this.colorHex,
    this.note,
  });

  MapTaxiwayNode copyWith({
    double? latitude,
    double? longitude,
    String? name,
    String? colorHex,
    String? note,
    bool clearName = false,
    bool clearColorHex = false,
    bool clearNote = false,
  }) {
    return MapTaxiwayNode(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      name: clearName ? null : (name ?? this.name),
      colorHex: clearColorHex ? null : (colorHex ?? this.colorHex),
      note: clearNote ? null : (note ?? this.note),
    );
  }
}
