import '../entities/player_profile.dart';
import '../entities/user.dart';
import '../entities/public_athlete_profile.dart';

abstract class ProfileRepository {
  Future<List<PlayerProfile>> fetchPlayerProfiles(String userId);

  Future<PlayerProfile> createPlayerProfile({
    required String sportId,
    String? roleOrDiscipline,
    required String skillLevel,
  });

  Future<PlayerProfile> updatePlayerProfile(
    String profileId, {
    String? roleOrDiscipline,
    String? skillLevel,
  });

  Future<User> updateMe({
    String? username,
    String? fullName,
    int? age,
    String? city,
    String? profilePhotoUrl,
    String? headline,
    String? bio,
    String? location,
    String? availability,
    List<String>? preferredOpportunityTypes,
    String? focusedSportId,
  });

  Future<PublicAthleteProfile> fetchPublicAthleteProfile(String userId);
  Future<PublicAthleteProfile> fetchPublicAthleteProfileByUsername(String username);
  Future<List<User>> searchAthletes(String query);
}
