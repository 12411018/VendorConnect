part of 'auth_service.dart';

extension AuthCore on AuthService {
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? shopName,
  }) async {
    late final AuthResponse response;
    try {
      response = await _supabase.auth
          .signUp(
            email: email,
            password: password,
            data: {
              'name': name,
              'role': role,
              if ((shopName ?? '').trim().isNotEmpty) 'shop_name': shopName,
            },
          )
          .timeout(const Duration(seconds: 20));
    } on AuthException catch (error) {
      throw AuthException(humanizeAuthError(error.message));
    }

    final user = response.user;
    if (user == null) {
      throw const AuthException('Sign-up failed. Please try again.');
    }

    final hasActiveSession =
        response.session != null || _supabase.auth.currentSession != null;

    if (!hasActiveSession) {
      return;
    }

    try {
      await _supabase
          .from('profiles')
          .upsert({
            'id': user.id,
            'name': name,
            'role': role,
            if ((shopName ?? '').trim().isNotEmpty) 'shop_name': shopName,
          })
          .timeout(const Duration(seconds: 10));
      await ensureCurrentUserRowInUsersTable();
    } on PostgrestException catch (error) {
      if (_supabase.auth.currentSession == null && isRlsPolicyError(error)) {
        return;
      }
      final message = humanizeDbError(error);
      throw AuthException(message);
    }
  }

  Future<void> login({required String email, required String password}) async {
    try {
      await _supabase.auth
          .signInWithPassword(email: email, password: password)
          .timeout(const Duration(seconds: 15));
      await ensureCurrentUserRowInUsersTable();
    } on AuthException catch (error) {
      throw AuthException(humanizeAuthError(error.message));
    } on PostgrestException catch (error) {
      throw AuthException(humanizeDbError(error));
    }
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
        .maybeSingle()
        .timeout(const Duration(seconds: 10));

    if (data == null) {
      return null;
    }

    final role = data['role'] as String?;
    if (role == null || role.isEmpty) {
      return null;
    }

    return role;
  }

  Future<void> createProfileEntryForCurrentUser({
    required String role,
    String? name,
    String? shopName,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('No logged-in user to create profile for.');
    }

    try {
      await _supabase
          .from('profiles')
          .upsert({
            'id': user.id,
            'name': name ?? user.email?.split('@').first ?? 'User',
            'role': role,
            if ((shopName ?? '').trim().isNotEmpty) 'shop_name': shopName,
          })
          .timeout(const Duration(seconds: 10));
    } on PostgrestException catch (error) {
      throw AuthException(humanizeDbError(error));
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  Session? get currentSession => _supabase.auth.currentSession;
  User? get currentUser => _supabase.auth.currentUser;

  Future<void> ensureCurrentUserRowInUsersTable() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('Please login to continue.');
    }

    final metadata = user.userMetadata;
    final roleFromMetadata = metadata?['role'] as String?;
    final nameFromMetadata = metadata?['name'] as String?;
    final fallbackName = user.email?.split('@').first ?? 'User';
    final phoneFromMetadata = metadata?['phone'] as String?;
    final profileRole = await getUserRole();
    final resolvedRole =
        normalizeUsersTableRole(roleFromMetadata) ??
        normalizeUsersTableRole(profileRole) ??
        'retailer';
    final resolvedFullName = nameFromMetadata ?? fallbackName;
    final resolvedPhone = phoneFromMetadata?.trim();

    try {
      await upsertUserRowWithFallback(
        userId: user.id,
        fullName: resolvedFullName,
        role: resolvedRole,
        phone: resolvedPhone,
      );
    } on PostgrestException catch (error) {
      throw AuthException(
        'Could not create vendor user row automatically: ${error.message}',
      );
    }
  }

  Future<void> upsertUserRowWithFallback({
    required String userId,
    String? fullName,
    String? role,
    String? phone,
  }) async {
    final cleanFullName = (fullName ?? '').trim();
    final cleanRole = normalizeUsersTableRole(role) ?? 'retailer';
    final cleanPhone = (phone ?? '').trim();

    final payloads = <Map<String, dynamic>>[
      {
        'id': userId,
        if (cleanFullName.isNotEmpty) 'full_name': cleanFullName,
        if (cleanRole.isNotEmpty) 'role': cleanRole,
        if (cleanPhone.isNotEmpty) 'phone': cleanPhone,
      },
      {
        'id': userId,
        if (cleanFullName.isNotEmpty) 'name': cleanFullName,
        if (cleanRole.isNotEmpty) 'role': cleanRole,
        if (cleanPhone.isNotEmpty) 'phone': cleanPhone,
      },
      {'id': userId, if (cleanRole.isNotEmpty) 'role': cleanRole},
    ];

    PostgrestException? lastError;
    for (final payload in payloads) {
      try {
        await _supabase.from('users').upsert(payload, onConflict: 'id');
        return;
      } on PostgrestException catch (error) {
        lastError = error;
      }
    }

    if (lastError != null) {
      throw lastError;
    }
  }

  String? normalizeUsersTableRole(String? role) {
    final normalized = (role ?? '').trim().toLowerCase();
    if (normalized == 'retailer') {
      return 'retailer';
    }
    if (normalized == 'wholesaler' || normalized == 'vendor') {
      return 'vendor';
    }
    return null;
  }

  Future<void> upsertProfileFieldWithFallback({
    required String userId,
    required String field,
    required String value,
    String? fallbackField,
  }) async {
    final clean = value.trim();
    final payload = {'id': userId, field: clean};

    try {
      await _supabase.from('profiles').upsert(payload);
      return;
    } on PostgrestException catch (error) {
      if (fallbackField == null ||
          !error.message.toLowerCase().contains(field.toLowerCase())) {
        rethrow;
      }
    }

    await _supabase.from('profiles').upsert({
      'id': userId,
      fallbackField: clean,
    });
  }
}
