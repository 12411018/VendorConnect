import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../widgets/dashboard_card.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  final AuthService _authService = AuthService();

  int _toQuantity(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  int _stockQty(Map<String, dynamic> item) {
    return _toQuantity(item['stock_qty'] ?? item['quantity']);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _authService.watchCurrentUserProducts(),
      builder: (context, snapshot) {
        final products = snapshot.data ?? const [];
        final totalProducts = products.length;
        final totalQuantity = products.fold<int>(
          0,
          (sum, item) => sum + _stockQty(item),
        );
        final lowStockCount = products
            .where((item) => _stockQty(item) <= 5)
            .length;
        final topProduct = products.isEmpty
            ? 'No products yet'
            : (products.reduce(
                        (a, b) => _stockQty(a) >= _stockQty(b) ? a : b,
                      )['name']
                      as String? ??
                  'Unnamed');

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
                        Icons.wifi_tethering,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          snapshot.connectionState == ConnectionState.waiting
                              ? 'Syncing realtime product data...'
                              : 'Realtime sync active for your product workspace',
                          style: const TextStyle(fontWeight: FontWeight.w600),
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
                child: Column(
                  children: [
                    DashboardCard(
                      title: 'Total Products',
                      value: '$totalProducts',
                      icon: Icons.inventory_2,
                      color: Colors.indigo,
                    ),
                    const SizedBox(height: 14),
                    DashboardCard(
                      title: 'Total Quantity',
                      value: '$totalQuantity units',
                      icon: Icons.numbers,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 14),
                    DashboardCard(
                      title: 'Top Stock Product',
                      value: topProduct,
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
                child: Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Low Stock',
                                style: TextStyle(color: Color(0xFF9CA3AF)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$lowStockCount Items',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Latest Product',
                                style: TextStyle(color: Color(0xFF9CA3AF)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                totalProducts == 0
                                    ? 'No products'
                                    : (products.first['name'] as String? ??
                                          'Unnamed'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
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
      },
    );
  }
}
