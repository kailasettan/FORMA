import '../../domain/entities/match_stat.dart';
import '../../domain/entities/aggregated_stats.dart';
import '../../domain/repositories/stats_repository.dart';
import '../api_client.dart';
import '../models/match_stat_model.dart';
import '../models/aggregated_stats_model.dart';

class StatsRepositoryImpl implements StatsRepository {
  final ApiClient _apiClient;

  StatsRepositoryImpl(this._apiClient);

  @override
  Future<List<MatchStat>> fetchMatchStats(String userId) async {
    final response = await _apiClient.get('/users/$userId/match-stats');
    if (response is List) {
      return response
          .map((item) => MatchStatModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  @override
  Future<MatchStat> createMatchStat({
    required String sport,
    required DateTime date,
    required String opponent,
    required Map<String, int> stats,
  }) async {
    final dateString =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final response = await _apiClient.post(
      '/match-stats',
      body: {
        'sport': sport,
        'date': dateString,
        'opponent': opponent,
        'stats': stats,
      },
    );
    return MatchStatModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<void> deleteMatchStat(String statId) async {
    await _apiClient.delete('/match-stats/$statId');
  }

  @override
  Future<AggregatedStats> fetchAggregatedStats(
    String userId,
    String sport,
  ) async {
    final response = await _apiClient.get(
      '/users/$userId/match-stats/aggregate?sport=$sport',
    );
    return AggregatedStatsModel.fromJson(response as Map<String, dynamic>);
  }
}
