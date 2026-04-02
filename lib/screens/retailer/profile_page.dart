import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  final IconData avatarIcon;

  const ProfilePage({
    super.key,
    required this.name,
    required this.email,
    required this.role,
    required this.avatarIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFF6366F1),
              child: Icon(avatarIcon, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              role,
              style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 14),
            ),
            const SizedBox(height: 30),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.email_outlined,
                  color: Color(0xFF93C5FD),
                ),
                title: const Text('Email'),
                subtitle: Text(email),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.badge_outlined,
                  color: Color(0xFF93C5FD),
                ),
                title: const Text('Role'),
                subtitle: Text(role),
              ),
            ),
            Card(
              child: const ListTile(
                leading: Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFF93C5FD),
                ),
                title: Text('Location'),
                subtitle: Text('Pune, Maharashtra'),
              ),
            ),
            Card(
              child: const ListTile(
                leading: Icon(Icons.phone_outlined, color: Color(0xFF93C5FD)),
                title: Text('Phone'),
                subtitle: Text('+91 98765 43210'),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Edit Profile'),
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
