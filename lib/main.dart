import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/api_config.dart';
import 'core/network/dio_client.dart';
import 'core/services/secure_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/order_repository.dart';
import 'data/repositories/product_repository.dart';
import 'logic/cart/cart_cubit.dart';
import 'logic/catalog/catalog_cubit.dart';
import 'logic/orders/orders_cubit.dart';
import 'presentation/pages/home_navigation_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة اتصال Supabase الرسمي بالمفتاح العام
  await Supabase.initialize(
    url: ApiConfig.supabaseUrl,
    publishableKey: ApiConfig.supabasePublishableKey,
  );

  final supabaseClient = Supabase.instance.client;

  // تهيئة عميل Dio مع معالج توقيع Digital Vault وخدمات التخزين
  final dioClient = DioClient();
  final secureStorage = SecureStorageService();
  final productRepository = ProductRepository(
    dioClient,
    supabaseClient: supabaseClient,
  );
  final orderRepository = OrderRepository(
    dioClient: dioClient,
    supabaseClient: supabaseClient,
  );

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<IProductRepository>.value(value: productRepository),
        RepositoryProvider<IOrderRepository>.value(value: orderRepository),
        RepositoryProvider<SecureStorageService>.value(value: secureStorage),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<CatalogCubit>(
            create: (_) => CatalogCubit(productRepository)..fetchCatalog(),
          ),
          BlocProvider<CartCubit>(
            create: (_) => CartCubit(),
          ),
          BlocProvider<OrdersCubit>(
            create: (_) => OrdersCubit(
              orderRepository: orderRepository,
              secureStorageService: secureStorage,
            )..loadOrders(),
          ),
        ],
        child: const ShabaktiEservicesApp(),
      ),
    ),
  );
}

class ShabaktiEservicesApp extends StatelessWidget {
  const ShabaktiEservicesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'شَبَكتي | للخدمات والاشتراكات الرقمية',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const HomeNavigationPage(),
    );
  }
}
