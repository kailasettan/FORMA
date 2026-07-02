import '../../domain/entities/scout_shortlist.dart';
import 'user_model.dart';

class ScoutShortlistModel extends ScoutShortlist {
  const ScoutShortlistModel({
    required super.id,
    required super.scoutUserId,
    required super.athleteUserId,
    super.dropId,
    super.privateNote,
    required super.createdAt,
    super.athlete,
  });

  factory ScoutShortlistModel.fromJson(Map<String, dynamic> json) {
    final athleteMap = json['athlete'] as Map<String, dynamic>?;
    return ScoutShortlistModel(
      id: json['id'] as String,
      scoutUserId: json['scout_user_id'] as String,
      athleteUserId: json['athlete_user_id'] as String,
      dropId: json['drop_id'] as String?,
      privateNote: json['private_note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      athlete: athleteMap != null ? UserModel.fromJson(athleteMap) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scout_user_id': scoutUserId,
      'athlete_user_id': athleteUserId,
      'drop_id': dropId,
      'private_note': privateNote,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
