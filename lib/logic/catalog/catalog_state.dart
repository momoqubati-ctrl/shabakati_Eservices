import '../../data/models/product_model.dart';

abstract class CatalogState {}

class CatalogInitial extends CatalogState {}

class CatalogLoading extends CatalogState {}

class CatalogLoaded extends CatalogState {
  final List<ProductModel> allProducts;
  final List<ProductModel> filteredProducts;
  final List<String> categories;
  final String selectedCategory;
  final String searchQuery;

  CatalogLoaded({
    required this.allProducts,
    required this.filteredProducts,
    required this.categories,
    this.selectedCategory = 'الكل',
    this.searchQuery = '',
  });

  CatalogLoaded copyWith({
    List<ProductModel>? allProducts,
    List<ProductModel>? filteredProducts,
    List<String>? categories,
    String? selectedCategory,
    String? searchQuery,
  }) {
    return CatalogLoaded(
      allProducts: allProducts ?? this.allProducts,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      categories: categories ?? this.categories,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class CatalogError extends CatalogState {
  final String message;
  CatalogError(this.message);
}
