import 'package:equatable/equatable.dart';

class MatchStat extends Equatable {
  final String id;
  final String userId;
  final String sport;
  final DateTime date;
  final String opponent;
  final Map<String, int> stats;
  final DateTime createdAt;

  const MatchStat({
    required this.id,
    required this.userId,
    required this.sport,
    required this.date,
    required this.opponent,
    required this.stats,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    userId,
    sport,
    date,
    opponent,
    stats,
    createdAt,
  ];
}
