import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/cart/cart_cubit.dart';
import '../../logic/cart/cart_state.dart';
import 'cart_page.dart';
import 'catalog_page.dart';
import 'orders_page.dart';

class HomeNavigationPage extends StatefulWidget {
  const HomeNavigationPage({super.key});

  @override
  State<HomeNavigationPage> createState() => _HomeNavigationPageState();
}

class _HomeNavigationPageState extends State<HomeNavigationPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const CatalogPage(),
      CartPage(onNavigateToOrders: () {
        setState(() => _currentIndex = 2);
      }),
      const OrdersPage(),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront_rounded),
              label: 'الخدمات والكتالوج',
            ),
            NavigationDestination(
              icon: BlocBuilder<CartCubit, CartState>(
                builder: (context, state) {
                  return Badge(
                    isLabelVisible: state.totalCount > 0,
                    label: Text('${state.totalCount}'),
                    child: const Icon(Icons.shopping_cart_outlined),
                  );
                },
              ),
              selectedIcon: BlocBuilder<CartCubit, CartState>(
                builder: (context, state) {
                  return Badge(
                    isLabelVisible: state.totalCount > 0,
                    label: Text('${state.totalCount}'),
                    child: const Icon(Icons.shopping_cart_rounded),
                  );
                },
              ),
              label: 'السلة',
            ),
            const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'طلباتي واشتراكاتي',
            ),
          ],
        ),
      ),
    );
  }
}
