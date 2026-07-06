import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final int? age;
  final String? city;
  final String? profilePhotoUrl;
  final DateTime createdAt;

  // Phase 5 additions
  final String? headline;
  final String? bio;
  final String? location;
  final String? availability;
  final List<String>? preferredOpportunityTypes;
  final String role;
  final String? focusedSportId;
  final bool emailVerified;

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    this.age,
    this.city,
    this.profilePhotoUrl,
    required this.createdAt,
    this.headline,
    this.bio,
    this.location,
    this.availability,
    this.preferredOpportunityTypes,
    this.role = 'athlete',
    this.focusedSportId,
    this.emailVerified = false,
  });

  @override
  List<Object?> get props => [
    id,
    username,
    email,
    fullName,
    age,
    city,
    profilePhotoUrl,
    createdAt,
    headline,
    bio,
    location,
    availability,
    preferredOpportunityTypes,
    role,
    focusedSportId,
    emailVerified,
  ];
}
