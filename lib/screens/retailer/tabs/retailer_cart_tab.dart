import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vendorlink/config/map_config.dart';
import 'package:vendorlink/screens/retailer/models/retailer_cart.dart';
import 'package:vendorlink/screens/retailer/widgets/vendorlink_payment_gateway_screen.dart';
import 'package:vendorlink/services/auth/auth_service.dart';

class RetailerCartTab extends StatefulWidget {
  const RetailerCartTab({
    super.key,
    required this.cart,
    required this.onOrderPlaced,
  });

  final RetailerCart cart;


  final VoidCallback onOrderPlaced;

  @override
  State<RetailerCartTab> createState() => _RetailerCartTabState();
}

class _RetailerCartTabState extends State<RetailerCartTab> {
  static const double _marketplaceLat = MapConfig.marketplaceLat;
  static const double _marketplaceLng = MapConfig.marketplaceLng;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    widget.cart.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    widget.cart.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart.cart;
    final cartProducts = widget.cart.cartProducts;

    if (cart.isEmpty) {
      return const Center(child: Text('Your cart is empty.'));
    }

    final cartEntries = cart.entries.toList();

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cartEntries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final entry = cartEntries[index];
              final product = cartProducts[entry.key] ?? const {};
              final name = (product['name'] ?? 'Product').toString();
              final price = (product['price'] ?? '0').toString();
              final imageUrl = _productImageUrl(product);

              return Card(
                color: const Color(0xFF111827),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 58,
                      height: 58,
                      color: const Color(0xFF1E293B),
                      child: imageUrl.isEmpty
                          ? const Icon(
                              Icons.image_outlined,
                              color: Color(0xFF94A3B8),
                            )
                          : Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.image_outlined,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(color: Color(0xFFF8FAFC)),
                  ),
                  subtitle: Text(
                    'Price: ₹$price',
                    style: const TextStyle(color: Color(0xFFCBD5E1)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => widget.cart.decrement(entry.key),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('${entry.value}'),
                      IconButton(
                        onPressed: () => widget.cart.increment(entry.key),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.cart.isPlacingOrder ? null : _placeOrder,
              icon: widget.cart.isPlacingOrder
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shopping_bag_outlined),
              label: Text(
                widget.cart.isPlacingOrder ? 'Placing...' : 'Place Order',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _placeOrder() async {
    if (widget.cart.isEmpty || widget.cart.isPlacingOrder) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    widget.cart.isPlacingOrder = true;

    try {
      final totalPayable = widget.cart.cart.entries.fold<double>(0, (
        sum,
        entry,
      ) {
        final product = widget.cart.cartProducts[entry.key] ?? const {};
        final unitPrice = _toDoubleOrNull(product['price']) ?? 0;
        return sum + (unitPrice * entry.value);
      });

      final paymentResult = await navigator.push<VendorlinkPaymentResult>(
        MaterialPageRoute(
          builder: (_) => VendorlinkPaymentGatewayScreen(
            amount: totalPayable,
          ),
        ),
      );

      if (!mounted) return;

      if (paymentResult == null || !paymentResult.success) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Payment cancelled. Order not placed.'),
          ),
        );
        return;
      }

      final location = await _capturePaymentLocationBestEffort();
      final paymentLat = location?.latitude ?? _marketplaceLat;
      final paymentLng = location?.longitude ?? _marketplaceLng;

      final groupedItemsByVendor = <String, List<Map<String, dynamic>>>{};
      for (final entry in widget.cart.cart.entries) {
        final product = widget.cart.cartProducts[entry.key];
        if (product == null) continue;

        final vendorId = (product['vendor_id'] ?? '').toString().trim();
        if (vendorId.isEmpty) continue;

        final item = Map<String, dynamic>.from(product);
        item['quantity'] = entry.value;
        groupedItemsByVendor.putIfAbsent(
          vendorId,
          () => <Map<String, dynamic>>[],
        );
        groupedItemsByVendor[vendorId]!.add(item);
      }

      if (groupedItemsByVendor.isEmpty) {
        throw Exception('No valid products found in cart.');
      }

      final resolvedAddress = await _authService.fetchCurrentRetailerLocation();
      final resolvedPhone = await _authService.fetchCurrentUserPhone();

      for (final items in groupedItemsByVendor.values) {
        await _authService.placeRetailerOrder(
          items: items,
          shippingName: _shippingName(),
          shippingAddress: resolvedAddress.isNotEmpty
              ? resolvedAddress
              : 'Address not available',
          shippingPhone: resolvedPhone,
          paymentLat: paymentLat,
          paymentLng: paymentLng,
          marketplaceLat: _marketplaceLat,
          marketplaceLng: _marketplaceLng,
        );
      }

      if (!mounted) return;

      widget.cart.clear();
      widget.onOrderPlaced();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Payment successful${paymentResult.paymentId == null ? '' : ' (${paymentResult.paymentId})'}. Order placed.',
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      final friendlyMessage = error
          .toString()
          .replaceFirst('Exception: ', '')
          .trim();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            friendlyMessage.isEmpty ? 'Order failed.' : friendlyMessage,
          ),
        ),
      );
    } finally {
      if (mounted) {
        widget.cart.isPlacingOrder = false;
      }
    }
  }

  String _shippingName() {
    final user = _authService.currentSession?.user;
    final metadataName = user?.userMetadata?['name']?.toString().trim();
    final fallback = user?.email?.split('@').first.trim();
    return (metadataName?.isNotEmpty == true
            ? metadataName
            : fallback?.isNotEmpty == true
            ? fallback
            : 'Retailer')
        .toString();
  }

  Future<Position?> _capturePaymentLocationBestEffort() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }
}



String _productImageUrl(Map<String, dynamic> product) {
  final rawValue =
      product['image_url'] ?? product['imageUrl'] ?? product['image'];
  return rawValue == null ? '' : rawValue.toString().trim();
}

double? _toDoubleOrNull(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse((value ?? '').toString());
}
