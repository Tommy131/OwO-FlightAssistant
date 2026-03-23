/// 将 dynamic 类型的数据转换为 Map<String, dynamic>
/// 如果数据本身是 Map 类型，会将其键统一转换为 String 格式
Map<String, dynamic>? asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry('$key', val));
  }
  return null;
}

/// 将 dynamic 数据转换为 Map<String, dynamic> 列表
/// 过滤掉列表中不是 Map 格式的项目
List<Map<String, dynamic>> asListOfMaps(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) => asMap(item))
      .whereType<Map<String, dynamic>>()
      .toList();
}

/// 安全读取字符串，并去除前后空格
/// 如果字符串为空或值为 null，则返回 null
String? readString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

/// 安全读取浮点数
/// 支持将 num 类型直接转换，或将字符串解析为 double
double? readDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

/// 安全读取整数
/// 支持将 num 类型转换，或将字符串解析为 int
int? readInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

/// 从给定的 Map 中选取指定键列表中的第一个存在的键对应的值
/// 支持忽略大小写的模糊匹配
dynamic pick(Map<String, dynamic>? map, List<String> keys) {
  if (map == null) return null;
  // 首先尝试精确匹配（性能较好）
  for (final key in keys) {
    if (map.containsKey(key)) {
      return map[key];
    }
  }
  // 备选方案：忽略大小写进行遍历搜索
  for (final key in keys) {
    for (final entry in map.entries) {
      if (entry.key.toLowerCase() == key.toLowerCase()) {
        return entry.value;
      }
    }
  }
  return null;
}
