import 'product_model.dart';

class CartItemModel {
  final ProductModel product;
  int quantity;

  CartItemModel({
    required this.product,
    this.quantity = 1,
  });

  int get totalCents => product.sellerPrice.amountCents * quantity;
  double get totalAmount => totalCents / 100.0;
  String get displayTotal => '\$${totalAmount.toStringAsFixed(2)} ${product.sellerPrice.currency}';

  CartItemModel copyWith({
    ProductModel? product,
    int? quantity,
  }) {
    return CartItemModel(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}
