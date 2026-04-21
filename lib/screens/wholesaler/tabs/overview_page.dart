import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../services/date_time_service.dart';
import '../widgets/dashboard_card.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _authService.repairCurrentWholesalerWalletFromOrdersBestEffort();
  }

  double _toAmount(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  String _formatMoney(double value) {
    return 'Rs ${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _authService.watchCurrentUserProfile(),
      builder: (context, profileSnapshot) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _authService.watchWholesalerOrders(),
          builder: (context, ordersSnapshot) {
            final profile = profileSnapshot.data ?? const <String, dynamic>{};
            final orders =
                ordersSnapshot.data ?? const <Map<String, dynamic>>[];
            final metadataName = _authService
                .currentSession
                ?.user
                .userMetadata?['name']
                ?.toString()
                .trim();
            final profileName = (profile['name'] ?? '').toString().trim();
            final emailPrefix = _authService.currentSession?.user.email
                ?.split('@')
                .first
                .trim();
            final wholesalerName =
                (metadataName != null && metadataName.isNotEmpty)
                ? metadataName
                : profileName.isNotEmpty
                ? profileName
                : (emailPrefix != null && emailPrefix.isNotEmpty)
                ? emailPrefix
                : 'Wholesaler';

            final walletBalance = _toAmount(profile['wallet_balance']);
            final totalOrders = orders.length;
            final totalRevenue = orders.fold<double>(
              0,
              (sum, order) =>
                  sum +
                  _toAmount(order['total_amount'] ?? order['total_price']),
            );
            final displayedWalletBalance = totalRevenue > walletBalance
                ? totalRevenue
                : walletBalance;
            final processingOrders = orders
                .where(
                  (order) =>
                      (order['status'] ?? '').toString().toLowerCase() ==
                      'processing',
                )
                .length;
            final deliveredOrders = orders
                .where(
                  (order) =>
                      (order['status'] ?? '').toString().toLowerCase() ==
                      'delivered',
                )
                .length;
            final recentOrders = orders.take(5).toList(growable: false);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.trending_up_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sales Dashboard - $wholesalerName',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Track wallet, revenue and order activity in one place',
                                    style: TextStyle(
                                      color: Color(0xFFD1D5DB),
                                      fontSize: 13,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Location: PICT College, Dhankawadi, Pune',
                                    style: TextStyle(
                                      color: Color(0xFFBFDBFE),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _BalanceCard(
                                title: 'Wallet balance',
                                value: _formatMoney(displayedWalletBalance),
                                icon: Icons.account_balance_wallet_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _BalanceCard(
                                title: 'Revenue',
                                value: _formatMoney(totalRevenue),
                                icon: Icons.payments_outlined,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DashboardCard(
                          title: 'Total Orders',
                          value: '$totalOrders',
                          icon: Icons.receipt_long,
                          color: Colors.indigo,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DashboardCard(
                          title: 'Processing Orders',
                          value: '$processingOrders',
                          icon: Icons.local_shipping_outlined,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DashboardCard(
                    title: 'Delivered Orders',
                    value: '$deliveredOrders',
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Recent Order History',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  if (ordersSnapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (recentOrders.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: const Text(
                        'No orders yet. New payments and order history will appear here.',
                        style: TextStyle(color: Color(0xFFCBD5E1)),
                      ),
                    )
                  else
                    ...recentOrders.map(
                      (order) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _OrderHistoryTile(order: order),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFD1D5DB),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
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

class _OrderHistoryTile extends StatelessWidget {
  const _OrderHistoryTile({required this.order});

  final Map<String, dynamic> order;

  String _toMoney(dynamic value) {
    if (value is num) {
      return 'Rs ${value.toDouble().toStringAsFixed(2)}';
    }
    final parsed = double.tryParse((value ?? '').toString()) ?? 0;
    return 'Rs ${parsed.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final orderNumber = (order['order_number'] ?? order['id'] ?? '-')
        .toString();
    final status = (order['status'] ?? 'pending').toString();
    final shippingName = (order['shipping_name'] ?? 'Retailer').toString();
    final amount = _toMoney(order['total_amount'] ?? order['total_price']);
    final createdAt = (order['created_at'] ?? '').toString();

    final statusColor = switch (status.toLowerCase()) {
      'accepted' => const Color(0xFF16A34A),
      'rejected' => const Color(0xFFDC2626),
      'processing' => const Color(0xFF2563EB),
      _ => const Color(0xFFF59E0B),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #$orderNumber',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shippingName,
                      style: const TextStyle(color: Color(0xFFCBD5E1)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InfoBlock(label: 'Revenue', value: amount),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoBlock(
                  label: 'Created',
                  value: DateTimeService.formatToIst(
                    createdAt.isEmpty ? null : createdAt,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
