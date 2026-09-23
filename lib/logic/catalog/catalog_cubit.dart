import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/product_repository.dart';
import 'catalog_state.dart';

class CatalogCubit extends Cubit<CatalogState> {
  final IProductRepository repository;

  CatalogCubit(this.repository) : super(CatalogInitial());

  Future<void> fetchCatalog() async {
    emit(CatalogLoading());
    try {
      final products = await repository.getCatalog();
      final Set<String> catSet = {'الكل'};
      for (var p in products) {
        catSet.add(p.category);
      }

      emit(CatalogLoaded(
        allProducts: products,
        filteredProducts: products,
        categories: catSet.toList(),
      ));
    } catch (e) {
      emit(CatalogError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  void selectCategory(String category) {
    if (state is CatalogLoaded) {
      final current = state as CatalogLoaded;
      List<ProductModel> filtered = current.allProducts;

      if (category != 'الكل') {
        filtered = filtered.where((p) => p.category == category).toList();
      }

      if (current.searchQuery.isNotEmpty) {
        filtered = filtered
            .where((p) =>
                p.name.toLowerCase().contains(current.searchQuery.toLowerCase()))
            .toList();
      }

      emit(current.copyWith(
        selectedCategory: category,
        filteredProducts: filtered,
      ));
    }
  }

  void search(String query) {
    if (state is CatalogLoaded) {
      final current = state as CatalogLoaded;
      List<ProductModel> filtered = current.allProducts;

      if (current.selectedCategory != 'الكل') {
        filtered =
            filtered.where((p) => p.category == current.selectedCategory).toList();
      }

      if (query.trim().isNotEmpty) {
        filtered = filtered
            .where((p) =>
                p.name.toLowerCase().contains(query.trim().toLowerCase()))
            .toList();
      }

      emit(current.copyWith(
        searchQuery: query,
        filteredProducts: filtered,
      ));
    }
  }
}
