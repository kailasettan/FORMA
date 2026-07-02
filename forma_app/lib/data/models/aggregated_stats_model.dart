import '../../domain/entities/aggregated_stats.dart';

class AggregatedStatsModel extends AggregatedStats {
  const AggregatedStatsModel({
    required super.matchesPlayed,
    required super.stats,
  });

  factory AggregatedStatsModel.fromJson(Map<String, dynamic> json) {
    final matchesPlayed = json['matches_played'] as int? ?? 0;

    final Map<String, int> statsMap = {};
    json.forEach((key, value) {
      if (key != 'matches_played' && value is num) {
        statsMap[key] = value.toInt();
      }
    });

    return AggregatedStatsModel(matchesPlayed: matchesPlayed, stats: statsMap);
  }
}
