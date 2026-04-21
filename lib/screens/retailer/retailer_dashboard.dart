import 'package:flutter/material.dart';
import 'package:vendorlink/screens/auth/login_screen.dart';
import 'package:vendorlink/screens/retailer/delivery_page.dart';
import 'package:vendorlink/screens/retailer/models/retailer_cart.dart';
import 'package:vendorlink/screens/retailer/profile_page.dart';
import 'package:vendorlink/screens/retailer/tabs/retailer_cart_tab.dart';
import 'package:vendorlink/screens/retailer/tabs/retailer_orders_tab.dart';
import 'package:vendorlink/screens/retailer/tabs/retailer_products_tab.dart';
import 'package:vendorlink/services/auth_service.dart';

class RetailerDashboard extends StatefulWidget {
  const RetailerDashboard({super.key});

  @override
  State<RetailerDashboard> createState() => _RetailerDashboardState();
}

class _RetailerDashboardState extends State<RetailerDashboard> {
  final AuthService _authService = AuthService();
  final RetailerCart _cart = RetailerCart();
  int _currentIndex = 0;

  static const _pageTitles = [
    'Retailer Dashboard',
    'My Cart',
    'My Orders',
    'Delivery',
  ];

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void dispose() {
    _cart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_pageTitles[_currentIndex])),
      drawer: _buildDrawer(context),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          RetailerProductsTab(cart: _cart),
          RetailerCartTab(
            cart: _cart,
            onOrderPlaced: () => _selectTab(2),
          ),
          const RetailerOrdersTab(),
          const RetailerDeliveryPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _selectTab,
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

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: StreamBuilder<Map<String, dynamic>?>(
        stream: _authService.watchCurrentUserProfile(),
        builder: (context, snapshot) {
          final user = _authService.currentSession?.user;
          final profile = snapshot.data;
          final metadataName = user?.userMetadata?['name']?.toString().trim();
          final profileName = (profile?['name'] as String?)?.trim();
          final emailPrefix = user?.email?.split('@').first.trim();
          final displayName =
              (metadataName != null && metadataName.isNotEmpty)
              ? metadataName
              : (profileName != null && profileName.isNotEmpty)
              ? profileName
              : (emailPrefix != null && emailPrefix.isNotEmpty)
              ? emailPrefix
              : 'Retail Account';
          final displayEmail = user?.email ?? 'No email found';

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: Color(0xFF6366F1)),
                accountName: Text(
                  displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                accountEmail: Text(displayEmail),
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
                  _selectTab(0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.shopping_cart_outlined),
                title: const Text('My Cart'),
                onTap: () {
                  Navigator.pop(context);
                  _selectTab(1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('My Orders'),
                onTap: () {
                  Navigator.pop(context);
                  _selectTab(2);
                },
              ),
              ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: const Text('Delivery'),
                onTap: () {
                  Navigator.pop(context);
                  _selectTab(3);
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
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
