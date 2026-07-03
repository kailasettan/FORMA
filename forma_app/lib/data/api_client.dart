import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';

class ApiClient {
  final http.Client _client;
  final FlutterSecureStorage _secureStorage;

  static const String tokenKey = 'forma_jwt_token';

  ApiClient({http.Client? client, FlutterSecureStorage? secureStorage})
    : _client = client ?? http.Client(),
      _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<Map<String, String>> _getHeaders({bool authenticated = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (authenticated) {
      final token = await _secureStorage.read(key: tokenKey);
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: tokenKey, value: token);
  }

  Future<void> deleteToken() async {
    await _secureStorage.delete(key: tokenKey);
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: tokenKey);
  }

  Future<void> healthCheck({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    await get('/health', authenticated: false, timeout: timeout);
  }

  Future<dynamic> get(
    String path, {
    bool authenticated = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final uri = _uri(path);
    try {
      final headers = await _getHeaders(authenticated: authenticated);

      final response = await _client
          .get(uri, headers: headers)
          .timeout(timeout);

      _debugLogResponse('GET', uri, response.statusCode);
      return _handleResponse(response);
    } catch (e) {
      _debugLogError('GET', uri, e);
      if (e is ApiException) rethrow;
      throw _networkExceptionFor(e);
    }
  }

  Future<dynamic> post(
    String path, {
    dynamic body,
    bool authenticated = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final uri = _uri(path);
    try {
      final headers = await _getHeaders(authenticated: authenticated);
      final encodedBody = body != null ? jsonEncode(body) : null;

      final response = await _client
          .post(uri, headers: headers, body: encodedBody)
          .timeout(timeout);

      _debugLogResponse('POST', uri, response.statusCode);
      _debugLogResponseBody('POST', uri, response.statusCode, response.body);
      return _handleResponse(response);
    } catch (e) {
      _debugLogError('POST', uri, e);
      if (e is ApiException) rethrow;
      throw _networkExceptionFor(e);
    }
  }

  Future<dynamic> patch(
    String path, {
    dynamic body,
    bool authenticated = true,
  }) async {
    final uri = _uri(path);
    try {
      final headers = await _getHeaders(authenticated: authenticated);
      final encodedBody = body != null ? jsonEncode(body) : null;

      final response = await _client
          .patch(uri, headers: headers, body: encodedBody)
          .timeout(const Duration(seconds: 15));

      _debugLogResponse('PATCH', uri, response.statusCode);
      return _handleResponse(response);
    } catch (e) {
      _debugLogError('PATCH', uri, e);
      if (e is ApiException) rethrow;
      throw _networkExceptionFor(e);
    }
  }

  Future<dynamic> delete(String path, {bool authenticated = true}) async {
    final uri = _uri(path);
    try {
      final headers = await _getHeaders(authenticated: authenticated);

      final response = await _client
          .delete(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      _debugLogResponse('DELETE', uri, response.statusCode);
      return _handleResponse(response);
    } catch (e) {
      _debugLogError('DELETE', uri, e);
      if (e is ApiException) rethrow;
      throw _networkExceptionFor(e);
    }
  }

  Uri _uri(String path) => ApiConfig.baseUri.resolve(path);

  NetworkException _networkExceptionFor(Object error) {
    if (error is TimeoutException || error is http.ClientException) {
      return NetworkException(
        'Unable to reach FORMA. Check your internet connection.',
      );
    }
    return NetworkException(
      'Unable to reach FORMA. Check your internet connection.',
    );
  }

  void _debugLogResponse(String method, Uri uri, int statusCode) {
    if (!kDebugMode) return;
    debugPrint('HTTP $method ${uri.host}${uri.path} -> $statusCode');
  }

  void _debugLogError(String method, Uri uri, Object error) {
    if (!kDebugMode) return;
    debugPrint(
      'HTTP $method ${uri.host}${uri.path} failed: ${error.runtimeType}',
    );
  }

  void _debugLogResponseBody(
    String method,
    Uri uri,
    int statusCode,
    String body,
  ) {
    if (!kDebugMode || statusCode < 400) return;
    debugPrint('HTTP $method ${uri.host}${uri.path} body: $body');
  }

  dynamic _handleResponse(http.Response response) {
    final int statusCode = response.statusCode;

    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    dynamic responseJson;
    try {
      responseJson = jsonDecode(response.body);
    } catch (_) {
      // Body not JSON
    }

    final message = responseJson != null && responseJson is Map
        ? responseJson['detail']
        : response.body;

    if (statusCode == 401) {
      throw UnauthenticatedException(
        message?.toString() ?? 'Session expired. Please log in again.',
        statusCode: statusCode,
        responseBody: response.body,
      );
    } else if (statusCode == 403) {
      throw ForbiddenException(
        message?.toString() ?? 'Access denied.',
        statusCode: statusCode,
        responseBody: response.body,
      );
    } else if (statusCode == 404) {
      throw NotFoundException(
        message?.toString() ?? 'Resource not found.',
        statusCode: statusCode,
        responseBody: response.body,
      );
    } else if (statusCode == 422) {
      String parsedMessage = 'Validation failed';
      if (responseJson != null && responseJson is Map) {
        parsedMessage = _parseValidationErrorMessage(responseJson);
      }
      throw ValidationException(
        parsedMessage,
        statusCode: statusCode,
        responseBody: response.body,
      );
    } else if (statusCode >= 500) {
      throw ServerException(
        'Server error ($statusCode): Please try again later.',
        statusCode: statusCode,
        responseBody: response.body,
      );
    } else {
      throw ApiException(
        message?.toString() ?? 'An error occurred. Status code: $statusCode',
        statusCode: statusCode,
        responseBody: response.body,
      );
    }
  }

  String _parseValidationErrorMessage(Map<dynamic, dynamic> json) {
    final detail = json['detail'];
    if (detail is String) {
      return detail;
    } else if (detail is List) {
      return detail
          .map((e) {
            if (e is Map) {
              final loc = e['loc'] as List?;
              final field = loc != null && loc.length > 1
                  ? loc.sublist(1).join('.')
                  : '';
              final msg = e['msg'] ?? 'invalid value';
              return field.isNotEmpty ? '$field: $msg' : '$msg';
            }
            return e.toString();
          })
          .join('\n');
    }
    return 'Validation failed';
  }
}

// Exception Definitions
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? responseBody;
  ApiException(this.message, {this.statusCode, this.responseBody});
  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  NetworkException(super.message, {super.statusCode, super.responseBody});
}

class UnauthenticatedException extends ApiException {
  UnauthenticatedException(
    super.message, {
    super.statusCode,
    super.responseBody,
  });
}

class ForbiddenException extends ApiException {
  ForbiddenException(super.message, {super.statusCode, super.responseBody});
}

class NotFoundException extends ApiException {
  NotFoundException(super.message, {super.statusCode, super.responseBody});
}

class ValidationException extends ApiException {
  ValidationException(super.message, {super.statusCode, super.responseBody});
}

class ServerException extends ApiException {
  ServerException(super.message, {super.statusCode, super.responseBody});
}
