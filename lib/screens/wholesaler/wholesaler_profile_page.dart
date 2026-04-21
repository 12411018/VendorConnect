import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

class WholesalerProfilePage extends StatelessWidget {
  const WholesalerProfilePage({super.key});

  Future<void> _showEditShopNameDialog(
    BuildContext context,
    AuthService authService,
    String currentShopName,
  ) async {
    final controller = TextEditingController(text: currentShopName);
    final newShopName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Shop Name'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Shop Name',
              hintText: 'Enter your store name',
            ),
            onSubmitted: (value) {
              Navigator.pop(dialogContext, value.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, controller.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    final cleanShopName = (newShopName ?? '').trim();
    if (cleanShopName.isEmpty || cleanShopName == currentShopName.trim()) {
      return;
    }

    try {
      await authService.updateCurrentUserShopName(shopName: cleanShopName);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop name updated successfully.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      final message = error.toString().replaceFirst('Exception: ', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isEmpty ? 'Unable to update shop name.' : message,
          ),
        ),
      );
    }
  }

  Future<void> _showEditNameDialog(
    BuildContext context,
    AuthService authService,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Wholesaler Name'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Wholesaler Name',
              hintText: 'Enter your business name',
            ),
            onSubmitted: (value) {
              Navigator.pop(dialogContext, value.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, controller.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    final cleanName = (newName ?? '').trim();
    if (cleanName.isEmpty || cleanName == currentName.trim()) {
      return;
    }

    try {
      await authService.updateCurrentUserName(name: cleanName);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wholesaler name updated successfully.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      final message = error.toString().replaceFirst('Exception: ', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message.isEmpty ? 'Unable to update name.' : message),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: authService.watchCurrentUserProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = authService.currentSession?.user;
          final profile = snapshot.data;

          if (profile == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Profile is missing in database. Please contact admin to create your profiles row.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final profileName = (profile['name'] as String?)?.trim();
          final metadataName = user?.userMetadata?['name']?.toString().trim();
          final emailPrefix = user?.email?.split('@').first.trim();
          final name = (metadataName != null && metadataName.isNotEmpty)
              ? metadataName
              : (profileName != null && profileName.isNotEmpty)
              ? profileName
              : (emailPrefix != null && emailPrefix.isNotEmpty)
              ? emailPrefix
              : 'Wholesaler';
          final role = ((profile['role'] as String?) ?? 'wholesaler')
              .toLowerCase();
          final metadataShopName = user?.userMetadata?['shop_name']
              ?.toString()
              .trim();
          final profileShopName = (profile['shop_name'] as String?)?.trim();
          final shopName =
              (metadataShopName != null && metadataShopName.isNotEmpty)
              ? metadataShopName
              : (profileShopName != null && profileShopName.isNotEmpty)
              ? profileShopName
              : '';

          final email = user?.email ?? 'No email';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 12),
                const CircleAvatar(
                  radius: 44,
                  backgroundColor: Color(0xFF4F46E5),
                  child: Icon(Icons.business, size: 42, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role == 'wholesaler' ? 'Wholesaler' : role,
                  style: const TextStyle(color: Color(0xFF93C5FD)),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      _showEditNameDialog(context, authService, name),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Name'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () =>
                      _showEditShopNameDialog(context, authService, shopName),
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Edit Shop Name'),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: const Text('Wholesaler Name'),
                        subtitle: Text(name),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.storefront_outlined),
                        title: const Text('Shop Name'),
                        subtitle: Text(shopName.isEmpty ? 'Not set' : shopName),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('Email'),
                        subtitle: Text(email),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('Role'),
                        subtitle: Text(role),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.inventory_2_outlined),
                        title: const Text('Business Type'),
                        subtitle: Text(
                          role == 'wholesaler'
                              ? 'Supplier / Distributor'
                              : 'Retailer',
                        ),
                      ),
                      const Divider(height: 1),
                      const ListTile(
                        leading: Icon(Icons.location_on_outlined),
                        title: Text('Location'),
                        subtitle: Text('PICT College, Dhankawadi, Pune'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
