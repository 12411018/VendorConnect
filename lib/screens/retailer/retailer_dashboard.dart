import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vendorlink/config/map_config.dart';
import 'package:vendorlink/screens/auth/login_screen.dart';
import 'package:vendorlink/screens/retailer/delivery_page.dart';
import 'package:vendorlink/screens/retailer/models/retailer_product_ui_model.dart';
import 'package:vendorlink/screens/retailer/profile_page.dart';
import 'package:vendorlink/screens/retailer/tabs/retailer_cart_tab.dart';
import 'package:vendorlink/screens/retailer/tabs/retailer_orders_tab.dart';
import 'package:vendorlink/screens/retailer/tabs/retailer_products_tab.dart';
import 'package:vendorlink/screens/retailer/widgets/retailer_product_detail_sheet.dart';
import 'package:vendorlink/screens/retailer/widgets/vendorlink_payment_gateway_screen.dart';
import 'package:vendorlink/screens/wholesaler/widgets/order_route_map_screen.dart';
import 'package:vendorlink/services/auth_service.dart';

class RetailerDashboard extends StatefulWidget {
  const RetailerDashboard({super.key});

  @override
  State<RetailerDashboard> createState() => _RetailerDashboardState();
}

class _RetailerDashboardState extends State<RetailerDashboard> {
  static const double _marketplaceLat = MapConfig.marketplaceLat;
  static const double _marketplaceLng = MapConfig.marketplaceLng;

  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> _marketplaceProductsStream;
  late final Stream<List<Map<String, dynamic>>> _retailerOrdersStream;

  int _currentIndex = 0;
  String _searchQuery = '';
  String _categoryFilter = 'All';
  String _typeFilter = 'All';

  final Map<String, int> _cart = {};
  final Map<String, Map<String, dynamic>> _cartProducts = {};
  bool _isPlacingOrder = false;

