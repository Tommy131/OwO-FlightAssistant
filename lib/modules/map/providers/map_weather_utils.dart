/// 天气/METAR 文本解析工具类
///
/// 封装所有 METAR 报文处理、能见度解析、飞行规则（飞行类别）推断等逻辑，
/// 从 [MapProvider] 中抽离，实现单一职责。
///
/// 所有方法均为静态纯函数，无副作用，便于单独测试。
class MapWeatherUtils {
  MapWeatherUtils._(); // 纯工具类，禁止实例化

  // ── API 响应解析辅助 ───────────────────────────────────────────────────────

  /// 从 Map 中安全提取字段值（大小写不敏感）
  ///
  /// 首先精确匹配 [keys] 中的键名，若未命中则进行不区分大小写的模糊匹配。
  static dynamic pickValue(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      if (raw.containsKey(key)) return raw[key];
    }
    for (final key in keys) {
      for (final entry in raw.entries) {
        if (entry.key.toLowerCase() == key.toLowerCase()) return entry.value;
      }
    }
    return null;
  }

  /// 将任意值转换为 [Map<String, dynamic>]（支持强类型和弱类型 Map）
  static Map<String, dynamic>? asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry('$k', v));
    return null;
  }

  // ── METAR 字段提取 ────────────────────────────────────────────────────────

  /// 从 METAR 根对象中提取指定字段的文本值
  ///
  /// 自动处理嵌套在 `data` 键下的情况，字段为空时返回 null。
  static String? extractMetarField(
    Map<String, dynamic> root,
    List<String> keys,
  ) {
    final payloadRoot = asMap(pickValue(root, ['data'])) ?? root;
    final raw = pickValue(payloadRoot, keys);
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  /// 清理天气文本中的非法字符（空字节、替换字符、不可见控制符）
  ///
  /// 返回 null 表示清理后文本为空。
  static String? normalizeWeatherText(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final cleaned = text
        .replaceAll('\u0000', '')
        .replaceAll('\uFFFD', '')
        .replaceAll(RegExp(r'[\u0001-\u0008\u000B\u000C\u000E-\u001F]'), '');
    return cleaned.trim().isEmpty ? null : cleaned.trim();
  }

  // ── 飞行规则推断 ──────────────────────────────────────────────────────────

  /// 推断机场飞行规则分类（VFR / MVFR / IFR / LIFR / UNK）
  ///
  /// 优先从 API 返回的结构化字段中直接读取（`flight_rules` 等），
  /// 其次根据能见度（SM）和云层高度（BKN/OVC）计算，
  /// 最后尝试从原始 METAR 字符串中提取，都无法识别时返回 "UNK"。
  static String resolveApproachRule(
    Map<String, dynamic> root,
    String? rawMetar,
  ) {
    final payloadRoot = asMap(pickValue(root, ['data'])) ?? root;
    final direct = extractMetarField(payloadRoot, [
      'flight_rules',
      'flight_rule',
      'flight_category',
      'flightCategory',
      'category',
      'approach_rule',
      'approachRule',
    ]);
    final byDirect = normalizeApproachRule(direct);
    if (byDirect != null) return byDirect;

    // 通过能见度和云层高度计算飞行类别
    final visibility = extractMetarField(payloadRoot, [
      'visibility',
      'display_visibility',
    ]);
    final clouds = extractMetarField(payloadRoot, ['clouds']);
    final visibilitySm = parseVisibilitySm(visibility);
    final ceilingFt = parseCeilingFt(clouds);
    if (visibilitySm != null || ceilingFt != null) {
      if ((ceilingFt != null && ceilingFt < 500) ||
          (visibilitySm != null && visibilitySm < 1)) {
        return 'LIFR';
      }
      if ((ceilingFt != null && ceilingFt < 1000) ||
          (visibilitySm != null && visibilitySm < 3)) {
        return 'IFR';
      }
      if ((ceilingFt != null && ceilingFt <= 3000) ||
          (visibilitySm != null && visibilitySm <= 5)) {
        return 'MVFR';
      }
      return 'VFR';
    }

    // 从原始 METAR 文本尝试提取飞行类别
    final fromRaw = normalizeApproachRule(rawMetar);
    if (fromRaw != null) return fromRaw;
    if ((rawMetar ?? '').toUpperCase().contains('CAVOK')) return 'VFR';
    return 'UNK';
  }

  /// 将任意文本标准化为 VFR/MVFR/IFR/LIFR（忽略大小写）
  ///
  /// 若文本中不含上述关键字，返回 null。
  static String? normalizeApproachRule(String? text) {
    final upper = (text ?? '').toUpperCase();
    if (upper.contains('LIFR')) return 'LIFR';
    if (upper.contains('MVFR')) return 'MVFR';
    if (upper.contains('IFR')) return 'IFR';
    if (upper.contains('VFR')) return 'VFR';
    return null;
  }

  // ── 能见度解析 ────────────────────────────────────────────────────────────

  /// 解析 METAR 能见度字段，返回英里（SM）数值
  ///
  /// 支持格式：
  /// - 纯 4 位数字（米，如 "9999"），转换为 SM
  /// - 带 SM 单位（如 "10SM"、"1/4SM"、"P6SM"）
  /// 返回 null 表示无法解析。
  static double? parseVisibilitySm(String? rawVisibility) {
    final text = (rawVisibility ?? '').trim().toUpperCase();
    if (text.isEmpty) return null;

    // ICAO 格式：4 位数字代表米（如 0000、9999）
    final meterMatch = RegExp(r'^\d{4}$').firstMatch(text);
    if (meterMatch != null) {
      final meters = double.tryParse(text);
      if (meters == null) return null;
      return meters / 1609.344;
    }

    // FAA 格式：带 SM 单位（支持分数，如 "1/4SM"、"P6SM"）
    final smMatch = RegExp(
      r'([PM]?\d+(?:/\d+)?(?:\.\d+)?)\s*SM',
    ).firstMatch(text);
    if (smMatch == null) return null;

    final token = smMatch.group(1) ?? '';
    final normalized = token.replaceAll('P', '').replaceAll('M', '');
    if (normalized.contains('/')) {
      final parts = normalized.split('/');
      if (parts.length == 2) {
        final numerator = double.tryParse(parts[0]);
        final denominator = double.tryParse(parts[1]);
        if (numerator != null && denominator != null && denominator != 0) {
          return numerator / denominator;
        }
      }
    }
    return double.tryParse(normalized);
  }

  // ── 云层高度解析 ──────────────────────────────────────────────────────────

  /// 解析 METAR 云层字段，返回最低云幕高度（英尺）
  ///
  /// 匹配 BKN（碎云）和 OVC（阴天），以及垂直能见度（VV）等影响目视飞行的云层，
  /// 取多个匹配中最低的那个值。
  /// 返回 null 表示没有匹配到有效云层数据。
  static double? parseCeilingFt(String? cloudText) {
    final text = (cloudText ?? '').toUpperCase();
    if (text.isEmpty) return null;
    final matches = RegExp(r'(BKN|OVC|VV)(\d{3})').allMatches(text);
    int? minCeiling;
    for (final match in matches) {
      final value = int.tryParse(match.group(2) ?? '');
      if (value == null) continue;
      final ceiling = value * 100; // METAR 云高以百英尺为单位
      if (minCeiling == null || ceiling < minCeiling) {
        minCeiling = ceiling;
      }
    }
    return minCeiling?.toDouble();
  }
}
