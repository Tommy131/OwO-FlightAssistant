/// 工具箱模块 - 单位转换配置模型
///
/// 用于定义单位转换的显示名称、目标单位以及转换逻辑。
class UnitConversionOption {
  /// 国际化显示的标签 Key
  final String labelKey;

  /// 转换结果的单位后缀 (如 'hPa', 'inHg')
  final String resultUnit;

  /// 具体的转换计算函数
  final double Function(double) converter;

  const UnitConversionOption({
    required this.labelKey,
    required this.resultUnit,
    required this.converter,
  });
}

/// 工具箱模块 - 航空术语模型
///
/// 用于定义航空术语的缩写、全称、中文名称及详细描述。
class AviationTerm {
  /// 术语缩写 (如 'V1', 'ILS')
  final String abbreviation;

  /// 术语英文全称
  final String fullName;

  /// 术语中文译名
  final String chineseName;

  /// 术语的详细解释 (可选)
  final String? description;

  const AviationTerm({
    required this.abbreviation,
    required this.fullName,
    required this.chineseName,
    this.description,
  });

  /// 获取用于搜索显示的复合字符串
  String get displayValue => '$chineseName ($fullName)';
}
