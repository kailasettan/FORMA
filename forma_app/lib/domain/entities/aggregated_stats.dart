import 'package:equatable/equatable.dart';

class AggregatedStats extends Equatable {
  final int matchesPlayed;
  final Map<String, int> stats;

  const AggregatedStats({required this.matchesPlayed, required this.stats});

  int get goals => stats['goals'] ?? 0;
  int get assists => stats['assists'] ?? 0;
  int get runs => stats['runs'] ?? 0;
  int get wickets => stats['wickets'] ?? 0;
  int get catches => stats['catches'] ?? 0;
  int get points => stats['points'] ?? 0;
  int get rebounds => stats['rebounds'] ?? 0;

  @override
  List<Object?> get props => [matchesPlayed, stats];
}
