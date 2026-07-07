import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/drop.dart';
import '../../domain/repositories/drop_repository.dart';

class DropFeedState extends Equatable {
  final List<Drop> drops;
  final String? nextCursor;
  final String? selectedSportId;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final Set<String> togglingPropIds;
  // True once loadInitial() has been called at least once. Lets the UI
  // distinguish "never started" from "started but empty" so the auth listener
  // can safely re-trigger a load without causing duplicate requests.
  final bool hasAttemptedLoad;

  const DropFeedState({
    this.drops = const [],
    this.nextCursor,
    this.selectedSportId,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.togglingPropIds = const {},
    this.hasAttemptedLoad = false,
  });

  bool get hasMore => nextCursor != null;

  DropFeedState copyWith({
    List<Drop>? drops,
    Object? nextCursor = _sentinel,
    Object? selectedSportId = _sentinel,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error = _sentinel,
    Set<String>? togglingPropIds,
    bool? hasAttemptedLoad,
  }) {
    return DropFeedState(
      drops: drops ?? this.drops,
      nextCursor: identical(nextCursor, _sentinel)
          ? this.nextCursor
          : nextCursor as String?,
      selectedSportId: identical(selectedSportId, _sentinel)
          ? this.selectedSportId
          : selectedSportId as String?,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: identical(error, _sentinel) ? this.error : error as String?,
      togglingPropIds: togglingPropIds ?? this.togglingPropIds,
      hasAttemptedLoad: hasAttemptedLoad ?? this.hasAttemptedLoad,
    );
  }

  @override
  List<Object?> get props => [
    drops,
    nextCursor,
    selectedSportId,
    isLoading,
    isLoadingMore,
    error,
    togglingPropIds,
    hasAttemptedLoad,
  ];
}

const Object _sentinel = Object();

class DropFeedCubit extends Cubit<DropFeedState> {
  final DropRepository _dropRepository;

  DropFeedCubit(this._dropRepository) : super(const DropFeedState());

  Future<void> loadInitial({String? sportId}) async {
    emit(
      state.copyWith(
        isLoading: true,
        error: null,
        selectedSportId: sportId,
        nextCursor: null,
        hasAttemptedLoad: true,
      ),
    );
    try {
      final page = await _dropRepository.getDropsFeed(sportId: sportId);
      if (isClosed) return;
      emit(
        state.copyWith(
          drops: page.items,
          nextCursor: page.nextCursor,
          isLoading: false,
          error: null,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> refreshCurrent() async {
    try {
      final page = await _dropRepository.getDropsFeed(
        sportId: state.selectedSportId,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          drops: page.items,
          nextCursor: page.nextCursor,
          isLoading: false,
          error: null,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void insertDropIfVisible(Drop drop) {
    if (drop.visibility != 'public' || drop.moderationStatus != 'approved') {
      return;
    }
    if (state.selectedSportId != null &&
        state.selectedSportId != drop.sportId) {
      return;
    }
    final withoutDuplicate = state.drops
        .where((existing) => existing.id != drop.id)
        .toList();
    emit(state.copyWith(drops: [drop, ...withoutDuplicate], error: null));
  }

  void insertNewlyCreatedDrop(Drop drop) {
    if (drop.visibility != 'public' || drop.moderationStatus != 'approved') {
      return;
    }
    final withoutDuplicate = state.drops
        .where((existing) => existing.id != drop.id)
        .toList();
    emit(
      state.copyWith(
        drops: [drop, ...withoutDuplicate],
        selectedSportId: null,
        error: null,
      ),
    );
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    emit(state.copyWith(isLoadingMore: true, error: null));
    try {
      final page = await _dropRepository.getDropsFeed(
        cursor: state.nextCursor,
        sportId: state.selectedSportId,
      );
      if (isClosed) return;
      final seenIds = state.drops.map((drop) => drop.id).toSet();
      final newItems = page.items.where((drop) => !seenIds.contains(drop.id));
      emit(
        state.copyWith(
          drops: [...state.drops, ...newItems],
          nextCursor: page.nextCursor,
          isLoadingMore: false,
          error: null,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(isLoadingMore: false, error: e.toString()));
    }
  }

  Future<void> toggleProps(String dropId) async {
    if (state.togglingPropIds.contains(dropId)) return;
    final index = state.drops.indexWhere((drop) => drop.id == dropId);
    if (index == -1) return;

    final original = state.drops[index];
    final updated = original.copyWith(
      hasPropped: !original.hasPropped,
      propsCount: original.hasPropped
          ? (original.propsCount - 1).clamp(0, 999999)
          : original.propsCount + 1,
    );
    final optimisticDrops = List<Drop>.from(state.drops)..[index] = updated;
    emit(
      state.copyWith(
        drops: optimisticDrops,
        togglingPropIds: {...state.togglingPropIds, dropId},
      ),
    );

    try {
      if (original.hasPropped) {
        await _dropRepository.removeProps(dropId);
      } else {
        await _dropRepository.giveProps(dropId);
      }
      if (isClosed) return;
      final toggling = {...state.togglingPropIds}..remove(dropId);
      emit(state.copyWith(togglingPropIds: toggling));
    } catch (e) {
      if (isClosed) return;
      final rollbackDrops = List<Drop>.from(state.drops);
      final rollbackIndex = rollbackDrops.indexWhere(
        (drop) => drop.id == dropId,
      );
      if (rollbackIndex != -1) {
        rollbackDrops[rollbackIndex] = original;
      }
      final toggling = {...state.togglingPropIds}..remove(dropId);
      emit(
        state.copyWith(
          drops: rollbackDrops,
          togglingPropIds: toggling,
          error: e.toString(),
        ),
      );
    }
  }

  void updateCommentCount(String dropId, int count) {
    final index = state.drops.indexWhere((drop) => drop.id == dropId);
    if (index == -1) return;
    final updatedDrops = List<Drop>.from(state.drops)
      ..[index] = state.drops[index].copyWith(commentsCount: count);
    emit(state.copyWith(drops: updatedDrops));
  }
}
