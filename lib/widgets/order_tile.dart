import 'package:flutter/material.dart';

class OrderTile extends StatelessWidget {

  final String name;
  final String amount;
  final String status;

  const OrderTile(
      this.name,
      this.amount,
      this.status,
      {super.key}
      );

  @override
  Widget build(BuildContext context) {

    return Card(
      color: const Color(0xFF1E293B),

      child: ListTile(

        title: Text(name),

        subtitle: Text(amount),

        trailing: Text(
          status,
          style: const TextStyle(
            color: Colors.green,
          ),
        ),

      ),
    );
  }
}