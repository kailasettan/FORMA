import 'package:equatable/equatable.dart';

import 'user.dart';

class SignupResult extends Equatable {
  final User user;
  final bool verificationRequired;

  const SignupResult({required this.user, required this.verificationRequired});

  @override
  List<Object?> get props => [user, verificationRequired];
}
