import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/sport.dart';
import '../../domain/entities/sport_category.dart';
import '../../domain/repositories/catalog_repository.dart';

abstract class CatalogState extends Equatable {
  const CatalogState();
  @override
  List<Object?> get props => [];
}

class CatalogInitial extends CatalogState {}

class CatalogLoading extends CatalogState {}

class CatalogLoaded extends CatalogState {
  final List<Sport> sports;
  final Map<String, List<SportCategory>> categories; // sportId -> categories

  const CatalogLoaded({required this.sports, required this.categories});

  @override
  List<Object?> get props => [sports, categories];
}

class CatalogError extends CatalogState {
  final String message;
  const CatalogError(this.message);

  @override
  List<Object?> get props => [message];
}

class CatalogCubit extends Cubit<CatalogState> {
  final CatalogRepository _catalogRepository;

  CatalogCubit(this._catalogRepository) : super(CatalogInitial());

  Future<void> loadSportsAndCategories() async {
    try {
      emit(CatalogLoading());
      final sports = await _catalogRepository.getSports();
      final Map<String, List<SportCategory>> categories = {};
      
      // Load categories for active sports
      for (final sport in sports) {
        final cats = await _catalogRepository.getCategories(sport.id);
        categories[sport.id] = cats;
      }
      
      emit(CatalogLoaded(sports: sports, categories: categories));
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }
}
