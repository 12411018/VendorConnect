import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';
import 'profile_page.dart';

class RetailerDashboard extends StatelessWidget {
  const RetailerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Retailer Dashboard")),

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF6366F1)),
              accountName: Text(
                "Nikhil Retail Store",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text("nikhilnikalje@1234"),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.store, size: 30, color: Colors.black),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.person),
              title: const Text("Profile"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfilePage(
                      name: 'Nikhil Retail Store',
                      email: 'nikhilnikalje@1234',
                      role: 'Retailer',
                      avatarIcon: Icons.store,
                    ),
                  ),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text("My Cart"),
              onTap: () {
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text("Order History"),
              onTap: () {
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text("Purchase Analytics"),
              onTap: () {
                Navigator.pop(context);
              },
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("Settings"),
              onTap: () {
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: () async {
                await AuthService().logout();
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
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            margin: EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.local_offer, color: Color(0xFF93C5FD)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Special Offer: Save 12% on bulk grocery orders today",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Text(
            "Categories",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text("Groceries")),
              Chip(label: Text("Beverages")),
              Chip(label: Text("Snacks")),
              Chip(label: Text("Personal Care")),
            ],
          ),

          SizedBox(height: 18),

          Text(
            "Quick Actions",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          SizedBox(height: 10),

          Card(
            child: ListTile(
              leading: Icon(Icons.store),
              title: Text("Browse Products"),
              subtitle: Text("Explore trending items and vendors"),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
            ),
          ),

          Card(
            child: ListTile(
              leading: Icon(Icons.shopping_cart),
              title: Text("My Cart"),
              subtitle: Text("2 products waiting for checkout"),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
            ),
          ),

          Card(
            child: ListTile(
              leading: Icon(Icons.receipt_long),
              title: Text("Order History"),
              subtitle: Text("Track status and reorder easily"),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
            ),
          ),

          SizedBox(height: 12),

          Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Monthly Spend",
                    style: TextStyle(color: Colors.white70),
                  ),
                  Text(
                    "₹48,500",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
