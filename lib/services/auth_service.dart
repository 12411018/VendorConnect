import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth/helpers.dart';
part 'auth/auth_core.dart';
part 'auth/profile_service.dart';
part 'auth/retailer/marketplace_service.dart';
part 'auth/retailer/retailer_order_service.dart';
part 'auth/wholesaler/wholesaler_product_service.dart';
part 'auth/wholesaler/wholesaler_order_service.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
}
