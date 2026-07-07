import 'user_model.dart';

class AuthResponse {
  final String accessToken;
  final String tokenType;
  final UserModel user;
  final bool verificationRequired;

  const AuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.user,
    this.verificationRequired = false,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      verificationRequired: json['verification_required'] as bool? ?? false,
    );
  }
}
