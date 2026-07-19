import 'package:shared_preferences/shared_preferences.dart';

/// Settings for TMDB API configuration.
/// This class provides getters and setters for the API key and URLs.
/// The values are persisted using SharedPreferences, allowing the user
/// to modify the API key at runtime via a Settings screen.
class Settings {
  // Keys for SharedPreferences storage.
  static const _apiKeyPref = 'tmdb_api_key';

  // Default values – used when no custom key has been saved.
  static const String _defaultApiKey = 'a27751dec0837fe77d58d0e3977b2cd9';
  static const String baseUrl = 'https://api.themoviedb.org/3';
  static const String imgBase = 'https://image.tmdb.org/t/p/w500';

  /// Retrieves the current API key. If a custom key has been saved it is returned,
  /// otherwise the default placeholder is used.
  static Future<String> get apiKey async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPref) ?? _defaultApiKey;
  }

  /// Saves a new API key entered by the user. If the key is empty, removes it to fallback to default.
  static Future<void> setApiKey(String newKey) async {
    final prefs = await SharedPreferences.getInstance();
    if (newKey.trim().isEmpty) {
      await prefs.remove(_apiKeyPref);
    } else {
      await prefs.setString(_apiKeyPref, newKey.trim());
    }
  }

  // Supabase Shared Preferences Keys
  static const _supabaseUrlPref = 'supabase_url';
  static const _supabaseKeyPref = 'supabase_anon_key';

  // Default Fallbacks
  static const String _defaultSupabaseUrl = 'https://iqprkbrjcgdqqsmwpwlo.supabase.co';
  static const String _defaultSupabaseKey = 'sb_publishable_tBgaGVED0LPdIgoPWlCpZg_ZKc0rYrN';

  /// Retrieves the current Supabase URL.
  static Future<String> get supabaseUrl async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_supabaseUrlPref) ?? _defaultSupabaseUrl;
  }

  /// Saves a custom Supabase URL.
  static Future<void> setSupabaseUrl(String newUrl) async {
    final prefs = await SharedPreferences.getInstance();
    if (newUrl.trim().isEmpty) {
      await prefs.remove(_supabaseUrlPref);
    } else {
      await prefs.setString(_supabaseUrlPref, newUrl.trim());
    }
  }

  /// Retrieves the current Supabase Anon/Publishable Key.
  static Future<String> get supabaseKey async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_supabaseKeyPref) ?? _defaultSupabaseKey;
  }

  /// Saves a custom Supabase Anon/Publishable Key.
  static Future<void> setSupabaseKey(String newKey) async {
    final prefs = await SharedPreferences.getInstance();
    if (newKey.trim().isEmpty) {
      await prefs.remove(_supabaseKeyPref);
    } else {
      await prefs.setString(_supabaseKeyPref, newKey.trim());
    }
  }
}
