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
    final userMap = json['user'] as Map<String, dynamic>?;
    final sportMap = json['sport'] as Map<String, dynamic>?;
    final catMap = json['category'] as Map<String, dynamic>?;

    return DropModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      playerProfileId: json['player_profile_id'] as String?,
      sportId: json['sport_id'] as String,
      categoryId: json['category_id'] as String?,
      provider: json['provider'] as String,
      providerAssetId: json['provider_asset_id'] as String,
      publicId: json['public_id'] as String,
      playbackUrl: json['playback_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      caption: json['caption'] as String?,
      durationSeconds: (json['duration_seconds'] as num).toDouble(),
      width: json['width'] as int?,
      height: json['height'] as int?,
      format: json['format'] as String,
      bytes: json['bytes'] as int,
      moderationStatus: json['moderation_status'] as String,
      visibility: json['visibility'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      propsCount: json['props_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      hasPropped: json['has_propped'] as bool? ?? false,
      user: userMap != null ? UserModel.fromJson(userMap) : null,
      sport: sportMap != null ? SportModel.fromJson(sportMap) : null,
      category: catMap != null ? SportCategoryModel.fromJson(catMap) : null,
    );
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
