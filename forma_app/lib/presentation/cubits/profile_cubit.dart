import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/player_profile.dart';
import '../../domain/repositories/profile_repository.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final List<PlayerProfile> profiles;
  const ProfileLoaded(this.profiles);

  @override
  List<Object?> get props => [profiles];
}

class ProfileSubmitting extends ProfileState {}

class ProfileSuccess extends ProfileState {}

class ProfileError extends ProfileState {
  final String message;
  const ProfileError(this.message);

  @override
  List<Object?> get props => [message];
}

class ProfileCubit extends Cubit<ProfileState> {
  final ProfileRepository _profileRepository;

  ProfileCubit(this._profileRepository) : super(ProfileInitial());

  Future<void> loadProfiles(String userId) async {
    emit(ProfileLoading());
    try {
      final profiles = await _profileRepository.fetchPlayerProfiles(userId);
      emit(ProfileLoaded(profiles));
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }

  Future<void> createProfile({
    required String sport, // maps to sportId
    String? position, // maps to roleOrDiscipline
    required String skillLevel,
    required String userId,
  }) async {
    emit(ProfileSubmitting());
    try {
      await _profileRepository.createPlayerProfile(
        sportId: sport,
        roleOrDiscipline: position,
        skillLevel: skillLevel,
      );
      emit(ProfileSuccess());
      // Reload profile list
      await loadProfiles(userId);
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }

  Future<void> updateProfile({
    required String profileId,
    String? position, // maps to roleOrDiscipline
    String? skillLevel,
    required String userId,
  }) async {
    emit(ProfileSubmitting());
    try {
      await _profileRepository.updatePlayerProfile(
        profileId,
        roleOrDiscipline: position,
        skillLevel: skillLevel,
      );
      emit(ProfileSuccess());
      // Reload profile list
      await loadProfiles(userId);
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }

  Future<bool> deleteProfile({
    required String profileId,
    required String userId,
  }) async {
    emit(ProfileSubmitting());
    try {
      await _profileRepository.deletePlayerProfile(profileId);
      emit(ProfileSuccess());
      await loadProfiles(userId);
      return true;
    } catch (e) {
      emit(ProfileError(e.toString()));
      return false;
    }
  }
}
