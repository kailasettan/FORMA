import '../entities/sport.dart';
import '../entities/sport_category.dart';

abstract class CatalogRepository {
  Future<List<Sport>> getSports();
  Future<List<SportCategory>> getCategories(String sportId);
}
