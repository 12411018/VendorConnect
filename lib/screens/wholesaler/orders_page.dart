import 'package:flutter/material.dart';

import '../../widgets/order_tile.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Recent Orders',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF374151)),
          ),
          child: const Column(
            children: [
              OrderTile('Retailer A', '₹12,000', 'Shipped'),
              SizedBox(height: 10),
              OrderTile('Retailer B', '₹8,500', 'Pending'),
              SizedBox(height: 10),
              OrderTile('Retailer C', '₹15,300', 'Delivered'),
              SizedBox(height: 10),
              OrderTile('Retailer D', '₹5,900', 'Pending'),
            ],
          ),
        ),
      ],
    );
  }
}
