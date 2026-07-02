import '../../domain/entities/sport.dart';
import '../../domain/entities/sport_category.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../api_client.dart';
import '../models/sport_model.dart';
import '../models/sport_category_model.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  final ApiClient _apiClient;

  CatalogRepositoryImpl(this._apiClient);

  @override
  Future<List<Sport>> getSports() async {
    final response = await _apiClient.get('/sports');
    if (response is List) {
      return response.map((json) => SportModel.fromJson(json as Map<String, dynamic>)).toList();
    }
    return [];
  }

  @override
  Future<List<SportCategory>> getCategories(String sportId) async {
    final response = await _apiClient.get('/sports/$sportId/categories');
    if (response is List) {
      return response.map((json) => SportCategoryModel.fromJson(json as Map<String, dynamic>)).toList();
    }
    return [];
  }
}
