import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/drop.dart';
import '../../domain/repositories/drop_repository.dart';

abstract class DropState extends Equatable {
  const DropState();
  @override
  List<Object?> get props => [];
}

class DropInitial extends DropState {}

class DropLoading extends DropState {}

class DropLoaded extends DropState {
  final List<Drop> drops;
  const DropLoaded(this.drops);

  @override
  List<Object?> get props => [drops];
}

class DropError extends DropState {
  final String message;
  const DropError(this.message);

  @override
  List<Object?> get props => [message];
}

class DropCubit extends Cubit<DropState> {
  final DropRepository _dropRepository;

  DropCubit(this._dropRepository) : super(DropInitial());

  Future<void> loadUserDrops(
    String userId, {
    bool preserveCurrent = false,
  }) async {
    try {
      if (!preserveCurrent) {
        emit(DropLoading());
      }
      final drops = await _dropRepository.getUserDrops(userId);
      if (isClosed) return;
      emit(DropLoaded(drops));
    } catch (e) {
      if (isClosed) return;
      emit(DropError(e.toString()));
    }
  }

  void insertDrop(Drop drop) {
    final currentDrops = state is DropLoaded
        ? (state as DropLoaded).drops
        : <Drop>[];
    final withoutDuplicate = currentDrops
        .where((existing) => existing.id != drop.id)
        .toList();
    emit(DropLoaded([drop, ...withoutDuplicate]));
  }

  Future<void> deleteDrop(String dropId, String userId) async {
    try {
      final currentDrops = state is DropLoaded
          ? (state as DropLoaded).drops
          : <Drop>[];
      emit(DropLoading());
      await _dropRepository.deleteDrop(dropId);
      final updatedDrops = currentDrops.where((d) => d.id != dropId).toList();
      if (isClosed) return;
      emit(DropLoaded(updatedDrops));
    } catch (e) {
      if (isClosed) return;
      emit(DropError(e.toString()));
    }
  }
}
