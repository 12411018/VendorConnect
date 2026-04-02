import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:vendorlink/screens/wholesaler/products/services/product_actions_service.dart';

Future<void> showProductFormDialog({
  required BuildContext context,
  required ProductActionsService actionsService,
  required ImagePicker imagePicker,
  required bool Function() isMounted,
  Map<String, dynamic>? existing,
}) async {
  final isEdit = existing != null;
  final productId = (existing?['id'] ?? '').toString();
  final nameController = TextEditingController();
  final priceController = TextEditingController();
  final skuController = TextEditingController();
  final categoryController = TextEditingController();
  final typeController = TextEditingController();
  final quantityController = TextEditingController();
  final descriptionController = TextEditingController();
  final imageController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  Uint8List? pickedImageBytes;
  String pickedImageExtension = 'jpg';
  bool useImageUrl = true;

  if (isEdit) {
    nameController.text = (existing['name'] ?? '').toString();
    priceController.text = (existing['price'] ?? '').toString();
    skuController.text = (existing['sku'] ?? '').toString();
    categoryController.text = (existing['category'] ?? '').toString();
    typeController.text = (existing['type'] ?? '').toString();
    quantityController.text =
        (existing['stock_qty'] ?? existing['quantity'] ?? 0).toString();
    descriptionController.text = (existing['description'] ?? '').toString();
    imageController.text = (existing['image_url'] ?? '').toString();
    useImageUrl = imageController.text.trim().isNotEmpty;
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogBuilderContext, setDialogState) {
          Future<void> pickImageFromGallery() async {
            try {
              final file = await imagePicker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
                maxWidth: 1600,
              );
              if (file == null) {
                return;
              }

              final bytes = await file.readAsBytes();
              final segments = file.path.split('.');
              final extension = segments.length > 1
                  ? segments.last.toLowerCase()
                  : 'jpg';

              setDialogState(() {
                pickedImageBytes = bytes;
                pickedImageExtension = extension;
                useImageUrl = false;
              });
            } catch (_) {
              if (!isMounted()) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Gallery image not available on this device. Use Image URL option.',
                  ),
                ),
              );
            }
          }

          return AlertDialog(
            title: Text(isEdit ? 'Update Product' : 'Add Product'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF374151)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: pickedImageBytes != null
                          ? Image.memory(pickedImageBytes!, fit: BoxFit.cover)
                          : (imageController.text.trim().isNotEmpty
                                ? Image.network(
                                    imageController.text.trim(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(
                                        Icons.image_not_supported,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.image_outlined,
                                      color: Colors.white70,
                                      size: 36,
                                    ),
                                  )),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            selected: !useImageUrl,
                            label: const Text('Gallery'),
                            onSelected: (selected) {
                              setDialogState(() {
                                useImageUrl = !selected ? useImageUrl : false;
                              });
                            },
                          ),
                          ChoiceChip(
                            selected: useImageUrl,
                            label: const Text('Image URL'),
                            onSelected: (selected) {
                              setDialogState(() {
                                useImageUrl = selected;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!useImageUrl)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: pickImageFromGallery,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Pick From Gallery'),
                        ),
                      ),
                    if (useImageUrl)
                      TextFormField(
                        controller: imageController,
                        decoration: const InputDecoration(
                          labelText: 'Image URL',
                          hintText: 'https://example.com/product.jpg',
                        ),
                      ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name',
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Enter product name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        hintText: 'e.g. 120 or ₹120',
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Enter price';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: skuController,
                      decoration: const InputDecoration(labelText: 'SKU'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: categoryController,
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: typeController,
                      decoration: const InputDecoration(labelText: 'Type'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stock Quantity',
                      ),
                      validator: (value) {
                        final number = int.tryParse((value ?? '').trim());
                        if (number == null) {
                          return 'Enter a valid quantity';
                        }
                        if (number < 0) {
                          return 'Quantity cannot be negative';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!(formKey.currentState?.validate() ?? false)) {
                    return;
                  }

                  final quantity =
                      int.tryParse(quantityController.text.trim()) ?? 0;

                  try {
                    final imageUrl = await actionsService.resolveImageUrl(
                      useImageUrl: useImageUrl,
                      imageText: imageController.text.trim(),
                      pickedImageBytes: pickedImageBytes,
                      pickedImageExtension: pickedImageExtension,
                    );

                    await actionsService.saveProduct(
                      isEdit: isEdit,
                      productId: productId,
                      name: nameController.text.trim(),
                      price: priceController.text.trim(),
                      quantity: quantity,
                      sku: skuController.text.trim(),
                      category: categoryController.text.trim(),
                      type: typeController.text.trim(),
                      description: descriptionController.text.trim(),
                      imageUrl: imageUrl,
                    );

                    if (!isMounted()) {
                      return;
                    }
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEdit
                              ? 'Product updated successfully.'
                              : 'Product added successfully.',
                        ),
                      ),
                    );
                  } on AuthException catch (error) {
                    if (!isMounted()) {
                      return;
                    }
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.message)));
                  } catch (error) {
                    if (!isMounted()) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Action failed: ${error.toString().replaceFirst('Exception: ', '')}',
                        ),
                      ),
                    );
                  }
                },
                child: Text(isEdit ? 'Update' : 'Add'),
              ),
            ],
          );
        },
      );
    },
  );

  nameController.dispose();
  priceController.dispose();
  skuController.dispose();
  categoryController.dispose();
  typeController.dispose();
  quantityController.dispose();
  descriptionController.dispose();
  imageController.dispose();
}
