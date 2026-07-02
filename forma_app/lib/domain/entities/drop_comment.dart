import 'package:equatable/equatable.dart';
import 'user.dart';

class DropComment extends Equatable {
  final String id;
  final String dropId;
  final String userId;
  final String body;
  final DateTime createdAt;
  final User? user;

  const DropComment({
    required this.id,
    required this.dropId,
    required this.userId,
    required this.body,
    required this.createdAt,
    this.user,
  });

  @override
  List<Object?> get props => [id, dropId, userId, body, createdAt, user];
}
