import '../../domain/entities/drop_comment.dart';
import 'user_model.dart';

class DropCommentModel extends DropComment {
  const DropCommentModel({
    required super.id,
    required super.dropId,
    required super.userId,
    required super.body,
    required super.createdAt,
    super.user,
  });

  factory DropCommentModel.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] as Map<String, dynamic>?;
    return DropCommentModel(
      id: json['id'] as String,
      dropId: json['drop_id'] as String,
      userId: json['user_id'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      user: userMap != null ? UserModel.fromJson(userMap) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'drop_id': dropId,
      'user_id': userId,
      'body': body,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
