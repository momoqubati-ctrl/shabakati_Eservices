import '../../data/models/cart_item_model.dart';

class CartState {
  final List<CartItemModel> items;

  CartState({this.items = const []});

  int get totalCount => items.fold(0, (sum, item) => sum + item.quantity);
  int get totalCents => items.fold(0, (sum, item) => sum + item.totalCents);
  double get totalAmount => totalCents / 100.0;
  String get displayTotal => '\$${totalAmount.toStringAsFixed(2)} USD';
  bool get isEmpty => items.isEmpty;

  CartState copyWith({List<CartItemModel>? items}) {
    return CartState(items: items ?? this.items);
  }
}
