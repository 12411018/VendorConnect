import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vendorlink/screens/auth/login_screen.dart';
import 'package:vendorlink/screens/retailer/delivery_page.dart';
import 'package:vendorlink/screens/retailer/models/retailer_product_ui_model.dart';
import 'package:vendorlink/screens/retailer/profile_page.dart';
import 'package:vendorlink/screens/retailer/widgets/retailer_order_status_chip.dart';
import 'package:vendorlink/screens/retailer/widgets/retailer_product_card.dart';
import 'package:vendorlink/screens/retailer/widgets/retailer_product_detail_sheet.dart';
import 'package:vendorlink/screens/retailer/widgets/retailer_products_empty_state.dart';
import 'package:vendorlink/screens/retailer/widgets/retailer_products_header.dart';
import 'package:vendorlink/screens/retailer/widgets/vendorlink_payment_gateway_screen.dart';
import 'package:vendorlink/screens/wholesaler/widgets/order_route_map_screen.dart';
import 'package:vendorlink/config/map_config.dart';
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
  final Set<String> _optimisticallyDeliveredOrderIds = <String>{};
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

  void _addToCart(Map<String, dynamic> product) {
    final productId = (product['id'] ?? '').toString();
    if (productId.isEmpty) {
      return;
    }

    if (RetailerProductUiModel.fromMap(product).stockQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This product is out of stock.')),
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
  }

  void _incrementCartItem(String productId) {
    final product = _cartProducts[productId] ?? const {};
    final stockQty = RetailerProductUiModel.fromMap(product).stockQty;
    final currentQty = _cart[productId] ?? 0;

    if (stockQty > 0 && currentQty >= stockQty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Only $stockQty unit(s) available in stock.')),
      );
      return;
    }

    setState(() {
      _cart[productId] = currentQty + 1;
    });
  }

  void _decrementCartItem(String productId) {
    setState(() {
      final current = _cart[productId] ?? 0;
      if (current <= 1) {
        _cart.remove(productId);
        _cartProducts.remove(productId);
      } else {
        _cart[productId] = current - 1;
      }
    });
  }

  Future<void> _placeOrder() async {
    if (_cart.isEmpty || _isPlacingOrder) {
      return;
    }

    setState(() {
      _isPlacingOrder = true;
    });

    try {
      final groupedItemsByVendor = <String, List<Map<String, dynamic>>>{};

      for (final entry in _cart.entries) {
        final product = _cartProducts[entry.key];
        if (product == null) {
          continue;
        }

        final vendorId = (product['vendor_id'] ?? '').toString().trim();
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

      // Calculate total amount
      double totalAmount = 0.0;
      for (final items in groupedItemsByVendor.values) {
        for (final item in items) {
          final price = (item['price'] ?? 0.0) as num;
          final quantity = _cart[item['id']] ?? 0;
          totalAmount += (price.toDouble() * quantity);
        }
      }

      if (!mounted) {
        setState(() => _isPlacingOrder = false);
        return;
      }

      // Show payment gateway screen
      final paymentResult = await Navigator.of(context)
          .push<VendorlinkPaymentResult?>(
            MaterialPageRoute(
              builder: (context) =>
                  VendorlinkPaymentGatewayScreen(amount: totalAmount),
            ),
          );

      if (!mounted) {
        return;
      }

      // If payment was cancelled or failed, don't proceed
      if (paymentResult == null || !paymentResult.success) {
        if (paymentResult == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Payment cancelled.')));
        }
        return;
      }

      // Payment successful, now create orders
      final location = await _capturePaymentLocationBestEffort();
      final paymentLat = location?.latitude ?? _marketplaceLat;
      final paymentLng = location?.longitude ?? _marketplaceLng;

      for (final items in groupedItemsByVendor.values) {
        await _authService.placeRetailerOrder(
          items: items,
          shippingName: _shippingName(),
          shippingAddress: _shippingAddress(),
          shippingPhone: _shippingPhone(),
          paymentLat: paymentLat,
          paymentLng: paymentLng,
          marketplaceLat: _marketplaceLat,
          marketplaceLng: _marketplaceLng,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _cart.clear();
        _cartProducts.clear();
        _currentIndex = 2;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Payment successful! Order placed.'),
          backgroundColor: Colors.green,
        ),
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      final friendlyMessage = error
          .toString()
          .replaceFirst('Exception: ', '')
          .trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyMessage.isEmpty ? 'Order failed.' : friendlyMessage,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPlacingOrder = false;
        });
      }
    }
  }

  Future<void> _showProductDetails(Map<String, dynamic> product) async {
    final productModel = RetailerProductUiModel.fromMap(product);
    await showRetailerProductDetails(
      context: context,
      product: productModel,
      onAddToCart: () => _addToCart(product),
      onRate: (rating, review) async {
        await _authService.submitProductRating(
          productId: productModel.id,
          rating: rating,
          review: review,
        );
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks for your rating.')),
        );
      },
    );
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

  String _shippingAddress() {
    return 'Flat 12, Blue Horizon Apartments, MG Road, Pune, Maharashtra';
  }

  String _shippingPhone() {
    return '9876543210';
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

  List<Map<String, dynamic>> _extractOrderItems(Map<String, dynamic> order) {
    final rawItems = order['order_items'];
    if (rawItems is List) {
      return rawItems.whereType<Map<String, dynamic>>().toList(growable: false);
    }

    final productName = (order['product_name'] ?? order['name'] ?? '')
        .toString();
    if (productName.isEmpty) {
      return const [];
    }

    return <Map<String, dynamic>>[
      {
        'product_name': productName,
        'quantity': order['quantity'] ?? 1,
        'price': order['total_price'] ?? order['unit_price'] ?? 0,
        'total_price': order['total_price'] ?? order['total_amount'] ?? 0,
        'sku': order['sku'] ?? '-',
        'category': order['category'] ?? '-',
        'type': order['type'] ?? '-',
      },
    ];
  }

  List<Map<String, dynamic>> _dedupeOrders(List<Map<String, dynamic>> orders) {
    final seen = <String>{};
    final deduped = <Map<String, dynamic>>[];

    for (final order in orders) {
      final key = (order['order_number'] ?? order['id'] ?? '').toString();
      if (key.isEmpty) {
        deduped.add(order);
        continue;
      }
      if (seen.add(key)) {
        deduped.add(order);
      }
    }

    deduped.sort((left, right) {
      int priority(Map<String, dynamic> order) {
        final status = _effectiveOrderStatus(order);
        if (status == 'processing' || status == 'accepted') {
          return 0;
        }
        if (status == 'pending') {
          return 1;
        }
        if (status == 'delivered') {
          return 2;
        }
        return 3;
      }

      final byPriority = priority(left).compareTo(priority(right));
      if (byPriority != 0) {
        return byPriority;
      }

      final leftCreated = (left['created_at'] ?? '').toString();
      final rightCreated = (right['created_at'] ?? '').toString();
      return rightCreated.compareTo(leftCreated);
    });

    return deduped;
  }

  String _effectiveOrderStatus(Map<String, dynamic> order) {
    final retailerConfirmedAt = (order['retailer_confirmed_at'] ?? '')
        .toString()
        .trim();
    if (retailerConfirmedAt.isNotEmpty ||
        _optimisticallyDeliveredOrderIds.contains(
          (order['id'] ?? '').toString(),
        )) {
      return 'delivered';
    }

    final raw = (order['status'] ?? 'pending').toString().toLowerCase();
    if (raw == 'completed' || raw == 'fulfilled' || raw == 'done') {
      return 'delivered';
    }
    return raw;
  }

  String _formatItemLabel(Map<String, dynamic> item) {
    final product = item['product'];
    final productName = product is Map<String, dynamic>
        ? (product['name'] ?? 'Product').toString()
        : (item['product_name'] ?? 'Product').toString();
    final quantity = (item['quantity'] ?? 1).toString();
    final price = (item['price'] ?? item['total_price'] ?? 0).toString();
    return '$productName x$quantity • ₹$price';
  }

  String _itemImage(Map<String, dynamic> item) {
    final product = item['product'];
    if (product is Map<String, dynamic>) {
      return (product['image_url'] ?? '').toString().trim();
    }
    return (item['image_url'] ?? '').toString().trim();
  }

  double? _toDoubleOrNull(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse((value ?? '').toString());
  }

  Widget _buildOrderMessage(String status) {
    final normalized = status.toLowerCase();
    if (normalized == 'processing' || normalized == 'accepted') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF2B1B0F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEA580C)),
        ),
        child: const Text(
          'Delivery partner is on the way to your location.',
          style: TextStyle(
            color: Color(0xFFFED7AA),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (normalized == 'delivered') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF052E16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF16A34A)),
        ),
        child: const Text(
          'Delivery completed successfully.',
          style: TextStyle(
            color: Color(0xFFBBF7D0),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (normalized == 'rejected') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1111),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF7F1D1D)),
        ),
        child: const Text(
          'Order canceled by wholesaler.',
          style: TextStyle(
            color: Color(0xFFFCA5A5),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: const Text(
        'Order placed. Waiting for wholesaler dispatch.',
        style: TextStyle(color: Color(0xFFD1D5DB), fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titleForTab(_currentIndex))),
      drawer: _buildDrawer(context),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildProductsTab(),
          _buildCartTab(),
          _buildOrdersTab(),
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
        backgroundColor: const Color(0xFF0F172A),
        selectedItemColor: const Color(0xFF38BDF8),
        unselectedItemColor: const Color(0xFF94A3B8),
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
          const UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF6366F1)),
            accountName: Text(
              'Retail Account',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text('retailer@vendorlink.app'),
            currentAccountPicture: CircleAvatar(
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
                MaterialPageRoute(
                  builder: (_) => const ProfilePage(
                    name: 'Retail Account',
                    email: 'retailer@vendorlink.app',
                    role: 'Retailer',
                    avatarIcon: Icons.store,
                  ),
                ),
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

  Widget _buildProductsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _marketplaceProductsStream,
      builder: (context, snapshot) {
        final products = snapshot.data ?? const <Map<String, dynamic>>[];
        final categories = _extractFilterOptions(products, 'category');
        final types = _extractFilterOptions(products, 'type');
        final effectiveCategory = categories.contains(_categoryFilter)
            ? _categoryFilter
            : 'All';
        final effectiveType = types.contains(_typeFilter) ? _typeFilter : 'All';
        final filtered = _filterProducts(
          products,
          selectedCategory: effectiveCategory,
          selectedType: effectiveType,
        );
        final hasActiveFilters =
            _searchQuery.isNotEmpty ||
            effectiveCategory != 'All' ||
            effectiveType != 'All';
        final visibleProducts =
            !hasActiveFilters && filtered.isEmpty && products.isNotEmpty
            ? products
            : filtered;
        final summaryText =
            snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData
            ? 'Loading products...'
            : 'Showing ${visibleProducts.length} product${visibleProducts.length == 1 ? '' : 's'}';

        Widget content;
        if (snapshot.hasError) {
          content = Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(snapshot.error.toString()),
            ),
          );
        } else if (snapshot.connectionState == ConnectionState.waiting &&
            products.isEmpty) {
          content = const Center(child: CircularProgressIndicator());
        } else {
          content = _buildProductList(products, visibleProducts);
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: RetailerProductsHeader(
                summaryText: summaryText,
                productCount: visibleProducts.length,
                searchController: _searchController,
                categoryValue: effectiveCategory,
                categoryOptions: categories,
                typeValue: effectiveType,
                typeOptions: types,
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
              ),
            ),
            Expanded(child: content),
          ],
        );
      },
    );
  }

  Widget _buildProductList(
    List<Map<String, dynamic>> allProducts,
    List<Map<String, dynamic>> visibleProducts,
  ) {
    final hasFilters =
        _searchQuery.isNotEmpty ||
        _categoryFilter != 'All' ||
        _typeFilter != 'All';
    final productsToRender = visibleProducts.isNotEmpty
        ? visibleProducts
        : allProducts;

    if (allProducts.isEmpty) {
      return const RetailerProductsEmptyState();
    }

    return Column(
      children: [
        if (hasFilters && visibleProducts.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'No exact matches for the current filters. Showing all products so you can verify the data.',
                style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12),
              ),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width >= 1100
                  ? 3
                  : width >= 720
                  ? 2
                  : 1;

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: crossAxisCount == 1 ? 470 : 520,
                ),
                itemCount: productsToRender.length,
                itemBuilder: (context, index) {
                  final product = productsToRender[index];
                  final productId = (product['id'] ?? '').toString();
                  final productModel = RetailerProductUiModel.fromMap(product);
                  return RetailerProductCard(
                    product: productModel,
                    onTap: () => _showProductDetails(product),
                    onAddToCart: productId.isEmpty
                        ? null
                        : () => _addToCart(product),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCartTab() {
    if (_cart.isEmpty) {
      return const Center(child: Text('Your cart is empty.'));
    }

    final cartEntries = _cart.entries.toList();

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cartEntries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final entry = cartEntries[index];
              final product = _cartProducts[entry.key] ?? const {};
              final name = (product['name'] ?? 'Product').toString();
              final price = (product['price'] ?? '0').toString();
              final image = (product['image_url'] ?? '').toString().trim();

              return Card(
                color: const Color(0xFF111827),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: image.isEmpty
                            ? Container(
                                width: 64,
                                height: 64,
                                color: const Color(0xFF1E293B),
                                child: const Icon(Icons.image_outlined),
                              )
                            : Image.network(
                                image,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 64,
                                  height: 64,
                                  color: const Color(0xFF1E293B),
                                  child: const Icon(Icons.image_not_supported),
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFF8FAFC),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Price: ₹$price',
                              style: const TextStyle(color: Color(0xFFCBD5E1)),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _decrementCartItem(entry.key),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('${entry.value}'),
                          IconButton(
                            onPressed: () => _incrementCartItem(entry.key),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isPlacingOrder ? null : _placeOrder,
              icon: _isPlacingOrder
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shopping_bag_outlined),
              label: Text(_isPlacingOrder ? 'Placing...' : 'Pay & Place Order'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _retailerOrdersStream,
      builder: (context, snapshot) {
        final orders = _dedupeOrders(snapshot.data ?? const []);

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(snapshot.error.toString()),
            ),
          );
        }

        if (orders.isEmpty) {
          return const Center(child: Text('No orders placed yet.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final order = orders[index];
            final orderNumber = (order['order_number'] ?? order['id'] ?? '-')
                .toString();
            final shippingName = (order['shipping_name'] ?? 'Retailer')
                .toString();
            final shippingAddress =
                (order['shipping_address'] ?? 'Fake address').toString();
            final status = (order['status'] ?? 'pending').toString();
            final totalAmount =
                (order['total_amount'] ?? order['total_price'] ?? 0).toString();
            final items = _extractOrderItems(order);
            final orderId = (order['id'] ?? '').toString();
            final isOptimisticallyDelivered = _optimisticallyDeliveredOrderIds
                .contains(orderId);
            final effectiveStatus = _effectiveOrderStatus(order);
            final paymentLat =
                _toDoubleOrNull(order['payment_lat']) ?? _marketplaceLat;
            final paymentLng =
                _toDoubleOrNull(order['payment_lng']) ?? _marketplaceLng;
            final marketplaceLat =
                _toDoubleOrNull(order['marketplace_lat']) ?? _marketplaceLat;
            final marketplaceLng =
                _toDoubleOrNull(order['marketplace_lng']) ?? _marketplaceLng;

            return Card(
              color: const Color(0xFF111827),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order #$orderNumber',
                                style: const TextStyle(
                                  color: Color(0xFFF8FAFC),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Deliver to: $shippingName',
                                style: const TextStyle(
                                  color: Color(0xFFCBD5E1),
                                ),
                              ),
                              Text(
                                shippingAddress,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        RetailerOrderStatusChip(status: effectiveStatus),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Total amount: ₹$totalAmount',
                      style: const TextStyle(
                        color: Color(0xFF93C5FD),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (items.isNotEmpty) ...[
                      const Text(
                        'Items',
                        style: TextStyle(
                          color: Color(0xFFE5E7EB),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...items
                          .take(4)
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _itemImage(item).isEmpty
                                        ? Container(
                                            width: 34,
                                            height: 34,
                                            color: const Color(0xFF1E293B),
                                            child: const Icon(
                                              Icons.image_outlined,
                                              size: 16,
                                            ),
                                          )
                                        : Image.network(
                                            _itemImage(item),
                                            width: 34,
                                            height: 34,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                                  width: 34,
                                                  height: 34,
                                                  color: const Color(
                                                    0xFF1E293B,
                                                  ),
                                                  child: const Icon(
                                                    Icons.broken_image,
                                                    size: 16,
                                                  ),
                                                ),
                                          ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _formatItemLabel(item),
                                      style: const TextStyle(
                                        color: Color(0xFFD1D5DB),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      if (items.length > 4)
                        Text(
                          '+ ${items.length - 4} more items',
                          style: const TextStyle(color: Color(0xFF9CA3AF)),
                        ),
                    ],
                    const SizedBox(height: 12),
                    _buildOrderMessage(effectiveStatus),
                    if (effectiveStatus == 'processing' ||
                        effectiveStatus == 'accepted') ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await _authService.updateOrderStatusForRetailer(
                                orderId: orderId,
                                status: 'delivered',
                              );
                              if (!mounted) {
                                return;
                              }
                              setState(() {
                                _optimisticallyDeliveredOrderIds.add(orderId);
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Delivery marked as completed.',
                                  ),
                                ),
                              );
                            } catch (error) {
                              if (!mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Confirmation failed: ${error.toString().replaceFirst('Exception: ', '')}',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Confirm Delivery Received'),
                        ),
                      ),
                    ],
                    if (effectiveStatus != 'delivered') ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
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
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Track Delivery on Map'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<String> _extractFilterOptions(
    List<Map<String, dynamic>> products,
    String field,
  ) {
    final values = <String>{'All'};
    for (final product in products) {
      final entry = (product[field] ?? '').toString().trim();
      if (entry.isNotEmpty) {
        values.add(entry);
      }
    }
    return values.toList();
  }

  List<Map<String, dynamic>> _filterProducts(
    List<Map<String, dynamic>> products, {
    required String selectedCategory,
    required String selectedType,
  }) {
    return products.where((product) {
      final name = (product['name'] ?? '').toString().toLowerCase();
      final category = (product['category'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final type = (product['type'] ?? '').toString().trim().toLowerCase();
      final requestedCategory = selectedCategory.trim().toLowerCase();
      final requestedType = selectedType.trim().toLowerCase();

      final matchesSearch =
          _searchQuery.isEmpty ||
          name.contains(_searchQuery) ||
          category.contains(_searchQuery) ||
          type.contains(_searchQuery);
      final matchesCategory =
          requestedCategory == 'all' || category == requestedCategory;
      final matchesType = requestedType == 'all' || type == requestedType;

      return matchesSearch && matchesCategory && matchesType;
    }).toList();
  }
}
