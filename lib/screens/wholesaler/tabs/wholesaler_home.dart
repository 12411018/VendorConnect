import 'package:flutter/material.dart';
import 'package:vendorlink/screens/auth/login_screen.dart';
import 'package:vendorlink/screens/wholesaler/products/products_page.dart';
import 'package:vendorlink/services/auth/auth_service.dart';

import 'deliveries_page.dart';
import 'analytics_page.dart';
import 'orders_page.dart';
import 'overview_page.dart';
import '../wholesaler_profile_page.dart';

class WholesalerHome extends StatefulWidget {
  const WholesalerHome({super.key});

  @override
  State<WholesalerHome> createState() => _WholesalerHomeState();
}

class _WholesalerHomeState extends State<WholesalerHome> {
  int _currentIndex = 0;
  final AuthService _authService = AuthService();

  static const _pageTitles = [
    'Wholesaler Dashboard',
    'Products',
    'Orders',
    'Deliveries',
    'Analytics',
  ];

  final List<Widget> _pages = const [
    OverviewPage(),
    ProductsPage(),
    OrdersPage(),
    DeliveriesPage(),
    AnalyticsPage(),
  ];

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_pageTitles[_currentIndex])),
      drawer: Drawer(
        child: StreamBuilder<Map<String, dynamic>?>(
          stream: _authService.watchCurrentUserProfile(),
          builder: (context, snapshot) {
            final user = _authService.currentSession?.user;
            final profile = snapshot.data;
            final metadataName = user?.userMetadata?['name']?.toString().trim();
            final profileName = (profile?['name'] as String?)?.trim();
            final emailPrefix = user?.email?.split('@').first.trim();
            final businessName =
                (metadataName != null && metadataName.isNotEmpty)
                ? metadataName
                : (profileName != null && profileName.isNotEmpty)
                ? profileName
                : (emailPrefix != null && emailPrefix.isNotEmpty)
                ? emailPrefix
                : 'My Business';
            final businessEmail = user?.email ?? 'No email';

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                UserAccountsDrawerHeader(
                  decoration: const BoxDecoration(color: Color(0xFF6366F1)),
                  accountName: Text(
                    businessName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  accountEmail: Text(businessEmail),
                  currentAccountPicture: const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.business, size: 30, color: Colors.black),
                  ),
                ),
                const ListTile(
                  leading: Icon(Icons.location_on_outlined),
                  title: Text('Business Location'),
                  subtitle: Text('PICT College, Dhankawadi, Pune'),
                ),
                ListTile(
                  leading: const Icon(Icons.dashboard_outlined),
                  title: const Text('Dashboard'),
                  onTap: () {
                    Navigator.pop(context);
                    _selectTab(0);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('Inventory'),
                  onTap: () {
                    Navigator.pop(context);
                    _selectTab(1);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.analytics_outlined),
                  title: const Text('Analytics'),
                  onTap: () {
                    Navigator.pop(context);
                    _selectTab(4);
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
                        builder: (_) => const WholesalerProfilePage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Settings page coming soon'),
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
            );
          },
        ),
      ),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _selectTab,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF0F172A),
        selectedItemColor: const Color(0xFF38BDF8),
        unselectedItemColor: const Color(0xFF94A3B8),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            activeIcon: Icon(Icons.local_shipping),
            label: 'Deliveries',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }
}
