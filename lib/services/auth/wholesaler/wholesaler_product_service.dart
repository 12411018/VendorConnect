part of '../auth_service.dart';

extension AuthWholesalerProductService on AuthService {
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
            .select('*')
            .eq('vendor_id', user.id)
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 12));

        final mappedRows = List<Map<String, dynamic>>.from(rows);
        controller.add(mappedRows);
      } on PostgrestException catch (error) {
        controller.addError(humanizeProductsDbError(error));
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
    final userId = requireCurrentUserId();

    final payload = {
      'vendor_id': userId,
      'name': name,
      'price': price,
      'stock_qty': quantity,
      'sku': (sku ?? '').trim().isEmpty
          ? 'SKU-${DateTime.now().millisecondsSinceEpoch}'
          : sku?.trim(),
      'category': (category ?? '').trim().isEmpty ? null : category?.trim(),
      'type': (type ?? '').trim().isEmpty ? null : type?.trim(),
      'description': (description ?? '').trim().isEmpty
          ? null
          : (description!.trim().length > 500
              ? description.trim().substring(0, 500)
              : description.trim()),
      'image_url': (imageUrl ?? '').trim().isEmpty ? null : imageUrl?.trim(),
    };

    try {
      return await insertProductWithFallback(payload);
    } on PostgrestException catch (error) {
      if (isVendorForeignKeyError(error)) {
        await ensureCurrentUserRowInUsersTable();
        try {
          return await insertProductWithFallback(payload);
        } on PostgrestException catch (retryError) {
          throw AuthException(humanizeProductsDbError(retryError));
        }
      }
      throw AuthException(humanizeProductsDbError(error));
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
    final userId = requireCurrentUserId();

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
      throw AuthException(humanizeProductsDbError(error));
    }
  }

  Future<void> deleteProductForCurrentUser(String productId) async {
    final userId = requireCurrentUserId();

    try {
      await _supabase
          .from('products')
          .delete()
          .eq('id', productId)
          .eq('vendor_id', userId);
    } on PostgrestException catch (error) {
      throw AuthException(humanizeProductsDbError(error));
    }
  }

  Future<String> uploadProductImageForCurrentUser({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final userId = requireCurrentUserId();
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



  Future<String> insertProductWithFallback(Map<String, dynamic> payload) async {
    final insertPayload = Map<String, dynamic>.from(payload);

    // Fields to progressively remove if index row size is exceeded
    const largeTextFields = ['description', 'image_url', 'category', 'type'];

    for (var attempt = 0; attempt < 5; attempt++) {
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
        final message = error.message.toLowerCase();

        // Handle index row size exceeded
        if (message.contains('index row requires') ||
            message.contains('maximum size is 8191')) {
          // Remove the next large text field and retry
          final removedField = largeTextFields
              .cast<String?>()
              .firstWhere(
                (f) => insertPayload.containsKey(f) && insertPayload[f] != null,
                orElse: () => null,
              );
          if (removedField != null) {
            insertPayload[removedField] = null;
            continue;
          }
          throw AuthException(
            'Product text fields are too large for the database index. '
            'Remove the index on text columns in Supabase, or shorten the product details.',
          );
        }

        final missingColumn = extractKnownMissingProductColumn(error.message);
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

  Future<void> ensureVendorRowsInUsersTable(Set<String> vendorIds) async {
    for (final vendorId in vendorIds) {
      if (vendorId.isEmpty) {
        continue;
      }

      final profile = await _fetchProfileForUser(vendorId);
      try {
        await upsertUserRowWithFallback(
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
}
