import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/app_router.dart';
import 'screens/auth_screen.dart';
import 'theme/app_theme.dart';
import 'config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Инициализируем Supabase
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
    
    runApp(const MyApp());
  } catch (error) {
    // Если Supabase не инициализируется, все равно запускаем приложение
    print('Supabase initialization error: $error');
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
