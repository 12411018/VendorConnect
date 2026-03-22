import 'package:flutter/material.dart';

class DeliveriesPage extends StatelessWidget {
  const DeliveriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Deliveries',
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
          child: Column(
            children: const [
              _DeliveryItem(
                retailer: 'Retailer A',
                orderId: 'ORD-1048',
                status: 'In Transit',
                eta: 'Today, 6:30 PM',
                icon: Icons.local_shipping,
              ),
              SizedBox(height: 10),
              _DeliveryItem(
                retailer: 'Retailer C',
                orderId: 'ORD-1042',
                status: 'Out for Delivery',
                eta: 'Today, 4:00 PM',
                icon: Icons.route,
              ),
              SizedBox(height: 10),
              _DeliveryItem(
                retailer: 'Retailer B',
                orderId: 'ORD-1037',
                status: 'Delivered',
                eta: 'Delivered at 11:50 AM',
                icon: Icons.check_circle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeliveryItem extends StatelessWidget {
  final String retailer;
  final String orderId;
  final String status;
  final String eta;
  final IconData icon;

  const _DeliveryItem({
    required this.retailer,
    required this.orderId,
    required this.status,
    required this.eta,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
        title: Text(retailer),
        subtitle: Text('$orderId • $eta'),
        trailing: Text(
          status,
          style: const TextStyle(
            color: Color(0xFF93C5FD),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
