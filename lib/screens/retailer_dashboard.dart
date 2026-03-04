import 'package:flutter/material.dart';

class RetailerDashboard extends StatelessWidget {
  const RetailerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: const Text("Retailer Dashboard"),
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),

        children: const [

          ListTile(
            leading: Icon(Icons.store),
            title: Text("Browse Products"),
          ),

          ListTile(
            leading: Icon(Icons.shopping_cart),
            title: Text("My Cart"),
          ),

          ListTile(
            leading: Icon(Icons.receipt_long),
            title: Text("Order History"),
          ),

        ],
      ),
    );
  }
}