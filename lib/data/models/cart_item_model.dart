import 'package:intl/intl.dart';
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

  double totalAmountYer({double exchangeRate = 535.0}) {
    return product.getFinalPriceYer(exchangeRate: exchangeRate) * quantity;
  }

  String displayTotalYer({double exchangeRate = 535.0}) {
    final yer = totalAmountYer(exchangeRate: exchangeRate);
    final formatter = NumberFormat('#,###');
    return '${formatter.format(yer)} ر.ي';
  }

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
