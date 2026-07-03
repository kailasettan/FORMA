import '../../domain/entities/scout_shortlist.dart';
import '../../domain/repositories/scout_repository.dart';
import '../api_client.dart';
import '../models/scout_shortlist_model.dart';

class ScoutRepositoryImpl implements ScoutRepository {
  final ApiClient _apiClient;

  ScoutRepositoryImpl(this._apiClient);

  @override
  Future<ScoutShortlist> shortlistAthlete({
    required String athleteUserId,
    String? dropId,
    String? privateNote,
  }) async {
    final payload = {
      'athlete_user_id': athleteUserId,
      'drop_id': dropId,
      'private_note': privateNote,
    };
    final response = await _apiClient.post(
      '/scout/shortlist/$athleteUserId',
      body: payload,
    );
    return ScoutShortlistModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<void> removeShortlist(String athleteUserId) async {
    await _apiClient.delete('/scout/shortlist/$athleteUserId');
  }

  @override
  Future<List<ScoutShortlist>> getShortlist() async {
    final response = await _apiClient.get('/scout/shortlist');
    if (response is List) {
      return response
          .map(
            (json) =>
                ScoutShortlistModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    }
    return [];
  }
}
