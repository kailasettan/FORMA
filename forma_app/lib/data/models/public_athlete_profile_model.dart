import '../../domain/entities/public_athlete_profile.dart';
import 'user_model.dart';
import 'player_profile_model.dart';
import 'drop_model.dart';

class PublicAthleteProfileModel extends PublicAthleteProfile {
  const PublicAthleteProfileModel({
    required super.user,
    required super.playerProfiles,
    required super.drops,
    required super.isShortlisted,
    required super.profileCompletionPercentage,
  });

  factory PublicAthleteProfileModel.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] as Map<String, dynamic>;
    final profilesList = json['player_profiles'] as List;
    final dropsList = json['drops'] as List;

    return PublicAthleteProfileModel(
      user: UserModel.fromJson(userMap),
      playerProfiles: profilesList
          .map((p) => PlayerProfileModel.fromJson(p as Map<String, dynamic>))
          .toList(),
      drops: dropsList
          .map((d) => DropModel.fromJson(d as Map<String, dynamic>))
          .toList(),
      isShortlisted: json['is_shortlisted'] as bool? ?? false,
      profileCompletionPercentage:
          json['profile_completion_percentage'] as int? ?? 0,
    );
  }
}
