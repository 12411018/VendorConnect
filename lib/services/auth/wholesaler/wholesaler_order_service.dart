part of '../../auth_service.dart';

extension AuthWholesalerOrderService on AuthService {
  Stream<List<Map<String, dynamic>>> watchWholesalerOrders() {
    final wholesalerId = requireCurrentUserId();
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    Timer? timer;

    Future<void> loadOrders() async {
      try {
        final rows = await _supabase
            .from('orders')
            .select()
            .eq('vendor_id', wholesalerId)
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 12));
        final mappedRows = List<Map<String, dynamic>>.from(rows);
        await syncWholesalerWalletFromOrdersBestEffort(
          wholesalerId: wholesalerId,
          orders: mappedRows,
        );
        controller.add(mappedRows);
      } on PostgrestException catch (error) {
        controller.addError(humanizeOrdersDbError(error));
      } on TimeoutException {
        controller.addError(
          'Wholesaler orders query timed out. Check internet or Supabase response.',
        );
      } catch (error) {
        controller.addError(error);
      }
    }

    loadOrders();
    timer = Timer.periodic(const Duration(seconds: 3), (_) => loadOrders());

    controller.onCancel = () {
      timer?.cancel();
    };

    return controller.stream;
  }

  Future<void> updateOrderStatusForWholesaler({
    required String orderId,
    required String status,
  }) async {
    final wholesalerId = requireCurrentUserId();

    try {
      await _supabase
          .from('orders')
          .update({'status': status})
          .eq('id', orderId)
          .eq('vendor_id', wholesalerId);
    } on PostgrestException catch (error) {
      throw AuthException(humanizeOrdersDbError(error));
    }
  }

  Future<void> repairCurrentWholesalerWalletFromOrdersBestEffort() async {
    final userId = requireCurrentUserId();

    try {
      final orders = await _supabase
          .from('orders')
          .select('total_amount, total_price')
          .eq('vendor_id', userId);
      await syncWholesalerWalletFromOrdersBestEffort(
        wholesalerId: userId,
        orders: List<Map<String, dynamic>>.from(orders),
      );
    } on PostgrestException catch (error) {
      if (kDebugMode) {
        debugPrint('[WalletRepair][Skipped] ${error.message}');
      }
    }
  }

  Future<void> syncWholesalerWalletFromOrdersBestEffort({
    required String wholesalerId,
    required List<Map<String, dynamic>> orders,
  }) async {
    final computedWallet = orders.fold<double>(
      0.0,
      (sum, order) =>
          sum + toDouble(order['total_amount'] ?? order['total_price']),
    );

    if (computedWallet <= 0) {
      return;
    }

    try {
      final profile = await _supabase
          .from('profiles')
          .select('wallet_balance')
          .eq('id', wholesalerId)
          .maybeSingle();

      final currentWallet = toDouble(profile?['wallet_balance']);
      final difference = (currentWallet - computedWallet).abs();
      if (difference < 0.01) {
        return;
      }

      try {
        await _supabase
            .from('profiles')
            .update({'wallet_balance': computedWallet})
            .eq('id', wholesalerId);
      } on PostgrestException {
        await _supabase.from('profiles').upsert({
          'id': wholesalerId,
          'wallet_balance': computedWallet,
        });
      }
    } on PostgrestException catch (error) {
      if (kDebugMode) {
        debugPrint('[WalletSync][Skipped] ${error.message}');
      }
    }
  }

  Future<void> creditWholesalerWalletBestEffort({
    required String vendorId,
    required double amount,
  }) async {
    if (vendorId.trim().isEmpty || amount <= 0) {
      return;
    }

    try {
      await _supabase.rpc(
        'credit_wholesaler_wallet',
        params: {'p_vendor_id': vendorId, 'p_amount': amount},
      );
    } on PostgrestException catch (error) {
      if (kDebugMode) {
        debugPrint('[WalletCredit][RPC Failed] ${error.message}');
      }

      try {
        final profile = await _supabase
            .from('profiles')
            .select('wallet_balance')
            .eq('id', vendorId)
            .maybeSingle();

        if (profile == null) {
          return;
        }

        final currentBalance = toDouble(profile['wallet_balance']);
        final updatedBalance = currentBalance + amount;

        await _supabase
            .from('profiles')
            .update({'wallet_balance': updatedBalance})
            .eq('id', vendorId);
      } on PostgrestException catch (fallbackError) {
        if (kDebugMode) {
          debugPrint(
            '[WalletCredit][Fallback Failed] ${fallbackError.message}',
          );
        }
      }
    }
  }
}
