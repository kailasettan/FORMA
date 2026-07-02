import '../entities/match_stat.dart';
import '../entities/aggregated_stats.dart';

abstract class StatsRepository {
  Future<List<MatchStat>> fetchMatchStats(String userId);

  Future<MatchStat> createMatchStat({
    required String sport,
    required DateTime date,
    required String opponent,
    required Map<String, int> stats,
  });

  Future<void> deleteMatchStat(String statId);

  Future<AggregatedStats> fetchAggregatedStats(String userId, String sport);
}
