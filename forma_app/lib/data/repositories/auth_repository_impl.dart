import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../api_client.dart';
import '../models/auth_response.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _apiClient;

  AuthRepositoryImpl(this._apiClient);

  @override
  Future<User> signUp({
    required String username,
    required String email,
    required String password,
    required String fullName,
    String role = 'athlete',
  }) async {
    final response = await _apiClient.post(
      '/auth/signup',
      body: {
        'username': username,
        'email': email,
        'password': password,
        'full_name': fullName,
        'role': role,
      },
      authenticated: false,
    );
    final authResponse = AuthResponse.fromJson(
      response as Map<String, dynamic>,
    );
    await _apiClient.saveToken(authResponse.accessToken);
    return authResponse.user;
  }

  @override
  Future<User> login({required String email, required String password}) async {
    final response = await _apiClient.post(
      '/auth/login',
      body: {'email': email, 'password': password},
      authenticated: false,
    );
    final authResponse = AuthResponse.fromJson(
      response as Map<String, dynamic>,
    );
    await _apiClient.saveToken(authResponse.accessToken);
    return authResponse.user;
  }

  @override
  Future<User?> checkAuth() async {
    final token = await _apiClient.getToken();
    if (token == null) {
      return null;
    }

    try {
      final response = await _apiClient.get('/users/me');
      return UserModel.fromJson(response as Map<String, dynamic>);
    } on UnauthenticatedException {
      await _apiClient.deleteToken();
      return null;
    } on ApiException {
      await _apiClient.deleteToken();
      return null;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> healthCheck() async {
    await _apiClient.healthCheck();
  }

  @override
  Future<void> logout() async {
    await _apiClient.deleteToken();
  }

  @override
  Future<String?> getToken() async {
    return await _apiClient.getToken();
  }

  @override
  Future<void> verifyOtp({required String email, required String otp}) async {
    await _apiClient.post(
      '/auth/verify-otp',
      body: {'email': email, 'otp': otp},
      authenticated: false,
    );
  }

  @override
  Future<void> resendOtp({required String email}) async {
    await _apiClient.post(
      '/auth/resend-otp',
      body: {'email': email},
      authenticated: false,
    );
  }

  @override
  Future<void> forgotPassword({required String email}) async {
    await _apiClient.post(
      '/auth/forgot-password',
      body: {'email': email},
      authenticated: false,
    );
  }

  @override
  Future<void> resendPasswordResetOtp({required String email}) async {
    await _apiClient.post(
      '/auth/resend-password-reset-otp',
      body: {'email': email},
      authenticated: false,
    );
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _apiClient.post(
      '/auth/reset-password',
      body: {
        'email': email,
        'otp': otp,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      },
      authenticated: false,
    );
  }
}
