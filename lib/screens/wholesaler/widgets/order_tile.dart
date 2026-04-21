import 'package:flutter/material.dart';

class OrderTile extends StatelessWidget {
  final String name;
  final String amount;
  final String status;

  const OrderTile(this.name, this.amount, this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final Color statusColor = status == "Pending"
        ? Colors.orange
        : status == "Shipped"
        ? Colors.lightBlue
        : Colors.green;

    return Card(
      color: const Color(0xFF111827),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF374151)),
      ),

      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        title: Text(name),

        subtitle: Text(
          amount,
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
        ),

        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: statusColor.withValues(alpha: 0.35)),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
