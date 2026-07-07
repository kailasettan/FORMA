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

    test('UserModel should parse supported profile photo field variants', () {
      final baseJson = {
        'id': 'b102b54c-53e7-4008-8e68-3e40632b6941',
        'username': 'johndoe',
        'email': 'john@example.com',
        'full_name': 'John Doe',
        'created_at': '2026-07-02T12:00:00Z',
      };

      for (final entry in {
        'profile_photo_url': 'https://example.com/profile-photo.jpg',
        'profilePhotoUrl': 'https://example.com/profile-photo-camel.jpg',
        'avatar_url': 'https://example.com/avatar.jpg',
        'avatarUrl': 'https://example.com/avatar-camel.jpg',
      }.entries) {
        final user = UserModel.fromJson({...baseJson, entry.key: entry.value});

        expect(user.profilePhotoUrl, entry.value);
      }
    });

    test('UserModel should normalize missing or blank profile photo URL', () {
      final json = {
        'id': 'b102b54c-53e7-4008-8e68-3e40632b6941',
        'username': 'johndoe',
        'email': 'john@example.com',
        'fullName': 'John Doe',
        'avatarUrl': '   ',
        'created_at': '2026-07-02T12:00:00Z',
      };

      final user = UserModel.fromJson(json);

      expect(user.fullName, 'John Doe');
      expect(user.profilePhotoUrl, isNull);
    });

    test('AuthResponse should parse access_token and user info', () {
      final json = {
        'access_token': 'secret_jwt_token',
        'token_type': 'bearer',
        'verification_required': true,
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
      expect(authResponse.verificationRequired, isTrue);
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

    test('DropModel parses sparse POST /drops response after publish', () {
      final json = {
        'id': '018fa0dc-5c63-73bb-a40f-020ace15ca9f',
        'user_id': '018fa0dc-5c63-73bb-a40f-020ace15ca9a',
        'player_profile_id': null,
        'sport_id': '018fa0dc-5c63-73bb-a40f-020ace15ca9b',
        'category_id': null,
        'provider': 'cloudinary',
        'provider_asset_id': 'asset_123',
        'public_id': 'forma/skill_clips/drop_123',
        'playback_url': 'https://res.cloudinary.com/demo/video/upload/drop.mp4',
        'thumbnail_url': null,
        'caption': null,
        'duration_seconds': 12.4,
        'width': null,
        'height': null,
        'format': 'mp4',
        'bytes': 1024,
        'moderation_status': 'approved',
        'visibility': 'public',
        'created_at': '2026-07-03T12:00:00Z',
        'updated_at': '2026-07-03T12:00:00Z',
        'user': {
          'id': '018fa0dc-5c63-73bb-a40f-020ace15ca9a',
          'username': 'athlete',
          'full_name': 'Athlete One',
          'age': null,
          'city': null,
          'profile_photo_url': null,
          'created_at': '2026-07-02T12:00:00Z',
          'headline': null,
          'bio': null,
          'location': null,
          'availability': null,
          'role': 'athlete',
          'focused_sport_id': null,
        },
        'sport': {
          'id': '018fa0dc-5c63-73bb-a40f-020ace15ca9b',
          'name': 'Football',
          'slug': 'football',
          'icon_url': null,
          'is_active': true,
          'created_at': '2026-07-02T12:00:00Z',
        },
        'category': null,
      };

      final drop = DropModel.fromJson(json);

      expect(drop.thumbnailUrl, isNull);
      expect(drop.caption, isNull);
      expect(drop.categoryId, isNull);
      expect(drop.playerProfileId, isNull);
      expect(drop.user?.profilePhotoUrl, isNull);
      expect(drop.sport?.iconUrl, isNull);
      expect(drop.category, isNull);
      expect(drop.width, isNull);
      expect(drop.height, isNull);
      expect(drop.propsCount, 0);
      expect(drop.commentsCount, 0);
      expect(drop.hasPropped, isFalse);
      expect(drop.user?.email, '');
    });

    test('DropModel parses nested author avatar field variants', () {
      final json = {
        'id': 'drop_1',
        'user_id': 'user_1',
        'sport_id': 'sport_1',
        'provider': 'cloudinary',
        'provider_asset_id': 'asset_1',
        'public_id': 'forma/skill_clips/drop_1',
        'playback_url': 'https://res.cloudinary.com/demo/video/upload/drop.mp4',
        'duration_seconds': 12.4,
        'format': 'mp4',
        'bytes': 1024,
        'moderation_status': 'approved',
        'visibility': 'public',
        'created_at': '2026-07-03T12:00:00Z',
        'author': {
          'id': 'user_1',
          'username': 'athlete',
          'email': 'athlete@example.com',
          'fullName': 'Athlete One',
          'avatarUrl': 'https://example.com/avatar.jpg',
          'created_at': '2026-07-02T12:00:00Z',
        },
      };

      final drop = DropModel.fromJson(json);

      expect(drop.user?.fullName, 'Athlete One');
      expect(drop.user?.profilePhotoUrl, 'https://example.com/avatar.jpg');
    });
  });
}
