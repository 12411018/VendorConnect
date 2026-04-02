import 'package:flutter/material.dart';
import 'package:vendorlink/screens/auth/login_screen.dart';
import 'package:vendorlink/screens/retailer/models/retailer_product_ui_model.dart';
import 'package:vendorlink/screens/retailer/profile_page.dart';
import 'package:vendorlink/screens/retailer/widgets/retailer_order_status_chip.dart';
import 'package:vendorlink/screens/retailer/widgets/retailer_product_card.dart';
import 'package:vendorlink/screens/retailer/widgets/retailer_product_detail_sheet.dart';
import 'package:vendorlink/screens/retailer/widgets/retailer_products_empty_state.dart';
import 'package:vendorlink/screens/retailer/widgets/retailer_products_header.dart';
import 'package:vendorlink/services/auth_service.dart';

class RetailerDashboard extends StatefulWidget {
  const RetailerDashboard({super.key});

  @override
  State<RetailerDashboard> createState() => _RetailerDashboardState();
}

class _RetailerDashboardState extends State<RetailerDashboard> {
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
    setState(() {
      _cart[productId] = (_cart[productId] ?? 0) + 1;
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
      for (final entry in _cart.entries) {
        final product = _cartProducts[entry.key];
        if (product == null) {
          continue;
        }

        await _authService.placeRetailerOrder(
          product: product,
          quantity: entry.value,
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
        const SnackBar(content: Text('Order placed successfully.')),
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

  Future<void> _manualRefreshProducts() async {
    try {
      await _authService.fetchMarketplaceProducts();
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _showProductDetails(Map<String, dynamic> product) async {
    final productModel = RetailerProductUiModel.fromMap(product);
    await showRetailerProductDetails(
      context: context,
      product: productModel,
      onAddToCart: () => _addToCart(product),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titleForTab(_currentIndex))),
      drawer: _buildDrawer(context),
      body: _buildBodyForIndex(),
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
        ],
      ),
    );
  }

  Widget _buildBodyForIndex() {
    switch (_currentIndex) {
      case 1:
        return _buildCartTab();
      case 2:
        return _buildOrdersTab();
      default:
        return _buildProductsTab();
    }
  }

  String _titleForTab(int index) {
    switch (index) {
      case 1:
        return 'My Cart';
      case 2:
        return 'My Orders';
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
          content = RefreshIndicator(
            onRefresh: _manualRefreshProducts,
            child: _buildProductList(products, visibleProducts),
          );
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
                onActionPressed: _manualRefreshProducts,
                actionLabel: 'Refresh products',
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
              final aspectRatio = crossAxisCount == 1 ? 0.86 : 0.78;

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

              return Card(
                color: const Color(0xFF111827),
                child: ListTile(
                  title: Text(
                    name,
                    style: const TextStyle(color: Color(0xFFF8FAFC)),
                  ),
                  subtitle: Text(
                    'Price: ₹$price',
                    style: const TextStyle(color: Color(0xFFCBD5E1)),
                  ),
                  trailing: Row(
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
              label: Text(_isPlacingOrder ? 'Placing...' : 'Place Order'),
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
        final orders = snapshot.data ?? const [];

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
            final productName =
                (order['product_name'] ?? order['name'] ?? 'Product')
                    .toString();
            final quantity = (order['quantity'] ?? 0).toString();
            final status = (order['status'] ?? 'pending').toString();
            final totalPrice = (order['total_price'] ?? order['price'] ?? '-')
                .toString();

            return Card(
              color: const Color(0xFF111827),
              child: ListTile(
                title: Text(
                  productName,
                  style: const TextStyle(color: Color(0xFFF8FAFC)),
                ),
                subtitle: Text(
                  'Qty: $quantity  |  Total: ₹$totalPrice',
                  style: const TextStyle(color: Color(0xFFCBD5E1)),
                ),
                trailing: RetailerOrderStatusChip(status: status),
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
      final sku = (product['sku'] ?? '').toString().toLowerCase();
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
          sku.contains(_searchQuery);
      final matchesCategory =
          requestedCategory == 'all' || category == requestedCategory;
      final matchesType = requestedType == 'all' || type == requestedType;

      return matchesSearch && matchesCategory && matchesType;
    }).toList();
  }
}

int _productQuantity(Map<String, dynamic> product) {
  final raw = product['stock_qty'] ?? product['quantity'];
  if (raw is int) {
    return raw;
  }
  if (raw is double) {
    return raw.toInt();
  }
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}
