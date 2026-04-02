import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:vendorlink/screens/wholesaler/products/services/product_actions_service.dart';

Future<void> showManageProductOptions({
  required BuildContext context,
  required Map<String, dynamic> product,
  required ProductActionsService actionsService,
  required bool Function() isMounted,
  required Future<void> Function() onUpdate,
}) async {
  final productName = (product['name'] ?? 'Product').toString();

  await showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Update Product'),
              onTap: () {
                Navigator.pop(sheetContext);
                onUpdate();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Product'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) {
                    return AlertDialog(
                      title: const Text('Delete Product'),
                      content: Text('Delete $productName permanently?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    );
                  },
                );

                if (confirm != true) {
                  return;
                }

                try {
                  await actionsService.deleteProduct(
                    (product['id'] ?? '').toString(),
                  );
                  if (!isMounted()) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Product deleted.')),
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
                        'Delete failed: ${error.toString().replaceFirst('Exception: ', '')}',
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      );
    },
  );
}
