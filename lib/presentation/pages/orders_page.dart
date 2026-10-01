import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/telegram_launcher.dart';
import '../../data/models/order_model.dart';
import '../../logic/orders/orders_cubit.dart';
import '../../logic/orders/orders_state.dart';
import '../widgets/order_status_card.dart';

enum OrderStatusFilter {
  all,
  ready,
  processing,
  failed,
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> with SingleTickerProviderStateMixin {
  late final TabController _mainTabController;

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    super.dispose();
  }

  bool _isOrderToday(DateTime orderDate) {
    final now = DateTime.now();
    return orderDate.year == now.year &&
        orderDate.month == now.month &&
        orderDate.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocBuilder<OrdersCubit, OrdersState>(
        builder: (context, state) {
          final List<OrderModel> allOrders = (state is OrdersLoaded) ? state.orders : [];

          // تقسيم العمليات: اليوم مقابل السابقة
          final todayOrders = allOrders.where((o) => _isOrderToday(o.createdAt)).toList();
          final previousOrders = allOrders.where((o) => !_isOrderToday(o.createdAt)).toList();

          return Scaffold(
            appBar: AppBar(
              title: const Text(
                'طلباتي واشتراكاتي',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              centerTitle: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'تحديث الطلبات',
                  onPressed: () => context.read<OrdersCubit>().loadOrders(),
                ),
              ],
              bottom: TabBar(
                controller: _mainTabController,
                indicatorWeight: 3,
                labelColor: colorScheme.primary,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.today_rounded, size: 18),
                        const SizedBox(width: 6),
                        const Text('مشتريات اليوم'),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: todayOrders.isNotEmpty
                                ? colorScheme.primaryContainer
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${todayOrders.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: todayOrders.isNotEmpty
                                  ? colorScheme.onPrimaryContainer
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.history_rounded, size: 18),
                        const SizedBox(width: 6),
                        const Text('العمليات السابقة'),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: previousOrders.isNotEmpty
                                ? colorScheme.secondaryContainer
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${previousOrders.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: previousOrders.isNotEmpty
                                  ? colorScheme.onSecondaryContainer
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            body: (state is OrdersLoading)
                ? const Center(child: CircularProgressIndicator())
                : (allOrders.isEmpty)
                    ? _buildGlobalEmptyState(context)
                    : TabBarView(
                        controller: _mainTabController,
                        children: [
                          _OrderListTab(
                            orders: todayOrders,
                            isTodayTab: true,
                            onRefresh: () => context.read<OrdersCubit>().loadOrders(),
                          ),
                          _OrderListTab(
                            orders: previousOrders,
                            isTodayTab: false,
                            onRefresh: () => context.read<OrdersCubit>().loadOrders(),
                          ),
                        ],
                      ),
          );
        },
      ),
    );
  }

  Widget _buildGlobalEmptyState(BuildContext context) {
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
            label: const Text('التواصل مع الدعم الفني (@sahm)'),
            onPressed: () => TelegramLauncher.openBotChat(),
          ),
        ),
      ],
    );
  }
}

class _OrderListTab extends StatefulWidget {
  final List<OrderModel> orders;
  final bool isTodayTab;
  final Future<void> Function() onRefresh;

  const _OrderListTab({
    required this.orders,
    required this.isTodayTab,
    required this.onRefresh,
  });

  @override
  State<_OrderListTab> createState() => _OrderListTabState();
}

