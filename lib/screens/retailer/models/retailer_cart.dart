import 'package:flutter/foundation.dart';

class RetailerCart extends ChangeNotifier {
  final Map<String, int> _cart = {};
  final Map<String, Map<String, dynamic>> _cartProducts = {};
  bool _isPlacingOrder = false;

  Map<String, int> get cart => Map.unmodifiable(_cart);
  Map<String, Map<String, dynamic>> get cartProducts =>
      Map.unmodifiable(_cartProducts);
  bool get isPlacingOrder => _isPlacingOrder;
  bool get isEmpty => _cart.isEmpty;

  void addToCart(String productId, Map<String, dynamic> product) {
    _cart[productId] = (_cart[productId] ?? 0) + 1;
    _cartProducts[productId] = product;
    notifyListeners();
  }

  void increment(String productId) {
    _cart[productId] = (_cart[productId] ?? 0) + 1;
    notifyListeners();
  }

  void decrement(String productId) {
    final current = _cart[productId] ?? 0;
    if (current <= 1) {
      _cart.remove(productId);
      _cartProducts.remove(productId);
    } else {
      _cart[productId] = current - 1;
    }
    notifyListeners();
  }

  void clear() {
    _cart.clear();
    _cartProducts.clear();
    notifyListeners();
  }

  set isPlacingOrder(bool value) {
    _isPlacingOrder = value;
    notifyListeners();
  }
}
