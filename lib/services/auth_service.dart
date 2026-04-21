import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? shopName,
  }) async {
    late final AuthResponse response;
    try {
      response = await _supabase.auth
          .signUp(
            email: email,
            password: password,
            data: {
              'name': name,
              'role': role,
              if ((shopName ?? '').trim().isNotEmpty) 'shop_name': shopName,
            },
          )
          .timeout(const Duration(seconds: 20));
    } on AuthException catch (error) {
      throw AuthException(_humanizeAuthError(error.message));
    }

    final user = response.user;
    if (user == null) {
      throw const AuthException('Sign-up failed. Please try again.');
    }

    final hasActiveSession =
        response.session != null || _supabase.auth.currentSession != null;

    if (!hasActiveSession) {
      return;
    }

    try {
      await _supabase
          .from('profiles')
          .upsert({
            'id': user.id,
            'name': name,
            'role': role,
            if ((shopName ?? '').trim().isNotEmpty) 'shop_name': shopName,
          })
          .timeout(const Duration(seconds: 10));
      await _ensureCurrentUserRowInUsersTable();
    } on PostgrestException catch (error) {
      if (_supabase.auth.currentSession == null && _isRlsPolicyError(error)) {
        return;
      }
      final message = _humanizeDbError(error);
      throw AuthException(message);
    }
  }

  Future<void> login({required String email, required String password}) async {
    try {
      await _supabase.auth
          .signInWithPassword(email: email, password: password)
          .timeout(const Duration(seconds: 15));
      await _ensureCurrentUserRowInUsersTable();
    } on AuthException catch (error) {
      throw AuthException(_humanizeAuthError(error.message));
    } on PostgrestException catch (error) {
      throw AuthException(_humanizeDbError(error));
    }
  }

  Future<String?> getUserRole() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return null;
    }

    final data = await _supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle()
        .timeout(const Duration(seconds: 10));

    if (data == null) {
      return null;
    }

    final role = data['role'] as String?;
    if (role == null || role.isEmpty) {
      return null;
    }

    return role;
  }

  Future<void> createProfileEntryForCurrentUser({
    required String role,
    String? name,
    String? shopName,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('No logged-in user to create profile for.');
    }

    try {
      await _supabase
          .from('profiles')
          .upsert({
            'id': user.id,
            'name': name ?? user.email?.split('@').first ?? 'User',
            'role': role,
            if ((shopName ?? '').trim().isNotEmpty) 'shop_name': shopName,
          })
          .timeout(const Duration(seconds: 10));
    } on PostgrestException catch (error) {
      throw AuthException(_humanizeDbError(error));
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  Stream<Map<String, dynamic>?> watchCurrentUserProfile() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', user.id)
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  Stream<List<Map<String, dynamic>>> watchCurrentUserProducts() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return Stream.value(const []);
    }

    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    Timer? timer;

    Future<void> loadProducts() async {
      try {
        final rows = await _supabase
            .from('products')
            .select()
            .eq('vendor_id', user.id)
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 12));

        final mappedRows = List<Map<String, dynamic>>.from(rows);
        controller.add(mappedRows);
      } on PostgrestException catch (error) {
        controller.addError(_humanizeProductsDbError(error));
      } on TimeoutException {
        controller.addError(
          'Products query timed out. Check internet or Supabase response.',
        );
      } catch (error) {
        controller.addError(error);
      }
    }

    loadProducts();
    timer = Timer.periodic(const Duration(seconds: 3), (_) => loadProducts());

    controller.onCancel = () {
      timer?.cancel();
    };

    return controller.stream;
  }

  Stream<List<Map<String, dynamic>>> watchMarketplaceProducts() {
    final viewerId = _supabase.auth.currentUser?.id;
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    Timer? timer;

    Future<void> loadProducts() async {
      try {
        final rows = await _supabase
            .from('products')
            .select(
              '*, vendor_profile:profiles!products_vendor_id_fkey(id, name, shop_name, phone), product_images(image_url, sort_order), product_ratings(rating, review, created_at, retailer_id)',
            )
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 12));

        final mapped = List<Map<String, dynamic>>.from(rows);
        for (final product in mapped) {
          final vendorId = (product['vendor_id'] ?? '').toString().trim();
          final profile = product['vendor_profile'];
          final existingLabel = (product['vendor_name'] ?? product['vendor'])
              .toString()
              .trim();

          if (profile is Map<String, dynamic>) {
            final profileName = (profile['name'] ?? '').toString().trim();
            final shopName = (profile['shop_name'] ?? '').toString().trim();
            final phone = (profile['phone'] ?? '').toString().trim();

            product['vendor_name'] = profileName.isNotEmpty
                ? profileName
                : (existingLabel.isNotEmpty ? existingLabel : 'Wholesaler');
            product['vendor_shop_name'] = shopName;
            product['vendor_phone'] = phone;
          } else {
            product['vendor_name'] = existingLabel.isNotEmpty
                ? existingLabel
                : 'Wholesaler';
            product['vendor_shop_name'] = (product['vendor_shop_name'] ?? '')
                .toString()
                .trim();
            product['vendor_phone'] = (product['vendor_phone'] ?? '')
                .toString()
                .trim();
          }

          if (vendorId.isEmpty) {
            product['vendor_name'] = 'Wholesaler';
          }

          product.remove('vendor_profile');
        }

        if (kDebugMode) {
          debugPrint(
            '[MarketplaceProducts] viewer=$viewerId rows=${mapped.length}',
          );
          if (mapped.isNotEmpty) {
            final first = mapped.first;
            debugPrint(
              '[MarketplaceProducts] sample id=${first['id']} vendor_id=${first['vendor_id']} name=${first['name']}',
            );
          }
        }
        controller.add(mapped);
      } on PostgrestException catch (error) {
        if (kDebugMode) {
          debugPrint(
            '[MarketplaceProducts][PostgrestException] code=${error.code} message=${error.message}',
          );
        }
        controller.addError(_humanizeProductsDbError(error));
      } on TimeoutException {
        if (kDebugMode) {
          debugPrint('[MarketplaceProducts][Timeout] Query timed out.');
        }
        controller.addError(
          'Marketplace query timed out. Check internet or Supabase response.',
        );
      } catch (error) {
        if (kDebugMode) {
          debugPrint('[MarketplaceProducts][Exception] $error');
        }
        controller.addError(error);
      }
    }

    loadProducts();
    timer = Timer.periodic(const Duration(seconds: 3), (_) => loadProducts());

    controller.onCancel = () {
      timer?.cancel();
    };

    return controller.stream;
  }

  Future<List<Map<String, dynamic>>> fetchMarketplaceProducts() async {
    try {
      final rows = await _supabase
          .from('products')
          .select(
            '*, vendor_profile:profiles!products_vendor_id_fkey(id, name, shop_name, phone), product_images(image_url, sort_order), product_ratings(rating, review, created_at, retailer_id)',
          )
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 12));
      final mapped = List<Map<String, dynamic>>.from(rows);
      for (final product in mapped) {
        final profile = product['vendor_profile'];
        final existingLabel = (product['vendor_name'] ?? product['vendor'])
            .toString()
            .trim();

        if (profile is Map<String, dynamic>) {
          final profileName = (profile['name'] ?? '').toString().trim();
          final shopName = (profile['shop_name'] ?? '').toString().trim();
          final phone = (profile['phone'] ?? '').toString().trim();

          product['vendor_name'] = profileName.isNotEmpty
              ? profileName
              : (existingLabel.isNotEmpty ? existingLabel : 'Wholesaler');
          product['vendor_shop_name'] = shopName;
          product['vendor_phone'] = phone;
        } else {
          product['vendor_name'] = existingLabel.isNotEmpty
              ? existingLabel
              : 'Wholesaler';
          product['vendor_shop_name'] = (product['vendor_shop_name'] ?? '')
              .toString()
              .trim();
          product['vendor_phone'] = (product['vendor_phone'] ?? '')
              .toString()
              .trim();
        }

        product.remove('vendor_profile');
      }
      return mapped;
    } on PostgrestException catch (error) {
      throw AuthException(_humanizeProductsDbError(error));
    } on TimeoutException {
      throw const AuthException(
        'Marketplace query timed out. Check internet or Supabase response.',
      );
    }
  }

  Stream<List<Map<String, dynamic>>> watchRetailerOrders() {
    final retailerId = _requireCurrentUserId();
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    Timer? timer;

    Future<void> loadOrders() async {
      try {
        final retailerLocation = await _resolveCurrentRetailerLocation(
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

        final mapped = await _enrichOrdersWithVendorInfo(
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
        controller.addError(_humanizeOrdersDbError(error));
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

  Future<List<Map<String, dynamic>>> _enrichOrdersWithVendorInfo(
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

  Future<String> _resolveCurrentRetailerLocation(String retailerId) async {
    // Check profiles table first (this is what gets updated by Edit Location)
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

    // Fallback to auth metadata
    final metadataLocation =
        (_supabase.auth.currentUser?.userMetadata?['location_label'] ?? '')
            .toString()
            .trim();
    if (metadataLocation.isNotEmpty) {
      return metadataLocation;
    }

    return '';
  }

  /// Public method for fetching the current retailer's saved location.
  Future<String> fetchCurrentRetailerLocation() async {
    final retailerId = _requireCurrentUserId();
    return _resolveCurrentRetailerLocation(retailerId);
  }

  /// Public method for fetching the current user's phone from profiles.
  Future<String> fetchCurrentUserPhone() async {
    final userId = _requireCurrentUserId();
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

  Stream<List<Map<String, dynamic>>> watchWholesalerOrders() {
    final wholesalerId = _requireCurrentUserId();
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
        await _syncWholesalerWalletFromOrdersBestEffort(
          wholesalerId: wholesalerId,
          orders: mappedRows,
        );
        controller.add(mappedRows);
      } on PostgrestException catch (error) {
        controller.addError(_humanizeOrdersDbError(error));
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

  Future<void> repairCurrentWholesalerWalletFromOrdersBestEffort() async {
    final userId = _requireCurrentUserId();

    try {
      final orders = await _supabase
          .from('orders')
          .select('total_amount, total_price')
          .eq('vendor_id', userId);
      await _syncWholesalerWalletFromOrdersBestEffort(
        wholesalerId: userId,
        orders: List<Map<String, dynamic>>.from(orders),
      );
    } on PostgrestException catch (error) {
      if (kDebugMode) {
        debugPrint('[WalletRepair][Skipped] ${error.message}');
      }
    }
  }

  Future<void> _syncWholesalerWalletFromOrdersBestEffort({
    required String wholesalerId,
    required List<Map<String, dynamic>> orders,
  }) async {
    final computedWallet = orders.fold<double>(
      0,
      (sum, order) =>
          sum + _toDouble(order['total_amount'] ?? order['total_price']),
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

      final currentWallet = _toDouble(profile?['wallet_balance']);
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
    final retailerId = _requireCurrentUserId();
    if (items.isEmpty) {
      throw const AuthException('No cart items were provided for the order.');
    }

    await _ensureCurrentUserRowInUsersTable();

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
    final orderItems = items.map(_buildOrderItem).toList(growable: false);
    final totalAmount = orderItems.fold<double>(
      0,
      (sum, item) => sum + (item['total_price'] as num).toDouble(),
    );
    final orderNumber = _generateOrderNumber();

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
      final orderId = await _insertOrderWithFallback(payload);
      await _insertOrderItems(orderId: orderId, items: orderItems);
      await _creditWholesalerWalletBestEffort(
        vendorId: vendorId,
        amount: totalAmount,
      );
    } on PostgrestException catch (error) {
      if (_isOrdersVendorForeignKeyError(error)) {
        await _ensureVendorRowsInUsersTable(vendorIds);
        try {
          final orderId = await _insertOrderWithFallback(payload);
          await _insertOrderItems(orderId: orderId, items: orderItems);
          await _creditWholesalerWalletBestEffort(
            vendorId: vendorId,
            amount: totalAmount,
          );
          return;
        } on PostgrestException catch (retryError) {
          throw AuthException(_humanizeOrdersDbError(retryError));
        }
      }
      throw AuthException(_humanizeOrdersDbError(error));
    }
  }

  Future<void> updateOrderStatusForWholesaler({
    required String orderId,
    required String status,
  }) async {
    final wholesalerId = _requireCurrentUserId();

    try {
      await _supabase
          .from('orders')
          .update({'status': status})
          .eq('id', orderId)
          .eq('vendor_id', wholesalerId);
    } on PostgrestException catch (error) {
      throw AuthException(_humanizeOrdersDbError(error));
    }
  }

  Future<void> updateOrderStatusForRetailer({
    required String orderId,
    required String status,
  }) async {
    final retailerId = _requireCurrentUserId();

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
      throw AuthException(_humanizeOrdersDbError(error));
    }
  }

  Future<String> addProductForCurrentUser({
    required String name,
    required String price,
    required int quantity,
    String? sku,
    String? category,
    String? type,
    String? description,
    String? imageUrl,
  }) async {
    final userId = _requireCurrentUserId();

    final payload = {
      'vendor_id': userId,
      'name': name,
      'price': price,
      'stock_qty': quantity,
      'sku': (sku ?? '').trim().isEmpty ? null : sku?.trim(),
      'category': (category ?? '').trim().isEmpty ? null : category?.trim(),
      'type': (type ?? '').trim().isEmpty ? null : type?.trim(),
      'description': (description ?? '').trim().isEmpty
          ? null
          : description?.trim(),
      'image_url': (imageUrl ?? '').trim().isEmpty ? null : imageUrl?.trim(),
    };

    try {
      return await _insertProductWithFallback(payload);
    } on PostgrestException catch (error) {
      if (_isVendorForeignKeyError(error)) {
        await _ensureCurrentUserRowInUsersTable();
        try {
          return await _insertProductWithFallback(payload);
        } on PostgrestException catch (retryError) {
          throw AuthException(_humanizeProductsDbError(retryError));
        }
      }
      throw AuthException(_humanizeProductsDbError(error));
    }
  }

  Future<String> updateProductForCurrentUser({
    required String productId,
    required String name,
    required String price,
    required int quantity,
    String? sku,
    String? category,
    String? type,
    String? description,
    String? imageUrl,
  }) async {
    final userId = _requireCurrentUserId();

    try {
      await _supabase
          .from('products')
          .update({
            'name': name,
            'price': price,
            'stock_qty': quantity,
            'sku': (sku ?? '').trim().isEmpty ? null : sku?.trim(),
            'category': (category ?? '').trim().isEmpty
                ? null
                : category?.trim(),
            'type': (type ?? '').trim().isEmpty ? null : type?.trim(),
            'description': (description ?? '').trim().isEmpty
                ? null
                : description?.trim(),
            'image_url': (imageUrl ?? '').trim().isEmpty
                ? null
                : imageUrl?.trim(),
          })
          .eq('id', productId)
          .eq('vendor_id', userId);
      return productId;
    } on PostgrestException catch (error) {
      throw AuthException(_humanizeProductsDbError(error));
    }
  }

  Future<void> deleteProductForCurrentUser(String productId) async {
    final userId = _requireCurrentUserId();

    try {
      await _supabase
          .from('products')
          .delete()
          .eq('id', productId)
          .eq('vendor_id', userId);
    } on PostgrestException catch (error) {
      throw AuthException(_humanizeProductsDbError(error));
    }
  }

  Future<String> uploadProductImageForCurrentUser({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final userId = _requireCurrentUserId();
    final sanitizedExt = fileExtension.toLowerCase().replaceAll('.', '');
    final now = DateTime.now().millisecondsSinceEpoch;
    final path = '$userId/$now.$sanitizedExt';

    try {
      await _supabase.storage
          .from('product-images')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
    } on StorageException catch (error) {
      throw AuthException('Image upload failed: ${error.message}');
    }

    return _supabase.storage.from('product-images').getPublicUrl(path);
  }

  Future<void> replaceProductImagesForCurrentUser({
    required String productId,
    required List<String> imageUrls,
  }) async {
    final userId = _requireCurrentUserId();
    final normalizedUrls = imageUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);

    try {
      await _supabase
          .from('product_images')
          .delete()
          .eq('product_id', productId)
          .eq('vendor_id', userId);

      if (normalizedUrls.isEmpty) {
        return;
      }

      final payload = normalizedUrls
          .asMap()
          .entries
          .map((entry) {
            return {
              'product_id': productId,
              'vendor_id': userId,
              'image_url': entry.value,
              'sort_order': entry.key,
            };
          })
          .toList(growable: false);

      await _supabase.from('product_images').insert(payload);
    } on PostgrestException catch (error) {
      if ((error.message).toLowerCase().contains('product_images')) {
        return;
      }
      throw AuthException(_humanizeProductsDbError(error));
    }
  }

  Future<void> submitProductRating({
    required String productId,
    required int rating,
    String? review,
  }) async {
    final retailerId = _requireCurrentUserId();

    try {
      await _supabase.from('product_ratings').upsert({
        'product_id': productId,
        'retailer_id': retailerId,
        'rating': rating,
        'review': (review ?? '').trim().isEmpty ? null : review?.trim(),
      }, onConflict: 'product_id,retailer_id');
    } on PostgrestException catch (error) {
      if (error.message.toLowerCase().contains('product_ratings')) {
        return;
      }
      throw AuthException(error.message);
    }
  }

  Session? get currentSession => _supabase.auth.currentSession;
  User? get currentUser => _supabase.auth.currentUser;

  Future<void> updateCurrentUserName({required String name}) async {
    final userId = _requireCurrentUserId();
    final clean = name.trim();
    if (clean.isEmpty) {
      return;
    }

    await _supabase.from('profiles').upsert({'id': userId, 'name': clean});
  }

  Future<void> updateCurrentUserPhone({required String phone}) async {
    final userId = _requireCurrentUserId();
    await _upsertProfileFieldWithFallback(
      userId: userId,
      field: 'phone',
      value: phone.trim(),
    );
  }

  Future<void> updateCurrentUserLocation({
    required String locationLabel,
    double? latitude,
    double? longitude,
  }) async {
    final userId = _requireCurrentUserId();
    final cleanLabel = locationLabel.trim();

    // Also update auth user metadata so it stays in sync
    try {
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            'location_label': cleanLabel,
            if (latitude != null) 'latitude': latitude,
            if (longitude != null) 'longitude': longitude,
          },
        ),
      );
    } catch (_) {
      // Non-critical: metadata sync failed, profile table is the source of truth
    }

    try {
      await _supabase.from('profiles').upsert({
        'id': userId,
        'location_label': cleanLabel,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      });
      return;
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      if (!(message.contains('location_label') ||
          message.contains('latitude') ||
          message.contains('longitude'))) {
        rethrow;
      }
    }

    await _supabase.from('profiles').upsert({
      'id': userId,
      'location': cleanLabel,
      if (latitude != null) 'lat': latitude,
      if (longitude != null) 'lng': longitude,
    });
  }

  Future<void> updateCurrentUserShopName({required String shopName}) async {
    final userId = _requireCurrentUserId();
    await _supabase.from('profiles').upsert({
      'id': userId,
      'shop_name': shopName.trim(),
    });
  }

  String _requireCurrentUserId() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('Please login to continue.');
    }
    return user.id;
  }

  bool _isRlsPolicyError(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == '42501' ||
        message.contains('row-level security policy');
  }

  bool _isRateLimitAuthMessage(String message) {
    final text = message.toLowerCase();
    return text.contains('rate limit') ||
        text.contains('too many requests') ||
        text.contains('over_email_send_rate_limit');
  }

  int? _extractRetrySeconds(String message) {
    final match = RegExp(
      r'(\d+)\s*seconds?',
      caseSensitive: false,
    ).firstMatch(message);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1) ?? '');
  }

  String _humanizeAuthError(String message) {
    if (_isRateLimitAuthMessage(message)) {
      final seconds = _extractRetrySeconds(message) ?? 60;
      return 'Rate limit exceeded. Please wait $seconds seconds and try again.';
    }

    return message;
  }

  String _humanizeDbError(PostgrestException error) {
    if (_isRlsPolicyError(error)) {
      return 'Sign-up blocked by database security policy. Please fix profiles RLS policies in Supabase.';
    }

    if (error.code == '23505') {
      return 'Profile already exists for this account.';
    }

    return error.message;
  }

  Future<String> _insertProductWithFallback(
    Map<String, dynamic> payload,
  ) async {
    final insertPayload = Map<String, dynamic>.from(payload);

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final inserted = await _supabase
            .from('products')
            .insert(insertPayload)
            .select('id')
            .single();
        final id = (inserted['id'] ?? '').toString();
        if (id.isNotEmpty) {
          return id;
        }
        return '';
      } on PostgrestException catch (error) {
        final missingColumn = _extractKnownMissingProductColumn(error.message);
        if (missingColumn == null ||
            !insertPayload.containsKey(missingColumn)) {
          rethrow;
        }

        insertPayload.remove(missingColumn);
      }
    }

    throw const AuthException(
      'Product add failed due to products table mismatch. Please verify required columns.',
    );
  }

  Future<void> _upsertProfileFieldWithFallback({
    required String userId,
    required String field,
    required String value,
    String? fallbackField,
  }) async {
    final clean = value.trim();
    final payload = {'id': userId, field: clean};

    try {
      await _supabase.from('profiles').upsert(payload);
      return;
    } on PostgrestException catch (error) {
      if (fallbackField == null ||
          !error.message.toLowerCase().contains(field.toLowerCase())) {
        rethrow;
      }
    }

    await _supabase.from('profiles').upsert({
      'id': userId,
      fallbackField: clean,
    });
  }

  Future<void> _creditWholesalerWalletBestEffort({
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

        final currentBalance = _toDouble(profile['wallet_balance']);
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

  String? _extractKnownMissingProductColumn(String message) {
    final text = message.toLowerCase();
    const knownColumns = [
      'stock_qty',
      'quantity',
      'image_url',
      'sku',
      'description',
      'category',
      'type',
    ];

    for (final column in knownColumns) {
      if (text.contains("'$column'") || text.contains('"$column"')) {
        return column;
      }
      if (text.contains('$column column')) {
        return column;
      }
    }
    return null;
  }

  bool _isVendorForeignKeyError(PostgrestException error) {
    return error.code == '23503' &&
        error.message.toLowerCase().contains('vendor_id');
  }

  bool _isOrdersVendorForeignKeyError(PostgrestException error) {
    if (error.code != '23503') {
      return false;
    }
    final message = error.message.toLowerCase();
    return message.contains('orders_vendor_id_fkey') ||
        message.contains('vendor_id');
  }

  Future<void> _ensureVendorRowsInUsersTable(Set<String> vendorIds) async {
    for (final vendorId in vendorIds) {
      if (vendorId.isEmpty) {
        continue;
      }

      final profile = await _fetchProfileForUser(vendorId);
      try {
        await _upsertUserRowWithFallback(
          userId: vendorId,
          fullName: profile?['full_name']?.toString(),
          role: profile?['role']?.toString(),
          phone: profile?['phone']?.toString(),
        );
      } on PostgrestException {
        // Ignore repair failure here and let final insert report the exact DB issue.
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchProfileForUser(String userId) async {
    try {
      final profile = await _supabase
          .from('profiles')
          .select('name, role, shop_name')
          .eq('id', userId)
          .maybeSingle();
      if (profile == null) {
        return null;
      }

      return {
        'full_name': (profile['name'] ?? '').toString(),
        'role': (profile['role'] ?? 'wholesaler').toString(),
        'shop_name': (profile['shop_name'] ?? '').toString(),
      };
    } on PostgrestException {
      return null;
    }
  }

  Future<void> _ensureCurrentUserRowInUsersTable() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('Please login to continue.');
    }

    final metadata = user.userMetadata;
    final roleFromMetadata = metadata?['role'] as String?;
    final nameFromMetadata = metadata?['name'] as String?;
    final fallbackName = user.email?.split('@').first ?? 'User';
    final phoneFromMetadata = metadata?['phone'] as String?;
    final profileRole = await getUserRole();
    final resolvedRole =
        _normalizeUsersTableRole(roleFromMetadata) ??
        _normalizeUsersTableRole(profileRole) ??
        'retailer';
    final resolvedFullName = nameFromMetadata ?? fallbackName;
    final resolvedPhone = phoneFromMetadata?.trim();

    try {
      await _upsertUserRowWithFallback(
        userId: user.id,
        fullName: resolvedFullName,
        role: resolvedRole,
        phone: resolvedPhone,
      );
    } on PostgrestException catch (error) {
      throw AuthException(
        'Could not create vendor user row automatically: ${error.message}',
      );
    }
  }

  Future<void> _upsertUserRowWithFallback({
    required String userId,
    String? fullName,
    String? role,
    String? phone,
  }) async {
    final cleanFullName = (fullName ?? '').trim();
    final cleanRole = _normalizeUsersTableRole(role) ?? 'retailer';
    final cleanPhone = (phone ?? '').trim();

    final payloads = <Map<String, dynamic>>[
      {
        'id': userId,
        if (cleanFullName.isNotEmpty) 'full_name': cleanFullName,
        if (cleanRole.isNotEmpty) 'role': cleanRole,
        if (cleanPhone.isNotEmpty) 'phone': cleanPhone,
      },
      {
        'id': userId,
        if (cleanFullName.isNotEmpty) 'name': cleanFullName,
        if (cleanRole.isNotEmpty) 'role': cleanRole,
        if (cleanPhone.isNotEmpty) 'phone': cleanPhone,
      },
      {'id': userId, if (cleanRole.isNotEmpty) 'role': cleanRole},
    ];

    PostgrestException? lastError;
    for (final payload in payloads) {
      try {
        await _supabase.from('users').upsert(payload, onConflict: 'id');
        return;
      } on PostgrestException catch (error) {
        lastError = error;
      }
    }

    if (lastError != null) {
      throw lastError;
    }
  }

  String? _normalizeUsersTableRole(String? role) {
    final normalized = (role ?? '').trim().toLowerCase();
    if (normalized == 'retailer') {
      return 'retailer';
    }
    if (normalized == 'wholesaler' || normalized == 'vendor') {
      return 'vendor';
    }
    return null;
  }

  String _humanizeProductsDbError(PostgrestException error) {
    if (_isRlsPolicyError(error)) {
      return 'Product action blocked by RLS. Ensure products policies allow vendor_id = auth.uid().';
    }

    final isGlobalSkuUniqueConstraint =
        error.code == '23505' &&
        error.message.toLowerCase().contains('products_sku_key');
    if (isGlobalSkuUniqueConstraint) {
      return 'Global SKU unique constraint detected. For multi-tenant setup, make SKU unique per vendor (vendor_id, sku), not globally on sku.';
    }

    final isVendorForeignKeyIssue =
        error.code == '23503' &&
        error.message.toLowerCase().contains('vendor_id');
    if (isVendorForeignKeyIssue) {
      return 'Products vendor_id foreign key failed. Create a matching row in public.users for this auth user id, or repoint FK to profiles(id).';
    }

    final missingColumn = _extractKnownMissingProductColumn(error.message);
    if (missingColumn != null) {
      return 'Products table is missing "$missingColumn" column. Add it in Supabase table editor.';
    }

    return error.message;
  }

  Future<String> _insertOrderWithFallback(Map<String, dynamic> payload) async {
    final orderNumber =
        (payload['order_number'] ?? '').toString().trim().isEmpty
        ? _generateOrderNumber()
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
      throw AuthException(_humanizeOrdersDbError(lastError));
    }

    throw const AuthException(
      'Order placement failed. Please verify the orders table schema in Supabase.',
    );
  }

  Map<String, dynamic> _buildOrderItem(Map<String, dynamic> product) {
    final productId = (product['id'] ?? '').toString().trim();
    final quantity = _toPositiveInt(product['quantity']);
    final unitPrice = _toDouble(product['price']);
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

  Future<void> _insertOrderItems({
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
            'quantity': _toPositiveInt(item['quantity']),
            'unit_price': _toDouble(item['unit_price']),
          };
        })
        .toList(growable: false);

    if (payload.isEmpty) {
      throw const AuthException('No order items to insert.');
    }

    await _supabase.from('order_items').insert(payload);
  }

  String _generateOrderNumber() {
    return 'ORD-${DateTime.now().millisecondsSinceEpoch}';
  }

  int _toPositiveInt(dynamic value) {
    final parsed = value is int
        ? value
        : value is double
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 1;
    return parsed <= 0 ? 1 : parsed;
  }

  double _toDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _humanizeOrdersDbError(PostgrestException error) {
    if (_isRlsPolicyError(error)) {
      return 'Order action blocked by RLS. Ensure orders policies allow retailer_id/vendor_id = auth.uid().';
    }

    if (_isOrdersVendorForeignKeyError(error)) {
      return 'Order failed due to DB foreign key mismatch (orders_vendor_id_fkey). Run migration 20260403_orders_and_order_items.sql, then try again.';
    }

    return error.message;
  }
}
