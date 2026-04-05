import 'dart:typed_data';

import 'package:vendorlink/services/auth_service.dart';

class ProductActionsService {
  ProductActionsService(this._authService);

  final AuthService _authService;

  Stream<List<Map<String, dynamic>>> watchCurrentUserProducts() {
    return _authService.watchCurrentUserProducts();
  }

  Future<String?> resolveImageUrl({
    required bool useImageUrl,
    required String imageText,
    Uint8List? pickedImageBytes,
    required String pickedImageExtension,
  }) async {
    if (useImageUrl) {
      return imageText;
    }

    if (pickedImageBytes != null) {
      return _authService.uploadProductImageForCurrentUser(
        bytes: pickedImageBytes,
        fileExtension: pickedImageExtension,
      );
    }

    return imageText;
  }

  Future<String> saveProduct({
    required bool isEdit,
    required String productId,
    required String name,
    required String price,
    required int quantity,
    required String sku,
    required String category,
    required String type,
    required String description,
    required String? imageUrl,
  }) async {
    if (isEdit) {
      return _authService.updateProductForCurrentUser(
        productId: productId,
        name: name,
        price: price,
        quantity: quantity,
        sku: sku,
        category: category,
        type: type,
        description: description,
        imageUrl: imageUrl,
      );
    }

    return _authService.addProductForCurrentUser(
      name: name,
      price: price,
      quantity: quantity,
      sku: sku,
      category: category,
      type: type,
      description: description,
      imageUrl: imageUrl,
    );
  }

  Future<void> replaceProductImages({
    required String productId,
    required List<String> imageUrls,
  }) {
    return _authService.replaceProductImagesForCurrentUser(
      productId: productId,
      imageUrls: imageUrls,
    );
  }

  Future<void> deleteProduct(String productId) {
    return _authService.deleteProductForCurrentUser(productId);
  }
}