class _OrderListTabState extends State<_OrderListTab> with AutomaticKeepAliveClientMixin {
  OrderStatusFilter _selectedStatus = OrderStatusFilter.all;
  final ScrollController _scrollController = ScrollController();
  int _visibleCount = 10;
  bool _isLoadingMore = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _OrderListTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orders.length != widget.orders.length) {
      // الحفاظ على الحدود إذا تم تحديث البيانات
      if (_visibleCount > widget.orders.length) {
        _visibleCount = math.max(10, widget.orders.length);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 150) {
      final filteredList = _getFilteredOrders();
      if (!_isLoadingMore && _visibleCount < filteredList.length) {
        setState(() => _isLoadingMore = true);
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() {
              _visibleCount = math.min(_visibleCount + 10, filteredList.length);
              _isLoadingMore = false;
            });
          }
        });
      }
    }
  }

  List<OrderModel> _getFilteredOrders() {
    switch (_selectedStatus) {
      case OrderStatusFilter.all:
        return widget.orders;
      case OrderStatusFilter.ready:
        return widget.orders.where((o) => o.isReady).toList();
      case OrderStatusFilter.processing:
        return widget.orders.where((o) => o.isProcessing).toList();
      case OrderStatusFilter.failed:
        return widget.orders.where((o) => o.isFailed).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filteredOrders = _getFilteredOrders();
    final displayedOrders = filteredOrders.take(_visibleCount).toList();

    // إحصائيات الحالات للتبويب الحالي
    final totalCount = widget.orders.length;
    final readyCount = widget.orders.where((o) => o.isReady).length;
    final processingCount = widget.orders.where((o) => o.isProcessing).length;
    final failedCount = widget.orders.where((o) => o.isFailed).length;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: Column(
        children: [
          // شريط تبويبات وفلاتر الحالات (الكل، منفذة، معلقة، فاشلة)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                bottom: BorderSide(color: Colors.grey.withAlpha(40)),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatusChip(
                    filter: OrderStatusFilter.all,
                    label: 'الكل',
                    count: totalCount,
                    color: Colors.blue.shade700,
                    icon: Icons.all_inbox_rounded,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(
                    filter: OrderStatusFilter.ready,
                    label: 'منفذة',
                    count: readyCount,
                    color: Colors.green.shade700,
                    icon: Icons.check_circle_outline_rounded,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(
                    filter: OrderStatusFilter.processing,
                    label: 'معلقة',
                    count: processingCount,
                    color: Colors.amber.shade800,
                    icon: Icons.hourglass_top_rounded,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(
                    filter: OrderStatusFilter.failed,
                    label: 'فاشلة',
                    count: failedCount,
                    color: Colors.red.shade700,
                    icon: Icons.cancel_outlined,
                  ),
                ],
              ),
            ),
          ),

          // قائمة العمليات المعروضة بنظام التمرير اللانهائي (10 سجلات في كل دفعة)
          Expanded(
            child: displayedOrders.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: displayedOrders.length + (_visibleCount < filteredOrders.length ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < displayedOrders.length) {
                        final order = displayedOrders[index];
                        return OrderStatusCard(
                          order: order,
                          onRefresh: () => context.read<OrdersCubit>().refreshOrder(order),
                        );
                      }

                      // شارة التمرير لتحميل 10 سجلات إضافية
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'جاري تحميل سجلات إضافية... (${displayedOrders.length} من ${filteredOrders.length})',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required OrderStatusFilter filter,
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    final isSelected = _selectedStatus == filter;

    return InkWell(
      onTap: () {
        if (_selectedStatus != filter) {
          setState(() {
            _selectedStatus = filter;
            _visibleCount = 10;
          });
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(25) : Colors.grey.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? color : Colors.grey.shade600,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    if (widget.orders.isEmpty) {
      message = widget.isTodayTab
          ? 'لا توجد أي عمليات شراء تمت اليوم حتى الآن'
          : 'لا توجد أي عمليات شراء سابقة مسجلة';
    } else {
      switch (_selectedStatus) {
        case OrderStatusFilter.ready:
          message = 'لا توجد عمليات منفذة في هذا القسم';
          break;
        case OrderStatusFilter.processing:
          message = 'لا توجد عمليات معلقة حالياً';
          break;
        case OrderStatusFilter.failed:
          message = 'لا توجد أي عمليات فاشلة، كافة طلباتك تمت بنجاح';
          break;
        case OrderStatusFilter.all:
          message = 'لا توجد عمليات مسجلة';
          break;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 50),
        Icon(
          Icons.filter_list_off_rounded,
          size: 56,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'اسحب الشاشة للأسفل للتحديث في أي وقت',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ),
      ],
    );
  }
}
