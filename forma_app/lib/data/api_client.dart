import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  final http.Client _client;
  final FlutterSecureStorage _secureStorage;

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://forma-app.up.railway.app',
  );

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

  Future<dynamic> get(String path, {bool authenticated = true}) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final headers = await _getHeaders(authenticated: authenticated);

      final response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(
        'Network connection failed or timed out: ${e.toString()}',
      );
    }
  }

  Future<dynamic> post(
    String path, {
    dynamic body,
    bool authenticated = true,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final headers = await _getHeaders(authenticated: authenticated);
      final encodedBody = body != null ? jsonEncode(body) : null;

      final response = await _client
          .post(uri, headers: headers, body: encodedBody)
          .timeout(const Duration(seconds: 15));

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(
        'Network connection failed or timed out: ${e.toString()}',
      );
    }
  }

  Future<dynamic> patch(
    String path, {
    dynamic body,
    bool authenticated = true,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final headers = await _getHeaders(authenticated: authenticated);
      final encodedBody = body != null ? jsonEncode(body) : null;

      final response = await _client
          .patch(uri, headers: headers, body: encodedBody)
          .timeout(const Duration(seconds: 15));

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(
        'Network connection failed or timed out: ${e.toString()}',
      );
    }
  }

  Future<dynamic> delete(String path, {bool authenticated = true}) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final headers = await _getHeaders(authenticated: authenticated);

      final response = await _client
          .delete(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(
        'Network connection failed or timed out: ${e.toString()}',
      );
    }
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
      );
    } else if (statusCode == 403) {
      throw ForbiddenException(message?.toString() ?? 'Access denied.');
    } else if (statusCode == 404) {
      throw NotFoundException(message?.toString() ?? 'Resource not found.');
    } else if (statusCode == 422) {
      String parsedMessage = 'Validation failed';
      if (responseJson != null && responseJson is Map) {
        parsedMessage = _parseValidationErrorMessage(responseJson);
      }
      throw ValidationException(parsedMessage);
    } else if (statusCode >= 500) {
      throw ServerException(
        'Server error ($statusCode): Please try again later.',
      );
    } else {
      throw ApiException(
        message?.toString() ?? 'An error occurred. Status code: $statusCode',
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
  ApiException(this.message);
  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  NetworkException(super.message);
}

class UnauthenticatedException extends ApiException {
  UnauthenticatedException(super.message);
}

class ForbiddenException extends ApiException {
  ForbiddenException(super.message);
}

class NotFoundException extends ApiException {
  NotFoundException(super.message);
}

class ValidationException extends ApiException {
  ValidationException(super.message);
}

class ServerException extends ApiException {
  ServerException(super.message);
}
