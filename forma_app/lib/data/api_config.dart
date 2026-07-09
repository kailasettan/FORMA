import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.nadhalabs.com',
  );

  static String get baseUrl =>
      _configuredBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');

  static Uri get baseUri => Uri.parse(baseUrl);

  static void validateForCurrentMode() {
    final uri = baseUri;
    final host = uri.host.toLowerCase();
    final isLocalHost =
        host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2';

    if (kReleaseMode) {
      if (isLocalHost) {
        throw StateError(
          'Invalid API_BASE_URL for release: local backend hosts are not allowed.',
        );
      }
      if (uri.scheme != 'https') {
        throw StateError(
          'Invalid API_BASE_URL for release: HTTPS is required.',
        );
      }
    }
  }
}
