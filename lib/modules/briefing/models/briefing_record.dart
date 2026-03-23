/// 飞行简报记录模型
/// 包含简报标题、正文内容、创建时间以及关联的本地文件路径
class BriefingRecord {
  /// 简报标题 (例如: ZGGG → VHHH)
  final String title;

  /// 简报正文 (纯文本格式)
  final String content;

  /// 生成时间
  final DateTime createdAt;

  /// 本地持久化文件路径 (用于更新或删除)
  final String? sourceFilePath;

  const BriefingRecord({
    required this.title,
    required this.content,
    required this.createdAt,
    this.sourceFilePath,
  });

  /// 转换为 JSON 格式
  Map<String, dynamic> toJson() => {
    'title': title,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
  };

  /// 从 JSON 格式解析
  factory BriefingRecord.fromJson(Map<String, dynamic> json) => BriefingRecord(
    title: json['title'] as String? ?? '',
    content: json['content'] as String? ?? '',
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now(),
  );

  /// 拷贝并替换部分字段
  BriefingRecord copyWith({
    String? title,
    String? content,
    DateTime? createdAt,
    String? sourceFilePath,
  }) {
    return BriefingRecord(
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      sourceFilePath: sourceFilePath ?? this.sourceFilePath,
    );
  }
}
