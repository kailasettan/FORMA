import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/profile_repository.dart';

abstract class UserSearchState extends Equatable {
  const UserSearchState();
  @override
  List<Object?> get props => [];
}

class UserSearchInitial extends UserSearchState {}

class UserSearchLoading extends UserSearchState {}

class UserSearchLoaded extends UserSearchState {
  final List<User> users;
  const UserSearchLoaded(this.users);

  @override
  List<Object?> get props => [users];
}

class UserSearchError extends UserSearchState {
  final String message;
  const UserSearchError(this.message);

  @override
  List<Object?> get props => [message];
}

class UserSearchCubit extends Cubit<UserSearchState> {
  final ProfileRepository _profileRepository;

  UserSearchCubit(this._profileRepository) : super(UserSearchInitial());

  Future<void> searchUsers(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      emit(UserSearchInitial());
      return;
    }

    try {
      emit(UserSearchLoading());
      final users = await _profileRepository.searchAthletes(trimmed);
      emit(UserSearchLoaded(users));
    } catch (e) {
      emit(UserSearchError(e.toString()));
    }
  }

  void reset() {
    emit(UserSearchInitial());
  }
}
