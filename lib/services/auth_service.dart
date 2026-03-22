import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    final AuthResponse response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'role': role},
    );

    final user = response.user;
    if (user == null) {
      throw const AuthException('Sign-up failed. Please try again.');
    }

    try {
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'name': name,
        'role': role,
      });
    } on PostgrestException catch (error) {
      final message = _humanizeDbError(error);
      throw AuthException(message);
    }
  }

  Future<void> login({required String email, required String password}) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<String?> getUserRole() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return null;
    }

    final data = await _supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) {
      return null;
    }

    final role = data['role'] as String?;
    if (role == null || role.isEmpty) {
      return null;
    }

    return role;
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

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

  Stream<List<Map<String, dynamic>>> watchCurrentUserProducts() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return Stream.value(const []);
    }

    return _supabase
        .from('products')
        .stream(primaryKey: ['id'])
        .eq('owner_id', user.id)
        .order('created_at', ascending: false);
  }

  Future<void> addProductForCurrentUser({
    required String name,
    required String price,
    required String imageUrl,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('Please login to add products.');
    }

    await _supabase.from('products').insert({
      'owner_id': user.id,
      'name': name,
      'price': price,
      'image_url': imageUrl,
    });
  }

  Session? get currentSession => _supabase.auth.currentSession;

  bool _isRlsPolicyError(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == '42501' ||
        message.contains('row-level security policy');
  }

  String _humanizeDbError(PostgrestException error) {
    if (_isRlsPolicyError(error)) {
      return 'Sign-up blocked by database security policy. Please fix profiles RLS policies in Supabase.';
    }

    if (error.code == '23505') {
      return 'Profile already exists for this account.';
    }

    return error.message;
  }
}
