import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/scout_shortlist.dart';
import '../../domain/repositories/scout_repository.dart';

abstract class ScoutShortlistState extends Equatable {
  const ScoutShortlistState();
  @override
  List<Object?> get props => [];
}

class ScoutShortlistInitial extends ScoutShortlistState {}

class ScoutShortlistLoading extends ScoutShortlistState {}

class ScoutShortlistLoaded extends ScoutShortlistState {
  final List<ScoutShortlist> shortlist;
  const ScoutShortlistLoaded(this.shortlist);

  @override
  List<Object?> get props => [shortlist];
}

class ScoutShortlistError extends ScoutShortlistState {
  final String message;
  const ScoutShortlistError(this.message);

  @override
  List<Object?> get props => [message];
}

class ScoutShortlistCubit extends Cubit<ScoutShortlistState> {
  final ScoutRepository _scoutRepository;

  ScoutShortlistCubit(this._scoutRepository) : super(ScoutShortlistInitial());

  Future<void> loadShortlist() async {
    try {
      emit(ScoutShortlistLoading());
      final list = await _scoutRepository.getShortlist();
      emit(ScoutShortlistLoaded(list));
    } catch (e) {
      emit(ScoutShortlistError(e.toString()));
    }
  }

  Future<void> shortlistAthlete(
    String athleteId, {
    String? dropId,
    String? privateNote,
  }) async {
    try {
      emit(ScoutShortlistLoading());
      await _scoutRepository.shortlistAthlete(
        athleteUserId: athleteId,
        dropId: dropId,
        privateNote: privateNote,
      );
      final list = await _scoutRepository.getShortlist();
      emit(ScoutShortlistLoaded(list));
    } catch (e) {
      emit(ScoutShortlistError(e.toString()));
    }
  }

  Future<void> removeShortlist(String athleteId) async {
    try {
      final currentList = state is ScoutShortlistLoaded
          ? (state as ScoutShortlistLoaded).shortlist
          : <ScoutShortlist>[];

      emit(ScoutShortlistLoading());
      await _scoutRepository.removeShortlist(athleteId);
      final updatedList = currentList
          .where((item) => item.athleteUserId != athleteId)
          .toList();
      emit(ScoutShortlistLoaded(updatedList));
    } catch (e) {
      emit(ScoutShortlistError(e.toString()));
    }
  }
}
