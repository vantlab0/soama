import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/supabase_config.dart';

/// Centralized service handling Supabase client lifecycle.
/// Securely initializes the SDK once during application startup.
class SupabaseService {
  SupabaseService._();

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  /// Initializes Supabase if credentials are provided in the environment.
  /// If credentials are missing, skips initialization gracefully to support
  /// test runners and local mock development without crashing.
  static Future<void> initialize() async {
    if (_initialized) return;

    if (!SupabaseConfig.isConfigured) {
      debugPrint(
        'ℹ️ [SupabaseService] SUPABASE_URL and SUPABASE_ANON_KEY not configured. '
        'Running with in-memory auth repository fallback.',
      );
      return;
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
        debug: kDebugMode,
      );
      _initialized = true;
      debugPrint('✅ [SupabaseService] Initialized with ${SupabaseConfig.url}');
    } catch (e, stack) {
      debugPrint('❌ [SupabaseService] Initialization failed: $e\n$stack');
      _initialized = false;
    }
  }

  /// Get the active Supabase client instance if initialized.
  static SupabaseClient? get client {
    if (!_initialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}
