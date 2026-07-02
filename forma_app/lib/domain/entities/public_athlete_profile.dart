import 'package:equatable/equatable.dart';
import 'user.dart';
import 'player_profile.dart';
import 'drop.dart';

class PublicAthleteProfile extends Equatable {
  final User user;
  final List<PlayerProfile> playerProfiles;
  final List<Drop> drops;
  final bool isShortlisted;
  final int profileCompletionPercentage;

  const PublicAthleteProfile({
    required this.user,
    required this.playerProfiles,
    required this.drops,
    required this.isShortlisted,
    required this.profileCompletionPercentage,
  });

  @override
  List<Object?> get props => [
    user,
    playerProfiles,
    drops,
    isShortlisted,
    profileCompletionPercentage,
  ];
}
