class SupabaseConfig {
  // Скопируйте этот файл в supabase_config.dart и замените значения на свои
  // ВАЖНО: supabase_config.dart не должен попадать в Git!
  
  static const String supabaseUrl = 'https://your-project-ref.supabase.co';
  static const String supabaseAnonKey = 'your-anon-key-here';
  static const String supabaseServiceKey = 'your-service-role-key-here';
  
  // Настройки для локальной разработки (если используете локальный Supabase)
  static const String localSupabaseUrl = 'http://localhost:54321';
  static const String localSupabaseAnonKey = 'local-anon-key';
  
  // Флаг для переключения между локальной и продакшн средой
  static const bool useLocalSupabase = false;
  
  static String get url => useLocalSupabase ? localSupabaseUrl : supabaseUrl;
  static String get anonKey => useLocalSupabase ? localSupabaseAnonKey : supabaseAnonKey;
}

