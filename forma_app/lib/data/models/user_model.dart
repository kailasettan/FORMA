import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.username,
    required super.email,
    required super.fullName,
    super.age,
    super.city,
    super.profilePhotoUrl,
    required super.createdAt,
    super.headline,
    super.bio,
    super.location,
    super.availability,
    super.preferredOpportunityTypes,
    super.role = 'athlete',
    super.focusedSportId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      age: json['age'] as int?,
      city: json['city'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      headline: json['headline'] as String?,
      bio: json['bio'] as String?,
      location: json['location'] as String?,
      availability: json['availability'] as String?,
      preferredOpportunityTypes: json['preferred_opportunity_types'] != null
          ? List<String>.from(json['preferred_opportunity_types'] as List)
          : null,
      role: (json['role'] as String?) ?? 'athlete',
      focusedSportId: json['focused_sport_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'full_name': fullName,
      'age': age,
      'city': city,
      'profile_photo_url': profilePhotoUrl,
      'created_at': createdAt.toIso8601String(),
      'headline': headline,
      'bio': bio,
      'location': location,
      'availability': availability,
      'preferred_opportunity_types': preferredOpportunityTypes,
      'role': role,
      'focused_sport_id': focusedSportId,
    };
  }
}
