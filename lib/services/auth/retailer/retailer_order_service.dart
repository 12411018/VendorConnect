part of '../auth_service.dart';

extension AuthRetailerOrderService on AuthService {
  Stream<List<Map<String, dynamic>>> watchRetailerOrders() {
    final retailerId = requireCurrentUserId();
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    Timer? timer;

    Future<void> loadOrders() async {
      try {
        final retailerLocation = await resolveCurrentRetailerLocation(
          retailerId,
        );

        final rows = await _supabase
            .from('orders')
            .select(
              '*, vendor_profile:profiles!orders_vendor_id_fkey(id, name, shop_name, phone)',
            )
            .eq('retailer_id', retailerId)
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 12));

        final mapped = await enrichOrdersWithVendorInfo(
          List<Map<String, dynamic>>.from(rows),
        );
        if (retailerLocation.isNotEmpty) {
          for (final order in mapped) {
            order['retailer_location'] = retailerLocation;
          }
        }
        if (kDebugMode) {
          debugPrint(
            '[RetailerOrders] retailer=$retailerId rows=${mapped.length}',
          );
        }
        controller.add(mapped);
      } on PostgrestException catch (error) {
        if (kDebugMode) {
          debugPrint(
            '[RetailerOrders][PostgrestException] code=${error.code} message=${error.message}',
          );
        }
        controller.addError(humanizeOrdersDbError(error));
      } on TimeoutException {
        if (kDebugMode) {
          debugPrint('[RetailerOrders][Timeout] Query timed out.');
        }
        controller.addError(
          'Retailer orders query timed out. Check internet or Supabase response.',
        );
      } catch (error) {
        if (kDebugMode) {
          debugPrint('[RetailerOrders][Exception] $error');
        }
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

  Future<void> placeRetailerOrder({
    required List<Map<String, dynamic>> items,
    required String shippingName,
    required String shippingAddress,
    required String shippingPhone,
    double? paymentLat,
    double? paymentLng,
    double? marketplaceLat,
    double? marketplaceLng,
  }) async {
    final retailerId = requireCurrentUserId();
    if (items.isEmpty) {
      throw const AuthException('No cart items were provided for the order.');
    }

    await ensureCurrentUserRowInUsersTable();

    final vendorIds = items
        .map((item) => (item['vendor_id'] ?? '').toString().trim())
        .where((vendorId) => vendorId.isNotEmpty)
        .toSet();
    if (vendorIds.isEmpty) {
      throw const AuthException(
        'Product vendor is missing. Cannot place order.',
      );
    }
    if (vendorIds.length > 1) {
      throw const AuthException(
        'Orders must be grouped by wholesaler before submission.',
      );
    }

    final vendorId = vendorIds.first;
    final orderItems = items.map(buildOrderItem).toList(growable: false);
    final totalAmount = orderItems.fold<double>(
      0.0,
      (sum, item) => sum + (item['total_price'] as num).toDouble(),
    );
    final orderNumber = generateOrderNumber();

    final payload = {
      'order_number': orderNumber,
      'vendor_id': vendorId,
      'retailer_id': retailerId,
      'shipping_name': shippingName,
      'shipping_address': shippingAddress,
      'shipping_phone': shippingPhone,
      'total_amount': totalAmount,
      'status': 'pending',
      'payment_lat': paymentLat,
      'payment_lng': paymentLng,
      'marketplace_lat': marketplaceLat,
      'marketplace_lng': marketplaceLng,
    };

    try {
      final orderId = await insertOrderWithFallback(payload);
      await insertOrderItems(orderId: orderId, items: orderItems);
      await creditWholesalerWalletBestEffort(
        vendorId: vendorId,
        amount: totalAmount,
      );
    } on PostgrestException catch (error) {
      if (isOrdersVendorForeignKeyError(error)) {
        await ensureVendorRowsInUsersTable(vendorIds);
        try {
          final orderId = await insertOrderWithFallback(payload);
          await insertOrderItems(orderId: orderId, items: orderItems);
          await creditWholesalerWalletBestEffort(
            vendorId: vendorId,
            amount: totalAmount,
          );
          return;
        } on PostgrestException catch (retryError) {
          throw AuthException(humanizeOrdersDbError(retryError));
        }
      }
      throw AuthException(humanizeOrdersDbError(error));
    }
  }

  Future<void> updateOrderStatusForRetailer({
    required String orderId,
    required String status,
  }) async {
    final retailerId = requireCurrentUserId();

    final payload = <String, dynamic>{'status': status};
    if (status.trim().toLowerCase() == 'delivered') {
      payload['retailer_confirmed_at'] = DateTime.now()
          .toUtc()
          .toIso8601String();
    }

    try {
      await _supabase
          .from('orders')
          .update(payload)
          .eq('id', orderId)
          .eq('retailer_id', retailerId);
    } on PostgrestException catch (error) {
      throw AuthException(humanizeOrdersDbError(error));
    }
  }

  Future<String> fetchCurrentRetailerLocation() async {
    final retailerId = requireCurrentUserId();
    return resolveCurrentRetailerLocation(retailerId);
  }

  Future<String> fetchCurrentUserPhone() async {
    final userId = requireCurrentUserId();
    try {
      final profile = await _supabase
          .from('profiles')
          .select('phone')
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));
      return (profile?['phone'] ?? '').toString().trim();
    } on PostgrestException catch (_) {
      return '';
    }
  }

  Future<String> resolveCurrentRetailerLocation(String retailerId) async {
    final profileLocationColumns = <String>['location_label', 'location'];
    for (final column in profileLocationColumns) {
      try {
        final profile = await _supabase
            .from('profiles')
            .select(column)
            .eq('id', retailerId)
            .maybeSingle()
            .timeout(const Duration(seconds: 8));
        final value = (profile?[column] ?? '').toString().trim();
        if (value.isNotEmpty) {
          return value;
        }
      } on PostgrestException catch (_) {
        continue;
      }
    }

    final metadataLocation =
        (_supabase.auth.currentUser?.userMetadata?['location_label'] ?? '')
            .toString()
            .trim();
    if (metadataLocation.isNotEmpty) {
      return metadataLocation;
    }

    return '';
  }

  Future<List<Map<String, dynamic>>> enrichOrdersWithVendorInfo(
    List<Map<String, dynamic>> orders,
  ) async {
    if (orders.isEmpty) {
      return orders;
    }

    for (final order in orders) {
      final vendorProfile = order['vendor_profile'];
      final existingName = (order['vendor_name'] ?? '').toString().trim();
      final existingPhone = (order['vendor_phone'] ?? '').toString().trim();

      if (vendorProfile is Map<String, dynamic>) {
        final profileName = (vendorProfile['name'] ?? '').toString().trim();
        final profileShopName = (vendorProfile['shop_name'] ?? '')
            .toString()
            .trim();
        final profilePhone = (vendorProfile['phone'] ?? '').toString().trim();

        order['vendor_name'] = profileName.isNotEmpty
            ? profileName
            : (profileShopName.isNotEmpty
                  ? profileShopName
                  : (existingName.isNotEmpty ? existingName : 'Wholesaler'));
        order['vendor_phone'] = profilePhone.isNotEmpty
            ? profilePhone
            : existingPhone;
      } else {
        order['vendor_name'] = existingName.isNotEmpty
            ? existingName
            : 'Wholesaler';
        order['vendor_phone'] = existingPhone;
      }

      order.remove('vendor_profile');
    }

    return orders;
  }

  Future<String> insertOrderWithFallback(Map<String, dynamic> payload) async {
    final orderNumber =
        (payload['order_number'] ?? '').toString().trim().isEmpty
        ? generateOrderNumber()
        : payload['order_number'].toString().trim();

    final candidates = <Map<String, dynamic>>[
      Map<String, dynamic>.from(payload)..['order_number'] = orderNumber,
      {
        'order_number': orderNumber,
        'vendor_id': payload['vendor_id'],
        'retailer_id': payload['retailer_id'],
        'shipping_name': payload['shipping_name'],
        'shipping_address': payload['shipping_address'],
        'shipping_phone': payload['shipping_phone'],
        'total_amount': payload['total_amount'],
        'status': payload['status'],
      },
      {
        'order_number': orderNumber,
        'vendor_id': payload['vendor_id'],
        'retailer_id': payload['retailer_id'],
        'shipping_phone': payload['shipping_phone'],
        'total_amount': payload['total_amount'],
        'status': payload['status'],
      },
    ];

    PostgrestException? lastError;
    for (final candidate in candidates) {
      final cleanedCandidate = Map<String, dynamic>.from(candidate)
        ..removeWhere((key, value) => value == null);

      try {
        final inserted = await _supabase
            .from('orders')
            .insert(cleanedCandidate)
            .select('id')
            .single();
        final orderId = (inserted['id'] ?? '').toString();
        if (orderId.isNotEmpty) {
          return orderId;
        }
      } on PostgrestException catch (error) {
        lastError = error;
      }
    }

    if (lastError != null) {
      throw AuthException(humanizeOrdersDbError(lastError));
    }

    throw const AuthException(
      'Order placement failed. Please verify the orders table schema in Supabase.',
    );
  }

  Future<void> insertOrderItems({
    required String orderId,
    required List<Map<String, dynamic>> items,
  }) async {
    final payload = items
        .map((item) {
          final productId = (item['product_id'] ?? '').toString().trim();
          if (productId.isEmpty) {
            throw const AuthException(
              'Each order item must include a product id.',
            );
          }

          return {
            'order_id': orderId,
            'product_id': productId,
            'quantity': toPositiveInt(item['quantity']),
            'unit_price': toDouble(item['unit_price']),
          };
        })
        .toList(growable: false);

    if (payload.isEmpty) {
      throw const AuthException('No order items to insert.');
    }

    await _supabase.from('order_items').insert(payload);
  }

  Map<String, dynamic> buildOrderItem(Map<String, dynamic> product) {
    final productId = (product['id'] ?? '').toString().trim();
    final quantity = toPositiveInt(product['quantity']);
    final unitPrice = toDouble(product['price']);
    final totalPrice = unitPrice * quantity;

    return {
      'product_id': productId,
      'product_name': (product['name'] ?? 'Product').toString(),
      'quantity': quantity,
      'unit_price': unitPrice,
      'price': unitPrice,
      'total_price': totalPrice,
    };
  }
}
