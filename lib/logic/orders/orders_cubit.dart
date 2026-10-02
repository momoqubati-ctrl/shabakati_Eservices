import 'dart:async';
import 'package:flutter/foundation.dart';
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

  /// دمج قائمة الطلبات مع الأكواد والمفاتيح المحفوظة مشفرة محلياً لضمان عدم الرجوع لحالة معلقة
  Future<List<OrderModel>> _mergeWithLocalCache(List<OrderModel> orders) async {
    final merged = <OrderModel>[];
    for (final order in orders) {
      if (order.deliveredKey != null && order.deliveredKey!.isNotEmpty && order.isReady) {
        merged.add(order);
        continue;
      }

      final cached = await secureStorageService.getDeliveredAsset(order.externalOrderId);
      if (cached != null && cached['key'] != null && cached['key']!.isNotEmpty) {
        merged.add(order.copyWith(
          status: 'completed',
          fulfillmentStatus: 'ready',
          deliveredKey: cached['key'],
          deliveredUrl: cached['url'],
        ));
        continue;
      }

      if (order.id != null) {
        final cachedById = await secureStorageService.getDeliveredAsset(order.id.toString());
        if (cachedById != null && cachedById['key'] != null && cachedById['key']!.isNotEmpty) {
          merged.add(order.copyWith(
            status: 'completed',
            fulfillmentStatus: 'ready',
            deliveredKey: cachedById['key'],
            deliveredUrl: cachedById['url'],
          ));
          continue;
        }
      }

      merged.add(order);
    }
    return merged;
  }

  /// فحص تلقائي خفي للطلبات المعلقة وتحديثها حال اكتمالها لدى المزود
  void _syncPendingOrders(List<OrderModel> orders) {
    final pendingOrders = orders.where((o) => o.isProcessing && o.sellerOrderId != null).toList();
    if (pendingOrders.isEmpty) return;

    Future.microtask(() async {
      bool hasUpdates = false;
      final currentList = (state is OrdersLoaded)
          ? List<OrderModel>.from((state as OrdersLoaded).orders)
          : List<OrderModel>.from(orders);

      for (final pending in pendingOrders) {
        try {
          final refreshed = await orderRepository.refreshOrderStatus(pending);
          if (refreshed.isReady && refreshed.deliveredKey != null) {
            await secureStorageService.saveDeliveredAsset(
              refreshed.externalOrderId,
              refreshed.deliveredKey!,
              refreshed.deliveredUrl,
            );
            if (refreshed.id != null) {
              await secureStorageService.saveDeliveredAsset(
                refreshed.id.toString(),
                refreshed.deliveredKey!,
                refreshed.deliveredUrl,
              );
            }
            final idx = currentList.indexWhere((o) => o.externalOrderId == refreshed.externalOrderId);
            if (idx >= 0) {
              currentList[idx] = refreshed;
              hasUpdates = true;
            }
          }
        } catch (_) {}
      }

      if (hasUpdates && !isClosed) {
        emit(OrdersLoaded(currentList));
      }
    });
  }

  Future<void> loadOrders() async {
    emit(OrdersLoading());
    try {
      final deviceId = await secureStorageService.getOrCreateDeviceId();

      // إلغاء أي اشتراك Realtime سابق لمنع تكرار الـ listeners
      await _ordersSubscription?.cancel();

      // جلب فوري أولي لتقليل وقت الانتظار ودمج الكاش المحلي
      final initialList = await orderRepository.getOrdersByDevice(deviceId);
      final mergedInitial = await _mergeWithLocalCache(initialList);
      emit(OrdersLoaded(mergedInitial));

      // فحص خفي لأي طلبات معلقة
      _syncPendingOrders(mergedInitial);

      // بدء الاستماع اللحظي (Supabase Realtime Stream)
      _ordersSubscription = orderRepository
          .streamOrdersByDevice(deviceId)
          .listen((ordersList) async {
        final mergedList = await _mergeWithLocalCache(ordersList);
        emit(OrdersLoaded(mergedList));
      }, onError: (_) async {
        final fallbackList = await orderRepository.getOrdersByDevice(deviceId);
        final mergedFallback = await _mergeWithLocalCache(fallbackList);
        emit(OrdersLoaded(mergedFallback));
      });
    } catch (_) {
      emit(OrdersLoaded(const []));
    }
  }

  /// تحديث شامل لكافة الطلبات عند الضغط على زر التحديث أو السحب للأسفل
  Future<void> refreshAllOrders() async {
    try {
      final deviceId = await secureStorageService.getOrCreateDeviceId();
      final latestOrders = await orderRepository.getOrdersByDevice(deviceId);
      final baseList = await _mergeWithLocalCache(latestOrders);

      final updatedList = <OrderModel>[];
      for (final order in baseList) {
        if (order.isProcessing && order.sellerOrderId != null) {
          final refreshed = await orderRepository.refreshOrderStatus(order);
          if (refreshed.isReady && refreshed.deliveredKey != null) {
            await secureStorageService.saveDeliveredAsset(
              refreshed.externalOrderId,
              refreshed.deliveredKey!,
              refreshed.deliveredUrl,
            );
            if (refreshed.id != null) {
              await secureStorageService.saveDeliveredAsset(
                refreshed.id.toString(),
                refreshed.deliveredKey!,
                refreshed.deliveredUrl,
              );
            }
          }
          updatedList.add(refreshed);
        } else {
          updatedList.add(order);
        }
      }

      emit(OrdersLoaded(updatedList));
    } catch (e) {
      debugPrint('[OrdersCubit] refreshAllOrders error: $e');
      await loadOrders();
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
      if (updated.isReady && updated.deliveredKey != null) {
        await secureStorageService.saveDeliveredAsset(
          updated.externalOrderId,
          updated.deliveredKey!,
          updated.deliveredUrl,
        );
        if (updated.id != null) {
          await secureStorageService.saveDeliveredAsset(
            updated.id.toString(),
            updated.deliveredKey!,
            updated.deliveredUrl,
          );
        }
      }

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
