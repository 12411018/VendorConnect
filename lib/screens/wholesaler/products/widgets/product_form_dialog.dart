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
  await Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _ProductFormPage(
        actionsService: actionsService,
        imagePicker: imagePicker,
        isMounted: isMounted,
        existing: existing,
      ),
    ),
  );
}

class _ProductFormPage extends StatefulWidget {
  const _ProductFormPage({
    required this.actionsService,
    required this.imagePicker,
    required this.isMounted,
    this.existing,
  });

  final ProductActionsService actionsService;
  final ImagePicker imagePicker;
  final bool Function() isMounted;
  final Map<String, dynamic>? existing;

  @override
  State<_ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<_ProductFormPage> {
  late final bool _isEdit = widget.existing != null;
  late final TextEditingController _nameController = TextEditingController(
    text: (widget.existing?['name'] ?? '').toString(),
  );
  late final TextEditingController _priceController = TextEditingController(
    text: (widget.existing?['price'] ?? '').toString(),
  );
  late final TextEditingController _skuController = TextEditingController(
    text: (widget.existing?['sku'] ?? '').toString(),
  );
  late final TextEditingController _categoryController = TextEditingController(
    text: (widget.existing?['category'] ?? '').toString(),
  );
  late final TextEditingController _typeController = TextEditingController(
    text: (widget.existing?['type'] ?? '').toString(),
  );
  late final TextEditingController _quantityController = TextEditingController(
    text: (widget.existing?['stock_qty'] ?? widget.existing?['quantity'] ?? 0)
        .toString(),
  );
  late final TextEditingController _descriptionController =
      TextEditingController(
        text: (widget.existing?['description'] ?? '').toString(),
      );
  final TextEditingController _imageController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final List<Uint8List> _galleryBytes = <Uint8List>[];
  final List<String> _galleryExt = <String>[];
  final List<String> _linkedUrls = <String>[];
  bool _useImageUrl = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final existingPrimary = (widget.existing?['image_url'] ?? '')
        .toString()
        .trim();
    if (existingPrimary.isNotEmpty) {
      _linkedUrls.add(existingPrimary);
    }

    final existingRelation = widget.existing?['product_images'];
    if (existingRelation is List) {
      for (final row in existingRelation) {
        if (row is Map<String, dynamic>) {
          final url = (row['image_url'] ?? '').toString().trim();
          if (url.isNotEmpty && !_linkedUrls.contains(url)) {
            _linkedUrls.add(url);
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _skuController.dispose();
    _categoryController.dispose();
    _typeController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final file = await widget.imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 86,
        maxWidth: 1600,
      );
      if (file == null) {
        return;
      }
      final bytes = await file.readAsBytes();
      final parts = file.path.split('.');
      final ext = parts.length > 1 ? parts.last.toLowerCase() : 'jpg';
      if (!mounted) {
        return;
      }
      setState(() {
        _galleryBytes.add(bytes);
        _galleryExt.add(ext);
      });
    } catch (_) {
      if (!widget.isMounted() || !mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gallery unavailable. Use image URLs instead.'),
        ),
      );
    }
  }

  Future<void> _saveProduct() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;

    setState(() {
      _saving = true;
    });

    try {
      final allImageUrls = <String>[..._linkedUrls];
      for (var i = 0; i < _galleryBytes.length; i++) {
        final uploaded = await widget.actionsService.resolveImageUrl(
          useImageUrl: false,
          imageText: '',
          pickedImageBytes: _galleryBytes[i],
          pickedImageExtension: _galleryExt[i],
        );
        if ((uploaded ?? '').trim().isNotEmpty) {
          allImageUrls.add(uploaded!.trim());
        }
      }

      final productId = await widget.actionsService.saveProduct(
        isEdit: _isEdit,
        productId: (widget.existing?['id'] ?? '').toString(),
        name: _nameController.text.trim(),
        price: _priceController.text.trim(),
        quantity: quantity,
        sku: _skuController.text.trim(),
        category: _categoryController.text.trim(),
        type: _typeController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: allImageUrls.isEmpty ? null : allImageUrls.first,
      );

      if (allImageUrls.isNotEmpty) {
        await widget.actionsService.replaceProductImages(
          productId: productId,
          imageUrls: allImageUrls,
        );
      }

      if (!widget.isMounted() || !mounted) {
        return;
      }

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? 'Product updated successfully.'
                : 'Product added successfully.',
          ),
        ),
      );
    } on AuthException catch (error) {
      if (!widget.isMounted() || !mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!widget.isMounted() || !mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Action failed: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _removeImageAt(int index) {
    setState(() {
      if (index < _galleryBytes.length) {
        _galleryBytes.removeAt(index);
        _galleryExt.removeAt(index);
      } else {
        _linkedUrls.removeAt(index - _galleryBytes.length);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: Text(_isEdit ? 'Update Product' : 'Add Product'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: const Color(0xFF0F172A),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFF1F2937)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Product Images',
                            style: TextStyle(
                              color: Color(0xFFF8FAFC),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 148,
                            child:
                                (_galleryBytes.isEmpty && _linkedUrls.isEmpty)
                                ? Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF111827),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFF475569),
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.photo_library_outlined,
                                        color: Colors.white70,
                                        size: 36,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount:
                                        _galleryBytes.length +
                                        _linkedUrls.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 8),
                                    itemBuilder: (_, index) {
                                      final isGallery =
                                          index < _galleryBytes.length;
                                      return Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: isGallery
                                                ? Image.memory(
                                                    _galleryBytes[index],
                                                    width: 160,
                                                    height: 148,
                                                    fit: BoxFit.cover,
                                                  )
                                                : Image.network(
                                                    _linkedUrls[index -
                                                        _galleryBytes.length],
                                                    width: 160,
                                                    height: 148,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (
                                                          _,
                                                          __,
                                                          ___,
                                                        ) => Container(
                                                          width: 160,
                                                          height: 148,
                                                          color: const Color(
                                                            0xFF111827,
                                                          ),
                                                          child: const Icon(
                                                            Icons.broken_image,
                                                          ),
                                                        ),
                                                  ),
                                          ),
                                          Positioned(
                                            right: 4,
                                            top: 4,
                                            child: InkWell(
                                              onTap: () =>
                                                  _removeImageAt(index),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.54),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  size: 14,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                selected: !_useImageUrl,
                                label: const Text('Gallery'),
                                onSelected: (selected) {
                                  setState(() {
                                    _useImageUrl = !selected;
                                  });
                                },
                              ),
                              ChoiceChip(
                                selected: _useImageUrl,
                                label: const Text('Image URL'),
                                onSelected: (selected) {
                                  setState(() {
                                    _useImageUrl = selected;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (!_useImageUrl)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _pickImageFromGallery,
                                icon: const Icon(
                                  Icons.add_photo_alternate_outlined,
                                ),
                                label: const Text('Add Image From Gallery'),
                              ),
                            ),
                          if (_useImageUrl)
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _imageController,
                                    style: const TextStyle(
                                      color: Color(0xFFF8FAFC),
                                    ),
                                    cursorColor: Color(0xFF38BDF8),
                                    decoration: InputDecoration(
                                      labelText: 'Image URL',
                                      hintText:
                                          'https://example.com/product.jpg',
                                      labelStyle: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                      ),
                                      hintStyle: const TextStyle(
                                        color: Color(0xFF64748B),
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFF111827),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF38BDF8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.tonal(
                                  onPressed: () {
                                    final url = _imageController.text.trim();
                                    if (url.isEmpty) {
                                      return;
                                    }
                                    setState(() {
                                      if (!_linkedUrls.contains(url)) {
                                        _linkedUrls.add(url);
                                      }
                                      _imageController.clear();
                                    });
                                  },
                                  child: const Text('Add'),
                                ),
                              ],
                            ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(color: Color(0xFFF8FAFC)),
                            cursorColor: Color(0xFF38BDF8),
                            decoration: const InputDecoration(
                              labelText: 'Product Name',
                              labelStyle: TextStyle(color: Color(0xFF94A3B8)),
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
                            controller: _priceController,
                            style: const TextStyle(color: Color(0xFFF8FAFC)),
                            cursorColor: Color(0xFF38BDF8),
                            decoration: const InputDecoration(
                              labelText: 'Price',
                              hintText: 'e.g. 120 or 120.50',
                              labelStyle: TextStyle(color: Color(0xFF94A3B8)),
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
                            controller: _skuController,
                            style: const TextStyle(color: Color(0xFFF8FAFC)),
                            cursorColor: Color(0xFF38BDF8),
                            decoration: const InputDecoration(
                              labelText: 'SKU (internal)',
                              labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _categoryController,
                            style: const TextStyle(color: Color(0xFFF8FAFC)),
                            cursorColor: Color(0xFF38BDF8),
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _typeController,
                            style: const TextStyle(color: Color(0xFFF8FAFC)),
                            cursorColor: Color(0xFF38BDF8),
                            decoration: const InputDecoration(
                              labelText: 'Type',
                              labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _quantityController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Color(0xFFF8FAFC)),
                            cursorColor: Color(0xFF38BDF8),
                            decoration: const InputDecoration(
                              labelText: 'Stock Quantity',
                              labelStyle: TextStyle(color: Color(0xFF94A3B8)),
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
                            controller: _descriptionController,
                            minLines: 2,
                            maxLines: 4,
                            style: const TextStyle(color: Color(0xFFF8FAFC)),
                            cursorColor: Color(0xFF38BDF8),
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _saving
                                      ? null
                                      : () {
                                          Navigator.of(context).pop();
                                        },
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _saving ? null : _saveProduct,
                                  child: Text(
                                    _saving
                                        ? 'Saving...'
                                        : (_isEdit ? 'Update' : 'Add'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
