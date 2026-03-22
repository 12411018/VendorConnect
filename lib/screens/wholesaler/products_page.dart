import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../../widgets/product_card.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final AuthService _authService = AuthService();

  Future<void> _showAddProductDialog() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final imageController = TextEditingController(
      text: 'https://images.unsplash.com/photo-1556740749-887f6717d7e4?w=1200',
    );
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Product'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                      labelText: 'Price (e.g. ₹550)',
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
                    controller: imageController,
                    decoration: const InputDecoration(labelText: 'Image URL'),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Enter image URL';
                      }
                      return null;
                    },
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
                try {
                  await _authService.addProductForCurrentUser(
                    name: nameController.text.trim(),
                    price: priceController.text.trim(),
                    imageUrl: imageController.text.trim(),
                  );
                  if (!mounted) {
                    return;
                  }
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Product added successfully.'),
                    ),
                  );
                } on AuthException catch (error) {
                  if (!mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.message)));
                } catch (_) {
                  if (!mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to add product.')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    priceController.dispose();
    imageController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _authService.watchCurrentUserProducts(),
      builder: (context, snapshot) {
        final products = snapshot.data ?? const [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Products',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddProductDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF374151)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 900
                      ? 4
                      : constraints.maxWidth > 680
                      ? 3
                      : 2;

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (products.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No products yet. Add your first product to start your personal workspace.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return GridView.builder(
                    itemCount: products.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.69,
                    ),
                    itemBuilder: (context, index) {
                      final item = products[index];
                      return ProductCard(
                        imageUrl: (item['image_url'] as String?) ?? '',
                        name: (item['name'] as String?) ?? 'Unnamed Product',
                        price: (item['price'] as String?) ?? '₹0',
                        buttonText: 'Manage',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Manage ${(item['name'] as String?) ?? 'product'}',
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
