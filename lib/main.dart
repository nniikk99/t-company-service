import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_strategy/url_strategy.dart';
import 'services/app_router.dart';
import 'theme/app_theme.dart';
import 'config/supabase_config.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set hash routing for Telegram Mini App compatibility
  setHashUrlStrategy();
  
  try {
    // ВАЖНО: Проверяем что URL и ключ не placeholder
    print('Initializing Supabase with URL: ${SupabaseConfig.url}');
    
    // Проверяем что URL не placeholder
    if (SupabaseConfig.url.contains('your-project-ref')) {
      throw Exception('Supabase URL contains placeholder! Check supabase_config.dart');
    }
    
    // Инициализируем Supabase
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
    
    print('✅ Supabase initialized successfully');
    
    await initializeDateFormatting('ru');
    runApp(const MyApp());
  } catch (error) {
    // Если Supabase не инициализируется, все равно запускаем приложение
    print('❌ Supabase initialization error: $error');
    
    await initializeDateFormatting('ru');
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'T-Co Service',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRouter.auth,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
