import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/telegram_launcher.dart';
import '../../logic/orders/orders_cubit.dart';
import '../../logic/orders/orders_state.dart';
import '../widgets/order_status_card.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('طلباتي واشتراكاتي', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث الطلبات',
              onPressed: () => context.read<OrdersCubit>().loadOrders(),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => context.read<OrdersCubit>().loadOrders(),
          child: BlocBuilder<OrdersCubit, OrdersState>(
            builder: (context, state) {
              if (state is OrdersLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is OrdersLoaded) {
                if (state.orders.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 80),
                      Icon(Icons.inventory_2_outlined, size: 72, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Center(
                        child: Text(
                          'لا توجد طلبات سابقة على هذا الجهاز',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'عند شرائك أي اشتراك ستظهر أكواد التفعيل وتفاصيل المتابعة هنا تلقائياً.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.telegram, color: Color(0xFF229ED9)),
                          label: const Text('التواصل مع دعم تيليجرام'),
                          onPressed: () => TelegramLauncher.openBotChat(),
                        ),
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.orders.length,
                  itemBuilder: (context, index) {
                    final order = state.orders[index];
                    return OrderStatusCard(
                      order: order,
                      onRefresh: () => context.read<OrdersCubit>().refreshOrder(order),
                    );
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}
