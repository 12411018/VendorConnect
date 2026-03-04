import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(




      appBar: AppBar(
        title: const Text(
          "VendorLink",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),

      drawer: Drawer(
        backgroundColor: const Color(0xFF1E293B),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [


            const UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xFF6366F1),
              ),
              accountName: Text("Nikhil "),
              accountEmail: Text("nikhilnikalje@1234"),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.business,
                  size: 30,
                  color: Colors.black,
                ),
              ),
            ),
            // const SizedBox(height: 60),

            ListTile(
              leading: const Icon(Icons.person, color: Colors.white),
              title: const Text(
                "Profile",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {},
            ),

            ListTile(
              leading: const Icon(Icons.analytics, color: Colors.white),
              title: const Text(
                "Analytics",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {},
            ),

            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white),
              title: const Text(
                "Settings",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {},
            ),

            ListTile(
              leading: const Icon(Icons.support_agent, color: Colors.white),
              title: const Text(
                "Contact Us",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {},
            ),

            const Divider(color: Colors.grey),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white),
              title: const Text(
                "Logout",
                style: TextStyle(color: Colors.white),
              ),
              onTap: (
                  ) {},
            ),
          ],
        ),
      ),




      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            _dashboardCard(
              title: "Total Orders",
              value: "124",
              icon: Icons.shopping_cart,
              color: Colors.indigo,
            ),

            const SizedBox(height: 16),

            _dashboardCard(
              title: "Monthly Revenue",
              value: "₹1,25,000",
              icon: Icons.currency_rupee,
              color: Colors.green,
            ),

            const SizedBox(height: 16),

            _dashboardCard(
              title: "Top Product",
              value: "Rice 25kg",
              icon: Icons.star,
              color: Colors.orange,
            ),

            const SizedBox(height: 24),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Recent Orders",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold
                ),
              ),
            ),

            const SizedBox(height: 10),

            _orderTile("Retailer A", "₹12,000", "Shipped"),
            _orderTile("Retailer B", "₹8,500", "Pending"),
            _orderTile("Retailer C", "₹15,300", "Delivered"),
          ],
        ),
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
            icon: Icon(Icons.dashboard),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: "Wholesaler",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: "Retailer",
          ),
        ],
      ),
    );
  }

  // 🔹 Drawer Item Widget
  Widget _drawerItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () {},
    );
  }

  // 🔹 Dashboard Card Widget
  Widget _dashboardCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                Text(value,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
              ]),
          Icon(icon, size: 40, color: color),
        ],
      ),
    );
  }

  // 🔹 Order Tile
  Widget _orderTile(String name, String amount, String status) {
    return Card(
      color: const Color(0xFF1E293B),
      child: ListTile(
        title: Text(name),
        subtitle: Text(amount),
        trailing: Text(
          status,
          style: const TextStyle(color: Colors.green),
        ),
      ),
    );
  }
}