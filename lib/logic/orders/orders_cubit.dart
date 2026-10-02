import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/secure_storage_service.dart';
import '../../data/models/cart_item_model.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/order_repository.dart';
import 'orders_state.dart';

class OrdersCubit extends Cubit<OrdersState> {
  final IOrderRepository orderRepository;
  final SecureStorageService secureStorageService;
  StreamSubscription<List<OrderModel>>? _ordersSubscription;

  OrdersCubit({
    required this.orderRepository,
    required this.secureStorageService,
  }) : super(OrdersInitial());

  Future<void> loadOrders() async {
    emit(OrdersLoading());
    try {
      final deviceId = await secureStorageService.getOrCreateDeviceId();

      // إلغاء أي اشتراك Realtime سابق لمنع تكرار الـ listeners
      await _ordersSubscription?.cancel();

      // بدء الاستماع اللحظي (Supabase Realtime Stream)
      _ordersSubscription = orderRepository
          .streamOrdersByDevice(deviceId)
          .listen((ordersList) {
        emit(OrdersLoaded(ordersList));
      }, onError: (_) async {
        // في حال انقطاع اتصال الـ Realtime، يتم الجلب العادي كـ Fallback
        final fallbackList = await orderRepository.getOrdersByDevice(deviceId);
        emit(OrdersLoaded(fallbackList));
      });
    } catch (_) {
      emit(OrdersLoaded(const []));
    }
  }

  Future<OrderSubmitResult> submitOrder({
    required List<CartItemModel> items,
    String? telegramUser,
    String? contactPhone,
    String? contactEmail,
    String? paymentId,
  }) async {
    emit(OrderSubmitting());
    try {
      final deviceId = await secureStorageService.getOrCreateDeviceId();
      if (telegramUser != null && telegramUser.isNotEmpty) {
        await secureStorageService.saveTelegramUser(telegramUser);
      }

      final result = await orderRepository.submitOrder(
        items: items,
        deviceId: deviceId,
        telegramUser: telegramUser,
        contactPhone: contactPhone,
        contactEmail: contactEmail,
        paymentId: paymentId,
      );

      final successState = OrderSubmitSuccess(
        order: result.order,
        message: result.message,
        isInstantDelivery: result.isInstantDelivery,
        isVaultSuccess: result.isSuccess,
        errorMessage: result.errorMessage,
      );

      emit(successState);
      return result;
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      emit(OrderSubmitError(errorMsg));
      final fallbackOrder = OrderModel(
        externalOrderId: 'ord_${DateTime.now().millisecondsSinceEpoch}',
        status: 'paid',
        fulfillmentStatus: 'processing',
        totalCents: 0,
        currency: 'USD',
        createdAt: DateTime.now(),
        contactPhone: contactPhone,
      );
      return OrderSubmitResult(
        isSuccess: false,
        order: fallbackOrder,
        errorMessage: errorMsg,
        message: errorMsg,
      );
    }
  }

  Future<void> refreshOrder(OrderModel order) async {
    try {
      final updated = await orderRepository.refreshOrderStatus(order);
      if (state is OrdersLoaded) {
        final current = (state as OrdersLoaded).orders;
        final index = current.indexWhere((o) => o.externalOrderId == updated.externalOrderId);
        if (index >= 0) {
          final newList = List<OrderModel>.from(current);
          newList[index] = updated;
          emit(OrdersLoaded(newList));
        }
      }
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _ordersSubscription?.cancel();
    return super.close();
  }
}
