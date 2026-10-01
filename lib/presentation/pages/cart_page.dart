import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/basgate_payment_service.dart';
import '../../core/services/secure_storage_service.dart';
import '../../logic/auth/auth_cubit.dart';
import '../../logic/cart/cart_cubit.dart';
import '../../logic/cart/cart_state.dart';
import '../../logic/orders/orders_cubit.dart';
import '../widgets/checkout_warning_dialog.dart';
import 'auth/login_page.dart';

class CartPage extends StatelessWidget {
  final VoidCallback onNavigateToOrders;

  const CartPage({super.key, required this.onNavigateToOrders});

  Future<bool> _showLoginRequiredDialog(BuildContext context) async {
    final shouldLogin = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_person_rounded, size: 40, color: Colors.orange.shade800),
          ),
          title: const Text(
            'تسجيل الدخول مطلوب',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'لا يمكنك متابعة الشراء أو الدفع إلا إذا كنت عميلاً مسجلاً وقمت بتسجيل الدخول إلى حسابك.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.5),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: TextStyle(color: Colors.grey.shade600)),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('تسجيل الدخول الآن'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );

    if (shouldLogin == true && context.mounted) {
      final loggedIn = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return loggedIn == true && context.mounted && context.read<AuthCubit>().isAuthenticated;
    }
    return false;
  }

  void _showCheckoutDialog(BuildContext context, CartState cartState) async {
    final authCubit = context.read<AuthCubit>();
    if (!authCubit.isAuthenticated || authCubit.currentUser == null) {
      final loggedIn = await _showLoginRequiredDialog(context);
      if (!loggedIn || !context.mounted) return;
    }

    final currentUser = authCubit.currentUser!;
    final storage = SecureStorageService();
    final savedTelegram = await storage.getSavedTelegramUser();
    final savedPhone = currentUser.accountNumber;
    final savedName = currentUser.fullName;

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => CheckoutWarningDialog(
        totalAmount: cartState.totalRetailUsd(),
        currency: 'USD',
        displayYer: cartState.displayTotalYer(),
        itemsCount: cartState.totalCount,
        initialTelegramUser: savedTelegram,
        initialPhone: savedPhone,
        onPayWithBasGate: (telegramUser, phone) async {
          final ordersCubit = context.read<OrdersCubit>();
          final cartCubit = context.read<CartCubit>();
          final basGateService = BasGatePaymentService();

          // 1. إظهار مؤشر الاتصال بالبوابة
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'جارٍ فتح بوابة الدفع الإلكترونية (BasGate)...',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          // 2. تشغيل تدفق الدفع عبر البوابة
          final orderId = 'ORD_${DateTime.now().millisecondsSinceEpoch}';
          final effectivePhone = phone.isNotEmpty ? phone : savedPhone;

          final paymentResult = await basGateService.payWithBasGate(
            context: context,
            amountYer: cartState.totalAmountYer(),
            orderId: orderId,
            userAccount: effectivePhone,
            customerPhone: effectivePhone,
            customerName: savedName.isNotEmpty ? savedName : 'عميل شبكتي',
            description: 'طلب خدمات شبكتي (${cartState.totalCount} عنصر)',
          );

          if (!context.mounted) return;
          Navigator.pop(context); // إغلاق مؤشر التحميل

          // 3. معالجة نتيجة الدفع
          if (paymentResult.isSuccess) {
            // ✅ تم الدفع بنجاح لدى البنك: يتم إرسال وتسجيل الطلب رسمياً
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const Center(child: CircularProgressIndicator()),
            );

            final submitResult = await ordersCubit.submitOrder(
              items: cartState.items,
              telegramUser: telegramUser,
              contactPhone: effectivePhone,
            );

            if (!context.mounted) return;
            Navigator.pop(context); // إغلاق مؤشر التسجيل

            cartCubit.clearCart();
            ordersCubit.loadOrders();

            showDialog(
              context: context,
              builder: (ctx) => Directionality(
                textDirection: TextDirection.rtl,
                child: AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Row(
                    children: const [
                      Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                      SizedBox(width: 8),
                      Text('تم الدفع واستلام الطلب'),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        submitResult?.message ?? 'تم خصم المبلغ بنجاح عبر بوابة BasGate وتأكيد طلبك.',
                        style: const TextStyle(fontSize: 13.5, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'المبلغ المسدد: ${cartState.displayTotalYer()}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            if (paymentResult.paymentId != null)
                              Text(
                                'رقم العملية البنكية: ${paymentResult.paymentId}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onNavigateToOrders();
                      },
                      child: const Text('عرض طلباتي واشتراكاتي'),
                    ),
                  ],
                ),
              ),
            );
          } else if (paymentResult.isCancelled) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ تم إلغاء عملية الدفع. لم يتم خصم أي مبلغ من حسابك.'),
                backgroundColor: Color(0xFFF59E0B),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ تعثر إتمام الدفع: ${paymentResult.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        onConfirm: (telegramUser, phone, paymentMethod) async {
          final ordersCubit = context.read<OrdersCubit>();
          final cartCubit = context.read<CartCubit>();

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator()),
          );

          final result = await ordersCubit.submitOrder(
            items: cartState.items,
            telegramUser: telegramUser,
            contactPhone: phone,
          );

          if (!context.mounted) return;
          Navigator.pop(context); // إغلاق مؤشر التحميل

          if (result != null) {
            cartCubit.clearCart();
            ordersCubit.loadOrders();

            showDialog(
              context: context,
              builder: (ctx) => Directionality(
                textDirection: TextDirection.rtl,
                child: AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Row(
                    children: const [
                      Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                      SizedBox(width: 8),
                      Text('تم استلام طلبك بنجاح'),
                    ],
                  ),
                  content: Text(
                    result.message,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  actions: [
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onNavigateToOrders();
                      },
                      child: const Text('عرض طلباتي واشتراكاتي'),
                    ),
                  ],
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('فشل في استكمال الطلب، يرجى المحاولة لاحقاً'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سلة المشتريات', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            BlocBuilder<CartCubit, CartState>(
              builder: (context, state) {
                if (state.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded),
                  tooltip: 'إفراغ السلة',
                  onPressed: () => context.read<CartCubit>().clearCart(),
                );
              },
            ),
          ],
        ),
        body: BlocBuilder<CartCubit, CartState>(
          builder: (context, state) {
            if (state.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_cart_outlined, size: 72, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text('سلة المشتريات فارغة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('تصفح الكتالوج وأضف الاشتراكات والخدمات الرقمية', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              );
            }

            final isAuthenticated = context.watch<AuthCubit>().isAuthenticated;

            return Column(
              children: [
                if (!isAuthenticated)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline_rounded, color: Colors.amber.shade900, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'يجب تسجيل الدخول لإتمام عملية الشراء وتأكيد الدفع',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginPage()),
                          ),
                          child: const Text('تسجيل الدخول', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.items.length,
                    separatorBuilder: (context, itemIndex) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colorScheme.outlineVariant.withAlpha(90),
                                  ),
                                ),
                                child: (item.product.iconUrl != null && item.product.iconUrl!.isNotEmpty)
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          item.product.iconUrl!,
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) => Icon(
                                            Icons.stars_rounded,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      )
                                    : Icon(Icons.stars_rounded, color: colorScheme.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.product.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 2,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.displayTotalYer(),
                                      style: TextStyle(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    Text(
                                      item.displayTotalRetailUsd(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, size: 22),
                                    onPressed: () => context.read<CartCubit>().updateQuantity(item.product.id, -1),
                                  ),
                                  Text(
                                    '${item.quantity}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, size: 22),
                                    onPressed: () => context.read<CartCubit>().updateQuantity(item.product.id, 1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // شريط أسفل السلة الإجمالي مع زر الدفع
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(12),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      )
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('الإجمالي النهائي:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  state.displayTotalYer(),
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                Text(
                                  state.displayTotalRetailUsd(),
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                            label: const Text('متابعة الشراء وتأكيد الدفع'),
                            onPressed: () => _showCheckoutDialog(context, state),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            );
          },
        ),
      ),
    );
  }
}
