import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/match_stat.dart';
import '../../domain/entities/aggregated_stats.dart';
import '../../domain/repositories/stats_repository.dart';

abstract class StatsState extends Equatable {
  const StatsState();

  @override
  List<Object?> get props => [];
}

class StatsInitial extends StatsState {}

class StatsLoading extends StatsState {}

class StatsLoaded extends StatsState {
  final List<MatchStat> matches;
  final AggregatedStats aggregated;

  const StatsLoaded({required this.matches, required this.aggregated});

  @override
  List<Object?> get props => [matches, aggregated];
}

class StatsSubmitting extends StatsState {}

class StatsSuccess extends StatsState {}

class StatsError extends StatsState {
  final String message;
  const StatsError(this.message);

  @override
  List<Object?> get props => [message];
}

class StatsCubit extends Cubit<StatsState> {
  final StatsRepository _statsRepository;

  StatsCubit(this._statsRepository) : super(StatsInitial());

  Future<void> loadStatsAndAggregate({
    required String userId,
    required String sport,
  }) async {
    emit(StatsLoading());
    try {
      final matchesFuture = _statsRepository.fetchMatchStats(userId);
      final aggregatedFuture = _statsRepository.fetchAggregatedStats(
        userId,
        sport,
      );

      final results = await Future.wait([matchesFuture, aggregatedFuture]);

      final List<MatchStat> matches = results[0] as List<MatchStat>;
      final AggregatedStats aggregated = results[1] as AggregatedStats;

      emit(
        StatsLoaded(
          matches: matches.where((m) => m.sport == sport).toList(),
          aggregated: aggregated,
        ),
      );
    } catch (e) {
      emit(StatsError(e.toString()));
    }
  }

  Future<void> addMatchStat({
    required String sport,
    required DateTime date,
    required String opponent,
    required Map<String, int> stats,
    required String userId,
  }) async {
    emit(StatsSubmitting());
    try {
      await _statsRepository.createMatchStat(
        sport: sport,
        date: date,
        opponent: opponent,
        stats: stats,
      );
      emit(StatsSuccess());
      await loadStatsAndAggregate(userId: userId, sport: sport);
    } catch (e) {
      emit(StatsError(e.toString()));
    }
  }

  Future<void> deleteMatchStat({
    required String statId,
    required String userId,
    required String sport,
  }) async {
    emit(StatsSubmitting());
    try {
      await _statsRepository.deleteMatchStat(statId);
      emit(StatsSuccess());
      await loadStatsAndAggregate(userId: userId, sport: sport);
    } catch (e) {
      emit(StatsError(e.toString()));
    }
  }
}
