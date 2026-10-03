import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/secure_storage_service.dart';
import '../../data/models/cart_item_model.dart';
import '../../data/models/order_model.dart';
import '../../data/models/user_account_model.dart';
import '../../data/repositories/order_repository.dart';
import 'orders_state.dart';

class OrdersCubit extends Cubit<OrdersState> {
  final IOrderRepository orderRepository;
  final SecureStorageService secureStorageService;
  StreamSubscription<List<OrderModel>>? _ordersSubscription;
  UserAccountModel? _currentUser;

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

  /// تحميل الطلبات الخاصة بمستخدم معين فقط لضمان العزل التام للبيانات
  Future<void> loadOrdersForUser(UserAccountModel user) async {
    _currentUser = user;
    emit(OrdersLoading());
    try {
      await _ordersSubscription?.cancel();

      final initialList = await orderRepository.getOrdersForUser(user);
      final mergedInitial = await _mergeWithLocalCache(initialList);
      emit(OrdersLoaded(mergedInitial));

      _syncPendingOrders(mergedInitial);

      _ordersSubscription = orderRepository
          .streamOrdersForUser(user)
          .listen((ordersList) async {
        final mergedList = await _mergeWithLocalCache(ordersList);
        emit(OrdersLoaded(mergedList));
      }, onError: (_) async {
        final fallbackList = await orderRepository.getOrdersForUser(user);
        final mergedFallback = await _mergeWithLocalCache(fallbackList);
        emit(OrdersLoaded(mergedFallback));
      });
    } catch (e) {
      debugPrint('[OrdersCubit] loadOrdersForUser error: $e');
      emit(OrdersLoaded(const []));
    }
  }

  /// مسح كافة الطلبات من الذاكرة والشاشات عند تسجيل الخروج النهائي
  Future<void> clearOrders() async {
    _currentUser = null;
    await _ordersSubscription?.cancel();
    _ordersSubscription = null;
    emit(OrdersLoaded(const []));
  }

  Future<void> loadOrders() async {
    final activeUser = await secureStorageService.getActiveUser();
    if (activeUser != null) {
      await loadOrdersForUser(activeUser);
      return;
    }

    // إذا لم يكن هناك مستخدم مسجل الدخول، لا يتم عرض أي طلبات لحماية الخصوصية
    await clearOrders();
  }

  /// تحديث شامل لكافة الطلبات الخاصة بالمستخدم المسجل حالياً
  Future<void> refreshAllOrders() async {
    try {
      var user = _currentUser;
      user ??= await secureStorageService.getActiveUser();
      if (user == null) {
        emit(OrdersLoaded(const []));
        return;
      }
      _currentUser = user;

      final latestOrders = await orderRepository.getOrdersForUser(user);
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
    String? paymentReference,
    String? paymentMethod,
    String? walletName,
    int? userId,
    String? accountNumber,
  }) async {
    emit(OrderSubmitting());
    try {
      final deviceId = await secureStorageService.getOrCreateDeviceId();
      if (telegramUser != null && telegramUser.isNotEmpty) {
        await secureStorageService.saveTelegramUser(telegramUser);
      }

      final resolvedUserId = userId ?? _currentUser?.id;
      final resolvedAccountNumber = accountNumber ?? _currentUser?.accountNumber;

      final result = await orderRepository.submitOrder(
        items: items,
        deviceId: deviceId,
        telegramUser: telegramUser,
        contactPhone: contactPhone,
        contactEmail: contactEmail,
        paymentId: paymentId,
        paymentReference: paymentReference,
        paymentMethod: paymentMethod,
        walletName: walletName,
        userId: resolvedUserId,
        accountNumber: resolvedAccountNumber,
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
        paymentId: paymentId,
        paymentReference: paymentReference ?? paymentId,
        paymentMethod: paymentMethod ?? 'المحافظ الإلكترونية',
        walletName: walletName,
        userId: userId ?? _currentUser?.id,
        accountNumber: accountNumber ?? _currentUser?.accountNumber,
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
