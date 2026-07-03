import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/public_athlete_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/repositories/drop_repository.dart';
import '../../domain/repositories/scout_repository.dart';

abstract class PublicProfileState extends Equatable {
  const PublicProfileState();
  @override
  List<Object?> get props => [];
}

class PublicProfileInitial extends PublicProfileState {}

class PublicProfileLoading extends PublicProfileState {}

class PublicProfileLoaded extends PublicProfileState {
  final PublicAthleteProfile profile;
  const PublicProfileLoaded(this.profile);

  @override
  List<Object?> get props => [profile];
}

class PublicProfileError extends PublicProfileState {
  final String message;
  const PublicProfileError(this.message);

  @override
  List<Object?> get props => [message];
}

class PublicProfileCubit extends Cubit<PublicProfileState> {
  final ProfileRepository _profileRepository;
  final DropRepository _dropRepository;
  final ScoutRepository _scoutRepository;

  bool _isTogglingProp = false;

  PublicProfileCubit(
    this._profileRepository,
    this._dropRepository,
    this._scoutRepository,
  ) : super(PublicProfileInitial());

  Future<void> loadProfile(String userId) async {
    try {
      emit(PublicProfileLoading());
      final profile = await _profileRepository.fetchPublicAthleteProfile(
        userId,
      );
      emit(PublicProfileLoaded(profile));
    } catch (e) {
      emit(PublicProfileError(e.toString()));
    }
  }

  Future<void> loadProfileByUsername(String username) async {
    try {
      emit(PublicProfileLoading());
      final profile = await _profileRepository
          .fetchPublicAthleteProfileByUsername(username);
      emit(PublicProfileLoaded(profile));
    } catch (e) {
      emit(PublicProfileError(e.toString()));
    }
  }

  Future<void> toggleShortlist(
    String athleteUserId, {
    String? dropId,
    String? privateNote,
  }) async {
    if (state is! PublicProfileLoaded) return;
    final currentState = state as PublicProfileLoaded;
    final profile = currentState.profile;

    try {
      // Toggle shortlist
      if (profile.isShortlisted) {
        await _scoutRepository.removeShortlist(athleteUserId);
        final updatedProfile = PublicAthleteProfile(
          user: profile.user,
          playerProfiles: profile.playerProfiles,
          drops: profile.drops,
          isShortlisted: false,
          profileCompletionPercentage: profile.profileCompletionPercentage,
        );
        emit(PublicProfileLoaded(updatedProfile));
      } else {
        await _scoutRepository.shortlistAthlete(
          athleteUserId: athleteUserId,
          dropId: dropId,
          privateNote: privateNote,
        );
        final updatedProfile = PublicAthleteProfile(
          user: profile.user,
          playerProfiles: profile.playerProfiles,
          drops: profile.drops,
          isShortlisted: true,
          profileCompletionPercentage: profile.profileCompletionPercentage,
        );
        emit(PublicProfileLoaded(updatedProfile));
      }
    } catch (e) {
      // Emit error temporarily, then restore loaded state
      final currentMsg = e.toString();
      emit(PublicProfileError(currentMsg));
      emit(PublicProfileLoaded(profile));
    }
  }

  Future<void> togglePropOnDrop(String dropId) async {
    if (state is! PublicProfileLoaded || _isTogglingProp) return;
    _isTogglingProp = true;

    final currentState = state as PublicProfileLoaded;
    final profile = currentState.profile;

    // Find the drop
    final dropIndex = profile.drops.indexWhere((d) => d.id == dropId);
    if (dropIndex == -1) {
      _isTogglingProp = false;
      return;
    }

    final originalDrop = profile.drops[dropIndex];
    final bool wasPropped = originalDrop.hasPropped;
    final int newPropsCount = wasPropped
        ? (originalDrop.propsCount - 1).clamp(0, 999999)
        : originalDrop.propsCount + 1;

    // Optimistic Drop Update
    final updatedDrop = originalDrop.copyWith(
      hasPropped: !wasPropped,
      propsCount: newPropsCount,
    );

    final updatedDrops = List<dynamic>.from(profile.drops);
    updatedDrops[dropIndex] = updatedDrop;

    final optimisticProfile = PublicAthleteProfile(
      user: profile.user,
      playerProfiles: profile.playerProfiles,
      drops: List.from(updatedDrops),
      isShortlisted: profile.isShortlisted,
      profileCompletionPercentage: profile.profileCompletionPercentage,
    );

    // Emit optimistic state
    emit(PublicProfileLoaded(optimisticProfile));

    try {
      if (wasPropped) {
        await _dropRepository.removeProps(dropId);
      } else {
        await _dropRepository.giveProps(dropId);
      }
      _isTogglingProp = false;
    } catch (e) {
      // Rollback on failure
      final rollbackDrops = List<dynamic>.from(profile.drops);
      rollbackDrops[dropIndex] = originalDrop;

      final rollbackProfile = PublicAthleteProfile(
        user: profile.user,
        playerProfiles: profile.playerProfiles,
        drops: List.from(rollbackDrops),
        isShortlisted: profile.isShortlisted,
        profileCompletionPercentage: profile.profileCompletionPercentage,
      );

      emit(PublicProfileLoaded(rollbackProfile));
      _isTogglingProp = false;
    }
  }
}
