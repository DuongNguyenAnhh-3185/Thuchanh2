import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';

/// Khởi tạo Supabase bằng Firebase ID token (Third-party Auth).
class SupabaseService {
  SupabaseService._();

  static bool _initialized = false;

  static bool get isConfigured => SupabaseConfig.isConfigured;
  static bool get isInitialized => _initialized;

  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError(
        'Supabase chưa được cấu hình. Hãy truyền SUPABASE_URL và '
        'SUPABASE_PUBLISHABLE_KEY bằng --dart-define.',
      );
    }
    return Supabase.instance.client;
  }

  static Future<void> initialize() async {
    if (_initialized || !isConfigured) return;

    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
      accessToken: () async {
        return FirebaseAuth.instance.currentUser?.getIdToken(false);
      },
    );
    _initialized = true;
  }
}
