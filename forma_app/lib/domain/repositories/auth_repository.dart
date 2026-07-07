import '../entities/user.dart';
import '../entities/signup_result.dart';

abstract class AuthRepository {
  Future<SignupResult> signUp({
    required String username,
    required String email,
    required String password,
    required String fullName,
    String role = 'athlete',
  });

  Future<User> login({required String identifier, required String password});

  Future<User?> checkAuth();

  Future<void> healthCheck();

  Future<void> logout();

  Future<String?> getToken();

  Future<void> verifyOtp({required String email, required String otp});
  Future<void> resendOtp({required String email});
  Future<void> forgotPassword({required String email});
  Future<void> resendPasswordResetOtp({required String email});
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
    required String confirmPassword,
  });
}
