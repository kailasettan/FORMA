import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User user;
  final bool verificationRequired;
  const AuthAuthenticated(this.user, {this.verificationRequired = false});

  @override
  List<Object?> get props => [user, verificationRequired];
}

class AuthUnauthenticated extends AuthState {
  final String? message;
  const AuthUnauthenticated({this.message});

  @override
  List<Object?> get props => [message];
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

class AuthPasswordResetEmailSent extends AuthState {
  final String email;
  final String message;
  const AuthPasswordResetEmailSent(this.email, this.message);

  @override
  List<Object?> get props => [email, message];
}

class AuthPasswordResetSuccess extends AuthState {
  final String message;
  const AuthPasswordResetSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;

  AuthCubit(this._authRepository) : super(AuthInitial());

  Future<void> checkAuth() async {
    emit(AuthLoading());
    try {
      await _authRepository.healthCheck();
      final user = await _authRepository.checkAuth();
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> login(String identifier, String password) async {
    emit(AuthLoading());
    try {
      await _authRepository.healthCheck();
      final user = await _authRepository.login(
        identifier: identifier,
        password: password,
      );
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signUp({
    required String username,
    required String email,
    required String password,
    required String fullName,
    String role = 'athlete',
  }) async {
    emit(AuthLoading());
    try {
      await _authRepository.healthCheck();
      final result = await _authRepository.signUp(
        username: username,
        email: email,
        password: password,
        fullName: fullName,
        role: role,
      );
      emit(
        AuthAuthenticated(
          result.user,
          verificationRequired: result.verificationRequired,
        ),
      );
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> logout() async {
    emit(AuthLoading());
    try {
      await _authRepository.logout();
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(const AuthUnauthenticated());
    }
  }

  void sessionExpired() {
    _authRepository.logout();
    emit(
      const AuthUnauthenticated(
        message: 'Session expired. Please log in again.',
      ),
    );
  }

  void updateCurrentUser(User user) {
    if (state is AuthAuthenticated) {
      emit(AuthAuthenticated(user));
    }
  }

  Future<void> verifyOtp(String email, String otp) async {
    emit(AuthLoading());
    try {
      await _authRepository.verifyOtp(email: email, otp: otp);
      final user = await _authRepository.checkAuth();
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> forgotPassword(String email) async {
    emit(AuthLoading());
    try {
      await _authRepository.forgotPassword(email: email);
      emit(
        AuthPasswordResetEmailSent(
          email,
          'If an account exists, a reset code has been sent.',
        ),
      );
    } catch (_) {
      emit(
        AuthPasswordResetEmailSent(
          email,
          'If an account exists, a reset code has been sent.',
        ),
      );
    }
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
    required String confirmPassword,
  }) async {
    emit(AuthLoading());
    try {
      await _authRepository.resetPassword(
        email: email,
        otp: otp,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      emit(
        const AuthPasswordResetSuccess(
          'Password reset successfully. Please log in.',
        ),
      );
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}
