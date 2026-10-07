import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
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
import 'logic/auth/auth_state.dart';
import 'logic/cart/cart_cubit.dart';
import 'logic/catalog/catalog_cubit.dart';
import 'logic/orders/orders_cubit.dart';
import 'presentation/pages/auth/login_page.dart';
import 'presentation/pages/home_navigation_page.dart';
import 'presentation/pages/onboarding_splash_page.dart';

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
    secureStorageService: secureStorage,
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
      home: const AppStartupGate(),
    );
  }
}

/// بوابة الانطلاق الأولى: تفحص عرض شاشات التعريف والترحيب (السبلاش) لأول مرة
class AppStartupGate extends StatefulWidget {
  const AppStartupGate({super.key});

  @override
  State<AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends State<AppStartupGate> {
  bool _isLoading = true;
  bool _hasSeenOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboardingState();
  }

  Future<void> _checkOnboardingState() async {
    final storage = context.read<SecureStorageService>();
    final seen = await storage.hasSeenOnboarding();
    if (mounted) {
      setState(() {
        _hasSeenOnboarding = seen;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF090D16),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF2563EB),
          ),
        ),
      );
    }

    if (!_hasSeenOnboarding) {
      return OnboardingSplashPage(
        onComplete: () {
          setState(() {
            _hasSeenOnboarding = true;
          });
        },
      );
    }

    return const AuthGate();
  }
}

/// بوابة التحقق من الجلسة والدخول
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (previous, current) {
        // إعادة البناء فقط عند الانتقال بين حالة AuthSuccess والحالات الأخرى
        return (previous is AuthSuccess) != (current is AuthSuccess);
      },
      builder: (context, state) {
        if (state is AuthSuccess) {
          return const HomeNavigationPage();
        }
        return const LoginPage();
      },
    );
  }
}

