import 'package:flutter_test/flutter_test.dart';
import 'package:forma/data/models/user_model.dart';
import 'package:forma/data/models/auth_response.dart';
import 'package:forma/data/models/aggregated_stats_model.dart';
import 'package:forma/data/models/drop_model.dart';

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

    test('DropModel should tolerate optional missing publish fields', () {
      final json = {
        'id': 'drop_1',
        'user_id': 'user_1',
        'player_profile_id': null,
        'sport_id': 'sport_1',
        'category_id': null,
        'provider': 'cloudinary',
        'provider_asset_id': 'asset_1',
        'public_id': 'forma/skill_clips/drop_1',
        'playback_url': 'https://res.cloudinary.com/demo/video/upload/drop.mp4',
        'caption': null,
        'duration_seconds': '12.4',
        'format': 'mp4',
        'bytes': 1024.0,
        'moderation_status': 'approved',
        'visibility': 'public',
        'created_at': '2026-07-03T12:00:00Z',
        'current_user_gave_props': false,
      };

      final drop = DropModel.fromJson(json);

      expect(drop.id, 'drop_1');
      expect(drop.thumbnailUrl, isNull);
      expect(drop.width, isNull);
      expect(drop.height, isNull);
      expect(drop.propsCount, 0);
      expect(drop.commentsCount, 0);
      expect(drop.hasPropped, isFalse);
      expect(drop.category, isNull);
      expect(drop.updatedAt, drop.createdAt);
    });
  });
}
