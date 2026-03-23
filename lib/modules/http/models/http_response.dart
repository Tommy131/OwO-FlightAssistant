import 'dart:convert';

/// HTTP 响应封装
///
/// 统一包装来自 [MiddlewareHttpService] 的原始响应，提供：
/// - [isSuccess]：状态码是否在 2xx 范围内
/// - [decodedBody]：自动 JSON 解码的响应体
/// - [jsonAs]：带泛型类型断言的解码快捷方法
class MiddlewareHttpResponse {
  /// HTTP 状态码
  final int statusCode;

  /// 响应头
  final Map<String, String> headers;

  /// 原始响应体字符串
  final String body;

  /// 请求 URI
  final Uri uri;

  const MiddlewareHttpResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
    required this.uri,
  });

  /// 是否为成功响应（状态码 200–299）
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// 解码后的响应体
  ///
  /// - 若 body 为空返回 null
  /// - 若可解析为 JSON 则返回解析结果
  /// - 否则以原始字符串返回
  dynamic get decodedBody {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  /// 将 [decodedBody] 强转为指定类型 [T]，失败返回 null
  T? jsonAs<T>() {
    final decoded = decodedBody;
    if (decoded is T) return decoded;
    return null;
  }
}
