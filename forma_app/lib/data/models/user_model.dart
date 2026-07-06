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
      id: _requiredString(json, 'id'),
      username: _requiredString(json, 'username'),
      email: json['email'] as String? ?? '',
      fullName: _requiredString(json, 'full_name'),
      age: (json['age'] as num?)?.toInt(),
      city: json['city'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      createdAt: _dateTimeOrNow(json['created_at']),
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

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('User response missing required field: $key');
}

DateTime _dateTimeOrNow(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now().toUtc();
  }
  return DateTime.now().toUtc();
}
