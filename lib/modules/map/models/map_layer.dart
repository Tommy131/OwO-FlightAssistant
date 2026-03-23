/// 地图图层样式枚举及瓦片 URL 解析
///
/// 定义地图可用的基底图层风格，并提供对应的 XYZ 瓦片 URL 模板。
library;

/// 地图图层样式
enum MapLayerStyle {
  /// 深色风格（CartoDB Dark，适合夜间/暗色主题）
  dark,

  /// 卫星影像图（ArcGIS World Imagery）
  satellite,

  /// 地形图（ArcGIS World Topo Map）
  terrain,

  /// 滑行道/街道图（CartoDB Voyager，适合机场地面引导）
  taxiway,
}

/// 根据图层样式返回对应的 XYZ 瓦片 URL 模板
///
/// 模板变量说明：
/// - `{z}` — 缩放级别
/// - `{x}` / `{y}` — 瓦片坐标
/// - `{s}` — 随机子域（a/b/c，用于负载均衡）
String mapTileUrl(MapLayerStyle style) {
  switch (style) {
    case MapLayerStyle.satellite:
      return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    case MapLayerStyle.terrain:
      return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}';
    case MapLayerStyle.taxiway:
      return 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}{r}.png';
    case MapLayerStyle.dark:
      return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
  }
}
