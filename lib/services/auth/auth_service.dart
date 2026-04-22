import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'helpers.dart';
part 'auth_core.dart';
part 'profile_service.dart';
part 'retailer/marketplace_service.dart';
part 'retailer/retailer_order_service.dart';
part 'wholesaler/wholesaler_product_service.dart';
part 'wholesaler/wholesaler_order_service.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
}
