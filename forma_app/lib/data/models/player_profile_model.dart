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
    final sportMap = json['sport'] as Map<String, dynamic>?;
    final sportDetails = sportMap != null ? SportModel.fromJson(sportMap) : null;
    
    // Fallback: use nested sport slug if available, otherwise sport_id or empty
    final sportSlug = sportDetails?.slug ?? (json['sport_id'] as String? ?? '');

    return PlayerProfileModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      sport: sportSlug,
      position: json['position'] as String? ?? json['role_or_discipline'] as String?,
      skillLevel: json['skill_level'] as String,
      sportId: json['sport_id'] as String,
      roleOrDiscipline: json['role_or_discipline'] as String? ?? json['position'] as String?,
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
