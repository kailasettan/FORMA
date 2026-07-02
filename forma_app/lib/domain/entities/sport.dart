import 'package:equatable/equatable.dart';

class Sport extends Equatable {
  final String id;
  final String name;
  final String slug;
  final String? iconUrl;
  final bool isActive;
  final DateTime createdAt;

  const Sport({
    required this.id,
    required this.name,
    required this.slug,
    this.iconUrl,
    required this.isActive,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, name, slug, iconUrl, isActive, createdAt];
}
