import 'package:flutter/foundation.dart';
import '../../domain/entities/drop.dart';
import 'user_model.dart';
import 'sport_model.dart';
import 'sport_category_model.dart';

class DropModel extends Drop {
  const DropModel({
    required super.id,
    required super.userId,
    super.playerProfileId,
    required super.sportId,
    super.categoryId,
    required super.provider,
    required super.providerAssetId,
    required super.publicId,
    required super.playbackUrl,
    super.thumbnailUrl,
    super.caption,
    required super.durationSeconds,
    super.width,
    super.height,
    required super.format,
    required super.bytes,
    required super.moderationStatus,
    required super.visibility,
    required super.createdAt,
    required super.updatedAt,
    super.propsCount = 0,
    super.commentsCount = 0,
    super.hasPropped = false,
    super.user,
    super.sport,
    super.category,
  });

  factory DropModel.fromJson(Map<String, dynamic> json) {
    try {
      final userMap = _mapOrNull(json['user'] ?? json['athlete']);
      final sportMap = _mapOrNull(json['sport']);
      final catMap = _mapOrNull(json['category']);

      final createdAt = _dateTimeOrNow(json['created_at']);
      return DropModel(
        id: _requiredString(json, 'id'),
        userId: _requiredString(json, 'user_id'),
        playerProfileId: _stringOrNull(json['player_profile_id']),
        sportId: _requiredString(json, 'sport_id'),
        categoryId: _stringOrNull(json['category_id']),
        provider: _stringOrDefault(json['provider'], 'cloudinary'),
        providerAssetId: _requiredString(json, 'provider_asset_id'),
        publicId: _requiredString(json, 'public_id'),
        playbackUrl: _requiredString(json, 'playback_url'),
        thumbnailUrl: _stringOrNull(json['thumbnail_url']),
        caption: _stringOrNull(json['caption']),
        durationSeconds: _doubleOrDefault(json['duration_seconds']),
        width: _intOrNull(json['width']),
        height: _intOrNull(json['height']),
        format: _requiredString(json, 'format'),
        bytes: _intOrDefault(json['bytes']),
        moderationStatus: _stringOrDefault(
          json['moderation_status'],
          'approved',
        ),
        visibility: _stringOrDefault(json['visibility'], 'public'),
        createdAt: createdAt,
        updatedAt: _dateTimeOrDefault(json['updated_at'], createdAt),
        propsCount: _intOrDefault(json['props_count']),
        commentsCount: _intOrDefault(json['comments_count']),
        hasPropped:
            _boolOrDefault(json['has_propped']) ??
            _boolOrDefault(json['current_user_gave_props']) ??
            false,
        user: userMap != null ? UserModel.fromJson(userMap) : null,
        sport: sportMap != null ? SportModel.fromJson(sportMap) : null,
        category: catMap != null ? SportCategoryModel.fromJson(catMap) : null,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[DropModel] parse failed: ${error.runtimeType}: $error '
          'keys=${json.keys.toList()}',
        );
      }
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'player_profile_id': playerProfileId,
      'sport_id': sportId,
      'category_id': categoryId,
      'provider': provider,
      'provider_asset_id': providerAssetId,
      'public_id': publicId,
      'playback_url': playbackUrl,
      'thumbnail_url': thumbnailUrl,
      'caption': caption,
      'duration_seconds': durationSeconds,
      'width': width,
      'height': height,
      'format': format,
      'bytes': bytes,
      'moderation_status': moderationStatus,
      'visibility': visibility,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'props_count': propsCount,
      'comments_count': commentsCount,
      'has_propped': hasPropped,
    };
  }
}

Map<String, dynamic>? _mapOrNull(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Drop response missing required field: $key');
}

String _stringOrDefault(Object? value, String fallback) {
  if (value is String && value.isNotEmpty) return value;
  return fallback;
}

String? _stringOrNull(Object? value) {
  if (value is String && value.isNotEmpty) return value;
  return null;
}

int _intOrDefault(Object? value, [int fallback = 0]) {
  return _intOrNull(value) ?? fallback;
}

int? _intOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double _doubleOrDefault(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

bool? _boolOrDefault(Object? value) {
  if (value is bool) return value;
  return null;
}

DateTime _dateTimeOrNow(Object? value) {
  return _dateTimeOrDefault(value, DateTime.now().toUtc());
}

DateTime _dateTimeOrDefault(Object? value, DateTime fallback) {
  if (value is String) {
    return DateTime.tryParse(value) ?? fallback;
  }
  return fallback;
}
