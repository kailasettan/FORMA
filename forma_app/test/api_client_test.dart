import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:forma/data/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read({
    required String key,
    AndroidOptions? aOptions,
    AppleOptions? iOptions,
    LinuxOptions? lOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
  }) async {
    return _storage[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AndroidOptions? aOptions,
    AppleOptions? iOptions,
    LinuxOptions? lOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
  }) async {
    if (value != null) {
      _storage[key] = value;
    } else {
      _storage.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    AndroidOptions? aOptions,
    AppleOptions? iOptions,
    LinuxOptions? lOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
  }) async {
    _storage.remove(key);
  }
}

class MockHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest) handler;

  MockHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    final bodyBytes = response.bodyBytes;
    return http.StreamedResponse(
      Stream.value(bodyBytes),
      response.statusCode,
      contentLength: bodyBytes.length,
      headers: response.headers,
      request: request,
    );
  }
}

void main() {
  group('ApiClient Tests', () {
    late FakeSecureStorage fakeSecureStorage;

    setUp(() {
      fakeSecureStorage = FakeSecureStorage();
    });

    test('should attach Authorization header when token is present', () async {
      await fakeSecureStorage.write(
        key: ApiClient.tokenKey,
        value: 'my_test_token',
      );

      http.BaseRequest? capturedRequest;
      final mockClient = MockHttpClient((request) async {
        capturedRequest = request;
        return http.Response(jsonEncode({'success': true}), 200);
      });

      final apiClient = ApiClient(
        client: mockClient,
        secureStorage: fakeSecureStorage,
      );
      await apiClient.get('/test-route');

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.headers['Authorization'], 'Bearer my_test_token');
    });

    test('401 response should throw UnauthenticatedException', () async {
      final mockClient = MockHttpClient((request) async {
        return http.Response(jsonEncode({'detail': 'Token expired'}), 401);
      });

      final apiClient = ApiClient(
        client: mockClient,
        secureStorage: fakeSecureStorage,
      );

      expect(
        () => apiClient.get('/test-route'),
        throwsA(isA<UnauthenticatedException>()),
      );
    });

    test('403 response should throw ForbiddenException', () async {
      final mockClient = MockHttpClient((request) async {
        return http.Response(jsonEncode({'detail': 'Forbidden action'}), 403);
      });

      final apiClient = ApiClient(
        client: mockClient,
        secureStorage: fakeSecureStorage,
      );

      expect(
        () => apiClient.get('/test-route'),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('422 response should parse validation errors', () async {
      final validationBody = {
        'detail': [
          {
            'loc': ['body', 'stats', 'goals'],
            'msg': 'goals must be non-negative',
            'type': 'value_error',
          },
        ],
      };

      final mockClient = MockHttpClient((request) async {
        return http.Response(jsonEncode(validationBody), 422);
      });

      final apiClient = ApiClient(
        client: mockClient,
        secureStorage: fakeSecureStorage,
      );

      expect(
        () => apiClient.post('/match-stats', body: {'goals': -1}),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('stats.goals: goals must be non-negative'),
          ),
        ),
      );
    });
  });
}
