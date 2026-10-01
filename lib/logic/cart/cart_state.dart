import 'package:intl/intl.dart';
import '../../data/models/cart_item_model.dart';

class CartState {
  final List<CartItemModel> items;

  CartState({this.items = const []});

  int get totalCount => items.fold(0, (sum, item) => sum + item.quantity);
  int get totalCents => items.fold(0, (sum, item) => sum + item.totalCents);
  double get totalAmount => totalCents / 100.0;
  String get displayTotal => '\$${totalAmount.toStringAsFixed(2)} USD';

  double totalAmountYer({double exchangeRate = 535.0}) {
    return items.fold(0.0, (sum, item) => sum + item.totalAmountYer(exchangeRate: exchangeRate));
  }

  String displayTotalYer({double exchangeRate = 535.0}) {
    final yer = totalAmountYer(exchangeRate: exchangeRate);
    final formatter = NumberFormat('#,###');
    return '${formatter.format(yer)} ر.ي';
  }

  double totalRetailUsd({double exchangeRate = 535.0}) {
    final rate = (exchangeRate > 0) ? exchangeRate : 535.0;
    return totalAmountYer(exchangeRate: rate) / rate;
  }

  String displayTotalRetailUsd({double exchangeRate = 535.0}) {
    final usd = totalRetailUsd(exchangeRate: exchangeRate);
    return '\$${usd.toStringAsFixed(2)} USD';
  }

  bool get isEmpty => items.isEmpty;

  CartState copyWith({List<CartItemModel>? items}) {
    return CartState(items: items ?? this.items);
  }
}
