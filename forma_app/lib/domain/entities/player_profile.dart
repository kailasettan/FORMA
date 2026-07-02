import 'package:equatable/equatable.dart';
import 'sport.dart';

class PlayerProfile extends Equatable {
  final String id;
  final String userId;
  final String sport; // Slug for compatibility (e.g. 'football')
  final String? position; // Legacy field
  final String skillLevel;

  // Phase 5 additions
  final String sportId;
  final String? roleOrDiscipline;
  final Sport? sportDetails;

  const PlayerProfile({
    required this.id,
    required this.userId,
    required this.sport,
    this.position,
    required this.skillLevel,
    required this.sportId,
    this.roleOrDiscipline,
    this.sportDetails,
  });

  @override
  List<Object?> get props => [
    id,
    userId,
    sport,
    position,
    skillLevel,
    sportId,
    roleOrDiscipline,
    sportDetails,
  ];
}
