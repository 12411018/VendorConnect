import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

class WholesalerProfilePage extends StatelessWidget {
  const WholesalerProfilePage({super.key});

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

          final name = (profile['name'] as String?) ?? 'Wholesaler';
          final role = ((profile['role'] as String?) ?? 'wholesaler')
              .toLowerCase();

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
                const SizedBox(height: 20),
                Card(
                  child: Column(
                    children: [
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
