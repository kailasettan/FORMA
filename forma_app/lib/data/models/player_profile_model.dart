import '../../domain/entities/player_profile.dart';
import 'sport_model.dart';

class PlayerProfileModel extends PlayerProfile {
  const PlayerProfileModel({
    required super.id,
    required super.userId,
    required super.sport,
    super.position,
    required super.skillLevel,
    required super.sportId,
    super.roleOrDiscipline,
    super.sportDetails,
  });

  factory PlayerProfileModel.fromJson(Map<String, dynamic> json) {
    final sportValue = json['sport'];
    final sportMap = sportValue is Map<String, dynamic>
        ? sportValue
        : sportValue is Map
        ? Map<String, dynamic>.from(sportValue)
        : null;
    final sportDetails = sportMap != null
        ? SportModel.fromJson(sportMap)
        : null;

    // Fallback: use nested sport slug if available, otherwise sport_id or empty
    final sportSlug = sportDetails?.slug ?? (json['sport_id'] as String? ?? '');

    return PlayerProfileModel(
      id: _requiredString(json, 'id'),
      userId: _requiredString(json, 'user_id'),
      sport: sportSlug,
      position:
          json['position'] as String? ?? json['role_or_discipline'] as String?,
      skillLevel: _requiredString(json, 'skill_level'),
      sportId: _requiredString(json, 'sport_id'),
      roleOrDiscipline:
          json['role_or_discipline'] as String? ?? json['position'] as String?,
      sportDetails: sportDetails,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'sport': sport,
      'position': position,
      'skill_level': skillLevel,
      'sport_id': sportId,
      'role_or_discipline': roleOrDiscipline,
    };
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Player profile response missing required field: $key');
}
