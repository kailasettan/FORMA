import 'package:equatable/equatable.dart';
import 'user.dart';
import 'sport.dart';
import 'sport_category.dart';

class Drop extends Equatable {
  final String id;
  final String userId;
  final String? playerProfileId;
  final String sportId;
  final String? categoryId;
  final String provider;
  final String providerAssetId;
  final String publicId;
  final String playbackUrl;
  final String? thumbnailUrl;
  final String? caption;
  final double durationSeconds;
  final int? width;
  final int? height;
  final String format;
  final int bytes;
  final String moderationStatus;
  final String visibility;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Rich metadata populated by backend endpoints
  final int propsCount;
  final int commentsCount;
  final bool hasPropped;
  final User? user;
  final Sport? sport;
  final SportCategory? category;

  const Drop({
    required this.id,
    required this.userId,
    this.playerProfileId,
    required this.sportId,
    this.categoryId,
    required this.provider,
    required this.providerAssetId,
    required this.publicId,
    required this.playbackUrl,
    this.thumbnailUrl,
    this.caption,
    required this.durationSeconds,
    this.width,
    this.height,
    required this.format,
    required this.bytes,
    required this.moderationStatus,
    required this.visibility,
    required this.createdAt,
    required this.updatedAt,
    this.propsCount = 0,
    this.commentsCount = 0,
    this.hasPropped = false,
    this.user,
    this.sport,
    this.category,
  });

  @override
  List<Object?> get props => [
    id,
    userId,
    playerProfileId,
    sportId,
    categoryId,
    provider,
    providerAssetId,
    publicId,
    playbackUrl,
    thumbnailUrl,
    caption,
    durationSeconds,
    width,
    height,
    format,
    bytes,
    moderationStatus,
    visibility,
    createdAt,
    updatedAt,
    propsCount,
    commentsCount,
    hasPropped,
    user,
    sport,
    category,
  ];

  Drop copyWith({
    int? propsCount,
    int? commentsCount,
    bool? hasPropped,
  }) {
    return Drop(
      id: id,
      userId: userId,
      playerProfileId: playerProfileId,
      sportId: sportId,
      categoryId: categoryId,
      provider: provider,
      providerAssetId: providerAssetId,
      publicId: publicId,
      playbackUrl: playbackUrl,
      thumbnailUrl: thumbnailUrl,
      caption: caption,
      durationSeconds: durationSeconds,
      width: width,
      height: height,
      format: format,
      bytes: bytes,
      moderationStatus: moderationStatus,
      visibility: visibility,
      createdAt: createdAt,
      updatedAt: updatedAt,
      propsCount: propsCount ?? this.propsCount,
      commentsCount: commentsCount ?? this.commentsCount,
      hasPropped: hasPropped ?? this.hasPropped,
      user: user,
      sport: sport,
      category: category,
    );
  }
}
