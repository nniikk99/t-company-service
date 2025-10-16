class SupabaseConfig {
  // Реальные ключи Supabase проекта
  static const String supabaseUrl = 'https://kwunhuzfnjpcoeusnxzy.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt3dW5odXpmbmpwY29ldXNueHp5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQwNDM2MTksImV4cCI6MjA1OTYxOTYxOX0.2ppg8GtsGKE-ACMC__jSTy0gmn7eUya2xHagi9cdypE';
  static const String supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt3dW5odXpmbmpwY29ldXNueHp5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NDA0MzYxOSwiZXhwIjoyMDU5NjE5NjE5fQ.JAn2aQ4dCcA64HHExVCDzaKOv1MtSTmlF7pPEn0CUlU';
  
  // Для разработки можете использовать эти тестовые значения:
  // static const String supabaseUrl = 'https://your-project-ref.supabase.co';
  // static const String supabaseAnonKey = 'your-anon-key-here';
  
  // Настройки для локальной разработки (если используете локальный Supabase)
  static const String localSupabaseUrl = 'http://localhost:54321';
  static const String localSupabaseAnonKey = 'local-anon-key';
  
  // Флаг для переключения между локальной и продакшн средой
  static const bool useLocalSupabase = false;
  
  static String get url => useLocalSupabase ? localSupabaseUrl : supabaseUrl;
  static String get anonKey => useLocalSupabase ? localSupabaseAnonKey : supabaseAnonKey;
}