  @override
  void initState() {
    super.initState();
    _marketplaceProductsStream = _authService.watchMarketplaceProducts();
    _retailerOrdersStream = _authService.watchRetailerOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titleForTab(_currentIndex))),
      drawer: _buildDrawer(context),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          RetailerProductsTab(
            productsStream: _marketplaceProductsStream,
            searchController: _searchController,
            searchQuery: _searchQuery,
            categoryFilter: _categoryFilter,
            typeFilter: _typeFilter,
            onSearchChanged: (value) {
              setState(() {
                _searchQuery = value.trim().toLowerCase();
              });
            },
            onCategoryChanged: (value) {
              setState(() {
                _categoryFilter = value;
              });
            },
            onTypeChanged: (value) {
              setState(() {
                _typeFilter = value;
              });
            },
            onRefresh: () => _authService.fetchMarketplaceProducts(),
            onOpenProductDetails: (product) async {
              final productModel = RetailerProductUiModel.fromMap(product);
              await showRetailerProductDetails(
                context: context,
                product: productModel,
                onAddToCart: () {
                  final productId = (product['id'] ?? '').toString();
                  if (productId.isEmpty) {
                    return;
                  }

                  if (RetailerProductUiModel.fromMap(product).stockQty <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('This product is out of stock.'),
                      ),
                    );
                    return;
                  }

                  setState(() {
                    _cart[productId] = (_cart[productId] ?? 0) + 1;
                    _cartProducts[productId] = product;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Added to cart.')),
                  );
                },
                onRate: (rating, review) async {
                  await _authService.submitProductRating(
                    productId: productModel.id,
                    rating: rating,
                    review: review,
                  );
                },
              );
            },
            onAddToCart: (product) {
              final productId = (product['id'] ?? '').toString();
              if (productId.isEmpty) {
                return;
              }

              if (RetailerProductUiModel.fromMap(product).stockQty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('This product is out of stock.'),
                  ),
                );
                return;
              }

              setState(() {
                _cart[productId] = (_cart[productId] ?? 0) + 1;
                _cartProducts[productId] = product;
              });

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Added to cart.')));
            },
          ),
          RetailerCartTab(
            cart: _cart,
            cartProducts: _cartProducts,
            isPlacingOrder: _isPlacingOrder,
            onIncrement: (productId) {
              setState(() {
                _cart[productId] = (_cart[productId] ?? 0) + 1;
              });
            },
            onDecrement: (productId) {
              setState(() {
                final current = _cart[productId] ?? 0;
                if (current <= 1) {
                  _cart.remove(productId);
                  _cartProducts.remove(productId);
                } else {
                  _cart[productId] = current - 1;
                }
              });
            },
            onPlaceOrder: () async {
              if (_cart.isEmpty || _isPlacingOrder) {
                return;
              }

              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              setState(() {
                _isPlacingOrder = true;
              });

              try {
                final totalPayable = _cart.entries.fold<double>(0, (
                  sum,
                  entry,
                ) {
                  final product = _cartProducts[entry.key] ?? const {};
                  final unitPrice = _toDoubleOrNull(product['price']) ?? 0;
                  return sum + (unitPrice * entry.value);
                });

                final paymentResult = await navigator
                    .push<VendorlinkPaymentResult>(
                      MaterialPageRoute(
                        builder: (_) => VendorlinkPaymentGatewayScreen(
                          amount: totalPayable,
                        ),
                      ),
                    );

                if (!context.mounted) {
                  return;
                }

                if (paymentResult == null || !paymentResult.success) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Payment cancelled. Order not placed.'),
                    ),
                  );
                  return;
                }

                final location = await _capturePaymentLocationBestEffort();
                final paymentLat = location?.latitude ?? _marketplaceLat;
                final paymentLng = location?.longitude ?? _marketplaceLng;
                final groupedItemsByVendor =
                    <String, List<Map<String, dynamic>>>{};

                for (final entry in _cart.entries) {
                  final product = _cartProducts[entry.key];
                  if (product == null) {
                    continue;
                  }

                  final vendorId = (product['vendor_id'] ?? '')
                      .toString()
                      .trim();
                  if (vendorId.isEmpty) {
                    continue;
                  }

                  final item = Map<String, dynamic>.from(product);
                  item['quantity'] = entry.value;
                  groupedItemsByVendor.putIfAbsent(
                    vendorId,
                    () => <Map<String, dynamic>>[],
                  );
                  groupedItemsByVendor[vendorId]!.add(item);
                }

                if (groupedItemsByVendor.isEmpty) {
                  throw Exception('No valid products found in cart.');
                }

                final resolvedAddress = await _shippingAddress();
                final resolvedPhone = await _shippingPhone();

                for (final items in groupedItemsByVendor.values) {
                  await _authService.placeRetailerOrder(
                    items: items,
                    shippingName: _shippingName(),
                    shippingAddress: resolvedAddress,
                    shippingPhone: resolvedPhone,
                    paymentLat: paymentLat,
                    paymentLng: paymentLng,
                    marketplaceLat: _marketplaceLat,
                    marketplaceLng: _marketplaceLng,
                  );
                }

                if (!context.mounted) {
                  return;
                }

                setState(() {
                  _cart.clear();
                  _cartProducts.clear();
                  _currentIndex = 2;
                });

                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Payment successful${paymentResult.paymentId == null ? '' : ' (${paymentResult.paymentId})'}. Order placed.',
                    ),
                  ),
                );
              } on Exception catch (error) {
                if (!context.mounted) {
                  return;
                }

                final friendlyMessage = error
                    .toString()
                    .replaceFirst('Exception: ', '')
                    .trim();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      friendlyMessage.isEmpty
                          ? 'Order failed.'
                          : friendlyMessage,
                    ),
                  ),
                );
              } finally {
                if (context.mounted) {
                  setState(() {
                    _isPlacingOrder = false;
                  });
                }
              }
            },
          ),
          RetailerOrdersTab(
            ordersStream: _retailerOrdersStream,
            marketplaceLat: _marketplaceLat,
            marketplaceLng: _marketplaceLng,
            onOpenMap:
                ({
                  required paymentLat,
                  required paymentLng,
                  required marketplaceLat,
                  required marketplaceLng,
                }) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OrderRouteMapScreen(
                        paymentLat: paymentLat,
                        paymentLng: paymentLng,
                        marketplaceLat: marketplaceLat,
                        marketplaceLng: marketplaceLng,
                      ),
                    ),
                  );
                },
            onConfirmDelivery: (orderId) {
              return _authService.updateOrderStatusForRetailer(
                orderId: orderId,
                status: 'delivered',
              );
            },
          ),
          const RetailerDeliveryPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            activeIcon: Icon(Icons.local_shipping),
            label: 'Delivery',
          ),
        ],
      ),
    );
  }

  String _titleForTab(int index) {
    switch (index) {
      case 1:
        return 'My Cart';
      case 2:
        return 'My Orders';
      case 3:
        return 'Delivery';
      default:
        return 'Retailer Dashboard';
    }
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF6366F1)),
            accountName: Text(
              _drawerAccountName(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(_drawerAccountEmail()),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.store, size: 30, color: Colors.black),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('Browse Products'),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _currentIndex = 0;
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.shopping_cart_outlined),
            title: const Text('My Cart'),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _currentIndex = 1;
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('My Orders'),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _currentIndex = 2;
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.local_shipping_outlined),
            title: const Text('Delivery'),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _currentIndex = 3;
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await _authService.logout();
              if (!context.mounted) {
                return;
              }
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  double? _toDoubleOrNull(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse((value ?? '').toString());
  }

  Future<Position?> _capturePaymentLocationBestEffort() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }

  String _shippingName() {
    final user = _authService.currentSession?.user;
    final metadataName = user?.userMetadata?['name']?.toString().trim();
    final fallback = user?.email?.split('@').first.trim();
    return (metadataName?.isNotEmpty == true
            ? metadataName
            : fallback?.isNotEmpty == true
            ? fallback
            : 'Retailer')
        .toString();
  }

  String _drawerAccountName() {
    final user = _authService.currentSession?.user;
    final metadataName = user?.userMetadata?['name']?.toString().trim();
    if (metadataName != null && metadataName.isNotEmpty) {
      return metadataName;
    }
    return 'Retail Account';
  }

  String _drawerAccountEmail() {
    final email = _authService.currentSession?.user.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email;
    }
    return 'No email found';
  }

  Future<String> _shippingAddress() async {
    final location = await _authService.fetchCurrentRetailerLocation();
    if (location.isNotEmpty) {
      return location;
    }
    return 'Address not available';
  }

  Future<String> _shippingPhone() async {
    final phone = await _authService.fetchCurrentUserPhone();
    if (phone.isNotEmpty) {
      return phone;
    }
    // Fallback to auth metadata
    final metadataPhone = _authService.currentSession?.user
        .userMetadata?['phone']
        ?.toString()
        .trim();
    return (metadataPhone?.isNotEmpty == true) ? metadataPhone! : '';
  }
}
