import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/services/persistence_service.dart';
import '../../../core/utils/logger.dart';
import '../models/http_models.dart';

class MiddlewareHttpService {
  static final MiddlewareHttpService _instance =
      MiddlewareHttpService._internal();

  factory MiddlewareHttpService() => _instance;

  MiddlewareHttpService._internal();

  static const String _baseUrlKey = 'middleware_http_base_url';
  static const String _timeoutMsKey = 'middleware_http_timeout_ms';
  static const String _defaultBaseUrl = 'http://127.0.0.1:18080';
  static const int _defaultTimeoutMs = 10000;

  final http.Client _client = http.Client();
  String _baseUrl = _defaultBaseUrl;
  Duration _timeout = const Duration(milliseconds: _defaultTimeoutMs);
  final Map<String, String> _defaultHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  String get baseUrl => _baseUrl;
  Duration get timeout => _timeout;
  Map<String, String> get defaultHeaders => Map.unmodifiable(_defaultHeaders);

  Future<void> init() async {
    final persistence = PersistenceService();
    if (!persistence.isInitialized) {
      await persistence.ensureReady();
    }
    final savedBaseUrl = persistence.getString(_baseUrlKey);
    if (savedBaseUrl != null && savedBaseUrl.trim().isNotEmpty) {
      _baseUrl = _normalizeBaseUrl(savedBaseUrl);
    }
    final timeoutMs = persistence.getInt(_timeoutMsKey);
    if (timeoutMs != null && timeoutMs > 0) {
      _timeout = Duration(milliseconds: timeoutMs);
    }
  }

  Future<void> configure({
    String? baseUrl,
    Duration? timeout,
    Map<String, String>? defaultHeaders,
    bool persist = true,
  }) async {
    if (baseUrl != null && baseUrl.trim().isNotEmpty) {
      _baseUrl = _normalizeBaseUrl(baseUrl);
    }
    if (timeout != null && timeout.inMilliseconds > 0) {
      _timeout = timeout;
    }
    if (defaultHeaders != null) {
      _defaultHeaders
        ..clear()
        ..addAll(defaultHeaders);
    }
    if (persist) {
      final persistence = PersistenceService();
      if (!persistence.isInitialized) {
        await persistence.ensureReady();
      }
      await persistence.setString(_baseUrlKey, _baseUrl);
      await persistence.setInt(_timeoutMsKey, _timeout.inMilliseconds);
    }
  }

  void setAuthToken(String? token) {
    if (token == null || token.trim().isEmpty) {
      _defaultHeaders.remove('Authorization');
      return;
    }
    _defaultHeaders['Authorization'] = 'Bearer ${token.trim()}';
  }

