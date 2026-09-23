import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/secure_storage_service.dart';
import '../../logic/cart/cart_cubit.dart';
import '../../logic/cart/cart_state.dart';
import '../../logic/orders/orders_cubit.dart';
import '../widgets/checkout_warning_dialog.dart';

class CartPage extends StatelessWidget {
  final VoidCallback onNavigateToOrders;

  const CartPage({super.key, required this.onNavigateToOrders});

  void _showCheckoutDialog(BuildContext context, CartState cartState) async {
    final storage = SecureStorageService();
    final savedTelegram = await storage.getSavedTelegramUser();

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => CheckoutWarningDialog(
        totalAmount: cartState.totalAmount,
        currency: 'USD',
        displayYer: cartState.displayTotalYer(),
        itemsCount: cartState.totalCount,
        initialTelegramUser: savedTelegram,
        onConfirm: (telegramUser, phone, paymentMethod) async {
          final ordersCubit = context.read<OrdersCubit>();
          final cartCubit = context.read<CartCubit>();

          // إظهار مؤشر تقدم أثناء الدفع والربط مع الـ API
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

            return Column(
              children: [
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
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.stars_rounded, color: colorScheme.primary),
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
                                      item.product.displaySecondaryUsd,
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
                                  state.displayTotal,
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
