import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/api_config.dart';
import 'core/network/dio_client.dart';
import 'core/services/auth_biometric_service.dart';
import 'core/services/otp_service.dart';
import 'core/services/secure_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/order_repository.dart';
import 'data/repositories/product_repository.dart';
import 'logic/auth/auth_cubit.dart';
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
  final biometricService = AuthBiometricService();
  final otpService = OtpService(supabase: supabaseClient);

  final productRepository = ProductRepository(
    dioClient,
    supabaseClient: supabaseClient,
  );
  final orderRepository = OrderRepository(
    dioClient: dioClient,
    supabaseClient: supabaseClient,
  );
  final authRepository = AuthRepository(supabase: supabaseClient);

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<IProductRepository>.value(value: productRepository),
        RepositoryProvider<IOrderRepository>.value(value: orderRepository),
        RepositoryProvider<IAuthRepository>.value(value: authRepository),
        RepositoryProvider<SecureStorageService>.value(value: secureStorage),
        RepositoryProvider<AuthBiometricService>.value(value: biometricService),
        RepositoryProvider<OtpService>.value(value: otpService),
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
          BlocProvider<AuthCubit>(
            create: (_) => AuthCubit(
              authRepository: authRepository,
              biometricService: biometricService,
              otpService: otpService,
              secureStorageService: secureStorage,
            )..restoreSavedSession(),
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
      title: 'بوابة شبكتي للخدمات الرقمية',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const HomeNavigationPage(),
    );
  }
}
