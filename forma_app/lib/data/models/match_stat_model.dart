import '../../domain/entities/match_stat.dart';

class MatchStatModel extends MatchStat {
  const MatchStatModel({
    required super.id,
    required super.userId,
    required super.sport,
    required super.date,
    required super.opponent,
    required super.stats,
    required super.createdAt,
  });

  factory MatchStatModel.fromJson(Map<String, dynamic> json) {
    // stats is returned as a Map<String, dynamic> from JSON, convert it to Map<String, int>
    final rawStats = json['stats'] as Map<String, dynamic>? ?? {};
    final Map<String, int> parsedStats = rawStats.map(
      (key, value) => MapEntry(key, value as int),
    );

    return MatchStatModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      sport: json['sport'] as String,
      date: DateTime.parse(json['date'] as String),
      opponent: json['opponent'] as String,
      stats: parsedStats,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'sport': sport,
      'date':
          "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
      'opponent': opponent,
      'stats': stats,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
