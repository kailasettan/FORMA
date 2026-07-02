import 'package:equatable/equatable.dart';

class SportCategory extends Equatable {
  final String id;
  final String sportId;
  final String name;
  final String slug;
  final bool isActive;
  final int displayOrder;

  const SportCategory({
    required this.id,
    required this.sportId,
    required this.name,
    required this.slug,
    required this.isActive,
    required this.displayOrder,
  });

  @override
  List<Object?> get props => [id, sportId, name, slug, isActive, displayOrder];
}
