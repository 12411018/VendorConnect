part of '../../auth_service.dart';

extension AuthMarketplaceService on AuthService {
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
        controller.addError(humanizeProductsDbError(error));
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
      throw AuthException(humanizeProductsDbError(error));
    } on TimeoutException {
      throw const AuthException(
        'Marketplace query timed out. Check internet or Supabase response.',
      );
    }
  }

  Future<void> submitProductRating({
    required String productId,
    required int rating,
    String? review,
  }) async {
    final retailerId = requireCurrentUserId();

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
}
