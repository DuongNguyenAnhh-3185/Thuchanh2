/// Cấu hình Supabase được truyền lúc build/run để không ghi khóa vào mã nguồn.
///
/// Ví dụ:
/// flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxx
abstract final class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://oemlhoqptgrgtwaozmgu.supabase.co',
  );
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_oo6cgZImDTT2zmc9SSZ-VQ_CzMkTGMW',
  );

  static bool get isConfigured =>
      url.startsWith('https://') && publishableKey.trim().isNotEmpty;
}
