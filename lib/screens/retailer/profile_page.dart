import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/auth/auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  late final TextEditingController _locationController;
  bool _isSavingProfile = false;
  bool _isSavingLocation = false;

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController();
    // Load initial location from profiles table asynchronously
    _authService.fetchCurrentRetailerLocation().then((location) {
      if (mounted && location.isNotEmpty) {
        _locationController.text = location;
      }
    });
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _showEditNamePhoneDialog({
    required String currentName,
    required String currentPhone,
  }) async {
    final nameController = TextEditingController(text: currentName);
    final phoneController = TextEditingController(text: currentPhone);

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Contact Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (save != true) {
      nameController.dispose();
      phoneController.dispose();
      return;
    }

    final newName = nameController.text.trim();
    final newPhone = phoneController.text.trim();

    nameController.dispose();
    phoneController.dispose();

    if (newName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name cannot be empty.')));
      return;
    }

    setState(() {
      _isSavingProfile = true;
    });

    try {
      await _authService.updateCurrentUserName(name: newName);
      await _authService.updateCurrentUserPhone(phone: newPhone);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.toString().replaceFirst('Exception: ', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isEmpty ? 'Unable to update profile.' : message,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingProfile = false;
        });
      }
    }
  }

  Future<void> _showEditLocationDialog({
    required String currentLocation,
  }) async {
    _locationController.text = currentLocation;
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Location'),
          content: TextField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'Profile Location',
              hintText: 'Example: Pune, Sukhsagar Nagar',
              prefixIcon: Icon(Icons.pin_drop_outlined),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (save == true) {
      await _saveManualLocation();
    }
  }

  Future<void> _saveManualLocation() async {
    final value = _locationController.text.trim();
    if (value.isEmpty) {
      return;
    }

    setState(() {
      _isSavingLocation = true;
    });

    try {
      await _authService.updateCurrentUserLocation(locationLabel: value);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Location updated.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', '').trim().isEmpty
                ? 'Unable to update location.'
                : error.toString().replaceFirst('Exception: ', '').trim(),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingLocation = false;
        });
      }
    }
  }

  Future<void> _setLiveLocation() async {
    setState(() {
      _isSavingLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Please enable location service first.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final locationLabel =
          'Live location (${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)})';
      _locationController.text = locationLabel;

      await _authService.updateCurrentUserLocation(
        locationLabel: locationLabel,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Live location captured successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', '').trim().isEmpty
                ? 'Unable to fetch live location.'
                : error.toString().replaceFirst('Exception: ', '').trim(),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _authService.watchCurrentUserProfile(),
        builder: (context, snapshot) {
          final profile = snapshot.data;
          final name = (profile?['name'] ?? '').toString().trim().isNotEmpty
              ? (profile?['name'] ?? '').toString().trim()
              : (user?.email?.split('@').first ?? 'Retailer');
          final roleRaw = (profile?['role'] ?? 'retailer').toString();
          final role = roleRaw.isEmpty
              ? 'Retailer'
              : '${roleRaw[0].toUpperCase()}${roleRaw.substring(1)}';
          final email = user?.email ?? 'No email';
          final location =
              (profile?['location_label'] ?? profile?['location'] ?? 'Not set')
                  .toString()
                  .trim();
          final displayLocation = location.isEmpty ? 'Not set' : location;
          final phone = (profile?['phone'] ?? '')
              .toString()
              .trim();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: Color(0xFF6366F1),
                  child: Icon(Icons.store, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  role,
                  style: const TextStyle(
                    color: Color(0xFF93C5FD),
                    fontSize: 14,
                  ),
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
                  child: ListTile(
                    leading: const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFF93C5FD),
                    ),
                    title: const Text('Location'),
                    subtitle: Text(displayLocation),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.phone_outlined,
                      color: Color(0xFF93C5FD),
                    ),
                    title: const Text('Phone'),
                    subtitle: Text(phone.isEmpty ? 'Not set' : phone),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSavingProfile
                        ? null
                        : () => _showEditNamePhoneDialog(
                            currentName: name,
                            currentPhone: phone,
                          ),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(
                      _isSavingProfile ? 'Saving...' : 'Edit Name & Contact',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSavingLocation
                            ? null
                            : () => _showEditLocationDialog(
                                currentLocation: displayLocation == 'Not set' ? '' : displayLocation,
                              ),
                        icon: const Icon(Icons.edit_location_alt_outlined),
                        label: const Text('Edit Location'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSavingLocation ? null : _setLiveLocation,
                        icon: const Icon(Icons.my_location_outlined),
                        label: const Text('Use Live Location'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
