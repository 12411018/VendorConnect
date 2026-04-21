part of '../auth_service.dart';

extension AuthProfileService on AuthService {
  Stream<Map<String, dynamic>?> watchCurrentUserProfile() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', user.id)
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  Future<void> updateCurrentUserName({required String name}) async {
    final userId = requireCurrentUserId();
    final clean = name.trim();
    if (clean.isEmpty) {
      return;
    }

    await _supabase.from('profiles').upsert({'id': userId, 'name': clean});
  }

  Future<void> updateCurrentUserPhone({required String phone}) async {
    final userId = requireCurrentUserId();
    await upsertProfileFieldWithFallback(
      userId: userId,
      field: 'phone',
      value: phone.trim(),
    );
  }

  Future<void> updateCurrentUserLocation({
    required String locationLabel,
    double? latitude,
    double? longitude,
  }) async {
    final userId = requireCurrentUserId();
    final cleanLabel = locationLabel.trim();

    // Also update auth user metadata so it stays in sync
    try {
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            'location_label': cleanLabel,
            if (latitude != null) 'latitude': latitude,
            if (longitude != null) 'longitude': longitude,
          },
        ),
      );
    } catch (_) {
      // Non-critical: metadata sync failed, profile table is the source of truth
    }

    try {
      await _supabase.from('profiles').upsert({
        'id': userId,
        'location_label': cleanLabel,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      });
      return;
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      if (!(message.contains('location_label') ||
          message.contains('latitude') ||
          message.contains('longitude'))) {
        rethrow;
      }
    }

    await _supabase.from('profiles').upsert({
      'id': userId,
      'location': cleanLabel,
      if (latitude != null) 'lat': latitude,
      if (longitude != null) 'lng': longitude,
    });
  }

  Future<void> updateCurrentUserShopName({required String shopName}) async {
    final userId = requireCurrentUserId();
    await _supabase.from('profiles').upsert({
      'id': userId,
      'shop_name': shopName.trim(),
    });
  }
}
