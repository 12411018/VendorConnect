import 'dart:async';
import 'dart:typed_data';

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
    } on AuthException catch (error) {
      throw AuthException(_humanizeAuthError(error.message));
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
            .select()
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 12));

        final mapped = List<Map<String, dynamic>>.from(rows);
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
            .select()
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
            .select()
            .eq('vendor_id', wholesalerId)
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 12));

        controller.add(List<Map<String, dynamic>>.from(rows));
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

  Future<void> placeRetailerOrder({
    required Map<String, dynamic> product,
    required int quantity,
  }) async {
    final retailerId = _requireCurrentUserId();
    final vendorId = (product['vendor_id'] ?? '').toString().trim();
    if (vendorId.isEmpty) {
      throw const AuthException(
        'Product vendor is missing. Cannot place order.',
      );
    }

    final productId = (product['id'] ?? '').toString();
    final productName = (product['name'] ?? 'Product').toString();
    final sku = (product['sku'] ?? '').toString();
    final category = (product['category'] ?? '').toString();
    final type = (product['type'] ?? '').toString();
    final priceText = (product['price'] ?? '0').toString();
    final unitPrice = double.tryParse(priceText) ?? 0;
    final totalPrice = unitPrice * quantity;

    final payload = {
      'vendor_id': vendorId,
      'retailer_id': retailerId,
      'product_id': productId,
      'product_name': productName,
      'sku': sku.isEmpty ? null : sku,
      'category': category.isEmpty ? null : category,
      'type': type.isEmpty ? null : type,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'status': 'pending',
    };

    try {
      await _insertOrderWithFallback(payload);
    } on PostgrestException catch (error) {
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

  Future<void> addProductForCurrentUser({
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
      await _insertProductWithFallback(payload);
    } on PostgrestException catch (error) {
      if (_isVendorForeignKeyError(error)) {
        await _ensureCurrentUserRowInUsersTable();
        try {
          await _insertProductWithFallback(payload);
          return;
        } on PostgrestException catch (retryError) {
          throw AuthException(_humanizeProductsDbError(retryError));
        }
      }
      throw AuthException(_humanizeProductsDbError(error));
    }
  }

  Future<void> updateProductForCurrentUser({
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

  Future<void> _insertProductWithFallback(Map<String, dynamic> payload) async {
    final insertPayload = Map<String, dynamic>.from(payload);

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await _supabase.from('products').insert(insertPayload);
        return;
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

  Future<void> _ensureCurrentUserRowInUsersTable() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('Please login to continue.');
    }

    final metadata = user.userMetadata;
    final nameFromMetadata = metadata?['name'] as String?;
    final roleFromMetadata = metadata?['role'] as String?;
    final fallbackName = user.email?.split('@').first ?? 'User';

    final payloads = <Map<String, dynamic>>[
      {
        'id': user.id,
        'email': user.email,
        'name': nameFromMetadata ?? fallbackName,
        'role': roleFromMetadata,
      },
      {
        'id': user.id,
        'email': user.email,
        'name': nameFromMetadata ?? fallbackName,
      },
      {'id': user.id, 'email': user.email},
      {'id': user.id},
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
      throw AuthException(
        'Could not create vendor user row automatically: ${lastError.message}',
      );
    }
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

  Future<void> _insertOrderWithFallback(Map<String, dynamic> payload) async {
    final insertPayload = Map<String, dynamic>.from(payload);

    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        await _supabase.from('orders').insert(insertPayload);
        return;
      } on PostgrestException catch (error) {
        final missingColumn = _extractKnownMissingOrderColumn(error.message);
        if (missingColumn == null ||
            !insertPayload.containsKey(missingColumn)) {
          rethrow;
        }
        insertPayload.remove(missingColumn);
      }
    }

    throw const AuthException(
      'Order placement failed due to orders table mismatch. Please verify required columns.',
    );
  }

  String? _extractKnownMissingOrderColumn(String message) {
    final text = message.toLowerCase();
    const knownColumns = [
      'product_id',
      'product_name',
      'sku',
      'category',
      'type',
      'unit_price',
      'total_price',
      'status',
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

  String _humanizeOrdersDbError(PostgrestException error) {
    if (_isRlsPolicyError(error)) {
      return 'Order action blocked by RLS. Ensure orders policies allow retailer_id/vendor_id = auth.uid().';
    }

    final missingColumn = _extractKnownMissingOrderColumn(error.message);
    if (missingColumn != null) {
      return 'Orders table is missing "$missingColumn" column. Add it in Supabase table editor.';
    }

    return error.message;
  }
}
