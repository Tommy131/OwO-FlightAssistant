/// HTTP 请求异常
///
/// 在请求超时、后端返回非 2xx 响应或网络错误时抛出
class MiddlewareHttpException implements Exception {
  /// 错误描述信息
  final String message;

  /// HTTP 状态码（网络层错误时为 null）
  final int? statusCode;

  /// 后端返回的原始响应体（可能为 null）
  final dynamic data;

  /// 请求目标 URI
  final Uri? uri;

  const MiddlewareHttpException({
    required this.message,
    this.statusCode,
    this.data,
    this.uri,
  });

  @override
  String toString() {
    final buffer = StringBuffer('MiddlewareHttpException: $message');
    if (statusCode != null) {
      buffer.write(' (statusCode=$statusCode)');
    }
    if (uri != null) {
      buffer.write(' uri=$uri');
    }
    return buffer.toString();
  }
}
