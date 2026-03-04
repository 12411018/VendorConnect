import 'package:flutter/material.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/order_tile.dart';

class WholesalerDashboard extends StatelessWidget {
  const WholesalerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: const Text("Wholesaler Dashboard"),
      ),

      drawer: Drawer(
        child: ListView(
          children: const [

            DrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xFF6366F1),
              ),
              child: Text(
                "Vendor Menu",
                style: TextStyle(fontSize: 22),
              ),
            ),

            ListTile(
              leading: Icon(Icons.person),
              title: Text("Profile"),
            ),

            ListTile(
              leading: Icon(Icons.analytics),
              title: Text("Analytics"),
            ),

            ListTile(
              leading: Icon(Icons.settings),
              title: Text("Settings"),
            ),

          ],
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: const [

            DashboardCard(
              title: "Total Orders",
              value: "124",
              icon: Icons.shopping_cart,
              color: Colors.indigo,
            ),

            SizedBox(height: 16),

            DashboardCard(
              title: "Monthly Revenue",
              value: "₹1,25,000",
              icon: Icons.currency_rupee,
              color: Colors.green,
            ),

            SizedBox(height: 16),

            DashboardCard(
              title: "Top Product",
              value: "Rice 25kg",
              icon: Icons.star,
              color: Colors.orange,
            ),

            SizedBox(height: 24),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Recent Orders",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            SizedBox(height: 10),

            OrderTile("Retailer A", "₹12,000", "Shipped"),
            OrderTile("Retailer B", "₹8,500", "Pending"),
            OrderTile("Retailer C", "₹15,300", "Delivered"),

          ],
        ),
      ),
    );
  }
}