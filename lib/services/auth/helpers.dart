part of '../auth_service.dart';

extension AuthServiceHelpers on AuthService {
  String requireCurrentUserId() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('Please login to continue.');
    }
    return user.id;
  }

}

bool isRlsPolicyError(PostgrestException error) {
  final message = error.message.toLowerCase();
  return error.code == '42501' ||
      message.contains('row-level security policy');
}

bool isRateLimitAuthMessage(String message) {
  final text = message.toLowerCase();
  return text.contains('rate limit') ||
      text.contains('too many requests') ||
      text.contains('over_email_send_rate_limit');
}

int? extractRetrySeconds(String message) {
  final match = RegExp(
    r'(\d+)\s*seconds?',
    caseSensitive: false,
  ).firstMatch(message);
  if (match == null) {
    return null;
  }
  return int.tryParse(match.group(1) ?? '');
}

String humanizeAuthError(String message) {
  if (isRateLimitAuthMessage(message)) {
    final seconds = extractRetrySeconds(message) ?? 60;
    return 'Rate limit exceeded. Please wait $seconds seconds and try again.';
  }

  return message;
}

String humanizeDbError(PostgrestException error) {
  if (isRlsPolicyError(error)) {
    return 'Sign-up blocked by database security policy. Please fix profiles RLS policies in Supabase.';
  }

  if (error.code == '23505') {
    return 'Profile already exists for this account.';
  }

  return error.message;
}

String humanizeProductsDbError(PostgrestException error) {
  if (isRlsPolicyError(error)) {
    return 'Product action blocked by RLS. Ensure products policies allow vendor_id = auth.uid().';
  }

  final isGlobalSkuUniqueConstraint =
      error.code == '23505' &&
      error.message.toLowerCase().contains('products_sku_key');
  if (isGlobalSkuUniqueConstraint) {
    return 'Global SKU unique constraint detected. For multi-tenant setup, make SKU unique per vendor (vendor_id, sku), not globally on sku.';
  }

  final isVendorForeignKeyIssue =
      error.code == '23503' &&
      error.message.toLowerCase().contains('vendor_id');
  if (isVendorForeignKeyIssue) {
    return 'Products vendor_id foreign key failed. Create a matching row in public.users for this auth user id, or repoint FK to profiles(id).';
  }

  final missingColumn = extractKnownMissingProductColumn(error.message);
  if (missingColumn != null) {
    return 'Products table is missing "$missingColumn" column. Add it in Supabase table editor.';
  }

  return error.message;
}

String humanizeOrdersDbError(PostgrestException error) {
  if (isRlsPolicyError(error)) {
    return 'Order action blocked by RLS. Ensure orders policies allow retailer_id/vendor_id = auth.uid().';
  }

  if (isOrdersVendorForeignKeyError(error)) {
    return 'Order failed due to DB foreign key mismatch (orders_vendor_id_fkey). Run migration 20260403_orders_and_order_items.sql, then try again.';
  }

  return error.message;
}

String? extractKnownMissingProductColumn(String message) {
  final text = message.toLowerCase();
  const knownColumns = [
    'stock_qty',
    'quantity',
    'image_url',
    'sku',
    'description',
    'category',
    'type',
  ];

  for (final column in knownColumns) {
    if (text.contains("'$column'") || text.contains('"$column"')) {
      return column;
    }
    if (text.contains('$column column')) {
      return column;
    }
  }
  return null;
}

bool isVendorForeignKeyError(PostgrestException error) {
  return error.code == '23503' &&
      error.message.toLowerCase().contains('vendor_id');
}

bool isOrdersVendorForeignKeyError(PostgrestException error) {
  if (error.code != '23503') {
    return false;
  }
  final message = error.message.toLowerCase();
  return message.contains('orders_vendor_id_fkey') ||
      message.contains('vendor_id');
}

String generateOrderNumber() {
  return 'ORD-${DateTime.now().millisecondsSinceEpoch}';
}

int toPositiveInt(dynamic value) {
  final parsed = value is int
      ? value
      : value is double
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? 1;
  return parsed <= 0 ? 1 : parsed;
}

double toDouble(dynamic value) {
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}


