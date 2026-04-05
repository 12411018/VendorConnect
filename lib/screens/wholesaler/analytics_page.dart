import 'package:flutter/material.dart';
import 'package:vendorlink/services/auth_service.dart';
import 'package:vendorlink/services/business_ai_service.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final AuthService _authService = AuthService();
  final BusinessAiService _aiService = BusinessAiService();
  late final Stream<List<Map<String, dynamic>>> _productsStream;

  String _stockSummaryKey = '';
  Future<String>? _stockPlanFuture;

  @override
  void initState() {
    super.initState();
    _productsStream = _authService.watchCurrentUserProducts();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _authService.watchWholesalerOrders(),
      builder: (context, snapshot) {
        final orders = snapshot.data ?? const <Map<String, dynamic>>[];
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _productsStream,
          builder: (context, productsSnapshot) {
            final products =
                productsSnapshot.data ?? const <Map<String, dynamic>>[];

            final metrics = _buildAnalyticsData(orders, products);
            _ensureAi(metrics.stockSummary);

            if (snapshot.connectionState == ConnectionState.waiting ||
                productsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            if (productsSnapshot.hasError) {
              return Center(child: Text(productsSnapshot.error.toString()));
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Business Analytics',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _metricCard(
                      'Total Orders',
                      '${metrics.totalOrders}',
                      Icons.receipt_long,
                    ),
                    _metricCard(
                      'Pending/Active',
                      '${metrics.pendingOrders}',
                      Icons.local_shipping_outlined,
                    ),
                    _metricCard(
                      'Delivered',
                      '${metrics.deliveredOrders}',
                      Icons.check_circle_outline,
                    ),
                    _metricCard(
                      'Revenue',
                      '₹${metrics.totalRevenue.toStringAsFixed(0)}',
                      Icons.payments_outlined,
                    ),
                    _metricCard(
                      'Avg Order Value',
                      '₹${metrics.averageOrderValue.toStringAsFixed(0)}',
                      Icons.trending_up,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _listSection(
                  title: 'Low Stock Products',
                  items: metrics.lowStockLines,
                  emptyText: 'No low-stock products right now.',
                ),
                const SizedBox(height: 12),
                _listSection(
                  title: 'High Stock Products',
                  items: metrics.highStockLines,
                  emptyText: 'No high-stock products right now.',
                ),
                const SizedBox(height: 12),
                _listSection(
                  title: 'Slow Moving Products',
                  items: metrics.slowMovingLines,
                  emptyText: 'No slow-moving products detected.',
                ),
                const SizedBox(height: 12),
                _listSection(
                  title: 'Top Buying Products',
                  items: metrics.topProductLines,
                  emptyText: 'No product orders yet.',
                ),
                const SizedBox(height: 12),
                _listSection(
                  title: 'Top Retailers',
                  items: metrics.topRetailerLines,
                  emptyText: 'No retailer activity yet.',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Next-Week Stock Plan',
                        style: TextStyle(
                          color: Color(0xFFF8FAFC),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<String>(
                        future: _stockPlanFuture,
                        builder: (context, aiSnapshot) {
                          if (aiSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(8),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          if (aiSnapshot.hasError) {
                            return Text(
                              aiSnapshot.error.toString(),
                              style: const TextStyle(color: Color(0xFFFCA5A5)),
                            );
                          }
                          return Text(
                            aiSnapshot.data ??
                                'No AI tips available right now.',
                            style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              height: 1.35,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _ensureAi(String summary) {
    if (_stockSummaryKey == summary && _stockPlanFuture != null) {
      return;
    }
    _stockSummaryKey = summary;
    _stockPlanFuture = _aiService.generateStockPlan(stockSummary: summary);
  }

  _AnalyticsData _buildAnalyticsData(
    List<Map<String, dynamic>> orders,
    List<Map<String, dynamic>> products,
  ) {
    final totalOrders = orders.length;
    final deliveredOrders = orders.where((order) {
      final status = (order['status'] ?? '').toString().toLowerCase();
      return status == 'delivered' ||
          status == 'completed' ||
          status == 'fulfilled' ||
          status == 'done';
    }).length;
    final pendingOrders = orders.where((order) {
      final status = (order['status'] ?? '').toString().toLowerCase();
      return status == 'pending' ||
          status == 'accepted' ||
          status == 'processing';
    }).length;

    final totalRevenue = orders.fold<double>(0, (sum, order) {
      final value = order['total_amount'] ?? order['total_price'] ?? 0;
      if (value is num) {
        return sum + value.toDouble();
      }
      return sum + (double.tryParse(value.toString()) ?? 0.0);
    });

    final averageOrderValue = totalOrders == 0
        ? 0.0
        : (totalRevenue / totalOrders);

    final retailerCounts = <String, int>{};
    final soldCounts = <String, int>{};
    final currentStock = <String, int>{};
    final productLookup = <String, Map<String, dynamic>>{};

    for (final product in products) {
      final productName = (product['name'] ?? 'Product').toString().trim();
      if (productName.isEmpty) {
        continue;
      }
      productLookup[productName.toLowerCase()] = product;
      final stockValue = product['stock_qty'] ?? product['quantity'] ?? 0;
      currentStock[productName] = stockValue is num
          ? stockValue.toInt()
          : int.tryParse(stockValue.toString()) ?? 0;
    }

    for (final order in orders) {
      final retailer =
          (order['shipping_name'] ?? order['retailer_id'] ?? 'Retailer')
              .toString();
      retailerCounts[retailer] = (retailerCounts[retailer] ?? 0) + 1;

      final rawItems = order['order_items'];
      if (rawItems is List) {
        for (final item in rawItems.whereType<Map<String, dynamic>>()) {
          final product = item['product'];
          final productName = product is Map<String, dynamic>
              ? (product['name'] ?? 'Product').toString()
              : (item['product_name'] ?? 'Product').toString();

          final qtyRaw = item['quantity'] ?? 1;
          final qty = qtyRaw is num
              ? qtyRaw.toInt()
              : int.tryParse('$qtyRaw') ?? 1;

          soldCounts[productName] = (soldCounts[productName] ?? 0) + qty;
        }
      }
    }

    final topProducts = soldCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topRetailers = retailerCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final stockRows = currentStock.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final lowStockLines = stockRows
        .where((entry) => entry.value <= 5)
        .map((entry) {
          final sold = soldCounts[entry.key] ?? 0;
          return '${entry.key} • stock ${entry.value} • sold $sold';
        })
        .toList(growable: false);

    final highStockLines = stockRows
        .where((entry) => entry.value >= 25)
        .map((entry) {
          final sold = soldCounts[entry.key] ?? 0;
          return '${entry.key} • stock ${entry.value} • sold $sold';
        })
        .toList(growable: false);

    final slowMovingLines = stockRows
        .where((entry) {
          final sold = soldCounts[entry.key] ?? 0;
          return entry.value >= 10 && sold <= 2;
        })
        .map((entry) {
          final sold = soldCounts[entry.key] ?? 0;
          return '${entry.key} • stock ${entry.value} • sold $sold';
        })
        .toList(growable: false);

    final stockSummary =
        'orders=$totalOrders, delivered=$deliveredOrders, pending=$pendingOrders, '
        'revenue=${totalRevenue.toStringAsFixed(2)}, '
        'avgOrderValue=${averageOrderValue.toStringAsFixed(2)}, '
        'lowStock=${lowStockLines.join(' | ')}, '
        'highStock=${highStockLines.join(' | ')}, '
        'slowMoving=${slowMovingLines.join(' | ')}, '
        'topProducts=${topProducts.take(5).map((e) => '${e.key}:${e.value}').join(', ')}, '
        'topRetailers=${topRetailers.take(5).map((e) => '${e.key}:${e.value}').join(', ')}';

    return _AnalyticsData(
      totalOrders: totalOrders,
      deliveredOrders: deliveredOrders,
      pendingOrders: pendingOrders,
      totalRevenue: totalRevenue,
      averageOrderValue: averageOrderValue,
      lowStockLines: lowStockLines,
      highStockLines: highStockLines,
      slowMovingLines: slowMovingLines,
      topProductLines: topProducts
          .take(5)
          .map((e) => '${e.key} • ${e.value} units')
          .toList(growable: false),
      topRetailerLines: topRetailers
          .take(5)
          .map((e) => '${e.key} • ${e.value} orders')
          .toList(growable: false),
      stockSummary: stockSummary,
    );
  }

  Widget _metricCard(String title, String value, IconData icon) {
    return SizedBox(
      width: 210,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF38BDF8)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFFF8FAFC),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listSection({
    required String title,
    required List<String> items,
    required String emptyText,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFF8FAFC),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(emptyText, style: const TextStyle(color: Color(0xFF94A3B8)))
          else
            ...items.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  line,
                  style: const TextStyle(color: Color(0xFFCBD5E1)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnalyticsData {
  _AnalyticsData({
    required this.totalOrders,
    required this.deliveredOrders,
    required this.pendingOrders,
    required this.totalRevenue,
    required this.averageOrderValue,
    required this.lowStockLines,
    required this.highStockLines,
    required this.slowMovingLines,
    required this.topProductLines,
    required this.topRetailerLines,
    required this.stockSummary,
  });

  final int totalOrders;
  final int deliveredOrders;
  final int pendingOrders;
  final double totalRevenue;
  final double averageOrderValue;
  final List<String> lowStockLines;
  final List<String> highStockLines;
  final List<String> slowMovingLines;
  final List<String> topProductLines;
  final List<String> topRetailerLines;
  final String stockSummary;
}