  Future<MiddlewareHttpResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) {
    return request(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Future<MiddlewareHttpResponse> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) {
    return request(
      method: 'POST',
      path: path,
      body: body,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Future<MiddlewareHttpResponse> put(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) {
    return request(
      method: 'PUT',
      path: path,
      body: body,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Future<MiddlewareHttpResponse> patch(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) {
    return request(
      method: 'PATCH',
      path: path,
      body: body,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Future<MiddlewareHttpResponse> delete(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) {
    return request(
      method: 'DELETE',
      path: path,
      body: body,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Future<MiddlewareHttpResponse> request({
    required String method,
    required String path,
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final mergedHeaders = <String, String>{}
      ..addAll(_defaultHeaders)
      ..addAll(headers ?? {});

    final requestBody = _serializeBody(body, mergedHeaders);
    final req = http.Request(method.toUpperCase(), uri)
      ..headers.addAll(mergedHeaders);
    if (requestBody != null) {
      req.body = requestBody;
    }

    final effectiveTimeout = timeout ?? _timeout;
    try {
      final streamed = await _client.send(req).timeout(effectiveTimeout);
      final response = await http.Response.fromStream(streamed);
      final result = MiddlewareHttpResponse(
        statusCode: response.statusCode,
        headers: response.headers,
        body: response.body,
        uri: uri,
      );
      if (!result.isSuccess) {
        throw MiddlewareHttpException(
          message: 'HTTP request failed',
          statusCode: result.statusCode,
          data: result.decodedBody,
          uri: uri,
        );
      }
      return result;
    } on TimeoutException catch (e) {
      throw MiddlewareHttpException(
        message: 'Request timeout: ${e.message ?? 'timeout'}',
        uri: uri,
      );
    } on MiddlewareHttpException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Middleware HTTP request error', e, stackTrace);
      throw MiddlewareHttpException(message: 'Request error: $e', uri: uri);
    }
  }

  Future<MiddlewareHttpResponse> getHealth() {
    return get('/health');
  }

  Future<MiddlewareHttpResponse> getVersion() {
    return get('/api/v1/version');
  }

  Future<MiddlewareHttpResponse> getAirportByIcao(String icao) {
    final normalizedIcao = _normalizeIcao(icao);
    return get('/api/v1/airport/$normalizedIcao');
  }

  Future<MiddlewareHttpResponse> getMetarByIcao(String icao) {
    final normalizedIcao = _normalizeIcao(icao);
    return get('/api/v1/metar/$normalizedIcao');
  }

  Future<MiddlewareHttpResponse> getAirportList() {
    return get('/api/v1/airport-list');
  }

  Future<MiddlewareHttpResponse> getSimulatorState({required String type}) {
    return post(
      '/api/v1/simulator/state',
      body: {'type': _normalizeType(type)},
    );
  }

  Future<MiddlewareHttpResponse> connectSimulator({
    required String type,
    int timeout = 8,
    String? address,
  }) {
    final body = <String, dynamic>{
      'type': _normalizeType(type),
      'timeout': timeout,
      'address': address?.trim() ?? '',
    };
    return post('/api/v1/simulator/connect', body: body);
  }

  Future<MiddlewareHttpResponse> getSimulatorData({required String token}) {
    return post('/api/v1/simulator/data', body: {'token': token.trim()});
  }

  Future<MiddlewareHttpResponse> disconnectSimulator({required String token}) {
    return post('/api/v1/simulator/disconnect', body: {'token': token.trim()});
  }

  Uri _buildUri(String path, Map<String, dynamic>? queryParameters) {
    final normalizedPath = path.trim().isEmpty ? '/' : path.trim();
    final baseUri = Uri.parse(_baseUrl);
    final segments = <String>[
      ...baseUri.pathSegments.where((e) => e.isNotEmpty),
      ...normalizedPath.split('/').where((e) => e.isNotEmpty),
    ];
    final query = <String, String>{};
    if (baseUri.queryParameters.isNotEmpty) {
      query.addAll(baseUri.queryParameters);
    }
    if (queryParameters != null) {
      query.addAll(
        queryParameters.map((k, v) => MapEntry(k, v?.toString() ?? '')),
      );
    }
    return baseUri.replace(
      pathSegments: segments,
      queryParameters: query.isEmpty ? null : query,
    );
  }

  String? _serializeBody(dynamic body, Map<String, String> headers) {
    if (body == null) {
      return null;
    }
    if (body is String) {
      return body;
    }
    final contentType =
        (headers['Content-Type'] ?? headers['content-type'])?.toLowerCase() ??
        '';
    if (contentType.contains('application/json')) {
      return jsonEncode(body);
    }
    return body.toString();
  }

  String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    final uri = Uri.parse(trimmed);
    final normalized = uri.replace(
      pathSegments: uri.pathSegments.where((e) => e.isNotEmpty).toList(),
      query: null,
      fragment: null,
    );
    return normalized.toString().replaceAll(RegExp(r'\/+$'), '');
  }

  String _normalizeIcao(String icao) {
    return icao.trim().toUpperCase();
  }

  String _normalizeType(String type) {
    return type.trim().toLowerCase();
  }
}
