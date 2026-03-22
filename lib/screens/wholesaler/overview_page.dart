import 'package:flutter/material.dart';

import '../../widgets/dashboard_card.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.local_shipping,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Today: 18 orders dispatched, 4 pending confirmations',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Overview',
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
                DashboardCard(
                  title: 'Total Orders',
                  value: '124',
                  icon: Icons.shopping_cart,
                  color: Colors.indigo,
                ),
                SizedBox(height: 14),
                DashboardCard(
                  title: 'Monthly Revenue',
                  value: '₹1,25,000',
                  icon: Icons.currency_rupee,
                  color: Colors.green,
                ),
                SizedBox(height: 14),
                DashboardCard(
                  title: 'Top Product',
                  value: 'Rice 25kg',
                  icon: Icons.star,
                  color: Colors.orange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF374151)),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Low Stock',
                            style: TextStyle(color: Color(0xFF9CA3AF)),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '5 Items',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New Retailers',
                            style: TextStyle(color: Color(0xFF9CA3AF)),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '3 This Week',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
