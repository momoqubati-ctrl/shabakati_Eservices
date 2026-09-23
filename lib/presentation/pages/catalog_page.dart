import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/cart/cart_cubit.dart';
import '../../logic/catalog/catalog_cubit.dart';
import '../../logic/catalog/catalog_state.dart';
import '../widgets/product_card.dart';

class CatalogPage extends StatelessWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.flash_on_rounded, color: colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 8),
              const Text('بوابة شبكتي للخدمات الرقمية', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث الكتالوج',
              onPressed: () => context.read<CatalogCubit>().fetchCatalog(),
            ),
          ],
        ),
        body: Column(
          children: [
            // حقل البحث السريع
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                onChanged: (val) => context.read<CatalogCubit>().search(val),
                decoration: InputDecoration(
                  hintText: 'ابحث عن خدمة أو اشتراك (ChatGPT, Duolingo, VPN...)',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withAlpha(80),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                ),
              ),
            ),

            // شريط الفئات الأفقية
            BlocBuilder<CatalogCubit, CatalogState>(
              builder: (context, state) {
                if (state is CatalogLoaded) {
                  return SizedBox(
                    height: 44,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: state.categories.length,
                      separatorBuilder: (context, chipIndex) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = state.categories[index];
                        final isSelected = cat == state.selectedCategory;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (_) => context.read<CatalogCubit>().selectCategory(cat),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : colorScheme.onSurface,
                          ),
                          selectedColor: colorScheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        );
                      },
                    ),
                  );
                }
                return const SizedBox(height: 44);
              },
            ),
            const SizedBox(height: 8),

            // شبكة عرض المنتجات
            Expanded(
              child: BlocBuilder<CatalogCubit, CatalogState>(
                builder: (context, state) {
                  if (state is CatalogLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is CatalogError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_off_rounded, size: 54, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(
                              state.message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('إعادة المحاولة'),
                              onPressed: () => context.read<CatalogCubit>().fetchCatalog(),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else if (state is CatalogLoaded) {
                    final products = state.filteredProducts;
                    if (products.isEmpty) {
                      return const Center(
                        child: Text('لا توجد خدمات مطابقة لبحثك حالياً'),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return ProductCard(
                          product: product,
                          exchangeRate: state.exchangeRate,
                          onAddToCart: () {
                            context.read<CartCubit>().addProduct(product);
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تمت إضافة "${product.name}" إلى السلة'),
                                duration: const Duration(milliseconds: 1500),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
