import 'package:flutter_test/flutter_test.dart';
import 'package:forma/data/models/user_model.dart';
import 'package:forma/data/models/auth_response.dart';
import 'package:forma/data/models/aggregated_stats_model.dart';

void main() {
  group('JSON Parsing Tests', () {
    test('UserModel should parse JSON successfully with all fields', () {
      final json = {
        'id': 'b102b54c-53e7-4008-8e68-3e40632b6941',
        'username': 'johndoe',
        'email': 'john@example.com',
        'full_name': 'John Doe',
        'age': 25,
        'city': 'New York',
        'profile_photo_url': 'https://example.com/photo.jpg',
        'created_at': '2026-07-02T12:00:00Z',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, 'b102b54c-53e7-4008-8e68-3e40632b6941');
      expect(user.username, 'johndoe');
      expect(user.email, 'john@example.com');
      expect(user.fullName, 'John Doe');
      expect(user.age, 25);
      expect(user.city, 'New York');
      expect(user.profilePhotoUrl, 'https://example.com/photo.jpg');
      expect(user.createdAt, DateTime.parse('2026-07-02T12:00:00Z'));
    });

    test('UserModel should handle nullable fields safely', () {
      final json = {
        'id': 'b102b54c-53e7-4008-8e68-3e40632b6941',
        'username': 'johndoe',
        'email': 'john@example.com',
        'full_name': 'John Doe',
        'age': null,
        'city': null,
        'profile_photo_url': null,
        'created_at': '2026-07-02T12:00:00Z',
      };

      final user = UserModel.fromJson(json);

      expect(user.age, isNull);
      expect(user.city, isNull);
      expect(user.profilePhotoUrl, isNull);
    });

    test('AuthResponse should parse access_token and user info', () {
      final json = {
        'access_token': 'secret_jwt_token',
        'token_type': 'bearer',
        'user': {
          'id': 'b102b54c-53e7-4008-8e68-3e40632b6941',
          'username': 'johndoe',
          'email': 'john@example.com',
          'full_name': 'John Doe',
          'age': 25,
          'city': 'New York',
          'profile_photo_url': null,
          'created_at': '2026-07-02T12:00:00Z',
        },
      };

      final authResponse = AuthResponse.fromJson(json);

      expect(authResponse.accessToken, 'secret_jwt_token');
      expect(authResponse.tokenType, 'bearer');
      expect(authResponse.user.username, 'johndoe');
    });

    test('AggregatedStatsModel should parse football stats correctly', () {
      final json = {'matches_played': 5, 'goals': 3, 'assists': 2};

      final aggregated = AggregatedStatsModel.fromJson(json);

      expect(aggregated.matchesPlayed, 5);
      expect(aggregated.goals, 3);
      expect(aggregated.assists, 2);
    });
  });
}
