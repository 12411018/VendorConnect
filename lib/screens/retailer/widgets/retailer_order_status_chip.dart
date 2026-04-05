import 'package:flutter/material.dart';

class RetailerOrderStatusChip extends StatelessWidget {
  const RetailerOrderStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    Color background;
    String label;
    switch (normalized) {
      case 'pending':
        background = const Color(0xFF1E40AF);
        label = 'Order Placed';
        break;
      case 'accepted':
      case 'processing':
        background = const Color(0xFF7C2D12);
        label = 'Out for Delivery';
        break;
      case 'rejected':
        background = const Color(0xFF7F1D1D);
        label = 'Rejected';
        break;
      case 'delivered':
      case 'completed':
      case 'fulfilled':
      case 'done':
        background = const Color(0xFF14532D);
        label = 'Delivered';
        break;
      default:
        background = const Color(0xFF374151);
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
