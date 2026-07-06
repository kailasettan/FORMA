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
    var currentField = '<start>';
    try {
      T parseField<T>(String field, T Function(Object? value) parse) {
        currentField = field;
        final value = json[field];
        _debugDropField(json, field, value == null);
        try {
          return parse(value);
        } catch (error) {
          _debugDropField(
            json,
            field,
            value == null,
            exceptionType: error.runtimeType.toString(),
          );
          rethrow;
        }
      }

      currentField = 'user';
      // Drops feed/detail responses should include one nested author object with
      // profile_photo_url/profilePhotoUrl/avatar_url/avatarUrl for avatar UI.
      final rawUser = json['user'] ?? json['author'] ?? json['athlete'];
      _debugDropField(json, 'user', rawUser == null);
      final userMap = _mapOrNull(rawUser);
      final sportMap = parseField('sport', _mapOrNull);
      final catMap = parseField('category', _mapOrNull);

      final createdAt = parseField('created_at', _dateTimeOrNow);
      return DropModel(
        id: parseField('id', (value) => _requiredString(json, 'id')),
        userId: parseField(
          'user_id',
          (value) => _requiredString(json, 'user_id'),
        ),
        playerProfileId: parseField('player_profile_id', _stringOrNull),
        sportId: parseField(
          'sport_id',
          (value) => _requiredString(json, 'sport_id'),
        ),
        categoryId: parseField('category_id', _stringOrNull),
        provider: parseField(
          'provider',
          (value) => _requiredString(json, 'provider'),
        ),
        providerAssetId: parseField(
          'provider_asset_id',
          (value) => _requiredString(json, 'provider_asset_id'),
        ),
        publicId: parseField(
          'public_id',
          (value) => _requiredString(json, 'public_id'),
        ),
        playbackUrl: parseField(
          'playback_url',
          (value) => _requiredString(json, 'playback_url'),
        ),
        thumbnailUrl: parseField('thumbnail_url', _stringOrNull),
        caption: parseField('caption', _stringOrNull),
        durationSeconds: parseField('duration_seconds', _doubleOrDefault),
        width: parseField('width', _intOrNull),
        height: parseField('height', _intOrNull),
        format: parseField(
          'format',
          (value) => _requiredString(json, 'format'),
        ),
        bytes: parseField('bytes', _intOrDefault),
        moderationStatus: parseField(
          'moderation_status',
          (value) => _stringOrDefault(value, 'approved'),
        ),
        visibility: parseField(
          'visibility',
          (value) => _stringOrDefault(value, 'public'),
        ),
        createdAt: createdAt,
        updatedAt: parseField(
          'updated_at',
          (value) => _dateTimeOrDefault(value, createdAt),
        ),
        propsCount: parseField('props_count', _intOrDefault),
        commentsCount: parseField('comments_count', _intOrDefault),
        hasPropped:
            parseField('has_propped', _boolOrDefault) ??
            parseField('current_user_gave_props', _boolOrDefault) ??
            false,
        user: userMap != null
            ? parseField('user', (value) => UserModel.fromJson(userMap))
            : null,
        sport: sportMap != null
            ? parseField('sport', (value) => SportModel.fromJson(sportMap))
            : null,
        category: catMap != null
            ? parseField(
                'category',
                (value) => SportCategoryModel.fromJson(catMap),
              )
            : null,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[DropModel] model=DropModel keys=${json.keys.toList()} '
          'field=$currentField isNull=${json[currentField] == null} '
          'exception=${error.runtimeType}',
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

void _debugDropField(
  Map<String, dynamic> json,
  String field,
  bool isNull, {
  String exceptionType = 'none',
}) {
  if (!kDebugMode) return;
  debugPrint(
    '[DropModel] model=DropModel keys=${json.keys.toList()} '
    'field=$field isNull=$isNull exception=$exceptionType',
  );
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
