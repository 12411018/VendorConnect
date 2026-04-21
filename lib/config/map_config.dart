class MapConfig {
  static const String marketplaceName = 'PICT College, Katraj';
  static const double marketplaceLat = 18.4578;
  static const double marketplaceLng = 73.8509;


  static const String embeddedGeoapifyApiKey =
      'dfd7f8580f3741cbae4a39a09eea4ab2';

  // Preferred production path: --dart-define=GEOAPIFY_API_KEY=...
  static const String _envGeoapifyApiKey = String.fromEnvironment(
    'GEOAPIFY_API_KEY',
    defaultValue: '',
  );

  static String get geoapifyApiKey {
    final embedded = embeddedGeoapifyApiKey.trim();
    if (embedded.isNotEmpty) {
      return embedded;
    }
    return _envGeoapifyApiKey.trim();
  }

  static bool get hasGeoapifyKey => geoapifyApiKey.trim().isNotEmpty;
}
