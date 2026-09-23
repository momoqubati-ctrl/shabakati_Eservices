import '../../data/models/order_model.dart';

abstract class OrdersState {}

class OrdersInitial extends OrdersState {}

class OrdersLoading extends OrdersState {}

class OrdersLoaded extends OrdersState {
  final List<OrderModel> orders;
  OrdersLoaded(this.orders);
}

class OrderSubmitting extends OrdersState {}

class OrderSubmitSuccess extends OrdersState {
  final OrderModel order;
  final String message;
  final bool isInstantDelivery;

  OrderSubmitSuccess({
    required this.order,
    required this.message,
    required this.isInstantDelivery,
  });
}

class OrderSubmitError extends OrdersState {
  final String errorMessage;
  OrderSubmitError(this.errorMessage);
}
