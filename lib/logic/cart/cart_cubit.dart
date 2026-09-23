import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/cart_item_model.dart';
import '../../data/models/product_model.dart';
import 'cart_state.dart';

class CartCubit extends Cubit<CartState> {
  CartCubit() : super(CartState());

  void addProduct(ProductModel product, {int quantity = 1}) {
    final currentList = List<CartItemModel>.from(state.items);
    final index = currentList.indexWhere((element) => element.product.id == product.id);

    if (index >= 0) {
      currentList[index].quantity += quantity;
    } else {
      currentList.add(CartItemModel(product: product, quantity: quantity));
    }

    emit(state.copyWith(items: currentList));
  }

  void updateQuantity(int productId, int delta) {
    final currentList = List<CartItemModel>.from(state.items);
    final index = currentList.indexWhere((element) => element.product.id == productId);

    if (index >= 0) {
      final newQty = currentList[index].quantity + delta;
      if (newQty <= 0) {
        currentList.removeAt(index);
      } else {
        currentList[index].quantity = newQty;
      }
      emit(state.copyWith(items: currentList));
    }
  }

  void removeItem(int productId) {
    final currentList = List<CartItemModel>.from(state.items);
    currentList.removeWhere((element) => element.product.id == productId);
    emit(state.copyWith(items: currentList));
  }

  void clearCart() {
    emit(CartState());
  }
}
