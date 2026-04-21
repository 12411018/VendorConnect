part of '../../auth_service.dart';

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
            .select()
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
      'sku': (sku ?? '').trim().isEmpty ? null : sku?.trim(),
      'category': (category ?? '').trim().isEmpty ? null : category?.trim(),
      'type': (type ?? '').trim().isEmpty ? null : type?.trim(),
      'description': (description ?? '').trim().isEmpty
          ? null
          : description?.trim(),
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

  Future<void> replaceProductImagesForCurrentUser({
    required String productId,
    required List<String> imageUrls,
  }) async {
    final userId = requireCurrentUserId();
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
      throw AuthException(humanizeProductsDbError(error));
    }
  }

  Future<String> insertProductWithFallback(Map<String, dynamic> payload) async {
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
