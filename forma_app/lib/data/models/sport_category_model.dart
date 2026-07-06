import '../../domain/entities/sport_category.dart';

class SportCategoryModel extends SportCategory {
  const SportCategoryModel({
    required super.id,
    required super.sportId,
    required super.name,
    required super.slug,
    required super.isActive,
    required super.displayOrder,
  });

  factory SportCategoryModel.fromJson(Map<String, dynamic> json) {
    return SportCategoryModel(
      id: _requiredString(json, 'id'),
      sportId: _requiredString(json, 'sport_id'),
      name: _requiredString(json, 'name'),
      slug: _requiredString(json, 'slug'),
      isActive: json['is_active'] as bool? ?? true,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sport_id': sportId,
      'name': name,
      'slug': slug,
      'is_active': isActive,
      'display_order': displayOrder,
    };
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Sport category response missing required field: $key');
}
