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
  }) async {
    late final AuthResponse response;
    try {
      response = await _supabase.auth
          .signUp(
            email: email,
            password: password,
            data: {'name': name, 'role': role},
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
          .upsert({'id': user.id, 'name': name, 'role': role})
          .timeout(const Duration(seconds: 10));
      try {
        await _ensureCurrentUserRowInUsersTable();
      } on AuthException catch (error) {
        if (kDebugMode) {
          debugPrint('[UsersSync][SignUp][Skipped] ${error.message}');
        }
      }
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

      try {
        await _ensureCurrentUserRowInUsersTable();
      } on AuthException catch (error) {
        if (kDebugMode) {
          debugPrint('[UsersSync][Login][Skipped] ${error.message}');
        }
      }
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
        try {
          final rows = await _supabase
              .from('products')
              .select(
                '*, product_images(image_url, sort_order), product_ratings(rating, review, created_at, retailer_id)',
              )
              .eq('vendor_id', user.id)
              .order('created_at', ascending: false)
              .timeout(const Duration(seconds: 12));

          final mappedRows = List<Map<String, dynamic>>.from(rows);
          controller.add(mappedRows);
          return;
        } on PostgrestException {
          final rows = await _supabase
              .from('products')
              .select()
              .eq('vendor_id', user.id)
              .order('created_at', ascending: false)
              .timeout(const Duration(seconds: 12));

          final mappedRows = List<Map<String, dynamic>>.from(rows);
          controller.add(mappedRows);
          return;
        }
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
        List<Map<String, dynamic>> mapped;
        try {
          final rows = await _supabase
              .from('products')
              .select(
                '*, product_images(image_url, sort_order), product_ratings(rating, review, created_at, retailer_id)',
              )
              .order('created_at', ascending: false)
              .timeout(const Duration(seconds: 12));
          mapped = List<Map<String, dynamic>>.from(rows);
        } on PostgrestException {
          final rows = await _supabase
              .from('products')
              .select()
              .order('created_at', ascending: false)
              .timeout(const Duration(seconds: 12));
          mapped = List<Map<String, dynamic>>.from(rows);
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
          .select()
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 12));
      return List<Map<String, dynamic>>.from(rows);
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
        final rows = await _supabase
            .from('orders')
            .select('*, order_items(*, product:products(*))')
            .eq('retailer_id', retailerId)
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 12));

        final mapped = List<Map<String, dynamic>>.from(rows);
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

  Stream<List<Map<String, dynamic>>> watchWholesalerOrders() {
    final wholesalerId = _requireCurrentUserId();
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    Timer? timer;

    Future<void> loadOrders() async {
      try {
        final rows = await _supabase
            .from('orders')
            .select('*, order_items(*, product:products(*))')
            .eq('vendor_id', wholesalerId)
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 12));

        final mappedRows = List<Map<String, dynamic>>.from(rows);
        if (kDebugMode) {
          debugPrint(
            '[WholesalerOrders][Primary] vendor_id=$wholesalerId rows=${mappedRows.length}',
          );
          if (mappedRows.isNotEmpty) {
            final first = mappedRows.first;
            final firstItems = first['order_items'];
            final itemCount = firstItems is List ? firstItems.length : 0;
            debugPrint(
              '[WholesalerOrders][Primary][FirstRow] order_id=${first['id']} order_number=${first['order_number']} status=${first['status']} items=$itemCount keys=${first.keys.toList()}',
            );
          }
        }
        if (mappedRows.isNotEmpty) {
          controller.add(mappedRows);
          return;
        }

        // Fallback for legacy/mismatched vendor_id data: show latest orders.
        final anyRows = await _supabase
            .from('orders')
            .select('*, order_items(*, product:products(*))')
            .order('created_at', ascending: false)
            .limit(50)
            .timeout(const Duration(seconds: 12));

        if (kDebugMode) {
          debugPrint(
            '[WholesalerOrders][VendorMismatchFallback] vendor_id=$wholesalerId fallback_rows=${anyRows.length}',
          );
          if (anyRows.isNotEmpty) {
            final first = anyRows.first;
            final firstItems = first['order_items'];
            final itemCount = firstItems is List ? firstItems.length : 0;
            debugPrint(
              '[WholesalerOrders][VendorMismatchFallback][FirstRow] order_id=${first['id']} order_number=${first['order_number']} status=${first['status']} items=$itemCount keys=${first.keys.toList()}',
            );
          }
        }

        controller.add(List<Map<String, dynamic>>.from(anyRows));
      } on PostgrestException catch (error) {
        // Fallback to base orders query when nested relation is unavailable.
        try {
          final fallbackRows = await _supabase
              .from('orders')
              .select()
              .eq('vendor_id', wholesalerId)
              .order('created_at', ascending: false)
              .timeout(const Duration(seconds: 12));

          if (kDebugMode) {
            debugPrint(
              '[WholesalerOrders][Fallback] code=${error.code} message=${error.message}',
            );
          }

          controller.add(List<Map<String, dynamic>>.from(fallbackRows));
        } on PostgrestException {
          controller.addError(_humanizeOrdersDbError(error));
        }
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
      await _decrementStockBestEffort(orderItems, vendorId: vendorId);
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
          await _decrementStockBestEffort(orderItems, vendorId: vendorId);
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

    PostgrestException? lastError;
    final candidateStatuses = _candidateStatusesForOrderUpdate(status);

    for (final candidate in candidateStatuses) {
      try {
        await _supabase
            .from('orders')
            .update({'status': candidate})
            .eq('id', orderId)
            .eq('vendor_id', wholesalerId);

        final persisted = await _isOrderStatusPersistedForVendor(
          orderId: orderId,
          vendorId: wholesalerId,
          status: candidate,
        );
        if (persisted) {
          return;
        }
      } on PostgrestException catch (error) {
        lastError = error;
        if (!_isInvalidOrderStatusEnumError(error)) {
          throw AuthException(_humanizeOrdersDbError(error));
        }
      }
    }

    if (lastError != null) {
      throw AuthException(_humanizeOrdersDbError(lastError));
    }

    throw const AuthException('Failed to update order status.');
  }

  Future<void> updateOrderStatusForRetailer({
    required String orderId,
    required String status,
  }) async {
    final retailerId = _requireCurrentUserId();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    PostgrestException? lastError;
    final candidateStatuses = _candidateStatusesForOrderUpdate(status);

    for (final candidate in candidateStatuses) {
      try {
        final payload = <String, dynamic>{'status': candidate};
        if (_isDeliveredLikeStatus(candidate)) {
          payload['retailer_confirmed_at'] = nowIso;
        }

        await _supabase
            .from('orders')
            .update(payload)
            .eq('id', orderId)
            .eq('retailer_id', retailerId);

        final persisted = await _isOrderStatusPersistedForRetailer(
          orderId: orderId,
          retailerId: retailerId,
          status: candidate,
        );
        if (persisted) {
          return;
        }
      } on PostgrestException catch (error) {
        lastError = error;
        if (_isMissingRetailerConfirmedAtColumnError(error) &&
            _isDeliveredLikeStatus(candidate)) {
          try {
            await _supabase
                .from('orders')
                .update({'status': candidate})
                .eq('id', orderId)
                .eq('retailer_id', retailerId);

            final statusOnlyPersisted =
                await _isOrderStatusPersistedForRetailer(
                  orderId: orderId,
                  retailerId: retailerId,
                  status: candidate,
                );
            if (statusOnlyPersisted) {
              return;
            }
          } on PostgrestException catch (statusOnlyError) {
            lastError = statusOnlyError;
          }
        }

        if (!_isInvalidOrderStatusEnumError(error) &&
            !_isMissingRetailerConfirmedAtColumnError(error)) {
          throw AuthException(_humanizeOrdersDbError(error));
        }
      }
    }

    if (lastError != null) {
      if (status.trim().toLowerCase() == 'delivered') {
        try {
          await _supabase
              .from('orders')
              .update({'retailer_confirmed_at': nowIso})
              .eq('id', orderId)
              .eq('retailer_id', retailerId);

          final fallbackPersisted = await _isOrderStatusPersistedForRetailer(
            orderId: orderId,
            retailerId: retailerId,
            status: 'delivered',
          );
          if (!fallbackPersisted) {
            throw const AuthException(
              'Order confirmation did not persist. Check orders update policy in Supabase.',
            );
          }
          return;
        } on PostgrestException catch (fallbackError) {
          lastError = fallbackError;
        } on AuthException {
          rethrow;
        }
      }

      throw AuthException(_humanizeOrdersDbError(lastError));
    }

    throw const AuthException('Failed to update order status.');
  }

  Future<bool> _isOrderStatusPersistedForRetailer({
    required String orderId,
    required String retailerId,
    required String status,
  }) async {
    final row = await _supabase
        .from('orders')
        .select('status, retailer_confirmed_at')
        .eq('id', orderId)
        .eq('retailer_id', retailerId)
        .maybeSingle();

    if (row == null) {
      return false;
    }

    final confirmedAt = (row['retailer_confirmed_at'] ?? '').toString().trim();
    if (confirmedAt.isNotEmpty) {
      return true;
    }

    final current = (row['status'] ?? '').toString().toLowerCase();
    if (_isDeliveredLikeStatus(status)) {
      return _isDeliveredLikeStatus(current);
    }

    return current == status.toLowerCase();
  }

  Future<bool> _isOrderStatusPersistedForVendor({
    required String orderId,
    required String vendorId,
    required String status,
  }) async {
    final row = await _supabase
        .from('orders')
        .select('status')
        .eq('id', orderId)
        .eq('vendor_id', vendorId)
        .maybeSingle();

    if (row == null) {
      return false;
    }

    final current = (row['status'] ?? '').toString().toLowerCase();
    if (_isDeliveredLikeStatus(status)) {
      return _isDeliveredLikeStatus(current);
    }
    return current == status.toLowerCase();
  }

  List<String> _candidateStatusesForOrderUpdate(String requestedStatus) {
    final normalized = requestedStatus.trim().toLowerCase();
    if (normalized == 'pending' || normalized == 'order_placed') {
      return const ['pending', 'accepted', 'processing'];
    }
    if (normalized == 'processing' ||
        normalized == 'delivery_pending_confirmation') {
      return const ['processing', 'accepted', 'pending'];
    }
    if (normalized == 'delivered') {
      return const ['delivered', 'completed', 'fulfilled', 'done'];
    }
    if (normalized == 'accepted') {
      return const ['accepted', 'confirmed', 'approved', 'processing'];
    }
    if (normalized == 'rejected') {
      return const ['rejected', 'cancelled', 'canceled', 'declined'];
    }
    return [normalized];
  }

  bool _isInvalidOrderStatusEnumError(PostgrestException error) {
    final text = '${error.code ?? ''} ${error.message}'.toLowerCase();
    return text.contains('invalid input value for enum') &&
        text.contains('order_status');
  }

  bool _isDeliveredLikeStatus(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'delivered' ||
        normalized == 'completed' ||
        normalized == 'fulfilled' ||
        normalized == 'done';
  }

  bool _isMissingRetailerConfirmedAtColumnError(PostgrestException error) {
    final text = '${error.code ?? ''} ${error.message}'.toLowerCase();
    return text.contains("could not find the 'retailer_confirmed_at' column") ||
        (text.contains('column') && text.contains('retailer_confirmed_at'));
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
    final clampedRating = rating.clamp(1, 5);

    try {
      await _supabase.from('product_ratings').upsert({
        'product_id': productId,
        'retailer_id': retailerId,
        'rating': clampedRating,
        'review': (review ?? '').trim().isEmpty ? null : review?.trim(),
      }, onConflict: 'product_id,retailer_id');
    } on PostgrestException catch (error) {
      if ((error.message).toLowerCase().contains('product_ratings')) {
        throw const AuthException(
          'Rating table not found. Run latest Supabase migration for ratings.',
        );
      }
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

  Session? get currentSession => _supabase.auth.currentSession;

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
        final productId = (inserted['id'] ?? '').toString();
        if (productId.isNotEmpty) {
          return productId;
        }
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
          .select('name, role')
          .eq('id', userId)
          .maybeSingle();
      if (profile == null) {
        return null;
      }

      return {
        'full_name': (profile['name'] ?? '').toString(),
        'role': (profile['role'] ?? 'wholesaler').toString(),
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
        _normalizeRole(roleFromMetadata) ??
        _normalizeRole(profileRole) ??
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
    final cleanRole = _normalizeRole(role) ?? 'retailer';
    final cleanPhone = (phone ?? '').trim();

    final payloads = <Map<String, dynamic>>[
      {
        'id': userId,
        'full_name': cleanFullName.isNotEmpty ? cleanFullName : 'User',
        'role': cleanRole,
        if (cleanPhone.isNotEmpty) 'phone': cleanPhone,
      },
      {
        'id': userId,
        'full_name': cleanFullName.isNotEmpty ? cleanFullName : 'User',
        'role': cleanRole,
      },
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

  String? _normalizeRole(String? role) {
    final normalized = (role ?? '').trim().toLowerCase();
    if (normalized == 'wholesaler' || normalized == 'retailer') {
      return normalized;
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

  Future<void> _decrementStockBestEffort(
    List<Map<String, dynamic>> orderItems, {
    String? vendorId,
  }) async {
    final requestedQtyByProduct = <String, int>{};
    for (final item in orderItems) {
      final productId = (item['product_id'] ?? '').toString().trim();
      if (productId.isEmpty) {
        throw const AuthException('Each order item must include a product id.');
      }
      final qty = _toPositiveInt(item['quantity']);
      requestedQtyByProduct.update(
        productId,
        (existing) => existing + qty,
        ifAbsent: () => qty,
      );
    }

    if (requestedQtyByProduct.isEmpty) {
      return;
    }

    final productIds = requestedQtyByProduct.keys.toList(growable: false);

    // Preferred path: use DB function to bypass retailer-side RLS safely.
    var allUpdatedWithRpc = true;
    for (final entry in requestedQtyByProduct.entries) {
      final updated = await _decrementStockViaRpcBestEffort(
        productId: entry.key,
        quantity: entry.value,
        vendorId: vendorId,
      );
      if (!updated) {
        allUpdatedWithRpc = false;
        break;
      }
    }
    if (allUpdatedWithRpc) {
      return;
    }
    final rows = await _supabase
        .from('products')
        .select('id, name, stock_qty')
        .inFilter('id', productIds)
        .timeout(const Duration(seconds: 12));

    final products = List<Map<String, dynamic>>.from(rows);
    final byId = <String, Map<String, dynamic>>{
      for (final row in products) (row['id'] ?? '').toString(): row,
    };

    for (final entry in requestedQtyByProduct.entries) {
      final product = byId[entry.key];
      if (product == null) {
        continue;
      }
      final available = _toNonNegativeInt(product['stock_qty']);
      final requested = entry.value;
      final newStock = (available - requested).clamp(0, 1 << 30);

      try {
        await _supabase
            .from('products')
            .update({'stock_qty': newStock})
            .eq('id', entry.key)
            .eq('stock_qty', available);
      } on PostgrestException catch (error) {
        if (kDebugMode) {
          debugPrint('[StockDecrement][Skipped] ${error.message}');
        }
      }
    }
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
        debugPrint('[WalletCredit][Skipped] ${error.message}');
      }
    }
  }

  Future<bool> _decrementStockViaRpcBestEffort({
    required String productId,
    required int quantity,
    String? vendorId,
  }) async {
    try {
      final response = await _supabase.rpc(
        'decrement_product_stock',
        params: {
          'p_product_id': productId,
          'p_quantity': quantity,
          'p_vendor_id': vendorId,
        },
      );

      if (response is bool) {
        return response;
      }
      if (response is num) {
        return response != 0;
      }
      if (response is String) {
        return response.toLowerCase() == 'true';
      }

      // If RPC exists and returns anything else, treat as success to avoid
      // falling back to retailer-side updates that may be blocked by RLS.
      return true;
    } on PostgrestException catch (error) {
      if (_isMissingRpcFunction(error, 'decrement_product_stock')) {
        return false;
      }
      if (kDebugMode) {
        debugPrint('[StockDecrement][RPCSkipped] ${error.message}');
      }
      return false;
    }
  }

  bool _isMissingRpcFunction(PostgrestException error, String functionName) {
    final text = '${error.code ?? ''} ${error.message}'.toLowerCase();
    return text.contains('does not exist') && text.contains(functionName);
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

  int _toNonNegativeInt(dynamic value) {
    final parsed = value is int
        ? value
        : value is double
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 0;
    return parsed < 0 ? 0 : parsed;
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
