import 'package:flutter/material.dart';

class RetailerOrderStatusChip extends StatelessWidget {
  const RetailerOrderStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    Color background;
    switch (normalized) {
      case 'accepted':
        background = const Color(0xFF14532D);
        break;
      case 'rejected':
        background = const Color(0xFF7F1D1D);
        break;
      case 'delivered':
        background = const Color(0xFF1E3A8A);
        break;
      default:
        background = const Color(0xFF374151);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
