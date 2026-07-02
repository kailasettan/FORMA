import '../../domain/entities/player_profile.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/public_athlete_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../api_client.dart';
import '../models/player_profile_model.dart';
import '../models/user_model.dart';
import '../models/public_athlete_profile_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ApiClient _apiClient;

  ProfileRepositoryImpl(this._apiClient);

  @override
  Future<List<PlayerProfile>> fetchPlayerProfiles(String userId) async {
    final response = await _apiClient.get('/users/$userId/player-profiles');
    if (response is List) {
      return response
          .map(
            (item) => PlayerProfileModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }
    return [];
  }

  @override
  Future<PlayerProfile> createPlayerProfile({
    required String sportId,
    String? roleOrDiscipline,
    required String skillLevel,
  }) async {
    final response = await _apiClient.post(
      '/player-profiles',
      body: {
        'sport_id': sportId,
        'role_or_discipline': ?roleOrDiscipline,
        'skill_level': skillLevel,
      },
    );
    return PlayerProfileModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<PlayerProfile> updatePlayerProfile(
    String profileId, {
    String? roleOrDiscipline,
    String? skillLevel,
  }) async {
    final response = await _apiClient.patch(
      '/player-profiles/$profileId',
      body: {
        'role_or_discipline': ?roleOrDiscipline,
        'skill_level': ?skillLevel,
      },
    );
    return PlayerProfileModel.fromJson(response as Map<String, dynamic>);
  }

  @override
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
  }) async {
    final body = {
      'username': ?username,
      'full_name': ?fullName,
      'age': ?age,
      'city': ?city,
      'profile_photo_url': ?profilePhotoUrl,
      'headline': ?headline,
      'bio': ?bio,
      'location': ?location,
      'availability': ?availability,
      'preferred_opportunity_types': ?preferredOpportunityTypes,
      'focused_sport_id': focusedSportId, // always set (can be null)
    };
    final response = await _apiClient.patch('/users/me', body: body);
    return UserModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<PublicAthleteProfile> fetchPublicAthleteProfile(String userId) async {
    final response = await _apiClient.get('/users/$userId/public-profile');
    return PublicAthleteProfileModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<PublicAthleteProfile> fetchPublicAthleteProfileByUsername(String username) async {
    final response = await _apiClient.get('/users/by-username/$username/public-profile');
    return PublicAthleteProfileModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<List<User>> searchAthletes(String query) async {
    final response = await _apiClient.get('/users/search?q=${Uri.encodeQueryComponent(query)}');
    if (response is List) {
      return response.map((item) => UserModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }
}
