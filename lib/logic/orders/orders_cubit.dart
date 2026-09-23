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

  Future<OrderSubmitSuccess?> submitOrder({
    required List<CartItemModel> items,
    String? telegramUser,
    String? contactPhone,
    String? contactEmail,
  }) async {
    emit(OrderSubmitting());
    try {
      final deviceId = await secureStorageService.getOrCreateDeviceId();
      if (telegramUser != null && telegramUser.isNotEmpty) {
        await secureStorageService.saveTelegramUser(telegramUser);
      }

      final order = await orderRepository.submitOrder(
        items: items,
        deviceId: deviceId,
        telegramUser: telegramUser,
        contactPhone: contactPhone,
        contactEmail: contactEmail,
      );

      final isInstant = order.isReady && order.deliveredKey != null;
      final message = isInstant
          ? 'تم تفعيل واستلام المفتاح الرقمي بنجاح!'
          : 'تم تأكيد الدفع بنجاح. طلبك قيد التنفيذ وسيتم تسليمه خلال مدة أقصاها 24 ساعة.';

      final successState = OrderSubmitSuccess(
        order: order,
        message: message,
        isInstantDelivery: isInstant,
      );

      emit(successState);
      return successState;
    } catch (e) {
      emit(OrderSubmitError(e.toString().replaceAll('Exception: ', '')));
      return null;
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
