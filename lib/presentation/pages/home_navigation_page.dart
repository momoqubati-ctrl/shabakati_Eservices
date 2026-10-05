import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/whatsapp_launcher.dart';
import '../../data/models/user_account_model.dart';
import '../../logic/auth/auth_cubit.dart';
import '../../logic/auth/auth_state.dart';
import '../../logic/cart/cart_cubit.dart';
import '../../logic/orders/orders_cubit.dart';
import 'account_profile_page.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<AuthCubit>();
      final authState = cubit.state;
      if (authState is AuthSuccess) {
        context.read<OrdersCubit>().loadOrdersForUser(authState.user);
        if (authState.isFirstLogin && cubit.consumeFirstLoginBiometricPrompt()) {
          _showEnableBiometricsDialog(authState.user);
        }
      }
    });
  }

  Future<void> _showEnableBiometricsDialog(UserAccountModel user) async {
    if (!mounted) return;
    final cubit = context.read<AuthCubit>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    bool isActivating = false;
    String? dialogError;

    final enabled = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(dialogCtx).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.fingerprint_rounded, color: Theme.of(dialogCtx).colorScheme.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('تفعيل الدخول بالبصمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'هل تريد تفعيل البصمة لتسهيل عملية الدخول في المرات القادمة بدون الحاجة لإدخال كلمة السر؟',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, size: 16, color: Colors.red.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            dialogError!,
                            style: TextStyle(fontSize: 11.5, color: Colors.red.shade800, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isActivating ? null : () => Navigator.pop(dialogCtx, false),
                child: Text('ليس الآن', style: TextStyle(color: Colors.grey.shade600)),
              ),
              FilledButton.icon(
                icon: isActivating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.fingerprint_rounded, size: 18),
                label: const Text('حفظ وتفعيل'),
                onPressed: isActivating
                    ? null
                    : () async {
                        setDialogState(() {
                          isActivating = true;
                          dialogError = null;
                        });
                        final ok = await cubit.authenticateAndEnableBiometrics(
                          user: user,
                        );
                        if (!dialogCtx.mounted) return;
                        if (ok) {
                          Navigator.pop(dialogCtx, true);
                        } else {
                          setDialogState(() {
                            isActivating = false;
                            dialogError = 'لم يتم التحقق من البصمة، يرجى مسح البصمة للمتابعة أو اختيار "ليس الآن"';
                          });
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );

    if (enabled == true) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('تم تفعيل الدخول بالبصمة بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = context.watch<CartCubit>().state;
    final bool hasCartBar = _currentIndex == 1 && cartState.items.isNotEmpty;

    final List<Widget> pages = [
      const CatalogPage(),
      CartPage(onNavigateToOrders: () {
        setState(() => _currentIndex = 2);
      }),
      const OrdersPage(),
      const AccountProfilePage(),
    ];

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, authState) {
        if (authState is AuthSuccess) {
          context.read<OrdersCubit>().loadOrdersForUser(authState.user);
          final cubit = context.read<AuthCubit>();
          if (authState.isFirstLogin && cubit.consumeFirstLoginBiometricPrompt()) {
            _showEnableBiometricsDialog(authState.user);
          }
        } else if (authState is AuthInitial) {
          context.read<OrdersCubit>().clearOrders();
          context.read<CartCubit>().clearCart();
        }
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
        floatingActionButtonLocation: _SupportFabLocation(hasCartBar: hasCartBar),
        floatingActionButton: FloatingActionButton(
          heroTag: 'whatsapp_support_fab',
          onPressed: () => WhatsAppLauncher.openSupportChat(),
          backgroundColor: const Color(0xFF25D366),
          foregroundColor: Colors.white,
          elevation: 4,
          shape: const CircleBorder(),
          tooltip: 'الدعم الفني والمساعدة عبر واتساب',
          child: const Icon(Icons.chat_rounded, size: 28),
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
              icon: Badge(
                isLabelVisible: cartState.totalCount > 0,
                label: Text('${cartState.totalCount}'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: cartState.totalCount > 0,
                label: Text('${cartState.totalCount}'),
                child: const Icon(Icons.shopping_cart_rounded),
              ),
              label: 'السلة',
            ),
            const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'طلباتي واشتراكاتي',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'حسابي',
            ),
          ],
        ),
      ),
    ),
  );
}
}

class _SupportFabLocation extends FloatingActionButtonLocation {
  final bool hasCartBar;

  const _SupportFabLocation({this.hasCartBar = false});

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabWidth = scaffoldGeometry.floatingActionButtonSize.width;
    final double fabHeight = scaffoldGeometry.floatingActionButtonSize.height;

    // End in RTL is left side (x = 16.0); in LTR, end is right side
    final double x = scaffoldGeometry.textDirection == TextDirection.rtl
        ? 16.0
        : scaffoldGeometry.scaffoldSize.width - fabWidth - 16.0;

    double y = scaffoldGeometry.contentBottom - fabHeight - 16.0;
    if (hasCartBar) {
      y -= 125.0; // Float right above the cart checkout summary bar
    }
    return Offset(x, y);
  }
}
