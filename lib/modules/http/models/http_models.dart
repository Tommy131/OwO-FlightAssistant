import 'dart:convert';

class MiddlewareHttpException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;
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

class MiddlewareHttpResponse {
  final int statusCode;
  final Map<String, String> headers;
  final String body;
  final Uri uri;

  const MiddlewareHttpResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
    required this.uri,
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  dynamic get decodedBody {
    if (body.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  T? jsonAs<T>() {
    final decoded = decodedBody;
    if (decoded is T) {
      return decoded;
    }
    return null;
  }
}
