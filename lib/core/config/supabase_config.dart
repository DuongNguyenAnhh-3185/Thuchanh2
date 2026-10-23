/// Cấu hình Supabase được truyền lúc build/run để không ghi khóa vào mã nguồn.
///
/// Ví dụ:
/// flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxx
abstract final class SupabaseConfig {
  static const String _defaultUrl =
      'https://oemlhoqptgrgtwaozmgu.supabase.co';
  static const String _defaultKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9lbWxob3FwdGdyZ3R3YW96bWd1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI2MDk2MzYsImV4cCI6MjEwODE4NTYzNn0.kH6Z5FlyCvlU1EEuZc2v9_baYxzFSFLJCjZvoCldyIA';

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _defaultUrl,
  );
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: _defaultKey,
    ),
  );

  static bool get isConfigured =>
      url.startsWith('https://') && publishableKey.trim().isNotEmpty;
}
