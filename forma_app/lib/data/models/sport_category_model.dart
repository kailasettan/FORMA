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
      id: json['id'] as String,
      sportId: json['sport_id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      isActive: json['is_active'] as bool,
      displayOrder: json['display_order'] as int,
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
