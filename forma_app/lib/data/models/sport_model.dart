import '../../domain/entities/sport.dart';

class SportModel extends Sport {
  const SportModel({
    required super.id,
    required super.name,
    required super.slug,
    super.iconUrl,
    required super.isActive,
    required super.createdAt,
  });

  factory SportModel.fromJson(Map<String, dynamic> json) {
    return SportModel(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      slug: _requiredString(json, 'slug'),
      iconUrl: json['icon_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: _dateTimeOrNow(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'icon_url': iconUrl,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Sport response missing required field: $key');
}

DateTime _dateTimeOrNow(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now().toUtc();
  }
  return DateTime.now().toUtc();
}
