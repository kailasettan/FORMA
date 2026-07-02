import '../entities/user.dart';

abstract class AuthRepository {
  Future<User> signUp({
    required String username,
    required String email,
    required String password,
    required String fullName,
    String role = 'athlete',
  });

  Future<User> login({required String email, required String password});

  Future<User?> checkAuth();

  Future<void> logout();

  Future<String?> getToken();
}
